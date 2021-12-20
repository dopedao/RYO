%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import (HashBuiltin,
    SignatureBuiltin)
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import (assert_nn_le,
    assert_not_zero, assert_not_equal, abs_value)
from starkware.cairo.common.math_cmp import is_nn_le, is_not_zero
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

# Number of elements ineach struct. Used to parse message arrays to structs.
const LEN_ACHIEVEMENTS = 10
const LEN_REPORT = 10
const LEN_ACTION_HISTORY = 10
const LEN_ACTION = 3

# State transition rule constants.
const MAX_X = 9
const MAX_Y = 9
const DAMAGE_ZONE = 1  # Max distance where damage possible.
const DAMAGE = 1  # Collateral lost when hit.

# @notice Used to represent milestones co-signed by both players.
# @dev Not stored on chain. Used for convenience.
struct Achievements:
    member todo : felt
end

# @notice Used to manage the elements of a player's turn.
# @dev Part of a Move. The x/y are relative to current position.
# @param delta_* pixel movement in x/y plane player moves to.
# @param type Encoded punch/kick/duck/jump/shoot.
struct Action:
    member x : felt
    member y : felt
    member type : felt
end

# @notice Information stored on-chain about a channel.
# @dev User A is whoever sends the transaction that opens the channel.
# @param addresses Account addreses (user_a, user_b).
# @param balances Locked collateral (user_a, user_b).
struct Channel:
    member addresses : (felt, felt)
    member balance : (felt, felt)
    member id : felt
    member initial_channel_data : felt
    member last_challenged_at_block : felt
    member nonce : felt
    member opened_at_block : felt
    member state_hash : felt
end

# @notice Used to represent player summary co-signed by both players.
# @dev Not stored on chain. Used for convenience.
struct Report:
    member todo : felt
end

# @notice Used to represent the accumulated game state for the channel.
# @dev Part of a Move. Not stored in the contract.
# @param achievements_* are awards given for certain actions. Likely binary encoded.
# @param report_* are the report card parameters for each user (e.g., agility points/100).
# @param action_history is an array of actions. Used for state transitions and to award achievements. [a_latest_action, b_latest_action, a_2nd_last, b_2nd_last, ... b_last]
struct GameHistory:
    member achievements_A : Achievements
    member achievements_B : Achievements
    member report_A : Report
    member report_B : Report
    member action_history : Action*
end

# @notice The packet of data signed by a player. Can be submitted to L2.
# @dev Used to manage player challenges, not stored on chain.
# @param commit The hash of the action for the current turn (concealed).
# @param history The accumulated agreed upon game outcomes.
# @param hash The hash of the message that sig_r/sig_s refer to.
# @param parent_hash The hash of the parent message (signed by opponent).
# @param player_index The index of the player in the channel (0 or 1).
# @param reveal The actions commited to (nonce - 2) by the same player.
# @param sig_r/sig_s Signature attesting to the hash.
struct Move:
    member channel_id : felt
    member commit : felt
    member history : GameHistory
    member hash : felt
    member nonce : felt
    member parent_hash : felt
    member player_index : felt
    member reveal : Action
    member sig_r : felt
    member sig_s : felt
end




# Channel details.
@storage_var
func channel_from_id(id) -> (result : Channel):
end

# Records the channel index for a given player.
@storage_var
func channel_of_player(player_account : felt) -> (channel_id : felt):
end

# Temporary workaround until blocks/time available.
@storage_var
func clock() -> (value : felt):
end

# The address of the ModuleController.
@storage_var
func controller_address() -> (address : felt):
end

# Increments with every new channel.
@storage_var
func highest_channel_id() -> (value : felt):
end

# Records when an offer (to open a channel) will expire.
@storage_var
func offer_expires(player_address : felt) -> (value : felt):
end

# Gets the account address of a player by index.
@storage_var
func player_from_queue_index(index) -> (address : felt):
end

# Records the public key a player wants to use for the channel.
@storage_var
func player_signing_key(player_account : felt) -> (signing_key : felt):
end

# Records array of users who are available.
@storage_var
func queue_index_of_player(address) -> (index : felt):
end

# Number of people waiting to open channels.
@storage_var
func queue_length() -> (value : felt):
end

# @notice Called on deployment only.
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


