%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.utils.game_structs import UserData

from contracts.utils.interfaces import (IModuleController,
    I04_UserRegistry)

# Returns a struct of decoded user data from binary-encoded registry.
func fetch_user_data{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr
    }(
        controller_address : felt,
        user_id : felt
    ) -> (
        user_stats : UserData
    ):
    alloc_locals
    let (local registry) = IModuleController.get_module_address(
        controller_address, 4)
    # Indicies are defined in the UserRegistry contract.
    # Call the UserRegsitry contract to get scores for given user.
    let (local weapon) = I04_UserRegistry.unpack_score(registry, user_id, 6)
    let (local vehicle) = I04_UserRegistry.unpack_score(registry, user_id, 26)
    let (local foot) = I04_UserRegistry.unpack_score(registry, user_id, 46)
    let (local necklace) = I04_UserRegistry.unpack_score(registry, user_id, 66)
    let (local ring) = I04_UserRegistry.unpack_score(registry, user_id, 76)
    let (local drug) = I04_UserRegistry.unpack_score(registry, user_id, 90)

    # Populate struct.
    let user_stats = UserData(
        weapon_strength=weapon,
        vehicle_speed=vehicle,
        foot_speed=foot,
        necklace_bribe=necklace,
        ring_bribe=ring,
        special_drug=drug
    )
    return (user_stats=user_stats)
end
