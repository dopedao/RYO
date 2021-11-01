%lang starknet
%builtins pedersen range_check bitwise

from starkware.cairo.common.cairo_builtins import (HashBuiltin,
    BitwiseBuiltin)
from starkware.cairo.common.math import (assert_nn_le,
    unsigned_div_rem, split_felt, assert_not_zero)
from starkware.cairo.common.math_cmp import is_nn_le
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.hash_state import (hash_init,
    hash_update, HashState)
from starkware.cairo.common.bitwise import bitwise_xor
from starkware.cairo.common.alloc import alloc

from contracts.utils.market_maker import trade
from contracts.utils.game_constants import (DEALER_DASH_BP,
    WRANGLE_DASHED_DEALER_BP, MUGGING_BP, MUGGING_IMPACT,
    RUN_FROM_MUGGING_BP, GANG_WAR_BP, GANG_WAR_IMPACT,
    DEFEND_GANG_WAR_BP, COP_RAID_BP, COP_RAID_IMPACT,
    BRIBE_COPS_BP, FIND_ITEM_BP, FIND_ITEM_IMPACT, LOCAL_SHIPMENT_BP,
    LOCAL_SHIPMENT_IMPACT, WAREHOUSE_SEIZURE_BP,
    WAREHOUSE_SEIZURE_IMPACT, MIN_EVENT_FRACTION, MIN_TURN_LOCKOUT, DRUG_LORD_PERCENTAGE, NUM_COMBAT_STATS,
    LOCATIONS, DISTRICTS, STARTING_MONEY)
from contracts.utils.game_structs import UserData

from contracts.utils.interfaces import (IModuleController,
    I02_LocationOwned, I03_UserOwned, I04_UserRegistry, I05_Combat)


############ Game key ############
# Location and market are equivalent terms (one market per location)
# 76 location_ids [0, 75]. (19 cities, 4 districts each).
# user_ids: e.g., [0, not capped]. These will likely be account addresses.
# item_ids: [1,19]. 0=money, 1=item1, 2=item2, ..., etc.
# buy=0, sell=1.

# E.g., first location (location_id=0), first item (item_id=1)

