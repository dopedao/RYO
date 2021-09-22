%lang starknet
%builtins pedersen range_check bitwise

from starkware.cairo.common.cairo_builtins import (HashBuiltin,
    BitwiseBuiltin)
from starkware.starknet.common.storage import Storage
from starkware.cairo.common.math import (assert_nn_le,
    unsigned_div_rem, split_felt)
from starkware.cairo.common.math_cmp import is_nn_le
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.bitwise import bitwise_xor
from starkware.cairo.common.alloc import alloc

############ Game constants ############
# Default basis point probabilities applied per turn. 10000=100%.
# Impact factor scales value. post = (pre * F)// 10). 3 = 30% increase.
# Impact factor is either added or subtracted from 10.
# Probabilities are currently just set to 50%.
const DEALER_DASH_BP = 1000  # E.g., 10% chance dealer runs.
const WRANGLE_DASHED_DEALER_BP = 5000  # 30% you catch them.
const MUGGING_BP = 5000  # 15% chance of mugging.
const MUGGING_IMPACT = 3  # Impact is 30% money loss = (10-3)/10.
const RUN_FROM_MUGGING_BP = 5000
const GANG_WAR_BP = 5000
const GANG_WAR_IMPACT = 3  # Impact is 30% money loss = (10-3)/10.
const DEFEND_GANG_WAR_BP = 5000
const COP_RAID_BP = 5000
const COP_RAID_IMPACT = 2  # Impact is 20% item & 20% money loss.
const BRIBE_COPS_BP = 5000
const FIND_ITEM_BP = 5000
const FIND_ITEM_IMPACT = 5  # Impact is 50% item gain = (10+5)/10.
const LOCAL_SHIPMENT_BP = 5000
const LOCAL_SHIPMENT_IMPACT = 2  # Regional impact is 20% item gain.
const WAREHOUSE_SEIZURE_BP = 5000
const WAREHOUSE_SEIZURE_IMPACT = 2  # Regional impact 20% item loss.

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
# 40 location_ids [0-39].
# user_ids: e.g., [0,10000].
# item_ids: [1,11]. 0=money, 1=item1, 2=item2, ..., etc.
# buy=0, sell=1.

############ Game state ############
# Specify user, item, return quantity.
@storage_var
func user_has_item(
        user_id : felt,
        item_id : felt
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
    }(
        toggle : felt
    ):
    assert toggle * (1 - toggle) = 0
    is_admin_locked.write(toggle)
    return ()
end

