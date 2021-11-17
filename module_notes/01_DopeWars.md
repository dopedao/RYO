
## Introduction


The Dope Wars universe is an open-ended project with many limbs. The
game engine seeks build the classic calculator game in the blockchain
environment. The game design seeks to enable gameplay similar to the
original experience, while also being expandable in other dimensions.

At a high level, this means players:

- Try to increase their inventory by swapping assets. By trading
cleverly they can out-compete other players.
    - Trades are against non-playable dealers in different locations.
    - 19 cities with 4 districts each.
    - Dealers have 19 drugs in different inventories and administer trades
    using automated market maker rules.
    - The game is unstable, with hard-to-predict events creating
    risk of personal loss and also trade opportunity.

Additional elements may be added through a mechanism outlined below.
One element being explored is auto-battler combat mechanism that
is used to appoint a Drug Lord in each region.

- Try to dethrone the local drug lord with a hand-crafted battler.
    - Each city has a drug lord who takes a cut from each trade.
    - Drug lords a appointed by battle (king of the hill).

Some dynamics may evolve around:
    - The market is transparent and opportunities openly visible.
    - Probabalistic events cause chaos and shake up the market.
    - Submitted drug lord battlers must take into account the current
    drug lord stats, but also defend against future challengers.

Expansions may be integrated to build out different elements into
complementary game play environments that read +/- write to the
same game state.


### Game play

Users will be defined by their Account contract address later.
For now, manually declare the `user_id`.

User `733` goes to location `34` to buy (sell is `1`,
buy is `0`) item `5`, giving `1000` units (of money), receiving whatever
that purchases.
```
bin/shell nile invoke 01_DopeWars have_turn 733 34 0 5 1000
```
Calling the `check_user_state()` function again reveals that the `100` units were
exchanged for some quantity of money.

```
bin/shell nile call 01_DopeWars check_user_state 733
```
Alternatively, see and do all of the above with the Voyager browser
[here](https://voyager.online).

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
user_1 -> (separate transaction, separate game module)
        fight current drug lord
            use combo of NFT + custom_fighter traits
            user also provides list of current winner traits.
            autobattle happens, drug lord appointed.
            drug lord gets a cut of trades in trading module.
user2 -> (same as user_1)
```