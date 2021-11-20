# Introduction

State channels allow very large quantities of messages to be passed
between two users who are online. These messages can represent
some move-by-move interaction in a game. The outcome of the interaction
plugs in to the broader stateful game module system.

## History

Historically, state channels have
been exensively explored as a scaling solution. The novel construction
that is potentially feasible is state channels built on L2.

Issues with state channels and the possible impact of L2 based channels:

- Require parties to be online (or have watchtower infrasturcture)
    - Game players will be online for the duration of the channel
- Require capital lockup to enforce good behaviour
    - Game players can commit to the conditions of opening a channel,
    which could include a reward/penalty as incentive to behave.
- Require generalised state channel constructions in order to avoid high
    burdens of closing a channel. Generalised state channels enable you to
    build a channel that can open/close channels without closing the base channel.
    Generalised state channels are complex in this regard.
    - Game players will close the channel with cheap L2 transactions.
    Channels can therefore be application-specific and simple.

## Layer 3

There are three layers:

- L1 Ethereum
- L2 StarkNet Rollup
- L3 State channel
    - Channel limitations are mitigated by the low cost of L2 transactions.

## Application example - 1v1 channel battle.

1. Player 1 sends an L2 transaction signalling intent to battle.
2. Player 2 sees that transaction and notes that the player is in the same
location. They send an L2 transaction to commence a battle.
3. The contract:
    - Checks that players are in the same location
    - Checks that player 1 sent the transaction within some recent time frame, implying
    they are still available to play. (e.g., 20 mins)
    - Opens a channel between the two players.
    - Starts a counter for the termination of the channel (e.g., 10 mins).
4. The fronted for both players identifies the channel has been opened.
5. A path to send messages between player computers is created.
6. The game begins and the players start sending signed messages according to the game
rules. For instance, this could be movement, defence & attack instructions.
7. The channel is closed by either player sending an L2 channel, and the final state
of the game (e.g., health) is updated and stored on L2.

# Considerations

All the usual state channel attack scenarios need to be considered. E.g.,
griefing etc. Because the games are short-lived and cheap, it may be reasonable
to implement simple rules to encourage participation. The channel-based fights end up
changing state within the broader modular game system, and so a player who repeatedly
engages in successful/unsuccessful channels can be rewarded/penalised easily.

Good reading can be found:

- Concise summary and example contract [here](https://programtheblockchain.com/posts/2018/05/11/state-channels-for-two-player-games/)
- A end-to-end state channel dice game setup [here](https://medium.com/ethereum-developers/how-to-create-scalable-dapps-and-smart-contracts-in-ethereum-with-state-channels-step-by-step-48e12481fb)
- FunFair's overview of main considerations [here](https://funfair.io/a-reference-implementation-of-state-channel-contracts/)


## One player disappears

If a player doesn't like the way a game is going they can stop sending messages
and go offline. The remaining player can update the state of the game
by making and L2 transaction.

## Stale state submission

If a player likes an older game state and tries to submit that to L2, the
state is updated but a window period allows the other player to receive
an alert. The other player then submits a fresher state and the window
period extends.

# Messaging architecture

Messages are signed and passed offline, but can also be sent to L2.

Background work:

- Magmo [commitment.sol](https://github.com/magmo/force-move-protocol/blob/master/packages/fmg-core/contracts/Commitment.sol)

# Game implementations

Ideas for how a state channel can be used to create meaningful play

## Streetfighter

Well known concept. Channels uniquely enable moves to be handled peer-to-peer.
Hustlers have sprites in n different positions representing different move actions:

Sprites:

- Jump
- Punch
- Duck
- Special (unique weapon)
- Walk

Game play is defined by a position (x axis) and a move. Moves can be capped
at +/- 3 tiles.

- Player A is in x=3
- Player B is in x=5

Sequence example, with messages corresponding to alternating
signed messages where AJ-1 is player jump back one tile

AJ-1 BW2 AP BP AD BW-2 ...

## Gear hunter

Players are walking around a game map looking for items. The channel
has the capacity to mint n (e.g., n=3) unique artifacts. The players must
pass each other movements to find the items first.

When the channel is created each player submits a seed that is combined to initialise
the locations of the items. Players explore the map and become the
owner of any item contained within that map tile.

The treasure is a game item that is useful elsewhere in current or future modules:

- Drugs/money submitted by participants
- Artifacts as funginble/semifunginble/nonfungible tokens. (e.g., health
pack, notoriety cool-offs, stats upgrades, wearables)

The map is defined as a discrete x-y grid (x=100, y=100). Players take turns to move
to each tile. The tile transition rules can include proximity (not allowed near another player)
or trails (cannot cross an opponents trail). So a player could cut another player off
from reachable areas in the map, giving them a higher chance of finding the gear.

Sequence example with messages corresponding to alternating
signed messages where AX2Y-3 is player A moving right 2 and down 3.

AX3Y-1 BX2Y2 AX2Y-1 BX2Y1 ...

The game could be constructed with either:

- Visible gear
    - Players can immediately see the locations of the items
- Invisible gear
    - Players note see the gear, they try to gain as much territory
    as possible to increase the chance of it containing an item.
- Partially visible gear
    - Some are visible, some not

## Drug Deal

**TRADE OFFER DOT JPG**

"I receive 100 COKE"   "You receive 1 KROKODIL and 3 MONEY"

Players engage in a real time heated swap of assets like a barter
in a bazaar. The players make offers for an exchange that the other
can accept. The clock is ticking - if the deal takes too long,
both players are busted.

The players can create bundles and combinations in creative ways
and can update their offers based on the sort of offers they are
receiving.

When a deal is agreed upon, the channel can be closed. Players both benefit
from engaging in a Drug Deal because it
earns them some resource (E.g., skill points, artifacts). The outcome of
the trade however may be good or bad, depending on what can be agreed
upon.

Anything in a players inventory can be traded, and there may be some
limit (e.g., 10% inventory max).

Example offers might be:

- Give 4 XANAX receive 10 MONEY
- Give 4 XANAX and 13 LSD receive 5 PCP and 9 FENTANYL

The players make repeated offers that replace old offers. If an offer
is accepted, it is used to close the channel. If no deal is submitted
on-chain, the players both receive a small penalty.

In this way, the game is one of coordination and compromise.



