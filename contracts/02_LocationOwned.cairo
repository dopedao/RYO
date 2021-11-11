%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.dict import dict_write, dict_read
from starkware.cairo.common.default_dict import (default_dict_new,
    default_dict_finalize)
from starkware.starknet.common.syscalls import get_caller_address

from contracts.utils.interfaces import IModuleController
from contracts.utils.game_constants import (DEFAULT_MARKET_MONEY,
    DEFAULT_MARKET_ITEM, DISTRICTS)

##### Module 02 #####
#
# This keeps the values of the items (drugs) and money for each
# dealer across all locations. Every item (19) has a unique market
# curve in each location (76). The markets initially have opaque
# values and upon first trade, a value is procedurally generated
# according to a profile that is defined by the nature of the location
# and the nature of the item. After this point, the value is susceptible
# to market dynamics and randomised exogenous shocks.
# There is no concept of users providing liquidity - they give
# either money or an item to the curve and receive something in return.
#
####################

# Returns item count for item-money pair in location.
# E.g., first location (location_id=0), first item (item_id=1)
@storage_var
func location_has_item(
        location_id : felt,
        item_id : felt
    ) -> (
        count : felt
    ):
end

# Returns money count for item-money pair in location.
# E.g., first location (location_id=0), first item (item_id=1)
@storage_var
func location_has_money(
        location_id : felt,
        item_id : felt
    ) -> (
        count : felt
    ):
end

@storage_var
func controller_address() -> (address : felt):
end


# Called on deployment only.
@constructor
func constructor{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        address_of_controller : felt
    ):
    # Store the address of the only fixed contract in the system.
    controller_address.write(address_of_controller)
    return ()
end


