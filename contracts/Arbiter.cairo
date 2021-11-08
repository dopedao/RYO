%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.starknet.common.syscalls import get_caller_address

from contracts.utils.interfaces import IModuleController

##### Arbiter #####
#
# Is the authority over the ModuleController.
# Responsible for deciding how the controller administers authority.
# Can be replaced by a vote-based module by calling the
# appoint_new_arbiter() in the ModuleController.
# Has an Owner, that may itself be a multisig account contract.
#
###################

@storage_var
func owner_of_arbiter() -> (owner : felt):
end

@storage_var
func controller_address() -> (address : felt):
end

@storage_var
func lock() -> (bool : felt):
end

@constructor
func constructor():
    return()
end

# Locks the stored addresses.
@external
func lock_addresses{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    only_owner()
    lock.write(1)
    return()
end


# Called to approve a deployed module for a numerical purpose.
@external
func set_address_of_controller{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        contract_address : felt
    ):
    let (locked) = lock.read()
    assert_not_zero(locked)
    only_owner()

    controller_address.write(contract_address)
    return ()
end

# Called to replace the contract that controls the Arbiter.
@external
func replace_self{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        new_arbiter_address : felt
    ):
    only_owner()
    let (controller) = controller_address.read()
    # The ModuleController has a fixed address. The Arbiter
    # may be upgraded by calling the ModuleController and declaring
    # the new Arbiter.
    IModuleController.appoint_new_arbiter(
        contract_address=controller, new_arbiter=new_arbiter_address)
    return ()
end

@external
func appoint_new_owner{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        new_owner_address : felt
    ):
    only_owner()
    owner_of_arbiter.write(new_owner_address)
    return ()
end

# Called to approve a deployed module as identified by an ID.
@external
func appoint_contract_as_module{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        module_address : felt,
        module_id : felt
    ):
    only_owner()
    let (controller) = controller_address.read()
    # Call the ModuleController and enable the new address.
    IModuleController.set_address_for_module_id(
        contract_address=controller,
        module_id=module_id,
        module_address=module_address)
    return ()
end

# Called to authorise write access of one module to another.
@external
func approve_module_to_module_write_access{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        module_id_doing_writing : felt,
        module_id_being_written_to : felt
    ):
    only_owner()
    let (controller) = controller_address.read()
    IModuleController.set_write_access(contract_address=controller,
        module_id_doing_writing=module_id_doing_writing,
        module_id_being_written_to=module_id_being_written_to)
    return()
end

# Assert that the person calling has authority.
func only_owner{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    alloc_locals
    let (local caller) = get_caller_address()
    let (owner) = owner_of_arbiter.read()
    assert caller = owner
    return ()
end
