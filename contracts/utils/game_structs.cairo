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

############ Turn Logs ############
# Used in Module 01.
# Turns are actioned through an @external function that modifies state.
# The events that occur in a turn are packed and stored for later query.
# The first few members are the turn inputs.
# TODO: Compact these e.g., bools all in one felt. Struct of structs etc.
struct TurnLog:
    member user_id : felt
    member location_id : felt
    member buy_or_sell : felt
    member item_id : felt
    member amount_to_give : felt
    member market_pre_trade_item : felt
    member market_post_trade_pre_event_item : felt
    member market_post_trade_post_event_item : felt
    member market_pre_trade_money : felt
    member market_post_trade_pre_event_money : felt
    member market_post_trade_post_event_money : felt
    member user_pre_trade_item : felt
    member user_post_trade_pre_event_item : felt
    member user_post_trade_post_event_item : felt
    member user_pre_trade_money : felt
    member user_post_trade_pre_event_money : felt
    member user_post_trade_post_event_money : felt
    member trade_occurs_bool : felt
    member money_reduction_factor : felt
    member item_reduction_factor : felt
    member regional_item_reduction_factor : felt
    member dealer_dash_bool : felt
    member wrangle_dashed_dealer_bool : felt
    member mugging_bool : felt
    member run_from_mugging_bool : felt
    member gang_war_bool : felt
    member defend_gang_war_bool : felt
    member cop_raid_bool : felt
    member bribe_cops_bool : felt
    member find_item_bool : felt
    member local_shipment_bool : felt
    member warehouse_seizure_bool : felt
end