# Gives all users an amount of money.
@external
func admin_set_user_amount{
        storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        num_users : felt,
        money_quantity : felt
    ):
    # Set the quantity of money for all users.
    loop_users(num_users, money_quantity)
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
    ) -> (
        trade_occurs_bool : felt,
        user_pre_trade_item : felt,
        user_post_trade_pre_event_item : felt,
        user_post_trade_post_event_item : felt,
        user_pre_trade_money : felt,
        user_post_trade_pre_event_money : felt,
        user_post_trade_post_event_money : felt,
        market_pre_trade_item : felt,
        market_post_trade_pre_event_item : felt,
        market_post_trade_post_event_item : felt,
        market_pre_trade_money : felt,
        market_post_trade_pre_event_money : felt,
        market_post_trade_post_event_money : felt,
        money_reduction_factor : felt,
        item_reduction_factor : felt,
        regional_item_reduction_factor : felt,
        dealer_dash_bool : felt,
        wrangle_dashed_dealer_bool : felt,
        mugging_bool : felt,
        run_from_mugging_bool : felt,
        gang_war_bool : felt,
        defend_gang_war_bool : felt,
        cop_raid_bool : felt,
        bribe_cops_bool : felt,
        find_item_bool : felt,
        local_shipment_bool : felt,
        warehouse_seizure_bool : felt
    ):

    # E.g., Sell 300 units of item. amount_to_give = 300.
    # E.g., Buy using 120 units of money. amount_to_give = 120.
    alloc_locals
    # Record initial state for UI and QA.
    let (local user_pre_trade_item) = user_has_item.read(user_id,
        item_id)
    let (local user_pre_trade_money) = user_has_item.read(user_id, 0)
    let (local market_pre_trade_item) = location_has_item.read(
        location_id, item_id)
    let (local market_pre_trade_money) = location_has_money.read(
        location_id, item_id)

    # Affect pesudorandomn seed at start of turn.
    let (psuedorandom : felt) = add_to_seed(item_id, amount_to_give)
    # Get all events for this turn.
    # For UI pass through values temporarily (in lieu of 'events').
    let (
        local trade_occurs_bool : felt,
        local money_reduction_factor : felt,
        local item_reduction_factor : felt,
        local regional_item_reduction_factor : felt,
        local dealer_dash_bool : felt,
        local wrangle_dashed_dealer_bool : felt,
        local mugging_bool : felt,
        local run_from_mugging_bool : felt,
        local gang_war_bool : felt,
        local defend_gang_war_bool : felt,
        local cop_raid_bool : felt,
        local bribe_cops_bool : felt,
        local find_item_bool : felt,
        local local_shipment_bool : felt,
        local warehouse_seizure_bool : felt
    ) = get_events()

    # Apply trade and save results for market QA checks.
    execute_trade(user_id, location_id, buy_or_sell, item_id,
            amount_to_give, trade_occurs_bool)

    # Save post-trade pre-event state.
    let (local market_post_trade_pre_event_item) = location_has_item.read(
        location_id, item_id)
    let (local market_post_trade_pre_event_money) = location_has_money.read(
        location_id, item_id)

    # Apply post-trade factors that arose from events.
    let (local user_post_trade_pre_event_money) = user_has_item.read(
        user_id, 0)
    let (local user_post_trade_post_event_money, _) = unsigned_div_rem(
        user_post_trade_pre_event_money * money_reduction_factor, 10)
    user_has_item.write(user_id, 0, user_post_trade_post_event_money)

    let (local user_post_trade_pre_event_item) = user_has_item.read(
        user_id, item_id)
    let (local user_post_trade_post_event_item, _) = unsigned_div_rem(
        user_post_trade_pre_event_item * item_reduction_factor, 10)
    user_has_item.write(user_id, item_id, user_post_trade_post_event_item)

    # Change the supply in regional markets.
    update_regional_items(location_id, item_id,
        regional_item_reduction_factor)

    # Return the post-trade post-event values for UI and QA checks.
    let (local market_post_trade_post_event_item) = location_has_item.read(
        location_id, item_id)
    let (local market_post_trade_post_event_money) = location_has_money.read(
        location_id, item_id)

    return (
        trade_occurs_bool,
        user_pre_trade_item,
        user_post_trade_pre_event_item,
        user_post_trade_post_event_item,
        user_pre_trade_money,
        user_post_trade_pre_event_money,
        user_post_trade_post_event_money,
        market_pre_trade_item,
        market_post_trade_pre_event_item,
        market_post_trade_post_event_item,
        market_pre_trade_money,
        market_post_trade_pre_event_money,
        market_post_trade_post_event_money,
        money_reduction_factor,
        item_reduction_factor,
        regional_item_reduction_factor,
        dealer_dash_bool,
        wrangle_dashed_dealer_bool,
        mugging_bool,
        run_from_mugging_bool,
        gang_war_bool,
        defend_gang_war_bool,
        cop_raid_bool,
        bribe_cops_bool,
        find_item_bool,
        local_shipment_bool,
        warehouse_seizure_bool
    )
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
# Execute trade
func execute_trade{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        storage_ptr : Storage*,
        bitwise_ptr : BitwiseBuiltin*,
        range_check_ptr
    }(
        user_id : felt,
        location_id : felt,
        buy_or_sell : felt,
        item_id : felt,
        amount_to_give : felt,
        trade_occurs_bool : felt
    ):
    alloc_locals

    # This skips the trade and passes back the implicit arguments.
    if trade_occurs_bool == 0:
        return ()
    end

    # Only 0 or 1 valid.
    assert_nn_le(buy_or_sell, 1)
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
    # Use the line below for deployment.
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
# Has not been tested rigorously (e.g., for biasing).
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
    # Snip in half to a manageable size for unsigned_div_rem.
    let (left, right) = split_felt(old_seed)
    let (_, new_seed) = unsigned_div_rem(1103515245 * right + 1,
        2**31)
    # Number has form: 10**9 (xxxxxxxxxx).
    # Should be okay to write multiple times to same variable
    # without increasing storage costs of this transaction.
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
    location_has_item.write(location_id - 1, item_id,
        item_list[location_id - 1])
    location_has_money.write(location_id - 1, item_id,
        money_list[location_id - 1])
    return ()
