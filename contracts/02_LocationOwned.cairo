%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

# Returns item count for item-money pair in location.
# E.g., first location (location_id=0), first item (item_id=1)
@storage_var
func location_has_item(
        location_id : felt,
        item_id : felt
    ) -> (
        count : felt
    ):
end

# Returns money count for item-money pair in location.
# E.g., first location (location_id=0), first item (item_id=1)
@storage_var
func location_has_money(
        location_id : felt,
        item_id : felt
    ) -> (
        count : felt
    ):
end

@storage_var
func controller_address() -> (address : felt):
end


@contract_interface
namespace IModuleController:
    func has_write_access(address_attempting_to_write : felt):
    end
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
func update_value{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    # TODO Customise.
    only_approved()
    return ()
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


