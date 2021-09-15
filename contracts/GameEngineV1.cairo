%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.storage import Storage
from starkware.cairo.common.math import assert_nn_le


#### Other Contract Info ####
# Address of previously deployed MarketMaket.cairo contract.
#const MARKET_MAKER_ADDRESS = 0x07f9ad51033cd6107ad7d70d01c3b0ba2dda3331163a45b6b7f1a2952dac0880
# Modifiable address pytest deployments.
@storage_var
func market_maker_address() -> (address : felt):
end

# Declare the interface with which to call the Market Maker contract.
@contract_interface
namespace IMarketMaker:
    func trade(market_a_pre : felt, market_b_pre : felt,
        user_gives_a : felt) -> (market_a_post : felt,
        market_b_post : felt, user_gets_b : felt):
    end
end

#### Game key ####
# World: 40 locations (city, suburb) pairs.
# city_ids: [1,10]
# suburb_ids: [1,4]
# user_ids: [1,10000]
# item_ids: [1,11]. 0=money, 1=item1, 2=item2, ..., etc.
# buy=0, sell=1.

#### Game state ####
# Specify user, item, return quantity.
@storage_var
func user_has_item(user_id : felt, item_id) -> (count : felt):
end

# Location of users. Input user, retrieve city.
@storage_var
func user_in_city(user_id : felt) -> (city_id : felt):
end

# Location of users. Input user, retrieve suburb.
@storage_var
func user_in_suburb(user_id : felt) -> (surburb_id : felt):
end

# Returns the count of some item for a given market, defined by location.
@storage_var
func market_has_item(city_id : felt, suburb_id : felt,
    item_id : felt) -> (count : felt):
end

# A market has their money in discrete accounts, one account per item.
@storage_var
func market_has_money(city_id : felt, suburb_id : felt,
    item_id : felt) -> (count : felt):
end


#### Admin Functions for Testing ####
# Sets the address of the deployed MarketMaker.cairo contract.
@external
func set_market_maker_address{storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*, range_check_ptr}(
        address : felt):
    # Used for testing. This can be ca constant on deployment.
    market_maker_address.write(address)
    return ()
end


# Creates an item-money market pair with specific liquidity.
@external
func admin_set_market_amount{storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*, range_check_ptr}(city_id : felt,
        suburb_id : felt, item_id : felt, item_quantity : felt,
        money_quantity : felt):
    # Set the quantity for a particular item in a specific market.
    # E.g., item_id 3, a market has 500 units, 3200 money liquidity.
    market_has_item.write(city_id, suburb_id, item_id, item_quantity)
    market_has_money.write(city_id, suburb_id, item_id, money_quantity)
    return ()
end


# Creates an item-money market pair with specific liquidity.
@external
func admin_set_user_amount{storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*, range_check_ptr}(user_id : felt,
        item_id : felt, item_quantity : felt):
    # Set the quantity for a particular item for a given user.
    # E.g., item_id 3, a user has market has 500 units. (id 0 is money).
    user_has_item.write(user_id, item_id, item_quantity)
    return ()
end


