/area/caribbean
	requires_power = FALSE
	has_gravity = TRUE
	no_air = FALSE
	base_turf = /turf/floor/dirt //The base turf type of the area, which can be used to override the z-level's base turf
	sound_env = FOREST
	icon_state = "purple1"
	dynamic_lighting = TRUE
	ambience = list("sound/ambience/ship1.ogg")

// Basic Area Definitions

/* note: BYOND reaches some kind of limit when it encounters areas with massive
 * contents lists (around 30,000 - 65,000 maybe), causing any movement in those areas
 * to slow down dramatically. The forest area reached this limit, but only
 * when there were snow objects, so its been split into 9 separate areas.
*/
/area/caribbean/roofed
	name = "Roofed Area"
	base_turf = /turf/floor/dirt
	icon_state = "blue1"
	location = AREA_INSIDE

/area/caribbean/treasury
	name = "Colony Treasury"
	base_turf = /turf/floor/dirt
	icon_state = "red3"
	ambience = list("sound/ambience/jungle1.ogg")

/area/caribbean/treasury/civilian
	name = "Colony Treasury"

/area/caribbean/treasury/french
	name = "French Treasury"

/area/caribbean/treasury/british
	name = "British Treasury"

/area/caribbean/treasury/spanish
	name = "Spanish Treasury"

/area/caribbean/treasury/portuguese
	name = "Portuguese Treasury"

/area/caribbean/treasury/dutch
	name = "Dutch Treasury"


/area/caribbean/tribes
	name = "Jungle"
	base_turf = /turf/floor/dirt
	icon_state = "red3"
	ambience = list("sound/ambience/jungle1.ogg")
	climate = "jungle"
/area/caribbean/tribes/goose
	name = "Red Goose Tribe"
/area/caribbean/tribes/goose/supplies

/area/caribbean/tribes/monkey
	name = "Green Monkey Tribe"
/area/caribbean/tribes/monkey/supplies

/area/caribbean/tribes/turkey
	name = "Blue Turkey Tribe"
/area/caribbean/tribes/turkey/supplies

/area/caribbean/tribes/mouse
	name = "Yellow Mouse Tribe"
/area/caribbean/tribes/mouse/supplies

/area/caribbean/tribes/wolf
	name = "White Wolf Tribe"
/area/caribbean/tribes/wolf/supplies

/area/caribbean/tribes/bear
	name = "Black Bear Tribe"
/area/caribbean/tribes/bear/supplies

/area/caribbean/tribes/caves
	name = "Caves"
	base_turf = /turf/floor/dirt
	icon_state = "red3"
	location = AREA_INSIDE
	ambience = list("sound/ambience/jungle1.ogg")
/area/caribbean/tribes/beach
	name = "Beach"
	base_turf = /turf/floor/beach/sand
	icon_state = "red1"
	ambience = list("sound/ambience/jungle1.ogg")
/area/caribbean/tribes/swamp
	name = "Swamp"
	base_turf = /turf/floor/beach/sand
	icon_state = "purple1"
	ambience = list("sound/ambience/jungle1.ogg")
/area/caribbean/tribes/grasslands
	name = "Grasslands"
	base_turf = /turf/floor/grass
	icon_state = "purple1"
	ambience = list("sound/ambience/jungle1.ogg")
/area/caribbean/tribes/lostcity
	name = "Lost City"
	base_turf = /turf/floor/dirt
	icon_state = "purple2"
	ambience = list("sound/ambience/jungle1.ogg")

/area/caribbean/nomads
	name = "Grassland"
	base_turf = /turf/floor/grass
	icon_state = "red2"
	ambience = list("sound/ambience/jungle1.ogg")
	climate = "temperate"

/area/caribbean/nomads/sand
	name = "Beach"
	base_turf = /turf/floor/beach/sand
	icon_state = "blue1"
	ambience = list("sound/ambience/jungle1.ogg")
	climate = "temperate"

/area/caribbean/nomads/desert
	name = "Desert"
	base_turf = /turf/floor/beach/sand/desert
	icon_state = "red3"
	ambience = list("sound/ambience/desert.ogg")
	climate = "desert"

/area/caribbean/nomads/desert/water
	name = "Desert River"
	base_turf = /turf/floor/beach/sand/desert
	icon_state = "blue2"
	ambience = list("sound/ambience/desert.ogg")
	climate = "desert"

