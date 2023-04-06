/area/caribbean
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

/area/caribbean/roofed/tundra
	climate = "tundra"
	base_turf = /turf/floor/dirt/winter

/area/caribbean/roofed/taiga
	climate = "taiga"
	base_turf = /turf/floor/dirt/winter

/area/caribbean/roofed/temperate
	climate = "temperate"
	base_turf = /turf/floor/dirt/burned

/area/caribbean/roofed/sea
	climate = "sea"
	base_turf = /turf/floor/dirt

/area/caribbean/roofed/desert
	climate = "desert"
	base_turf = /turf/floor/beach/sand/desert

/area/caribbean/roofed/semiarid
	climate = "semiarid"
	base_turf = /turf/floor/dirt/dust

/area/caribbean/roofed/savanna
	climate = "savanna"
	base_turf = /turf/floor/dirt/jungledirt

/area/caribbean/roofed/jungle
	climate = "jungle"
	base_turf = /turf/floor/dirt/jungledirt

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
	base_turf = /turf/floor/dirt/burned
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
	base_turf = /turf/floor/dirt/jungledirt
	icon_state = "green1"
	climate = "jungle"

/area/caribbean/nomads/forest/Jungle/sea
	base_turf = /turf/floor/beach/water/deep/saltwater
	icon_state = "blue1"

/area/caribbean/nomads/forest/Jungle/beach
	base_turf = /turf/floor/beach/sand
	icon_state = "yellow1"
//lava paths
/area/caribbean/nomads/forest/Jungle/lava_west
	icon_state = "green3"
/area/caribbean/nomads/forest/Jungle/lava_west/one

/area/caribbean/nomads/forest/Jungle/lava_west/two

/area/caribbean/nomads/forest/Jungle/lava_east
	icon_state = "green3"
/area/caribbean/nomads/forest/Jungle/lava_east/one

/area/caribbean/nomads/forest/Jungle/lava_east/two

/area/caribbean/nomads/forest/Jungle/lava_south
	icon_state = "green3"
/area/caribbean/nomads/forest/Jungle/lava_south/one

/area/caribbean/nomads/forest/Jungle/lava_south/two

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

/area/caribbean/nomads/ice/target
	name = "Ice"
	base_turf = /turf/floor/beach/water/ice
	icon_state = "green1"
	climate = "tundra"

/area/caribbean/prison
	name = "Prisoner camp"
	base_turf = /turf/floor/dirt/winter
	icon_state = "blue2"
	climate = "tundra"

/area/caribbean/prison/jail
	name = "Jail"
	climate = "temperate"
	base_turf = /turf/floor/dirt
	location = AREA_INSIDE

/area/caribbean/prison/jail/processing
	name = "Processing Area"
	icon_state = "blue1"
	location = AREA_INSIDE

/area/caribbean/island
	name = "Island"
	base_turf = /turf/floor/beach/sand
	icon_state = "red3"
	ambience = list("sound/ambience/jungle1.ogg")
	climate = "sea"

/area/caribbean/island/river
	base_turf = /turf/floor/beach/water/deep
	icon_state = "red1"

/area/caribbean/island/tropical
	name = "Island"
	base_turf = /turf/floor/beach/sand
	icon_state = "red3"
	ambience = list("sound/ambience/jungle1.ogg")
	climate = "jungle"

/area/caribbean/island/river/tropical
	base_turf = /turf/floor/beach/water
	icon_state = "red1"
	climate = "jungle"

/area/caribbean/sea
	name = "Island"
	base_turf = /turf/floor/beach/sand
	icon_state = "purple1"
	ambience = list("sound/ambience/ship1.ogg")
	climate = "sea"

/area/caribbean/sea/top
	name = "sea"
	base_turf = /turf/floor/beach/water/deep/saltwater
	icon_state = "purple2"

/area/caribbean/sea/top/roofed
	location = AREA_INSIDE

/area/caribbean/sea/bottom
	name = "sea"
	base_turf = /turf/floor/beach/water/deep/saltwater
	icon_state = "red4"
/area/caribbean/sea/bottom/temperate
	climate = "temperate"

/area/caribbean/sea/bottom/roofed
	location = AREA_INSIDE

/area/caribbean/sea/beach
	name = "Beach"
	base_turf = /turf/floor/beach/sand
	icon_state = "red4"

/area/caribbean/sea/beach/temperate
	climate = "temperate"

/area/caribbean/sea/shallow
	name = "Shallow Water"
	base_turf = /turf/floor/beach/water
	icon_state = "blue1"

/area/caribbean/sea/shallow/temperate
	climate = "temperate"

