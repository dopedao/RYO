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

bin/shell starknet-compile contracts/UserRegistry.cairo \
    --output contracts/UserRegistry_compiled.json \
    --abi abi/UserRegistry_contract_abi.json
```

### Test

```
bin/shell pytest -s testing/GameEngineV1_contract_test.py

bin/shell pytest -s testing/MarketMaker_contract_test.py

bin/shell pytest -s testing/UserRegistry_contract_test.py
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

Alternatively, see and do all of the above with the Voyager browser
[here](https://voyager.online/contract/0x01c721e3452005ddc95f10bf8dc86c98c32a224085c258024931ddbaa8a44557#writeContract).

## Game flow

```
admin ->
        create L1 snapshot, build Merkle tree, save to L2.
        initialise L2 state variables.
        lock admin power.

Once-off registrarion:
user_1 ->
        register_for_game(my_L1_address, my_chosen_DOPE_ID)

Routine play:
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

Non-coding tasks:

- Use [this google sheet](https://docs.google.com/spreadsheets/d/1-qIYqnk0MJ6y9x7LcxW-OezpXjPwy7GFL3VbZdQnlmc/edit#gid=0) to CTRL-F the counts for the items in
`mappings/thingxyz_score.csv` (final column in each document) to help inform score creation.
Could also script it, but probably takes just as long.
    - The counts are 'total in sheet', and
are a rough guide, so don't worry about a single DOPE having 2x "murdertown" items - just count
it as 2 for simplicity.
    - Need to account for name clashes during searching:
        - Drug 'soma', place 'SOMA'.
        - Shoe 'Air Jordan 1 Chicagos', place 'Chicago'.
    - This may really be unecessary if items are distributed evenly and have the same ballpark
    counts. TBC.
- Assign scores to all the DOPE wearables/itmes in `mappings/thingxyz_score.csv`.
E.g., is a `Baseball Bat` or a handgun more powerful, or what is more costly per 'unit'
`Krokodil` or `Oxycontin`. Might also be interesting to look at documenting/using the
rarity of each of these items to help inform the score.
- Create names for all the districts in `mappings/location_travel.csv`.
The names can be creative rather than strictly factual. Four districts per region.
    - We started to make new regions (Miami, Medellin, New York & Los Angeles),
    but no DOPE NFTs directly link to these. Need to decide if we want to stick to
    the NFT fields or keep these (+/- add more). Leaning toward sticking to NFT.
    If keeping them, need to check for clashes/overlap in the first four vs the remaining and tweak the first if need be.
- Assign a cost-to-travel for regions in `mappings/location_travel.csv`. Traveling to different
districts within a region is free.
    - Cost is relative (can be scaled depending on how much money people have in the game).
    Cost is a rough number - may reflect a combination of distance and other factors.
    - Code note: Locations are implemented as follows:
        - Currently the game architecture has 40 Locations with be 10 cities/regions [0, 9]
        each with 4 suburbs/districts [0, 4].
        - E.g., locations 0, 11, 21, 31 are city 1. Locations 2, 12, 22, 32 are
        city 2. So `location_id=27` is city 7, suburb 2. Free to travel to
        other suburbs in same city (7, 17, 37).
        - The city number will be adusted to match the final row count in
        `mappings/location_travel.csv`.
    - It may be interesting to look at statistics on distribution of the locations amongst
    DOPE NFTs. How often do all the locations appear? Does it make sense for the game to use
    this as a player trait (e.g., player from x has some benefit in location x).
- Fill out `mappings/initial_markets_cost_rel_100.csv` with how
much items should start of costing in a certain area, where 100 is 'average' and 120 is 20% above
average, 80 is 20% below average.
- Fill out `mappings/initial_markets_quantity_rel_100.csv` with how
many items should start of in a certain area, where 100 is 'average' and 120 is 20% above
average, 80 is 20% below average. Areas can have different profiles, with different combinations of quantity and price
at the start of the game to create a different vibe/market dynamic. Will be good to just get
some rought numbers down and try it out.

Quick-coding tasks:

- Initialised multiple player states.
- Turn rate limiting. Game has global clock that increments every time
    a turn occurs. User has a lockout of x clock ticks.
- Game end criterion based on global clock.
- Update the `item_id`s in `GameEngineV1` to be in range 1-19 to reflect `mappings/drugs_value.csv`.

Coding tasks:

- Refine both the likelihood (basis points per user turn) and impact (percentage
change) that events have and treak the constant at the top of `contracts/GameEngineV1.cairo`.
E.g., how often should you get mugged, how much money would you lose.
- Initialize users with money upon first turn. (e.g., On first turn triggers save
of starting amount e.g., 10,000, then sets the flag to )
- Create caps on maximum parameters (40 location_ids, 10k user_ids, 10 item_ids)
- User authentication. E.g., signature verification.
- Apply modifiers to the events based on the held-items scores (`mappings/thingxyz_score.csv`).
    - Run: Shoes and vehicle scores.
    - Fight: Weapon score.
    - Bribe: Necklace and Ring score.
- More testing of held-item binary encoding implementation in `UserRegistry`

Maybe tasks:

- Add health clock. E.g., some events lower health


Welcome:

- PRs
- Issues
- Questions about Cairo
- Ideas for the game
