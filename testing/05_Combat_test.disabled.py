import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils.Account import Account

# Create signers that use a private key to sign transaction objects.
NUM_SIGNING_ACCOUNTS = 2
DUMMY_PRIVATE = 123456789987654321
# All accounts currently have the same L1 fallback address.
L1_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984

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
        account = Account(DUMMY_PRIVATE + i, L1_ADDRESS)
        await account.create(starknet)
        accounts.append(account)

        print(f'Account {i} is: {account}')

    # Admin is usually accounts[0], user_1 = accounts[1].
    # To build a transaction to call func_xyz(arg_1, arg_2)
    # on a TargetContract:

    # user_1 = accounts[1]
    # await user_1.tx_with_nonce(
    #     to=TargetContract,
    #     selector_name='func_xyz',
    #     calldata=[arg_1, arg_2])
    return starknet, accounts


@pytest.fixture(scope='module')
async def combat_factory(account_factory):
    starknet, accounts = account_factory
    combat = await starknet.deploy("contracts/05_Combat.cairo")
    return starknet, accounts, combat


@pytest.mark.asyncio
async def test_combat(combat_factory):
    _, accounts, combat = combat_factory
    admin = accounts[0]

    # Test framework doesn't currenlty handle struct arguments.
    user_data = 0  # Struct.
    lord_user_data = 0  # Struct.
    user_combat_stats_len = 16
    user_combat_stats = [8]*16
    drug_lord_combat_stats_len = 16
    drug_lord_combat_stats = [5]*16

    (user_wins) = await combat.fight_1v1(
        user_data,
        lord_user_data,
        user_combat_stats_len,
        user_combat_stats,
        drug_lord_combat_stats_len,
        drug_lord_combat_stats).invoke()

    assert user_wins == 1