/area/caribbean/sea/cobblebridge
	name = "Bridge"
	base_turf = /turf/floor/plating/cobblestone
	icon_state = "purple2"

/area/caribbean/sea/sea
	name = "Sea"
	base_turf = /turf/floor/beach/water/deep
	icon_state = "blue2"

/area/caribbean/sea/sea/ins
	name = "Sea"
	base_turf = /turf/floor/beach/water/deep
	icon_state = "blue2"
	location = AREA_INSIDE

/area/caribbean/no_mans_land/sky
	name = "No Man's Sky"
	icon_state = "purple1"
	base_turf = /turf/floor/broken_floor/sky
	dynamic_lighting = FALSE
	ambience = list("sound/effect/wind/wind_4_1.ogg")
	var/landing_area = null
	var/allow_area_subtypes = FALSE

/area/caribbean/no_mans_land/sky/paratrooper_drop_zone
	landing_area = /area/caribbean/forest
	allow_area_subtypes = TRUE
	name = "The Sky"

/area/caribbean/helicopter/takeoff
	name = "Helicopter Takeoff Pad"
	icon_state = "blue2"

/area/caribbean/helicopter/transit
	name = "Helicopter Transit"
	icon_state = "blue2"

/area/caribbean/helicopter/landing_pad/one
	name = "Helicopter Landing Pad 1"
	icon_state = "blue2"
/area/caribbean/helicopter/landing_pad/two
	name = "Helicopter Takeoff Pad 2"
	icon_state = "blue2"
/area/caribbean/helicopter/landing_pad/three
	name = "Helicopter Takeoff Pad 3"
	icon_state = "blue2"

/area/caribbean/no_mans_land/sky/paratrooper_drop_zone/plane
	landing_area = /area/caribbean/forest
	allow_area_subtypes = TRUE
	name = "Plane"

/area/caribbean/no_mans_land
	name = "No Man's Land"
	icon_state = "purple1"
	base_turf = /turf/floor/dirt

/area/caribbean/no_mans_land/battleroyale
	name = "Area 1"
	icon_state = "red1"
	base_turf = /turf/floor/dirt

/area/caribbean/no_mans_land/battleroyale/one
	name = "North-Western Area"
	icon_state = "red1"
	base_turf = /turf/floor/dirt

/area/caribbean/no_mans_land/battleroyale/one/inside
	location = AREA_INSIDE
	icon_state = "purple1"

/area/caribbean/no_mans_land/battleroyale/one/border
	icon_state = "black1"
/area/caribbean/no_mans_land/battleroyale/one/border/inside
	icon_state = "black1"
	location = AREA_INSIDE

/area/caribbean/no_mans_land/battleroyale/two
	name = "North-Eastern Area"
	icon_state = "blue1"
	base_turf = /turf/floor/dirt
/area/caribbean/no_mans_land/battleroyale/two/inside
	location = AREA_INSIDE
	icon_state = "purple1"
/area/caribbean/no_mans_land/battleroyale/two/border
	icon_state = "black1"
/area/caribbean/no_mans_land/battleroyale/two/border/inside
	icon_state = "black1"
	location = AREA_INSIDE

/area/caribbean/no_mans_land/battleroyale/three
	name = "Western Area"
	icon_state = "green1"
	base_turf = /turf/floor/dirt
/area/caribbean/no_mans_land/battleroyale/three/inside
	location = AREA_INSIDE
	icon_state = "purple1"
/area/caribbean/no_mans_land/battleroyale/three/border
	icon_state = "black1"
/area/caribbean/no_mans_land/battleroyale/three/border/inside
	icon_state = "black1"
	location = AREA_INSIDE

/area/caribbean/no_mans_land/battleroyale/four
	name = "Eastern Area"
	icon_state = "green2"
	base_turf = /turf/floor/dirt
/area/caribbean/no_mans_land/battleroyale/four/inside
	location = AREA_INSIDE
	icon_state = "purple1"
/area/caribbean/no_mans_land/battleroyale/four/border
	icon_state = "black1"
/area/caribbean/no_mans_land/battleroyale/four/border/inside
	icon_state = "black1"
	location = AREA_INSIDE

/area/caribbean/no_mans_land/battleroyale/five
	name = "South-Western Area"
	icon_state = "red2"
/area/caribbean/no_mans_land/battleroyale/five/inside
	location = AREA_INSIDE
	icon_state = "purple1"
/area/caribbean/no_mans_land/battleroyale/five/border
	icon_state = "black1"
/area/caribbean/no_mans_land/battleroyale/five/border/inside
	icon_state = "black1"
	location = AREA_INSIDE

