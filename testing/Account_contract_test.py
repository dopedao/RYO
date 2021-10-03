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

    # admin is usually accounts[0], user_1 = accounts[1].
    # To build a transaction to call func_xyz(arg_1, arg_2)
    # on a TargetContract:

    # user_1 = accounts[1]
    # await user_1.tx_with_nonce(
    #     to=TargetContract,
    #     selector_name='func_xyz',
    #     calldata=[arg_1, arg_2])
    return starknet, accounts


@pytest.mark.asyncio
async def test_account_unique(account_factory):
    _, accounts = account_factory
    admin = accounts[0].signer.public_key
    user_1 = accounts[1].signer.public_key
    assert admin != user_1


@pytest.mark.asyncio
async def test_initializer(account_factory):
    _, accounts = account_factory
    admin = accounts[0]
    (key_in_contract, ) = await admin.contract.get_public_key().call()
    key_in_object = admin.signer.public_key
    assert key_in_contract == key_in_object

