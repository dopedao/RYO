import pytest
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils.Signer import Signer

signer = Signer(123456789987654321)
L1_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()

@pytest.fixture(scope='module')
async def registry_factory():
    starknet = await Starknet.empty()
    account = await starknet.deploy("contracts/Account.cairo")
    registry = await starknet.deploy("contracts/UserRegistry.cairo")
    await account.initialize(signer.public_key, L1_ADDRESS).invoke()
    return starknet, account, registry


@pytest.mark.asyncio
async def test_initializer(registry_factory):
    _, account, registry = registry_factory

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
    await registry.admin_fill_registry(user_count, sample_data).invoke()


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


