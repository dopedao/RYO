%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import (HashBuiltin,
    SignatureBuiltin)
from starkware.cairo.common.math import assert_nn_le, assert_not_zero
from starkware.cairo.common.math_cmp import is_nn_le
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
func queue_length() -> (value : felt):
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

# Records when an offer (to open a channel) will expire.
@storage_var
func offer_expires(player_address : felt) -> (value : felt):
end

# Records the public key a player wants to use for the channel.
@storage_var
func player_signing_key(player_account : felt) -> (signing_key : felt):
end

# Temporary workaround until blocks/time available.
@storage_var
func clock() -> (value : felt):
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
    alloc_locals
    # If a player signals availability but then is not available,
    # their opponent will win.
    let (local player) = get_caller_address()
    let (local time) = clock.read()
    let (queue_len) = queue_length.read()
    # If queue is not empty, look for a match.
    if queue_len != 0:

        # First update the active list
        update_active_signals(queue_len)

        # Is anyone in the queue compatible?
        let (success, matched_player) = check_for_match(queue_len)

        # If no match,
        if success != 0:
            jmp join_queue
        else:
            open_channel(player, matched_player)
            jmp dont_join_queue
        end
    else:
        jmp join_queue
    end

    join_queue:
    # Re-read the queue, some may have been removed.
    # Err ---> syscall_ptr was revoked.
    let (old_queue_length) = queue_length.read()
    queue_length.write(old_queue_length + 1)
    let free_index = old_queue_length

    player_from_queue_index.write(free_index, player)
    queue_index_of_player.write(player, free_index)


    dont_join_queue:


    register_new_account(pub_key)
    clock.write(time + 1)

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
    }(
        channel_id : felt
    ):
    only_channel_participant()
    only_closable_channel()
    execute_final_outcome()
    erase_channel(channel_id)
    return ()
end


# Stores the details of the channel.
func open_channel{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        player_from_tx : felt,
        player_from_queue : felt
    ):

    # Create channel

    # Remove channel participant matched from the waiting list

    # Update the waiting list
    erase_from_queue(player_from_queue)
    return ()
end

# Removes a player from the queue.
func erase_from_queue{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        player_address : felt
    ):

    player_from_queue_index()
    let (index) = queue_index_of_player.read(player_address)
    player_from_queue_index.write(index, 0)
    queue_index_of_player.write(player_address, 0)
    offer_expires.write(player_address, 0)
    let (length) = queue_length.read()
    queue_length.write(length - 1)
    return ()
end

# Removes all channel and player information.
func erase_channel{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        channel_index : felt
    ):
    alloc_locals
    let (local c : Channel) = channel_from_index.read(
        channel_index)

    # Get both player details.
    let player_a = c.addresses[0]
    let player_b = c.addresses[1]
    # Wipe channel details.
    channel_from_index.write(channel_index, 0)
    let (channels) = highest_channel_index.read()
    highest_channel_index.write(channels - 1)
    # Wipe both player details.
    player_signing_key.write(player_a, 0)
    player_signing_key.write(player_b, 0)
    return ()
end

# Used to check which of the channel offers are still valid.
func update_active_signals{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        time : felt
    ):
    alloc_locals
    let (queue_length) = queue_length.read()
    # Look at time measure (e.g., block height)
    let (time) = clock.read()
    # Build up a queue by checking if players have been erased.
    local queue : felt*
    # Build queue and record the new length.
    let (length) = build_queue(queue_length, queue, 0)
    queue_length.write(length)
    save_queue(length, queue)

    return ()
end

# Walks from the start to the end of the queue. If
func build_queue{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        n : felt,
        queue : felt*,
        time : felt
    ) -> (
        length : felt
    ):
    alloc_locals
    if n == 0:
        return (0)
    end
    let (length) = build_queue(n - 1, queue, time)
    # On first entry, n=1.
    let index = 0
    let (player) = player_from_queue_index.read(index)
    if player == 0:
        # If the player has been removed from the queue already.
        offer_expires.write(player, 0)
        queue_index_of_player.write(player, 0)
        return (length)
    end

    let (expiry) = offer_expires.read(player)
    let (expired) = is_nn_le(time, expiry)

    # This queue is possibly outdated, wipe the order.
    queue_index_of_player.write(player, 0)
    player_from_queue_index.write(index, 0)

    if expired == 1:
        # If the players offer is expired,
        # don't add them to the new_queue.
        offer_expires.write(player, 0)
        return (length)
    end

    # Add the player to the new queue
    assert queue[index] = player
    # Increment the length of this new queue.
    return (length + 1)
end

# Saves the order of the new queue.
func save_queue{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        player : felt,
        n : felt,
        queue : felt*
    ):
    alloc_locals
    if n == 0:
        return ()
    end
    save_queue(player, n - 1, queue)
    # On first entry, n=1.
    let index = 0
    queue_index_of_player.write(player, index)
    player_from_queue_index.write(index, player)
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

    # Remove all details about players.

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

# Ensures an account cannot be used twice simultaneously.
func register_new_account{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        pub_key : felt
    ):
    # Prevents a user opening a channel but then joining a queue
    # or another channel, which might result in wiped details.

    let (player) = get_caller_address()
    # A player always registers a non-zero key.
    assert_not_zero(pub_key)
    # Player must not have a registered key.
    let (registered_key) = player_signing_key.read(player)
    assert_not_zero(registered_key)
    # The player is registered.
    player_signing_key.write(player, pub_key)
    return ()
end


# Ensures a channel is not closed during a waiting period.
func only_closable_channel{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        channel : Channel
    ):
    # Checks when a channel is able to be closed by, based
    # on the challenge period.

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
