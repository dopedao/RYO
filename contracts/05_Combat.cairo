%lang starknet
%builtins pedersen range_check bitwise

from starkware.cairo.common.cairo_builtins import (HashBuiltin,
    BitwiseBuiltin)
from starkware.cairo.common.math import assert_nn_le, unsigned_div_rem
from starkware.cairo.common.math_cmp import is_nn_le
from starkware.starknet.common.syscalls import get_caller_address

from contracts.utils.game_structs import UserData, Fighter
from contracts.utils.general import list_to_hash
from contracts.utils.game_data_helpers import fetch_user_data

from contracts.utils.interfaces import (IModuleController,
    I03_UserOwned, I06_DrugLord)

##### Module 05 #####
#
# The fighter contract has no storage - it attempts to create complex
# interrelated dynamics requiring many computations to make the game
# interesting. The contract accepts two fighters and emits events
# during a multi-round battle. The winner is decided and is passed
# for storage in module 06. King-of-the-Hill style game. Module 01
# gives users taxes/cuts in a location if they are the curent Drug Lord.
#
#################

# General TODO
## [ ] Review the combat structure then implement the fight logic.
## [ ] Add token-UserData to the fight logic in addition to the user inputs

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

# Entry point for a player looking to challenge the current drug lord.
@external
func challenge_current_drug_lord{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr
    }(
        user_combat_stats_len : felt,
        user_combat_stats : felt*,
        drug_lord_combat_stats_len : felt,
        drug_lord_combat_stats : felt*
    ):
    alloc_locals
    # TODO
    ## [ ] Rate limit user (perhaps with DopeWars clock? Or new clock.)
    ## [ ] Fetch the user_id based on the caller address
    ## [ ] Check the location of the user.
    ## [ ] Fetch the current drug lord from module 06.
    let (local controller) = controller_address.read()
    let (local user_id) = get_caller_address()
    let (local drug_lord_addr) = IModuleController.get_module_address(
        controller, 6)
    let (local user_owned_addr) = IModuleController.get_module_address(
        controller, 3)
    let (local location_id) = I03_UserOwned.user_in_location_read(user_owned_addr, user_id)
    let (lord_user_id) = I06_DrugLord.drug_lord_read(drug_lord_addr, location_id)

    let (local user_data : UserData) = fetch_user_data(controller, user_id)
    let (local lord_user_data : UserData) = fetch_user_data(controller, lord_user_id)

    let (win_bool) = fight_lord(
        controller,
        location_id,
        user_id,
        user_data,
        lord_user_data,
        user_combat_stats_len,
        user_combat_stats,
        drug_lord_combat_stats_len,
        drug_lord_combat_stats,)

    ## [ ] Return win_bool and the events that took place for front end
    return ()
end


# Fight the drug lord.
func fight_lord{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        range_check_ptr
    }(
        controller : felt,
        location_id : felt,
        user_id : felt,
        user_data : UserData,
        lord_user_data : UserData,
        user_combat_stats_len : felt,
        user_combat_stats : felt*,
        drug_lord_combat_stats_len : felt,
        drug_lord_combat_stats : felt*
    ) -> (
        win_bool : felt
    ):
    alloc_locals
    # Check that the user provided the drug lord stats.
    local syscall_ptr : felt* = syscall_ptr
    let (provided_lord_hash) = list_to_hash(drug_lord_combat_stats,
        drug_lord_combat_stats_len)
    let (local drug_lord_addr) = IModuleController.get_module_address(
        controller, 6)
    let (current_lord_hash) = I06_DrugLord.drug_lord_stat_hash_read(
        drug_lord_addr, location_id)


    # If no current lord, save and 'win'.
    if current_lord_hash == 0:
        local syscall_ptr : felt* = syscall_ptr
        let (user_combat_hash) = list_to_hash(user_combat_stats,
            user_combat_stats_len)

        I06_DrugLord.drug_lord_stat_hash_write(drug_lord_addr,
            location_id, user_combat_hash)
        I06_DrugLord.drug_lord_write(drug_lord_addr, location_id, user_id)
        return (win_bool=1)
    else:
        local syscall_ptr : felt* = syscall_ptr
    end
    # If you fail to provide the current lord stats, pay the tax.
    if current_lord_hash != provided_lord_hash:
        return (win_bool=0)
    end

    local pedersen_ptr : HashBuiltin* = pedersen_ptr

    # Execute combat.
    let (local win_bool : felt) = fight_1v1(
        user_data,
        lord_user_data,
        user_combat_stats_len,
        user_combat_stats,
        drug_lord_combat_stats_len,
        drug_lord_combat_stats)
    local syscall_ptr : felt* = syscall_ptr

    if win_bool == 0:
        return (win_bool=0)
    end

    # Hash and store the user_id and combat stats as new lord.
    local syscall_ptr : felt* = syscall_ptr
    let (user_combat_hash) = list_to_hash(user_combat_stats,
        user_combat_stats_len)
    I06_DrugLord.drug_lord_stat_hash_write(drug_lord_addr,
        location_id, user_combat_hash)
    I06_DrugLord.drug_lord_write(drug_lord_addr, location_id, user_id)

    return(win_bool=1)
