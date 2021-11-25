%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import (HashBuiltin,
    SignatureBuiltin)
from starkware.cairo.common.math import assert_nn_le
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.signature import verify_ecdsa_signature

from contracts.utils.interfaces import IModuleController
from contracts.utils.general import list_to_hash

##### Module 08 #####
#
# This module provides a mechanism for users to engage in
# high-frequency interactions. Two users may open a channel
# for a short period, exchange moves, then close the channel.
#
####################

# Number of time-units (e.g., blocks or some other measure) a channel persists for.
const DURATION = 20
const CHALLENGE_TIMEOUT = 5

# An transaction to update the L2 state contains a 'move'.
struct Move:
    member target_id : felt
    member message_hash : felt
    member sig_r : felt
    member sig_s : felt
    member a : felt
end

# Stores the details of a channel tuples are: (user_a, user_b)
struct Channel:
    member index : felt
    member opened_at_block : felt
    member last_challenged_at_block : felt
    member latest_state_index : felt
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
        duration : felt,
        pub_key : felt
    ):
    # If a player signals availability but then is not available,
    # their opponent will win.

    # First update the active list
    update_active_signals()

    # Check conditions of compatibility
    # E.g., players must be in same area or have some similar trait.
    # Currently left as anyone-is-compatible.
    let queue_length = 8
    let (bool, match) = check_for_match(queue_length)



    open_channel()


    return ()
end


# Called by a user who intends to secure state on-chain.
@external
func manual_state_update{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        ecdsa_ptr: SignatureBuiltin*
    }(
        channel_index : felt,
        state_index : felt,
        sig_r : felt,
        sig_s : felt,
        message_len : felt,
        message : felt*
    ):
    alloc_locals
    # Channels progress state, but if one player disappears, the remaining
    # player can update the game state using this function.
    # State_index is the unique (incrementing) state identifier.
    let (local c : Channel) = channel_from_index.read(channel_index)
    # Check channel
    assert c.index = channel_index
    # Check state is not stale (latest state < provided state).
    assert_nn_le(c.latest_state_index + 1, state_index)
    # The players are stored as a tuple. Fetch which index the caller is.
    let (player_index) = get_player_index(c)
    # Signature check.
    is_valid_submission(c, player_index, message_len, message,
        sig_r, sig_s,)

    # Update the state.
    execute_final_outcome()

    return ()
end

# Called by a channel participant to close.
@external
func close_channel{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():

    execute_final_outcome()

    return ()
end


# Stores the details of the channel.
func open_channel{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():

    # Create channel

    # Remove channel participant matched from the waiting list

    # Update the waiting list
    update_active_signals()
    return ()
end

# Used to check which of the channel offers are still valid.
func update_active_signals{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    alloc_locals
    # Look at time measure (e.g., block height)

    # Iterate over all the active queued participants and assess if they
    # are still valid offers.
    let (index) = highest_queue_index.read()
    # Build up a queue by checking if players have been erased.
    local queue : felt*
    let (length) = append_queue_array(index, queue, 0)


    return ()
end

# Walks from the start to the end of the queue. If
func append_queue_array{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        n : felt,
        queue : felt*,
        free_index : felt
    ) -> (
        length : felt
    ):
    alloc_locals
    if n == 0:
        return (0)
    end
    let (length) = append_queue_array(n - 1, queue, free_index)
    # On first entry, n=1.
    let index = 0

    # TODO: Fetch the offer. Read the block number, determine
    # if the offer is valid. If the player is 0, also skip (they
    # are the one matched and have been removed).
    let (player) = player_from_queue_index.read(index)
    local exists : felt
    local expired : felt
    if player == 0:
        return (length)
    end
    # If the player.offer is expired, skip them.
    if expired == 1:
        return (length)
    end

    return (length + 1)
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

# Checks that
func is_valid_submission{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        ecdsa_ptr: SignatureBuiltin*
    }(
        c : Channel,
        player_index : felt,
        message_len : felt,
        message : felt*,
        sig_r : felt,
        sig_s : felt
    ):
    alloc_locals
    # Get the stored pubkey of the player.
    local public_key : felt
    if player_index == 0:
        assert public_key = c.game_pub_key[0]
    else:
        assert public_key = c.game_pub_key[1]
    end

    # Hash the message they signed.
    let (hash) = list_to_hash(message, message_len)
    # Verify the hash was signed by the pubk registered by the player.
    verify_ecdsa_signature(
        message=hash,
        public_key=public_key,
        signature_r=sig_r,
        signature_s=sig_s)
    return ()
end

func get_player_index{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        c : Channel
    ) -> (
        index : felt
    ):
    alloc_locals
    let (player) = get_caller_address()
    # Players are stored by index, use their address to get the index.
    local player_index : felt
    if c.addresses[0] == player:
        assert player_index = 0
    end
    if c.addresses[1] == player:
        player_index = 1
    end
    return (player_index)
end

# Returns the details of a matched player to open a channel with if found.
func check_for_match{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        queue_pos : felt
    ) -> (
        match_found_bool : felt,
        matched_player : felt
    ):
    # TODO implement checks and queue search.
    if queue_pos == 0:
        return (0, 0)
    end
    # Recursive loop.

    let (bool, match) = check_for_match(queue_pos - 1)
    # Upon first entry here, queue_pos=1.
    let index = queue_pos - 1


    let (bool, match) = check_for_match(index)
    let bool = 1
    return (bool, match)
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

