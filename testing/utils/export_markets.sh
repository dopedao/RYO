#!/bin/sh
echo "Exported markets to variables MARKET_MONEY and MARKET_ITEMS"
MARKET_MONEY=$(python3 ./testing/utils/markets_to_list.py 0)
MARKET_ITEMS=$(python3 ./testing/utils/markets_to_list.py 1)

echo $MARKET_MONEY
echo $MARKET_ITEMS
