# OpenZepellin commit hash: 259d2854a5c1e7d62878f0fb03d0772777c7c348

%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import call_contract, get_caller_address, get_tx_signature
from starkware.cairo.common.hash_state import (
    hash_init, hash_finalize, hash_update, hash_update_single
)

#
# Structs
#

struct Message:
    member sender: felt
    member to: felt
    member selector: felt
    member calldata: felt*
    member calldata_size: felt
    member nonce: felt
end

#
# Storage
#

@storage_var
func current_nonce() -> (res: felt):
end

@storage_var
func public_key() -> (res: felt):
end

@storage_var
func initialized() -> (res: felt):
end

@storage_var
func address() -> (res: felt):
end

#
# Guards
#

@view
func assert_only_self{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (self) = address.read()
    let (caller) = get_caller_address()
    assert self = caller
    return ()
end

@view
func assert_initialized{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    let (_initialized) = initialized.read()
    assert _initialized = 1
    return ()
end

#
# Getters
#

@view
func get_public_key{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: felt):
    let (res) = public_key.read()
    return (res=res)
end

@view
func get_address{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: felt):
    let (res) = address.read()
    return (res=res)
end

@view
func get_nonce{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (res: felt):
    let (res) = current_nonce.read()
    return (res=res)
end

#
# Setters
#

@external
func set_public_key{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(new_public_key: felt):
    assert_only_self()
    public_key.write(new_public_key)
    return ()
end

#
# Constructor
#

@constructor
func constructor{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(_public_key: felt):
    public_key.write(_public_key)
    return()
end

#
# Initializer (will remove once this.address is available for the constructor)
#


@external
func initialize{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(_address: felt):
    let (_initialized) = initialized.read()
    assert _initialized = 0
    initialized.write(1)
    address.write(_address)
    return ()
end

#
# Business logic
#

@view
func is_valid_signature{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        ecdsa_ptr: SignatureBuiltin*
    }(
        hash: felt,
        signature_len: felt,
        signature: felt*
    ) -> ():
    assert_initialized()
    let (_public_key) = public_key.read()

    # This interface expects a signature pointer and length to make
    # no assumption about signature validation schemes.
    # But this implementation does, and it expects a (sig_r, sig_s) pair.
    let sig_r = signature[0]
    let sig_s = signature[1]

    verify_ecdsa_signature(
        message=hash,
        public_key=_public_key,
        signature_r=sig_r,
        signature_s=sig_s)

    return ()
end

@external
func execute{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        ecdsa_ptr: SignatureBuiltin*
    }(
        to: felt,
        selector: felt,
        calldata_len: felt,
        calldata: felt*,
        nonce: felt
    ) -> (response : felt):
    alloc_locals
    assert_initialized()

    let (__fp__, _) = get_fp_and_pc()
    let (_address) = address.read()
    let (_current_nonce) = current_nonce.read()

    local syscall_ptr : felt* = syscall_ptr
    local range_check_ptr = range_check_ptr
    local _current_nonce = _current_nonce

    local message: Message = Message(
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
    is_valid_signature(hash, signature_len, signature)

    # bump nonce
    current_nonce.write(_current_nonce + 1)

    # execute call
    let response = call_contract(
        contract_address=message.to,
        function_selector=message.selector,
        calldata_size=message.calldata_size,
        calldata=message.calldata
    )

    return (response=response.retdata_size)
end

func hash_message{pedersen_ptr : HashBuiltin*}(message: Message*) -> (res: felt):
    alloc_locals
    # we need to make `res_calldata` local
    # to prevent the reference from being revoked
    let (local res_calldata) = hash_calldata(message.calldata, message.calldata_size)
    let hash_ptr = pedersen_ptr
    with hash_ptr:
        let (hash_state_ptr) = hash_init()
        # first three iterations are 'sender', 'to', and 'selector'
        let (hash_state_ptr) = hash_update(
            hash_state_ptr,
            message,
            3
        )
        let (hash_state_ptr) = hash_update_single(
            hash_state_ptr, res_calldata)
        let (hash_state_ptr) = hash_update_single(
            hash_state_ptr, message.nonce)
        let (res) = hash_finalize(hash_state_ptr)
        let pedersen_ptr = hash_ptr
    return (res=res)
    end
end

func hash_calldata{pedersen_ptr: HashBuiltin*}(
        calldata: felt*,
        calldata_size: felt
    ) -> (res: felt):
    let hash_ptr = pedersen_ptr
    with hash_ptr:
        let (hash_state_ptr) = hash_init()
        let (hash_state_ptr) = hash_update(
            hash_state_ptr,
            calldata,
            calldata_size
        )
        let (res) = hash_finalize(hash_state_ptr)
        let pedersen_ptr = hash_ptr
        return (res=res)
    end
end