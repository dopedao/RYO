%lang starknet

# A struct that holds the unpacked DOPE NFT data for the user.
struct UserData:
    member weapon_strength : felt  # low to high, [0, 10]. 0=None.
    member vehicle_speed : felt  # low to high, [0, 10]. 0=None.
    member foot_speed : felt  # low to high, [0, 10]. 0=None.
    member necklace_bribe : felt  # low to high, [0, 10]. 0=None.
    member ring_bribe : felt  # low to high, [0, 10]. 0=None.
    member special_drug : felt  # NFT drug item [0, 10]. 0=None.
end



# WIP Used by module 05_Combat.
# Slider-style traits that a user selects.
# Defined by the position in the Stats array (member_a = index_0).
struct Fighter:
    member strength : felt
    member agility : felt
    member duck : felt
    member block : felt
    member climb : felt
    member strike : felt
    member shoot : felt
    member grapple : felt
    member courage : felt
    member iq : felt
    member psyops : felt
    member notoriety : felt
    member friends : felt
    member stamina : felt
    member health : felt
    member speed : felt
    member core : UserData
    member score : felt
    member defeated : felt
    member temp_damage : felt
end