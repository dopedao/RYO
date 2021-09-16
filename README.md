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
starknet deploy --contract contracts/GameEngineV1_compiled.json \
    --network=alpha

starknet deploy --contract contracts/MarketMaker_compiled.json \
    --network=alpha
```
Upon deployment, the CLI will return an address, which can be used
to interact with.

Check deployment status by passing in the transaction ID you receive:
```
starknet tx_status --network=alpha --id=151281
```
`PENDING` Means that the transaction passed the validation and is waiting to be sent on-chain.
```
{
    "block_id": 16065,
    "tx_status": "ACCEPTED_ONCHAIN"
}
```
### Interact

CLI - Write (initialise markets). Set up `item_id=5` across all 40 locations,
with locations 1, 11, 21, etc. 2, 12, 22 etc. having identical curves. Each pair has 10x more money than item quantity.
```
starknet invoke \
    --network=alpha \
    --address 0x0605ecb2519a1953425824356435b04364bebd3513e1c34fcb4c75ded01e6b29 \
    --abi abi/GameEngineV1_contract_abi.json \
    --function admin_set_pairs_for_item \
    --inputs 5 \
        40 \
        10 20 30 40 50 60 70 80 90 100 \
        10 20 30 40 50 60 70 80 90 100 \
        10 20 30 40 50 60 70 80 90 100 \
        10 20 30 42 50 60 70 80 90 100 \
        40 \
        100 200 300 400 500 600 700 800 900 1000 \
        100 200 300 400 500 600 700 800 900 1000 \
        100 200 300 400 500 600 700 800 900 1000 \
        100 200 300 444 500 600 700 800 900 1000
```
Change `5` to another `item_id` in the range `1-10` to populate other curves.

CLI - Write (initialize user). Set up `user_id=733` to have `200` of item `5`.
```
starknet invoke \
    --network=alpha \
    --address 0x0605ecb2519a1953425824356435b04364bebd3513e1c34fcb4c75ded01e6b29 \
    --abi abi/GameEngineV1_contract_abi.json \
    --function admin_set_user_amount \
    --inputs 733 5 200
```
CLI - Read (user state)
```
starknet call \
    --network=alpha \
    --address 0x0605ecb2519a1953425824356435b04364bebd3513e1c34fcb4c75ded01e6b29 \
    --abi abi/GameEngineV1_contract_abi.json \
    --function check_user_state \
    --inputs 733
```
CLI - Write (Have a turn). User `733` goes to location `34` to sell (sell is `1`,
buy is `0`) item `5`, giving `100` units.
```
starknet invoke \
    --network=alpha \
    --address 0x0605ecb2519a1953425824356435b04364bebd3513e1c34fcb4c75ded01e6b29 \
    --abi abi/GameEngineV1_contract_abi.json \
    --function have_turn \
    --inputs 733 34 1 5 100
```
Calling the `check_user_state()` function again reveals that the `100` units were
exchanged for `333` money.

Alternatively, see and do all of the above with the Voyager browser [here](https://voyager.online/contract/0x0605ecb2519a1953425824356435b04364bebd3513e1c34fcb4c75ded01e6b29#writeContract).

## Next steps

Building out parts to make a functional `v1`. Some good entry-level options
for anyone wanting to try out Cairo.

- Initialised multiple player states.
- Connect random engine to turn to trigger probabalistic theft.
- Implement cost to travel for some locations.
    - Locations will e.g., be 10 cities each with 4 suburbs.
    - E.g., locations 1-10 are suburb 1. Locations 2, 12, 22, 32 are
    city 2. So `location_id=27` is city 7, suburb 3. Free to travel to
    other suburbs in same city (7, 17, 37).
- Turn rate limiting. Game has global clock that increments every time
    a turn occurs. User has a lockout of x clock ticks.
- Game end criterion based on global clock.
- Create lists of market pair values to initialize the game with. E.g.,
for all 40 locations x 10 items = 400 money_count-item_count pairs as a separate file.
- Initialize users with money upon first turn. (e.g., On first turn triggers save
of starting amount e.g., 10,000, then sets the flag to )
- Create caps on maximum parameters (40 location_ids, 10k user_ids, 10 item_ids)
- User authentication. E.g., signature verification.

Welcome:

- PRs
- Issues
- Questions about Cairo
- Ideas for the game