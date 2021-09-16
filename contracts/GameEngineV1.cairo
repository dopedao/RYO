%lang starknet
%builtins pedersen range_check bitwise

from starkware.cairo.common.cairo_builtins import (HashBuiltin,
    BitwiseBuiltin)
from starkware.starknet.common.storage import Storage
from starkware.cairo.common.math import (assert_nn_le,
    unsigned_div_rem, split_felt)
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.bitwise import bitwise_xor

############ Other Contract Info ############
# Address of previously deployed MarketMaket.cairo contract.
const MARKET_MAKER_ADDRESS = 0x07f9ad51033cd6107ad7d70d01c3b0ba2dda3331163a45b6b7f1a2952dac0880
# Modifiable address pytest deployments.
@storage_var
func market_maker_address(
    ) -> (
        address : felt
    ):
end

# Declare the interface with which to call the Market Maker contract.
@contract_interface
namespace IMarketMaker:
    func trade(
        market_a_pre : felt,
        market_b_pre : felt,
        user_gives_a : felt
    ) -> (
        market_a_post : felt,
        market_b_post : felt,
        user_gets_b : felt
    ):
    end
end

############ Game key ############
# Location and market are equivalent terms (one market per location)
# 40 location_ids [1-40].
# user_ids: e.g., [0,10000].
# item_ids: [1,11]. 0=money, 1=item1, 2=item2, ..., etc.
# buy=0, sell=1.

############ Game state ############
# Specify user, item, return quantity.
@storage_var
func user_has_item(
        user_id : felt, item_id
    ) -> (
        count : felt
    ):
end

# Location of users. Input user, retrieve city.
@storage_var
func user_in_location(
        user_id : felt
    ) -> (
        location_id : felt
    ):
end

# Returns item count for item-money pair in location.
@storage_var
func location_has_item(
        location_id : felt,
        item_id : felt
    ) -> (
        count : felt
    ):
end

# Returns money count for item-money pair in location.
@storage_var
func location_has_money(
        location_id : felt,
        item_id : felt
    ) -> (
        count : felt
    ):
end

# Seed (for pseudorandom) that players add to.
@storage_var
func entropy_seed(
    ) -> (
        value : felt
    ):
end

# Admin lock (1 = yes locked out, 0 = can use)
@storage_var
func is_admin_locked(
    ) -> (
        value : felt
    ):
end

############ Admin Functions for Testing ############
# Sets the address of the deployed MarketMaker.cairo contract.
@external
func set_market_maker_address{
        storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        address : felt
    ):
    # Used for testing. This can be constant on deployment.
    market_maker_address.write(address)
    return ()
end


############ Game State Initialization ############
# Sets the initial market maker values for a given item_id.
@external
func admin_set_pairs_for_item{
        storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        item_id : felt,
        item_list_len : felt,
        item_list : felt*,
        money_list_len : felt,
        money_list : felt*,
    ):
    # item-money pairs for a specified item, ordered by location.

    # Check if allowed.
    let (admin_locked : felt) = is_admin_locked.read()
    assert admin_locked = 0

    # Pass both lists and item number to iterate and save.
    loop_over_locations(item_list_len - 1, item_list, money_list, item_id)
    return ()
end


