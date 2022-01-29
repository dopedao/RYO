## Dope Arena: Duel

Champion: beatws9

1v1 grid shooter in disposable state channels.

Dope Arena: Duel allows two
players to engage in a fast turn-based game to hit each other with a projectile.
Health decreases with each hit, and if health hits 0, the player is defeated.

```
oxoxoxoxoxoxoxoxoxoxoxoxoxox
xoxoxoxoxoxoxoxoxoxoxoxoxoxo
oxo A oxoxoxoxoxoxoxoxoxoxox
xoxoxoxoxoxoxoxoxoxoxoxoxoxo
oxoxoxoxoxoxoxoxox B xoxoxox
xoxoxoxoxoxoxoxoxoxoxoxoxoxo

^
Y

X >
```
The two players (A and B) take turns to move to a new nearby position and
fire a projectile at the opponent. This is an expansion of the state channel
explored in Module 08.

The concept is that players sign moves and pass them to each other. If
there is an illegal move, the move can be submitted to the cairo contract
to punish the offender.

In this way, the game exists as a way for two adversaries to engage without
having to trust that some system (such as a game server) is available and neutral.
A channel may be created by using the smart contract and connecting to the opponent
over the internet. The player could be a hand built program, a bot, or a beautiful
front end showcasing a rich tapestry of art, such as that created in the DopeWars
system (Hustlers in a suburban environment).

The goal is to start with a very simple game, which if feasible could be added to.

## Rationale

With contracts on Layer 2, it is cheap to create throwaway state channels that
only last for brief periods (10 mins). Channels allow players to interact in
and adversarial environment, including considering a game server an adversary.

Players use cryptoeconomic guarantees to make rational decisions. Malicious players
can be punished by sending L2 transactions.

Disappearing infrastructure can be
mitigated by writing your own client to:

- Monitor StarkNet
- Display the basic game state (a grid with two player positions)
- Receive and digest signed messages
- Sign and send moves
- Submit bad moves / channel closing conditions to StarkNet

"Why blockchain?" If the opponent cannot rug you and the server cannot
rug you, then the game can exist in a pure minimal environment. The events in
the game and the outcomes from the game cannot be controlled
by anyone except the player. If you assume everyone is an adversary, then
you can create a system that is functional in friendly and adversarial conditions.
While it may not eventuate that this game becomes subject to such conditions,
it is interesting to explore them to test the technology and contribute
to the ecosystem.

The distillation of the architecture design is:

- State channels require participants to be online,
which is actually normal for a short game. You are literally
present for the entire experience. Unlike payment channels,
where you might go out for a hike between payments and something has
to monitor the channel for you.
- Channels that are closed when not in use is costly, so you can't open
and close channels on L1 frequently. If a channel is instead on a rollup,
the cost to open and close channels is much cheaper! So channels can be
"disposable".
- L2 is cheap but you still do not want to put a fast paced game on a rollup,
because it will at some point be prohibitively expensive.
A state channel provides you with great guarantees and allows the fast pace.


```
L3 Game: State Channel (suffers from liveness requirement).
  |
__v__
L2 StarkNet: Rollup secures channel (suffers from bounded data posting).
  |
--v--
L1 Ethereum: EVM secures rollup (suffers from bounded data and computation)
```

## Game meta

The goal is to hit the other player, but if you receive a message from you opponent in which you are hit, perhaps it is in your interest to pretend you never saw this
message. To avoid this problem, moves are concealed. So a player commits to a
move and the opponent acknowledges receipt of the message. Then, the move is revealed
in the next message.

The game flow looks like this, imagining that tiles have numbers. The players
move one step and shoot, keeping track of current health.
```
A is on 11 and B is on 22, each with 100 health.

A: Health 100, move to 12, shoot at 22.

B: Health 99, move to 21, shoot at 12.

A: Health 99, move to 13, shoot at 24. (misses)

B: Health 99, move to ...
```

So the players do not know where the opponent is exactly. They know where
they were a moment ago, and so they must exist within "one step".

```
xoxoxoxoxoxo
oxox~~~xoxox
xoxo~A~oxoxo
oxox~~~xoxox
xoxoxoxoxoxo

Player A moves one step:

xoxoxoxoxoxo
oxox~~Axoxox
xoxo~ ~oxoxo
oxox~~~xoxox
xoxoxoxoxoxo

Player B knows that A could have moved to any one of the 8 '~'
surrounding tiles (or remain stationary).
```
So the game is about predicting the behaviour of the other player. This
protects the game from being easily ruined by a bot. If you a playing against
an opponent for long enough, you might be able to learn their behaviour, their psychology. Those able to do so will be able to deliver more successful hits.

