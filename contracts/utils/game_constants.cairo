############ Game constants ############
# Default basis point probabilities applied per turn. 10000=100%.
# Impact factor scales value. post = (pre * F)// 100). 30 = 30% increase.
# Impact factor is either added or subtracted from 100.
# Probabilities are not currently optimised (e.g. all set to 50%).

const DEALER_DASH_BP = 1000  # E.g., 10% chance dealer runs.
const WRANGLE_DASHED_DEALER_BP = 5000  # E.g., 30% you catch them.
const MUGGING_BP = 5000  # E.g., 15% chance of mugging.
const MUGGING_IMPACT = 30  # Impact is 30% money loss = (100-30)/100.
const RUN_FROM_MUGGING_BP = 5000
const GANG_WAR_BP = 5000
const GANG_WAR_IMPACT = 30  # Impact is 30% money loss = (100-30)/100.
const DEFEND_GANG_WAR_BP = 5000
const COP_RAID_BP = 5000
const COP_RAID_IMPACT = 20  # Impact is 20% item & 20% money loss.
const BRIBE_COPS_BP = 5000
const FIND_ITEM_BP = 5000
const FIND_ITEM_IMPACT = 50  # Impact is 50% item gain = (100+50)/100.
const LOCAL_SHIPMENT_BP = 5000
const LOCAL_SHIPMENT_IMPACT = 20  # Regional impact is 20% item gain.
const WAREHOUSE_SEIZURE_BP = 5000
const WAREHOUSE_SEIZURE_IMPACT = 20  # Regional impact 20% item loss.

# Probabilities are for minimum-stat wearable (score=1).
# For a max-stat wearable (score=10), the probability is scaled down.
# E.g., an event_BP of 3000 (30% chance) and an event fraction of
# 20 will become (30*20/100) = 6% chance for that event for that player.
const MIN_EVENT_FRACTION = 20  # 20% the stated XYZ_BP probability.

# Number of turns by other players that must occur before next turn.
const MIN_TURN_LOCKOUT = 3

# Drug lord percentage (2 = 2%).
const DRUG_LORD_PERCENTAGE = 2

# Number of stats that a player specifies for combat.
const NUM_COMBAT_STATS = 30

# Number of locations (defined by DOPE NFT).
const LOCATIONS = 19

# Number of districts per location.
const DISTRICTS = 4

# Amount of money a user starts with.
const STARTING_MONEY = 20000