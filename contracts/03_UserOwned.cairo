%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

from contracts.utils.interfaces import IModuleController

##### Module XX #####
#
# This module ...
#
#
####################

# Specify user, item, return quantity.
@storage_var
func user_has_item(
        user_id : felt,
        item_id : felt
    ) -> (
        count : felt
    ):
end

# Location of users. Input user, retrieve city.
@storage_var
func user_in_location(
        user_id : felt
    ) -> (
        location_id : felt
    ):
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


# Called by another module to update a global variable.
func user_has_item_write{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        user_id : felt,
        item_id : felt,
        value : felt
    ):
    only_approved()
    user_has_item.write(user_id, item_id, value)
    return ()
end

func user_has_item_read{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        user_id : felt,
        item_id : felt
    ) -> (
        value : felt
    ):
    let (value) = user_has_item.read(user_id, item_id)
    return (value)
end


# Called by another module to update a global variable.
func user_in_location_write{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        user_id : felt,
        location_id : felt
    ):
    only_approved()
    user_in_location.write(user_id, location_id)
    return ()
end

func user_in_location_read{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        user_id : felt
    ) -> (
        location_id : felt
    ):
    let (location_id) = user_in_location.read(user_id)
    return (location_id)
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


