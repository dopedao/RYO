import os
import pytest

from starkware.starknet.compiler.compile import (
    compile_starknet_files)
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.testing.contract import StarknetContract

# The path to the contract source code.
ENGINE_CONTRACT_FILE = os.path.join(
    os.path.dirname(__file__), "../contracts/GameEngineV1.cairo")
MARKET_CONTRACT_FILE = os.path.join(
    os.path.dirname(__file__), "../contracts/MarketMaker.cairo")

# The testing library uses python's asyncio. So the following
# decorator and the ``async`` keyword are needed.
@pytest.mark.asyncio
async def test_record_items():
    # Compile the contracts.
    engine_contract_definition = compile_starknet_files(
        [ENGINE_CONTRACT_FILE], debug_info=True)
    market_contract_definition = compile_starknet_files(
        [MARKET_CONTRACT_FILE], debug_info=True)

    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # Deploy the contracts.
    market_contract_address = await starknet.deploy(
        contract_definition=market_contract_definition)
    engine_contract_address = await starknet.deploy(
        contract_definition=engine_contract_definition)

    # Create contract Objects to interact with.
    engine_contract = StarknetContract(
        starknet=starknet,
        abi=engine_contract_definition.abi,
        contract_address=engine_contract_address,
    )

    # Save the market address in the engine contract so it can call
    # the market maker contract.
    await engine_contract.set_market_maker_address(
        address=market_contract_address).invoke()

    # Set up a scenario. A user who will go to some market and trade
    # in some item in exchange for money.
    number_of_users=1000
    total_locations=40
    location_id = 34
    user_id = 3
    item_id = 7
    # Pick a different location in the same suburb (4, 14, 24, 34)
    random_location = 24

    # User has small amount of money, but lots of the item they are selling.
    user_money_pre = 10000
    user_item_pre = 0
    # Set action (buy=0, sell=1)
    buy_or_sell = 0
    # How much is the user giving (either money or item)
    # If selling, it is "give x item". If buying, it is "give x money".
    give_quantity = 2000

    # E.g., 10 items in location 1, 20 loc 2.
    sample_item_count_list = [total_locations,
        20, 40, 60, 80, 100, 120, 140, 160, 180, 200,
        220, 240, 260, 280, 300, 320, 340, 360, 380, 400,
        420, 440, 460, 480, 500, 520, 540, 560, 580, 600,
        620, 640, 660, 680, 700, 720, 740, 760, 780, 800]
    # E.g., 100 money in curve for item location 1, 200 loc 2.
    sample_item_money_list = [total_locations,
        200, 400, 600, 800, 1000, 1200, 1400, 1600, 1800, 2000,
        2200, 2400, 2600, 2800, 3000, 3200, 3400, 3600, 3800, 4000,
        4200, 4400, 4600, 4800, 5000, 5200, 5400, 5600, 5800, 6000,
        6200, 6400, 6600, 6800, 7000, 7200, 7400, 7600, 7800, 8000]
    # Market has lots of money, not a lot of the item it is receiving.

    # Create the market.
    # Populate the item pair of interest across all locations.
    await engine_contract.admin_set_pairs_for_item(item_id,
        sample_item_count_list, sample_item_money_list).invoke()
    # Give the user money (id=0).
    await engine_contract.admin_set_user_amount(number_of_users,
        user_money_pre).invoke()
    pre_trade_user = await engine_contract.check_user_state(
        user_id).invoke()
    print('pre_trade_user', pre_trade_user)
    pre_trade_market = await engine_contract.check_market_state(
        location_id, item_id).invoke()
    print('pre_trade_market', pre_trade_market)
    random_market_pre_turn_item = sample_item_count_list[random_location]

    # Execute a game turn.
    turn = await engine_contract.have_turn(user_id, location_id,
        buy_or_sell, item_id, give_quantity).invoke()


    event_name = [
        "trade_occurs_bool",
        "user_pre_trade_item",
        "user_post_trade_pre_event_item",
        "user_post_trade_post_event_item",
        "user_pre_trade_money",
        "user_post_trade_pre_event_money",
        "user_post_trade_post_event_money",
        "market_pre_trade_item",
        "market_post_trade_pre_event_item",
        "market_post_trade_post_event_item",
        "market_pre_trade_money",
        "market_post_trade_pre_event_money",
        "market_post_trade_post_event_money",
        "money_reduction_factor",
        "item_reduction_factor",
        "regional_item_reduction_factor",
        "dealer_dash_bool",
        "wrangle_dashed_dealer_bool",
        "mugging_bool",
        "run_from_mugging_bool",
        "gang_war_bool",
        "defend_gang_war_bool",
        "cop_raid_bool",
        "bribe_cops_bool",
        "find_item_bool",
        "local_shipment_bool",
        "warehouse_seizure_bool"
    ]
    print("Turn events")
    [
        print(f"Result: {turn[index]}\t{event_name[index]}")
        for index in range(len(event_name))
    ]
    (
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
    ) = turn

    assert market_pre_trade_item == sample_item_count_list[location_id]
    assert market_pre_trade_money == sample_item_money_list[location_id]

    if dealer_dash_bool == 1 and wrangle_dashed_dealer_bool == 0:
        assert trade_occurs_bool == 0
    else:
        trade_occurs_bool == 1

    # Check market operation
    if trade_occurs_bool:
        if buy_or_sell == 1:  # Selling (give item, get money).
            assert user_pre_trade_item > user_post_trade_pre_event_item
            assert user_pre_trade_money < user_post_trade_pre_event_money
            assert market_pre_trade_item < market_post_trade_pre_event_item
            assert market_pre_trade_money > market_post_trade_pre_event_money
        if buy_or_sell == 0:  # Buying (give money, get item).
            assert user_pre_trade_item < user_post_trade_pre_event_item
            assert user_pre_trade_money > user_post_trade_pre_event_money
            assert market_pre_trade_item > market_post_trade_pre_event_item
            assert market_pre_trade_money < market_post_trade_pre_event_money
    else:
        if buy_or_sell == 1:
            assert user_pre_trade_item == user_post_trade_pre_event_item
            assert user_pre_trade_money == user_post_trade_pre_event_money
            assert market_pre_trade_item == market_post_trade_pre_event_item
            assert market_pre_trade_money == market_post_trade_pre_event_money
        if buy_or_sell == 0:
            assert user_pre_trade_item == user_post_trade_pre_event_item
            assert user_pre_trade_money == user_post_trade_pre_event_money
            assert market_pre_trade_item == market_post_trade_pre_event_item
            assert market_pre_trade_money == market_post_trade_pre_event_money


    # Check no item was minted in the market maker step.
    assert user_pre_trade_item + market_pre_trade_item == \
        user_post_trade_pre_event_item + \
        market_post_trade_pre_event_item

    # Check no money was minted in the market maker step.
    assert user_pre_trade_money + market_pre_trade_money == \
        user_post_trade_pre_event_money + \
        market_post_trade_pre_event_money

    # Determine final event occurrence
    cop_hit = cop_raid_bool * (1 - bribe_cops_bool)
    gang_hit = gang_war_bool * (1 - defend_gang_war_bool)
    mug_hit = mugging_bool * (1 - run_from_mugging_bool)

    # Check event factor logic.
    if (gang_hit == 1 or cop_hit == 1) and find_item_bool == 0:
        assert item_reduction_factor < 10
    if gang_hit == 0 and cop_hit == 0 and find_item_bool == 1:
        assert item_reduction_factor > 10
    if mug_hit == 1 or cop_hit == 1:
        assert money_reduction_factor < 10
    if local_shipment_bool == 1 and warehouse_seizure_bool == 0:
        assert regional_item_reduction_factor > 10
    if local_shipment_bool == 0 and warehouse_seizure_bool == 1:
        assert regional_item_reduction_factor < 10

    # Check event factors appliied.
    # Check regional event item effect.
    assert market_post_trade_post_event_item == \
        regional_item_reduction_factor * \
        market_post_trade_pre_event_item // 10
    # Check regional market money unaffected by events.
    assert market_post_trade_pre_event_money == (
        market_post_trade_post_event_money)
    # Check user money event effect.
    assert user_post_trade_post_event_money == \
        money_reduction_factor * \
        user_post_trade_pre_event_money // 10
    # Check user item event effect.
    assert user_post_trade_post_event_item == \
        item_reduction_factor * user_post_trade_pre_event_item // 10


    # Make a separate conract call to assert persistence of state.
    # Inspect post-trade state
    post_trade_user = await engine_contract.check_user_state(
        user_id).invoke()
    assert post_trade_user[0] == user_post_trade_post_event_money
    assert post_trade_user[item_id] == user_post_trade_post_event_item
    print('post_trade_user', post_trade_user)

    post_trade_market = await engine_contract.check_market_state(
        location_id, item_id).invoke()
    assert post_trade_market[0] == market_post_trade_post_event_item
    assert post_trade_market[1] == market_post_trade_post_event_money
    print('post_trade_market', post_trade_market)

    # Check location is set
    assert post_trade_user[11] == location_id

    # Check that another location has been set.
    (random_market_item, random_market_money) = \
        await engine_contract.check_market_state(
        random_location, item_id).invoke()
    assert random_market_item != 0 and random_market_money != 0
    # Check that if there was a regional event, it was applied.
    assert random_market_item == random_market_pre_turn_item * \
        regional_item_reduction_factor // 10

    random_initialized_user = await engine_contract.check_user_state(
        9).invoke()
    print('rand user', random_initialized_user)


    # Make false assertion to trigger printing of variables to console.
    assert 1==0