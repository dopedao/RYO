# RYO
Dope Wars game engine on StarkNet L2 roll-up.

## What

TI-83 drug wars built as smart contract system.

Background mechanism design notion [here](https://dope-wars.notion.site/dope-22fe2860c3e64b1687db9ba2d70b0bb5).

Initial exploration / walkthrough viability testing blog [here](https://perama-v.github.io/cairo/game/world).

Join in and learn about:

    - Cairo. A turing-complete language for programs that become proofs.
    - StarkNet. An Ethereum L2 rollup with:
        - L1 for data availability
        - State transitions executed by validity proofs that the EVM checks.

## Setup

Clone this repo, make and activate environment, install the Cairo language, check teh StarkNet CLI.

```
git clone git@github.com:dopedao/RYO.git
cd RYO
python3.7 -m venv ./venv
source venv/bin/activate
pip install cairo-lang
starknet
```
If installed properly, the CLI menu should appear.

The CLI allows you to deploy to StarkNet and read/write to contracts
already deployed. The CLI communicates with a server that StarkNet
run, who bundle the request, execute the program (contracts are
Cairo programs), create and aggregated validity proofs, then post that
to Goerli Ethereum testnet. Learn more in the [Cairo language and StarkNet docs](https://www.cairo-lang.org/docs/)

If using VS-code for writing code, install the extension for syntax highlighting:
```
curl -LO https://github.com/starkware-libs/cairo-lang/releases/download/v0.4.0/cairo-0.4.0.vsix
code --install-extension cairo-0.4.0.vsix
code .
```

## Dev

Flow:

1. Compile the contract with the CLI
2. Test using pytest
3. Deploy with CLI
4. Interact using the CLI or the explorer

File name prefixes are paired (e.g., contract, ABI and test all share comon prefix).

### Compile

The compiler will check the integrity of the code locally.
It will also produce an ABI, which is a mapping of the contract functions
(used to interact with the contract).
```
starknet-compile contracts/GameEngineV1.cairo \
    --output contracts/GameEngineV1_compiled.json \
    --abi abi/GameEngineV1_contract_abi.json

starknet-compile contracts/MarketMaker.cairo \
    --output contracts/MarketMaker_compiled.json \
    --abi abi/MarketMaker_contract_abi.json
```

### Test

```
pytest testing/GameEngineV1_contract_test.py

pytest testing/MarketMaker_contract_test.py
```

### Deploy

```
starknet deploy --contract GameEngineV1_compiled.json \
    --network=alpha

starknet deploy --contract MarketMaker_compiled.json \
    --network=alpha
```
Upon deployment, the CLI will return an address, which can be used
to interact with.

Check deployment status by passing in the transaction ID you receive:
```
starknet tx_status --network=alpha --id=143843
```
`PENDING` Means that the transaction passed the validation and is waiting to be sent on-chain.
```
{
    "block_id": 15650,
    "tx_status": "PENDING"
}
```
### Interact

CLI - Write (initialise markets)
```
starknet invoke \
    --network=alpha \
    --address 0x035e5e589f4ef5736b27958f1733c9ee64d12ffeb9ce8cc4019d50911e2685de \
    --abi abi/GameEngineV1_contract_abi.json \
    --function admin_set_market_amount \
    --inputs 7 2 3 10 12000
```
That will randomize the all markets (with the exception of the one specified).

**Dev note:** The market initialization method worked locally, but exceeded the allowable limit in the sequencing service. May have to try in batches / redesign how initialization works.
```
starknet tx_status --network=alpha --id=143902                                                                                                                                                                                          *[engine-loop]
{
    "tx_failure_reason": {
        "code": "INVALID_TRANSACTION",
        "error_message": "Transaction with ID 143902 of type InvokeFunction is too big for batch. Exception details: No room for transaction due to pedersen_builtin reaching capacity. Value: 390180.0. Limit: 125000.0. Note that this is the first transaction in the batch; meaning, batch will not be closed.",
        "tx_id": 143902
    },
    "tx_status": "REJECTED"
}
```


CLI - Write
```
starknet invoke \
    --network=alpha \
    --address 0x035e5e589f4ef5736b27958f1733c9ee64d12ffeb9ce8cc4019d50911e2685de \
    --abi abi/GameEngineV1_contract_abi.json \
    --function admin_set_user_amount \
    --inputs 733 3 200
```
CLI - Read
```
starknet call \
    --network=alpha \
    --address 0x035e5e589f4ef5736b27958f1733c9ee64d12ffeb9ce8cc4019d50911e2685de \
    --abi abi/GameEngineV1_contract_abi.json \
    --function check_user_state \
    --inputs 733
```
Or with the Voyager browser [here](https://voyager.online/contract/0x035e5e589f4ef5736b27958f1733c9ee64d12ffeb9ce8cc4019d50911e2685de#writeContract).

## Next steps

Building out parts to make a functional `v1`.

- Initialised player state
- Random theft
- Cost to travel
- Turn rate limiting
- User authentication

Welcome:

- PRs
- Issues
- Questions about Cairo
- Ideas for the game