/area/caribbean/no_mans_land/battleroyale/six
	name = "South-Eastern Area"
	icon_state = "blue2"
/area/caribbean/no_mans_land/battleroyale/six/inside
	location = AREA_INSIDE
	icon_state = "purple1"
/area/caribbean/no_mans_land/battleroyale/six/border
	icon_state = "black1"
/area/caribbean/no_mans_land/battleroyale/six/border/inside
	icon_state = "black1"
	location = AREA_INSIDE

/area/caribbean/no_mans_land/capturable
	base_turf = /turf/floor/dirt/burned
	icon_state = "red4"
	location = AREA_INSIDE

/area/caribbean/no_mans_land/capturable/one
	name = "Capture Area 1"
/area/caribbean/no_mans_land/capturable/one/outside
	location = AREA_OUTSIDE

/area/caribbean/no_mans_land/capturable/two
	name = "Capture Area 2"
/area/caribbean/no_mans_land/capturable/two/outside
	location = AREA_OUTSIDE

/area/caribbean/no_mans_land/capturable/three
	name = "Capture Area 3"
/area/caribbean/no_mans_land/capturable/three/outside
	location = AREA_OUTSIDE

/area/caribbean/no_mans_land/capturable/four
	name = "Capture Area 4"
/area/caribbean/no_mans_land/capturable/four/outside
	location = AREA_OUTSIDE

/area/caribbean/no_mans_land/capturable/five
	name = "Capture Area 5"
/area/caribbean/no_mans_land/capturable/five/outside
	location = AREA_OUTSIDE

/area/caribbean/no_mans_land/tundra
	name = "No Man's Land"
	icon_state = "purple1"
	climate = "tundra"
	base_turf = /turf/floor/dirt/winter
/area/caribbean/no_mans_land/taiga
	name = "No Man's Land"
	icon_state = "purple1"
	climate = "taiga"
	base_turf = /turf/floor/dirt/winter
/area/caribbean/no_mans_land/temperate
	name = "No Man's Land"
	icon_state = "purple1"
	climate = "temperate"
	base_turf = /turf/floor/dirt

/area/caribbean/no_mans_land/temperate/two
	name = "No Man's Land 2"
	icon_state = "purple2"
	climate = "temperate"
	base_turf = /turf/floor/dirt

/area/caribbean/no_mans_land/temperate/three
	name = "No Man's Land 3"
	icon_state = "blue3"
	climate = "temperate"
	base_turf = /turf/floor/dirt

/area/caribbean/no_mans_land/temperate/four
	name = "No Man's Land 4"
	icon_state = "red4"
	climate = "temperate"
	base_turf = /turf/floor/dirt

/area/caribbean/no_mans_land/temperate/five
	name = "No Man's Land 5"
	icon_state = "green5"
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
	name = "grace wall"
	icon_state = "green5"
/area/caribbean/no_mans_land/invisible_wall/not_dynamic
	dynamic_lighting = FALSE

/area/caribbean/no_mans_land/invisible_wall/tundra
	name = "grace wall"
	climate = "tundra"
	base_turf = /turf/floor/dirt/winter
	icon_state = "purple1"

/area/caribbean/no_mans_land/invisible_wall/tundra/one
	name = "grace wall 1"

/area/caribbean/no_mans_land/invisible_wall/tundra/two
	name = "grace wall 2"

/area/caribbean/no_mans_land/invisible_wall/tundra/three
	name = "grace wall 3"

/area/caribbean/no_mans_land/invisible_wall/taiga
	climate = "taiga"
	base_turf = /turf/floor/dirt/winter
/area/caribbean/no_mans_land/invisible_wall/taiga/one
	icon_state = "green1"
	name = "I grace wall"
/area/caribbean/no_mans_land/invisible_wall/taiga/two
	icon_state = "green1"
	name = "II grace wall"
/area/caribbean/no_mans_land/invisible_wall/temperate
	climate = "temperate"
	base_turf = /turf/floor/dirt
/area/caribbean/no_mans_land/invisible_wall/temperate/one
	icon_state = "green1"
	name = "I grace wall"
/area/caribbean/no_mans_land/invisible_wall/temperate/two
	icon_state = "green1"
	name = "II grace wall"
/area/caribbean/no_mans_land/invisible_wall/desert
	climate = "desert"
	base_turf = /turf/floor/beach/sand/desert
/area/caribbean/no_mans_land/invisible_wall/desert/one
	name = "grace wall 1"

/area/caribbean/no_mans_land/invisible_wall/semiarid
	climate = "semiarid"
	base_turf = /turf/floor/dirt/dust
