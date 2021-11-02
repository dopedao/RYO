%lang starknet

from contracts.utils.game_structs import UserData

# These are interfaces that can be imported by other contracts for convenience.
# All of the functions in an interface must be @view or @external.

# Interface for the ModuleController.
@contract_interface
namespace IModuleController:
    func get_module_address(
        module_id : felt
    ) -> (
        address : felt
    ):
    end

    func has_write_access(
        address_attempting_to_write : felt
    ):
    end

    func appoint_new_arbiter(
        new_arbiter : felt
    ):
    end

    func set_address_for_module_id(
        module_id : felt,
        module_address : felt):
    end

    func set_write_access(
        module_id_doing_writing : felt,
        module_id_being_written_to : felt):
    end
end


@contract_interface
namespace I02_LocationOwned:
    func location_has_item_read(
        location_id : felt,
        item_id : felt
    ) -> (
        count : felt
    ):
    end
    func location_has_item_write(
        location_id : felt,
        item_id : felt,
        count : felt
    ):
    end
    func location_has_money_read(
        location_id : felt,
    ) -> (
        count : felt
    ):
    end
    func location_has_money_write(
        location_id : felt,
        count : felt
    ):
    end
end



@contract_interface
namespace I03_UserOwned:
    func user_has_item_read(
        user_id : felt,
        item_id : felt
    ) -> (
        count : felt
    ):
    end
    func user_has_item_write(
        user_id : felt,
        item_id : felt,
        count : felt
    ):
    end
    func user_in_location_read(
        user_id : felt
    ) -> (
        location_id : felt
    ):
    end
    func user_in_location_write(
        user_id : felt,
        location_id : felt
    ):
    end
end


# Declare the interface with which to call the UserRegistry contract.
@contract_interface
namespace I04_UserRegistry:
    func get_user_info(
        user_id : felt,
        starknet_pubkey : felt
    ) -> (
        user_data : felt
    ):
    end
    func unpack_score(
        user_id : felt,
        index : felt
    ) -> (
        score : felt
    ):
    end
end

# Declare the interfacs with which to call the Combat contract.
@contract_interface
namespace I05_Combat:
    func fight_1v1(
        user_data : UserData,
        lord_user_data : UserData,
        user_combat_stats_len : felt,
        user_combat_stats : felt*,
        drug_lord_combat_stats_len : felt,
        drug_lord_combat_stats : felt*
    ) -> (
        user_wins_bool : felt
    ):
    end
end

@contract_interface
namespace I06_DrugLord:
    func drug_lord_read(
        location_id : felt
    ) -> (
        user_id : felt
    ):
    end
    # Modify variable.
    func drug_lord_write(
        location_id : felt,
        user_id : felt
    ):
    end
    func drug_lord_stat_hash_read(
        location_id : felt
    ) -> (
        stat_hash : felt
    ):
    end
    func drug_lord_stat_hash_write(
        location_id : felt,
        stat_hash : felt
    ):
    end
end


@contract_interface
namespace I07_PseudoRandom:
    func get_pseudorandom(
    ) -> (
        num_to_use : felt
    ):
    end
    func add_to_seed(
        val0 : felt,
        val1 : felt
    ) -> (
        num_to_use : felt
    ):
    end
end