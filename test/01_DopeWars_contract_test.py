import pytest
import asyncio
import random
from fixtures.account import account_factory

# Number of ticks a player is locked out before its next turn is allowed; MUST be consistent with MIN_TURN_LOCKOUT in contract
MIN_TURN_LOCKOUT = 3


@pytest.mark.asyncio
async def test_playerlockout(ctx_factory):
    ctx = ctx_factory()

    # TODO: perhaps make MIN_TURN_LOCKOUT a storage variable in contract instead of constant
    #       so that we can set it to 0 for faster testing

    # This test first sets up 1 user, who makes two consecutive turns, the second of which should raise exception;
    # then this test sets up MIN_TURN_LOCKOUT+1 users and each user makes one turn in order followed by the first user
    # making its second turn, which should raise no exception.
    # Note: test test assumes MIN_TURN_LOCKOUT>0; otherwise, this test would always pass
    # Note: this test bypasses the user account generation for faster testing purposes

    if MIN_TURN_LOCKOUT == 0:
        return

    print(
        f"> [test_playerlockout] test begins with MIN_TURN_LOCKOUT = {MIN_TURN_LOCKOUT}")

    # sub-test #1: 1 user making two consecutive turns
    location_id = 1
    item_id = 1
    buy_or_sell = 0  # buy
    give_quantity = 2000

    await ctx.execute(
        "alice",
        ctx.engine.contract_address,
        'have_turn',
        [location_id, buy_or_sell, item_id, give_quantity]
    )

    with pytest.raises(Exception) as e_info:
        await ctx.execute(
            "alice",
            ctx.engine.contract_address,
            'have_turn',
            [location_id, buy_or_sell, item_id, give_quantity]
        )
    print(
        f"> [test_playerlockout] sub-test #1 raises exception: {e_info.value.args}")
    print("> [test_playerlockout] sub-test #1 passes with exception raised correctly.")

    users = ["bob", "carol", "dave", "eric"]
    # sub-test #2: MIN_TURN_LOCKOUT+1 users making turns in order, followed by the first user making its second turn
    for i in range(MIN_TURN_LOCKOUT+1):
        user = users[i]
        location_id = i+1
        item_id = random.randint(1, 19)
        buy_or_sell = 0  # buy only since players start with all money and no items
        give_quantity = 2000
        turn = await ctx.execute(
            user,
            ctx.engine.contract_address,
            'have_turn',
            [location_id, buy_or_sell, item_id, give_quantity]
        )
        print(
            f"> [test_playerlockout] sub-test #2 #{i}-turn by user {user} completed.")

    # back to the first user making its second turn after exactly MIN_TURN_LOCKOUT ticks
    location_id = 6
    item_id = 10
    turn = await ctx.execute(
        "alice",
        ctx.engine.contract_address,
        'have_turn',
        [location_id, buy_or_sell, item_id, give_quantity]
    )
    print(
        f"> [test_playerlockout] sub-test #2 #{MIN_TURN_LOCKOUT+1}-turn by user alice (its second turn) completed.")

    print("> [test_playerlockout] sub-test 2 passes")
    return


def market_spawn_list_index(ctx, city_index, district_index, item_id):
    # Markets are populated with a list that is sorted by location
    # then item. Get index by accounting for city, then dist, then item.
    prev_city_items = (city_index) * ctx.consts.DISTRICTS_PER_CITY * ctx.consts.ITEM_TYPES
    prev_dist_items = (district_index) * ctx.consts.ITEM_TYPES
    prev_items = item_id - 1
    return prev_city_items + prev_dist_items + prev_items


