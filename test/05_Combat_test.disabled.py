import pytest
import asyncio
from fixtures.account import account_factory

NUM_SIGNING_ACCOUNTS = 2

# Combat stats.
USER_COMBAT_STATS = [5]*16
DRUG_LORD_STATS = [3]*16

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
async def test_combat(game_factory):
    starknet, accounts, signers, arbiter, controller, engine, \
        location_owned, user_owned, registry, combat = game_factory
    user = accounts[1]
    user_signer = signers[1]

    user_combat_stats = [8]*16
    drug_lord_combat_stats = [5]*16

    await user_signer.send_transaction(
        account=user,
        to=combat.contract_address,
        selector_name='challenge_current_drug_lord',
        calldata=user_combat_stats + drug_lord_combat_stats)

    # TODO: Implement the battle and historical save function
    user_id=0
    r = await combat.view_combat(user_id)
    c = r.result.combat_details
    assert c.winner == 0
    assert c.move_sequence_3 == 0