# @notice Called by a player who wishes to engage in channel interaction.
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
    let (local clock_now) = clock.read()
    let (queue_len) = queue_length.read()

    if queue_len != 0:
        # If queue is not empty, look for a match.

        # First update the active list
        update_active_signals(player, clock_now, queue_len)

        # Is anyone in the queue compatible?
        let (success, matched_player) = check_for_match(queue_len)
        if success != 0:
            # If match.
            open_channel(player, matched_player, clock_now)
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
            jmp dont_join_queue
        else:
            # If no match.
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
            jmp join_queue
        end
    else:
        # If queue is empty, join queue.
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
        jmp join_queue
    end

    join_queue:
    # Re-read the queue, some may have been removed.
    let (old_queue_length) = queue_length.read()
    queue_length.write(old_queue_length + 1)
    let free_index = old_queue_length

    player_from_queue_index.write(free_index, player)
    queue_index_of_player.write(player, free_index)

    dont_join_queue:

    register_new_account(pub_key)
    clock.write(clock_now + 1)

    return ()
end



# @notice Called by a user who intends to secure state on-chain.
# @dev Anyone with the signed message can submit the move.
@external
func manual_state_update{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        ecdsa_ptr: SignatureBuiltin*
    }(
        move_len : felt,
        move : felt*,
        hash : felt,
        sig_r : felt,
        sig_s : felt
    ):
    alloc_locals
    let (local m : Move) = array_to_move_struct(move, hash, sig_r, sig_s)
    # Signature check.
    is_valid_move_signature(m)
    # Channels progress state, but if one player disappears, the remaining
    # player can update the game state using this function.
    # state_nonce is the unique (incrementing) state identifier.
    let (c : Channel) = channel_from_id.read(m.channel_id)
    # Check state is not stale (latest state < provided state).
    assert_nn_le(c.nonce + 1, m.nonce)

    # Update the state.
    save_state_transition(c, m)

    return ()
end



# @notice A signed bad message can be submitted here to punish the signer. Stops players from breaking the chain of moves.
# @dev Checks the signed message has a bad parent hash.
# @param bad_move The message that contains a non-parent hash.
# @param parent_move The parent message.
@external
func submit_bad_parent{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        ecdsa_ptr: SignatureBuiltin*
    }(
        bad_move_len : felt,
        bad_move : felt*,
        bad_move_hash : felt,
        bad_move_sig_r : felt,
        bad_move_sig_s : felt,
        parent_move_len : felt,
        parent_move : felt*,
        parent_move_hash : felt,
        parent_move_sig_r : felt,
        parent_move_sig_s : felt
    ):
    alloc_locals
    let (local m : Move, local parent_m : Move) = parse_moves(
        bad_move_len, bad_move, bad_move_hash,
        bad_move_sig_r, bad_move_sig_s,
        parent_move_len, parent_move, parent_move_hash,
        parent_move_sig_r, parent_move_sig_s)

    # Enforces that the hash is different from the parent hash
    assert m.parent_hash = parent_m.hash

    # Apply a penalty to the offending party and close the channel.
    apply_penalty(m)
    close_channel(m)
    return ()
end


# @notice A signed bad message can be submitted here to punish the signer. Stops players from revealing a move they did not commit to.
# @dev Checks the hash of the reveal doesn't match the commithash.
# @param bad_move The message that contains a non-parent hash.
# @param parent_move The parent message.
@external
func submit_bad_reveal{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        ecdsa_ptr: SignatureBuiltin*
    }(
        bad_move_len : felt,
        bad_move : felt*,
        bad_move_hash : felt,
        bad_move_sig_r : felt,
        bad_move_sig_s : felt,
        parent_move_len : felt,
        parent_move : felt*,
        parent_move_hash : felt,
        parent_move_sig_r : felt,
        parent_move_sig_s : felt
    ):
    alloc_locals
    let (local m : Move, local parent_m : Move) = parse_moves(
        bad_move_len, bad_move, bad_move_hash,
        bad_move_sig_r, bad_move_sig_s,
        parent_move_len, parent_move, parent_move_hash,
        parent_move_sig_r, parent_move_sig_s)

    # Compute the hash chain of the reveal.
    # Hash the members of the moves' reaveal, last to first.
    # E.g., h(a, h(b, c))
    let (h1) = hash2{hash_ptr=pedersen_ptr}(m.reveal.y, m.reveal.type)
    let (h2) = hash2{hash_ptr=pedersen_ptr}(m.reveal.x, h1)
    # Check that the reveal hash is not equal to the commit hash.
    assert_not_equal(parent_m.commit, h2)
    # Apply a penalty to the offending party and close the channel.
    apply_penalty(m)
    close_channel(m)
    return ()
end