At a glance it appears that standing on the edge provides your opponent with
a higher chance of hitting you. Beyond that more tactics may emerge.

# Arc of a Game

## Game initiation

Players submit a transaction to a StarkNet contract. The contract
coordinates the setup of a channel for two players. By watching the contract,
the players (or the software they run) can learn when a channel has been
successfully started. The game has begun.

The channel consists of players sending messages to each other. This could
be direct (by sharing IP address) or through a service that passes along messages (the same server that runs a nice interface). Once players can send a message
they do so in turns.

## Message flow

Turns consist of the game data that both parties agree upon. Players
may send anything to each other, but will be on the lookout for valid messages.

A valid message consists of a signature that belongs to the opponent, as
well as a standard structure. The structure will include elements like position and
health for each player. "The current game board looks like this, and my next move is this".

## Game termination

A game ends when the contract receives a transaction that contains the right information to close the channel and declare an outcome/victory. The
contract is aware of who the players are, and can look to see if the transaction
contains the right information, signed by the correct players.

The contract says: "This transaction is for Game 42. Both players have agreed
that Player A has 0 health and Player B has 13 health. I will store the outcome
as a victory for player A and remove Game 42 from the list of active games."

Because players might want to cheat somehow, the contract also must be prepared to
accept a different sort of transaction. In these situations the contract might say
something like: "This transaction for Game 42 contains a claim that Player B
signed a move to a tile more than one step away. I can see that Player B did sign
the message and that the position they move to is greater than one step. I declare
victory for A, and will remove Game 42 from the list of active games."

# Scenarios

The following is an exploration of the adversarial scenarios possible.
For each scenario, a proposed solution is outlined, including a function
available on the contract that can be used to enforce the outcome.

## Cooperative fair play

Players engage in good faith and all messages are correctly
passed according to game rules. A player reaches 0 health, and
one player submits a transaction to the contract to close the channel.
The winner is registered by the contract and the channel is removed from
the list of active games.

## Player ghosts

Player B who sent a transaction to the contract is entered into
a channel. They then fail to interact with the other player. Player
A sends a transaction to the contract function: `ghost_alert()`. The
contract starts a block-based countdown. Player B can cancel the countdown
and resume play with player A.

`ghost_alert()` must accept the game id, but also the latest agreed game
state number. E.g., zero if the game never progressed, or 455 if the game
went for a while before player B disappeared.

Player B can only cancel the countdown once per game state. E.g., they cannot
cancel the countdown twice without sending a valid move to the other player.
If the player ghosts again, then the contract

Thus, player A is protected from a disappearing opponent, although they must
endure the countdown waiting period. The countdown period is ideally short for this
reason. E.g., if games only last 10 minutes the countdown might be 30 seconds.


## Player moves to a illegal tile

Player B makes a move to a tile that is outside the allowable range. This
might be one tile away. Player A's client detects this and submits
the message in a transaction to the contract `submit_bad_move()` function.
The tiles have x and y
coordinates and so the contract looks at difference between player B's previous position and the latest position and if greater than 1 in either x or y,
then the game is terminated and Player A declared winner.

Thus, the game messages must have at least the previous player positions (previous
position, and new position, all signed by the player).

## Player fails to take damage

Player B is hit but when signing the message does not reduce their health.
Player A takes the message and submits it to the contract `submit_bad_health()`
function. The contract looks at Player B's position and the position of the
attacked tile. If the tile and the position are the same then a hit has occurred.
Then the health of player B pre- and post- move can be compared. If one health
point was recorded by B then player A is declared the winner.

Thus, the game messages must have the previous health state as well as the
current health state.

## Player makes a reveal that doesn't match their commitment

Player B makes a commitment for a move, then in their next message reveals
a move that doesn't match. The move commitment is a hash of the move. So
Player A can take B's move, hash it and see that the hash matches the
hash that they promised. If the hash is different, then A can submit it
to the `submit_bad_reveal()` function. The move can be hashed by the contract,
which can compare it to the hash B promised. If they are different, A is declared
the winner.

This prevents a player from promising one move and delivering another.
The game messages must have the previous commit in order for the contract to
perform this check.

## TBC

More adversarial scenarios here as they are thought of.

# Messages

## Message contents

How should a message from Player A to Player B best be structured? What is the minimum set of
information players A and B must sign and send to each other? Keeping in
mind that messages need to be formatted so that they can be sent to
the contract if needed.

Using the above section the requirements are laid out for the basic game.
Moves are numbered (A move 1, B move 2, A move 3, B move 4, ...). The rules
so far only require messages from the previous turn, so 2 players with 2 turns is 4 total:

