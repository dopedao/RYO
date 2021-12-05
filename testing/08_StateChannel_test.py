import pytest
import asyncio
import random
from fixtures.account import account_factory

# admin, user, user
NUM_SIGNING_ACCOUNTS = 4

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

@pytest.fixture(scope='module')
@pytest.mark.asyncio
@pytest.mark.parametrize('account_factory', [dict(num_signers=NUM_SIGNING_ACCOUNTS)], indirect=True)
async def test_channel_open(game_factory):
    starknet, accounts, signers, channels = game_factory
    user_1_signer = signers[1]
    user_2_signer = signers[2]
    user_3_signer = signers[3]
    user_1 = accounts[1]
    user_2 = accounts[2]
    user_3 = accounts[3]
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
    assert c.id == 0  # Empty channel has zero ID.
    assert c.addresses == (0, 0)
    assert c.initial_state_hash == 0
    res = await channels.read_queue_length().call()
    assert res.result.length == 1

    # Second user signals availability and is matched.
    await user_2_signer.send_transaction(
        account=user_2,
        to=channels.contract_address,
        selector_name='signal_available',
        calldata=[OFFER_DURATION, user_2_signer.public_key])

    res = await channels.read_queue_length().call()
    assert res.result.length == 0

    res = await channels.status_of_player(user_2.contract_address).call()
    assert res.result.game_key == user_2_signer.public_key
    assert res.result.queue_len == 0
    assert res.result.index_in_queue == 0
    c = res.result.channel_details
    assert c.id == 1  # First channel has id==1.
    assert c.opened_at_block == 1
    assert c.last_challenged_at_block == 1
    assert c.latest_state_index == 0
    # User 2 opens channel so is recorded at index 0 in the channel.
    assert c.addresses[0] == user_2.contract_address
    assert c.addresses[1] == user_1.contract_address
    assert c.balance == (100, 100)
    assert c.initial_channel_data == 987654321
    assert c.initial_state_hash == 123456789
    print("Passed: Open a channel.")
    try:
        await user_3_signer.send_transaction(
            account=user_3,
            to=channels.contract_address,
            selector_name='close_channel',
            calldata=[c.id])
    except Exception as e:
        print("Passed: Prevent third party from closing channel")
    return starknet, accounts, signers, channels


@pytest.mark.asyncio
@pytest.mark.parametrize('account_factory', [dict(num_signers=NUM_SIGNING_ACCOUNTS)], indirect=True)
async def test_close_channel(test_channel_open):
    _, accounts, signers, channels = test_channel_open
    user_1_signer = signers[1]
    user_2_signer = signers[2]
    user_3_signer = signers[3]
    user_1 = accounts[1]
    user_2 = accounts[2]
    user_3 = accounts[3]
    await user_1_signer.send_transaction(
        account=user_1,
        to=channels.contract_address,
        selector_name='close_channel',
        calldata=[OFFER_DURATION, user_1_signer.public_key])

    # TODO: Implement channel closure logic.
    # E.g., movement of assets to winner, record events as reportcard.
    res = await channels.status_of_player(user_1.contract_address).call()
    assert res.result.game_key == 0
    assert res.result.queue_len == 0
    assert res.result.index_in_queue == 0
    c = res.result.channel_details
    # Assert c is empty.
    # assert balances are changed.
    # assert report card administered.


@pytest.mark.asyncio
@pytest.mark.parametrize('account_factory', [dict(num_signers=NUM_SIGNING_ACCOUNTS)], indirect=True)
async def test_queue_function(game_factory):
    _, accounts, signers, channels = game_factory
    user_1_signer = signers[1]
    user_2_signer = signers[2]
    user_3_signer = signers[3]
    user_1 = accounts[1]
    user_2 = accounts[2]
    user_3 = accounts[3]
    # User signals availability and submits a pubkey for the channel.
    await user_1_signer.send_transaction(
        account=user_1,
        to=channels.contract_address,
        selector_name='signal_available',
        calldata=[OFFER_DURATION, user_1_signer.public_key])

    res = await channels.read_queue_length().call()
    assert res.result.length == 1
    assert res.result.player_at_index_0 == user_1.contract_address


    # User 1 cannot rejoin queue.
    try:
        await user_1_signer.send_transaction(
            account=user_1,
            to=channels.contract_address,
            selector_name='signal_available',
            calldata=[OFFER_DURATION, user_1_signer.public_key])
    except Exception as e:
        print(f'\nPassed: Prevent queue re-entry.')

    # Second user signals availability and is matched.
    await user_2_signer.send_transaction(
        account=user_2,
        to=channels.contract_address,
        selector_name='signal_available',
        calldata=[OFFER_DURATION, user_2_signer.public_key])

    # User 2 matches, channel should open and queue length reduces.
    res = await channels.read_queue_length().call()
    assert res.result.length == 0

    # User 1 cannot rejoin queue now they are in a channel.
    try:
        await user_1_signer.send_transaction(
            account=user_1,
            to=channels.contract_address,
            selector_name='signal_available',
            calldata=[OFFER_DURATION, user_1_signer.public_key])
    except Exception as e:
        print(f'\nPassed: Prevent queue entry once in channel.')

    # Third user signals availability and is matched.
    await user_3_signer.send_transaction(
        account=user_3,
        to=channels.contract_address,
        selector_name='signal_available',
        calldata=[OFFER_DURATION, user_3_signer.public_key])

    # User 3 enters queue.
    res = await channels.read_queue_length().call()
    assert res.result.length == 1

    res = await channels.status_of_player(user_3.contract_address).call()
    assert res.result.game_key == user_3_signer.public_key
    assert res.result.queue_len == 1
    assert res.result.index_in_queue == 0