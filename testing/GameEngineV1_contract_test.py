import pytest
import asyncio
import random
from starkware.starknet.testing.starknet import Starknet
from utils.Signer import Signer

### Constants
signer = Signer(123456789987654321)
L1_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984

# E.g., >1000.
USER_COUNT = 10
LOCATION_COUNT = 40
ITEM_COUNT = 19 # item_id lies in [1,19]
GAME_CLOCK_LOCKUP_PERIOD = 5 # must be consistent with the GAME_CLOCK_LOCKUP_PERIOD constant in GameEngineV1.cairo
EVENT_NAMES = [
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

@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()

@pytest.fixture(scope='module')
async def game_factory():
    starknet = await Starknet.empty()
    account = await starknet.deploy("contracts/Account.cairo")
    engine = await starknet.deploy("contracts/GameEngineV1.cairo")
    market = await starknet.deploy("contracts/MarketMaker.cairo")
    registry = await starknet.deploy("contracts/UserRegistry.cairo")
    await account.initialize(signer.public_key, L1_ADDRESS).invoke()

    # Save the other contract address in the game contract.
    await engine.set_market_maker_address(
        address=market.contract_address).invoke()
    await engine.set_user_registry_address(
        address=registry.contract_address).invoke()
    return starknet, account, engine, market, registry

@pytest.mark.asyncio
async def test_market(game_factory):
    _, _, _, market, _, = game_factory
    market_a_pre = 300
    market_b_pre = 500
    user_a_pre = 40  # User gives 40.
    res = await market.trade(market_a_pre, market_b_pre, user_a_pre).invoke()
    (market_a_post, market_b_post, user_b_post, ) = res

    assert market_a_post == market_a_pre + user_a_pre
    assert market_b_post == market_b_pre - user_b_post


@pytest.fixture(scope='module')
async def populated_registry(game_factory):
    _, _, _, _, registry = game_factory
    # Populate the registry with some data.
    sample_data = 84622096520155505419920978765481155

    # Repeating sample data
    # Indices from 0, 20, 40, 60, 80..., have values 3.
    # Indices from 10, 30, 50, 70, 90..., have values 1.
    # [00010000010011000011] * 6 == [1133] * 6
    # Populate the registry with homogeneous users (same data each).
    await registry.admin_fill_registry(USER_COUNT, sample_data).invoke()
    return registry


@pytest.fixture(scope='module')
async def populated_game(game_factory):
    _, _, engine, _, _ = game_factory
    # Populate the item pair of interest across all locations.
    total_locations= LOCATION_COUNT
    user_money_pre = 10000
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
    for item_id in range(1, 20):
        await engine.admin_set_pairs_for_item(item_id,
            sample_item_count_list, sample_item_money_list).invoke()
        # Give the users money (id=0).
        await engine.admin_set_user_amount(USER_COUNT,
            user_money_pre).invoke()

    return engine, sample_item_count_list, sample_item_money_list


@pytest.mark.asyncio
async def test_single_turn_logic(populated_game, populated_registry):
    engine, sample_item_count_list, sample_item_money_list = populated_game
    
    # Initialize clock
    await engine.admin_init_clock(USER_COUNT).invoke()

    user_id = 3
    location_id = 34
    item_id = 13
    # Pick a different location in the same suburb (4, 14, 24, 34)
    random_location = 24
    random_market_pre_turn_item = sample_item_count_list[random_location]
    # Set action (buy=0, sell=1)
    buy_or_sell = 0
    # How much is the user giving (either money or item)
    # If selling, it is "give x item". If buying, it is "give x money".
    give_quantity = 2000

    pre_trade_user = await engine.check_user_state(user_id).invoke()

    pre_trade_market = await engine.check_market_state(
        location_id, item_id).invoke()

    print('pre_trade_market', pre_trade_market)
    print('pre_trade_user', pre_trade_user)
    # Execute a game turn.
    turn = await engine.have_turn(user_id, location_id,
        buy_or_sell, item_id, give_quantity).invoke()

    
    print("Turn events")
    [
        print(f"Result: {turn[index]}\t{EVENT_NAMES[index]}")
        for index in range(len(EVENT_NAMES))
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
        assert item_reduction_factor < 100
    if gang_hit == 0 and cop_hit == 0 and find_item_bool == 1:
        assert item_reduction_factor > 100
    if mug_hit == 1 or cop_hit == 1:
        assert money_reduction_factor < 100
    if local_shipment_bool == 1 and warehouse_seizure_bool == 0:
        assert regional_item_reduction_factor > 100
    if local_shipment_bool == 0 and warehouse_seizure_bool == 1:
        assert regional_item_reduction_factor < 100

    # Check event factors applied.
    # Check regional event item effect.
    assert market_post_trade_post_event_item == \
        regional_item_reduction_factor * \
        market_post_trade_pre_event_item // 100
    # Check regional market money unaffected by events.
    assert market_post_trade_pre_event_money == (
        market_post_trade_post_event_money)
    # Check user money event effect.
    assert user_post_trade_post_event_money == \
        money_reduction_factor * \
        user_post_trade_pre_event_money // 100
    # Check user item event effect.
    assert user_post_trade_post_event_item == \
        item_reduction_factor * user_post_trade_pre_event_item // 100


    # Make a separate contract call to assert persistence of state.
    # Inspect post-trade state
    post_trade_user = await engine.check_user_state(
        user_id).invoke()
    assert post_trade_user[0] == user_post_trade_post_event_money
    assert post_trade_user[item_id] == user_post_trade_post_event_item
    print('post_trade_user', post_trade_user)

    post_trade_market = await engine.check_market_state(
        location_id, item_id).invoke()
    assert post_trade_market[0] == market_post_trade_post_event_item
    assert post_trade_market[1] == market_post_trade_post_event_money
    print('post_trade_market', post_trade_market)

    # Check location is set
    assert post_trade_user[20] == location_id

    # Check that another location has been set.
    (random_market_item, random_market_money) = \
        await engine.check_market_state(
        random_location, item_id).invoke()
    assert random_market_item != 0 and random_market_money != 0
    # Check that if there was a regional event, it was applied.
    assert random_market_item == random_market_pre_turn_item * \
        regional_item_reduction_factor // 100

    random_initialized_user = await engine.check_user_state(
        9).invoke()
    print('rand user', random_initialized_user)


@pytest.mark.asyncio
async def test_clock_multi_user_turn_logic(populated_game, populated_registry):
    engine, sample_item_count_list, sample_item_money_list = populated_game

    # Initialize clock
    await engine.admin_init_clock(USER_COUNT).invoke()

    # Test: every user buys a fixed amount of a random item at a random city
    #       with no repeating city&item so that user's actions are independent;
    #       make sure no transaction reverts and that
    #       observed == expected in terms of quantity of item bought

    # Pre-trade setup
    turn_user_id_s = [i for i in range(USER_COUNT)] # each user makes one turn
    random.shuffle(turn_user_id_s)
    turn_location_id_s = random.sample([i for i in range(LOCATION_COUNT)], USER_COUNT)
    turn_item_id_s = random.sample([i+1 for i in range(ITEM_COUNT)], USER_COUNT) # skipping item#0 (money)
    turn_payment = 2000

    # Fetching pre-trade state from engine contract
    state_pre_trade_user = {}
    state_pre_trade_loc_item = {}

    for i in range(USER_COUNT):
        state_pre_trade_user[turn_user_id_s[i]] = await engine.check_user_state(turn_user_id_s[i]).invoke()

    for loc_id in range(LOCATION_COUNT):
        state_pre_trade_loc_item[loc_id] = {}
        for item_id in [i for i in range(ITEM_COUNT+1)]: # money amount at market needed for calculating expected trade result
            state_pre_trade_loc_item[loc_id][item_id] = await engine.check_market_state(loc_id, item_id).invoke()
    
    # Printing pre-trade state
    '''
    print('\n\n== Pre-trade state ==')
    for user_id in turn_user_id_s:
        print(f'{user_id} / {state_pre_trade_user[user_id]}')
    print()

    for loc_id in range(LOCATION_COUNT):
        for item_id in [i+1 for i in range(ITEM_COUNT)]:
            print(f'loc{loc_id} - item{item_id} / {state_pre_trade_loc_item[loc_id][item_id]}')
    
    ret = await engine.check_game_clock().invoke()
    print(f"game_clock = {ret.game_clock_value}")

    for i in range(USER_COUNT):
        ret = await engine.check_user_clock_at_previous_turn(i).invoke()
        print(f"user#{i}'s user_clock_at_previous_turn = {ret.game_clock_value}")
    print()
    '''

    # Confirming game clock and each user's clock at previous turn are initialized correctly (to zero)
    ret = await engine.check_game_clock().invoke()
    assert ret.game_clock_value == 0
    for i in range(USER_COUNT):
        ret = await engine.check_user_clock_at_previous_turn(i).invoke()
        assert ret.game_clock_value == 0
    print("Confirmed: game_clock and each user's clock_at_previous_turn are initialized correctly to 0")
    print("Pre-trade setup completed.\n")

    # Make turns
    turn_s = []
    for i in range(USER_COUNT):
        user_id = turn_user_id_s[i]
        loc_id =  turn_location_id_s[i]
        item_id = turn_item_id_s[i]

        ret = await engine.check_game_clock().invoke()
        print(f"game_clock before {i}th turn = {ret.game_clock_value}")

        ret = await engine.check_user_clock_at_previous_turn(user_id).invoke()
        print(f"user#{user_id}'s user_clock_at_previous_turn before turn = {ret.game_clock_value}")

        print(f"user#{user_id} about to pay {turn_payment} to buy item#{item_id} at location#{loc_id}")

        buy_or_sell = 0 # all buys
        turn = await engine.have_turn(user_id, loc_id,
            buy_or_sell, item_id, turn_payment).invoke()
        turn_s.append(turn)

        print(f'> {i}th turn completed.\n')
    print("Each player has made one turn.")

    # Fetching post-trade state from engine contract
    # and extract quantities of items bought per user as "observed" results
    state_post_trade_user = {}
    state_post_trade_loc_item = {}

    for i in range(USER_COUNT):
        state_post_trade_user[turn_user_id_s[i]] = await engine.check_user_state(turn_user_id_s[i]).invoke()

    for loc_id in range(LOCATION_COUNT):
        state_post_trade_loc_item[loc_id] = {}
        for item_id in [i+1 for i in range(ITEM_COUNT)]:
            state_post_trade_loc_item[loc_id][item_id] = await engine.check_market_state(loc_id, item_id).invoke()
    
    # Printing post-trade state
    '''
    print('\n\n== Post-trade state ==')
    for user_id in turn_user_id_s:
        print(f'{user_id} / {state_post_trade_user[user_id]}')
    print()

    for loc_id in range(LOCATION_COUNT):
        for item_id in [i+1 for i in range(ITEM_COUNT)]:
            print(f'loc{loc_id} - item{item_id} / {state_post_trade_loc_item[loc_id][item_id]}')
    '''

    # Simulate trades to produce "expected" quantities of items bought per user
    # for each user, expected quantity of item bought =
    # (market_inventory_pre_trade * user_money_paid) // (market_money_pre_trade + user_money_paid)
    print("Simulating trades to calculate expected results:")
    expected_s = []
    for i in range(1):
        user_id = turn_user_id_s[i]
        loc_id =  turn_location_id_s[i]
        item_id = turn_item_id_s[i]

        market_inventory_pre_trade = state_pre_trade_loc_item[loc_id][item_id]
        user_money_paid = turn_payment
        market_money_pre_trade = state_pre_trade_loc_item[loc_id][0]

        #print(f'market_inventory_pre_trade = {market_inventory_pre_trade}')
        #print(f'market_money_pre_trade = {market_money_pre_trade}')
        #expected_quantity_bought = (market_inventory_pre_trade * user_money_paid) // (market_money_pre_trade + user_money_paid)

        #print(f"> user{user_id} paid {turn_payment} at loc#{loc_id} for item#{item_id}; expected to get {expected_quantity_bought} in return.")
        #expected_s.append(expected_quantity_bought)

    # Checking "observed" results against "expected" results in terms of quantity of item bought
