import pytest
import asyncio
import random
import math
from starkware.starknet.testing.starknet import Starknet
from utils.Signer import Signer

# Game parameters
MIN_TURN_LOCKOUT = 3 # MUST be consistent with MIN_TURN_LOCKOUT in contract
LOCATION_COUNT = 40 # Number of locations
ITEM_COUNT = 19 # Number of items; item_id in [1,19]

# Playtest parameters
NUM_SIGNING_ACCOUNTS = MIN_TURN_LOCKOUT*5 # == total user count
DUMMY_PRIVATE = 123456789987654321
signers = []
L1_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984 # All accounts currently have the same L1 fallback address.
N_TURN = 100

# Logging parameters
COLOR_GREEN = '\33[32m'
COLOR_RED = '\33[31m'
ENDC = '\033[0m'

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

    return starknet, accounts

@pytest.fixture(scope='module')
async def game_factory(account_factory):
    starknet, accounts = account_factory

    arbiter = await starknet.deploy("contracts/Arbiter.cairo")
    controller = await starknet.deploy(
        source="contracts/ModuleController.cairo",
        constructor_calldata=[arbiter.contract_address])
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


    return starknet, accounts, arbiter, controller, engine, \
        location_owned, user_owned, registry, combat

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
    await Signer.send_transaction(
        account=admin,
        to=registry.contract_address,
        selector_name='admin_fill_registry',
        calldata=[NUM_SIGNING_ACCOUNTS, sample_data])
    return registry

@pytest.fixture(scope='module')
async def populated_game(game_factory):
    starknet, accounts, arbiter, controller, engine, \
        location_owned, user_owned, registry, combat = game_factory
    admin = accounts[0]

    # Populate the item pair of interest across all locations.
    total_locations = LOCATION_COUNT
    sample_item_count_list = [total_locations] + [(i+1)*200 for i in range(40)]
    sample_item_money_list = [total_locations] + [(i+1)*2000 for i in range(40)]

    for item_id in range(1, 20):
        # raw-interact with engine to initialize market; using admin
        # TODO figure out how to pass list as argument to admin.tx_with_nonce()
        await Signer.send_transaction(account=admin,
            to=location_owned.contract_address,
            selector_name='admin_set_pairs',
            calldata=[sample_item_count_list, sample_item_money_list])

    return engine, accounts, sample_item_count_list, sample_item_money_list

@pytest.mark.asyncio
async def test_exerciser(populated_game, populated_registry):
    '''
    test_exerciser blasts random stimulus at turn-based PvE game,
    where player (P) only interacts with the game environment (E)
    and never with each other. Specifically, P is able to query
    states of E as well as take action to affect the states of E.

    Algorithm:
    Step 0. Observe pre-game states S, open empty action record AR (omitted)
    Loop:
        Step 1. Choose P among player pool to make a turn based on turn model (TM)
        Step 2. P assembles action space (A) based on observation model (OM)
        Step 3. P chooses one action (a) from A based on behavior model (BM)
        Step 4. P performs action a against E, add action a to AR
        Step 5. Update TM
    Step 6. Observe post-game states S'_observed (omitted)
    Step 7. Simulate S + AR = S'_expected (omitted)
    Step 8. Check S'_observed == S'_expected (omitted)

    For Dope Wars specifically, one implementation could be:
    - Set TM to "random sample while excluding player among disabled-player-list"
    - Set OM to "loop over each market, check all items of that market, and add
                 valid buy-quantity and sell-quantity to A; terminate if A is
                 not null after checking a market, otherwise check all markets.
    - Set BM to "randomly sample a from A"
    - Update TM by "if P has null A then add P to TM's disabled-player-list

    TODO: abstractify this function e.g. abstract TM, OM, BM out as classes
    '''

    engine, accounts, _, _ = populated_game

    player_ids = [i for i in range(NUM_SIGNING_ACCOUNTS)]
    loc_ids = [i for i in range(LOCATION_COUNT)]
    item_ids = [i for i in range(1,ITEM_COUNT+1)] # item_id in range [1,ITEM_COUNT]

    print(f"> test_exerciser begins with {N_TURN} turns")
    disabled_players = []

    for turn in range(N_TURN):

        # Step 1. Choose player P TODO: implement disabled-player-list
        player_id = player_ids [turn % NUM_SIGNING_ACCOUNTS]

        # Step 2. Player builds action space == [actions]
        #         where each action is {type: buy/sell, item_id: item_id, quantity: quantity}
        p = await engine.check_user_state(player_id).invoke()
        player_items = [ p.money,
            p.id1, p.id2, p.id3, p.id4, p.id5, p.id6, p.id7, p.id8, p.id9, p.id10,
            p.id11, p.id12, p.id13, p.id14, p.id15, p.id16, p.id17, p.id18, p.id19 ]

        random.shuffle(loc_ids) # explore locations in different order every time
        A = [] # start with empty action space
        for loc_id in loc_ids:
            random.shuffle(item_ids) # explore items in different order every time
            for item_id in item_ids:
                curve = await engine.check_market_state(loc_id, item_id).invoke()
                curve_item = curve.item_quantity
                curve_money = curve.money_quantity

                # Calculate price_for_one:
                #   curve_item * curve_money = (curve_item-1) * (curve_money + X)
                #   => X = curve_money / (curve_item-1)
                can_pay_max = int(player_items[0])
                if curve_item>1: # has more than one item in inventory so that price_for_one != inf:
                    price_for_one = math.ceil( curve_money/(curve_item-1) ) # if paying less than one item's price, transaction will revert
                    if can_pay_max >= price_for_one: # otherwise player can't afford even one item!
                        A.append({ 'type':'buy',  'item_id':item_id, 'max_give_quantity':can_pay_max, 'price_for_one':price_for_one})

                # Calculate can_sell_max == "all my item"
                can_sell_max = int(player_items[item_id])
                if can_sell_max > 0:
                    A.append({ 'type' : 'sell', 'item_id' : item_id, 'max_give_quantity' : can_sell_max})

            if len(A) > 0: # impatient player is not going to scan all locations; test runs faster
                break

        #print(f"Size of action space = {len(A)}")

        # Step 3. P chooses one action (a) from A based on behavior model (BM)
        # TODO: check for null A, meaning a player who traded so badly that no further trades can be made anywhere
        # TODO: Should calculate the closet price to purchase integer amount of items (avoid overpaying)
        a = random.choice(A)
        if a['type'] == 'buy':
            give_quantity = random.randint(a['price_for_one'], a['max_give_quantity'])
        else:
            give_quantity = random.randint(1,a['max_give_quantity'])

        # Step 4. P performs action a against E
        buy_or_sell = 0 if a['type']=='buy' else 1
        try:
            turn_made = await Signer.send_transaction(
                account=accounts[1],
                to=engine.contract_address,
                selector_name='have_turn',
                calldata=[player_id, loc_id,
                buy_or_sell, a['item_id'], give_quantity]).invoke()
        except Exception as e:
            print(f'\n*** Trade failed with exception raised:\n{e}\n')

        if a['type'] == 'buy':
            color = COLOR_GREEN
        else:
            color = COLOR_RED
        # TODO: use .format() to format the print
        print(f"> Turn #{turn} completed: player #{player_id}" + color + f" {a['type']} " + ENDC + f"item #{a['item_id']} at location #{loc_id} by giving {give_quantity}.")

        # Step 5. Update TM TODO

    print("> test_exerciser passes.")
    return