end

# Evaluates all major events.
func get_events{
        storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*
    }() -> (
        trade_occurs_bool : felt,
        money_reduction_factor : felt,
        item_reduction_factor : felt,
        regional_item_reduction_factor : felt,
        dealer_dash_bool : felt,
        wrangle_dashed_dealer_bool : felt,
        mugging_bool : felt,
        run_from_mugging_bool : felt,
        gang_war_bool : felt,
        defend_gang_war_bool : felt,
        cop_raid_bool : felt,
        bribe_cops_bool : felt,
        find_item_bool : felt,
        local_shipment_bool : felt,
        warehouse_seizure_bool : felt
    ):
    # Factors that apply post trade. Two scenarios can affect the
    # same variable, with both having a summation effect where two
    # 30% reduction effects (10 - 3 - 3) * 10)//10 = 60% reduction.
    alloc_locals
    # Retrieve events
    let (local dealer_dash_bool) = event_occured(DEALER_DASH_BP)
    let (local wrangle_dashed_dealer_bool) = event_occured(WRANGLE_DASHED_DEALER_BP)
    let (local mugging_bool) = event_occured(MUGGING_BP)
    let (local run_from_mugging_bool) = event_occured(RUN_FROM_MUGGING_BP)
    let (local gang_war_bool) = event_occured(GANG_WAR_BP)
    let (local defend_gang_war_bool) = event_occured(DEFEND_GANG_WAR_BP)
    let (local cop_raid_bool) = event_occured(COP_RAID_BP)
    let (local bribe_cops_bool) = event_occured(BRIBE_COPS_BP)
    let (local find_item_bool) = event_occured(FIND_ITEM_BP)
    let (local local_shipment_bool) = event_occured(LOCAL_SHIPMENT_BP)
    let (local warehouse_seizure_bool) = event_occured(WAREHOUSE_SEIZURE_BP)

    # Apply events
    let trade_occurs_bool = 1
    # post = pre x factor / 10. (10 = no change. 8 = 20% reduction).
    let money_reduction_factor = 10
    let item_reduction_factor = 10
    let regional_item_reduction_factor = 10
    assert_nn_le(GANG_WAR_IMPACT + COP_RAID_IMPACT, 9)

    # E.g., Trade = 0 if dealer dashes and gets away.
    # trade does not occur = 1 - 1 * (1 - 0) = 0.
    # trade occurs = 1 - 0 * (1 - NA) = 1.
    let trade_occurs_bool = 1 - dealer_dash_bool * (1 - wrangle_dashed_dealer_bool)

    # E.g., Post-trade money * (7/10) if mugged and run fails.
    # mugged = F - x * (1 * (1 - 0)) = F - x.
    # no mug = F - x * (1 * (1 - 1)) = F.
    # no mug = F - x * (0 * (1 - NA)) = F.
    let money_reduction_factor = money_reduction_factor - MUGGING_IMPACT * (
        mugging_bool * (1 - run_from_mugging_bool))

    # E.g., Post-trade item * (7/10) if war and no defence.
    # gang hit = F - x * (1 * (1 - 0)) = F - x.
    # gang not = F - x * (1 * (1 - 1)) = F.
    # gang not = F - x * (0 * (1 - NA)) = F.
    let item_reduction_factor = item_reduction_factor - GANG_WAR_IMPACT * (
        gang_war_bool * (1 - defend_gang_war_bool))

    # E.g., Post-trade item and money * (8/10) raid and no bribe.
    # cop raid = F - x * (1 * (1 - 0)) = F - x.
    # not raid = F - x * (1 * (1 - 1)) = F.
    # not raid = F - x * (0 * (1 - NA)) = F.
    let item_reduction_factor =  item_reduction_factor - COP_RAID_IMPACT * (
        cop_raid_bool * (1 - bribe_cops_bool))
    let money_reduction_factor = money_reduction_factor - COP_RAID_IMPACT * (
        cop_raid_bool * (1 - bribe_cops_bool))

    # E.g., Post-trade item * (15/10) if found.
    # find item = F + x * (1) = F + x.
    # no find = F + x * (0) = F.
    let item_reduction_factor = item_reduction_factor + FIND_ITEM_IMPACT * (
        find_item_bool)

    # E.g., Post-trade regional item quantities * (12/10) if shipment arrives.
    # shipment = F + x * 1 = F + x.
    # no ship = F + x * 0 = F.
    let regional_item_reduction_factor = regional_item_reduction_factor + (
        LOCAL_SHIPMENT_IMPACT * local_shipment_bool)

    # E.g., Post-trade regional item quantities * (8/10) if seizure occurs.
    # raid hit = F - x * 1 = F - x.
    # raid not = F - x * 0 = F.
    let regional_item_reduction_factor = regional_item_reduction_factor - (
        WAREHOUSE_SEIZURE_IMPACT * warehouse_seizure_bool)

    # TODO: Need to emit these events.
    return (
        trade_occurs_bool,
        money_reduction_factor,
        item_reduction_factor,
        regional_item_reduction_factor,
        dealer_dash_bool,
        wrangle_dashed_dealer_bool,
        mugging_bool,
        run_from_mugging_bool,
        gang_war_bool,
        defend_gang_war_bool,
        cop_raid_bool,
        bribe_cops_bool,
        find_item_bool,
        local_shipment_bool,
        warehouse_seizure_bool
    )
