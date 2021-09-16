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

Clone this repo and use our docker shell to interact with starknet:

```
git clone git@github.com:dopedao/RYO.git
cd RYO
bin/shell starknet --version
```

The CLI allows you to deploy to StarkNet and read/write to contracts
already deployed. The CLI communicates with a server that StarkNet
runs, which bundles the requests, executes the program (contracts are
Cairo programs), creates and aggregates validity proofs, then post them
to the Goerli Ethereum testnet. Learn more in the [Cairo language and StarkNet docs](https://www.cairo-lang.org/docs/)

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

### Interact

CLI - Write

```
starknet invoke \
    --network=alpha \
    --address 0x02c9163ce5908b12a1d547e736f8ab6f5543f6ef1fd4994c7f1b146087f3279a \
    --abi GameEngineV1_contract_abi.json \
    --function admin_set_user_amount \
    --inputs 733 3 200
```

CLI - Read

```
starknet call \
    --network=alpha \
    --address 0x02c9163ce5908b12a1d547e736f8ab6f5543f6ef1fd4994c7f1b146087f3279a \
    --abi GameEngineV1_contract_abi.json \
    --function check_user_state \
    --inputs 733
```

Or with the Voyager browser [here](https://voyager.online/contract/0x02c9163ce5908b12a1d547e736f8ab6f5543f6ef1fd4994c7f1b146087f3279a#writeContract).

## Next steps

Building out parts to make a functional `v1`.

- Initialised state
- Random theft
- Cost to travel
- Turn rate limiting
- User authentication

Welcome:

- PRs
- Issues
- Questions about Cairo
- Ideas for the game
