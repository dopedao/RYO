import os
import pytest

from starkware.starknet.compiler.compile import (
    compile_starknet_files)
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.testing.contract import StarknetContract

# The path to the contract source code.
ENGINE_CONTRACT_FILE = os.path.join(
    os.path.dirname(__file__), "../contracts/GameEngineV1.cairo")
MARKET_CONTRACT_FILE = os.path.join(
    os.path.dirname(__file__), "../contracts/MarketMaker.cairo")

# The testing library uses python's asyncio. So the following
# decorator and the ``async`` keyword are needed.
@pytest.mark.asyncio
async def test_record_items():
    # Compile the contracts.
    engine_contract_definition = compile_starknet_files(
        [ENGINE_CONTRACT_FILE], debug_info=True)
    market_contract_definition = compile_starknet_files(
        [MARKET_CONTRACT_FILE], debug_info=True)

    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # Deploy the contracts.
    market_contract_address = await starknet.deploy(
        contract_definition=market_contract_definition)
    engine_contract_address = await starknet.deploy(
        contract_definition=engine_contract_definition)

    # Create contract Objects to interact with.
    engine_contract = StarknetContract(
        starknet=starknet,
        abi=engine_contract_definition.abi,
        contract_address=engine_contract_address,
    )

    # Save the market address in the engine contract so it can call
    # the market maker contract.
    await engine_contract.set_market_maker_address(
        address=market_contract_address).invoke()

    # Set up a scenario. A user who will go to some market and trade
    # in some item in exchange for money.
    user_id = 3
    item_id = 5
    city_id = 9
    suburb_id = 4
    # User has small amount of money, but lots of the item they are selling.
    user_money_pre = 300
    user_item_pre = 55
    # Market has lots of money, not a lot of the item it is receiving.
    # This will use override
    market_item_pre = 10
    market_money_pre = 12000
    # Set action (buy=0, sell=1)
    buy_or_sell = 1  # Selling
    # How much is the user giving (either money or item)
    item_quantity = 20  # 20 of the item.

    # Create the market.
    await engine_contract.admin_set_market_amount(city_id, suburb_id,
        item_id, market_item_pre, market_money_pre).invoke()
    # Give the user item.
    await engine_contract.admin_set_user_amount(user_id, item_id,
        user_item_pre).invoke()
    # Give the user money (id=0).
    await engine_contract.admin_set_user_amount(user_id, 0,
        user_money_pre).invoke()
    pre_trade_user = await engine_contract.check_user_state(
        user_id).invoke()
    print('pre_trade_user', pre_trade_user)
    pre_trade_market = await engine_contract.check_market_state(
        city_id, suburb_id, item_id).invoke()
    print('pre_trade_market', pre_trade_market)

    # Execute a game turn.
    await engine_contract.have_turn(user_id, city_id, suburb_id,
        buy_or_sell, item_id, item_quantity).invoke()

    # Inspect post-trade state
    post_trade_user = await engine_contract.check_user_state(
        user_id).invoke()
    print('post_trade_user', post_trade_user)
    post_trade_market = await engine_contract.check_market_state(
        city_id, suburb_id, item_id).invoke()
    print('post_trade_market', post_trade_market)

    # Check money made. (Assert user money (index 0) post > money pre)
    assert post_trade_user[0] > user_money_pre
    # Check gave items. (Assert user item quantity (index=item_id) post > money pre)
    assert post_trade_user[item_id] < user_item_pre
    # Check city is set
    assert post_trade_user[11] == city_id
    # Check suburb is set
    assert post_trade_user[12] == suburb_id

    # Check that the market gained item
    assert post_trade_market[0] > market_item_pre
    # Check that the market lost money
    assert post_trade_market[1] < market_money_pre

    # Check nothing was minted
    units_pre = user_money_pre + user_item_pre + market_item_pre + \
        market_money_pre
    units_post = post_trade_user[0] + post_trade_user[item_id] \
        + post_trade_market[0] + post_trade_market[1]
    assert units_pre == units_post

    (random_item, random_money) = await engine_contract.check_market_state(
        10, 2, 1).invoke()
    assert random_money != 0




