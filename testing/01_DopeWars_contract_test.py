import pytest
import asyncio
import random
from starkware.starknet.testing.starknet import Starknet
from utils.Signer import Signer
import sys

# Increase limit to enable initializing the market.
sys.setrecursionlimit(10000)

# Create signers that use a private key to sign transaction objects.
NUM_SIGNING_ACCOUNTS = 2
DUMMY_PRIVATE = 123456789987654321
signers = []
# All accounts currently have the same L1 fallback address.
L1_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984

# Number of users the game simulates for testing. E.g., >1000.
USER_COUNT = 10

# Combat stats.
USER_COMBAT_STATS = [5]*16
DRUG_LORD_STATS = [3]*16

# Params
CITIES = 19
DISTRICTS_PER_CITY = 4
ITEM_TYPES = 19

# Number of ticks a player is locked out before its next turn is allowed; MUST be consistent with MIN_TURN_LOCKOUT in contract
MIN_TURN_LOCKOUT = 3

# event name copied from game engine contract
EVENT_NAME = [
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
async def account_factory():
    # Initialize network
    starknet = await Starknet.empty()
    accounts = []
    print(f'Deploying {NUM_SIGNING_ACCOUNTS} accounts...')
    for i in range(NUM_SIGNING_ACCOUNTS):
        signer = Signer(DUMMY_PRIVATE + i)
        signers.append(signer)
        account = await starknet.deploy(
            "contracts/Account.cairo",
            constructor_calldata=[signer.public_key]
        )
        await account.initialize(account.contract_address).invoke()
        accounts.append(account)

        print(f'Account {i} is: {hex(account.contract_address)}')

    # Admin is usually accounts[0], user_1 = accounts[1].
    # To build a transaction to call func_xyz(arg_1, arg_2)
    # on a TargetContract:

    # await Signer.send_transaction(
    #   account=accounts[1],
    #   to=TargetContract,
    #   selector_name='func_xyz',
    #   calldata=[arg_1, arg_2],
    #   nonce=current_nonce)

    # Note that nonce is an optional argument.
    return starknet, accounts

@pytest.fixture(scope='module')
async def game_factory(account_factory):
    starknet, accounts = account_factory
    admin_key = signers[0]
    admin_account = accounts[0]

    ## The Controller is the only unchangeable contract.
    ## First deploy Arbiter.
    ## Then send the Arbiter address during Controller deployment.
    ## Then save the controller address in the Arbiter.
    ## Then deploy Controller address during module deployments.
    arbiter = await starknet.deploy(
        source="contracts/Arbiter.cairo",
        constructor_calldata=[admin_account.contract_address])
    controller = await starknet.deploy(
        source="contracts/ModuleController.cairo",
        constructor_calldata=[arbiter.contract_address])
    await admin_key.send_transaction(
        account=admin_account,
        to=arbiter.contract_address,
        selector_name='set_address_of_controller',
        calldata=[controller.contract_address])
    engine = await starknet.deploy(
        source="contracts/01_DopeWars.cairo",
        constructor_calldata=[controller.contract_address])
    location_owned = await starknet.deploy(
        source="contracts/02_LocationOwned.cairo",
        constructor_calldata=[controller.contract_address])
    user_owned = await starknet.deploy(
        source="contracts/03_UserOwned.cairo",
        constructor_calldata=[controller.contract_address])
    registry = await starknet.deploy(
        source="contracts/04_UserRegistry.cairo",
        constructor_calldata=[controller.contract_address])
    combat = await starknet.deploy(
        source="contracts/05_Combat.cairo",
        constructor_calldata=[controller.contract_address])
    drug_lord = await starknet.deploy(
        source="contracts/06_DrugLord.cairo",
        constructor_calldata=[controller.contract_address])
    pseudorandom = await starknet.deploy(
        source="contracts/07_PseudoRandom.cairo",
        constructor_calldata=[controller.contract_address])

    # The admin key controls the arbiter. Use it to have the arbiter
    # set the module deployment addresses in the controller.

    await admin_key.send_transaction(
        account=admin_account,
        to=arbiter.contract_address,
        selector_name='batch_set_controller_addresses',
        calldata=[
            engine.contract_address,
            location_owned.contract_address,
            user_owned.contract_address,
            registry.contract_address,
            combat.contract_address,
            drug_lord.contract_address,
            pseudorandom.contract_address])
    return starknet, accounts, arbiter, controller, engine, \
        location_owned, user_owned, registry, combat


@pytest.mark.asyncio
async def test_account_unique(game_factory):
    starknet, accounts, arbiter, controller, engine, \
        location_owned, user_owned, registry, combat = game_factory
    # Test the account deployments.
    admin_pub = await accounts[0].get_public_key().call()
    assert admin_pub.result == (signers[0].public_key,)
    user_1_pub = await accounts[1].get_public_key().call()
    assert user_1_pub.result == (signers[1].public_key,)
    assert signers[0].public_key != signers[1].public_key

@pytest.fixture(scope='module')
async def populated_registry(game_factory):
    starknet, accounts, arbiter, controller, engine, \
        location_owned, user_owned, registry, combat = game_factory
    admin = accounts[0]
    # Populate the registry with some data.
    sample_data = 84622096520155505419920978765481155

    # Repeating sample data
    # Indices from 0, 20, 40, 60, 80..., have values 3.
    # Indices from 10, 30, 50, 70, 90..., have values 1.
    # [00010000010011000011] * 6 == [1133] * 6
    # Populate the registry with homogeneous users (same data each).
    await admin.send_transaction(
        account=admin,
        to=registry.contract_address,
        selector_name='admin_fill_registry',
        calldata=[USER_COUNT, sample_data])
    return registry


# Checks to make sure the markets were initialized properly.
@pytest.mark.asyncio
async def test_market_spawn(game_factory):
    starknet, accounts, arbiter, controller, engine, \
        location_owned, user_owned, registry, combat = game_factory
    # Recall that item_id=1 is the first item (money is id=0)
    market  = await engine.check_market_state(0, 1).call()
    assert market.result.item_quantity != 0
    assert market.result.money_quantity != 0


@pytest.mark.asyncio
async def test_playerlockout(game_factory):
    starknet, accounts, arbiter, controller, engine, \
        location_owned, user_owned, registry, combat = game_factory
    user_signer = signers[1]
    # TODO: perhaps make MIN_TURN_LOCKOUT a storage variable in contract instead of constant
    #       so that we can set it to 0 for faster testing

    # This test first sets up 1 user, who makes two consecutive turns, the second of which should raise exception;
    # then this test sets up MIN_TURN_LOCKOUT+1 users and each user makes one turn in order followed by the first user
    # making its second turn, which should raise no exception.
    # Note: test test assumes MIN_TURN_LOCKOUT>0; otherwise, this test would always pass
    # Note: this test bypasses the user account generation for faster testing purposes

    if MIN_TURN_LOCKOUT == 0:
        return

    print(f"> [test_playerlockout] test begins with MIN_TURN_LOCKOUT = {MIN_TURN_LOCKOUT}")

    # sub-test #1: 1 user making two consecutive turns
    user_id = 1
    location_id = 1
    item_id = 1
    buy_or_sell = 0 # buy
    give_quantity = 2000

    turn_1 = await user_signer.send_transaction(
        account=accounts[1],
        to=engine.contract_address,
        selector_name='have_turn',
        calldata=[user_id, location_id,
        buy_or_sell, item_id, give_quantity])

    with pytest.raises(Exception) as e_info:
        turn_2 = await user_signer.send_transaction(
            account=accounts[1],
            to=engine.contract_address,
            selector_name='have_turn',
            calldata=[user_id, location_id,
            buy_or_sell, item_id, give_quantity])
    print(f"> [test_playerlockout] sub-test #1 raises exception: {e_info.value.args}")
    print( "> [test_playerlockout] sub-test #1 passes with exception raised correctly.")

    # sub-test #2: MIN_TURN_LOCKOUT+1 users making turns in order, followed by the first user making its second turn
    for i in range(MIN_TURN_LOCKOUT+1):
        user_id = i+2 # skipping user 0 (admin) and 1 (used by sub-test #1)
        location_id = i+1
        item_id = random.randint(1, 19)
        buy_or_sell = 0 # buy only since players start with all money and no items
        give_quantity = 2000
        turn = await user_signer.send_transaction(
            account=accounts[1],
            to=engine.contract_address,
            selector_name='have_turn',
            calldata=[user_id, location_id,
            buy_or_sell, item_id, give_quantity])
        print(f"> [test_playerlockout] sub-test #2 #{i}-turn by user#{user_id} completed.")

    # back to the first user making its second turn after exactly MIN_TURN_LOCKOUT ticks
    user_id = 2
    location_id = 6
    item_id = 10
    turn = await user_signer.send_transaction(
        account=accounts[1],
        to=engine.contract_address,
        selector_name='have_turn',
        calldata=[user_id, location_id,
        buy_or_sell, item_id, give_quantity])
    print(f"> [test_playerlockout] sub-test #2 #{MIN_TURN_LOCKOUT+1}-turn by user#{user_id} (its second turn) completed.")

    print("> [test_playerlockout] sub-test 2 passes")
    return

def market_spawn_list_index(city_index, district_index, item_id):
    # Markets are populated with a list that is sorted by location
    # then item. Get index by accounting for city, then dist, then item.
    prev_city_items = (city_index) * DISTRICTS_PER_CITY * ITEM_TYPES
    prev_dist_items = (district_index) * ITEM_TYPES
    prev_items = item_id - 1
    return prev_city_items + prev_dist_items + prev_items

@pytest.mark.asyncio
async def test_single_turn_logic(game_factory):
    starknet, accounts, arbiter, controller, engine, \
        location_owned, user_owned, registry, combat = game_factory
    user_signer = signers[1]
    user_id = 9 # avoid reusing user_id already used by test_playerlockout
    location_id = 34
    item_id = 13
    city_index = location_id // 4 # 34 is in city index 8 (Brooklyn)
    # 34 is brooklyn district index 2 (34 % 4 = 2)
    district_index = location_id % 4 # = 2
    # See more in GameEngine contract function update_regional_items.

    initialized_index = market_spawn_list_index(city_index,
        district_index, item_id)
    # Will test effect on a nearby district:
    # 8 * 4 = 32 = district 0. So Brooklyn is locs [32, 33, 34, 35]
    # A nearby district is therefore id=35. (district index=3)
    random_location = 35


    # Set action (buy=0, sell=1)
    buy_or_sell = 0
    # How much is the user giving (either money or item)
    # If selling, it is "give 50 item". If buying, it is "give 50 money".
    give_quantity = 2000

    pre_trade_user = await engine.check_user_state(user_id).invoke()

    pre_trade_market = await engine.check_market_state(
        location_id, item_id).invoke()

    print('pre_trade_market', pre_trade_market.result)
    print('pre_trade_user', pre_trade_user.result)
    # Execute a game turn.
    turn = await user_signer.send_transaction(
        account=accounts[1],
        to=engine.contract_address,
        selector_name='have_turn',
        calldata=[user_id, location_id,
        buy_or_sell, item_id, give_quantity])


    print("Turn events")
    [
        print(f"Result: {turn[index]}\t{EVENT_NAME[index]}")
        for index in range(len(EVENT_NAME))
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

    # Check event factors appliied.
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
    # TODO.
    #assert random_market_item == random_market_pre_turn_item * \
    #    regional_item_reduction_factor // 100

    random_initialized_user = await engine.check_user_state(
        user_id - 1).invoke()
    print('rand user', random_initialized_user)

