import sys
import os
import time
import asyncio
import pytest
import dill
from types import SimpleNamespace

from starkware.starknet.compiler.compile import compile_starknet_files
from starkware.starknet.testing.starknet import Starknet, StarknetContract
from starkware.starknet.business_logic.state.state import BlockInfo

from utils.Signer import Signer

# pytest-xdest only shows stderr
sys.stdout = sys.stderr

CONTRACT_SRC = os.path.join(os.path.dirname(__file__), "..", "contracts")


def compile(path):
    return compile_starknet_files(
        files=[os.path.join(CONTRACT_SRC, path)],
        debug_info=True,
        # cairo_path=CONTRACT_SRC,
    )


def get_block_timestamp(starknet_state):
    return starknet_state.state.block_info.block_timestamp


def set_block_timestamp(starknet_state, timestamp):
    starknet_state.state.block_info = BlockInfo(
        starknet_state.state.block_info.block_number, timestamp, 0
    )


async def deploy_account(starknet, signer, account_def):
    return await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key],
    )


# StarknetContracts contain an immutable reference to StarknetState, which
# means if we want to be able to use StarknetState's `copy` method, we cannot
# rely on StarknetContracts that were created prior to the copy.
# For this reason, we specifically inject a new StarknetState when
# deserializing a contract.
def serialize_contract(contract, abi):
    return dict(
        abi=abi,
        contract_address=contract.contract_address,
        deploy_execution_info=contract.deploy_execution_info,
    )


def unserialize_contract(starknet_state, serialized_contract):
    return StarknetContract(state=starknet_state, **serialized_contract)


@pytest.fixture(scope="session")
def event_loop():
    return asyncio.new_event_loop()