/area/caribbean/nomads/river
	name = "Jungle River"
	base_turf = /turf/floor/beach/water/jungle
	icon_state = "blue1"
	climate = "jungle"

/area/caribbean/nomads/forest
	name = "Forest"
	base_turf = /turf/floor/grass
	icon_state = "green1"
	climate = "temperate"

/area/caribbean/nomads/semiarid
	name = "Semi-Arid"
	base_turf = /turf/floor/dirt/dust
	icon_state = "red1"
	climate = "semiarid"

/area/caribbean/nomads/forest/snow
	name = "Snowy Forest"
	base_turf = /turf/floor/winter/grass
	icon_state = "green1"
	climate = "tundra"

/area/caribbean/nomads/forest/Jungle
	name = "Jungle"
	base_turf = /turf/floor/grass/jungle
	icon_state = "green1"
	climate = "jungle"

/area/caribbean/nomads/forest/savanna
	name = "Savanna"
	base_turf = /turf/floor/grass/jungle/savanna
	icon_state = "blue3"
	climate = "savanna"

/area/caribbean/nomads/forest/Jungle/river
	name = "Jungle River"
	base_turf = /turf/floor/beach/water/jungle
	icon_state = "green3"
	climate = "jungle"

/area/caribbean/nomads/snow
	name = "Snow"
	base_turf = /turf/floor/winter
	icon_state = "red1"
	climate = "tundra"

/area/caribbean/nomads/taiga
	name = "Taiga"
	base_turf = /turf/floor/dirt
	icon_state = "red3"
	climate = "taiga"

/area/caribbean/nomads/ice
	name = "Ice"
	base_turf = /turf/floor/beach/water/ice
	icon_state = "blue1"
	climate = "tundra"

/area/caribbean/island
	name = "Island"
	base_turf = /turf/floor/beach/sand
	icon_state = "red3"
	ambience = list("sound/ambience/jungle1.ogg")
	climate = "sea"

/area/caribbean/island/river
	base_turf = /turf/floor/beach/water/shallowsaltwater
	icon_state = "red1"

/area/caribbean/sea
	name = "Island"
	base_turf = /turf/floor/beach/sand
	icon_state = "purple1"
	ambience = list("sound/ambience/ship1.ogg")
	climate = "sea"

/area/caribbean/sea/beach
	name = "Beach"
	base_turf = /turf/floor/beach/sand
	icon_state = "red4"

/area/caribbean/sea/shallow
	name = "Shallow Water"
	base_turf = /turf/floor/beach/water
	icon_state = "blue1"

/area/caribbean/sea/sea
	name = "Sea"
	base_turf = /turf/floor/beach/water/deep
	icon_state = "blue2"

/area/caribbean/no_mans_land
	name = "No Man's Land"
	icon_state = "purple1"
	base_turf = /turf/floor/dirt
/area/caribbean/no_mans_land/tundra
	name = "No Man's Land"
	icon_state = "purple1"
	climate = "tundra"
	base_turf = /turf/floor/dirt/winter
/area/caribbean/no_mans_land/taiga
	name = "No Man's Land"
	icon_state = "purple1"
	climate = "tundra"
	base_turf = /turf/floor/dirt/winter
/area/caribbean/no_mans_land/temperate
	name = "No Man's Land"
	icon_state = "purple1"
	climate = "temperate"
	base_turf = /turf/floor/dirt
/area/caribbean/no_mans_land/desert
	name = "No Man's Land"
	icon_state = "purple1"
	climate = "desert"
	base_turf = /turf/floor/beach/sand/desert
/area/caribbean/no_mans_land/semiarid
	name = "No Man's Land"
	icon_state = "purple1"
	climate = "semiarid"
	base_turf = /turf/floor/dirt/dust
/area/caribbean/no_mans_land/jungle
	name = "No Man's Land"
	icon_state = "purple1"
	climate = "jungle"
	base_turf = /turf/floor/dirt/jungledirt
/area/caribbean/no_mans_land/invisible_wall
	icon_state = "green1"
	name = "grace wall"

/area/caribbean/no_mans_land/invisible_wall/one
	icon_state = "green1"
	name = "I grace wall"

/area/caribbean/no_mans_land/invisible_wall/two
	icon_state = "green1"
	name = "II grace wall"

/area/caribbean/no_mans_land/invisible_wall/three
	icon_state = "green1"
	name = "III grace wall"