/area/caribbean/no_mans_land/invisible_wall/jungle
	climate = "jungle"
	base_turf = /turf/floor/dirt/jungledirt
/area/caribbean/no_mans_land/invisible_wall/jungle/one
	climate = "jungle"
	base_turf = /turf/floor/dirt
/area/caribbean/no_mans_land/invisible_wall/jungle/two
	climate = "jungle"
	base_turf = /turf/floor/dirt
/area/caribbean/no_mans_land/invisible_wall/jungle/three
	climate = "jungle"
	base_turf = /turf/floor/dirt
/area/caribbean/no_mans_land/invisible_wall/sea
	climate = "sea"
	base_turf = /turf/floor/beach/water/deep/saltwater

/area/caribbean/no_mans_land/invisible_wall/sea/temperate
	climate = "temperate"

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

/area/caribbean/no_mans_land/invisible_wall/inside/one
	icon_state = "green1"
	name = "I grace wall"
/area/caribbean/no_mans_land/invisible_wall/inside/two
	icon_state = "green1"
	name = "II grace wall"
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

/area/caribbean/forest/one
/area/caribbean/forest/two

/area/caribbean/forest/cobbleroad
	name = "Road"
	icon_state = "purple2"
	base_turf = /turf/floor/plating/cobblestone

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

/area/caribbean/supply/russian
	name = "Russian Supply Arrival"

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
	base_turf = /turf/floor
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
	base_turf = /turf/floor/dirt/jungledirt
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
	base_turf = /turf/floor/plating
	artillery_integrity = INFINITY

/area/caribbean/russian/land/inside/command
	location = AREA_INSIDE
	icon_state = "red2"


/area/caribbean/russian/land/outside
	icon_state = "red3"
/area/caribbean/russian/land/outside/tundra
	climate = "tundra"

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
	base_turf = /turf/floor/plating

/area/caribbean/german/inside/roof
	location = AREA_OUTSIDE
	icon_state = "blue1"
/area/caribbean/german/inside/roof/objective
	icon_state = "blue2"
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

/area/caribbean/pirates/ship/voyage
	name = "Ship"
	base_turf = /turf/floor/beach/water/deep/saltwater
	location = AREA_OUTSIDE

/area/caribbean/pirates/ship/voyage/upper
	base_turf =/turf/floor/broken_floor

/area/caribbean/pirates/ship/voyage/upper/inside
	base_turf =/turf/floor/broken_floor
	location = AREA_INSIDE

/area/caribbean/pirates/ship/voyage/upper/inside/treasury
	name = "Treasury Room"
	icon_state = "green4"

/area/caribbean/pirates/ship/voyage/lower
	base_turf =/turf/floor/beach/water/deep/saltwater
	location = AREA_INSIDE

/area/caribbean/pirates/ship/voyage/lower/storage
	name = "Storage Area"
	icon_state = "green3"

/area/caribbean/pirates/ship/voyage/lower/storage/kitchen
	name = "Kitchen Storage Area"

/area/caribbean/pirates/ship/voyage/lower/storage/magazine
	name = "Magazine"

/area/caribbean/indians
	name = "Natives"

/area/caribbean/indians/camp
	name = "Native Camp"
	icon_state = "red1"
	base_turf = /turf/floor/dirt
	ambience = list("sound/ambience/jungle1.ogg")
	climate = "jungle"

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

/area/caribbean/football
	name = "Football Field"
	icon_state = "green1"
	climate = "temperate"
	ambience = list("sound/ambience/football.ogg")
/area/caribbean/football/red
	name = "Football Field"
	icon_state = "red1"

/area/caribbean/football/red/score
	name = "Football Field"
	icon_state = "red2"

/area/caribbean/football/red/goalkeeper
	name = "Football Field"
	icon_state = "red3"

/area/caribbean/football/blue
	name = "Football Field"
	icon_state = "blue2"

/area/caribbean/football/blue/goalkeeper
	name = "Football Field"
	icon_state = "blue1"

/area/caribbean/football/blue/score
	name = "Football Field"
	icon_state = "blue3"

/area/caribbean/football/midfield
	icon_state = "green1"

/area/caribbean/football/nopass
	icon_state = "green1"


/area/caribbean/space
	has_gravity = FALSE
	no_air = TRUE
	base_turf = /turf/floor/space //The base turf type of the area, which can be used to override the z-level's base turf
	sound_env = FOREST
	icon_state = "blue1"
	dynamic_lighting = TRUE
	climate = "tundra"
	location = AREA_OUTSIDE
	ambience = list()