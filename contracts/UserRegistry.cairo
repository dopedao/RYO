%lang starknet
%builtins pedersen range_check bitwise

from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.cairo_builtins import (HashBuiltin,
    BitwiseBuiltin)
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.pow import pow
from starkware.starknet.common.storage import Storage

##### Encoding details #####
# Zero-based bit index for data locations.
# 0 weapon id.
# 6 weapon strength score (v1).
# 10 clothes.
# 20 vehicle id.
# 26 vehicle speed score (v1).
# 30 waistArmor id.
# 40 footArmor id.
# 46 footArmor speed score (v1).
# 50 handArmor id.
# 60 necklace id.
# 66 necklace bribe score (v1).
# 70 ring id.
# 76 ring bribe score (v1).
# 80 suffix id.
# 90 drug id (v1).
# 100 namePrefixes.
# 110 nameSuffixes.
# 120-249 (vacant).

# Test data with alternating id/score values: 113311331133113311331133
# E.g., weapon score = 3, vehicle speed score = 3, ring bribe score = 1.
# 00010000010011000011 * 6 = 12 items (indices starting 0-110).
#000100000100110000110001000001001100001100010000010011000011000100000100110000110001000001001100001100010000010011000011
const TESTDATA1 = 84622096520155505419920978765481155

##### Storage #####
# Binary encoding of ownership fields.
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

##### External Functions #####
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
        data : felt
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
    user_data.write(id, data)

    return (id)
end

# Creates artificial users for testing.
@external
func admin_fill_registry{
        storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        n_users : felt,
        data : felt
    ):
    #

    # Loop over, populating user store with pubkey and data.
    loop_n_users(n_users, data)
    return ()
end

# Returns a 4-bit value at a particular index for item score.
@external
func unpack_score{
        storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr
    }(
        user_id : felt,
        index : felt
    ) -> (
        score : felt
    ):
    alloc_locals
    # User data is a binary encoded value with alternating
    # 6-bit id followed by a 4-bit score (see top of file).
    let (local data) = user_data.read(user_id)
    local storage_ptr : Storage* = storage_ptr
    local pedersen_ptr : HashBuiltin* = pedersen_ptr
    local bitwise_ptr: BitwiseBuiltin* = bitwise_ptr
    # 1. Create a 4-bit mask at and to the left of the index
    # E.g., 000111100 = 2**2 + 2**3 + 2**4 + 2**5
    # E.g.,  2**(i) + 2**(i+1) + 2**(i+2) + 2**(i+3) = (2**i)(15)
    let (power) = pow(2, index)
    # 1 + 2 + 4 + 8 = 15
    let mask = 15 * power

    # 2. Apply mask using bitwise operation: mask AND data.
    let (masked) = bitwise_and(mask, data)

    # 3. Shift element right by dividing by the order of the mask.
    let (score, _) = unsigned_div_rem(masked, power)

    return (score)
end

##### Helper Functions #####
# Recursion to populate registry storage.
func loop_n_users{
        storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        num : felt,
        data : felt
    ):
    if num == 0:
        return ()
    end
    loop_n_users(num - 1, data)
    # On first entry, num=1.
    # Set the pubkey to be n+1000000 (testing). Same data for all.
    register_user(num - 1 + 1000000, data)
    return ()
end
