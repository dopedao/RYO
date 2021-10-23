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

Basics:

- Try to increase your inventory by swapping assets with NPC dealers.
    - 19 cities with 4 districts each. Each district has a
- Try to dethrone the local drug lord with a hand-crafted battler.
    - Each city has a drug lord who takes a cut from each trade.
    - Drug lords a appointed by battle (king of the hill).

## Why

For fun. The game state of this shared calculator game cannot be falsified,
what dynamics does this produce?


Some dynamics may evolve around:

- The market is transparent and opportunities openly visible.
- Probabalistic events cause chaos and shake up the market.
- Submitted drug lord battlers must take into account the current
drug lord stats, but also defend against future challengers.


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
curl -LO https://github.com/starkware-libs/cairo-lang/releases/download/v0.4.2/cairo-0.4.2.vsix
code --install-extension cairo-0.4.2.vsix
code .
```

## Outline

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

bin/shell starknet-compile contracts/Combat.cairo \
    --output contracts/Combat_compiled.json \
    --abi abi/Combat_contract_abi.json
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
### Admin initialisation

Set up initial values for every market curve. Pass two lists,
one for market item quantities, the other for market money quantities,
Ordred first by location_id, then by item_id.

First, collect the market values from the `mappings/` directory.
This script saves them to environment variables `$MARKET_ITEMS` and
`$MARKET_MONEY` in a format that the StarkNet CLI will use.
```
. ./testing/utils/export_markets.sh
```
Then
```
bin/shell starknet invoke \
    --network=alpha \
    --address DEPLOYED_ADDRESS \
    --abi abi/GameEngineV1_contract_abi.json \
    --function admin_set_pairs \
    --inputs 1444 $MARKET_ITEMS 1444 $MARKET_MONEY
```

CLI - Write (initialize user). Set up `user_id=733` to have `2000` of item `5`.
```
bin/shell starknet invoke \
    --network=alpha \
    --address DEPLOYED_ADDRESS \
    --abi abi/GameEngineV1_contract_abi.json \
    --function admin_set_user_amount \
    --inputs 733 5 2000
```
CLI - Read (user state)
```
bin/shell starknet call \
    --network=alpha \
    --address DEPLOYED_ADDRESS \
    --abi abi/GameEngineV1_contract_abi.json \
    --function check_user_state \
    --inputs 733
```
CLI - Write (Have a turn). User `733` goes to location `34` to sell (sell is `1`,
buy is `0`) item `5`, giving `100` units.
```
bin/shell starknet invoke \
    --network=alpha \
    --address DEPLOYED_ADDRESS \
    --abi abi/GameEngineV1_contract_abi.json \
    --function have_turn \
    --inputs 733 34 1 5 100
```
Calling the `check_user_state()` function again reveals that the `100` units were
exchanged for some quantity of money.

Alternatively, see and do all of the above with the Voyager browser
[here](https://voyager.online/contract/DEPLOYED_ADDRESS#writeContract).

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
        have_turn(got_to_loc, trade_x_for_y, custom_fighter)
            check if game finished.
            check user authentification.
            get wearables from registry.
            check if user allowed using game clock.
            fight current drug lord
                use combo of NFT + custom_fighter traits
                user also provides list of current winner traits
                autobattle happens, drug lord appointed
                drug lord gets a cut of trades
            add to random seed.
            modify event probabilites based on wearables.
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

- Assign different places 'cost to travel' in `mappings/location_travel.csv`. Doesn't have to be pure geographical.
- Review the names of the 'districts' in `mappings/location_travel.csv`. Add interesting
ones and remove ones that aren't as fun. The regions names are fixed.
- Revise/sssign scores to all the DOPE wearables/itmes in `mappings/thingxyz_score.csv`.
E.g., is a `Baseball Bat` or a handgun more powerful, or what is more costly per 'unit'
`Krokodil` or `Oxycontin`. Might also be interesting to look at documenting/using the
rarity of each of these items to help inform the score.
- Create new `mappings/thingxyz_score.csv` for the missing categories (clothes, waist
armor, name suffixes, etc.).

Quick-coding tasks:

- Add a check for when a user has first turn, gives them money (e.g., 20k).
This allows for open number of players. Remove `admin_set_user_amount` and `loop_users`.
- Game end criterion based on global clock.
- Potentially separate out tests into different files to reduce the time required for tests.

Coding tasks:

- Refine both the likelihood (basis points per user turn) and impact (percentage
change) that events have and treak the constant at the top of `contracts/GameEngineV1.cairo`.
E.g., how often should you get mugged, how much money would you lose.
- Initialize users with money upon first turn. (e.g., On first turn triggers save
of starting amount e.g., 10,000, then sets the flag to )
- Create caps on maximum parameters (40 location_ids, 10k user_ids, 10 item_ids)
- User authentication. E.g., signature verification.
- More testing of held-item binary encoding implementation in `UserRegistry`
- More testing of effect of wearables on event occurences.
- Write a script that populates `mappings/initial_markets_item.csv`
and `mappings/initial_markets_money.csv` in a way that is interesting. The
values are currently randomised in [50, 150]. The script could incorporate
factors such as a normal value for the drug. It ideally implements some sort
of system where places have different market dynamics. E.g.,:
    - A city (all four districts) can have low drug quantity, or high drug quantity, or have
    a few drugs that is has a high quantity of.
    - A city can have a high amount of money but low quantity of drugs.
    - Low quantity of all drugs, low prices.
    - High quantity of some drugs, high prices.
- Think about the mechanics of the battles in `Combat.cairo`.
    - How many variables,what they are, how to create a system that
    forces users to be creative and make tradeoffs in the design of their combat submissions. (e.g., the values they submit during their turn).
    - Think about how to integrate the non-flexible combat
    atributes that come from the Hustler (1 item per slot). E.g., how
    should combate integrate the score that each item has.



Maybe tasks:

- Add health clock. E.g., some events lower health


Welcome:

- PRs
- Issues
- Questions about Cairo
- Ideas for the game
