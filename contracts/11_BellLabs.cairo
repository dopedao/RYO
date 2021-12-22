%lang starknet
%builtins pedersen range_check

# Imports
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import unsigned_div_rem
from starkware.starknet.common.syscalls import get_caller_address

from contracts.utils.interfaces import IModuleController

##### Module 11 #####
#
# This module provides scores for players along specific axes.
# An axis can be used to assess how well suited a player is
# to a certain context. Axes can be thought of as colours.
# A player equipped with a lot of green items might perform poorly
# in a red game context, but well in a green context and neutral in
# a blue context.
#
####################

# Axes are given numbers according to the following key:
# - 1 Red
# - 2 Green
# - 3 Blue

# @notice A struct representing the wearable traits.
# @dev This is the order they should appear in the array.
struct Items:
    member weapon : felt
    member clothes : felt
    member vehicle : felt
    member waist : felt
    member foot : felt
    member hand : felt
    member necklace : felt
    member ring : felt
    member item_suffix : felt
    member drug : felt
    member name_prefix : felt
    member name_suffix : felt
end

# @notice Stores the address of the only fixed contract in the system.
@storage_var
func controller_address() -> (address : felt):
end

# @notice Sets up the contract.
# @dev Only called once.
@constructor
func constructor{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        address_of_controller : felt
    ):
    controller_address.write(address_of_controller)
    return ()
end


# @notice Returns the global score for the requested axis.
# @param axis The number of the axis requested (key top of file).
# @param equipped_items_len Length of the list (A helper value).
# @param equipped_items An array of item ids, as ordered in the DOPE NFT.
@view
func get_aggregate_score{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        axis : felt,
        items_array_len : felt,
        items_array : felt*
    ) -> (
        score : felt
    ):
    alloc_locals
    # Convert the array to a struct.
    let (local items : Items) = array_to_struct(items_array)

    let (local weapon) = get_item_score(axis, 0, items)
    # TODO: remaining categories.
    # let (local clothes) = get_item_score(axis, item_type=11, items)
    # etc.
    let (local ring) = get_item_score(axis, 7, items)
    let (local drugs) = get_item_score(axis, 9, items)

    let sum = weapon + ring + drugs
    # Basic formula: Calculate the average
    let (average, _) = unsigned_div_rem(sum, 3)
    return (average)
end

# @notice Returns the single item score for the requested axis. Can be called independently by a game module.
# @param axis The number of the axis requested (key top of file).
# @param item_type Item type as ordered in the DOPE NFT.
# @param item Specific item, as ordered in the DOPE NFT.
# @return result The single-item score for the axis, in range [0, 99].
@view
func get_item_score{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        axis : felt,
        item_type : felt,
        items : Items
    ) -> (
        result : felt
    ):
    alloc_locals
    # This is all a hacky method to call different functions based
    # on different input value (if 0 call func_0, if 1 call func_1 etc).
    # If you are reading this and see a better method let me know.
    let bool_weapon = item_type - 0
    let bool_clothes = item_type - 1
    let bool_vehicle = item_type - 2
    let bool_waist = item_type - 3
    let bool_foot = item_type - 4
    let bool_hand = item_type - 5
    let bool_necklace = item_type - 6
    let bool_ring = item_type - 7
    let bool_item_suffix = item_type - 8
    let bool_drug = item_type - 9
    let bool_name_prefix = item_type - 10
    let bool_name_suffix = item_type - 11

    # If the item is that being examined, get the score.
    local result
    if bool_weapon == 0:
        let (score) = get_weapon(axis, items.weapon)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
        assert result = score
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    if bool_clothes == 0:
        let (score) = get_clothes(axis, items.clothes)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
        assert result = score
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    if bool_vehicle == 0:
        let (score) = get_vehicle(axis, items.vehicle)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
        assert result = score
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    if bool_waist == 0:
        let (score) = get_waist(axis, items.waist)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
        assert result = score
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    if bool_foot == 0:
        let (score) = get_foot(axis, items.foot)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
        assert result = score
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    if bool_hand == 0:
        let (score) = get_hand(axis, items.hand)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
        assert result = score
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    if bool_necklace == 0:
        let (score) = get_necklace(axis, items.necklace)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
        assert result = score
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    if bool_ring == 0:
        let (score) = get_ring(axis, items.ring)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
        assert result = score
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    if bool_item_suffix == 0:
        let (score) = get_item_suffix(axis, items.item_suffix)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
        assert result = score
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    if bool_drug == 0:
        let (score) = get_drug(axis, items.drug)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
        assert result = score
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    if bool_name_prefix == 0:
        let (score) = get_name_prefix(axis, items.name_prefix)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
        assert result = score
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    if bool_name_suffix == 0:
        let (score) = get_name_suffix(axis, items.name_suffix)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
        assert result = score
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    return (result)
end



