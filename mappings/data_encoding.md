## Data use outilne

Storage on L2 is more expensive than computation, so this an outline of a
storage efficient mechanism to pack-unpack the data for each unique player in the
game so that NFTs confer different game experiences.

The DOPE NFT (`0x87072`) has 12 fields (weapons, clothes, etc.).
Not all fields will be useful for the game in `v1`, but this structure
may be useful as an expansible but storage-efficient starting point.

The flow to use this structure is:

- User selects a single DOPE to use for the game.
- They register it to be associated with their L2 address (one-address one-dope)
- The registry contract records their address with a user_id and dope_data.
- The player calls the game contract for a turn, the contract looks at their pubkey
and calls the registry, fetching the dope_data to give players unique in-game qualities.
- The game contract parses the data and the turn progresses using that information to
affect probabilities (e.g., strong weapon, better chance at xyz.)
- The turn ends.

## Scoring

The game will have a scoring layer on top of the items, giving them a scale of
of 0-10, with 10/10 being the most potent for whatever task. (e.g., speed to run from
mugging, or ability to bribe the cops). These scores are in `mappings/[description_xyz].csv`.

The score should incorporate:

- The nature of the item
- The rarity of the item

The score should does not have to be strictly logical. For example, a Rolls Royce or
electric scooter may not be super fast, but may have a high speed score for allure or
rarity or some other reason.

It may be useful to have the distribution of each of the items to better inform this.
But it is better to just get rough numbers down and then improve laterif need.

### Encoding

- Values in StarkNet are 250-bit (field elements).
- The DOPE NFT has 12 fields
    - The largest field has 64 (2**6 bits) options (namePrefixes). The specific
    item will be stored, but may not be used in `v1` directly.
    - Each field will also have a 1-10 score (2**4 bits) that the
    game can read.
    - Each item is therefore `6 + 4 = 10 bits`.
    - Total storage is `12 * 10 = 120 bits`.
    - This is well within the available 250-bits for a single value.
- The items will be packed from leas significant bit (LSB) to most
significant bit (MSB), in the order they appear in the contract,
with item and score beside each other.
    - `A` is the index of the weapon (`0b000100` = 4 = Handgun).
    - `B` is the strength of the weapon (`0b0101` = 5 = 5/10 strength).
    - `C` is the clothes index, `D` is clothes score. E.g., may not
    be used in `v1`, but stored in case.
    - `^110th` is the final field, nameSuffixes, again, may not be used
    and could be set to zero to start with.

```
E.g., user 354 has data field in UserRegistry:
MSB                                                              LSB
000...000101....1101010110000011011000000101001101011111010101000100
      ^110th                          F   E     D   C     B   A
```

The scores that are most useful for `v1` are marked below:

```
# Zero-based bit index for data locations.
# 0 weapon id.
# 6 weapon strength score (v1).
# 10 clothes.
# 20 vehicle id.
# 26 vehicle speed score (v1).
# 30 waistArmor id.
# 40 footArmor id.
# 46 footArmor speed score (v1).
# 50 handArmor id.
# 60 necklace id.
# 66 necklace bribe score (v1).
# 70 ring id.
# 76 ring bribe score (v1).
# 80 suffix id.
# 90 drug id (v1).
# 100 namePrefixes.
# 110 nameSuffixes.
# 120-249 (vacant).
```
To decode the element score, the game engine knows to look
at a certain index in the data (e.g., weapon strength is at the 6th
bit index).

1. Create 4-bit long binary mask at 2**index (000000001111000000)
    - `2**index + 2**(index+1) + 2**(index+2) + 2**(index+3)`
2. Bitwise AND the mask and the data
    - 000...010101000100 Data.
    - 000000001111000000 Weapon mask.
    - 000000000101000000 Data AND mask.
3. Shift right (divide by 2**index)
    - 000000000001000000 Order = 2**index
    - 000000000000000101 (Data AND mask) // order
4. Use as value for some calculation.
    - Attack likelihood modifier

## Loading scores into the system

If Merkle tree is being constructed, these data can be computed
using the `mappings/xyz.csv` scores for each DOPE NFT and upon
claiming, the `UserRegistry` will save the value claimed.

For example:

- Scrape the mainnet at some blockheight for token ID - L1_pubkey mapping
- Use for each item, retrieve the strings for each parameter
(e.g., `Baseball Bat`, `Gold Chain`)
- Consult the `mappings/xyz.csv` files to pull the item strength score
- Then either:
    - (better) Build the binary encoding off chain.
    - Build the tree with fields and have the L2 contract build the mapping.
- Then an L2 user will come to L2 contract with a signed message from their
L1 public key declaring ownership of a DOPE NFT.
- The contract checks the Eth1 signature and saves the Merkle leaf data
(binary encoded NFT item data) in the UserRegistry.
- The game contract may then consult the registry every turn, unpacking the
items at the start of each turn.

## Other considerations

What other fields might be useful to encode?

- DOPE NFT ID?
- ...

## Contract source data

