
%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.starknet.common.syscalls import get_caller_address

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
# Stores the address of the Arbiter contract.
@storage_var
func arbiter() -> (address : felt):
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

##### Constructor #####
@constructor
func constructor{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        arbiter_address : felt,
        module_1 : felt,
        module_2 : felt
    ):
    arbiter.write(arbiter_address)
    # Store the address of already deployed modules.
    address_of_module_id.write(1, module_1)
    module_id_of_address.write(module_1, 1)

    address_of_module_id.write(2, module_2)
    module_id_of_address.write(module_2, 2)
    return ()
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
    }(
        module_id : felt,
        module_address : felt
    ):
    only_arbiter()
    module_id_of_address.write(module_id, module_address)
    address_of_module_id.write(module_address, module_id)

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
        address_attempting_to_write : felt,
    ):
    alloc_locals
    # Approves the write-permissions between two modules, ensuring
    # first that the modules are both active (not replaced), and
    # then that write-access has been given.

    # Get the address of the module calling (being written to).
    let (caller) = get_caller_address()
    let (module_id_being_written_to) = module_id_of_address.read(caller)

    # Make sure the module has not been replaced.
    let (local current_module_address) = address_of_module_id.read(
        module_id_being_written_to)
    assert current_module_address = caller

    # Get the module id of the contract that is trying to write.
    let (module_id_attempting_to_write) = module_id_of_address.read(
        address_attempting_to_write)
    # Make sure that module has not been replaced.
    let (local active_address) = address_of_module_id.read(
        module_id_attempting_to_write)
    assert active_address = address_attempting_to_write

    # See if the address is
    let (bool) = can_write_to.read(
        module_id_attempting_to_write,
        module_id_being_written_to)
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
    let (current_arbiter) = arbiter.read()
    assert caller = current_arbiter
    return ()
end