# @notice A signed state that violates the game rules can be submitted. Stops players from cheating the game rules.
# @dev Executes a single state transition from a move and compares result.
# @param bad_move The message that contains a non-parent hash.
# @param parent_move The parent message.
@external
func submit_bad_state{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        ecdsa_ptr: SignatureBuiltin*
    }(
        bad_move_len : felt,
        bad_move : felt*,
        bad_move_hash : felt,
        bad_move_sig_r : felt,
        bad_move_sig_s : felt,
        parent_move_len : felt,
        parent_move : felt*,
        parent_move_hash : felt,
        parent_move_sig_r : felt,
        parent_move_sig_s : felt
    ):
        alloc_locals
    let (local m : Move, local parent_m : Move) = parse_moves(
        bad_move_len, bad_move, bad_move_hash,
        bad_move_sig_r, bad_move_sig_s,
        parent_move_len, parent_move, parent_move_hash,
        parent_move_sig_r, parent_move_sig_s)

    # Checks the new state from the revealed move and the parent state.
    let (is_valid_bool) = check_state_transition(parent_m, m)
    # Require that the transition was incorrect.
    assert is_valid_bool = 0
    # Apply a penalty to the offending party and close the channel.
    apply_penalty(m)
    close_channel(m)
    return ()
end

# @notice Submit the final move of the channel to close the channel.
# @dev Check the move and ensure the nonce is the end-nonce.
# @param move The final move.
@external
func cooperative_close{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        ecdsa_ptr: SignatureBuiltin*
    }(
        move_len : felt,
        move : felt*,
        hash : felt,
        sig_r : felt,
        sig_s : felt
    ):
        alloc_locals
    let (local m : Move) = array_to_move_struct(move, hash, sig_r, sig_s)
    # The DURATION of the channel should be equal to the nonce.
    assert DURATION = m.nonce
    # Signature check.
    is_valid_move_signature(m)
    # Close.
    close_channel(m)
    return ()
end


# @notice Called by a channel participant to close.
# @dev Only callable for channels undergoing a waiting period.
func close_channel{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        m : Move
    ):
    alloc_locals
    let (local c : Channel) = channel_from_id.read(m.channel_id)
    only_channel_participant(c, m)
    distribute_to_players(c, m)
    erase_channel(c)
    return ()
end


# @notice Applies state transition rules (e.g., to detect an illegal move).
# @dev Detects if signed reveal violates state transition.
# @param m_parent The parent move.
# @param m The signed move to modify state.
func check_state_transition{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        m_parent : Move,
        m : Move
    ) -> (
        is_valid_bool : felt
    ):
    alloc_locals
    # TBD: Does the state transition truly need to be implemented here
    # in the contract? It seems so. Uses:
    # - If a player signs a bad transition, the other player needs to be
    # able to punish them. If they ignore the bad message, then they are
    # themselves vulnerable to an inactivity punishment.


    # History structure:
    # [a, b, a-1, b-1, a-2, b-2, ...,]
    # The state must be sequential.
    assert m.nonce = m_parent.nonce + 1
    # State to apply transition to.
    let prior : Action = m_parent.history.action_history[0]
    # New state that was signed by the player.
    let proposed : Action = m.reveal

    # The reveal is used to transition state.
    # These are the game rules, intended to be very basic as POC.
    # Movement is within range.
    let (x_dist) = abs_value(prior.x - proposed.x)
    let (local x_ok) = is_nn_le(x_dist, MAX_X)
    let (y_dist) = abs_value(prior.y - proposed.y)
    let (local y_ok) = is_nn_le(y_dist, MAX_Y)

    # Detect if hit:
    # - Within range.
    # - Attack hits opponents position.
    # - Damage sustained is correct.
    # - Allocated balances are correctly adjusted.

    # Apply any achievements,
    # - Examine moves in the context of recent history:
    # - If this is a third consecutive hit without a miss, record triple_combo=1.
    # - If no damage sustained yet, set damage_free=0.
    # - ...

    # Adjust live report card:
    # - If hit the opponent, increase 'accuracy' metric.
    # - ...

    # Can also check that the stored history matches.
    let new_stored : Action = m.history.action_history[0]
    let old_stored : Action = m_parent.reveal
    assert new_stored = old_stored

    # If any conditions are not ok (they equal 0), then this will be 0 too.
    let is_valid_bool = x_ok * y_ok

    return (is_valid_bool)
end


