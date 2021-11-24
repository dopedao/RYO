import pytest
from starkware.starknet.testing.starknet import Starknet
from utils.Signer import Signer

# Create signers that use a private key to sign transaction objects.
DUMMY_PRIVATE = 123456789987654321

@pytest.fixture(scope='module')
async def account_factory(request):
    num_signers = request.param.get("num_signers", "1")
    starknet = await Starknet.empty()
    accounts = []
    signers = []

    print(f'Deploying {num_signers} accounts...')
    for i in range(num_signers):
        signer = Signer(DUMMY_PRIVATE + i)
        signers.append(signer)
        account = await starknet.deploy(
            "contracts/Account.cairo",
            constructor_calldata=[signer.public_key]
        )
        await account.initialize(account.contract_address).invoke()
        accounts.append(account)

        print(f'Account {i} is: {hex(account.contract_address)}')

    # Initialize network

    # Admin is usually accounts[0], user_1 = accounts[1].
    # To build a transaction to call func_xyz(arg_1, arg_2)
    # on a TargetContract:

    # await Signer.send_transaction(
    #   account=accounts[1],
    #   to=TargetContract,
    #   selector_name='func_xyz',
    #   calldata=[arg_1, arg_2],
    #   nonce=current_nonce)

    # Note that nonce is an optional argument.
    return starknet, accounts, signers
