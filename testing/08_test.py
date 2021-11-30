import pytest
import asyncio
import random
from fixtures.account import account_factory

NUM_SIGNING_ACCOUNTS = 2

# Number of users the game simulates for testing. E.g., >1000.
USER_COUNT = 3

# How long a channel offer persists ('time-units')
OFFER_DURATION = 20


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()

@pytest.fixture(scope='module')
async def game_factory(account_factory):
    (starknet, accounts, signers) = account_factory
    admin_key = signers[0]
    admin_account = accounts[0]

    CONTROLLER_ADDRESS = 34567
    channel = await starknet.deploy(
        source="contracts/01_DopeWars.cairo",
        constructor_calldata=[CONTROLLER_ADDRESS])

    return starknet, accounts, signers, channel

@pytest.mark.asyncio
@pytest.mark.parametrize('account_factory', [dict(num_signers=NUM_SIGNING_ACCOUNTS)], indirect=True)
async def test_channel_match(game_factory):
    starknet, accounts, signers, channel = game_factory
    user_1_signer = signers[1]
    user_1 = accounts[1]
    # User signals availability and submits a pubkey for the channel.
    await user_1_signer.send_transaction(
        account=user_1,
        to=channel.contract_address,
        selector_name='signal_available',
        calldata=[OFFER_DURATION, user_1_signer.public_key])