# @notice Frontend calls to see if user has channel opened.
@view
func status_of_player{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        player_address : felt
    ) -> (
        game_key : felt,
        index_in_queue : felt,
        queue_len : felt,
        channel_details : Channel
    ):
    alloc_locals
    # Upon submitting to join the queue, players should ping this
    # function to see if they are queued or matched.
    # Could be replaced by listening to an Event when technically feasible.

    let (game_key) = player_signing_key.read(player_address)
    let (index_in_queue) = queue_index_of_player.read(player_address)
    let (queue_len) = queue_length.read()
    let (channel_id) = channel_of_player.read(player_address)
    let (local channel : Channel) = channel_from_id.read(channel_id)

    # To interprete these values:
    # If game_key is 0, player is not registered for queue or channel.
    # If channel_details is zero, the position_in_queue informs queue index.
    # If channel_details not zero, the channel is live.
    return (
        game_key,
        index_in_queue,
        queue_len,
        channel)
end

# @notice Fetch queue length
@view
func read_queue_length{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (
        length : felt,
        player_at_index_0 : felt
    ):
    let (length) = queue_length.read()
    let (zeroth_queuer) = player_from_queue_index.read(0)
    return (length, zeroth_queuer)
end



# Stores the details of the channel.
func open_channel{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        player_from_tx : felt,
        player_from_queue : felt,
        clock : felt
    ):
    alloc_locals
    # Cannot open channel with self.
    assert_not_equal(player_from_tx, player_from_queue)
    let (current_index) = highest_channel_id.read()
    # Create channel
    let channel_id = current_index + 1
    local c : Channel
    assert c.id = channel_id
    assert c.opened_at_block = clock
    assert c.last_challenged_at_block = clock
    assert c.nonce = 0
    assert c.addresses[0] = player_from_tx
    assert c.addresses[1] = player_from_queue
    # Collateral, fake 100 units for now.
    assert c.balance[0] = 100
    assert c.balance[1] = 100
    assert c.initial_channel_data = 987654321
    assert c.state_hash = 123456789


    channel_from_id.write(channel_id, c)
    highest_channel_id.write(channel_id)
    channel_of_player.write(player_from_tx, channel_id)
    channel_of_player.write(player_from_queue, channel_id)
    # Update the waiting list
    erase_from_queue(player_from_queue)
    return ()
end


# @notice Removes a player from the queue.
func erase_from_queue{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        player_address : felt
    ):

    let (index) = queue_index_of_player.read(player_address)
    player_from_queue_index.write(index, 0)
    queue_index_of_player.write(player_address, 0)
    offer_expires.write(player_address, 0)
    let (length) = queue_length.read()
    queue_length.write(length - 1)
    return ()
end

# @notice Removes all channel and player information.
func erase_channel{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        c : Channel
    ):
    alloc_locals

    # Get both player details.
    let player_a = c.addresses[0]
    let player_b = c.addresses[1]
    # Wipe channel details.
    local null_channel : Channel
    channel_from_id.write(c.id, null_channel)
    let (channels) = highest_channel_id.read()
    highest_channel_id.write(channels - 1)
    # Wipe both player details.
    channel_of_player.write(player_a, 0)
    channel_of_player.write(player_b, 0)
    player_signing_key.write(player_a, 0)
    player_signing_key.write(player_b, 0)
    return ()
end

# @notice Used to check which of the channel offers are still valid.
func update_active_signals{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        player : felt,
        clock_now : felt,
        original_queue_length : felt
    ):
    alloc_locals
    # Build up a queue by checking if players have been erased.

    let (local queue : felt*) = alloc()
    # Build queue and record the new length.
    let (length) = build_queue(original_queue_length, queue, clock_now)
    queue_length.write(length)
    save_queue(length, queue)

    return ()
end

# @notice Walks from the start to the end of the queue.
func build_queue{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        n : felt,
        queue : felt*,
        clock_now : felt
    ) -> (
        length : felt
    ):
    alloc_locals
    if n == 0:
        return (0)
    end
    let (length) = build_queue(n - 1, queue, clock_now)
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
    let (expired) = is_nn_le(clock_now, expiry)

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

# @notice Saves the order of the new queue.
func save_queue{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        n : felt,
        queue : felt*
    ):
    alloc_locals
    if n == 0:
        return ()
    end
    save_queue(n - 1, queue)
    # On first entry, n=1.
    let index = 0
    queue_index_of_player.write(queue[index], index)
    player_from_queue_index.write(index, queue[index])
    return ()
end

# @notice This applies the final outcome of a state channel.
# @dev Used once, when no further challenges are permitted.
# @param c Channel details, sourced from on-chain state.
# @param m Move, submitted by player as tx data.
func distribute_to_players{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        c : Channel,
        m : Move
    ):

    # Assert that the move submitted is confirmed already
    # c.state_hash == m.hash

    # Divide and send collateral to players as appropriate.

    # Mint report cards. E.g.,
    # - I10_ReportCard.mint(c.player[0], m.report_A)
    # - I10_ReportCard.mint(c.player[1], m.report_B)

    # Administer achievement artifacts. Eg.,
    # - Mint artifact as trophy for each triple-combo.
    # - Ixx_ArtifactMaker.mint(c.player[0], m.achievements)
    # - Ixx_ArtifactMaker.mint(c.player[1], m.achievements)

    return ()
end

# @notice Updates on-chain channel information. E.g., Player submits tx.
# @dev Records the latest state and challenge data of a channel.
func save_state_transition{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        c : Channel,
        m : Move
    ):
    # Update the on-chain channel to the latest confirmed state.
    assert c.nonce = m.nonce
    assert c.state_hash = m.hash
    # Save new state
    channel_from_id.write(c.id, c)
    return ()
end




# @notice Checks that a signed move is valid with respect to a channel and public key.
func is_valid_move_signature{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        ecdsa_ptr: SignatureBuiltin*
    }(
        m : Move
    ):
    alloc_locals
    let (c : Channel) = channel_from_id.read(m.channel_id)
    # Retrieve the public key from the chain.
    # Hack: "Subscript-operator for tuples supports only constant offsets, found 'ExprDeref'." Would have otherwise used: c.addresses[index]
    local public_key : felt
    if m.player_index == 0:
        let (pk) = player_signing_key.read(c.addresses[0])
        assert public_key = pk
    else:
        let (pk) = player_signing_key.read(c.addresses[1])
        assert public_key = pk
    end
    # Verify the hash was signed by the pubk registered by the player.
    verify_ecdsa_signature(
        message=m.hash,
        public_key=public_key,
        signature_r=m.sig_r,
        signature_s=m.sig_s)
    return ()
end

# @notice Ensures the hash supplied/signed is correctly computed.
# @dev The order of the array elements is defined in
func is_valid_hash{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        move_array_len : felt,
        move_array : felt*,
        supplied_hash : felt
    ):
    # All the Move elements are hashed alphabetically by Move struct name.
    # Omitted: hash, sig_r, sig_s (the hash cannot be self referential).
    let (hash) = list_to_hash(move_array, move_array_len)
    assert supplied_hash = hash
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
    alloc_locals
    if queue_pos == 0:
        return (0, 0)
    end
    # Recursive loop.

    let (bool, match) = check_for_match(queue_pos - 1)
    # Upon first entry here, queue_pos=1.
    let index = queue_pos - 1

    let (candidate) = player_from_queue_index.read(index)
    assert_not_zero(candidate)
    local matched_player : felt
    local bool_result : felt
    if bool != 1:
        # If no match found yet, look for one.
        # If suitable (currently everyone is suitable), save.
        assert matched_player = candidate
        # let (ok) = apply_check_to_selected_player(matched_player)
        let ok = 1
        assert bool_result = ok
    else:
        # If match already found
        assert matched_player = match
        assert bool_result = 1
    end
    return (bool_result, matched_player)
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
    assert registered_key = 0
    # The player is registered.
    player_signing_key.write(player, pub_key)
    return ()
end

# @notice Helper function for commonly used checks on submitted moves.
# @dev Comutes and verifies hash, parses to struct, checks signature.
func parse_moves{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        ecdsa_ptr: SignatureBuiltin*
    }(
        bad_move_len : felt,
        bad_move : felt*,
        bad_move_hash : felt,
        bad_move_sig_r : felt,
        bad_move_sig_s : felt,
        parent_move_len : felt,
        parent_move : felt*,
        parent_move_hash : felt,
        parent_move_sig_r : felt,
        parent_move_sig_s : felt
    ) -> (
        m : Move,
        parent_move : Move
    ):
    alloc_locals
    is_valid_hash(bad_move_len, bad_move, bad_move_hash)
    is_valid_hash(parent_move_len, parent_move, parent_move_hash)
    # Unpack the arrays as structs for easier manipulation
    let (local m : Move) = array_to_move_struct(bad_move,
        bad_move_hash, bad_move_sig_r, bad_move_sig_s)
    let (local parent_m : Move) = array_to_move_struct(parent_move,
        parent_move_hash, parent_move_sig_r, parent_move_sig_s)
    # Both must be signed correctly
    is_valid_move_signature(m)
    is_valid_move_signature(parent_m)

    return (m, parent_m)
end

# @notice Helper function to convert move-array to Move-struct.
# @dev Defines hash sequence. Allows Inputs and Move struct to change over time more easily.
# @param a The array containing ordered elements to populate struct.
func array_to_move_struct{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        a : felt*,
        hash : felt,
        sig_r : felt,
        sig_s : felt
    ) -> (
        m : Move
    ):
    alloc_locals
    # Dummy values. Needs to incorporate nested struct once actual
    # channel data format is worked out (e.g., game elements/awards/actions).
    # Create empty structs to populate.
    let (local actions : Action*) = alloc()
    local game : GameHistory
    local m : Move

    # Action history index, representing where the first element is.
    let ah = 23  # Dummy value
    # Everything comes from the array. E.g.,
    assert actions[0] = Action(1, 1, 1) # Action(a[ah + 0], a[ah + 2], a[ah + 3]),
    assert actions[1] = Action(1, 1, 1) # Action(a[ah + 4], a[ah + 5], a[ah + 6]),
    assert actions[2] = Action(1, 1, 1)
    assert actions[3] = Action(1, 1, 1)
    assert actions[4] = Action(1, 1, 1)
    assert actions[5] = Action(1, 1, 1)
    assert actions[6] = Action(1, 1, 1)
    assert actions[7] = Action(1, 1, 1)
    assert actions[8] = Action(1, 1, 1)
    assert actions[9] = Action(1, 1, 1)

    local gh : GameHistory
    assert gh = GameHistory(
        achievements_A=Achievements(todo=0),
        achievements_B=Achievements(todo=0),
        report_A=Report(todo=0),
        report_B=Report(todo=0),
        action_history=actions
    )

    let action : Action = Action(1, 1, 1)
    # A message is passed to the contract as an array.
    # The length of the achievements/reports/movehistory elements
    # affect the parsing of the array. These lengths are recorded
    # as constants at the top of this page.
    # LEN_ACHIEVEMENTS, LEN_REPORT, LEN_ACTION_HISTORY, LEN_ACTION
    let game_history_len = ((1 + LEN_ACHIEVEMENTS) * 2 +
        LEN_REPORT * 2 + 1 + LEN_ACTION_HISTORY * LEN_ACTION)
    # [id, commit, history, hash, nonce, ...]
    let nonce_pos = 2 + game_history_len + 1
    let reveal_pos = nonce_pos + 2
    assert m = Move(
        channel_id=a[0],
        commit=a[1],
        history=gh,
        hash=hash,
        nonce=a[nonce_pos],
        parent_hash=a[nonce_pos + 1],
        player_index=a[nonce_pos + 2],
        reveal=action,
        sig_r=sig_r,
        sig_s=sig_s
    )
    return (m)
end


# @notice Applies a penalty to one party in favour of the other.
# @dev Moves allocated capital in stored channel. Usually followed by channel close.
# @param player_index The in-channel index of the offending player.
func apply_penalty{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        m : Move
    ):
    alloc_locals
    let (local c : Channel) = channel_from_id.read(m.channel_id)
    # Player looses all of their collateral. This could be modified
    # to burn some of it, or distribute it differently.
    if m.player_index == 0:
        assert c.balance[0] = 0
        assert c.balance[1] = c.balance[1] + c.balance[0]
    else:
        assert c.balance[1] = 0
        assert c.balance[0] = c.balance[0] + c.balance[1]
    end
    assert c.balance[0] * c.balance[1] = 0
    channel_from_id.write(m.channel_id, c)
    return ()
end

# @notice Ensures only channel participant can call this function.
# @dev Prevents non-channel participants closing a channel.
func only_channel_participant{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        c : Channel,
        m : Move
    ):
    # Checks which account originating address
    let (player) = get_caller_address()
    # Hack: Subscript-operator for tuples supports only constant offsets, found 'ExprDeref'.
    # assert player = c.addresses[m.player_index]
    let stored_player_0 = c.addresses[0]
    let stored_player_1 = c.addresses[1]

    let zero_if_is_0 = player - stored_player_0
    let zero_if_is_1 = player - stored_player_1

    let zero_if_1_or_0 = zero_if_is_0 * zero_if_is_1
    # The calling address must be must be one of the stored accounts.
    assert zero_if_1_or_0 = 0

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

