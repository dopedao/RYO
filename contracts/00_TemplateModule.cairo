%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

# Stores TODO
@storage_var
func TODO(
    ) -> (
        value : felt
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
        controller_address : felt
    ):
    # Store the address of the only fixed contract in the system.
    controller_address.write(controller_address)
    return ()
end


# Called by another module to update a global variable.
func update_value():
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
    let (controller_address) = controller_address.read()
    # Pass this address on to the ModuleController.
    # "Does this address have write-authority here?"
    # Will revert the transaction if not.
    IModuleController.has_write_access(contract_address=controller,
        address_attempting_to_write=caller)
    return ()
end


