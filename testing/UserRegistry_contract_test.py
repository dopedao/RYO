import os
import pytest

from starkware.starknet.compiler.compile import (
    compile_starknet_files)
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.testing.contract import StarknetContract

# The path to the contract source code.
CONTRACT_FILE = os.path.join(
    os.path.dirname(__file__), "../contracts/UserRegistry.cairo")


# The testing library uses python's asyncio. So the following
# decorator and the ``async`` keyword are needed.
@pytest.mark.asyncio
async def test_record_items():
    # Compile the contract.
    contract_definition = compile_starknet_files(
        [CONTRACT_FILE], debug_info=True)

    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # Deploy the contract.
    contract_address = await starknet.deploy(
        contract_definition=contract_definition)
    contract = StarknetContract(
        starknet=starknet,
        abi=contract_definition.abi,
        contract_address=contract_address,
    )
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
    await contract.admin_fill_registry(user_count, sample_data).invoke()


    user_a_id = 271
    user_a_pubkey = user_a_id + pubkey_prefix
    # Check that the data is stored correctly for a random user.
    (data, ) = await contract.get_user_info(
        user_a_id, user_a_pubkey).invoke()
    assert data == sample_data

    # Check that the data decoding function works.
    (weapon_score, ) = await contract.unpack_score(
        user_a_id, weapon_strength_index).invoke()
    (ring_score, ) = await contract.unpack_score(
        user_a_id, ring_bribe_index).invoke()
    assert weapon_score == 3
    assert ring_score == 1
    print(f'Initialised {user_count} users and called for user {user_a_id}.')


