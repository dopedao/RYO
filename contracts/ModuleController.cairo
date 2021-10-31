
%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_not_zero

##### Controller #####
#
# A long-lived open-ended lookup table.
#
# Is in control of the addresses game modules use.
# Is controlled by the Arbiter, who can update addresses.
# Maintains a generic mapping that is open ended and which
# can be added to for new modules.
#
# A new module is deployed and the address is submitted for
# a purpose. Purposes are indexed, and their interpretation
# is off-chain/social.

# Modules are organised by numbers: a particular module (storage
# of player health, or a new game module) will have a module_id which
# will be used by other components, even if the underlying contract
# address changes.

# Flow: An ecosystem contract calls the controller with a module_id,
# and uses the response to make a call to that contract.

######################
# Module id descriptions. Do not alter, only append.
# 1 Dope Wars ti83 mechanics.
# 2 AMM item/money values of NPC dealers.
# 3 Hustler item/money values.
# 4 Hustler L1 trait registry.
# 5 Combat mechanics.
# 6 [available]

#######################
# To be compliant with this system, a new module containint variables
# intended to be open to the ecosystem MUST implement a check
# on any contract.
# 1. Get address attempting to write to the variables in the contract.
# 2. Call 'has_write_access()'

# This way, new modules can be added to update existing systems a
# and create new dynamics.

##### Storage #####
@storage_var
func arbiter() -> (bool : felt):
end

# The contract address for a module.
@storage_var
func address_of_module_id(module_id : felt) -> (address : felt):
end

# The module id of a contract address.
@storage_var
func module_id_of_address(address : felt) -> (module_id : felt):
end

# A mapping of which modules have write access to the others. 1=yes.
@storage_var
func can_write_to(
        doing_writing : felt,
        being_written_to : felt
    ) -> (
        bool : felt
    ):
end


##### External functions #####
# Called by the current Arbiter to replace itself.
@external
func appoint_new_arbiter{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        new_arbiter : felt
    ):
    only_arbiter()
    arbiter.write(new_arbiter)
    return ()
end


# Called by the Arbiter to set new address mappings.
@external
func set_address_for_module_id{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    only_arbiter()
    let (caller) = get_caller_address()
    return ()
end


# Called to authorise write access of one module to another.
@external
func set_write_access{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        module_id_doing_writing : felt,
        module_id_being_written_to : felt
    ):
    only_arbiter()
    can_write_to.write(module_id_doing_writing,
        module_id_being_written_to, 1)
    return ()
end


##### View functions #####
@view
func get_module_address{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        module_id : felt
    ) -> (
        address : felt
    ):
    let (address) = address_of_module_id.read(module_id)
    return (address)
end


# Called by a module before it updates internal state.
@view
func has_write_access{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        address_attempting_to_write : felt
    ):
    # Get the address of the module calling (being written to).
    let (caller) = get_caller_address()
    let (to_id) = module_id_of_address.read(caller)
    let (from_id) = address_attempting_to_write
    let (bool) = can_write_to.read(from_id, to_id)
    assert_not_zero(bool)
    return ()
end


##### Private functions #####
# Assert that the person calling has authority.
func only_arbiter{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    alloc_locals
    let (local caller) = get_caller_address()
    let (arbiter) = arbiter.read()
    assert caller = arbiter
    return ()
end