#### Game functions ####
# Actions turn (move user, execute trade).
@external
func have_turn{syscall_ptr : felt*, storage_ptr : Storage*,
        pedersen_ptr : HashBuiltin*, range_check_ptr}(user_id : felt,
        city_id : felt, suburb_id : felt, buy_or_sell : felt,
        item_id : felt, amount_to_give : felt):
    # E.g., Sell 300 units of item. amount_to_give = 300.
    # E.g., Buy using 120 units of money. amount_to_give = 120.
    alloc_locals
    assert_nn_le(buy_or_sell, 1)  # Only 0 or 1 valid.
    # Move user
    user_in_city.write(user_id, city_id)
    user_in_suburb.write(user_id, suburb_id)

    # giving_id = 0 if buying, giving_id = item_id if selling.
    local giving_id = item_id * buy_or_sell
    # receiving_id = item_id if buying, receiving_id = 0 if selling.
    local receiving_id = item_id * (1 - buy_or_sell)

    # A is always being given by user. B is always received by user.

    # Pre-giving balance.
    let (local user_a_pre) = user_has_item.read(user_id, giving_id)
    assert_nn_le(amount_to_give, user_a_pre)
    # Post-giving balance.
    local user_a_post = user_a_pre - amount_to_give
    # Save reduced balance to state.
    user_has_item.write(user_id, giving_id, user_a_post)

    # Pre-receiving balance.
    let (local user_b_pre) = user_has_item.read(user_id, receiving_id)
    # Post-receiving balance depends on MarketMaker.

    # Record pre-trade market balances.
    if buy_or_sell == 0:
        # Buying. A money, B item.
        let (market_a_pre_temp) = market_has_money.read(
            city_id, suburb_id, item_id)
        let (market_b_pre_temp) = market_has_item.read(
            city_id, suburb_id, item_id)
    else:
        # Selling. A item, B money.
        let (market_a_pre_temp) = market_has_item.read(
            city_id, suburb_id, item_id)
        let (market_b_pre_temp) = market_has_money.read(
            city_id, suburb_id, item_id)
    end
    # Finalise values after IF-ELSE section (handles fp).
    local market_a_pre = market_a_pre_temp
    local market_b_pre = market_b_pre_temp

    # Uncomment for pytest: Get address of MarketMaker.
    let (market_maker) = market_maker_address.read()
    # let market_maker = MARKET_MAKER_ADDRESS

    # Execute trade by calling the market maker contract.
    let (market_a_post, market_b_post,
        user_gets_b) = IMarketMaker.trade(market_maker,
        market_a_pre, market_b_pre, amount_to_give)

    # Post-receiving balance depends on user_gets_b.
    let user_b_post = user_b_pre + user_gets_b
    # Save increased balance to state.
    user_has_item.write(user_id, receiving_id, user_b_post)

    # Update post-trade states (market & user, items a & b).
    if buy_or_sell == 0:
        # User bought item. A is money.
        market_has_money.write(city_id, suburb_id,
            item_id, market_a_post)
        # B is item.
        market_has_item.write(city_id, suburb_id, item_id,
            market_b_post)
    else:
        # User sold item. A is item.
        market_has_item.write(city_id, suburb_id, item_id,
            market_a_post)
        # B is money.
        market_has_money.write(city_id, suburb_id, item_id,
            market_b_post)
    end
    return ()
end


#### Read-Only Functions for Testing ####
# A read-only function to inspect user state.
@view
func check_user_state{
        storage_ptr : Storage*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(user_id : felt) -> (money : felt,
        id1 : felt, id2 : felt, id3 : felt, id4 : felt, id5 : felt,
        id6 : felt, id7 : felt, id8 : felt, id9 : felt, id10 : felt,
        city : felt, suburb : felt):
    alloc_locals
    # Get the quantity held for each item.
    let (local money) = user_has_item.read(user_id, 0)
    let (local id1) = user_has_item.read(user_id, 1)
    let (local id2) = user_has_item.read(user_id, 2)
    let (local id3) = user_has_item.read(user_id, 3)
    let (local id4) = user_has_item.read(user_id, 4)
    let (local id5) = user_has_item.read(user_id, 5)
    let (local id6) = user_has_item.read(user_id, 6)
    let (local id7) = user_has_item.read(user_id, 7)
    let (local id8) = user_has_item.read(user_id, 8)
    let (local id9) = user_has_item.read(user_id, 9)
    let (local id10) = user_has_item.read(user_id, 10)
    # Get location
    let (local city) = user_in_city.read(user_id)
    let (local suburb) = user_in_suburb.read(user_id)
    return (money, id1, id2, id3, id4, id5, id6, id7, id8, id9, id10,
        city, suburb)
end


# A read-only function to inspect pair state of a particular market.
@view
func check_market_state{
        storage_ptr : Storage*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(city : felt, suburb : felt,
        item_id : felt) -> (item_quantity : felt, money_quantity):
    alloc_locals
    # Get the quantity held for each item for item-money pair
    let (local item_quantity) = market_has_item.read(city, suburb,
        item_id)
    let (local money_quantity) = market_has_money.read(city, suburb,
        item_id)
    return (item_quantity, money_quantity)
end