# Called by another module to update a global variable.
@external
func update_value{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    # TODO Customise.
    only_approved()
    return ()
end


@external
func location_has_item_read{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        location_id : felt,
        item_id : felt
    ) -> (
        count : felt
    ):
    only_approved()
    let (count) = location_has_item.read(location_id, item_id)
    # If the count is zero, the market has not been initialized.
    if count == 0:
        let (item, money) = generate_curve(location_id, item_id)
        location_has_item.write(location_id, item_id, item)
        location_has_money.write(location_id, item_id, money)
        return (item)
    end
    return (count)
end


@external
func location_has_money_read{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        location_id : felt,
        item_id : felt
    ) -> (
        count : felt
    ):
    only_approved()
    let (count) = location_has_money.read(location_id, item_id)
    # If the count is zero, the market has not been initialized.
    if count == 0:
        let (item, money) = generate_curve(location_id, item_id)
        location_has_item.write(location_id, item_id, item)
        location_has_money.write(location_id, item_id, money)
        return (money)
    end
    return (count)
end

@external
func location_has_item_write{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        location_id : felt,
        item_id : felt,
        count : felt
    ):
    only_approved()
    location_has_item.write(location_id, item_id, count)
    return ()
end

@external
func location_has_money_write{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        location_id : felt,
        item_id : felt,
        count : felt
    ):
    only_approved()
    location_has_money.write(location_id, item_id, count)
    return ()
end

##### Initial value generation #####
#
# For each location, initial quantities are set based on a rule
# and some randomness. E.g., a city might be defined by having
# very low MONEY on each of its item curves, which makes all the
# items more expensive than other locations.

# The locations have different starting profiles that are multifactorial:
# - Money: low/high
# - Items: low/high

# Relative quantities: # 100 normal, 110 (10% more than normal)
# These values have not been 'curated'.
# This section describes initial money in that city.
# A city with high value has more quantity of money in general.
#
##########
# If a market has no value yet, one is set and saved.
func generate_curve{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        location_id : felt,
        item_id : felt
    ) -> (
        item_count : felt,
        money_count : felt
    ):
    alloc_locals
    # Generates and saves both sides of the curve (money and item).
    let (local city_index, local district_index) = get_indices(location_id)

    # Quantities are multifactorial.
    let (city_money_factor) = city_money_lookup(city_index)
    let (city_item_factor) = city_item_lookup(city_index)

    let (district_money_factor) = district_money_lookup(district_index)
    let (district_item_factor) = district_item_lookup(district_index)

    let (item_money_factor) = item_money_lookup(item_id)
    let (item_quantity_factor) = item_quantity_lookup(item_id)

    # Combine factors.
    let (money_count) = combine_factors(DEFAULT_MARKET_MONEY,
        city_money_factor, district_money_factor, item_money_factor)
    let (item_count) = combine_factors(DEFAULT_MARKET_ITEM,
        city_item_factor, district_item_factor, item_quantity_factor)

    return (item_count, money_count)
end

# Returns the starting value by applying multipl factors.
func combine_factors{
        range_check_ptr
    }(
        default_amount : felt,
        city_factor : felt,
        district_factor : felt,
        item_factor
    ) -> (
        value
    ):
    # Returns the value to be used for initialising half a curve.
    # Factors are relative to 100 (100 is no change).
    # E.g. 10000 * 90 * 90 * 70 / 1000000 = 567
    # (Rather than 10000 * .9 * .9 * .7)
    let num = default_amount * city_factor * district_factor * item_factor
    let (value, _) = unsigned_div_rem(num, 1000000)
    return (value)
end

# Returns the relative money in a city for spawning a market.
func city_money_lookup{
        range_check_ptr
    }(
        city_index : felt
    ) -> (
        val : felt
    ):
    # Holds a lookup table.
    alloc_locals
    let (local dict) = default_dict_new(0)
    dict_write{dict_ptr=dict}(0, 60)
    dict_write{dict_ptr=dict}(1, 70)
    dict_write{dict_ptr=dict}(2, 80)
    dict_write{dict_ptr=dict}(3, 90)
    dict_write{dict_ptr=dict}(4, 100)
    dict_write{dict_ptr=dict}(5, 110)
    dict_write{dict_ptr=dict}(6, 120)
    dict_write{dict_ptr=dict}(7, 130)
    dict_write{dict_ptr=dict}(8, 140)
    dict_write{dict_ptr=dict}(9, 150)
    dict_write{dict_ptr=dict}(10, 65)
    dict_write{dict_ptr=dict}(12, 75)
    dict_write{dict_ptr=dict}(13, 85)
    dict_write{dict_ptr=dict}(14, 95)
    dict_write{dict_ptr=dict}(15, 105)
    dict_write{dict_ptr=dict}(16, 115)
    dict_write{dict_ptr=dict}(17, 125)
    dict_write{dict_ptr=dict}(18, 135)

    default_dict_finalize(dict, dict, 0)
    let (val) = dict_read{dict_ptr=dict}(city_index)
    return (val)
end

# Returns the relative items in a city for spawning a market.
func city_item_lookup{
        range_check_ptr
    }(
        city_index : felt
    ) -> (
        val : felt
    ):
    # Holds a lookup table.
    alloc_locals
    let (local dict) = default_dict_new(0)
    dict_write{dict_ptr=dict}(0, 60)
    dict_write{dict_ptr=dict}(1, 70)
    dict_write{dict_ptr=dict}(2, 80)
    dict_write{dict_ptr=dict}(3, 90)
    dict_write{dict_ptr=dict}(4, 100)
    dict_write{dict_ptr=dict}(5, 110)
    dict_write{dict_ptr=dict}(6, 120)
    dict_write{dict_ptr=dict}(7, 130)
    dict_write{dict_ptr=dict}(8, 140)
    dict_write{dict_ptr=dict}(9, 150)
    dict_write{dict_ptr=dict}(10, 135)
    dict_write{dict_ptr=dict}(12, 125)
    dict_write{dict_ptr=dict}(13, 115)
    dict_write{dict_ptr=dict}(14, 105)
    dict_write{dict_ptr=dict}(15, 95)
    dict_write{dict_ptr=dict}(16, 85)
    dict_write{dict_ptr=dict}(17, 75)
    dict_write{dict_ptr=dict}(18, 65)

    default_dict_finalize(dict, dict, 0)
    let (val) = dict_read{dict_ptr=dict}(city_index)
    return (val)
end

# Returns the relative items in a city for spawning a market.
func district_item_lookup{
        range_check_ptr
    }(
        district_index : felt
    ) -> (
        val : felt
    ):
    # Holds a lookup table.
    alloc_locals
    let (local dict) = default_dict_new(0)
    dict_write{dict_ptr=dict}(0, 80)
    dict_write{dict_ptr=dict}(1, 100)
    dict_write{dict_ptr=dict}(2, 110)
    dict_write{dict_ptr=dict}(3, 120)

    default_dict_finalize(dict, dict, 0)
    let (val) = dict_read{dict_ptr=dict}(district_index)
    return (val)
end

# Returns the relative money in a city for spawning a market.
func district_money_lookup{
        range_check_ptr
    }(
        district_index : felt
    ) -> (
        val : felt
    ):
    # Holds a lookup table.
    alloc_locals
    let (local dict) = default_dict_new(0)
    dict_write{dict_ptr=dict}(0, 80)
    dict_write{dict_ptr=dict}(1, 100)
    dict_write{dict_ptr=dict}(2, 80)
    dict_write{dict_ptr=dict}(3, 120)

    default_dict_finalize(dict, dict, 0)
    let (val) = dict_read{dict_ptr=dict}(district_index)
    return (val)
end

# Returns the relative money for a given item for spawning a market.
func item_money_lookup{
        range_check_ptr
    }(
        item_id : felt
    ) -> (
        val : felt
    ):
    # Holds a lookup table.
    alloc_locals
    let (local dict) = default_dict_new(0)
    # These are not yet curated to match the nature of the drug.
    dict_write{dict_ptr=dict}(1, 70)
    dict_write{dict_ptr=dict}(2, 80)
    dict_write{dict_ptr=dict}(3, 90)
    dict_write{dict_ptr=dict}(4, 100)
    dict_write{dict_ptr=dict}(5, 110)
    dict_write{dict_ptr=dict}(6, 120)
    dict_write{dict_ptr=dict}(7, 130)
    dict_write{dict_ptr=dict}(8, 140)
    dict_write{dict_ptr=dict}(9, 150)
    dict_write{dict_ptr=dict}(10, 135)
    dict_write{dict_ptr=dict}(12, 125)
    dict_write{dict_ptr=dict}(13, 115)
    dict_write{dict_ptr=dict}(14, 105)
    dict_write{dict_ptr=dict}(15, 95)
    dict_write{dict_ptr=dict}(16, 85)
    dict_write{dict_ptr=dict}(17, 75)
    dict_write{dict_ptr=dict}(18, 65)
    dict_write{dict_ptr=dict}(19, 60)

    default_dict_finalize(dict, dict, 0)
    let (val) = dict_read{dict_ptr=dict}(item_id)
    return (val)
end

# Returns the relative item quantity for a given item for spawning a market.
func item_quantity_lookup{
        range_check_ptr
    }(
        item_id : felt
    ) -> (
        val : felt
    ):
    # Holds a lookup table.
    alloc_locals
    let (local dict) = default_dict_new(0)
    # These are not yet curated to match the nature of the drug.
    dict_write{dict_ptr=dict}(1, 70)
    dict_write{dict_ptr=dict}(2, 80)
    dict_write{dict_ptr=dict}(3, 90)
    dict_write{dict_ptr=dict}(4, 100)
    dict_write{dict_ptr=dict}(5, 110)
    dict_write{dict_ptr=dict}(6, 120)
    dict_write{dict_ptr=dict}(7, 130)
    dict_write{dict_ptr=dict}(8, 140)
    dict_write{dict_ptr=dict}(9, 150)
    dict_write{dict_ptr=dict}(10, 65)
    dict_write{dict_ptr=dict}(12, 75)
    dict_write{dict_ptr=dict}(13, 85)
    dict_write{dict_ptr=dict}(14, 95)
    dict_write{dict_ptr=dict}(15, 105)
    dict_write{dict_ptr=dict}(16, 115)
    dict_write{dict_ptr=dict}(17, 125)
    dict_write{dict_ptr=dict}(18, 135)
    dict_write{dict_ptr=dict}(19, 145)

    default_dict_finalize(dict, dict, 0)
    let (val) = dict_read{dict_ptr=dict}(item_id)
    return (val)
end

func get_indices{
        range_check_ptr
    }(
        location_id : felt
    ) -> (
        city_index : felt,
        district_index : felt
    ):
    # 76 Locations [0, 75] are divided into 19 cities with 4 districts.
    # First four are city_index=0, district indices 0-3.
    # location_ids are sequential.
    # [loc_0_dis_0, loc_0_dis_1, ..., loc_75_dis_3, loc_75_dis_3]

    # For the supplied location_id, find the ids of nearby districts.
    # E.g., loc 7 is second city third district (city 1, district 3)
    # 1. City = integer division by number of districts. 7//4 = 1
    # and location 34 is city index 8.
    let (city_index, district_index) = unsigned_div_rem(location_id, DISTRICTS)
    # Loction id is the city + district index. [0, 3] for 4 districts.
    # E.g. for city index 8, the location_ids are:
    # 8 * 4, 8 * 4 + 1, 8 * 4 + 2, 8 * 4 + 3.
    # (32, 33, 34, 35)
    # So location_id for first city in this region is:
    return (city_index, district_index)
end

# Checks write-permission of the calling contract.
func only_approved{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }():
    # Get the address of the module trying to write to this contract.
    let (caller) = get_caller_address()
    let (controller) = controller_address.read()
    # Pass this address on to the ModuleController.
    # "Does this address have write-authority here?"
    # Will revert the transaction if not.
    IModuleController.has_write_access(
        contract_address=controller,
        address_attempting_to_write=caller)
    return ()
end

