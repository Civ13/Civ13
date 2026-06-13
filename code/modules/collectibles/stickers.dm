#define STICKER_COMMON    1
#define STICKER_UNCOMMON  2
#define STICKER_RARE      3
#define STICKER_LEGENDARY 4

#define STICKER_AGE_STONE      "Stone Age"
#define STICKER_AGE_CLASSICAL  "Classical Age"
#define STICKER_AGE_MEDIEVAL   "Medieval Age"
#define STICKER_AGE_IMPERIAL   "Imperial Age"
#define STICKER_AGE_INDUSTRIAL "Industrial Age"
#define STICKER_AGE_WW1        "WW1"
#define STICKER_AGE_WW2        "WW2"
#define STICKER_AGE_COLDWAR    "Cold War"
#define STICKER_AGE_MODERN     "Modern Age"

#define STICKER_CAT_WONDERS  "Wonders"
#define STICKER_CAT_NATURAL  "Natural Wonders"
#define STICKER_CAT_TECH     "Technology"
#define STICKER_CAT_WEAPONS  "Weapons"
#define STICKER_CAT_ANIMALS  "Animals"
#define STICKER_CAT_CROPS    "Crops"
#define STICKER_CAT_MINERALS "Minerals"

/datum/sticker
	var/id
	var/index = 0
	var/name = "sticker"
	var/desc = "A collectible sticker."
	var/rarity = STICKER_COMMON
	var/category = STICKER_CAT_TECH
	var/age = STICKER_AGE_STONE
	var/icon = 'icons/obj/collectibles.dmi'
	var/icon_state = "collectible_card"

/datum/sticker/proc/rarity_name()
	switch(src.rarity)
		if(STICKER_COMMON)    return "Common"
		if(STICKER_UNCOMMON)  return "Uncommon"
		if(STICKER_RARE)      return "Rare"
		if(STICKER_LEGENDARY) return "Legendary"
	return "Unknown"

/datum/sticker/proc/rarity_color()
	switch(src.rarity)
		if(STICKER_COMMON)    return "#583d07"
		if(STICKER_UNCOMMON)  return "#CE8946"
		if(STICKER_RARE)      return "#C0C0C0"
		if(STICKER_LEGENDARY) return "#D4AF37"
	return "#ffffff"

// ======================= COMMON =======================

/datum/sticker/spear
	id = "spear"
	index = 1
	name = "Spear"
	desc = "A sharpened stick tipped with stone - humanity's first ranged weapon."
	rarity = STICKER_COMMON
	category = STICKER_CAT_WEAPONS
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_1"

/datum/sticker/flint_hatchet
	id = "flint_hatchet"
	index = 2
	name = "Flint Hatchet"
	desc = "Knapped flint lashed to a wooden handle. Sharp enough to fell a tree."
	rarity = STICKER_COMMON
	category = STICKER_CAT_WEAPONS
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_1"

/datum/sticker/club
	id = "club"
	index = 3
	name = "Wooden Club"
	desc = "The simplest weapon. Pointed end goes in the other guy."
	rarity = STICKER_COMMON
	category = STICKER_CAT_WEAPONS
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_1"

/datum/sticker/sling
	id = "sling"
	index = 4
	name = "Sling"
	desc = "A leather strip that turns a pebble into a deadly projectile."
	rarity = STICKER_COMMON
	category = STICKER_CAT_WEAPONS
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_1"

/datum/sticker/bow
	id = "bow"
	index = 5
	name = "Short Bow"
	desc = "Bent wood and sinew - the engine of conquest for a thousand years."
	rarity = STICKER_COMMON
	category = STICKER_CAT_WEAPONS
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_1"

/datum/sticker/pottery
	id = "pottery"
	index = 6
	name = "Clay Pot"
	desc = "Fired clay shaped by hand - the first durable container."
	rarity = STICKER_COMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_3"

/datum/sticker/plough
	id = "plough"
	index = 7
	name = "Wooden Plough"
	desc = "Turned the earth so civilizations could settle and feed themselves."
	rarity = STICKER_COMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_3"

/datum/sticker/drying_rack
	id = "drying_rack"
	index = 8
	name = "Drying Rack"
	desc = "Meat and fish hung to dry - the oldest form of food preservation."
	rarity = STICKER_COMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_3"

/datum/sticker/loom
	id = "loom"
	index = 9
	name = "Loom"
	desc = "Threads pulled tight into cloth - weaving warmth from fibre."
	rarity = STICKER_COMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_3"

/datum/sticker/fire
	id = "fire"
	index = 10
	name = "Fire"
	desc = "The first great discovery - warmth, cooked food, and fear in the eyes of beasts."
	rarity = STICKER_COMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_3"

/datum/sticker/basket
	id = "basket"
	index = 11
	name = "Basket"
	desc = "Woven reeds and grasses - the first portable container."
	rarity = STICKER_COMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_3"

/datum/sticker/fishing_net
	id = "fishing_net"
	index = 12
	name = "Fishing Net"
	desc = "Cord knotted into mesh, feeding entire villages from the river."
	rarity = STICKER_COMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_3"

/datum/sticker/rope
	id = "rope"
	index = 13
	name = "Rope"
	desc = "Twisted fibre, the invisible thread holding civilization together."
	rarity = STICKER_COMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_3"

/datum/sticker/hammer
	id = "hammer"
	index = 14
	name = "Hammer"
	desc = "Stone or bronze, the universal builder's tool."
	rarity = STICKER_COMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_3"

/datum/sticker/axe
	id = "axe"
	index = 15
	name = "Axe"
	desc = "Felling trees and shaping timber - the woodsman's best friend."
	rarity = STICKER_COMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_3"

