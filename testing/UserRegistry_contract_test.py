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
async def registry_factory(account_factory):
    starknet, accounts = account_factory
    registry = await starknet.deploy("contracts/UserRegistry.cairo")
    return starknet, accounts, registry


@pytest.mark.asyncio
async def test_initializer(registry_factory):
    _, accounts, registry = registry_factory
    admin = accounts[0]
    user_count = 500
    sample_data = 84622096520155505419920978765481155
    # Repeating sample data
    # Indices from 0, 20, 40, 60, 80..., have values 3.
    # Indices from 10, 30, 50, 70, 90..., have values 1.
    # [00010000010011000011] * 6 == [1133] * 6
    weapon_strength_index = 6
    ring_bribe_index = 76
    pubkey_prefix = 1000000
    # Populate the registry with homogeneous users (same data each).
    await admin.tx_with_nonce(
        to=registry.contract_address,
        selector_name='admin_fill_registry',
        calldata=[user_count, sample_data])

    user_a_id = 271
    user_a_pubkey = user_a_id + pubkey_prefix
    # Check that the data is stored correctly for a random user.
    (data, ) = await registry.get_user_info(
        user_a_id, user_a_pubkey).invoke()
    assert data == sample_data

    # Check that the data decoding function works.
    (weapon_score, ) = await registry.unpack_score(
        user_a_id, weapon_strength_index).invoke()
    (ring_score, ) = await registry.unpack_score(
        user_a_id, ring_bribe_index).invoke()
    assert weapon_score == 3
    assert ring_score == 1
    print(f'Initialised {user_count} users and called for user {user_a_id}.')
