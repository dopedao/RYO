%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

from contracts.utils.interfaces import IModuleController

##### Module XX #####
#
# This module ...
#
#
####################

# Specify user, item, return quantity.
@storage_var
func user_has_item(
        user_id : felt,
        item_id : felt
    ) -> (
        count : felt
    ):
end

# Location of users. Input user, retrieve city.
@storage_var
func user_in_location(
        user_id : felt
    ) -> (
        location_id : felt
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
func user_has_item_write{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        user_id : felt,
        item_id : felt,
        value : felt
    ):
    only_approved()
    user_has_item.write(user_id, item_id, value)
    return ()
end

@external
func user_has_item_read{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        user_id : felt,
        item_id : felt
    ) -> (
        value : felt
    ):
    let (value) = user_has_item.read(user_id, item_id)
    return (value)
end


# Called by another module to update a global variable.
@external
func user_in_location_write{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        user_id : felt,
        location_id : felt
    ):
    only_approved()
    user_in_location.write(user_id, location_id)
    return ()
end

@external
func user_in_location_read{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        user_id : felt
    ) -> (
        location_id : felt
    ):
    let (location_id) = user_in_location.read(user_id)
    return (location_id)
end


# A read-only function to inspect user state.
@view
func check_user_state{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        user_id : felt
    ) -> (
        items_len : felt,
        items : felt*,
        location : felt
    ):
    alloc_locals
    # Get the quantity held for each item.
    # Item 0 is money. First drug is item 1.
    let (money) = user_has_item_read(user_id, 0)
    let (id1) = user_has_item_read(user_id, 1)
    let (id2) = user_has_item_read(user_id, 2)
    let (id3) = user_has_item_read(user_id, 3)
    let (id4) = user_has_item_read(user_id, 4)
    let (id5) = user_has_item_read(user_id, 5)
    let (id6) = user_has_item_read(user_id, 6)
    let (id7) = user_has_item_read(user_id, 7)
    let (id8) = user_has_item_read(user_id, 8)
    let (id9) = user_has_item_read(user_id, 9)
    let (id10) = user_has_item_read(user_id, 10)
    let (id11) = user_has_item_read(user_id, 11)
    let (id12) = user_has_item_read(user_id, 12)
    let (id13) = user_has_item_read(user_id, 13)
    let (id14) = user_has_item_read(user_id, 14)
    let (id15) = user_has_item_read(user_id, 15)
    let (id16) = user_has_item_read(user_id, 16)
    let (id17) = user_has_item_read(user_id, 17)
    let (id18) = user_has_item_read(user_id, 18)
    let (id19) = user_has_item_read(user_id, 19)

    let (items : felt*) = alloc()
    assert items[0] = money
    assert items[1] = id1
    assert items[2] = id2
    assert items[3] = id3
    assert items[4] = id4
    assert items[5] = id5
    assert items[6] = id6
    assert items[7] = id7
    assert items[8] = id8
    assert items[9] = id9
    assert items[10] = id10
    assert items[11] = id11
    assert items[12] = id12
    assert items[13] = id13
    assert items[14] = id14
    assert items[15] = id15
    assert items[16] = id16
    assert items[17] = id17
    assert items[18] = id18
    assert items[19] = id19
    # Get location
    let (location) = user_in_location.read(user_id)
    return (20, items, location)
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