async def build_copyable_deployment():
    starknet = await Starknet.empty()

    # initialize a realistic timestamp
    set_block_timestamp(starknet.state, round(time.time()))

    defs = SimpleNamespace(
        account=compile("Account.cairo"),
        arbiter=compile("Arbiter.cairo"),
        controller=compile("ModuleController.cairo"),
        engine=compile("01_DopeWars.cairo"),
        location_owned=compile("02_LocationOwned.cairo"),
        user_owned=compile("03_UserOwned.cairo"),
        registry=compile("04_UserRegistry.cairo"),
        combat=compile("05_Combat.cairo"),
        drug_lord=compile("06_DrugLord.cairo"),
        pseudorandom=compile("07_PseudoRandom.cairo")
    )

    signers = dict(
        admin=Signer(83745982347),
        unregistered=Signer(69420),
        alice=Signer(7891011),
        bob=Signer(12345),
        carol=Signer(888333444555),
        dave=Signer(897654321),
        eric=Signer(6969),
        frank=Signer(23904852345),
        grace=Signer(215242342),
        hank=Signer(420),
        
        user1=Signer(1),
        user2=Signer(2),
        user3=Signer(3),
        user4=Signer(4),
        user5=Signer(5),
        user6=Signer(6),
        user7=Signer(7),
    )

    # Maps from name -> account contract
    accounts = SimpleNamespace(
        **{
            name: (await deploy_account(starknet, signer, defs.account))
            for name, signer in signers.items()
        }
    )

    # The Controller is the only unchangeable contract.
    # First deploy Arbiter.
    # Then send the Arbiter address during Controller deployment.
    # Then save the controller address in the Arbiter.
    # Then deploy Controller address during module deployments.
    arbiter = await starknet.deploy(
        contract_def=defs.arbiter,
        constructor_calldata=[accounts.admin.contract_address])

    controller = await starknet.deploy(
        contract_def=defs.controller,
        constructor_calldata=[arbiter.contract_address])

    await signers["admin"].send_transaction(
        account=accounts.admin,
        to=arbiter.contract_address,
        selector_name='set_address_of_controller',
        calldata=[controller.contract_address])

    engine = await starknet.deploy(
        contract_def=defs.engine,
        constructor_calldata=[controller.contract_address])

    location_owned = await starknet.deploy(
        contract_def=defs.location_owned,
        constructor_calldata=[controller.contract_address])

    user_owned = await starknet.deploy(
        contract_def=defs.user_owned,
        constructor_calldata=[controller.contract_address])

    registry = await starknet.deploy(
        contract_def=defs.registry,
        constructor_calldata=[controller.contract_address])

    combat = await starknet.deploy(
        contract_def=defs.combat,
        constructor_calldata=[controller.contract_address])

    drug_lord = await starknet.deploy(
        contract_def=defs.drug_lord,
        constructor_calldata=[controller.contract_address])

    pseudorandom = await starknet.deploy(
        contract_def=defs.pseudorandom,
        constructor_calldata=[controller.contract_address])

    consts = SimpleNamespace(
        CITIES=19,
        DISTRICTS_PER_CITY=4,
        ITEM_TYPES=19
    )

    await signers["admin"].send_transaction(
        account=accounts.admin,
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

    async def register_user(account_name):
        # Populate the registry with some data.
        sample_data = 84622096520155505419920978765481155

        # Repeating sample data
        # Indices from 0, 20, 40, 60, 80..., have values 3.
        # Indices from 10, 30, 50, 70, 90..., have values 1.
        # [00010000010011000011] * 6 == [1133] * 6
        # Populate the registry with homogeneous users (same data each).
        await signers[account_name].send_transaction(
            accounts.__dict__[account_name],
            registry.contract_address,
            'register_user',
            [sample_data]
        )

    await register_user("alice")
    await register_user("bob")
    await register_user("carol")
    await register_user("dave")
    await register_user("eric")
    await register_user("frank")
    await register_user("grace")
    await register_user("hank")

    await register_user("user1")
    await register_user("user2")
    await register_user("user3")
    await register_user("user4")
    await register_user("user5")
    await register_user("user6")
    await register_user("user7")



    return SimpleNamespace(
        starknet=starknet,
        consts=consts,
        signers=signers,
        serialized_contracts=dict(
            admin=serialize_contract(accounts.admin, defs.account.abi),
            unregistered=serialize_contract(
                accounts.unregistered, defs.account.abi),
            alice=serialize_contract(accounts.alice, defs.account.abi),
            bob=serialize_contract(accounts.bob, defs.account.abi),
            carol=serialize_contract(accounts.carol, defs.account.abi),
            dave=serialize_contract(accounts.dave, defs.account.abi),
            eric=serialize_contract(accounts.eric, defs.account.abi),
            frank=serialize_contract(accounts.frank, defs.account.abi),
            grace=serialize_contract(accounts.grace, defs.account.abi),
            hank=serialize_contract(accounts.hank, defs.account.abi),
            
            user1=serialize_contract(accounts.user1, defs.account.abi),
            user2=serialize_contract(accounts.user2, defs.account.abi),
            user3=serialize_contract(accounts.user3, defs.account.abi),
            user4=serialize_contract(accounts.user4, defs.account.abi),
            user5=serialize_contract(accounts.user5, defs.account.abi),
            user6=serialize_contract(accounts.user6, defs.account.abi),
            user7=serialize_contract(accounts.user7, defs.account.abi),


            arbiter=serialize_contract(arbiter, defs.arbiter.abi),
            controller=serialize_contract(controller, defs.controller.abi),
            engine=serialize_contract(engine, defs.engine.abi),
            location_owned=serialize_contract(
                location_owned, defs.location_owned.abi),
            user_owned=serialize_contract(user_owned, defs.user_owned.abi),
            registry=serialize_contract(registry, defs.registry.abi),
            combat=serialize_contract(combat, defs.combat.abi),
            drug_lord=serialize_contract(drug_lord, defs.drug_lord.abi),
            pseudorandom=serialize_contract(
                pseudorandom, defs.pseudorandom.abi),
        ),
    )


@pytest.fixture(scope="session")
async def copyable_deployment(request):
    CACHE_KEY = "deployment"
    val = request.config.cache.get(CACHE_KEY, None)
    if val is None:
        val = await build_copyable_deployment()
        res = dill.dumps(val).decode("cp437")
        request.config.cache.set(CACHE_KEY, res)
    else:
        val = dill.loads(val.encode("cp437"))
    return val


@pytest.fixture(scope="session")
async def ctx_factory(copyable_deployment):
    serialized_contracts = copyable_deployment.serialized_contracts
    signers = copyable_deployment.signers
    consts = copyable_deployment.consts

    def make():
        starknet_state = copyable_deployment.starknet.state.copy()
        contracts = {
            name: unserialize_contract(starknet_state, serialized_contract)
            for name, serialized_contract in serialized_contracts.items()
        }

        async def execute(account_name, contract_address, selector_name, calldata):
            return await signers[account_name].send_transaction(
                contracts[account_name],
                contract_address,
                selector_name,
                calldata,
            )

        def advance_clock(num_seconds):
            set_block_timestamp(
                starknet_state, get_block_timestamp(
                    starknet_state) + num_seconds
            )

        return SimpleNamespace(
            starknet=Starknet(starknet_state),
            advance_clock=advance_clock,
            consts=consts,
            execute=execute,
            **contracts,
        )

    return make