end


# Accepts two fighters (the user and the drug lord) and determines
# winner through combat using innate UserData and selected Stats.
func fight_1v1{
        range_check_ptr
    }(
        user_data : UserData,
        lord_user_data : UserData,
        user_combat_stats_len : felt,
        user_combat_stats : felt*,
        drug_lord_combat_stats_len : felt,
        drug_lord_combat_stats : felt*
    ) -> (
        user_wins_bool : felt
    ):
    alloc_locals
    # Make user stats readable.
    let (local user : Fighter) = array_to_struct(user_combat_stats,
        user_data)
    # If the user selected illegal parameters, they lose
    let (legal_params_bool) = are_params_legal(user)
    local range_check_ptr = range_check_ptr

    if legal_params_bool == 0:
        return (user_wins_bool=0)
    end

    # Make lord stats readable.
    let (local lord : Fighter) = array_to_struct(drug_lord_combat_stats,
        lord_user_data)

    # Start fight
    let (user_wins_bool : felt) = fight(user=user, lord=lord, round=10)

    return (user_wins_bool=user_wins_bool)
end


# Entry function for the actual fight
func fight{
        range_check_ptr
    }(
        user : Fighter,
        lord : Fighter,
        round : felt
    ) -> (
        defeated_bool : felt
    ):
    alloc_locals
    # If anyone is defeated before the last round, return.
    let defeated_bool = (1 - user.defeated) * (1 - lord.defeated)
    if defeated_bool == 0:
        return (defeated_bool)
    end
    if round == 0:
        return (defeated_bool)
    end

    let (local defeated_bool) = fight(user=user, lord=lord,
        round=round-1)

    # One round is two parts: First attack then be attacked.

    # E.g., attack, block attack, defend, block defend
    let (defeated_bool) = attack_sequence(att=user, def=lord)

    # If anyone is defeated, return.
    if user.defeated + lord.defeated != 0:
        return (defeated_bool=1)
    end
    let (defeated_bool) = attack_sequence(att=lord, def=user)

    # If anyone is defeated, return.
    if user.defeated + lord.defeated != 0:
        return (defeated_bool=1)
    end
    return (defeated_bool=0)
end

# Executes a four-part sequence for specified attacker/defender.
func attack_sequence{
        range_check_ptr
    }(
        att : Fighter,
        def : Fighter
    ) -> (
        defeated_bool : felt
    ):
    # In an attack, the defender accumulates damage, however, the
    # attacker may also receive damage from a react action.
    # Reset the damage cache before the sequence begins.
    assert att.temp_damage = 0
    assert def.temp_damage = 0
    attack(att, def)
    attack_react(att, def)
    defence(att, def)
    defence_react(att, def)

    # TODO: If health < 0, defeated_ool = 1.
    return (defeated_bool=0)
end

