%lang starknet
%builtins range_check

from starkware.cairo.common.math import assert_nn_le, unsigned_div_rem

##### Intro #####
#
# StarkNet is very good at verifying computation cheaply.
# Storage is still fundamentally tied to L1 data costs.
# The fighter contract has no storage - it attempts to create complex
# interrelated dynamics requiring many computations to make the game
# interesting. The contract accepts two fighters and emits events
# during a multi-round battle. The winner is decided and is passed
# back to the main contract.
#
#################


# Traits that are defined by token ownership.
struct UserData:
    member weapon_strength : felt  # low to high, [0, 10]. 0=None.
    member vehicle_speed : felt  # low to high, [0, 10]. 0=None.
    member foot_speed : felt  # low to high, [0, 10]. 0=None.
    member necklace_bribe : felt  # low to high, [0, 10]. 0=None.
    member ring_bribe : felt  # low to high, [0, 10]. 0=None.
    member special_drug : felt  # NFT drug item [0, 10]. 0=None.
end

# Slider-style traits that a user selects.
# Defined by the position in the Stats array (member_a = index_0).
struct Fighter:
    member strength
    member agility
    member duck
    member block
    member climb
    member strike
    member shoot
    member grapple
    member courage
    member IQ
    member psyops
    member notoriety
    member friends
    member stamina
    member health
    member speed
    member core : UserData
    member score
    member defeated
end
# TODO ^^ add more and refine. Target is maybe 30.

# Accepts two fighters (the user and the drug lord) and determines
# winner through combat using innate UserData and selected Stats.
@external
func fight_1v1{
        range_check_ptr
    }(
        user_data : UserData,
        lord_user_data : UserData,
        len_user_combat_stats : felt,
        user_combat_stats : felt*,
        len_drug_lord_stats : felt,
        drug_lord_combat_stats : felt*)
    ) -> (
        user_wins_bool : felt
    ):
    # Make user stats readable.
    let (local user : Fighter) = array_to_struct(user_combat_stats,
        user_data)
    # If the user selected illegal parameters, they lose
    let (legal_params_bool) = are_params_legal(user)
    if legal_params_bool = 0:
        return (user_wins_bool=0)
    end

    # Make lord stats readable.
    let (local lord : Fighter) = array_to_struct(drug_lord_combat_stats,
        lord_user_data)

    # Start fight
    let (user_wins_bool : felt) = fight(user=user, lord=lord, round=10)

    return (user_wins_bool=user_wins_bool)
end

# Entry function for the fight
func fight{}(
        user : Fighter,
        lord : Fighter,
        round : felt
    ) -> (
        defeated_bool : felt
    ):
    # If anyone is defeated before the last round, return.
    if defeat_bool = 1:
        return (defeated_bool)

    if round = 0:
        return (defeated_bool)
    end

    let (local defeated_bool) = fight(user=user, lord=lord,
        round=round-1)

    # One round is two parts: First attack then be attacked.

    # E.g., attack, block attack, defend, block defend
    let (defeated_bool) = attack(att=user, def=lord)

    # If anyone is defeated, return.
    if user.defeated + lord.defeated != 0:
        return (defeated_bool=1)

    let (defeated_bool) = attack(att=lord, def=user)

    # If anyone is defeated, return.
    if user.defeated + lord.defeated != 0:
        return (defeated_bool=1)

    return (defeated_bool=0)
end

# Executes a four-part sequence for specified attacker/defender.
func attack(
        att : Fighter
        def : Fighter
    ) -> (
        defeated_bool : felt
    ):

    attack_react(att, def)
    # TODO
    defence(att, def)
    # TODO
    defence_react(att, def)
    # TODO
    return (defeated_bool)
end




# Enforces the constraints on the params selected by the user.
func are_params_legal(
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
    let mind = F.courage + F.IQ + F.psyops
    let social = F.notoriety + F.friends
    let drainable = F.stamina + F.health + F.speed
    let sum = physical * physical + protec * protec + attac * attac
        + mind * mind + social * social + drainable * drainable

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
    local F : fighter
    assert F.strength = arr[0]
    assert F.agility = arr[1]
    assert F.duck = arr[2]
    assert F.block = arr[3]
    assert F.climb = arr[4]
    assert F.strike = arr[5]
    assert F.shoot = arr[6]
    assert F.grapple = arr[7]
    assert F.courage = arr[8]
    assert F.IQ = arr[9]
    assert F.psyops = arr[10]
    assert F.notoriety = arr[11]
    assert F.friends = arr[12]
    assert F.stamina = arr[13]
    assert F.health = arr[14]
    assert F.speed = arr[15]
    assert F.data = user_data

    return (fighter=F)
end