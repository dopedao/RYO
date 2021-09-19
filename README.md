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
Cairo programs), creates and aggregates validity proofs, then posts them
to the Goerli Ethereum testnet. Learn more in the Cairo language and StarkNet
docs [here](https://www.cairo-lang.org/docs/), which also has instructions for manual
installation if you are not using docker.

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
bin/shell starknet-compile contracts/GameEngineV1.cairo \
    --output contracts/GameEngineV1_compiled.json \
    --abi abi/GameEngineV1_contract_abi.json

bin/shell starknet-compile contracts/MarketMaker.cairo \
    --output contracts/MarketMaker_compiled.json \
    --abi abi/MarketMaker_contract_abi.json
```

### Test

```
bin/shell pytest testing/GameEngineV1_contract_test.py

bin/shell pytest testing/MarketMaker_contract_test.py
```

### Deploy

```
bin/shell starknet deploy --contract contracts/GameEngineV1_compiled.json \
    --network=alpha

bin/shell starknet deploy --contract contracts/MarketMaker_compiled.json \
    --network=alpha
```

Upon deployment, the CLI will return an address, which can be used
to interact with.

Check deployment status by passing in the transaction ID you receive:
```
bin/shell starknet tx_status --network=alpha --id=176230
```
`PENDING` Means that the transaction passed the validation and is waiting to be sent on-chain.
```
{
    "block_id": 18880,
    "tx_status": "PENDING"
}
```
### Interact

CLI - Write (initialise markets). Set up `item_id=5` across all 40 locations.
Each pair has 10x more money than item quantity. All items have the same curve

```
bin/shell starknet invoke \
    --network=alpha \
    --address 0x01c721e3452005ddc95f10bf8dc86c98c32a224085c258024931ddbaa8a44557 \
    --abi abi/GameEngineV1_contract_abi.json \
    --function admin_set_pairs_for_item \
    --inputs 5 \
        40 \
        20 40 60 80 100 120 140 160 180 200 \
        220 240 260 280 300 320 340 360 380 400 \
        420 440 460 480 500 520 540 560 580 600 \
        620 640 660 680 700 720 740 760 780 800 \
        40 \
        200 400 600 800 1000 1200 1400 1600 1800 2000 \
        2200 2400 2600 2800 3000 3200 3400 3600 3800 4000 \
        4200 4400 4600 4800 5000 5200 5400 5600 5800 6000 \
        6200 6400 6600 6800 7000 7200 7400 7600 7800 8000
```
Change `5` to another `item_id` in the range `1-10` to populate other curves.

CLI - Write (initialize user). Set up `user_id=733` to have `2000` of item `5`.
```
bin/shell starknet invoke \
    --network=alpha \
    --address 0x01c721e3452005ddc95f10bf8dc86c98c32a224085c258024931ddbaa8a44557 \
    --abi abi/GameEngineV1_contract_abi.json \
    --function admin_set_user_amount \
    --inputs 733 5 2000
```
CLI - Read (user state)
```
bin/shell starknet call \
    --network=alpha \
    --address 0x01c721e3452005ddc95f10bf8dc86c98c32a224085c258024931ddbaa8a44557 \
    --abi abi/GameEngineV1_contract_abi.json \
    --function check_user_state \
    --inputs 733
```
CLI - Write (Have a turn). User `733` goes to location `34` to sell (sell is `1`,
buy is `0`) item `5`, giving `100` units.
```
bin/shell starknet invoke \
    --network=alpha \
    --address 0x01c721e3452005ddc95f10bf8dc86c98c32a224085c258024931ddbaa8a44557 \
    --abi abi/GameEngineV1_contract_abi.json \
    --function have_turn \
    --inputs 733 34 1 5 100
```
Calling the `check_user_state()` function again reveals that the `100` units were
exchanged for some quantity of money.

Alternatively, see and do all of the above with the Voyager browser [here](https://voyager.online/contract/0x01c721e3452005ddc95f10bf8dc86c98c32a224085c258024931ddbaa8a44557#writeContract).

## Game flow

```
admin ->
        initialise state variables
        lock admin power
user_1 ->
        have_turn(got_to_loc, trade_x_for_y)
            check if game finished.
            check user authentification.
            check if user allowed using game clock.
            add to random seed.
            user location update.
                decrease money count if new city.
            check for dealer dash (x %).
                check for chase dealer (x %).
                    item lost, no money gained.
            trade with market curve for location.
                decrease money/item, increase the other.
            check for any of:
                mugging (x %).
                    check for run (x %).
                        lose a percentage of money.
                gang war (x %).
                    check for fight (x %).
                        lose a percentage of money.
                cop raid (x %).
                    check for bribe (x %).
                        lose percentage of money & items held.
                find item (x %).
                    increase item balance.
                local shipment (x %).
                    increase item counts in suburb curves.
                warehouse seizure (x %).
                    decrease item counts in suburb curves.
            save next allowed turn as game_clock + n.
user2 -> (same as user_1)
```

## Next steps

Building out parts to make a functional `v1`. Some good entry-level options
for anyone wanting to try out Cairo.

- Initialised multiple player states.
- Turn rate limiting. Game has global clock that increments every time
    a turn occurs. User has a lockout of x clock ticks.
- Game end criterion based on global clock.
- Finish `mappings/locations.json`. Name places and implement different cost to travel for
some locations.
    - Locations will e.g., be 10 cities [0, 9] each with 4 suburbs [0, 4].
    - E.g., locations 0, 11, 21, 31 are city 1. Locations 2, 12, 22, 32 are
    city 2. So `location_id=27` is city 7, suburb 2. Free to travel to
    other suburbs in same city (7, 17, 37).
    - Need to create a file with nice city/subrub names for these in
- Finish `mappings/items.json`. Populate and tweak the item names and item unit price.
E.g., cocaine price per unit different from weed price per unit.
- Finish `mappings/initial_markets.csv`. Create lists of market pair values to initialize the
game with. E.g., for all 40 locations x 10 items = 400 money_count-item_count pairs as a
separate file. A mapping of 600 units with 6000 money initialises
a dealer in that location with 60 of the item at (6000/60) 100 money per item. This mapping should
be in the ballpark of the value in `items.json`. The fact that values deviate, creates trade
opportunities at the start of the game. (e.g., a location might have large quantity at lower price).
- Refine both the likelihood (basis points per user turn) and impact (percentage
change) that events have and treak the constanst at the top of `contracts/GameEngineV1.cairo`. E.g., how often should you get mugged, how much money would you lose.
- Initialize users with money upon first turn. (e.g., On first turn triggers save
of starting amount e.g., 10,000, then sets the flag to )
- Create caps on maximum parameters (40 location_ids, 10k user_ids, 10 item_ids)
- User authentication. E.g., signature verification.
- Add health clock. E.g., some events lower health


Welcome:

- PRs
- Issues
- Questions about Cairo
- Ideas for the game
