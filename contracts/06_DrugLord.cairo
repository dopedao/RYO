%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

from contracts.utils.interfaces import IModuleController
from contracts.utils.game_structs import UserData

##### Module 06 #####
#
# This module stores state for the Combat module.
#
#
####################


# Returns the user_id who is currently the drug lord in that location.
@storage_var
func drug_lord(location_id : felt) -> (user_id : felt):
end

# Returns the hash of the stats of the drug lord in that location.
@storage_var
func drug_lord_stat_hash(location_id : felt) -> (stat_hash : felt):
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


# Access variable.
func drug_lord_read{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        location_id : felt
    ) -> (
        user_id : felt
    ):
    let (user_id) = drug_lord.read(location_id)
    return (user_id)
end

# Modify variable.
func drug_lord_write{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        location_id : felt,
        user_id : felt
    ):
    only_approved()
    drug_lord.write(location_id, user_id)
    return ()
end


# Access variable.
func drug_lord_stat_hash_read{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        location_id : felt
    ) -> (
        stat_hash : felt
    ):
    let (stat_hash) = drug_lord.read(location_id)
    return (stat_hash)
end

# Modify variable.
func drug_lord_stat_hash_write{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        location_id : felt,
        stat_hash : felt
    ):
    only_approved()
    drug_lord.write(location_id, stat_hash)
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