# RYO
Dope Wars game engine on StarkNet L2 roll-up

## What

Background mechanism design [here](https://dope-wars.notion.site/dope-22fe2860c3e64b1687db9ba2d70b0bb5)

Initial exploration / walkthrough [here](https://perama-v.github.io/cairo/game/world)

## How

Clone this repo, make and activate environment, install the Cairo language, check teh StarkNet CLI.

```
git clone git@github.com:dopedao/RYO.git
python3 -m venv ./venv
source venv/bin/activate
pip install cairo-lang
starknet
```

That CLI allows you to deploy to StarkNet and read/write to contracts
already deployed. The CLI communicates with a server that StarkNet
run, who bundle the request, execute the program (contracts are
Cairo programs), create and aggregated validity proofs, then post that
to Goerli Ethereum testnet.

[Cairo language / StarkNet docs](https://www.cairo-lang.org/docs/)
