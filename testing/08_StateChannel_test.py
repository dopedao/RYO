import pytest
import asyncio
import random
from fixtures.account import account_factory

# admin, user, user
NUM_SIGNING_ACCOUNTS = 3

# How long a channel offer persists ('time-units')
OFFER_DURATION = 20

@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()

@pytest.fixture(scope='module')
async def game_factory(account_factory):
    (starknet, accounts, signers) = account_factory
    CONTROLLER_ADDRESS = 34567
    channels = await starknet.deploy(
        source="contracts/08_StateChannel.cairo",
        constructor_calldata=[CONTROLLER_ADDRESS])
    return starknet, accounts, signers, channels

@pytest.mark.asyncio
@pytest.mark.parametrize('account_factory', [dict(num_signers=NUM_SIGNING_ACCOUNTS)], indirect=True)
async def test_channel_match(game_factory):
    _, accounts, signers, channels = game_factory
    user_1_signer = signers[1]
    user_2_signer = signers[2]
    user_1 = accounts[1]
    user_2 = accounts[2]
    # User signals availability and submits a pubkey for the channel.
    await user_1_signer.send_transaction(
        account=user_1,
        to=channels.contract_address,
        selector_name='signal_available',
        calldata=[OFFER_DURATION, user_1_signer.public_key])

    res = await channels.status_of_player(user_1.contract_address).call()
    assert res.result.game_key == user_1_signer.public_key
    assert res.result.queue_len == 1
    assert res.result.index_in_queue == 0
    c = res.result.channel_details
    print("Channel details: ")
    [print(t) for t in c]
    assert c.index == 0
    assert c.opened_at_block == 0
    assert c.last_challenged_at_block == 0
    assert c.latest_state_index == 0
    assert c.addresses == (0, 0)
    assert c.balance == (0, 0)
    assert c.initial_channel_data == 0
    assert c.initial_state_hash == 0

    # Second user signals availability and is matched.
    await user_2_signer.send_transaction(
        account=user_2,
        to=channels.contract_address,
        selector_name='signal_available',
        calldata=[OFFER_DURATION, user_2_signer.public_key])

    res = await channels.status_of_player(user_2.contract_address).call()
    assert res.result.game_key == user_2_signer.public_key
    assert res.result.queue_len == 0
    assert res.result.index_in_queue == 0
    c = res.result.channel_details
    print("Channel details: ")
    [print(t) for t in c]
    assert c.index == 0
    assert c.opened_at_block == 0
    assert c.last_challenged_at_block == 0
    assert c.latest_state_index == 0
    assert c.addresses == (user_1_signer.public_key,
        user_2_signer.public_key)
    assert c.balance == (100, 100)
    assert c.initial_channel_data == 987654321
    assert c.initial_state_hash == 123456789