# Prevents modifying markets after initialization.
@external
func toggle_admin{
        storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    is_admin_locked.write(1)
    return ()
end

# Creates an item-money market pair with specific liquidity.
@external
func admin_set_user_amount{
        storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        user_id : felt,
        item_id : felt,
        item_quantity : felt
    ):
    # Set the quantity for a particular item for a given user.
    # E.g., item_id 3, a user has market has 500 units. (id 0 is money).
    user_has_item.write(user_id, item_id, item_quantity)
    return ()
end


############ Game functions ############
# Actions turn (move user, execute trade).
@external
func have_turn{
        syscall_ptr : felt*,
        storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*
    }(
        user_id : felt,
        location_id : felt,
        buy_or_sell : felt,
        item_id : felt,
        amount_to_give : felt
    ):
    # E.g., Sell 300 units of item. amount_to_give = 300.
    # E.g., Buy using 120 units of money. amount_to_give = 120.
    alloc_locals
    # Affect pesudorandomn seed at start of turn.
    let (psuedorandom) = add_to_seed(item_id, amount_to_give)

    assert_nn_le(buy_or_sell, 1)  # Only 0 or 1 valid.
    # Move user
    user_in_location.write(user_id, location_id)

    # giving_id = 0 if buying, giving_id = item_id if selling.
    local giving_id = item_id * buy_or_sell
    # receiving_id = item_id if buying, receiving_id = 0 if selling.
    local receiving_id = item_id * (1 - buy_or_sell)

    # A is always being given by user. B is always received by user.

    # Pre-giving balance.
    let (local user_a_pre) = user_has_item.read(user_id, giving_id)
    assert_nn_le(amount_to_give, user_a_pre)
    # Post-giving balance.
    local user_a_post = user_a_pre - amount_to_give
    # Save reduced balance to state.
    user_has_item.write(user_id, giving_id, user_a_post)

    # Pre-receiving balance.
    let (local user_b_pre) = user_has_item.read(user_id, receiving_id)
    # Post-receiving balance depends on MarketMaker.

    # Record pre-trade market balances.
    if buy_or_sell == 0:
        # Buying. A money, B item.
        let (market_a_pre_temp) = location_has_money.read(
            location_id, item_id)
        let (market_b_pre_temp) = location_has_item.read(
            location_id, item_id)
    else:
        # Selling. A item, B money.
        let (market_a_pre_temp) = location_has_item.read(
            location_id, item_id)
        let (market_b_pre_temp) = location_has_money.read(
            location_id, item_id)
    end
    # Finalise values after IF-ELSE section (handles fp).
    local market_a_pre = market_a_pre_temp
    local market_b_pre = market_b_pre_temp

    # Uncomment for pytest: Get address of MarketMaker.
    let (market_maker) = market_maker_address.read()
    #let market_maker = MARKET_MAKER_ADDRESS

    # Execute trade by calling the market maker contract.
    let (market_a_post, market_b_post,
        user_gets_b) = IMarketMaker.trade(market_maker,
        market_a_pre, market_b_pre, amount_to_give)

    # Post-receiving balance depends on user_gets_b.
    let user_b_post = user_b_pre + user_gets_b
    # Save increased balance to state.
    user_has_item.write(user_id, receiving_id, user_b_post)

    # Update post-trade states (market & user, items a & b).
    if buy_or_sell == 0:
        # User bought item. A is money.
        location_has_money.write(location_id, item_id, market_a_post)
        # B is item.
        location_has_item.write(location_id, item_id, market_b_post)
    else:
        # User sold item. A is item.
        location_has_item.write(location_id, item_id, market_a_post)
        # B is money.
        location_has_money.write(location_id, item_id, market_b_post)
    end
    return ()
end


############ Read-Only Functions for Testing ############
# A read-only function to inspect user state.
@view
func check_user_state{
        storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        user_id : felt
    ) -> (
        money : felt,
        id1 : felt, id2 : felt, id3 : felt, id4 : felt, id5 : felt,
        id6 : felt, id7 : felt, id8 : felt, id9 : felt, id10 : felt,
        location : felt):
    alloc_locals
    # Get the quantity held for each item.
    let (local money) = user_has_item.read(user_id, 0)
    let (local id1) = user_has_item.read(user_id, 1)
    let (local id2) = user_has_item.read(user_id, 2)
    let (local id3) = user_has_item.read(user_id, 3)
    let (local id4) = user_has_item.read(user_id, 4)
    let (local id5) = user_has_item.read(user_id, 5)
    let (local id6) = user_has_item.read(user_id, 6)
    let (local id7) = user_has_item.read(user_id, 7)
    let (local id8) = user_has_item.read(user_id, 8)
    let (local id9) = user_has_item.read(user_id, 9)
    let (local id10) = user_has_item.read(user_id, 10)
    # Get location
    let (local location) = user_in_location.read(user_id)
    return (money, id1, id2, id3, id4, id5, id6, id7, id8, id9, id10,
        location)
end


# A read-only function to inspect pair state of a particular market.
@view
func check_market_state{
        storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        location_id : felt,
        item_id : felt
    ) -> (
        item_quantity : felt,
        money_quantity
    ):
    alloc_locals
    # Get the quantity held for each item for item-money pair
    let (local item_quantity) = location_has_item.read(location_id,
        item_id)
    let (local money_quantity) = location_has_money.read(location_id,
        item_id)
    return (item_quantity, money_quantity)
end

############ Helper Functions ############
# Add to seed.
func add_to_seed{
        pedersen_ptr : HashBuiltin*,
        storage_ptr : Storage*,
        bitwise_ptr : BitwiseBuiltin*,
        range_check_ptr
    }(
        val0 : felt,
        val1 : felt
    ) -> (
        num_to_use : felt
    ):
    # Players add to the seed (seed = seed XOR hash(item, quantity)).
    # You can game the hash by changing the item/quantity (not useful)
    let (hash) = hash2{hash_ptr=pedersen_ptr}(val0, val1)
    let (old_seed) = entropy_seed.read()
    let (new_seed) = bitwise_xor(hash, old_seed)
    entropy_seed.write(new_seed)
    return (new_seed)
end

# Gets hard-to-predict values. Player can draw multiple times.
# Has not been tested rigorously.
# @external # '@external' for testing only.
func get_pseudorandom{
        storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (
        num_to_use : felt
    ):
    # Seed is fed to linear congruential generator.
    # seed = (multiplier * seed + increment) % modulus.
    # Params from GCC. (https://en.wikipedia.org/wiki/Linear_congruential_generator).
    let (old_seed) = entropy_seed.read()
    # Snip in half to a manageable size.
    let (left, right) = split_felt(old_seed)
    let (_, new_seed) = unsigned_div_rem(1103515245 * right + 1,
        2**31)
    # Number has form: 10**9 (xxxxxxxxxx).
    entropy_seed.write(new_seed)
    return (new_seed)
end

# Recursion to populate one market pair in all locations.
func loop_over_locations{
        storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        location_id : felt,
        item_list : felt*,
        money_list : felt*,
        item_id : felt
    ) -> ():
    # Location_id==Index
    if location_id == 0:
        # Triggers part 2.
        return ()
    end
    # Call recursively until location=1, then a return is hit.
    loop_over_locations(location_id - 1, item_list, money_list, item_id)
    # Part 2. Save the state.
    # Upon first entry here location_id=1, on second location_id=2.
    location_has_item.write(location_id, item_id, item_list[location_id])
    location_has_money.write(location_id, item_id, money_list[location_id])
    return ()
end