/datum/sticker/mortar_pestle
	id = "mortar_pestle"
	index = 16
	name = "Mortar and Pestle"
	desc = "Grinding grain, herbs, and pigments into fine powder."
	rarity = STICKER_COMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_3"

/datum/sticker/papyrus
	id = "papyrus"
	index = 17
	name = "Papyrus"
	desc = "The birth of writing and record-keeping - thoughts made permanent."
	rarity = STICKER_COMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_3"

/datum/sticker/torch
	id = "torch"
	index = 18
	name = "Torch"
	desc = "Light against the dark, carried into caves and new lands."
	rarity = STICKER_COMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_3"

/datum/sticker/leather_hide
	id = "leather_hide"
	index = 19
	name = "Leather Hide"
	desc = "Tanned animal skin, the first clothing and shelter material."
	rarity = STICKER_COMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_3"

/datum/sticker/irrigation
	id = "irrigation"
	index = 20
	name = "Irrigation"
	desc = "Channels and ditches bringing water to the fields - the surplus that built cities."
	rarity = STICKER_COMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_3"

/datum/sticker/sails
	id = "sails"
	index = 21
	name = "Sails"
	desc = "Canvas catching the wind - humanity's first engine."
	rarity = STICKER_COMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_3"

/datum/sticker/cement
	id = "cement"
	index = 22
	name = "Cement"
	desc = "Powder that turns to stone - binding the ancient world together."
	rarity = STICKER_COMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_3"

/datum/sticker/fermentation
	id = "fermentation"
	index = 23
	name = "Fermentation"
	desc = "Yeast and time turning grain into beer, grapes into wine - the first chemistry."
	rarity = STICKER_COMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_3"

/datum/sticker/chicken
	id = "chicken"
	index = 24
	name = "Chicken"
	desc = "The most widespread domesticated bird - eggs, meat, and feathers."
	rarity = STICKER_COMMON
	category = STICKER_CAT_ANIMALS
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_2"

/datum/sticker/cow
	id = "cow"
	index = 25
	name = "Cow"
	desc = "Milk, meat, leather, and labour - the backbone of agriculture."
	rarity = STICKER_COMMON
	category = STICKER_CAT_ANIMALS
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_2"

/datum/sticker/deer
	id = "deer"
	index = 26
	name = "Deer"
	desc = "Swift and wary, hunted since the earliest days for meat and antler."
	rarity = STICKER_COMMON
	category = STICKER_CAT_ANIMALS
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_2"

/datum/sticker/sheep
	id = "sheep"
	index = 27
	name = "Sheep"
	desc = "Wool, milk, and mutton - the flock that clothed nations."
	rarity = STICKER_COMMON
	category = STICKER_CAT_ANIMALS
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_2"

/datum/sticker/bear
	id = "bear"
	index = 28
	name = "Bear"
	desc = "Apex predator of the northern forests - feared and revered."
	rarity = STICKER_COMMON
	category = STICKER_CAT_ANIMALS
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_2"

/datum/sticker/horse
	id = "horse"
	index = 29
	name = "Horse"
	desc = "The animal that shrank the world - cavalry, trade, and transport."
	rarity = STICKER_COMMON
	category = STICKER_CAT_ANIMALS
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_2"

/datum/sticker/dog
	id = "dog"
	index = 30
	name = "Dog"
	desc = "Man's best friend - the first animal to walk beside us."
	rarity = STICKER_COMMON
	category = STICKER_CAT_ANIMALS
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_2"

/datum/sticker/wheel
	id = "wheel"
	index = 31
	name = "Wheel"
	desc = "Round and simple, yet it revolutionized every civilization that turned it."
	rarity = STICKER_COMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_3"

/datum/sticker/pickaxe
	id = "pickaxe"
	index = 32
	name = "Pickaxe"
	desc = "A pointed tool for breaking rock - the miner's constant companion."
	rarity = STICKER_COMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_3"

// ======================= UNCOMMON =======================

/datum/sticker/sword
	id = "sword"
	index = 33
	name = "Iron Sword"
	desc = "A well-forged iron blade that has seen many battles."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_WEAPONS
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_1"

/datum/sticker/compass
	id = "compass"
	index = 34
	name = "Navigation Compass"
	desc = "Guided explorers across uncharted oceans to new worlds."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_MEDIEVAL
	icon_state = "collectible_card_3"

/datum/sticker/cannon
	id = "cannon"
	index = 35
	name = "Iron Cannon"
	desc = "Black-powder firepower that shattered the age of castles."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_WEAPONS
	age = STICKER_AGE_MEDIEVAL
	icon_state = "collectible_card_1"

/datum/sticker/arquebus
	id = "arquebus"
	index = 36
	name = "Arquebus"
	desc = "The first handheld gunpowder weapon - slow to load, terrifying to face."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_WEAPONS
	age = STICKER_AGE_IMPERIAL
	icon_state = "collectible_card_1"

/datum/sticker/musket
	id = "musket"
	index = 37
	name = "Musket"
	desc = "Smoothbore, muzzle-loaded, devastating in a volley. The empire builder."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_WEAPONS
	age = STICKER_AGE_IMPERIAL
	icon_state = "collectible_card_1"

/datum/sticker/forge
	id = "forge"
	index = 38
	name = "Forge"
	desc = "The beating heart of metalworking - where ore becomes iron."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_MEDIEVAL
	icon_state = "collectible_card_3"

/datum/sticker/bloomery
	id = "bloomery"
	index = 39
	name = "Bloomery"
	desc = "A furnace that separates iron from stone, producing a spongy bloom to be hammered."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_MEDIEVAL
	icon_state = "collectible_card_3"