@pytest.mark.asyncio
async def test_single_turn_logic(ctx_factory):
    ctx = ctx_factory()

    user_address = (await ctx.alice.get_address().call()).result.res
    location_id = 34
    item_id = 13
    city_index = location_id // 4  # 34 is in city index 8 (Brooklyn)
    # 34 is brooklyn district index 2 (34 % 4 = 2)
    district_index = location_id % 4  # = 2
    # See more in GameEngine contract function update_regional_items.

    initialized_index = market_spawn_list_index(
        ctx, city_index,  district_index, item_id)

    # Will test effect on a nearby district:
    # 8 * 4 = 32 = district 0. So Brooklyn is locs [32, 33, 34, 35]
    # A nearby district is therefore id=35. (district index=3)
    random_location = 35

    # Set action (buy=0, sell=1)
    buy_or_sell = 0
    # How much is the user giving (either money or item)
    # If selling, it is "give 50 item". If buying, it is "give 50 money".
    give_quantity = 2000

    pre_trade_user = await ctx.user_owned.check_user_state(user_address).call()

    pre_trade_market = await ctx.location_owned.check_market_state(
        location_id, item_id).call()

    print('pre_trade_market', pre_trade_market.result)
    print('pre_trade_user', pre_trade_user.result)
    # Execute a game turn.
    await ctx.execute(
        "alice",
        ctx.engine.contract_address,
        'have_turn',
        [location_id, buy_or_sell, item_id, give_quantity]
    )

    response = await ctx.engine.read_game_clock().call()
    turn = await ctx.engine.view_given_turn(response.result.clock).call()
    t = turn.result.turn_log

    if t.dealer_dash_bool == 1 and t.wrangle_dashed_dealer_bool == 0:
        assert t.trade_occurs_bool == 0
    else:
        assert t.trade_occurs_bool == 1

    # Check market operation
    if t.trade_occurs_bool:
        if buy_or_sell == 1:  # Selling (give item, get money).
            assert t.user_pre_trade_item > t.user_post_trade_pre_event_item
            assert t.user_pre_trade_money < t.user_post_trade_pre_event_money
            assert t.market_pre_trade_item < t.market_post_trade_pre_event_item
            assert t.market_pre_trade_money > t.market_post_trade_pre_event_money
        if buy_or_sell == 0:  # Buying (give money, get item).
            assert t.user_pre_trade_item < t.user_post_trade_pre_event_item
            assert t.user_pre_trade_money > t.user_post_trade_pre_event_money
            assert t.market_pre_trade_item > t.market_post_trade_pre_event_item
            assert t.market_pre_trade_money < t.market_post_trade_pre_event_money
    else:
        if buy_or_sell == 1:
            assert t.user_pre_trade_item == t.user_post_trade_pre_event_item
            assert t.user_pre_trade_money == t.user_post_trade_pre_event_money
            assert t.market_pre_trade_item == t.market_post_trade_pre_event_item
            assert t.market_pre_trade_money == t.market_post_trade_pre_event_money
        if buy_or_sell == 0:
            assert t.user_pre_trade_item == t.user_post_trade_pre_event_item
            assert t.user_pre_trade_money == t.user_post_trade_pre_event_money
            assert t.market_pre_trade_item == t.market_post_trade_pre_event_item
            assert t.market_pre_trade_money == t.market_post_trade_pre_event_money

    # Check no item was minted in the market maker step.
    assert t.user_pre_trade_item + t.market_pre_trade_item == \
        t.user_post_trade_pre_event_item + \
        t.market_post_trade_pre_event_item

    # Check no money was minted in the market maker step.
    assert t.user_pre_trade_money + t.market_pre_trade_money == \
        t.user_post_trade_pre_event_money + \
        t.market_post_trade_pre_event_money

    # Determine final event occurrence
    cop_hit = t.cop_raid_bool * (1 - t.bribe_cops_bool)
    gang_hit = t.gang_war_bool * (1 - t.defend_gang_war_bool)
    mug_hit = t.mugging_bool * (1 - t.run_from_mugging_bool)

    # Check event factor logic.
    if (gang_hit == 1 or cop_hit == 1) and t.find_item_bool == 0:
        assert t.item_reduction_factor < 100
    if gang_hit == 0 and cop_hit == 0 and t.find_item_bool == 1:
        assert t.item_reduction_factor > 100
    if mug_hit == 1 or cop_hit == 1:
        assert t.money_reduction_factor < 100
    if t.local_shipment_bool == 1 and t.warehouse_seizure_bool == 0:
        assert t.regional_item_reduction_factor > 100
    if t.local_shipment_bool == 0 and t.warehouse_seizure_bool == 1:
        assert t.regional_item_reduction_factor < 100

    # Check event factors appliied.
    # Check regional event item effect.
    assert t.market_post_trade_post_event_item == \
        t.regional_item_reduction_factor * \
        t.market_post_trade_pre_event_item // 100
    # Check regional market money unaffected by events.
    assert t.market_post_trade_pre_event_money == (
        t.market_post_trade_post_event_money)
    # Check user money event effect.
    assert t.user_post_trade_post_event_money == \
        t.money_reduction_factor * \
        t.user_post_trade_pre_event_money // 100
    # Check user item event effect.
    assert t.user_post_trade_post_event_item == \
        t.item_reduction_factor * t.user_post_trade_pre_event_item // 100

    # Make a separate contract call to assert persistence of state.
    # Inspect post-trade state
    response = await ctx.user_owned.check_user_state(user_address).call()
    post_trade_user = response.result
    assert post_trade_user.items[0] == t.user_post_trade_post_event_money
    assert post_trade_user.items[item_id] == t.user_post_trade_post_event_item
    print('post_trade_user', post_trade_user)

    response = await ctx.location_owned.check_market_state(location_id, item_id).call()
    post_trade_market = response.result
    assert post_trade_market.item_quantity == t.market_post_trade_post_event_item
    assert post_trade_market.money_quantity == t.market_post_trade_post_event_money

    print('post_trade_market', post_trade_market)

    # Check location is set
    assert post_trade_user.location == location_id

    # Check that another location has been set.
    response = await ctx.location_owned.check_market_state(
        random_location, item_id).call()
    random = response.result
    assert random.item_quantity != 0 and random.money_quantity != 0
    # Check that if there was a regional event, it was applied.
    # TODO.
    # assert random_market_item == random_market_pre_turn_item * \
    #    regional_item_reduction_factor // 100

    # random_initialized_user = await user_owned.check_user_state(
    #     user_id - 1).call()
    # print('rand user', random_initialized_user.result)
