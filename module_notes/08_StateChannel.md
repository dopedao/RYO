# Introduction

State channels allow very large quantities of messages to be passed
between two users who are online. This might be some move-by-move
interaction in a game.

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