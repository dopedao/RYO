%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from contracts.utils.interfaces import IModuleController

##### Module XX #####
#
# This module ...
#
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
        location_id : felt
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

# Sets the initial market maker values for a given item_id.
@external
func admin_set_pairs{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        item_list_len : felt,
        item_list : felt*,
        money_list_len : felt,
        money_list : felt*,
    ):
    # Spawns the 1444 AMMs each with an item and money quantity.

    # The game starts with 76 locations. [0, 75]
    # 19 cities with 4 districts. Each with 19 item-money pairs.
    # First locations, then item ids, then save value from each list.
    # Location ids [0, 75]
    #   Item ids [0, 19]
    #       Save item val.
    #       Save money val

    # List len = 19 items x 4 districts x 19 drugs = 1444.
    # Items: [bayou_dist_0_weed_val, bayou_dist_0_cocaine_val,
    #   ..., buffalo_dist_3_adderall_val]
    # Money: [bayou_dist_0_weed_money, ..., buffalo_dist_3_adderall_money]

    # Pass both lists and item number to iterate and save.
    loop_over_locations(76, item_list, money_list)
    # Start the game clock where everyone can play.

    return ()
end


# Recursion to populate one market pair in all locations.
func loop_over_locations{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        location_id : felt,
        item_list : felt*,
        money_list : felt*,
    ) -> ():
    # Location_id==Index
    if location_id == 0:
        # Triggers part 2.
        return ()
    end
    # Call recursively until location=1, then a return is hit.
    loop_over_locations(location_id - 1, item_list, money_list)
    # Part 2. Loop the items in this location.
    # Upon first entry here location_id=1, on second location_id=2.
    # Go over the items starting with location_id=0.
    loop_over_items(19, location_id - 1, item_list, money_list)
    return ()
end


# Recursion to populate one market pair in all locations.
func loop_over_items{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        item_id : felt,
        location_id : felt,
        item_list : felt*,
        money_list : felt*,
    ) -> ():
    # Location_id==Index
    if item_id == 0:
        # Triggers part 3.
        return ()
    end
    # Call recursively until item_id=1, then a return is hit.
    loop_over_items(item_id - 1, location_id, item_list, money_list)
    # Part 3. Save the state.
    # Upon first entry here item_id=1, on second item_id=2.

    # Get the position of the element in the list.
    # On first round, first entry, index = 0*19 + 1 - 1 = 0
    # On first round , second entry, index = 0*19 + 2 - 1 = 1
    # On second round, first entry, index = 1*19 + 1 - 1 = 20

    # Get index of the element: Each location has 19 elements,
    # followed by anFirst locat
    let index = location_id * 19 + item_id - 1
    # Locations are zero-based.
    # Items are 1-based. (because for a user, item_id=0 is money).

    let money_val = money_list[index]
    let item_val = item_list[index]
    location_has_item.write(location_id, item_id, item_val)
    location_has_money.write(location_id, money_val)
    return ()
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

