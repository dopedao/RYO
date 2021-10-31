# Asynchronous combat

```
TL;DR

Complex checks an balances in StarkNet are cheaper than storage.

Rather than store data, store the hash:

1. Supply the data every time
2. Check the hash matches
3. Do complex calculations
4. Output some tiny result
5. Save a new hash
```

## Framework

Goal: Creating a game that involves multiple players competing in a fun
and cheap way, in an un-ruggable stage that you can connect to user-owned things.

Building on StarkNet is interesting because there is a new design space that is partly rooted
in the well-studied Ethereum enviroment, and partly rooted in a new space:

```
I did the computation: no need to repeat it.
```

That's one simple way to imagine StarkNet from a distance. If a contract/program has been
loaded into the prover-verifier apparatus successfully, then the whatever happened is valid.
Proofs cannot be faked, and so no contract needs to be run twice.

Once the program has been confirmed - it's good to go. In the EVM solidity contracts are
checked by going over the bytecode. For StarkNet, the proof for the program is checked.

## Large programs, small programs same same.

Now it doesn't really matter how big this program is. Not in the same way that
we are used to in the EVM where every line is agonized over.

The reason for this is that a Cairo program is turned into a series of steps. Each step is
reimagined as a statement "this step is good". The steps are combined in a way that is
efficient (multiple steps combined into one). Then the program is represented in a way
that you can say "check enough steps and you can be very confident in the integrity of the whole
program". This arises form the prover tying-their-own hands and allowing for deterministic
check-points in the the prover-verifier-interaction-game.

Thus a Cairo contract becomes a set of pre-arranged checks that guaranteed the integrity
of the whole program. So as the program length increases, the prover has to spend more time
building this special step-based checking-system. But for the verifier, it doesn't really matter.

The verifier is of course a Solidity contract. So ultimately, a longer Cairo contract doesn't
pay more than a short Cairo contract.

For review the steps are:

```
1. Creates a statement of integrity for the steps in the trace.
2. Represents those statments as AIRs (statments in polynomial form).
3. Combines them into a single AIR.
4. Performs low degree testing (FRI) to generate a probabalistic proof
(that the polynomials have low degree).
5. Generates Merkle trees that commit to that proof.
6. Saves the commitments as CALLDATA in the verifier smart contract
```

## More storage bad, less storage good

If you use the `@storage` function in a StarkNet contract, this is making a special
extra step to load a variable into one of the StarkNet L1 contracts. This causes more
storage cost on L1, which must be passed on to the L2 user. StarkNet will charge for
transactions and a contract with heavy use of storage will incur more transaction cost
than an equivalent without.

Thus, if there is any way to replace storage with computation, it will likely be cheaper.

## State transitions

A game is fundamentally about state transitions, where the game accepts
a user input and arrives at a new state. What sort of state makes sense for a game
to hold?

Certainly, if a game has players with ownable things that can be used in other places,
storing these on chain is important. E.g., an item can be used in two different games.

Other parts of state are perhaps not as criticial. For example, is it important that
a game record all a players keystrokes? Rather, ensuring that the keystrokes were valid
and recording important outcomes is more worthwhile.

In `01_DopeWars` a player chooses to go to a location and make a trade, as their turn is
processed, the contract generates events that help and hinder the player. They may be
attacked and they may find a free bag of cocaine. The game does not store the attack, rather
it emits the event and applies its effect to the core storage record to store
the final balance of the user.

## Provenance and agency

Part of the game mechanic is tied to the DOPE-universe tokens that are ownable, tradeable
and enjoyable in extra-game environments. Items brought into the game may confer desirable
qualities to one's game character. This extends game play to the creation, curation and collection
of these tokens.

Whilc game play is partly based on these tokens, it also requires user action to synthesise
the drug-trade market and exercise risk management and arbitrage in an asynchronous and fully
public environment. Chosing where, when and what to trade brings agency to the player.

I was inspired by
[killari's post on AutoBattlers](https://killari.medium.com/starks-verifying-a-complex-auto-battler-calculation-on-ethereum-d8698f29808d)
to expand on an idea that the regions in the game could be 'ownable zones' and that
players could fight for. As part of their normal turn they can also engage in another dimension
of game play where they interact more directly with other players.

An auto-battler is a preconfigured agent who competes with another agent in a framework with known
rules. In the `Combat.cairo` module a Drug Lord is added each region. They collect a
cut from each trade and gain advantage in the main game - to gather the most resources in the game.
Any player may become a Drug Lord by challenging and defeating an existing Drug Lord.

## Gameplay-in-advance

A fight consists of a player providing a fighter, who is loaded in to the fight contract
which programatically chips away at variables like a health bar until a defeat is realised.

In a public blockchain, this is troublesome - you can see the outcome before you begin.

However - what you cannot see is the battle that takes place in a future turn. If you become
the Drug Lord, anyone can see your player and challenge you.

So the game has two goals:

1. Defeat the current Drug Lord in the region and start taking cuts on trades.
2. Defend against anyone who is going to challenge you.

With the autobattle rule in public, the game becomes a game of player design. Should you
make you player smart and quick or strong and slow? This depends heavily on the game rules.
The game can become interesting again if the design space is very large and many vaiable strategies
exist.

So one design is as follows:

1. The user calls `have_turn`, including the normal trade-related instructions,
specifying a location and some trade to execute.
2. They pass in a large array which specifies the design of a fighter
3. They obtain from the chain history (e.g., Event emitted or old transaction) the parameters
that the Drug Lord used.
4. The contract verifies the Drug Lord variable hash matches the stored hash.
5. The token-related data for the user and the Drug Lord are pulled from the game registry.
6. The data is sent to `Combat.cairo`, where multiple rounds of fighting occurs
7. Events are emitted which can be picked up by a front-end.
8. The winner is decided based on some metric. E.g., first to lose all health.
9. The main game contract stores the new winner `user_id` and parameter hash.
10. Future trades in this region send some cut to this user
11. The next user to come along will fight the Drug Lord (back to step 1).

The interesting thing might be to see how many parameters you can include. 30? 100? How complex
can the auto-battle rules get? Can there be different phases in the battle that call out
to other modular contracts.

## Proof of knoweledge

This mechanism invovles manually going to the block chain and harvesting a previous Event
to obtain the parameters that the current Drug Lord used for their turn. This is sort of
a proof of knowledge, where the contract does not store the actual data but instead
verfies it upon presentation. I think this is a compelling model - having a user pass in
a large blob, which requires a moderate amount of computation to process - because of the
computation vs storage advantage inherent to StarkNet.

## Player constraint design

The parameters that a player designs for their fighter can be grouped in to different
categories, such as `physical`, `mental`, `social`, `attac`, `protec`.

These can then be billed quadratically, preventing any one category to be supercharged.
Without serious consideratio for a more balanced approach.

## Fight mechanics

The rules of how the auto-battle progresses is a TODO. Perhaps a reciprocated
four step attack, attack-react, defence, defence-react sequence per loop?