/area/caribbean/no_mans_land/invisible_wall/four
	icon_state = "green1"
	name = "IV grace wall"
/area/caribbean/no_mans_land/invisible_wall/inside
	location = AREA_INSIDE

/area/caribbean/desert
	name = "The Desert"
	icon_state = "red1"
	base_turf = /turf/floor/beach/sand/desert
	ambience = list("sound/ambience/desert.ogg")
	climate = "desert"
/area/caribbean/desert/town
	name = "Little Creek"
	icon_state = "blue1"

/area/caribbean/desert/escape
	name = "Escape Area"
	icon_state = "blue3"

/area/caribbean/desert/buildings
	name = "Little Creek Buildings"
	icon_state = "green1"
	base_turf = /turf/floor/dirt
	location = AREA_INSIDE

/area/caribbean/forest
	name = "The Forest"
	icon_state = "purple1"
	base_turf = /turf/floor/grass
	climate = "temperate"

/area/caribbean/forest/dirt
	name = "The Forest"
	icon_state = "purple1"
	base_turf = /turf/floor/dirt
	climate = "temperate"

/area/caribbean/supply
	name = "Supply Arrival"
	icon_state = "blue1"

/area/caribbean/supply/british
	name = "British Supply Arrival"

/area/caribbean/supply/spanish
	name = "Spanish Supply Arrival"

/area/caribbean/supply/portuguese
	name = "PortugueseSupply Arrival"

/area/caribbean/supply/french
	name = "French Supply Arrival"

/area/caribbean/supply/dutch
	name = "Dutch Supply Arrival"

/area/caribbean/transport
	name = "Boat"
	icon_state = "red1"

/area/caribbean/transport/one
	name = "Boat"
	icon_state = "red1"

/area/caribbean/transport/two
	name = "Boat"
	icon_state = "red1"

/area/caribbean/transport/three
	name = "Boat"
	icon_state = "red1"

/area/caribbean/transport/four
	name = "Boat"
	icon_state = "red1"

/area/caribbean/transport/five
	name = "Boat"
	icon_state = "red1"

/area/caribbean/farm
	name = "Farmland"
	icon_state = "red3"
	climate = "temperate"

// admin zone

/area/caribbean/admin
	icon_state = "blue1"
	name = "Admin Zone"
	location = AREA_INSIDE
	artillery_integrity = INFINITY
	base_turf = /turf/floor/dirt
	climate = "temperate"

// houses in No Man's Land

/area/caribbean/houses
	name = "Houses"
	icon_state = "red1"
	location = AREA_INSIDE
	base_turf = /turf/floor/dirt

/area/caribbean/houses/nml_one
/area/caribbean/houses/nml_two
/area/caribbean/houses/nml_three
/area/caribbean/houses/nml_four
/area/caribbean/houses/nml_five
/area/caribbean/houses/nml_six
/area/caribbean/houses/nml_seven
/area/caribbean/houses/nml_eight
/area/caribbean/houses/nml_nine
/area/caribbean/houses/nml_ten
/area/caribbean/houses/nml_eleven
/area/caribbean/houses/nml_twelve
/area/caribbean/houses/nml_thirteen
/area/caribbean/houses/nml_fourteen
/area/caribbean/houses/nml_fifteen
/area/caribbean/houses/nml_sixteen
/area/caribbean/houses/nml_seventeen
/area/caribbean/houses/nml_eighteen
/area/caribbean/houses/nml_nineteen
/area/caribbean/houses/nml_twenty
/area/caribbean/houses/nml_twentyone
/area/caribbean/houses/nml_bunker
	artillery_integrity = 200


/area/caribbean/sewers
	artillery_integrity = INFINITY
	dynamic_lighting = FALSE
	location = AREA_INSIDE

// "wormhole" areas: doesn't include trains since they don't get their area copied

// where all this stuff is

/area/caribbean/void
	icon_state = "purple1"
	name = "the void"
	location = AREA_INSIDE
	is_void_area = TRUE
	base_turf = /turf/floor/dirt

/area/caribbean/void/caves
	icon_state = "blue1"
	name = "the caves"
	location = AREA_INSIDE

/area/caribbean/void/caves/special
	icon_state = "blue2"
	name = "the caves"
	location = AREA_INSIDE

/area/caribbean/void/caves/level1
	icon_state = "blue1"
	name = "the caves"
	location = AREA_INSIDE

