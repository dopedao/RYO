%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_caller_address

from contracts.utils.interfaces import IModuleController

##### Module 09 #####
#
# This module provides a mechanism for users to coordinate
# around short-text based user-generated content. Players can
# tag the wall, and engage in appriaising the tags of others.
# Tags can be messages, or they can be more complex representations
# such as narratives or proposals. The concept is to play with
# the idea of 'micro-voting' (voting on L2, where it is cheap enough
# do higher levels of community on-chain interaction).
# The 'post-delegation-age'.
#
####################


@storage_var
func controller_address() -> (address : felt):
end

@storage_var
func tag_count() -> (value : felt):
end

# Stores tags by index.
@storage_var
func tag(tag_index : felt) -> (tag : felt):
end

# Stores points per tag.
@storage_var
func tag_points(tag_index : felt) -> (value : felt):
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
func leave_tag{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        text : felt
    ):
    let (tag_index) = tag_count.read()
    tag_count.write(tag_index + 1)
    tag.write(tag_index, text)
    return ()
end

# Called by another module to update a global variable.
@external
func respect_a_tag{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        tag_index : felt
    ):
    let (points) = tag_points.read(tag_index)
    tag_points.write(tag_index, points + 1)
    return ()
end

@view
func read_tags{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }() -> (
        tags_len : felt,
        tags : felt*,
        points_len : felt,
        points : felt*,
    ):
    alloc_locals
    let (local tags : felt*) = alloc()
    let (local points : felt*) = alloc()
    let (local tags_len) = tag_count.read()

    loop_tags(tags_len, tags, points)
    return (tags_len, tags, tags_len, points)
end

# Loops over tags and appends the text and points to arrays.
func loop_tags{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        n : felt,
        tags : felt*,
        points : felt*
    ):
    if n == 0:
        return ()
    end
    loop_tags(n, tags, points)
    let tag_index = n - 1
    let (current_tag) = tag.read(tag_index)
    let (current_points) = tag_points.read(tag_index)
    assert tags[tag_index] = current_tag
    assert points[tag_index] = current_points
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