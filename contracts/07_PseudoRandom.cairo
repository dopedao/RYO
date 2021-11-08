%lang starknet
%builtins pedersen range_check bitwise

from starkware.cairo.common.bitwise import bitwise_xor
from starkware.cairo.common.cairo_builtins import (HashBuiltin,
    BitwiseBuiltin)
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import (unsigned_div_rem,
    split_felt)
from starkware.starknet.common.syscalls import get_caller_address

from contracts.utils.interfaces import IModuleController

##### Module XX #####
#
# This module ...
#
#
####################

# Seed (for pseudorandom) that players add to.
@storage_var
func entropy_seed() -> (value : felt):
end


@storage_var
func controller_address() -> (address : felt):
end


# Called on deployment only.
@constructor
func constructor{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        address_of_controller : felt
    ):
    # Store the address of the only fixed contract in the system.
    controller_address.write(address_of_controller)
    return ()
end


# Gets hard-to-predict values. Player can draw multiple times.
# Has not been tested rigorously (e.g., for biasing).
@external
func get_pseudorandom{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (
        num_to_use : felt
    ):
    only_approved()
    # Seed is fed to linear congruential generator.
    # seed = (multiplier * seed + increment) % modulus.
    # Params from GCC. (https://en.wikipedia.org/wiki/Linear_congruential_generator).
    let (old_seed) = entropy_seed.read()
    # Snip in half to a manageable size for unsigned_div_rem.
    let (left, right) = split_felt(old_seed)
    let (_, new_seed) = unsigned_div_rem(1103515245 * right + 1,
        2**31)
    # Number has form: 10**9 (xxxxxxxxxx).
    entropy_seed.write(new_seed)
    return (new_seed)
end

# Add to seed. If modules want to make manipulation difficult, make
# val0 and val1 hard-to-grind values (grinding val0 or val1 will
# wildly affect their turn and therefore make it largely nonviable).
@external
func add_to_seed{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        bitwise_ptr : BitwiseBuiltin*,
        range_check_ptr
    }(
        val0 : felt,
        val1 : felt
    ) -> (
        num_to_use : felt
    ):
    # Players add to the seed (seed = seed XOR hash(item, quantity)).
    # You can game the hash by changing the item/quantity (not useful)
    let (hash) = hash2{hash_ptr=pedersen_ptr}(val0, val1)
    let (old_seed) = entropy_seed.read()
    let (new_seed) = bitwise_xor(hash, old_seed)
    entropy_seed.write(new_seed)
    return (new_seed)
end

# This returns the stored number without running the generator.
@view
func read_current{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (
        old_seed : felt
    ):
    let (old_seed) = entropy_seed.read()
    # Number has form: 10**9 (xxxxxxxxxx).
    return (old_seed)
end


# Checks write-permission of the calling contract.
func only_approved{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    # Get the address of the module trying to write to this contract.
    let (caller) = get_caller_address()
    let (controller) = controller_address.read()
    # Pass this address on to the ModuleController.
    # "Does this address have write-authority here?"
    # Will revert the transaction if not.
    IModuleController.has_write_access(
        contract_address=controller,
        address_attempting_to_write=caller)
    return ()
end