# @notice Helper function that makes an array into a struct
# @dev Used for readability.
# @param items_array An array of item slots with specific item indices.
# @return items A struct with specific item indices.
func array_to_struct(
        items_array : felt*
    ) -> (
        items : Items
    ):
    alloc_locals
    local items : Items
    # Set the struct member values.
    assert items.weapon = items_array[0]
    assert items.clothes = items_array[1]
    assert items.vehicle = items_array[2]
    assert items.waist = items_array[3]
    assert items.foot = items_array[4]
    assert items.hand = items_array[5]
    assert items.necklace = items_array[6]
    assert items.ring = items_array[7]
    assert items.item_suffix = items_array[8]
    assert items.drug = items_array[9]
    assert items.name_prefix = items_array[10]
    assert items.name_suffix = items_array[11]
    # Return the struct.
    return (items)
end



# @notice Gets the score for a given item on a given axis.
func get_weapon{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        axis : felt,
        item : felt
    ) -> (
        result : felt
    ):
    let result = 50
    return (result)
end

# @notice Gets the score for a given item on a given axis.
func get_clothes{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        axis : felt,
        item : felt
    ) -> (
        result : felt
    ):
    let result = 50
    return (result)
end

# @notice Gets the score for a given item on a given axis.
func get_vehicle{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        axis : felt,
        item : felt
    ) -> (
        result : felt
    ):
    let result = 50
    return (result)
end

# @notice Gets the score for a given item on a given axis.
func get_waist{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        axis : felt,
        item : felt
    ) -> (
        result : felt
    ):
    let result = 50
    return (result)
end

# @notice Gets the score for a given item on a given axis.
func get_foot{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        axis : felt,
        item : felt
    ) -> (
        result : felt
    ):
    let result = 50
    return (result)
end

# @notice Gets the score for a given item on a given axis.
func get_hand{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        axis : felt,
        item : felt
    ) -> (
        result : felt
    ):
    let result = 50
    return (result)
end

# @notice Gets the score for a given item on a given axis.
func get_necklace{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        axis : felt,
        item : felt
    ) -> (
        result : felt
    ):
    let result = 50
    return (result)
end

# @notice Gets the score for a given item on a given axis.
func get_ring{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        axis : felt,
        item : felt
    ) -> (
        result : felt
    ):
    let result = 50
    return (result)
end

# @notice Gets the score for a given item on a given axis.
func get_item_suffix{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        axis : felt,
        item : felt
    ) -> (
        result : felt
    ):
    let result = 50
    return (result)
end

# @notice Gets the score for a given item on a given axis.
func get_drug{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        axis : felt,
        item : felt
    ) -> (
        result : felt
    ):
    let result = 50
    return (result)
end

# @notice Gets the score for a given item on a given axis.
func get_name_prefix{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        axis : felt,
        item : felt
    ) -> (
        result : felt
    ):
    let result = 50
    return (result)
end

# @notice Gets the score for a given item on a given axis.
func get_name_suffix{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        axis : felt,
        item : felt
    ) -> (
        result : felt
    ):
    let result = 50
    return (result)
end

# @notice Used in situations where other modules have write access here.
# @dev Checks write-permission of the calling contract.
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