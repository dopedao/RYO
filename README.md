# RYO

Roll Your Own - A Dope Wars open universe project.

A modular game engine architecture for the StarkNet L2 roll-up.

## What

TI-83 drug wars built as smart contract system.

History:

- Background mechanism design notion [here](https://dope-wars.notion.site/dope-22fe2860c3e64b1687db9ba2d70b0bb5).
- Initial exploration / walkthrough viability testing blog [here](https://perama-v.github.io/cairo/game/world).
- Expansion for forward compatibility [here](https://perama-v.github.io/cairo/game/aggregated-architecture).


Join in:

- Learn about Cairo. A turing-complete language for programs that become proofs.
- Learn about StarkNet. An Ethereum L2 rollup with:
    - L1 for data availability
    - State transitions executed by validity proofs that the EVM checks.
- Work on anything to do with the game/ecosystem that fits your skills and interest.

## System architecture

The game mechanics are separated from the game state variables.
A controller system manages a mapping of modules to deployed addresses
and a governance module may update the controller.

It is also worth pointing out that StarkNet has account abstraction
(see background notes [here](https://perama-v.github.io/cairo/examples/test_accounts/)).
This means that transactions are actioned by sending a payload to a personal
Account contract that holds your public key. The contract checks the payload
and forwards it on to the destination.

- Accounts
    - A user who controls a Hustler (game character) in the system.
    - An admin who controls the Arbiter. The admin may be a human or a
    multisig governance contract activated by votes on L2.
- Arbiter (most power in the system).
    - Can update/add module mappings in ModuleController.
- ModuleController (mapping of deployments to module_ids)
    - Is the reference point for all modules. Modules call this
    contract as the source of truth for the address of other modules.
- Modules (open ended set)
    - Game mechanics (where a player would interact to play)
    - Storage modules (game variables)
    - L1 connectors (for integrating L1 state/ownership to L2)
    - Other arbitrary contracts

For more information see [system architecture](./system_architecture.md)

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

Building out parts to make a functional `v1`. Some good entry-level options
for anyone wanting to try out Cairo.

Non-coding tasks:

- Review the names of the 'districts' in `mappings/location_travel.csv`. Add interesting
ones and remove ones that aren't as fun. The regions names are fixed.
- Revise/sssign scores to all the DOPE wearables/itmes in `mappings/thingxyz_score.csv`.
E.g., is a `Baseball Bat` or a handgun more powerful, or what is more costly per 'unit'
`Krokodil` or `Oxycontin`. Might also be interesting to look at documenting/using the
rarity of each of these items to help inform the score.
- Create new `mappings/thingxyz_score.csv` for the missing categories (clothes, waist
armor, name suffixes, etc.).

Quick-coding tasks:

- Game end criterion based on global clock.
- Potentially separate out tests into different files to reduce the time required for tests.
Reuse the deployment module across different tests.
- Outline a rule that can be applied for location travel costs. This
can be a simple function that uses a dictionary-based lookup table such as the one in module 02.
This will replace `mappings/location_travel.csv`.

Coding tasks:

- Refine both the likelihood (basis points per user turn) and impact (percentage
change) that events have and treak the constant at the top of `contracts/01_DopeWars.cairo`.
E.g., how often should you get mugged, how much money would you lose.
- Make the market initialisation function smaller (exceeded pedersen builtin, tx_id=302029).
E.g., break it into 8 separate transactions.
- User authentication. E.g., signature verification.
- More testing of held-item binary encoding implementation in `UserRegistry`
- More testing of effect of wearables on event occurences.
- Think about the mechanics of the battles in `Combat.cairo`.
    - How many variables,what they are, how to create a system that
    forces users to be creative and make tradeoffs in the design of their combat submissions.
    (e.g., the values they submit during their turn).
    - Think about how to integrate the non-flexible combat
    atributes that come from the Hustler (1 item per slot). E.g., how
    should combate integrate the score that each item has.
    - Whether a player could have a tree-like decision matrix that
    they populate with "I would block if punched, and then kick to counter"
- Extract the global state variables i to separate modules.

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