/datum/sticker/furnace
	id = "furnace"
	index = 40
	name = "Blast Furnace"
	desc = "Superheated air melts ore into molten metal, feeding the machines of war."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_IMPERIAL
	icon_state = "collectible_card_3"

/datum/sticker/steam_engine
	id = "steam_engine"
	index = 41
	name = "Steam Engine"
	desc = "The pounding heart of the Industrial Revolution."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_INDUSTRIAL
	icon_state = "collectible_card_3"

/datum/sticker/petrol_engine
	id = "petrol_engine"
	index = 42
	name = "Petrol Engine"
	desc = "Internal combustion - compact, portable power that shrank the world."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_INDUSTRIAL
	icon_state = "collectible_card_3"

/datum/sticker/electricity
	id = "electricity"
	index = 43
	name = "Electricity"
	desc = "Harnessed lightning - powered the second industrial revolution."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_INDUSTRIAL
	icon_state = "collectible_card_3"

/datum/sticker/flight
	id = "flight"
	index = 44
	name = "Flight"
	desc = "Humanity took to the skies and never looked back."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_INDUSTRIAL
	icon_state = "collectible_card_3"

/datum/sticker/cars
	id = "cars"
	index = 45
	name = "Cars"
	desc = "Personal transport on four wheels - the open road calling."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_INDUSTRIAL
	icon_state = "collectible_card_3"

/datum/sticker/computers
	id = "computers"
	index = 46
	name = "Computers"
	desc = "Logic machines that think faster than any human - the digital revolution."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_COLDWAR
	icon_state = "collectible_card_3"

/datum/sticker/printing_press
	id = "printing_press"
	index = 47
	name = "Printing Press"
	desc = "Movable type and ink - knowledge escaped the monasteries and reached the masses."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_TECH
	age = STICKER_AGE_IMPERIAL
	icon_state = "collectible_card_3"

// ======================= RARE =======================

/datum/sticker/hanging_gardens
	id = "hanging_gardens"
	index = 48
	name = "Hanging Gardens of Babylon"
	desc = "Terraced greenery cascading down the walls of a desert city - a wonder built by love."
	rarity = STICKER_RARE
	category = STICKER_CAT_WONDERS
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_5"

/datum/sticker/statue_zeus
	id = "statue_zeus"
	index = 49
	name = "Statue of Zeus"
	desc = "A towering chryselephantine figure seated upon his throne at Olympia."
	rarity = STICKER_RARE
	category = STICKER_CAT_WONDERS
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_5"

/datum/sticker/temple_artemis
	id = "temple_artemis"
	index = 50
	name = "Temple of Artemis"
	desc = "A marble temple of 127 columns, burned down by a madman seeking fame."
	rarity = STICKER_RARE
	category = STICKER_CAT_WONDERS
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_5"

/datum/sticker/mausoleum
	id = "mausoleum"
	index = 51
	name = "Mausoleum at Halicarnassus"
	desc = "The tomb of King Mausolus - so grand it gave us the word 'mausoleum'."
	rarity = STICKER_RARE
	category = STICKER_CAT_WONDERS
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_5"

/datum/sticker/colossus_rhodes
	id = "colossus_rhodes"
	index = 52
	name = "Colossus of Rhodes"
	desc = "A bronze giant straddling the harbour entrance, lost to earthquake after 56 years."
	rarity = STICKER_RARE
	category = STICKER_CAT_WONDERS
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_5"

/datum/sticker/lighthouse
	id = "lighthouse"
	index = 53
	name = "Lighthouse of Alexandria"
	desc = "Fire and mirror guided sailors home from 100 miles at sea."
	rarity = STICKER_RARE
	category = STICKER_CAT_WONDERS
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_5"

/datum/sticker/bolt_action_rifle
	id = "bolt_action_rifle"
	index = 54
	name = "Bolt Action Rifle"
	desc = "Bolt cycled, round chambered - the rifle that defined the Great War."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_WEAPONS
	age = STICKER_AGE_WW1
	icon_state = "collectible_card_1"

/datum/sticker/machine_gun
	id = "machine_gun"
	index = 55
	name = "Machine Gun"
	desc = "Belt-fed, water-cooled death. The weapon that turned charges into slaughter."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_WEAPONS
	age = STICKER_AGE_WW1
	icon_state = "collectible_card_1"

/datum/sticker/submachine_gun
	id = "submachine_gun"
	index = 56
	name = "Submachine Gun"
	desc = "A pistol cartridge on full auto - close-quarters devastation."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_WEAPONS
	age = STICKER_AGE_WW1
	icon_state = "collectible_card_1"

/datum/sticker/assault_rifle
	id = "assault_rifle"
	index = 57
	name = "Assault Rifle"
	desc = "The universal infantry weapon - controllable automatic fire in an intermediate cartridge."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_WEAPONS
	age = STICKER_AGE_WW2
	icon_state = "collectible_card_1"

/datum/sticker/crossbow
	id = "crossbow"
	index = 58
	name = "Crossbow"
	desc = "A bolt loosed with mechanical force - piercing armour at range with minimal skill."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_WEAPONS
	age = STICKER_AGE_MEDIEVAL
	icon_state = "collectible_card_1"

/datum/sticker/alligator
	id = "alligator"
	index = 59
	name = "Alligator"
	desc = "Armoured ambush predator lurking in the waterways since the age of dinosaurs."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_ANIMALS
	age = STICKER_AGE_MODERN
	icon_state = "collectible_card_2"

/datum/sticker/sabertooth
	id = "sabertooth"
	index = 60
	name = "Sabertooth Tiger"
	desc = "Saber-long canines built for the kill - extinct but never forgotten."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_ANIMALS
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_2"

