import pytest
import asyncio
from fixtures.account import account_factory
from utils import Signer

# [admin, user, user, user]
NUM_SIGNING_ACCOUNTS = 4

@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()

@pytest.fixture(scope='module')
async def game_factory(account_factory):
    (starknet, accounts, signers) = account_factory
    CONTROLLER_ADDRESS = 34567
    channels = await starknet.deploy(
        source="contracts/11_Trinity.cairo",
        constructor_calldata=[CONTROLLER_ADDRESS])
    return starknet, accounts, signers, channels

@pytest.fixture(scope='module')
@pytest.mark.asyncio
@pytest.mark.parametrize('account_factory', [dict(num_signers=NUM_SIGNING_ACCOUNTS)], indirect=True)
async def test_channel_open(game_factory):
    starknet, accounts, signers, channels = game_factory
    user_1_signer = signers[1]
    user_1 = accounts[1]
    # User signals availability and submits a pubkey for the channel.
    await user_1_signer.send_transaction(
        account=user_1,
        to=channels.contract_address,
        selector_name='signal_available',
        calldata=[param_a, param_b])

    res = await channels.status_of_player(user_1.contract_address).call()
