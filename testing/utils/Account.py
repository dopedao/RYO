from utils.Signer import Signer

ACCOUNT_PATH = "contracts/Account.cairo"

# A deployed contract-based account with nonce awareness.
class Account():
    # Initialize with signer. Deploy separately.
    def __init__(self, private_key, L1_address):
        self.signer = Signer(private_key)
        self.L1_address = L1_address
        self.address = 0
        self.contract = None

    def __str__(self):
        addr = hex(self.address)
        pubkey = hex(self.signer.public_key)
        return f'Account with address {addr[:6]}...{addr[-4:]} and \
signer public key {pubkey[:6]}...{pubkey[-4:]}'

    # Deploy. Creates a contract and initializes.
    async def create(self, starknet):
        contract = await starknet.deploy(ACCOUNT_PATH)
        self.contract = contract
        self.address = contract.contract_address
        await contract.initialize(self.signer.public_key,
            self.L1_address).invoke()

    # Transact. Signs and sends a transaction using latest nonce.
    async def tx_with_nonce(self, to, selector_name, calldata):
        (nonce, ) = await self.contract.get_nonce().call()
        transaction = await self.signer.build_transaction(
            account=self.contract,
            to=to,
            selector_name=selector_name,
            calldata=calldata,
            nonce=nonce
        ).invoke()
        return transaction