- Move `n` (e.g., Player A, move 552)
- Move `n - 1` (e.g., Player B, move 551)
- Move `n - 2` (e.g., Player A, move 550)
- Move `n - 3` (e.g., Player B, move 549)

For each player, the following set describes what a move message consists of.

- Commit (the hash of the currently private intended next move)
    - hash of x and y coordinates of tile being moved to and tile being
    shot at.
- Revealed state
    - Player data representing up to date info. Matches the lastest commit.
- Old state
    - Player data prior to the latest revealed state.

State consists of (for each player)

- Health, in range [0,99]
- Current position x, in range [0, 30]
- Current position y, in range [0, 30]
- Shoots at x, in range [0, 30]
- Shoots at y, in range [0, 30]

Moves all contain the hash of the previous move, which forms a chain of
moves that cannot be easily edited retroactively.

## Message structure

The structure is up for design. Perhaps something that can
be passed straight to the contract (e.g, an array where the contract
is expecting things in certain indices).

This is an example of how it might be structured in json.

Here Player A makes a move (one step, one shot), revealing their shot which hits B
(on tile x=23, y=19),
reducing B's health from 94 to 93. B's position is included in the description
of player A's move, even though B has no action while it is A's turn.
This makes A sign and agree to the current state, and B could use that
to send to the contract if A makes an illegal move.

```
{
    "move" : {
        "number" : 552,
        "player_moving" : "a",
        "commit" : "0x12345",
        "reveal" : {
            "health" : {
                "a" : 89,
                "b" : 93,
            }
            "x_y_position" : {
                "a" : (12, 12)
                "b" : (23, 19)
            }
            "x_y_shots" : {
                "a" : (23, 19)
                "b" : (11, 11)
            }
        },
        "old_state" : {
            "health" : {
                "a" : 89,
                "b" : 94,
            }
            "x_y_position" : {
                "a" : (12, 11)
                "b" : (23, 19)
            }
            "x_y_shots" : {
                "a" : (23, 19)
                "b" : (11, 11)
            }
        },
        "prev_move_hash" : 0x28282
        "move_hash" : 0x98876,
        "move_signature" : {
            "sig_r" : 0x3456,
            "sig_s" : 0x6453,
        }
    },
    "move_n-1" : {
        "number" : 551,
        "player_moving" : "b",
        ...
        "move_hash" : 0x28282
    },
    "move_n-1" : {
        "number" : 550,
        "player_moving" : "a",
        ... (the commit hash for A's current reveal is here)
    },
    "move_n-1" : {
        "number" : 549,
        "player_moving" : "b",
        ...
    }
}
```

The above structure might be reorganised to a list as follows:

```
[552, 0, 0x12345, 89, 93, 12, 12, 23, 19, 23, 19, 11, 11, 89, 94, ...]
```

The cairo contract can accept that list and reference index 0 for the move nuber,
and have player A encoded as `0`, player B as `1`.

The contract functions that handle each specific dispute scenario can
be designed at a high level, and later coded. For example: `submit_bad_move()`
takes the data and looks at the difference in x coordinates for the current turn
and that players last turn. If the difference is more than 1, the channel is closed.
This high level description enables the different edge cases to be thought out
and documented in plain language before coding.

# Infrastructure

## Keys

Games use single-use ECDSA keys that are not used elsewhere. Players
register a new key for each game. This allows a game client to
hold the key and sign moves. If the key is properly generated fresh for
each game, then when it is lost there is no effect on
other systems or assets.

## Networking

The game could coordinate around sending messages peer to peer, some thought
could go into what is appropriate for establishing mature messaging architecture.
E.g., LibP2P.


## Blockchain

Options: Poll StarkNet API or run your own StarkNet node

Open source node: https://github.com/eqlabs/pathfinder.

The game involves sending messages peer-to-peer as quickly as possible. This
does not involve the blockchain. However, the chain must be watched so that
a player can detect if their opponent has submitted a transaction that affects
the game.

E.g. A player sends a transaction claiming that the opponent has ghosted. The
countdown is started, and if the other player is unaware (but playing the game),
then the contract could close the channel. Thus, the blockchain must be watched
to allow enough time to respond (proving they haven't ghosted by submitting
a signed game message).

# User interface

## Experience

The DopeWars game engine is a multiplayer walkable world for Hustlers.
Walking into a carpark might open a dialogue "Would you like to register to
fight". If selected, the fronted generates an ephemeral game key and
submits that in a transaction to StarkNet. The player now waits for another
player to join. Perhaps this is broadcast to other players, to attract them
to come to the carpark.

Upon a second player registering to play, the two players are matched by the
StarkNet contract and a 1v1 game is created with a unique ID. The players share
communication details and commence a peer to peer message session (e.g., through
libP2P or other).