/area/caribbean/void/caves/level2
	icon_state = "blue1"
	name = "the caves"
	location = AREA_INSIDE

/area/caribbean/void/caves/level3
	icon_state = "blue1"
	name = "the caves"
	location = AREA_INSIDE

/area/caribbean/void/caves/level4
	icon_state = "blue1"
	name = "the caves"
	location = AREA_INSIDE

/area/caribbean/void/caves/level5
	icon_state = "blue1"
	name = "the caves"
	location = AREA_INSIDE

/area/caribbean/void/caves/level6
	icon_state = "blue1"
	name = "the caves"
	location = AREA_INSIDE

/area/caribbean/void/caves/level7
	icon_state = "blue1"
	name = "the caves"
	location = AREA_INSIDE

/area/caribbean/void/caves/level8
	icon_state = "blue1"
	name = "the caves"
	location = AREA_INSIDE
// end of wormhole areas


/area/caribbean/colonies

/area/caribbean/colonies/jungle
	name = "Jungle"
	icon_state = "red2"
	base_turf = /turf/floor/dirt
	ambience = list("sound/ambience/jungle1.ogg")
	climate = "jungle"

/area/caribbean/colonies/beach
	name = "Beach"
	icon_state = "red1"
	base_turf = /turf/floor/beach/sand
	ambience = list("sound/ambience/jungle1.ogg")
	climate = "temperate"

/area/caribbean/colonies/caves
	name = "Caves"
	icon_state = "red3"
	base_turf = /turf/floor/dirt
	location = AREA_INSIDE
	ambience = list("sound/ambience/jungle1.ogg")

/area/caribbean/colonies/swamp
	name = "Swamp"
	icon_state = "red4"
	base_turf = /turf/floor/beach/water/swamp
	ambience = list("sound/ambience/jungle1.ogg")
	climate = "jungle"

/area/caribbean/colonies/british
	name = "British Colony Hall"
	icon_state = "green2"
	base_turf = /turf/floor/dirt
	location = AREA_INSIDE
	ambience = list("sound/ambience/jungle1.ogg")

/area/caribbean/colonies/portuguese
	name = "Portuguese Colony Hall"
	icon_state = "green2"
	base_turf = /turf/floor/dirt
	location = AREA_INSIDE
	ambience = list("sound/ambience/jungle1.ogg")

/area/caribbean/colonies/spanish
	name = "Spanish Colony Hall"
	icon_state = "green2"
	base_turf = /turf/floor/dirt
	location = AREA_INSIDE
	ambience = list("sound/ambience/jungle1.ogg")

/area/caribbean/colonies/french
	name = "French Colony Hall"
	icon_state = "green2"
	base_turf = /turf/floor/dirt
	location = AREA_INSIDE
	ambience = list("sound/ambience/jungle1.ogg")

/area/caribbean/colonies/dutch
	name = "Dutch Colony Hall"
	icon_state = "green2"
	base_turf = /turf/floor/dirt
	ambience = list("sound/ambience/jungle1.ogg")
	location = AREA_INSIDE

/area/caribbean/japanese

/area/caribbean/japanese/land
	name = "Land Base"
	icon_state = "red1"
	base_turf = /turf/floor/dirt


/area/caribbean/japanese/land/inside
	location = AREA_INSIDE
	icon_state = "red2"

/area/caribbean/japanese/land/inside/command
	location = AREA_INSIDE
	icon_state = "red2"


/area/caribbean/japanese/land/outside
	icon_state = "red3"

/area/caribbean/russian

/area/caribbean/russian/land
	name = "Land Base"
	icon_state = "red1"
	base_turf = /turf/floor/dirt
	ambience = list("sound/ambience/jungle1.ogg")


/area/caribbean/russian/land/inside
	location = AREA_INSIDE
	icon_state = "red2"

/area/caribbean/russian/land/inside/command
	location = AREA_INSIDE
	icon_state = "red2"


/area/caribbean/russian/land/outside
	icon_state = "red3"

/area/caribbean/british
	icon_state = "blue1"

/area/caribbean/british/land
	name = "British Base"
	icon_state = "blue1"
	base_turf = /turf/floor/dirt
	ambience = list("sound/ambience/jungle1.ogg")


/area/caribbean/british/land/inside
	location = AREA_INSIDE
	icon_state = "blue2"

/area/caribbean/british/land/inside/objective
	icon_state = "blue2"

