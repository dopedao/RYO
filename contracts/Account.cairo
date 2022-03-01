%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import (
    call_contract, get_caller_address, get_tx_signature, get_contract_address, get_block_timestamp)
from starkware.cairo.common.hash_state import (
    hash_init, hash_finalize, hash_update, hash_update_single)
from starkware.cairo.common.math import (assert_nn_le)

#
# Structs
#

struct Message:
    member sender : felt
    member to : felt
    member selector : felt
    member calldata : felt*
    member calldata_size : felt
    member nonce : felt
end

#
# Storage
#

@storage_var
func current_nonce() -> (res : felt):
end

@storage_var
func public_key() -> (res : felt):
end

# Given a guardian selector, returns its expiration time
@storage_var
func guardians(selector : felt) -> (expires : felt):
end

#
# Guards
#

@view
func assert_only_self{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    let (self) = get_contract_address()
    let (caller) = get_caller_address()
    assert self = caller
    return ()
end

#
# Getters
#

@view
func get_public_key{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        res : felt):
    let (res) = public_key.read()
    return (res=res)
end

@view
func get_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        res : felt):
    let (res) = get_contract_address()
    return (res=res)
end

@view
func get_nonce{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (res : felt):
    let (res) = current_nonce.read()
    return (res=res)
end

#
# Setters
#

@external
func set_public_key{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        new_public_key : felt):
    assert_only_self()
    public_key.write(new_public_key)
    return ()
end

@external
func set_guardian{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        public_key : felt, to : felt, selector : felt, expires : felt):
    alloc_locals
    assert_only_self()
    let (guardian_selector) = hash_guardian_selector(public_key, to, selector)
    guardians.write(guardian_selector, expires)
    return ()
end

#
# Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _public_key : felt):
    public_key.write(_public_key)
    return ()
end

#
# Business logic
#

@view
func is_valid_signature{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr,
        ecdsa_ptr : SignatureBuiltin*}(public_key : felt, hash : felt, signature_len : felt, signature : felt*) -> ():

    # This interface expects a signature pointer and length to make
    # no assumption about signature validation schemes.
    # But this implementation does, and it expects a (sig_r, sig_s) pair.
    let sig_r = signature[0]
    let sig_s = signature[1]

    verify_ecdsa_signature(
        message=hash, public_key=public_key, signature_r=sig_r, signature_s=sig_s)

    return ()
end

@view
func is_authorized{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr,
        ecdsa_ptr : SignatureBuiltin*}(
        public_key : felt, to : felt, selector : felt) -> ():

    let (guardian_selector) = hash_guardian_selector(public_key, to, selector)
    let (expires) = guardians.read(guardian_selector)
    let (block_timestamp) = get_block_timestamp()
    assert_nn_le(block_timestamp, expires)
    return ()
end

@external
func execute{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr,
        ecdsa_ptr : SignatureBuiltin*}(
        to : felt, selector : felt, calldata_len : felt, calldata : felt*, nonce : felt) -> (
        response : felt):
    alloc_locals
    let (_public_key) = public_key.read()
    let (response) = _execute(_public_key, to, selector, calldata_len, calldata, nonce)
    return (response=response)
end

@external
func executeFrom{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr,
        ecdsa_ptr : SignatureBuiltin*}(
        public_key : felt, to : felt, selector : felt, calldata_len : felt, calldata : felt*, nonce : felt) -> (
        response : felt):
    alloc_locals

    is_authorized(public_key, to, selector)

    # execute call
    let (response) = _execute(public_key, to, selector, calldata_len, calldata, nonce)
    return (response=response)
end

func _execute{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr,
        ecdsa_ptr : SignatureBuiltin*}(
        public_key : felt, to : felt, selector : felt, calldata_len : felt, calldata : felt*, nonce : felt) -> (
        response : felt):
    alloc_locals

    let (__fp__, _) = get_fp_and_pc()
    let (_address) = get_contract_address()
    let (_current_nonce) = current_nonce.read()

    local message : Message = Message(
        _address,
        to,
        selector,
        calldata,
        calldata_size=calldata_len,
        _current_nonce
        )

    # validate transaction
    let (hash) = hash_message(&message)
    let (signature_len, signature) = get_tx_signature()
    is_valid_signature(public_key, hash, signature_len, signature)

    # bump nonce
    current_nonce.write(_current_nonce + 1)

    # execute call
    let response = call_contract(
        contract_address=message.to,
        function_selector=message.selector,
        calldata_size=message.calldata_size,
        calldata=message.calldata)

    return (response=response.retdata_size)
end

func hash_message{pedersen_ptr : HashBuiltin*}(message : Message*) -> (res : felt):
    alloc_locals
    # we need to make `res_calldata` local
    # to prevent the reference from being revoked
    let (local res_calldata) = hash_calldata(message.calldata, message.calldata_size)
    let hash_ptr = pedersen_ptr
    with hash_ptr:
        let (hash_state_ptr) = hash_init()
        # first three iterations are 'sender', 'to', and 'selector'
        let (hash_state_ptr) = hash_update(hash_state_ptr, message, 3)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, res_calldata)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, message.nonce)
        let (res) = hash_finalize(hash_state_ptr)
        let pedersen_ptr = hash_ptr
        return (res=res)
    end
end

func hash_calldata{pedersen_ptr : HashBuiltin*}(calldata : felt*, calldata_size : felt) -> (
        res : felt):
    let hash_ptr = pedersen_ptr
    with hash_ptr:
        let (hash_state_ptr) = hash_init()
        let (hash_state_ptr) = hash_update(hash_state_ptr, calldata, calldata_size)
        let (res) = hash_finalize(hash_state_ptr)
        let pedersen_ptr = hash_ptr
        return (res=res)
    end
end

func hash_guardian_selector{pedersen_ptr : HashBuiltin*}(guardian : felt, to : felt, selector : felt) -> (
        res : felt):
    let hash_ptr = pedersen_ptr
    with hash_ptr:
        let (hash_state_ptr) = hash_init()
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, guardian)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, to)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, selector)
        let (res) = hash_finalize(hash_state_ptr)
        let pedersen_ptr = hash_ptr
        return (res=res)
    end
end