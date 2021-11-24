import pytest
import asyncio
from fixtures.account import account_factory

NUM_SIGNING_ACCOUNTS = 2

# Number of ticks a player is locked out before its next turn is allowed; MUST be consistent with MIN_TURN_LOCKOUT in contract
MIN_TURN_LOCKOUT = 3

@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()

@pytest.fixture(scope='module')
async def game_factory(account_factory):
    (starknet, accounts, signers) = account_factory
    admin_key = signers[0]
    admin_account = accounts[0]

    ## The Controller is the only unchangeable contract.
    ## First deploy Arbiter.
    ## Then send the Arbiter address during Controller deployment.
    ## Then save the controller address in the Arbiter.
    ## Then deploy Controller address during module deployments.
    arbiter = await starknet.deploy(
        source="contracts/Arbiter.cairo",
        constructor_calldata=[admin_account.contract_address])
    controller = await starknet.deploy(
        source="contracts/ModuleController.cairo",
        constructor_calldata=[arbiter.contract_address])
    await admin_key.send_transaction(
        account=admin_account,
        to=arbiter.contract_address,
        selector_name='set_address_of_controller',
        calldata=[controller.contract_address])
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
    drug_lord = await starknet.deploy(
        source="contracts/06_DrugLord.cairo",
        constructor_calldata=[controller.contract_address])
    pseudorandom = await starknet.deploy(
        source="contracts/07_PseudoRandom.cairo",
        constructor_calldata=[controller.contract_address])

    # The admin key controls the arbiter. Use it to have the arbiter
    # set the module deployment addresses in the controller.

    await admin_key.send_transaction(
        account=admin_account,
        to=arbiter.contract_address,
        selector_name='batch_set_controller_addresses',
        calldata=[
            engine.contract_address,
            location_owned.contract_address,
            user_owned.contract_address,
            registry.contract_address,
            combat.contract_address,
            drug_lord.contract_address,
            pseudorandom.contract_address])
    return starknet, accounts, signers, arbiter, controller, engine, \
        location_owned, user_owned, registry, combat

@pytest.mark.asyncio
@pytest.mark.parametrize('account_factory', [dict(num_signers=NUM_SIGNING_ACCOUNTS)], indirect=True)
async def test_initializer(game_factory):
    starknet, accounts, signers, arbiter, controller, engine, \
        location_owned, user_owned, registry, combat = game_factory
    admin = accounts[0]
    user_signer = signers[1]
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
    await user_signer.send_transaction(
        account=admin,
        to=registry.contract_address,
        selector_name='admin_fill_registry',
        calldata=[user_count, sample_data])

    user_a_id = 271
    user_a_pubkey = user_a_id + pubkey_prefix
    # Check that the data is stored correctly for a random user.
    r = await registry.get_user_info(
        user_a_id, user_a_pubkey).call()
    assert r.result.user_data == sample_data

    # Check that the data decoding function works.
    # Only dummy values are implemented so far.
    # Weapon score
    r = await registry.unpack_score(user_a_id,
        weapon_strength_index).call()
    assert r.weapon_score == 3
    # Ring score
    r = await registry.unpack_score(user_a_id,
        ring_bribe_index).call()
    assert r.result.score == 1