############ Game state ############
# Records if a user has been initialized (flips to 1 on first turn).
@storage_var
func user_initialized(
        user_id : felt
    ) -> (
        bool : felt
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

# Game clock for measuring total turns that have passed
@storage_var
func game_clock(
   ) -> (
       value : felt
   ):
end

# Returns the game clock recorded during the previous turn of a user.
@storage_var
func clock_at_previous_turn(
       user_id : felt,
   ) -> (
       value : felt
   ):
end


# Returns the user_id who is currently the drug lord in that location.
@storage_var
func drug_lord(
       location_id : felt,
   ) -> (
       user_id : felt
   ):
end

# Returns the hash of the stats of the drug lord in that location.
@storage_var
func drug_lord_stat_hash(
       location_id : felt,
   ) -> (
       stat_hash : felt
   ):
end

# Stores the address of the ModuleController.
@storage_var
func controller_address() -> (address : felt):
end

############ Admin Functions for Testing ############
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

############ Game State Initialization ############
# Sets the initial market maker values for a given item_id.
@external
func admin_set_pairs{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        item_list_len : felt,
        item_list : felt*,
        money_list_len : felt,
        money_list : felt*,
    ):
    # Spawns the 1444 AMMs each with an item and money quantity.

    # The game starts with 76 locations. [0, 75]
    # 19 cities with 4 districts. Each with 19 item-money pairs.
    # First locations, then item ids, then save value from each list.
    # Location ids [0, 75]
    #   Item ids [0, 19]
    #       Save item val.
    #       Save money val

    # List len = 19 items x 4 districts x 19 drugs = 1444.
    # Items: [bayou_dist_0_weed_val, bayou_dist_0_cocaine_val,
    #   ..., buffalo_dist_3_adderall_val]
    # Money: [bayou_dist_0_weed_money, ..., buffalo_dist_3_adderall_money]

    # Check if allowed.
    let (admin_locked : felt) = is_admin_locked.read()
    assert admin_locked = 0

    # Pass both lists and item number to iterate and save.
    loop_over_locations(76, item_list, money_list)
    # Start the game clock where everyone can play.
    game_clock.write(MIN_TURN_LOCKOUT)
    return ()
end


# Prevents modifying markets after initialization.
@external
func toggle_admin{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        toggle : felt
    ):
    assert toggle * (1 - toggle) = 0
    is_admin_locked.write(toggle)
    return ()
end

############ Game functions ############
# Actions turn (move user, execute trade).
@external
func have_turn{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*
    }(
        user_id : felt,
        location_id : felt,
        buy_or_sell : felt,
        item_id : felt,
        amount_to_give : felt,
        user_combat_stats_len : felt,
        user_combat_stats : felt*,
        drug_lord_combat_stats_len : felt,
        drug_lord_combat_stats : felt*
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
    alloc_locals
    # Uncomment for pytest: Get address of UserRegistry.
    # let user_registry = USER_REGISTRY_ADDRESS

    # User_id will be the account contract address of the player.
    # TODO: let (user_id) = get_caller_address

    # Check if user has registered to play.
    check_user(user_id)
    # E.g., Sell 300 units of item. amount_to_give = 300.
    # E.g., Buy using 120 units of money. amount_to_give = 120.
    # Record initial state for UI and QA.
    let (controller) = controller_address.read()
    let (local user_owned_addr) = IModuleController.get_module_address(
        controller, 3)
    let (local location_owned_addr) = IModuleController.get_module_address(
        controller, 2)
    let (local user_pre_trade_item) = I03_UserOwned.user_has_item_read(
        user_owned_addr, user_id, item_id)
    let (local user_pre_trade_money) = I03_UserOwned.user_has_item_read(
        user_owned_addr, user_id, 0)
    let (local market_pre_trade_item) = I02_LocationOwned.location_has_item_read(
        location_owned_addr, location_id, item_id)
    let (local market_pre_trade_money) = I02_LocationOwned.location_has_money_read(
        location_owned_addr, location_id)

    # Get unique user data.
    let (local user_data : UserData) = fetch_user_data(user_id)
    let (local lord_user_id) = drug_lord.read(location_id)
    let (local lord_user_data : UserData) = fetch_user_data(lord_user_id)
    # TODO - Use unique user data to modify events:
    # E.g., use user_data.foot_speed to change change run_from_mugging

    # Fight the drug lord. King-of-the-Hill style.
    let (local win_bool : felt) = fight_lord(
        location_id, user_id,
        user_data, lord_user_data,
        user_combat_stats_len, user_combat_stats,
        drug_lord_combat_stats_len, drug_lord_combat_stats)

    local syscall_ptr : felt* = syscall_ptr
    # Drug lord takes a cut.
    let (local amount_to_give_post_cut) = take_cut(user_id,
            location_id, buy_or_sell, item_id,
            amount_to_give, win_bool)


    # Affect pseudorandom seed at start of turn.
    # User can grind a favourable number by incrementing lots of 10.
    let (low_precision_quant, _) = unsigned_div_rem(amount_to_give_post_cut, 10)
    let (pseudorandom : felt) = add_to_seed(item_id, amount_to_give_post_cut)
    # Get all events for this turn.
    # For UI, pass through values temporarily (in lieu of 'events').
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
    ) = get_events(user_data)

    # Apply trade and save results for market QA checks.
    # TODO: QA checks need to account for cut taken by drug_lord.
    #    E.g. amount to give is reduced if player doesn't defeat drug lord.
    execute_trade(user_id, location_id, buy_or_sell, item_id,
            amount_to_give_post_cut, trade_occurs_bool)

    # Save post-trade pre-event state.
    let (local market_post_trade_pre_event_item) = I02_LocationOwned.location_has_item_read(
        location_owned_addr, location_id, item_id)
    let (local market_post_trade_pre_event_money) = I02_LocationOwned.location_has_money_read(
        location_owned_addr, location_id)

    # Apply post-trade money using factors that arose from events.
    let (local user_post_trade_pre_event_money) = I03_UserOwned.user_has_item_read(user_owned_addr,
        user_id, 0)
    let (local user_post_trade_post_event_money, _) = unsigned_div_rem(
        user_post_trade_pre_event_money * money_reduction_factor, 100)
    I03_UserOwned.user_has_item_write(user_owned_addr, user_id, 0, user_post_trade_post_event_money)
    # Apply post-trade item using factors that arose from events.
    let (local user_post_trade_pre_event_item) = I03_UserOwned.user_has_item_read(user_owned_addr,
        user_id, item_id)
    let (local user_post_trade_post_event_item, _) = unsigned_div_rem(
        user_post_trade_pre_event_item * item_reduction_factor, 100)
    I03_UserOwned.user_has_item_write(user_owned_addr, user_id, item_id, user_post_trade_post_event_item)

    # Change the supply in regional markets due to event occurences.
    update_regional_items(location_id, item_id,
        regional_item_reduction_factor)

    # Return the post-trade posmarket_post_trade_post_event_item-event values for UI and QA checks.
    let (local market_post_trade_post_event_item) = I02_LocationOwned.location_has_item_read(
        location_owned_addr, location_id, item_id)
    let (local market_post_trade_post_event_money) = I02_LocationOwned.location_has_money_read(
        location_owned_addr, location_id)

    # Check that turn for this player is sufficiently spaced.
    let (current_clock) = game_clock.read()
    let (last_turn) = clock_at_previous_turn.read(user_id)
    assert_nn_le(MIN_TURN_LOCKOUT + last_turn, current_clock)
    game_clock.write(current_clock + 1)
    clock_at_previous_turn.write(user_id, current_clock + 1)


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
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        user_id : felt
    ) -> (
        money : felt,
        id1 : felt, id2 : felt, id3 : felt, id4 : felt, id5 : felt,
        id6 : felt, id7 : felt, id8 : felt, id9 : felt, id10 : felt,
        id11 : felt, id12 : felt, id13 : felt, id14 : felt,
        id15 : felt, id16 : felt, id17 : felt, id18 : felt,
        id19 : felt, location : felt):
    alloc_locals
    # Get the quantity held for each item.
    let (controller) = controller_address.read()
    let (user_owned_addr) = IModuleController.get_module_address(
        controller, 3)
    let (local money) = I03_UserOwned.user_has_item_read(user_owned_addr, user_id, 0)
    let (local id1) = I03_UserOwned.user_has_item_read(user_owned_addr, user_id, 1)
    let (local id2) = I03_UserOwned.user_has_item_read(user_owned_addr, user_id, 2)
    let (local id3) = I03_UserOwned.user_has_item_read(user_owned_addr, user_id, 3)
    let (local id4) = I03_UserOwned.user_has_item_read(user_owned_addr, user_id, 4)
    let (local id5) = I03_UserOwned.user_has_item_read(user_owned_addr, user_id, 5)
    let (local id6) = I03_UserOwned.user_has_item_read(user_owned_addr, user_id, 6)
    let (local id7) = I03_UserOwned.user_has_item_read(user_owned_addr, user_id, 7)
    let (local id8) = I03_UserOwned.user_has_item_read(user_owned_addr, user_id, 8)
    let (local id9) = I03_UserOwned.user_has_item_read(user_owned_addr, user_id, 9)
    let (local id10) = I03_UserOwned.user_has_item_read(user_owned_addr, user_id, 10)
    let (local id11) = I03_UserOwned.user_has_item_read(user_owned_addr, user_id, 11)
    let (local id12) = I03_UserOwned.user_has_item_read(user_owned_addr, user_id, 12)
    let (local id13) = I03_UserOwned.user_has_item_read(user_owned_addr, user_id, 13)
    let (local id14) = I03_UserOwned.user_has_item_read(user_owned_addr, user_id, 14)
    let (local id15) = I03_UserOwned.user_has_item_read(user_owned_addr, user_id, 15)
    let (local id16) = I03_UserOwned.user_has_item_read(user_owned_addr, user_id, 16)
    let (local id17) = I03_UserOwned.user_has_item_read(user_owned_addr, user_id, 17)
    let (local id18) = I03_UserOwned.user_has_item_read(user_owned_addr, user_id, 18)
    let (local id19) = I03_UserOwned.user_has_item_read(user_owned_addr, user_id, 19)
    # Get location
    let (local location) = I03_UserOwned.user_in_location_read(user_owned_addr, user_id)
    return (money, id1, id2, id3, id4, id5, id6, id7, id8, id9, id10,
        id11, id12, id13, id14, id15, id16, id17, id18, id19,
        location)
