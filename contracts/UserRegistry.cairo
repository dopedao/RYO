%lang starknet
%builtins pedersen range_check bitwise

from starkware.cairo.common.cairo_builtins import (HashBuiltin,
    BitwiseBuiltin)
from starkware.starknet.common.storage import Storage

@storage_var
func user_data(
        user_id : felt
    ) -> (
        data : felt
    ):
end

@storage_var
func user_pubkey(
        user_id : felt
    ) -> (
        pubkey : felt
    ):
end

@storage_var
func available_id(
    ) -> (
        res : felt
    ):
end

# Returns the L2 public key and game-related player data for a user.
@external
func get_user_info{
        storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        user_id : felt,
        starknet_pubkey : felt
    ) -> (
        user_data : felt
    ):
    # The GameEngine contract calls this function when a player
    # takes a turn. This ensures a user is allowed to play.
    # The user_data provides different properties during gameplay.
    let (stored_pubkey) = user_pubkey.read(user_id)
    assert stored_pubkey = starknet_pubkey
    let (data) = user_data.read(user_id)
    return (data)
end

# User with specific token calls to save their details the game.
@external
func register_user{
        storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        starknet_pubkey : felt,
        user_data : felt
    ) -> (
        user_id : felt
    ):
    # Performs a check on either:
    # 1) Merkle claim or
    # 2) Ownership of L2-bridged ERC721, ERC1155 or ERC20 token

    # Allocates the user a user_id

    # Saves the user_id, L2_public_key and user_data

    # Testing
    let (id) = available_id.read()
    available_id.write(id + 1)

    user_pubkey.write(id, starknet_pubkey)
    # User data may be a binary encoding of all assets.
    # 00000000000000000000000000010000000010001
    #                            ^ RR         ^ shovel
    user_pubkey.write(id, user_data)

    return (id)
end