/datum/sticker/piranha
	id = "piranha"
	index = 61
	name = "Piranha"
	desc = "Small freshwater fish with razor teeth and a fearsome reputation."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_ANIMALS
	age = STICKER_AGE_MODERN
	icon_state = "collectible_card_2"

/datum/sticker/mount_fuji
	id = "mount_fuji"
	index = 62
	name = "Mount Fuji"
	desc = "A perfect volcanic cone draped in snow - sacred to the gods, painted by a thousand artists."
	rarity = STICKER_RARE
	category = STICKER_CAT_NATURAL
	age = STICKER_AGE_MODERN
	icon_state = "collectible_card_2"

/datum/sticker/great_barrier_reef
	id = "great_barrier_reef"
	index = 63
	name = "Great Barrier Reef"
	desc = "The largest living structure on Earth, visible from space."
	rarity = STICKER_RARE
	category = STICKER_CAT_NATURAL
	age = STICKER_AGE_MODERN
	icon_state = "collectible_card_2"

/datum/sticker/grand_canyon
	id = "grand_canyon"
	index = 64
	name = "Grand Canyon"
	desc = "A mile-deep gash in the earth carved by two billion years of patient water."
	rarity = STICKER_RARE
	category = STICKER_CAT_NATURAL
	age = STICKER_AGE_MODERN
	icon_state = "collectible_card_2"

/datum/sticker/everest
	id = "everest"
	index = 65
	name = "Mount Everest"
	desc = "The roof of the world - the highest point any human can stand."
	rarity = STICKER_RARE
	category = STICKER_CAT_NATURAL
	age = STICKER_AGE_MODERN
	icon_state = "collectible_card_2"

/datum/sticker/victoria_falls
	id = "victoria_falls"
	index = 66
	name = "Victoria Falls"
	desc = "The smoke that thunders - a curtain of water a mile wide plunging into the abyss."
	rarity = STICKER_RARE
	category = STICKER_CAT_NATURAL
	age = STICKER_AGE_MODERN
	icon_state = "collectible_card_2"

/datum/sticker/sahara
	id = "sahara"
	index = 67
	name = "Sahara Desert"
	desc = "The largest hot desert on Earth - an ocean of sand stretching across a continent."
	rarity = STICKER_RARE
	category = STICKER_CAT_NATURAL
	age = STICKER_AGE_MODERN
	icon_state = "collectible_card_2"

/datum/sticker/amazon
	id = "amazon"
	index = 68
	name = "Amazon Rainforest"
	desc = "The lungs of the planet - home to 10% of all species on Earth."
	rarity = STICKER_RARE
	category = STICKER_CAT_NATURAL
	age = STICKER_AGE_MODERN
	icon_state = "collectible_card_2"

/datum/sticker/internet
	id = "internet"
	index = 69
	name = "Internet"
	desc = "A web connecting every mind on Earth - the largest library ever built."
	rarity = STICKER_RARE
	category = STICKER_CAT_TECH
	age = STICKER_AGE_MODERN
	icon_state = "collectible_card_3"

/datum/sticker/nuclear_energy
	id = "nuclear_energy"
	index = 70
	name = "Nuclear Energy"
	desc = "Split the atom and unlocked power measured in kilotons."
	rarity = STICKER_RARE
	category = STICKER_CAT_TECH
	age = STICKER_AGE_COLDWAR
	icon_state = "collectible_card_3"

// ======================= LEGENDARY =======================

/datum/sticker/great_wall
	id = "great_wall"
	index = 71
	name = "Great Wall of China"
	desc = "Thousands of miles of stone winding over mountains - the longest structure ever built by human hands."
	rarity = STICKER_LEGENDARY
	category = STICKER_CAT_WONDERS
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_5"

/datum/sticker/petra
	id = "petra"
	index = 72
	name = "Petra"
	desc = "A rose-red city half as old as time, carved into the living rock of a desert canyon."
	rarity = STICKER_LEGENDARY
	category = STICKER_CAT_WONDERS
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_5"

/datum/sticker/christ_redeemer
	id = "christ_redeemer"
	index = 73
	name = "Christ the Redeemer"
	desc = "Arms outstretched atop Corcovado, watching over Rio de Janeiro."
	rarity = STICKER_LEGENDARY
	category = STICKER_CAT_WONDERS
	age = STICKER_AGE_MODERN
	icon_state = "collectible_card_5"

/datum/sticker/machu_picchu
	id = "machu_picchu"
	index = 74
	name = "Machu Picchu"
	desc = "An Incan citadel in the clouds, hidden from the world for centuries."
	rarity = STICKER_LEGENDARY
	category = STICKER_CAT_WONDERS
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_5"

/datum/sticker/chichen_itza
	id = "chichen_itza"
	index = 75
	name = "Chichen Itza"
	desc = "A pyramid where serpents of light descend the staircase at equinox."
	rarity = STICKER_LEGENDARY
	category = STICKER_CAT_WONDERS
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_5"

/datum/sticker/taj_mahal
	id = "taj_mahal"
	index = 76
	name = "Taj Mahal"
	desc = "A monument of white marble built by an emperor for his beloved wife."
	rarity = STICKER_LEGENDARY
	category = STICKER_CAT_WONDERS
	age = STICKER_AGE_IMPERIAL
	icon_state = "collectible_card_5"

/datum/sticker/colosseum
	id = "colosseum"
	index = 77
	name = "Colosseum"
	desc = "The arena that held 50,000 screaming Romans and 100,000 gallons of blood."
	rarity = STICKER_LEGENDARY
	category = STICKER_CAT_WONDERS
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_5"