/area/caribbean/british/land/outside
	icon_state = "blue3"

/area/caribbean/british/land/outside/objective
	icon_state = "blue1"


/area/caribbean/french
	icon_state = "blue1"

/area/caribbean/french/land
	name = "French Base"
	icon_state = "blue1"
	base_turf = /turf/floor/dirt
	ambience = list("sound/ambience/jungle1.ogg")


/area/caribbean/french/land/inside
	location = AREA_INSIDE
	icon_state = "blue2"

/area/caribbean/french/land/inside/objective
/area/caribbean/french/land/outside
	icon_state = "blue3"

/area/caribbean/french/land/outside/objective
	icon_state = "blue1"

/area/caribbean/german
	name = "German Base"
	icon_state = "red1"
	base_turf = /turf/floor/dirt
/area/caribbean/german/objective
	icon_state = "red3"
/area/caribbean/german/inside
	location = AREA_INSIDE
	icon_state = "red2"
/area/caribbean/german/inside/objective

/area/caribbean/german/reichstag/lobby
	name = "Reichstag Lobby"
	base_turf = /turf/floor/dirt
	location = AREA_INSIDE
	icon_state = "red2"

/area/caribbean/german/reichstag/first
	name = "Reichstag 1st Floor"
	base_turf = /turf/floor/plating/concrete
	location = AREA_INSIDE
	icon_state = "red2"

/area/caribbean/german/reichstag/second
	name = "Reichstag 2nd Floor"
	base_turf = /turf/floor/plating/concrete
	location = AREA_INSIDE
	icon_state = "red2"

/area/caribbean/german/reichstag/roof
	name = "Reichstag Roof"
	base_turf = /turf/floor/plating/concrete
	icon_state = "red2"
/area/caribbean/german/reichstag/roof/objective
	name = "Reichstag Roof Objective"
	icon_state = "red3"

/area/caribbean/british/ship
	name = "British Ship"
	icon_state = "blue1"
	base_turf = /turf/floor/beach/water
	ambience = list("sound/ambience/ship1.ogg")

/area/caribbean/british/ship/main_deck
	name = "Main Deck"
	icon_state = "blue1"
	base_turf = /turf/floor/broken_floor

/area/caribbean/british/ship/poop_deck
	name = "Poop Deck"
	icon_state = "blue2"
	base_turf = /turf/floor/broken_floor

/area/caribbean/british/ship/upper_gun
	name = "Upper Gun Deck"
	icon_state = "blue3"
	location = AREA_INSIDE
	base_turf = /turf/floor/broken_floor

/area/caribbean/british/ship/middle
	name = "Middle Deck"
	icon_state = "blue3"
	location = AREA_INSIDE
	base_turf = /turf/floor/broken_floor

/area/caribbean/british/ship/lower
	name = "Lower Deck"
	icon_state = "blue3"
	location = AREA_INSIDE
	base_turf = /turf/floor/broken_floor


/area/caribbean/british/ship/orlop
	name = "Orlop Deck"
	icon_state = "blue4"
	location = AREA_INSIDE
	base_turf = /turf/floor/broken_floor

/area/caribbean/british/ship/hold
	name = "Hold"
	icon_state = "blue4"
	location = AREA_INSIDE
	base_turf = /turf/floor/beach/water

/area/caribbean/british/ship/galley
	name = "Prison"
	icon_state = "blue5"
	capturable = FALSE
	location = AREA_INSIDE
	base_turf = /turf/floor/broken_floor


/area/caribbean/british/ship/kitchen
	name = "Kitchen"
	icon_state = "blue5"
	location = AREA_INSIDE
	base_turf = /turf/floor/broken_floor


/area/caribbean/british/ship/office
	name = "Captain's Office"
	icon_state = "green5"
	location = AREA_INSIDE
	base_turf = /turf/floor/broken_floor

// pirates areas

/area/caribbean/pirates
	name = "pirates"
/area/caribbean/pirates/land
	name = "Land Base"
	icon_state = "red1"
	base_turf = /turf/floor/dirt
	ambience = list("sound/ambience/jungle1.ogg")

/area/caribbean/pirates/land/inside
	location = AREA_INSIDE
	icon_state = "red2"

/area/caribbean/pirates/land/inside/objective



/area/caribbean/pirates/land/outside
	icon_state = "red3"


