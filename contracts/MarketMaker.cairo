%lang starknet
%builtins range_check

from starkware.cairo.common.math import assert_nn_le, unsigned_div_rem

# The maximum value an item can have.
const BALANCE_UPPER_BOUND = 2 ** 64

# Accepts an AMM state and an order, instantiates AMM, swaps, returns balances.
# The market gains item `a` loses item `b`, the user loses item `a` gains item `b`.
@external
func trade{range_check_ptr}(
    market_a_pre : felt, market_b_pre : felt, user_gives_a : felt) -> (
    market_a_post : felt, market_b_post : felt, user_gets_b : felt):
    # Prevent values exceeding max.
    assert_nn_le(market_a_pre, BALANCE_UPPER_BOUND - 1)
    assert_nn_le(market_b_pre, BALANCE_UPPER_BOUND - 1)
    assert_nn_le(user_gives_a, BALANCE_UPPER_BOUND - 1)

    # Calculated how much item `b` the user gets.
    # user_gets_b = market_b_pre * user_gives_a // (market_a_pre + user_gives_a)
    let (user_gets_b, _) = unsigned_div_rem(
        market_b_pre * user_gives_a, market_a_pre + user_gives_a)

    # Calculate what the market is left with.
    let market_a_post = market_a_pre + user_gives_a
    let market_b_post = market_b_pre - user_gets_b

    # Ensure that all value updates are >= 1.
    assert_nn_le(1, user_gives_a)
    assert_nn_le(1, user_gets_b)
    assert_nn_le(1, market_a_post - market_a_pre)
    assert_nn_le(1, market_b_pre - market_b_post)

    # Check not items conjured into existence.
    assert (market_a_pre + market_b_pre + user_gives_a) = (
        market_a_post + market_b_post + user_gets_b)
    return (market_a_post, market_b_post, user_gets_b)
end
