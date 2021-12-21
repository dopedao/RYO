## Trinity

A module that provides a score for a game character along a requested axis.

## Outline

Problem: Gameplay can become static when characters have generic properties.

Solution: Character properties are grouped by themes that can used to give
context for a given scenario. A character might be well suited to a drug
trade by poorly suited to a combat. This contract:

- Defines axes.
- Accepts a request to score a player along one axis.
- Reads what a character is equipped with (Hustler with shovel, gold chain and
a bloodstained shirt).
- Looks up a hard-coded set of constants and uses them to calculate a score.
- Returns the score to the calling contract.

## Use

The system might be thought of as assigning colours to different objects. A shovel
might be a 'green' object. Another game module might define an interaction (e.g., a fight)
as a 'red' interaction. The fighting module might look to assess how much damage the
player will inflict with their weapon. They call Trinity and ask for a score along the
'red' axis. The contract detects that the player has a shovel, which has a high green
score but a low red score. It returns a low value and the fighting contract inflicts
low damage in the interaction.


## Setup

Rough steps to get going:

- Install github and clone the RYO repository.
- Create a branch and give it a name.
- Install docker and VS Code.
- Then edit the contract in `contracts/11_Trinity.cairo`.
- Open the terminal in VS code.
- Compile the contract `nile compile contracts/contracts/11_Trinity.cairo`.
- Test the contract `pytest -s testing/11_Trinity_test.disabled.py::get_aggregate_score`.


## Contract design

The contract for now will accept a array of the items a player has.
The array will be defined in the order they appear in the DOPE NFT contract.
This can be viewed [here](../mappings/data_encoding.md#contract-source-data).
There are 12 categories, so the array will be 12 elements long. Each element
has a single number that corresponds to the index of the item in the array.

For example, a player with array starting with: `[2, 0, 4, ...]` is
equivalent to a player with `["knife", "White T Shirt", "ATV", ...]`.

The contract will use dictionaries to store how the different items
are stored in each category. The items can be slowly rolled out so that things
like `namePrefixes` don't have to be used immediately.

The entry function `get_aggregate_score()` calls other functions,
such as `get_item_score()` to separate out the
different category calculations
(E.g., weapons, then drugs then xyz). The total score is then combined.

## Algorithm

The algorithm might start simple and then be refined over time. Perhaps
at first each item contributes a number `[0, 99]`. Where a value
of 50 can be used for a neutral score, ~80 for a high score and ~20 for a low score.

So the process might be: check the value for each category, add them all,
divide by 12 to arrive at a composite score for the axis.

## Testing

In the `testing/11_Trinity_test.disabled.py` file, the contract can be
called in a local environment. The user can be created with an arbitrary
array of equipped items, and the score for this configuration can be queried
from the contract locally. Different tests can be created to check
a set of desirable properties for the system. E.g., a player score should not
exceed x or be below y.
