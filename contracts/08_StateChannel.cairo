%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

from contracts.utils.interfaces import IModuleController

##### Module 08 #####
#
# This module provides a mechanism for users to engage in
# high-frequency interactions. Two users may open a channel
# for a short period, exchange moves, then close the channel.
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

# Number of time-units (e.g., blocks or some other measure) a channel persists for.
const DURATION = 20
const CHALLENGE_TIMEOUT = 5

# Stores the details of a channel tuples are: (user_a, user_b)
struct Channel:
    member index : felt
    member opened_at_block : felt
    member last_challenged_at_block : felt
    member latest_state_update_index : felt
    member addresses : (felt, felt)
    member game_pub_key : (felt, felt)
    member balance : (felt, felt)
    member initial_channel_data : felt
    member initial_state_hash : felt
end

# The address of the ModuleController.
@storage_var
func controller_address() -> (address : felt):
end

# Number of people waiting to open channels.
@storage_var
func highest_queue_index() -> (count : felt):
end

# Records array of users who are available.
@storage_var
func queue_index_of_player(address) -> (index : felt):
end

# Gets the account address of a player by index.
@storage_var
func player_from_queue_index(index) -> (address : felt):
end

# Channel details.
@storage_var
func channel_from_index(index) -> (result : Channel):
end

# Increments with every new channel.
@storage_var
func highest_channel_index() -> (value : felt):
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


# Called by a player who wishes to engage in channel interaction.
@external
func signal_available{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        duration : felt
    ):
    # If a player signals availability but then is not available,
    # their opponent will win.

    # First update the active list
    update_active_signals()

    # Check conditions of compatibility
    # E.g., players must be in same area or have some similar trait.
    # Currently left as anyone-is-compatible.
    open_channel()

    return ()
end


# Called by a user whose opponent has disappeared
@external
func manual_state_update{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    # Channels progress state, but if one player disappears, the remaining
    # player can update the game state.

    execute_final_outcome()

    return ()
end

# Called by a channel participant to close.
@external
func close_channel{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }

    execute_final_outcome()

    return ()
end


# Stores the details of the channel.
func open_channel{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():

    return ()
end

# Used to check which of the channel offers are still valid.
func update_active_signals{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():

    # Look at time measure (e.g., block height)

    # Iterate over all the active queued participants and assess if they
    # are still valid offers.

    return ()
end

# Saves the result of the whole channel interaction to L2.
func execute_final_outcome{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():

    # Check permissions

    # Process the submitted data

    # Evaluate channel logic to detect if this message is consistent with the
    # general rules of channels, including whether this overrides a previous claim
    # about this same channel.

    # Store the data

    return ()
end

# Actions a state update.
func save_state_transition{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    # Called when the game is progressed for some reason.

    # Increment 'Channel.latest_state_update_index'

    # Save new state

    return ()
end

# Ensures a signed message contains the necessary authority.
func only_channel_participant{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    # Checks originating address and signatures of signed
    # channel message.
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