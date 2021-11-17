%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

from contracts.utils.interfaces import IModuleController

##### Module XX #####
#
# This module [module functional description]
#
# It predominantly is used by modules [] and uses modules [].
#
####################

# Steps - Copy and modify this template contract for new modules.
# 1. Assign the new module the next available number in the contracts/ folder.
# 2. Ensure state variables and application logic are in different modules.
# 3. Expose any modifiable state variables with helper functions 'var_x_write()'.
# 4. Import any module dependencies from utils.interfaces (above).
# 5. Document which modules this module will interact with (above).
# 6. Add deployment line to bin/compile bin/deploy.
# 7. Document which modules this module requires write access to.
# 8. Write tests in testing/XX_test.py and add to bin/test.
# 9. +/- Add useful interfaces for this module to utils/interfaces.cairo.
# 10. Delete this set of instructions.

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
@external
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