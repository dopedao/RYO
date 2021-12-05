# Introduction

```
TL;DR
Generate ownable and composable summaries of human effort
achieved in game play.
```

In the quest to give players dignity and ownership in the modern
gaming environment, one model is to generate cross-platform artifacts.
Players can obtain an artifact in one game and use them in other domains,
thus increasing agency and utility of their actions within each domain.

An artifact might be easily imagined as a sword: Build a sword in one
game, and export it to another game. This captures ownership, but raises
questions of interoperatibility in different ecosystems. A sword might
be powerful and sought after by other players, and likely represents
work and skill in the game it originates.

Report cards are an extension to the artifact model. An item could
be inscribed with traits that represent the events that took place
during the game. A report card might capture specific domains
and quantify them by some metric: skill, creativity, speed, collaboration.

An artifact therefore be a sword with maxed-out speed in one game, but
in another game/system it could be read as an axe with maxed-out speed.
The second game acknolwedges that:

1. The initial adminstrating game is a reputable source for player reports
2. The player has speed, and grants them some like-kind object or right
in the new game.

## Implementation

A report card it a token that contains:

- Scores that conform to some standard.
- Record of scoring standard used.
- Attestation by some enity (game contract, game signature)
- Ownership/normal non-fungible token qualities.

A user plays a game, the contract is configured to assess the players
behaviour and administer a report card.

## Use

The report card can be a record for personal or social use, or other
contracts could use them programmatically: Players who have a report
card with collaboration score above 7 are rewarded.

## Standards

Report card standards could be defined by the hash of a name,
with the parameters and rules defined and published.

## Constraints

A report card might restrain the total sum of scores to be less than
some number, or scores in one domain not drastically exceeding some other domain.