/datum/sticker/angkor_wat
	id = "angkor_wat"
	index = 78
	name = "Angkor Wat"
	desc = "The largest religious monument ever built - a temple city rising from the jungle."
	rarity = STICKER_LEGENDARY
	category = STICKER_CAT_WONDERS
	age = STICKER_AGE_MEDIEVAL
	icon_state = "collectible_card_5"

/datum/sticker/pyramid
	id = "pyramid"
	index = 79
	name = "Great Pyramid"
	desc = "Last of the Seven Wonders of the Ancient World - and the only one still standing."
	rarity = STICKER_RARE
	category = STICKER_CAT_WONDERS
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_5"

// == Crops: Common ==

/datum/sticker/wheat
	id = "wheat"
	index = 80
	name = "Wheat"
	desc = "The golden grain that feeds civilizations - bread of life since the Fertile Crescent."
	rarity = STICKER_COMMON
	category = STICKER_CAT_CROPS
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_4"

/datum/sticker/corn
	id = "corn"
	index = 81
	name = "Corn"
	desc = "Maize - the gift of the Americas, feeding billions across the New World and the Old."
	rarity = STICKER_COMMON
	category = STICKER_CAT_CROPS
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_4"

/datum/sticker/cotton
	id = "cotton"
	index = 82
	name = "Cotton"
	desc = "Soft white bolls that clothed the world - and fueled revolutions in industry and labor."
	rarity = STICKER_COMMON
	category = STICKER_CAT_CROPS
	age = STICKER_AGE_MEDIEVAL
	icon_state = "collectible_card_4"

/datum/sticker/hemp
	id = "hemp"
	index = 83
	name = "Hemp"
	desc = "Tough fibrous stalks woven into rope, sails, and paper - the working man's plant."
	rarity = STICKER_COMMON
	category = STICKER_CAT_CROPS
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_4"

/datum/sticker/rice
	id = "rice"
	index = 84
	name = "Rice"
	desc = "The staple grain of half the world - paddy fields stretching to the horizon."
	rarity = STICKER_COMMON
	category = STICKER_CAT_CROPS
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_4"

/datum/sticker/tomato
	id = "tomato"
	index = 85
	name = "Tomato"
	desc = "A bright red fruit from the New World that conquered every kitchen in the Old."
	rarity = STICKER_COMMON
	category = STICKER_CAT_CROPS
	age = STICKER_AGE_IMPERIAL
	icon_state = "collectible_card_4"

/datum/sticker/potato
	id = "potato"
	index = 86
	name = "Potato"
	desc = "A humble tuber that fed armies, survived famines, and changed the fate of nations."
	rarity = STICKER_COMMON
	category = STICKER_CAT_CROPS
	age = STICKER_AGE_IMPERIAL
	icon_state = "collectible_card_4"

// == Crops: Uncommon ==

/datum/sticker/tobacco
	id = "tobacco"
	index = 87
	name = "Tobacco"
	desc = "A controversial cash crop that shaped empires, economies, and the fate of colonies."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_CROPS
	age = STICKER_AGE_IMPERIAL
	icon_state = "collectible_card_4"

/datum/sticker/opium
	id = "opium"
	index = 88
	name = "Opium"
	desc = "A potent narcotic resin that sparked wars, addiction crises, and diplomatic incidents."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_CROPS
	age = STICKER_AGE_IMPERIAL
	icon_state = "collectible_card_4"

/datum/sticker/tea
	id = "tea"
	index = 89
	name = "Tea"
	desc = "Leaves steeped in hot water - the drink of emperors, philosophers, and revolutionaries."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_CROPS
	age = STICKER_AGE_MEDIEVAL
	icon_state = "collectible_card_4"

/datum/sticker/coffee
	id = "coffee"
	index = 90
	name = "Coffee"
	desc = "Dark bitter beans brewed into a drink that fueled the Enlightenment and the modern world."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_CROPS
	age = STICKER_AGE_IMPERIAL
	icon_state = "collectible_card_4"

// == Minerals: Common ==

/datum/sticker/dd_rock
	id = "dd_rock"
	index = 91
	name = "Diamond Drilling Rock"
	desc = "Core samples from deep beneath the earth - every gem starts as stone."
	rarity = STICKER_COMMON
	category = STICKER_CAT_MINERALS
	age = STICKER_AGE_INDUSTRIAL
	icon_state = "collectible_card_6"

/datum/sticker/iron_ore
	id = "iron_ore"
	index = 92
	name = "Iron Ore"
	desc = "The backbone of industry - from ploughshares to swords to skyscrapers."
	rarity = STICKER_COMMON
	category = STICKER_CAT_MINERALS
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_6"

/datum/sticker/coal
	id = "coal"
	index = 93
	name = "Coal"
	desc = "Black rock that powered the Industrial Revolution and fired the furnaces of empire."
	rarity = STICKER_COMMON
	category = STICKER_CAT_MINERALS
	age = STICKER_AGE_INDUSTRIAL
	icon_state = "collectible_card_6"

/datum/sticker/copper_ore
	id = "copper_ore"
	index = 94
	name = "Copper Ore"
	desc = "The first metal shaped by human hands - coins, tools, and plumbing."
	rarity = STICKER_COMMON
	category = STICKER_CAT_MINERALS
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_6"

/datum/sticker/tin_ore
	id = "tin_ore"
	index = 95
	name = "Tin Ore"
	desc = "Mixed with copper to make bronze - the alloy that defined an age."
	rarity = STICKER_COMMON
	category = STICKER_CAT_MINERALS
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_6"

/datum/sticker/salt
	id = "salt"
	index = 96
	name = "Salt"
	desc = "White gold of the ancient world - preserving food and seasoning every meal."
	rarity = STICKER_COMMON
	category = STICKER_CAT_MINERALS
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_6"

// == Minerals: Uncommon ==