/area/caribbean/pirates/ship
	icon_state = "green1"
	base_turf = /turf/floor/beach/water
	ambience = list("sound/ambience/ship1.ogg")

/area/caribbean/pirates/ship/main_deck
	name = "Main Deck"
	icon_state = "green1"
	base_turf = /turf/floor/broken_floor

/area/caribbean/pirates/ship/poop_deck
	name = "Poop Deck"
	icon_state = "green2"
	base_turf = /turf/floor/broken_floor

/area/caribbean/pirates/ship/upper_gun
	name = "Upper Gun Deck"
	icon_state = "green3"
	location = AREA_INSIDE
	base_turf = /turf/floor/broken_floor

/area/caribbean/pirates/ship/middle
	name = "Middle Deck"
	icon_state = "green3"
	location = AREA_INSIDE
	base_turf = /turf/floor/broken_floor

/area/caribbean/pirates/ship/lower
	name = "Lower Deck"
	icon_state = "green3"
	location = AREA_INSIDE
	base_turf = /turf/floor/broken_floor


/area/caribbean/pirates/ship/orlop
	name = "Orlop Deck"
	icon_state = "green4"
	location = AREA_INSIDE
	base_turf = /turf/floor/broken_floor

/area/caribbean/pirates/ship/hold
	name = "Hold"
	icon_state = "green4"
	location = AREA_INSIDE
	base_turf = /turf/floor/beach/water

/area/caribbean/pirates/ship/galley
	name = "Prison"
	icon_state = "green5"
	capturable = FALSE
	location = AREA_INSIDE
	base_turf = /turf/floor/broken_floor


/area/caribbean/pirates/ship/kitchen
	name = "Kitchen"
	icon_state = "green5"
	location = AREA_INSIDE
	base_turf = /turf/floor/broken_floor


/area/caribbean/pirates/ship/office
	name = "Captain's Office"
	icon_state = "green5"
	location = AREA_INSIDE
	base_turf = /turf/floor/broken_floor

/area/caribbean/indians
	name = "Natives"

/area/caribbean/indians/camp
	name = "Native Camp"
	icon_state = "red1"
	base_turf = /turf/floor/dirt
	ambience = list("sound/ambience/jungle1.ogg")

/area/caribbean/roman
	name = "Roman Camp"
	icon_state = "red3"
	base_turf = /turf/floor/dirt

/area/caribbean/roman/arena1
	name = "Arena I"
	icon_state = "blue1"

/area/caribbean/roman/arena2
	name = "Arena II"
	icon_state = "blue2"

/area/caribbean/roman/arena3
	name = "Arena III"
	icon_state = "blue1"

/area/caribbean/roman/arena4
	name = "Arena IV"
	icon_state = "blue2"
/area/caribbean/roman/arena4/out
	name = "Arena IV outer ring"
	icon_state = "blue3"

/area/caribbean/roman/morgue
	name = "Morgue"
	icon_state = "red3"
	location = AREA_INSIDE

/area/caribbean/roman/armory
	name = "Armory"
	icon_state = "green1"
	location = AREA_INSIDE

/area/caribbean/roman/armory/loot
	name = "Armory Loots"
	icon_state = "green2"
/area/caribbean/roman/armory/loot2
	name = "Armory Loots"
	icon_state = "green3"
/area/caribbean/greek
	name = "Greek Camp"
	icon_state = "blue1"
	base_turf = /turf/floor/dirt
/area/caribbean/arab
	name = "Arab Camp"
	icon_state = "blue1"
	base_turf = /turf/floor/dirt

/area/caribbean/crusader
	name = "Crusader Camp"
	icon_state = "red1"
	base_turf = /turf/floor/dirt

/area/caribbean/crusader/sand
	base_turf = /turf/floor/beach/sand
/area/caribbean/arab/sand
	base_turf = /turf/floor/beach/sand

/area/caribbean/arab/desert
	name = "Desert"
	base_turf = /turf/floor/beach/sand/desert
	climate = "desert"
	icon_state = "blue1"
/area/caribbean/arab/caves
	name = "Caves"
	base_turf = /turf/floor/dirt
	icon_state = "blue2"
	location = AREA_INSIDE
	climate = "desert"

/area/caribbean/arab/caves/prison
	name = "Cave Prison"
	base_turf = /turf/floor/dirt
	icon_state = "blue3"
	location = AREA_INSIDE
	climate = "desert"