end


# A read-only function to inspect pair state of a particular market.
@view
func check_market_state{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        location_id : felt,
        item_id : felt
    ) -> (
        item_quantity : felt,
        money_quantity : felt
    ):
    alloc_locals
    # Get the quantity held for each item for item-money pair
    let (controller) = controller_address.read()
    let (local location_owned_addr) = IModuleController.get_module_address(
        controller, 2)
    let (local item_quantity) = I02_LocationOwned.location_has_item_read(
        location_owned_addr, location_id, item_id)
    let (local money_quantity) = I02_LocationOwned.location_has_money_read(
        location_owned_addr, location_id)
    return (item_quantity, money_quantity)
end


############ Helper Functions ############
# Execute trade
func execute_trade{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
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
    let (controller) = controller_address.read()
    let (location_owned_addr) = IModuleController.get_module_address(
        controller, 2)
    let (user_owned_addr) = IModuleController.get_module_address(
        controller, 3)
    I03_UserOwned.user_in_location_write(user_owned_addr,
        user_id, location_id)

    # giving_id = 0 if buying, giving_id = item_id if selling.
    local giving_id = item_id * buy_or_sell
    # receiving_id = item_id if buying, receiving_id = 0 if selling.
    local receiving_id = item_id * (1 - buy_or_sell)

    # A is always being given by user. B is always received by user.

    # Pre-giving balance.
    let (local user_a_pre) = I03_UserOwned.user_has_item_read(user_owned_addr, user_id, giving_id)
    assert_nn_le(amount_to_give, user_a_pre)
    # Post-giving balance.
    local user_a_post = user_a_pre - amount_to_give
    # Save reduced balance to state.
    I03_UserOwned.user_has_item_write(user_owned_addr, user_id, giving_id, user_a_post)


    # Pre-receiving balance.
    let (local user_b_pre) = I03_UserOwned.user_has_item_read(user_owned_addr, user_id, receiving_id)
    # Post-receiving balance depends on MarketMaker.

    # Record pre-trade market balances.
    local market_a_pre
    local market_b_pre
    if buy_or_sell == 0:
        # Buying. A money, B item.
        let (market_a_pre_temp) = I02_LocationOwned.location_has_money_read(
            location_owned_addr, location_id)
        let (market_b_pre_temp) = I02_LocationOwned.location_has_item_read(
            location_owned_addr, location_id, item_id)
        assert market_a_pre = market_a_pre_temp
        assert market_b_pre = market_b_pre_temp
    else:
        # Selling. A item, B money.
        let (market_a_pre_temp) = I02_LocationOwned.location_has_item_read(
            location_owned_addr, location_id, item_id)
        let (market_b_pre_temp) = I02_LocationOwned.location_has_money_read(
            location_owned_addr, location_id)
        assert market_a_pre = market_a_pre_temp
        assert market_b_pre = market_b_pre_temp
    end



    # Execute trade by calling the market maker contract.
    let (market_a_post, market_b_post, user_gets_b) = trade(
        market_a_pre, market_b_pre, amount_to_give)

    # Post-receiving balance depends on user_gets_b.
    let user_b_post = user_b_pre + user_gets_b
    # Save increased balance to state.
    I03_UserOwned.user_has_item_write(user_owned_addr, user_id, receiving_id, user_b_post)

    # Update post-trade states (market & user, items a & b).
    if buy_or_sell == 0:
        # User bought item. A is money.
        I02_LocationOwned.location_has_money_write(
            location_owned_addr, location_id, market_a_post)
        # B is item.
        I02_LocationOwned.location_has_item_write(
            location_owned_addr, location_id, item_id, market_b_post)
    else:
        # User sold item. A is item.
        I02_LocationOwned.location_has_item_write(
            location_owned_addr, location_id, item_id, market_a_post)
        # B is money.
        I02_LocationOwned.location_has_money_write(
            location_owned_addr, location_id, market_b_post)
    end
    return ()
end


# Add to seed.
func add_to_seed{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
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
        syscall_ptr : felt*,
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
func loop_over_items{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        item_id : felt,
        location_id : felt,
        item_list : felt*,
        money_list : felt*,
    ) -> ():
    # Location_id==Index
    if item_id == 0:
        # Triggers part 3.
        return ()
    end
    # Call recursively until item_id=1, then a return is hit.
    loop_over_items(item_id - 1, location_id, item_list, money_list)
    # Part 3. Save the state.
    # Upon first entry here item_id=1, on second item_id=2.

    # Get the position of the element in the list.
    # On first round, first entry, index = 0*19 + 1 - 1 = 0
    # On first round , second entry, index = 0*19 + 2 - 1 = 1
    # On second round, first entry, index = 1*19 + 1 - 1 = 20

    # Get index of the element: Each location has 19 elements,
    # followed by anFirst locat
    let index = location_id * 19 + item_id - 1
    # Locations are zero-based.
    # Items are 1-based. (because for a user, item_id=0 is money).

    let money_val = money_list[index]
    let item_val = item_list[index]
    let (controller) = controller_address.read()
    let (location_owned_addr) = IModuleController.get_module_address(
        controller, 2)
    I02_LocationOwned.location_has_item_write(
        location_owned_addr, location_id, item_id, item_val)
    I02_LocationOwned.location_has_money_write(
        location_owned_addr, location_id, money_val)
    return ()
end

# Recursion to populate one market pair in all locations.
func loop_over_locations{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        location_id : felt,
        item_list : felt*,
        money_list : felt*,
    ) -> ():
    # Location_id==Index
    if location_id == 0:
        # Triggers part 2.
        return ()
    end
    # Call recursively until location=1, then a return is hit.
    loop_over_locations(location_id - 1, item_list, money_list)
    # Part 2. Loop the items in this location.
    # Upon first entry here location_id=1, on second location_id=2.
    # Go over the items starting with location_id=0.
    loop_over_items(19, location_id - 1, item_list, money_list)
    return ()
end

# Evaluates all major events.
func get_events{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*
    }(
        user_data : UserData
    ) -> (
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

    # User-specific wearables alter the probability of each event.
    # Ability out of 100. Range [10, 100].
    local power_ability = user_data.weapon_strength * 10
    let run_ability = user_data.vehicle_speed * 10 + user_data.foot_speed * 10
    let (local run_ability, _) = unsigned_div_rem(run_ability, 2)
    let bribe_ability = user_data.necklace_bribe * 10 + user_data.ring_bribe * 10
    let (local bribe_ability, _) = unsigned_div_rem(bribe_ability, 2)

    # Run ability increases WRANGLE_DASHED_DEALER_BP (increases=1).
    let (local wrangle_bp) = scale_ability(run_ability,
        WRANGLE_DASHED_DEALER_BP, 1)
    # Power ability decreases MUGGING_BP (increases=0).
    let (local mugging_bp) = scale_ability(power_ability,
        MUGGING_BP, 0)
    # Run ability increases RUN_FROM_MUGGING_BP (increases=1).
    let (local run_bp) = scale_ability(run_ability,
        RUN_FROM_MUGGING_BP, 1)
    # Power ability decreases GANG_WAR_BP (increases=0).
    let (local war_bp) = scale_ability(power_ability, GANG_WAR_BP, 0)
    # Power ability increases DEFEND_GANG_WAR_BP (increases=1).
    let (local defend_war_bp) = scale_ability(power_ability,
        DEFEND_GANG_WAR_BP, 1)
    # Power ability increases COP_RAID_BP (increases=1).
    # That is, power increases chance of cop raids.
    let (local cop_raid_bp) = scale_ability(power_ability,
        COP_RAID_BP, 1)
    # Bribe ability decreases BRIBE_COPS_BP (increases=0).
    let (local bribe_bp) = scale_ability(bribe_ability,
        BRIBE_COPS_BP, 0)

    # Retrieve events
    let (local dealer_dash_bool) = event_occured(DEALER_DASH_BP)
    let (local wrangle_dashed_dealer_bool) = event_occured(wrangle_bp)
    let (local mugging_bool) = event_occured(mugging_bp)
    let (local run_from_mugging_bool) = event_occured(run_bp)
    let (local gang_war_bool) = event_occured(war_bp)
    let (local defend_gang_war_bool) = event_occured(war_bp)
    let (local cop_raid_bool) = event_occured(cop_raid_bp)
    let (local bribe_cops_bool) = event_occured(bribe_bp)
    let (local find_item_bool) = event_occured(FIND_ITEM_BP)
    let (local local_shipment_bool) = event_occured(LOCAL_SHIPMENT_BP)
    let (local warehouse_seizure_bool) = event_occured(WAREHOUSE_SEIZURE_BP)

    # Apply events
    let trade_occurs_bool = 1
    # post = pre x factor / 100. (100 = no change. 88 = 20% reduction).
    let money_reduction_factor = 100
    let item_reduction_factor = 100
    let regional_item_reduction_factor = 100
    # The combined effect of both gang+cop cannot be 100 (whole balance).
    assert_nn_le(GANG_WAR_IMPACT + COP_RAID_IMPACT, 99)

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


# Generic mapping from one range to another.
func scale{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*
    } (
        val_in : felt,
        in_low : felt,
        in_high : felt,
        out_low : felt,
        out_high : felt
    ) -> (
        val_out : felt
    ):
    # val_out = ((val_in - in_low) / (in_high - in_low))
    #           * (out_high - out_low) + out_low
    let a = (val_in - in_low) * (out_high - out_low)
    let b = in_high - in_low
    let (c, _) = unsigned_div_rem(a, b)
    let val_out = c + out_low
    return (val_out)
end

# Returns an effective probability based on an ability.
func scale_ability{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*
    } (
        ability : felt,
        event_max_bp : felt,
        increases : felt
    ) -> (
        effective_bp : felt
    ):
    # Ability range (derived from item scores 1-10, then scaled).
    let min_ab = 10
    let max_ab = 100
    # Determine the minimum possible BP: EVENT_BP * MEF/100
    let (min_bp, _) = unsigned_div_rem(
        event_max_bp * MIN_EVENT_FRACTION, 100)

    # Get effective probability, based on how the ability (increases=1)
    # changes the event. E.g., event has 50% chance, low ability=30.
    # ability = 1 * 30 (unlikely). If increases=0, ability = 80 (likely).
    let ability = increases * (ability) + (1 - increases) *
        (max_ab + min_ab - ability)

    # Map the ability to BPs: [10, 100] -> [min_bp, EVENT_BP]
    let (effective_bp) = scale(ability, min_ab, max_ab, min_bp,
        event_max_bp)
    return (effective_bp)
end


# Determines if an event occurs, given a probabilitiy (basis points).
func event_occured{
        syscall_ptr : felt*,
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
    local syscall_ptr : felt* = syscall_ptr
    local pedersen_ptr : HashBuiltin* = pedersen_ptr
    # Event occurs if number is below specified basis points.
    let (result) = is_nn_le(event, probability_bp)
    return (event_boolean = result)
end

# Changes the supply of an item in the region around a location.
func update_regional_items{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*
    }(
        location_id : felt,
        item_id : felt,
        factor : felt
    ):
    # 76 Locations [0, 75] are divided into 19 cities with 4 suburbs.
    # location_ids are sequential.
    # [loc_0_dis_0, loc_0_dis_1, ..., loc_75_dis_3, loc_75_dis_3]

    # For the supplied location_id, find the ids of nearby districts.
    # E.g., loc 7 is second city third district (city 1, district 3)
    # 1. City = integer division by number of districts. 7//4 = 1
    # and location 34 is city index 8.
    let (city_index, _) = unsigned_div_rem(location_id, DISTRICTS)
    # Loction id is the city + district index. [0, 3] for 4 districts.
    # E.g. for city index 8, the location_ids are:
    # 8 * 4, 8 * 4 + 1, 8 * 4 + 2, 8 * 4 + 3.
    # So location_id for first city in this region is:
    let city = city_index * DISTRICTS

    # new = old * factor.
    let (controller) = controller_address.read()
    let (location_owned_addr) = IModuleController.get_module_address(
        controller, 2)

    # Get current count, apply factor, save.
    let (val_0) = I02_LocationOwned.location_has_item_read(
        location_owned_addr, city, item_id)
    let (val_0_new, _) = unsigned_div_rem(val_0 * factor, 100)
    I02_LocationOwned.location_has_item_write(
        location_owned_addr, city, item_id, val_0_new)

    let (val_1) = I02_LocationOwned.location_has_item_read(
        location_owned_addr, city + 1, item_id)
    let (val_1_new, _) = unsigned_div_rem(val_1 * factor, 100)
    I02_LocationOwned.location_has_item_write(
        location_owned_addr, city + 1, item_id, val_1_new)

    let (val_2) = I02_LocationOwned.location_has_item_read(
        location_owned_addr, city + 2, item_id)
    let (val_2_new, _) = unsigned_div_rem(val_2 * factor, 100)
    I02_LocationOwned.location_has_item_write(
        location_owned_addr, city + 2, item_id, val_2_new)

    let (val_3) = I02_LocationOwned.location_has_item_read(
        location_owned_addr, city + 3, item_id)
    let (val_3_new, _) = unsigned_div_rem(val_3 * factor, 100)
    I02_LocationOwned.location_has_item_write(
        location_owned_addr, city + 3, item_id, val_3_new)
    return ()
end

# Checks the user has the correct credentials and returns game data.
func check_user{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*
    }(
        user_id : felt
    ) -> (
        user_data : felt
    ):
    alloc_locals
    # The user_id is the account contract address of the user.
    # Calls UserRegistry and retrieves information stored there.
    # let (user_registry) = user_registry_address.read()
    # let(local pub_key, player_data) = I04_UserRegistry.get_user_info()
    # Assert message sender pubkey used here matches the one retrieved.
    # assert pub_key = user_id

    # Check that the user is initialized. If not, give money.
    let (already_initialized) = user_initialized.read(user_id)
    let (controller) = controller_address.read()
    let (user_owned_addr) = IModuleController.get_module_address(
        controller, 3)
    if already_initialized == 0:
        I03_UserOwned.user_has_item_write(user_owned_addr, user_id, 0, STARTING_MONEY)
        tempvar syscall_ptr : felt* = syscall_ptr
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr : felt* = syscall_ptr
        tempvar pedersen_ptr : HashBuiltin* = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    # TODO: Return the registry-based characteristics of the player.
    let user_data = 0
    return (user_data)
end

# Returns a struct of decoded user data from binary-encoded registry.
func fetch_user_data{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr
    }(
        user_id : felt
    ) -> (
        user_stats : UserData
    ):
    alloc_locals
    let (controller) = controller_address.read()
    let (local registry) = IModuleController.get_module_address(
        controller, 4)
    # Indicies are defined in the UserRegistry contract.
    # Call the UserRegsitry contract to get scores for given user.
    let (local weapon) = I04_UserRegistry.unpack_score(registry, user_id, 6)
    let (local vehicle) = I04_UserRegistry.unpack_score(registry, user_id, 26)
    let (local foot) = I04_UserRegistry.unpack_score(registry, user_id, 46)
    let (local necklace) = I04_UserRegistry.unpack_score(registry, user_id, 66)
    let (local ring) = I04_UserRegistry.unpack_score(registry, user_id, 76)
    let (local drug) = I04_UserRegistry.unpack_score(registry, user_id, 90)

    # Populate struct.
    let user_stats = UserData(
        weapon_strength=weapon,
        vehicle_speed=vehicle,
        foot_speed=foot,
        necklace_bribe=necklace,
        ring_bribe=ring,
        special_drug=drug
    )
    return (user_stats=user_stats)
end


# Fight the drug lord.
func fight_lord{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr
    }(
        location_id : felt,
        user_id : felt,
        user_data : UserData,
        lord_user_data : UserData,
        user_combat_stats_len : felt,
        user_combat_stats : felt*,
        drug_lord_combat_stats_len : felt,
        drug_lord_combat_stats : felt*
    ) -> (
        win_bool : felt
    ):
    alloc_locals
    # Check that the user provided the drug lord stats.
    local syscall_ptr : felt* = syscall_ptr
    let (provided_lord_hash) = list_to_hash(drug_lord_combat_stats,
        drug_lord_combat_stats_len)
    let (current_lord_hash) = drug_lord_stat_hash.read(location_id)

    # If no current lord, save and 'win'.
    if current_lord_hash == 0:
        local syscall_ptr : felt* = syscall_ptr
        let (user_combat_hash) = list_to_hash(user_combat_stats,
            user_combat_stats_len)
        drug_lord_stat_hash.write(location_id, user_combat_hash)
        drug_lord.write(location_id, user_id)
        return (win_bool=1)
    end
    # If you fail to provide the current lord stats, pay the tax.
    if current_lord_hash != provided_lord_hash:
        return (win_bool=0)
    end

    let (controller) = controller_address.read()
    let (combat_addr) = IModuleController.get_module_address(
        controller, 5)
    local pedersen_ptr : HashBuiltin* = pedersen_ptr

    # Execute combat.
    let (local win_bool : felt) = I05_Combat.fight_1v1(
        combat_addr,
        user_data,
        lord_user_data,
        user_combat_stats_len,
        user_combat_stats,
        drug_lord_combat_stats_len,
        drug_lord_combat_stats)
    local syscall_ptr : felt* = syscall_ptr

    if win_bool == 0:
        return (win_bool=0)
    end

    # Hash and store the user_id and combat stats as new lord.
    local syscall_ptr : felt* = syscall_ptr
    let (user_combat_hash) = list_to_hash(user_combat_stats,
        user_combat_stats_len)
    drug_lord_stat_hash.write(location_id, user_combat_hash)
    drug_lord.write(location_id, user_id)

    return( win_bool=1)
end


# Computes the unique hash of a list of felts.
func list_to_hash{
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        list : felt*,
        list_len : felt
    ) -> (
        hash : felt
    ):
    let (list_hash : HashState*) = hash_init()
    let (list_hash : HashState*) = hash_update{
        hash_ptr=pedersen_ptr}(list_hash, list, list_len)
    return (list_hash.current_hash)
end

# Gives the drug lord a cut of whatever the user is giving.
func take_cut{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr
    }(
        user_id : felt,
        location_id : felt,
        buy_or_sell : felt,
        item_id : felt,
        amount_to_give : felt,
        win_bool : felt
    ) -> (
        amount_to_give_post_cut : felt
    ):
    alloc_locals
    if win_bool == 1:
        # User becomes new lord.
        drug_lord.write(location_id, user_id)
        # Does not pay cut
        return (amount_to_give)
    end

    # Pay the drug lord their % cut before the trade.
    let (lord_user_id) = drug_lord.read(location_id)
    # Calculate cut from amount the user is giving (money or drug).
    # E.g., amount to give 451. 1pc = 4.51 = 4.
    let (cut_1_PC, _) = unsigned_div_rem(amount_to_give, 100)
    let lord_cut = cut_1_PC * DRUG_LORD_PERCENTAGE
    # The drug lord is another user. Increase their money or drug.
    # id = 0 if buying.
    let giving_id = item_id * buy_or_sell
    let (controller) = controller_address.read()
    let (user_owned_addr) = IModuleController.get_module_address(
        controller, 3)
    I03_UserOwned.user_has_item_write(user_owned_addr, lord_user_id, giving_id, lord_cut)

    return (amount_to_give - lord_cut)
end