The entire list is:
```
string[] private weapons = [
    "Pocket Knife",
    "Chain",
    "Knife",
    "Crowbar",
    "Handgun",
    "AK47",
    "Shovel",
    "Baseball Bat",
    "Tire Iron",
    "Police Baton",
    "Pepper Spray",
    "Razor Blade",
    "Chain",
    "Taser",
    "Brass Knuckles",
    "Shotgun",
    "Glock",
    "Uzi"
];

string[] private clothes = [
    "White T Shirt",
    "Black T Shirt",
    "White Hoodie",
    "Black Hoodie",
    "Bulletproof Vest",
    "3 Piece Suit",
    "Checkered Shirt",
    "Bikini",
    "Golden Shirt",
    "Leather Vest",
    "Blood Stained Shirt",
    "Police Uniform",
    "Combat Jacket",
    "Basketball Jersey",
    "Track Suit",
    "Trenchcoat",
    "White Tank Top",
    "Black Tank Top",
    "Shirtless",
    "Naked"
];

string[] private vehicle = [
    "Dodge",
    "Porsche",
    "Tricycle",
    "Scooter",
    "ATV",
    "Push Bike",
    "Electric Scooter",
    "Golf Cart",
    "Chopper",
    "Rollerblades",
    "Lowrider",
    "Camper",
    "Rolls Royce",
    "BMW M3",
    "Bike",
    "C63 AMG",
    "G Wagon"
];

string[] private waistArmor = [
    "Gucci Belt",
    "Versace Belt",
    "Studded Belt",
    "Taser Holster",
    "Concealed Holster",
    "Diamond Belt",
    "D Ring Belt",
    "Suspenders",
    "Military Belt",
    "Metal Belt",
    "Pistol Holster",
    "SMG Holster",
    "Knife Holster",
    "Laces",
    "Sash",
    "Fanny Pack"
];

string[] private footArmor = [
    "Black Air Force 1s",
    "White Forces",
    "Air Jordan 1 Chicagos",
    "Gucci Tennis 84",
    "Air Max 95",
    "Timberlands",
    "Reebok Classics",
    "Flip Flops",
    "Nike Cortez",
    "Dress Shoes",
    "Converse All Stars",
    "White Slippers",
    "Gucci Slides",
    "Alligator Dress Shoes",
    "Socks",
    "Open Toe Sandals",
    "Barefoot"
];

string[] private handArmor = [
    "Rubber Gloves",
    "Baseball Gloves",
    "Boxing Gloves",
    "MMA Wraps",
    "Winter Gloves",
    "Nitrile Gloves",
    "Studded Leather Gloves",
    "Combat Gloves",
    "Leather Gloves",
    "White Gloves",
    "Black Gloves",
    "Kevlar Gloves",
    "Surgical Gloves",
    "Fingerless Gloves"
];

string[] private necklaces = ["Bronze Chain", "Silver Chain", "Gold Chain"];

string[] private rings = [
    "Gold Ring",
    "Silver Ring",
    "Diamond Ring",
    "Platinum Ring",
    "Titanium Ring",
    "Pinky Ring",
    "Thumb Ring"
];

string[] private suffixes = [
    "from the Bayou",
    "from Atlanta",
    "from Compton",
    "from Oakland",
    "from SOMA",
    "from Hong Kong",
    "from London",
    "from Chicago",
    "from Brooklyn",
    "from Detroit",
    "from Mob Town",
    "from Murdertown",
    "from Sin City",
    "from Big Smoke",
    "from the Backwoods",
    "from the Big Easy",
    "from Queens",
    "from BedStuy",
    "from Buffalo"
];

string[] private drugs = [
    "Weed",
    "Cocaine",
    "Ludes",
    "Acid",
    "Speed",
    "Heroin",
    "Oxycontin",
    "Zoloft",
    "Fentanyl",
    "Krokodil",
    "Coke",
    "Crack",
    "PCP",
    "LSD",
    "Shrooms",
    "Soma",
    "Xanax",
    "Molly",
    "Adderall"
];

string[] private namePrefixes = [
    "OG",
    "King of the Street",
    "Cop Killer",
    "Blasta",
    "Lil",
    "Big",
    "Tiny",
    "Playboi",
    "Snitch boi",
    "Kingpin",
    "Father of the Game",
    "Son of the Game",
    "Loose Trigger Finger",
    "Slum Prince",
    "Corpse",
    "Mother of the Game",
    "Daughter of the Game",
    "Slum Princess",
    "Da",
    "Notorious",
    "The Boss of Bosses",
    "The Dog Killer",
    "The Killer of Dog Killer",
    "Slum God",
    "Candyman",
    "Candywoman",
    "The Butcher",
    "Yung Capone",
    "Yung Chapo",
    "Yung Blanco",
    "The Fixer",
    "Jail Bird",
    "Corner Cockatoo",
    "Powder Prince",
    "Hippie",
    "John E. Dell",
    "The Burning Man",
    "The Burning Woman",
    "Kid of the Game",
    "Street Queen",
    "The Killer of Dog Killers Killer",
    "Slum General",
    "Mafia Prince",
    "Crooked Cop",
    "Street Mayor",
    "Undercover Cop",
    "Oregano Farmer",
    "Bloody",
    "High on the Supply",
    "The Orphan",
    "The Orphan Maker",
    "Ex Boxer",
    "Ex Cop",
    "Ex School Teacher",
    "Ex Priest",
    "Ex Engineer",
    "Street Robinhood",
    "Hell Bound",
    "SoundCloud Rapper",
    "Gang Leader",
    "The CEO",
    "The Freelance Pharmacist",
    "Soccer Mom",
    "Soccer Dad"
];

string[] private nameSuffixes = [
    "Feared",
    "Baron",
    "Vicious",
    "Killer",
    "Fugitive",
    "Triggerman",
    "Conman",
    "Outlaw",
    "Assassin",
    "Shooter",
    "Hitman",
    "Bloodstained",
    "Punishment",
    "Sin",
    "Smuggled",
    "LastResort",
    "Contraband",
    "Illicit"
];
```