On screen the Hustlers now move into the carpark to starting positions in a
well demarcated grid of discrete tiles. They then are instructed to click
to move and click to shoot.

The interface watches for a click uses that to determine where the player
intends to move to. The location of the mouse is used to pick the
closest appropriate tile.

The interface then awaits a second click. This determines where the player
intends to shoot at. The location of the mouse is use to pick the closest
appropriate tile.

The health bar allows the user to see how being hit reduces health. Other players
can walk over and observe the fight by moving their Hustler to the carpark region
(but they cannot enter while a fight is happening). They could perhaps engage in
a fight with another person, and the front end could overlay multiple fights.

## Connection and state management flow

The browser maintains the move objects by keeping record of the current move
number, storing only the latest relevant moves.

The game engine currently reads the user input to control the character
https://github.com/dopedao/dope-monorepo/blob/master/packages/web/src/game/entities/player/PlayerController.ts

This could perhaps be integrated in the following way:

- When the channel is created the player becomes locked in a discrete area, such as a carpark.
- Game engine controls are turned off (no normal wandering allowed)
- Mouse click event listeners are added. When the two clicks are detected,
the move is constructed from those two elements (move to x, shoot at x)
- A call is made for the move to be properly formatted
- The formatted move is signed by the special ephemeral channel private key
- The message is sent to the opponent
- Await message from opponent
- Read message, see the revealed moves and state.
- Check if the moves are valid and well formed.
    - If not, construct a message to sign and send to StarkNet to close the channel
    and claim victory (call the function for whatever specific issue is found).
- Update the position of the player on the screen, including any animations
for weapon fire. E.g., a 'shot' might be different depending on what weapon the Hustler holds.
- Update the health bar
- Listen for mouse clikc events
- When a player has 0 health, construct a message to sign and send to the contract
- Display the winner on some scoreboard, whose state is recorded in the StarkNet
contract of recorded wins.

# Alternate client concepts

A true test of decentralisation is if anyone can create a new client for the
game and remain competitive.

## Nice client

DopeWars.gg browser based game engine displays the game as a grid in an open
space such as a parking lot. Players are represented as Hustlers and the game
is broadcast so that other people in the game engine (but outside the channel)
can view the game. The browser holds keys, the server watches the chain for channel
open/close conditions. Game rules are automated so that the player
only has to make two clicks:

Click 1: Move to particular tile.
CLick 2: Shoot at particular tile.

## Bare client

Watches the channel contract and detects open/close conditions. Renders
the game as an ASCII grid (such as with python curses module similar to: https://github.com/perama-v/fee-feed).

The client could have automated game rules, partaking in games autonomously according
to some custom scheme. This would be super cool, and shares philosophy with the way
players build out plugins for Dark Forest (see https://plugins.zkga.me/).

# Game outcomes

The game channel contract could record winners, which can be polled by the front end
to display on a leader board. Upon demonstration of viability, additional elements
can be introduced. This could include posting some slashable deposit which is lost and given to the other player upon defeat. Players might also be given the opportunity
to generate a winners-trophy or similar artefact. This could grant access to a new
part of the map, or enable some other functionality in a contract.

# Examples

Below are some scenarios to explore game play flow. Here the game is
considered a grid of 30 x 30 tiles. Players start in positions:

A is mid-left (x=10, y=15)

B is mid-right (x=20, y=15)

The commit-reveal patter is inherent to every move. In the first example
this is described explicitly, but in later examples it may be ommitted.
The important ting is that moves are always done on top of a single unknown
move by the opponent.

## A and B are stationary

Both A and B stand in the same position, only shooting at each other.

A: Commits to move (reveals nothing)

B: Commits to move (reveals nothing)

A: Reveals first move which is: shoots at 20, 15. B loses 1 health (100->99).
Commits to second move.

B: Reveals first move which is: shoots at 10, 15. A loses 1 health (100->99).
Commits to second move.

A: Reveals second move which is: shoots at 20, 15. B loses 1 health (99->98).
Commits to third move.

...

A: shoots at 20, 15. B loses 1 health (1->0).

A now sends the message data in a transaction to the contract and claims
victory.

## A and B dance up and down

A and B move up and down one tile, but always shoot at the starting squares.

A: commit move

B: commit move

A: Reveal: moves up to 10, 14. Shoots at 20, 15. Hits (player started there). Commits next.

B: Reveal: moves up to 20, 14. Shoots at 10, 15. Hits. Commits next.

A: Reveal: moves down to 10, 15. Shoots at 20, 15. Misses (player B revealed they
were on y=14 not y=15). Commits next.

...

Etc. each player hits half the time.

## Next scenario here

...


### Feedback/participation welcome here or in dopewars discord.