end

# Determines if an event occurs, given a probabilitiy (basis points).
func event_occured{
        storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*
    }(
        probability_bp : felt
    ) -> (
        event_boolean : felt
    ):
    # Returns 1 if the event occured, 0 otherwise.
    # Event evaluation = num modulo max_basis_points
    alloc_locals
    let (p_rand_num) = get_pseudorandom()
    let (_, event) = unsigned_div_rem(p_rand_num, 10000)

    # Save pointers here (otherwise revoked by is_nn_le).
    local storage_ptr : Storage* = storage_ptr
    local pedersen_ptr : HashBuiltin* = pedersen_ptr
    # Event occurs if number is below specified basis points.
    let (result) = is_nn_le(event, probability_bp)
    return (event_boolean = result)
end

# Changes the supply of an item in the region around a location.
func update_regional_items{
        syscall_ptr : felt*,
        storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*
    }(
        location_id : felt,
        item_id : felt,
        factor : felt
    ):
    # 40 Locations [0, 39] are divided into 10 cities with 4 suburbs.
    # E.g., where location 24 has 3 other co-suburbs (4, 14, 34).
    # ids = location_id mod 10 + [0, 10, 20, 30].
    # new = old * factor.
    let (_ , rem) = unsigned_div_rem(location_id, 10)
    # Get current count, apply factor, save.
    let (val_0) = location_has_item.read(rem, item_id)
    let (val_0_new, _) = unsigned_div_rem(val_0 * factor, 10)
    location_has_item.write(rem, item_id, val_0_new)

    let (val_1) = location_has_item.read(rem + 10, item_id)
    let (val_1_new, _) = unsigned_div_rem(val_1 * factor, 10)
    location_has_item.write(rem + 10, item_id, val_1_new)

    let (val_2) = location_has_item.read(rem + 20, item_id)
    let (val_2_new, _) = unsigned_div_rem(val_2 * factor, 10)
    location_has_item.write(rem + 20, item_id, val_2_new)

    let (val_3) = location_has_item.read(rem + 30, item_id)
    let (val_3_new, _) = unsigned_div_rem(val_3 * factor, 10)
    location_has_item.write(rem + 30, item_id, val_3_new)
    return ()
end

# Loops over all users and initializes a balance.
func loop_users{
        storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        num_users : felt,
        amount : felt
    ):
    if num_users == 0:
        return ()
    end
    loop_users(num_users=num_users-1, amount=amount)
    # Num users 1 on first entry. User index is num_users-1.
    user_has_item.write(user_id=num_users-1, item_id=0, value=amount)
    return ()
end