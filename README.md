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

### Compile

The compiler will check the integrity of the code locally.
It will also produce an ABI, which is a mapping of the contract functions
(used to interact with the contract).

Compile all contracts:
```
bin/compile
```

Compile an individual contract:
```
starknet-compile contracts/GameEngineV1.cairo \
    --output artifacts/compiled/GameEngineV1.json \
    --abi artifacts/abi/GameEngineV1_abi.json
```

### Test

Run all github actions tests: `bin/test`

Run individual tests
```
bin/shell pytest -s testing/GameEngineV1_contract_test.py

bin/shell pytest -s testing/MarketMaker_contract_test.py

bin/shell pytest -s testing/UserRegistry_contract_test.py
```

### Deploy

The deploy script deploys all the contracts and exports the addresses
in the form `ContractNameAddress` to the current environment.

```
. bin/deploy
```
See deployed addresses [here](deployed_addresses.md)
```

```
Check deployment status by passing in the transaction ID you receive:
```
bin/shell starknet tx_status --network=alpha --id=TRANSACTION_ID
```
`PENDING` Means that the transaction passed the validation and is waiting to be sent on-chain.

### Admin initialisation

Save deployment addresses into the game contract and
then save the initial market state, pulling values from the
`mappings/inital_markets_*.csv`
```
TODO: Complete/fix this script.
bin/set_initial_values
```

### Have turn

Users will be defined by their Account contract address later.
For now, manually declare the `user_id`.

User `733` goes to location `34` to buy (sell is `1`,
buy is `0`) item `5`, giving `1000` units (of money), receiving whatever
that purchases.
```
bin/shell starknet invoke \
    --network=alpha \
    --address $GameEngineV1Address \
    --abi abi/GameEngineV1_contract_abi.json \
    --function have_turn \
    --inputs 733 34 0 5 1000
```
Calling the `check_user_state()` function again reveals that the `100` units were
exchanged for some quantity of money.

```
bin/shell starknet call \
    --network=alpha \
    --address $GameEngineV1Address \
    --abi abi/GameEngineV1_contract_abi.json \
    --function check_user_state \
    --inputs 733
```
Alternatively, see and do all of the above with the Voyager browser
[here](https://voyager.online/contract/ADDRESS).

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
            give user money if first turn.
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
- Make the bash script `bin/set_initial_values` pass the initial
market values as a list (rather than string).

Coding tasks:

- Refine both the likelihood (basis points per user turn) and impact (percentage
change) that events have and treak the constant at the top of `contracts/GameEngineV1.cairo`.
E.g., how often should you get mugged, how much money would you lose.
- Make the market initialisation function smaller (exceeded pedersen builtin, tx_id=302029). E.g., break it into 8 separate transactions.
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

Design considerations/todo

- Add health clock. E.g., some events lower health
- Outline combat mechanics, inputs and structure
- Consider how side games between turns could be used to inform
actions on next turn.


Welcome:

- PRs
- Issues
- Questions about Cairo
- Ideas for the game
