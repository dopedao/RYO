# RYO

Roll Your Own - A [Dope Wars](https:/www.dopewars.gg) open universe project.

A modular game engine architecture for the StarkNet L2 roll-up, where
computation is cheap and new game styles are being explored.
Roll your own module and join the ecosystem.

## What

A community-driven collection of contracts that allows sharing
of game states between different game modules. Games all fit within
the Dope Wars ecosystem, which is an open-ended project where anyone can
add something for the community to enjoy.

Design a new game module that interests you. Call other modules
and read their state to create composable game interactions.
Create new artefacts that other future modules can use.

Games can pull inspiration from the DOPE ERC721 NFT on Mainnet,
the item-equipped Hustler ERC1155 characters on Optimism, or other
community ideas that are fun.

Some modules are outlines waiting to be explored and expanded. The
first module is an implementation of the Drug Wars drug arbitrage
game on TI-83-era calculators.

History:

- Background mechanism design notion [here](https://dope-wars.notion.site/dope-22fe2860c3e64b1687db9ba2d70b0bb5).
- Initial exploration / walkthrough viability testing blog [here](https://perama-v.github.io/cairo/game/world).
- Expansion for forward compatibility [here](https://perama-v.github.io/cairo/game/aggregated-architecture).

From there the idea evolved to be a system where, just like the open-ended
nature of the DOPE NFT, anyone can come and build what they like. To achieve
that, the modules are able to read from each other by using a central
coordinator contract. There is even the possibility to have contracts grant
write access to each other, potentially though a governance process.

## Join in

Everyone is welcome to join in:

- Learn about Cairo. A turing-complete language for programs that become proofs.
- Learn about StarkNet. An Ethereum L2 rollup with:
    - L1 for data availability
    - State transitions executed by validity proofs that the EVM checks.
- Work on anything to do with the game/ecosystem that fits your skills and interest.
- If you have an idea for a new module, first claim the next available number
and start writing some ideas down in `/module_notes`. Then use the `00_TemplateModule.cairo` file to start writing your module. Help is always available in the Dope Wars
discord.

The modules here are by their nature experimental and assumed to be broken
by default. The goal is to have fun exploring new ideas. As modules mature,
they might be suitable to be slotted into the front end game, where players
can use their characters. For example, a player might go to a payphone
and partake in Module 01 to make a drug trade (single transaction), then
go to a car park and start a fight using Module 08 (open channel with
a single transaction).

Game modules can take any form, and if revenue is generated,
there is a cultural norm to direct 5% to the DOPE DAO. If the community
likes your idea, perhaps the DOPE DAO might vote to support you in your efforts!


## System architecture

Modules can exist in isolation, or they can read or even write to other
modules.

The game mechanics are separated from the game state variables.
A controller system manages a mapping of modules to deployed addresses
and a governance module may update the controller.

For example all these modules could read and write from the state modules and be connected-but-distinct game interactions:

- Try arbitrage drug markets [01 Dope Wars module](/module_notes/01_DopeWars.md).
Manage inventory against risks and try to out-trade other players. Swap coke
in one region and swoop in to collect cheap Krokodil after a regional drug bust.
- Try to become a regional Drug Lord by submitting an autobattler to the
[05 Combat module](/module_notes/05_Combat.md). Hand crafted strategies submitted
against the current drug Lord. Winner collects a cut from future regional trades.
- Try an L3 move-by-move 1v1 fight with another player in the
[08 State channel module](/module_notes/08_StateChannel.md). Inventory from your work in
the drug trades is placed as collateral for the channel. Off-chain messages
signed by your key ensure that when submitted back to L2 the winnings are enforced.
High-frequency moves allow for granular game play.
- Leave some graffiti on-chain, appraise and erase the tags of others with the
Wall module (module 09).
- Generate a report card (module 11), attesting to the achievements of a player. Perhaps the report card can be structured to enable another module (or ecosystem) to ingest it.
- Explore or use a game-balancer, such as the one in module 11, giving equippable
items a theme that is suited to specific domains.

## Contract hierarchy

It is also worth pointing out that StarkNet has account abstraction
(see background notes [here](https://perama-v.github.io/cairo/examples/test_accounts/)).
This means that transactions are actioned by sending a payload to a personal
Account contract that holds your public key. The contract checks the payload
and forwards it on to the destination.

- Player Account
    - A user who controls a Hustler (game character) in the system.
- Governance Account
    - An admin who controls the Arbiter.
    - The admin may be an L2 DAO to administer governance decisions
    voted through on L2, where voting will be cheap.
    - Governance might enable a new module to have write-access to
    and important game variable. For example, to change the location
    that a player is currently in. All other modules that read and use location
    would be affected by this.
- Arbiter (most power in the system).
    - Can update/add module mappings in ModuleController.
- ModuleController (mapping of deployments to module_ids).
    - The game 'swichboard' that connects all modules.
    - Is the reference point for all modules. Modules call this
    contract as the source of truth for the address of other modules.
    - The controller stores where modules can be found, and which modules
    have write access to other modules.
- Modules (open ended set)
    - Game mechanics (where a player would interact to play)
    - Storage modules (game variables)
    - L1 connectors/registry (for integrating L1 state/ownership to L2)
    - Other arbitrary contracts as they are added to the game system.

For more information see

- Modular [system architecture](./system_architecture.md).
- Descriptions of example modules in [module notes](/module_notes).

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

### Development workflow

If you are using VSCode, we provide a development container with all required dependencies.
When opening VS Code, it should ask you to re-open the project in a container, if it finds
the .devcontainer folder. If not, you can open the Command Palette (`cmd + shift + p`),
and run “Remote-Containers: Rebuild and Reopen in Container”.

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
nile compile
```

Compile an individual contract:
```
nile compile contracts/01_DopeWars.cairo
```

### Test

Run all github actions tests: `bin/test`

Run individual tests
```
bin/shell pytest -s testing/01_DopeWars_contract_test.py
```

### Deploy

Start up a local StarkNet devnet with:
```
nile node
```
Then run the deployment of all the contracts. This uses nile
and handles passing addresses between the modules to create a
permissions system.
```
bin/deploy
```

## Next steps

- Module 01
    - Outline a rule that can be applied for location travel costs. This
    can be a simple function that uses a dictionary-based lookup table such as the one in module 02. This will replace `mappings/location_travel.csv`.
    - Refine both the likelihood (basis points per user turn) and impact (percentage
    change) that events have and treak the constant at the top of `contracts/01_DopeWars.cairo`.
    E.g., how often should you get mugged, how much money would you lose.
    - Make the market initialisation function smaller (exceeded pedersen builtin, tx_id=302029). E.g., break it into 8 separate transactions.
    - User authentication. E.g., signature verification.
- Module 05 - Combat
    - Think about the mechanics of the auto-battles.
    - How many variables, what they are, how to create a system that
    forces users to be creative and make tradeoffs in the design of their combat submissions.
    (e.g., the values they submit during their turn).
    - Think about how to integrate the non-flexible combat
    atributes that come from the Hustler (1 item per slot). E.g., how
    should combate integrate the score that each item has.
    - Whether a player could have a tree-like decision matrix that
    they populate with "I would block if punched, and then kick to counter"
- Module 08 - State Channel
    - Design data structure for p2p messages that are signed. What
    does a player sign when they make a 'punch'.
- Module 09 - Wall
    - Add mechanism where players can vote on tags.
- Module 10 - Report card
    - Implement a token-generator that represents "Contract X attesting to
    Player Y, with skills a, b, c, ... j."
- Module 11 - Bell Labs
    - Implement a scoring system for the three different colours.
- UserRegistry
    - Outline a system for loading Hustler-data from Optimism. E.g.,
    snapshot, bridge or storage merkle proof.
    - More testing of held-item binary encoding implementation in `UserRegistry`
- Arbiter
    - Add vote-counter for all players - they can vote to give one module
    write access over another.

Welcome:

- PRs
- Issues
- Questions about Cairo
- Ideas for the game