/datum/sticker/silver_ore
	id = "silver_ore"
	index = 97
	name = "Silver Ore"
	desc = "A gleaming white metal - currency of kings and adornment of temples."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_MINERALS
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_6"

/datum/sticker/gold_ore
	id = "gold_ore"
	index = 98
	name = "Gold Ore"
	desc = "The eternal metal - incorruptible, beautiful, and the root of countless quests."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_MINERALS
	age = STICKER_AGE_STONE
	icon_state = "collectible_card_6"

/datum/sticker/uranium_ore
	id = "uranium_ore"
	index = 99
	name = "Uranium Ore"
	desc = "A radioactive element that powers reactors and haunts battlefields."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_MINERALS
	age = STICKER_AGE_MODERN
	icon_state = "collectible_card_6"

/datum/sticker/lead_ore
	id = "lead_ore"
	index = 100
	name = "Lead Ore"
	desc = "A heavy, dull metal - bullets, pipes, and the shield against radiation."
	rarity = STICKER_UNCOMMON
	category = STICKER_CAT_MINERALS
	age = STICKER_AGE_CLASSICAL
	icon_state = "collectible_card_6"

GLOBAL_LIST_EMPTY(sticker_registry)

/proc/init_sticker_registry()
	if(length(GLOB.sticker_registry))
		return
	var/list/paths = subtypesof(/datum/sticker)
	for(var/path in paths)
		var/datum/sticker/S = new path()
		if(!S.id)
			qdel(S)
			continue
		if(GLOB.sticker_registry[S.id])
			qdel(S)
			continue
		GLOB.sticker_registry[S.id] = S

/proc/sticker_weight(rarity)
	switch(rarity)
		if(STICKER_COMMON)    return 50
		if(STICKER_UNCOMMON)  return 30
		if(STICKER_RARE)      return 15
		if(STICKER_LEGENDARY) return 5
	return 1

/obj/item/sticker
	name = "sticker"
	desc = "A loose collectible sticker."
	icon = 'icons/obj/collectibles.dmi'
	icon_state = "collectible_card"
	w_class = ITEM_SIZE_TINY
	var/sticker_id

/obj/item/sticker/New(loc, _sticker_id)
	..(loc)
	if(_sticker_id)
		sticker_id = _sticker_id
	update_appearance()

/obj/item/sticker/proc/get_sticker_datum()
	if(sticker_id)
		return GLOB.sticker_registry[sticker_id]

/obj/item/sticker/proc/update_appearance()
	var/datum/sticker/S = get_sticker_datum()
	if(S)
		name = S.name
		desc = S.desc
		icon = S.icon
		icon_state = S.icon_state
	else
		name = "unknown sticker"
		desc = "This sticker seems blank or corrupted."
		icon = 'icons/obj/collectibles.dmi'
		icon_state = "collectible_card"

/obj/item/sticker/attack_self(mob/user)
	..()
	examine(user)

/obj/item/sticker/examine(mob/user)
	..()
	var/datum/sticker/S = get_sticker_datum()
	if(S)
		to_chat(user, "<span class='notice'>Index: #[S.index]</span>")
		to_chat(user, "<span class='notice'>Rarity: <font color='[S.rarity_color()]'>[S.rarity_name()]</font></span>")
		to_chat(user, "<span class='notice'>Category: [S.category] | Era: [S.age]</span>")
		user << browse("<!DOCTYPE html><html><head><meta http-equiv='X-UA-Compatible' content='IE=edge'><style>body,html{margin:0;padding:0;width:100%;height:100%;overflow:hidden;}iframe{width:100%;height:100%;border:none;}</style></head><body><iframe src='https://civ13.com/card/[S.index]'></iframe></body></html>", "window=sticker_card;size=370x490")

/obj/item/sticker_pack
	name = "Civ Cards sticker pack"
	desc = "A shiny foil pack containing random stickers. Trade with your friends!"
	icon = 'icons/obj/collectibles.dmi'
	icon_state = "cardpack_civ"
	w_class = ITEM_SIZE_TINY
	var/pack_size = 5

/obj/item/sticker_pack/attack_self(mob/user)
	if(!length(GLOB.sticker_registry))
		to_chat(user, "<span class='warning'>The sticker registry is empty! Something is wrong.</span>")
		return
	user.visible_message("<span class='notice'>[user] rips open \the [src]!</span>")
	playsound(user, 'sound/effects/rip_pack.ogg', 100, TRUE)

	var/list/weighted = list()
	for(var/id in GLOB.sticker_registry)
		var/datum/sticker/S = GLOB.sticker_registry[id]
		weighted[id] = sticker_weight(S.rarity)

	for(var/i = 1 to pack_size)
		if(!length(weighted))
			break
		var/picked = pickweight(weighted)
		if(picked)
			new /obj/item/sticker(get_turf(user), picked)

	user.drop_item()
	qdel(src)

/obj/item/sticker_album
	name = "Civ Cards sticker album"
	desc = "A binder for collecting and displaying your 'Civ Cards' stickers."
	icon = 'icons/obj/collectibles.dmi'
	icon_state = "collectible_album"
	w_class = ITEM_SIZE_NORMAL

/obj/item/sticker_album/anchored
	anchored = TRUE

/obj/item/sticker_album/attackby(obj/item/W, mob/user)
	if(istype(W, /obj/item/sticker))
		var/obj/item/sticker/S = W
		if(!S.sticker_id || !GLOB.sticker_registry[S.sticker_id])
			to_chat(user, "<span class='warning'>This sticker seems blank!</span>")
			return
		var/list/player_stickers = get_player_stickers(user.ckey)
		if(S.sticker_id in player_stickers)
			to_chat(user, "<span class='notice'>You already have this sticker in your collection!</span>")
			return
		player_stickers += S.sticker_id
		user.visible_message("<span class='notice'>[user] carefully places \the [S] into \the [src].</span>")
		qdel(W)
		save_sticker_collection(user.ckey, player_stickers)
		return
	..()