# Attacker damages the defender.
func attack{
        range_check_ptr
    }(
        att : Fighter,
        def : Fighter
    ):
    # TODO More action complexity and dependency.
    # E.g., conditionals, non-linearity, multipliers and modifiers
    # based on other traits.
    assert def.temp_damage = att.strike * att.strength +
        att.shoot * att.shoot

    return ()
end

# Attacker gets damaged by the defender.
func attack_react{
        range_check_ptr
    }(
        att : Fighter,
        def : Fighter
    ):
    assert att.temp_damage = def.iq * def.iq + def.courage * def.psyops
    return ()
end

# Defender reduces the damage sustained.
func defence{
        range_check_ptr
    }(
        att : Fighter,
        def : Fighter
    ):
    # TODO
    alloc_locals
    let damage_reduction = def.duck * def.speed + def.climb * def.stamina
    let (no_clout) = is_nn_le(def.notoriety + def.friends, 10)
    local range_check_ptr = range_check_ptr
    if no_clout == 0:
        # Reduced damage only if has clout.
        assert damage_reduction = damage_reduction + def.friends * def.friends
    end
    assert def.temp_damage = def.temp_damage - damage_reduction
    return ()
end

# Attacker counters the defence, and defender sustains damage.
func defence_react{
        range_check_ptr
    }(
        att : Fighter,
        def : Fighter
    ):
    alloc_locals
    let outwit = att.psyops + att.iq
    let (cant_outwit) = is_nn_le(outwit, 10)
    local range_check_ptr = range_check_ptr
    if cant_outwit == 0:
        # If the attacker outwits, increase damage to defender.
        assert def.temp_damage = def.temp_damage + att.stamina
    end

    # TODO Make sure negatives are handled (damage > health).
    # E.g., if the defender is very strong, being attacked may
    # increase health, which is possibly okay.
    assert def.health = def.health - def.temp_damage
    return ()
end


# Enforces the constraints on the params selected by the user.
func are_params_legal{
        range_check_ptr
    }(
        F : Fighter
    ) -> (
        legal_params_bool : felt
    ):
    # Players can choose any of these after examining the game logic.
    # If they become Drug Lord, these traits will persist for them.
    # Going heavy in one axis makes one vulnerable in another.

    # Here the stats are in categories and quadratic total attempts
    # to prevent lopsided characters. The more you add to one
    # category, the more you use a quota (non-linearly).
    # This hopefullly makes it harder to exploit the better traits,
    # to create more even play.

    let MAX_QUADRATIC_TOTAL = 1000
    # E.g., to really max out a category, you have to sacrifice a lot.
    let physical = F.strength + F.agility
    let protec = F.duck + F.block + F.climb
    let attac = F.strike + F.shoot + F.grapple
    let mind = F.courage + F.iq + F.psyops
    let social = F.notoriety + F.friends
    let drainable = F.stamina + F.health + F.speed
    let sum = physical * physical + protec * protec + attac * attac +
        mind * mind + social * social + drainable * drainable

    let (legal_params_bool : felt) = is_nn_le(sum, MAX_QUADRATIC_TOTAL)

    # TODO: Other checks here.

    return (legal_params_bool)
end

# Return a struct for the given information.
func array_to_struct(
        arr : felt*,
        user_data : UserData
    ) -> (
        fighter : Fighter
    ):
    alloc_locals
    # Initialize the fighter. Health is 10x. e.g., 9 = 90 HP
    local F : Fighter
    assert F.strength = arr[0]
    assert F.agility = arr[1]
    assert F.duck = arr[2]
    assert F.block = arr[3]
    assert F.climb = arr[4]
    assert F.strike = arr[5]
    assert F.shoot = arr[6]
    assert F.grapple = arr[7]
    assert F.courage = arr[8]
    assert F.iq = arr[9]
    assert F.psyops = arr[10]
    assert F.notoriety = arr[11]
    assert F.friends = arr[12]
    assert F.stamina = arr[13]
    assert F.health = arr[14] * 10
    assert F.speed = arr[15]
    assert F.core = user_data

    return (fighter=F)
end