/obj/item/sticker_album/attack_self(mob/user)
	ui_interact(user)

/obj/item/sticker_album/ui_interact(mob/user)
	var/list/player_stickers = get_player_stickers(user.ckey)
	var/list/stickers_by_rarity = list()
	stickers_by_rarity[STICKER_COMMON]    = list()
	stickers_by_rarity[STICKER_UNCOMMON]  = list()
	stickers_by_rarity[STICKER_RARE]      = list()
	stickers_by_rarity[STICKER_LEGENDARY] = list()

	for(var/id in GLOB.sticker_registry)
		var/datum/sticker/S = GLOB.sticker_registry[id]
		if(S)
			stickers_by_rarity[S.rarity] += list(S)

	var/dat = {"<html><head>[common_browser_style]<style>
.rarity-title { font-size: 16px; font-weight: bold; margin-top: 16px; margin-bottom: 8px; padding: 4px; border-bottom: 2px solid; }
.sticker-slot { display: inline-block; width: 140px; height: 80px; margin: 4px; padding: 4px; text-align: center; vertical-align: top; border-radius: 4px; }
.sticker-slot.owned { background: #2a3a2a; border: 1px solid #4a6a4a; }
.sticker-slot.missing { background: #1a1a1a; border: 1px solid #333; }
.sticker-slot .rarity-tag { font-size: 10px; font-weight: bold; display: block; margin-top: 4px; }
.sticker-slot .info-tag { font-size: 9px; color: #888; display: block; }
</style></head><body>"}
	dat += "<h2>Sticker Album</h2>"
	var/collected = length(player_stickers)
	var/total = length(GLOB.sticker_registry)
	dat += "<p>Progress: <b>[collected] / [total]</b> ([round((collected / max(total, 1)) * 100)]%)</p>"

	for(var/r = STICKER_COMMON to STICKER_LEGENDARY)
		var/tier_list = stickers_by_rarity[r]
		if(!length(tier_list))
			continue
		var/first = tier_list[1]
		var/datum/sticker/FS = first
		var/color = FS.rarity_color()
		dat += "<div class='rarity-title' style='border-color: [color]; color: [color];'>[FS.rarity_name()]</div>"
		for(var/datum/sticker/S in tier_list)
			if(S.id in player_stickers)
				dat += "<div class='sticker-slot owned'>"
				dat += "<b>#[S.index] [S.name]</b><br>"
				dat += "<span class='rarity-tag' style='color: [color];'>COLLECTED</span>"
				dat += "<span class='info-tag'>[S.category] - [S.age]</span>"
				dat += "</div>"
			else
				dat += "<div class='sticker-slot missing'>"
				dat += "#[S.index] ???<br>"
				dat += "<span class='rarity-tag' style='color: #555;'>Not yet collected</span>"
				dat += "</div>"

	dat += "<br><br><a href='byond://?src=\ref[src];close=1' class='btn'>Close</a>"
	dat += "</body></html>"
	user << browse(dat, "window=sticker_album;size=650x550")

/obj/item/sticker_album/Topic(href, href_list)
	. = ..()
	if(href_list["close"])
		usr << browse(null, "window=sticker_album")
		return TRUE

GLOBAL_LIST_EMPTY(sticker_collections)

/proc/get_player_stickers(ckey)
	if(!ckey)
		return list()
	if(!GLOB.sticker_collections[ckey])
		GLOB.sticker_collections[ckey] = load_sticker_collection(ckey)
	return GLOB.sticker_collections[ckey]

/proc/load_sticker_collection(ckey)
	if(!ckey)
		return list()
	if(!fexists("SQL/collectibles.txt"))
		return list()
	var/list/lines = file2list("SQL/collectibles.txt")
	for(var/line in lines)
		if(!line)
			continue
		var/list/parts = splittext(line, ";")
		if(length(parts) >= 2 && parts[1] == ckey)
			return parts.Copy(2)
	return list()

/proc/save_sticker_collection(ckey, list/ids)
	if(!ckey || !istype(ids))
		return
	var/list/temp = list()
	for(var/id in ids)
		temp[id] = TRUE
	ids = list()
	for(var/id in temp)
		ids += id
	var/list/new_lines = list()
	var/found = FALSE
	if(fexists("SQL/collectibles.txt"))
		var/list/lines = file2list("SQL/collectibles.txt")
		for(var/line in lines)
			var/list/parts = splittext(line, ";")
			if(length(parts) >= 1 && parts[1] == ckey)
				if(!found)
					new_lines += "[ckey];[jointext(ids, ";")]"
					found = TRUE
			else
				new_lines += line
	if(!found)
		new_lines += "[ckey];[jointext(ids, ";")]"
	if(fexists("SQL/collectibles.txt"))
		if(fexists("SQL/collectibles_backup.txt"))
			fdel("SQL/collectibles_backup.txt")
		fcopy("SQL/collectibles.txt", "SQL/collectibles_backup.txt")
		fdel("SQL/collectibles.txt")
	for(var/line in new_lines)
		if(length(line) > 0)
			text2file(line, "SQL/collectibles.txt")
	GLOB.sticker_collections[ckey] = ids

/obj/item/sticker_album/attack(mob/M, mob/user)
	if(user == M)
		return ui_interact(user)
	if(ismob(M))
		if(!M.ckey)
			to_chat(user, "<span class='notice'>You flip through \the [src] but find no collection linked to [M].</span>")
			return
		var/list/owner_stickers = get_player_stickers(M.ckey)
		var/dat = "<html><head>[common_browser_style]</head><body>"
		dat += "<h2>[M]'s Sticker Album</h2>"
		dat += "<p>Collected: [length(owner_stickers)] / [length(GLOB.sticker_registry)]</p>"
		for(var/id in GLOB.sticker_registry)
			var/datum/sticker/S = GLOB.sticker_registry[id]
			if(id in owner_stickers)
				dat += "<span style='display:inline-block;width:150px;padding:4px;margin:2px;background:#2a3a2a;border:1px solid #4a6a4a;'>"
				dat += "<b>#[S.index] [S.name]</b><br><font color='[S.rarity_color()]'>[S.rarity_name()]</font></span> "
			else
				dat += "<span style='display:inline-block;width:150px;padding:4px;margin:2px;background:#1a1a1a;border:1px solid #333;color:#555;'>"
				dat += "<b>#[S.index]</b> ???</span> "
		dat += "<br><br><a href='byond://?src=\ref[src];close=1' class='btn'>Close</a>"
		dat += "</body></html>"
		user << browse(dat, "window=[M.ckey]_album;size=550x500")
		return
	..()

/obj/item/sticker/attack(mob/M, mob/user)
	if(user == M)
		var/datum/sticker/S = get_sticker_datum()
		if(S)
			to_chat(user, "<span class='notice'>You look at [S.name]. [S.desc]</span>")
		return
	if(ismob(M) && M.ckey && user.ckey != M.ckey)
		user.visible_message("<span class='notice'>[user] offers \the [src] to [M].</span>")
		var/response = alert(M, "[user] wants to give you \a [name]. Accept?", "Sticker Trade", "Accept", "Decline")
		if(response == "Accept" && isturf(user.loc) && isturf(M.loc) && get_dist(user, M) <= 1)
			if(!istype(src) || qdeleted(src))
				return
			user.visible_message("<span class='notice'>[user] hands \the [src] to [M].</span>")
			user.drop_item()
			forceMove(get_turf(M))
			M.put_in_active_hand(src)
			return
		else
			to_chat(user, "<span class='notice'>[M] declined the sticker.</span>")
			return
	..()

/obj/item/sticker_pack/special
	name = "Civ Cards premium sticker pack"
	desc = "A glittering gold-foil pack containing guaranteed rare stickers. Two commons, two uncommons, and one premium pull!"
	icon_state = "cardpack_civ_special"

/obj/item/sticker_pack/special/attack_self(mob/user)
	if(!length(GLOB.sticker_registry))
		to_chat(user, "<span class='warning'>The sticker registry is empty! Something is wrong.</span>")
		return
	user.visible_message("<span class='notice'>[user] carefully opens \the [src]!</span>")
	playsound(user, 'sound/effects/rip_pack.ogg', 100, TRUE)

	var/list/common_pool = list()
	var/list/uncommon_pool = list()
	var/list/rare_pool = list()
	var/list/legendary_pool = list()

	for(var/id in GLOB.sticker_registry)
		var/datum/sticker/S = GLOB.sticker_registry[id]
		switch(S.rarity)
			if(STICKER_COMMON)    common_pool += id
			if(STICKER_UNCOMMON)  uncommon_pool += id
			if(STICKER_RARE)      rare_pool += id
			if(STICKER_LEGENDARY) legendary_pool += id

	// 2 commons
	for(var/i in 1 to 2)
		if(length(common_pool))
			new /obj/item/sticker(get_turf(user), pick(common_pool))
	// 2 uncommons
	for(var/i in 1 to 2)
		if(length(uncommon_pool))
			new /obj/item/sticker(get_turf(user), pick(uncommon_pool))
	// 1 premium: 70% rare, 30% legendary
	if(length(legendary_pool) && prob(30))
		new /obj/item/sticker(get_turf(user), pick(legendary_pool))
	else if(length(rare_pool))
		new /obj/item/sticker(get_turf(user), pick(rare_pool))
	else if(length(legendary_pool))
		new /obj/item/sticker(get_turf(user), pick(legendary_pool))

	user.drop_item()
	qdel(src)

/obj/effect/spawner/sticker_single
	name = "sticker spawner"
	icon = 'icons/obj/collectibles.dmi'
	icon_state = "cardpack_civ"

/obj/effect/spawner/sticker_single/New()
	..()
	if(!length(GLOB.sticker_registry))
		qdel(src)
		return
	var/list/pool = build_pool()
	if(length(pool))
		new /obj/item/sticker(get_turf(src), pick(pool))
	qdel(src)

/obj/effect/spawner/sticker_single/proc/build_pool()
	var/list/pool = list()
	for(var/id in GLOB.sticker_registry)
		var/datum/sticker/S = GLOB.sticker_registry[id]
		var/w = sticker_weight(S.rarity)
		for(var/i in 1 to w)
			pool += id
	return pool

/obj/effect/spawner/sticker_single/common
	name = "common sticker spawner"

/obj/effect/spawner/sticker_single/common/build_pool()
	var/list/pool = list()
	for(var/id in GLOB.sticker_registry)
		var/datum/sticker/S = GLOB.sticker_registry[id]
		if(S.rarity == STICKER_COMMON)
			pool += id
	return pool

/obj/effect/spawner/sticker_single/rare
	name = "rare+ sticker spawner"

/obj/effect/spawner/sticker_single/rare/build_pool()
	var/list/pool = list()
	for(var/id in GLOB.sticker_registry)
		var/datum/sticker/S = GLOB.sticker_registry[id]
		if(S.rarity == STICKER_RARE || S.rarity == STICKER_LEGENDARY)
			pool += id
	return pool
