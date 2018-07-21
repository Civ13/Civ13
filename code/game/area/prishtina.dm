/area/prishtina
	requires_power = FALSE
	has_gravity = TRUE
	no_air = FALSE
	base_turf = /turf/floor/plating/grass/wild //The base turf type of the area, which can be used to override the z-level's base turf
	sound_env = STANDARD_STATION
	icon_state = "purple1"
	dynamic_lighting = TRUE

/area/prishtina/New()
	..()
	if (istype(src, /area/prishtina/german))
		name = "(Axis) [name]"
	else if (istype(src, /area/prishtina/soviet))
		name = "(Allies) [name]"
	else if (istype(src, /area/prishtina/void/sky/paratrooper_drop_zone))
		name = "(Sky) [name]"
	else if (!istype(src, /area/prishtina/void/sky))
		name = "(Civilian) [name]"

// Basic Area Definitions

/* note: BYOND reaches some kind of limit when it encounters areas with massive
 * contents lists (around 30,000 - 65,000 maybe), causing any movement in those areas
 * to slow down dramatically. The forest area reached this limit, but only
 * when there were snow objects, so its been split into 9 separate areas.
*/
/area/prishtina/island
	name = "Island"
	base_turf = /turf/floor/plating/beach/sand
	icon_state = "purple1"

/area/prishtina/island/beach
	name = "Beach"
	base_turf = /turf/floor/plating/beach/sand
	icon_state = "red4"

/area/prishtina/island/shallow
	name = "Shallow Water"
	base_turf = /turf/floor/plating/beach/water
	icon_state = "blue1"

/area/prishtina/island/sea
	name = "Sea"
	base_turf = /turf/floor/plating/beach/water/deep
	icon_state = "blue2"

/area/prishtina/no_mans_land
	name = "No Man's Land"
	icon_state = "purple1"

/area/prishtina/no_mans_land/invisible_wall
	icon_state = "green1"

/area/prishtina/no_mans_land/invisible_wall/inside
	location = AREA_INSIDE

/area/prishtina/no_mans_land/sector1
	name = "Northwestern Town"
/area/prishtina/no_mans_land/sector1/ss1
/area/prishtina/no_mans_land/sector1/ss2
/area/prishtina/no_mans_land/sector1/ss3
/area/prishtina/no_mans_land/sector1/ss4

/area/prishtina/no_mans_land/sector2
	name = "Northern Town"
/area/prishtina/no_mans_land/sector2/ss1
/area/prishtina/no_mans_land/sector2/ss2
/area/prishtina/no_mans_land/sector2/ss3
/area/prishtina/no_mans_land/sector2/ss4

/area/prishtina/no_mans_land/sector3
	name = "Northeastern Town"
/area/prishtina/no_mans_land/sector3/ss1
/area/prishtina/no_mans_land/sector3/ss2
/area/prishtina/no_mans_land/sector3/ss3
/area/prishtina/no_mans_land/sector3/ss4

/area/prishtina/no_mans_land/sector4
	name = "Western Town"
/area/prishtina/no_mans_land/sector4/ss1
/area/prishtina/no_mans_land/sector4/ss2
/area/prishtina/no_mans_land/sector4/ss3
/area/prishtina/no_mans_land/sector4/ss4

/area/prishtina/no_mans_land/sector5
	name = "Central Town"
/area/prishtina/no_mans_land/sector5/ss1
/area/prishtina/no_mans_land/sector5/ss2
/area/prishtina/no_mans_land/sector5/ss3
/area/prishtina/no_mans_land/sector5/ss4

/area/prishtina/no_mans_land/sector6
	name = "Eastern Town"
/area/prishtina/no_mans_land/sector6/ss1
/area/prishtina/no_mans_land/sector6/ss2
/area/prishtina/no_mans_land/sector6/ss3
/area/prishtina/no_mans_land/sector6/ss4

/area/prishtina/no_mans_land/sector7
	name = "Southwestern Town"
/area/prishtina/no_mans_land/sector7/ss1
/area/prishtina/no_mans_land/sector7/ss2
/area/prishtina/no_mans_land/sector7/ss3
/area/prishtina/no_mans_land/sector7/ss4

/area/prishtina/no_mans_land/sector8
	name = "Southern Town"
/area/prishtina/no_mans_land/sector8/ss1
/area/prishtina/no_mans_land/sector8/ss2
/area/prishtina/no_mans_land/sector8/ss3
/area/prishtina/no_mans_land/sector8/ss4

/area/prishtina/no_mans_land/sector9
	name = "Southeastern Town"
/area/prishtina/no_mans_land/sector9/ss1
/area/prishtina/no_mans_land/sector9/ss2
/area/prishtina/no_mans_land/sector9/ss3
/area/prishtina/no_mans_land/sector9/ss4

/area/prishtina/forest
	name = "The Forest"
	icon_state = "purple1"

/area/prishtina/forest/north/invisible_wall
	dynamic_lighting = TRUE

/area/prishtina/forest/north/invisible_wall/train
	dynamic_lighting = FALSE

/area/prishtina/forest/south/invisible_wall
/area/prishtina/forest/south/invisible_wall2

/* sector 1 = top left, sector 2 = top center, sector 3 = top right
   sector 4 = middle left, sector 5 = middle center, sector 6 = middle right
   sector 7 = bottom left, sector 8 = bottom center, sector 9 = bottom right */

/area/prishtina/forest/sector1
	name = "Northwestern Forest"
/area/prishtina/forest/sector1/ss1
/area/prishtina/forest/sector1/ss2
/area/prishtina/forest/sector1/ss3
/area/prishtina/forest/sector1/ss4

/area/prishtina/forest/sector2
	name = "Northern Forest"
/area/prishtina/forest/sector2/ss1
/area/prishtina/forest/sector2/ss2
/area/prishtina/forest/sector2/ss3
/area/prishtina/forest/sector2/ss4

/area/prishtina/forest/sector3
	name = "Northeastern Forest"
/area/prishtina/forest/sector3/ss1
/area/prishtina/forest/sector3/ss2
/area/prishtina/forest/sector3/ss3
/area/prishtina/forest/sector3/ss4

/area/prishtina/forest/sector4
	name = "Western Forest"
/area/prishtina/forest/sector4/ss1
/area/prishtina/forest/sector4/ss2
/area/prishtina/forest/sector4/ss3
/area/prishtina/forest/sector4/ss4

/area/prishtina/forest/sector5
	name = "Central Forest"
/area/prishtina/forest/sector5/ss1
/area/prishtina/forest/sector5/ss2
/area/prishtina/forest/sector5/ss3
/area/prishtina/forest/sector5/ss4

/area/prishtina/forest/sector6
	name = "Eastern Forest"
/area/prishtina/forest/sector6/ss1
/area/prishtina/forest/sector6/ss2
/area/prishtina/forest/sector6/ss3
/area/prishtina/forest/sector6/ss4

/area/prishtina/forest/sector7
	name = "Southwestern Forest"
/area/prishtina/forest/sector7/ss1
/area/prishtina/forest/sector7/ss2
/area/prishtina/forest/sector7/ss3
/area/prishtina/forest/sector7/ss4

/area/prishtina/forest/sector8
	name = "Southern Forest"
/area/prishtina/forest/sector8/ss1
/area/prishtina/forest/sector8/ss2
/area/prishtina/forest/sector8/ss3
/area/prishtina/forest/sector8/ss4

/area/prishtina/forest/sector9
	name = "Southeastern Forest"
/area/prishtina/forest/sector9/ss1
/area/prishtina/forest/sector9/ss2
/area/prishtina/forest/sector9/ss3
/area/prishtina/forest/sector9/ss4

/area/prishtina/farm1
	name = "Farmland"
	icon_state = "red3"

/area/prishtina/farm2
	name = "Farmland"
	icon_state = "red3"

/area/prishtina/farm3
	name = "Farmland"
	icon_state = "red3"

/area/prishtina/farm4
	name = "Farmland"
	icon_state = "red3"

// admin zone

/area/prishtina/admin
	icon_state = "purple1"
	name = "Admin Zone"
	location = AREA_INSIDE
	artillery_integrity = INFINITY

/area/prishtina/admin/tonkland
	name = "Tonk Zone"
	location = AREA_INSIDE

// houses in No Man's Land

/area/prishtina/houses
	name = "\improper Houses"
	icon_state = "red1"
	location = AREA_INSIDE

/area/prishtina/houses/nml_one
/area/prishtina/houses/nml_two
/area/prishtina/houses/nml_three
/area/prishtina/houses/nml_four
/area/prishtina/houses/nml_five
/area/prishtina/houses/nml_six
/area/prishtina/houses/nml_seven
/area/prishtina/houses/nml_eight
/area/prishtina/houses/nml_nine
/area/prishtina/houses/nml_ten
/area/prishtina/houses/nml_eleven
/area/prishtina/houses/nml_twelve
/area/prishtina/houses/nml_thirteen
/area/prishtina/houses/nml_fourteen
/area/prishtina/houses/nml_fifteen
/area/prishtina/houses/nml_sixteen
/area/prishtina/houses/nml_seventeen
/area/prishtina/houses/nml_eighteen
/area/prishtina/houses/nml_nineteen
/area/prishtina/houses/nml_twenty
/area/prishtina/houses/nml_twentyone
/area/prishtina/houses/nml_bunker
	artillery_integrity = 200

/area/prishtina/houses/sov_one
/area/prishtina/houses/sov_two
/area/prishtina/houses/sov_three
/area/prishtina/houses/sov_four
/area/prishtina/houses/sov_five
/area/prishtina/houses/sov_six
/area/prishtina/houses/sov_seven
/area/prishtina/houses/sov_eight
/area/prishtina/houses/sov_nine
/area/prishtina/houses/sov_ten
/area/prishtina/houses/sov_eleven
/area/prishtina/houses/sov_twelve
/area/prishtina/houses/sov_thirteen
/area/prishtina/houses/sov_fourteen

/area/prishtina/houses/ger_one
/area/prishtina/houses/ger_two
/area/prishtina/houses/ger_three
/area/prishtina/houses/ger_four
/area/prishtina/houses/ger_five
/area/prishtina/houses/ger_six
/area/prishtina/houses/ger_seven
/area/prishtina/houses/ger_eight
/area/prishtina/houses/ger_nine
/area/prishtina/houses/ger_ten
/area/prishtina/houses/ger_eleven
/area/prishtina/houses/ger_twelve
/area/prishtina/houses/ger_thirteen
/area/prishtina/houses/ger_fourteen

/area/prishtina/sewers
	artillery_integrity = INFINITY
	dynamic_lighting = FALSE
	location = AREA_INSIDE

// "wormhole" areas: doesn't include trains since they don't get their area copied

// where all this stuff is

/area/prishtina/void
	icon_state = "purple1"
	name = "the void"
	location = AREA_INSIDE
	is_void_area = TRUE

/area/prishtina/void/caves
	icon_state = "blue1"
	name = "the caves"
	location = AREA_INSIDE

/area/prishtina/void/german
	icon_state = "red1"
	name = "what the fuck is this"

/area/prishtina/void/german/ss_train
	icon_state = "red2"
	name = "Train"
	location = AREA_INSIDE

/area/prishtina/void/german/ss_train/entrance
	icon_state = "red3"
	name = "Train Entrance Room"

/area/prishtina/void/german/ss_train/command
	icon_state = "red4"
	name = "Train Command Room"

/area/prishtina/void/german/ss_train/command/office
	icon_state = "red5"
	name = "Train Command Office"

/area/prishtina/void/german/ss_train/prison
	icon_state = "blue1"
	name = "Train Prison"

/area/prishtina/void/german/ss_train/prison/cell1
	icon_state = "blue2"
	name = "Train Prison Cell #1"

/area/prishtina/void/german/ss_train/prison/cell2
	icon_state = "blue3"
	name = "Train Prison Cell #2"

/area/prishtina/void/german/ss_train/prison/cell3
	icon_state = "blue4"
	name = "Train Prison Cell #3"

/area/prishtina/void/german/ss_train/prison/cell4
	icon_state = "blue5"
	name = "Train Prison Cell #4"

/area/prishtina/void/german/ss_train/gas_chamber
	icon_state = "blue1"
	name = "Train Gas Chamber"

/area/prishtina/void/german/ss_train/gas_chamber/gas_room
	icon_state = "blue2"
	name = "Train Gas Room"

/area/prishtina/void/skybox
	icon_state = "purple1"
	name = "The Sky"
	dynamic_lighting = FALSE

/area/prishtina/void/skybox/one
/area/prishtina/void/skybox/two
/area/prishtina/void/skybox/three
/area/prishtina/void/skybox/four
/area/prishtina/void/skybox/five
/area/prishtina/void/skybox/six
/area/prishtina/void/skybox/seven

/area/prishtina/void/sky
	icon_state = "purple1"
	name = "The Sky"
	dynamic_lighting = FALSE
	var/corresponding_area_type = null
	var/corresponding_area_allow_subtypes = FALSE

/area/prishtina/void/sky/paratrooper_drop_zone
	corresponding_area_type = /area/prishtina/forest
	corresponding_area_allow_subtypes = TRUE
	name = "The Sky"

/area/prishtina/void/sky/paratrooper_drop_zone/plane
	corresponding_area_type = /area/prishtina/forest
	corresponding_area_allow_subtypes = TRUE
	name = "Fallschirmjager Plane"

/area/prishtina/void/civilian_second_floors
/area/prishtina/void/civilian_second_floors/house1
/area/prishtina/void/civilian_second_floors/house2
/area/prishtina/void/civilian_second_floors/house3
/area/prishtina/void/civilian_second_floors/house4
/area/prishtina/void/civilian_second_floors/outside
	dynamic_lighting = FALSE

/area/prishtina/void/civilian_basements
/area/prishtina/void/civilian_basements/house1
	parent_area_type = /area/prishtina/houses/sov_three
/area/prishtina/void/civilian_basements/house2
	parent_area_type = /area/prishtina/houses/sov_thirteen
/area/prishtina/void/civilian_basements/house3
	parent_area_type = /area/prishtina/houses/nml_two


// end of wormhole areas

// german areas

/area/prishtina/german

/area/prishtina/german/main_area
	name = "Base"
	icon_state = "red1"

/area/prishtina/german/main_area/inside
	location = AREA_INSIDE
	icon_state = "red2"

/area/prishtina/german/main_area/sector1
/area/prishtina/german/main_area/sector2
/area/prishtina/german/main_area/sector3

/area/prishtina/german/main_area/dogshed
	name = "Dogshed"
	icon_state = "red2"
	location = AREA_INSIDE

/area/prishtina/german/outside

/area/prishtina/german/outside/indoors
	location = AREA_INSIDE

/area/prishtina/german/gas_chamber
	name = "Gas Chamber"
	icon_state = "red3"

/area/prishtina/german/resting_area_1
	name = "Resting Area #1"
	icon_state = "green1"
	location = AREA_INSIDE

/area/prishtina/german/resting_area_2
	name = "Resting Area #2"
	icon_state = "green2"
	location = AREA_INSIDE

/area/prishtina/german/resting_area_3
	name = "Resting Area #3"
	icon_state = "green3"
	location = AREA_INSIDE

/area/prishtina/german/resting_area_4
	name = "Resting Area #4"
	icon_state = "green4"
	location = AREA_INSIDE

/area/prishtina/german/gearing
	name = "Cargo"
	icon_state = "blue1"
	location = AREA_INSIDE

/area/prishtina/german/armory
	name = "Armory"
	icon_state = "blue2"
	location = AREA_INSIDE

/area/prishtina/german/armory/supplydrop
	name = "Supplydrop Pad"
	icon_state = "blue3"
	location = AREA_OUTSIDE

/area/prishtina/german/armory/room1
	icon_state = "green1"
	location = AREA_INSIDE

/area/prishtina/german/armory/room2
	icon_state = "green2"
	location = AREA_INSIDE

/area/prishtina/german/armory/room3
	icon_state = "green3"
	location = AREA_INSIDE

/area/prishtina/german/mparea
	name = "MP Area"
	icon_state = "green1"
	location = AREA_INSIDE

/area/prishtina/german/prison
	name = "Prison"
	icon_state = "green2"
	capturable = FALSE
	location = AREA_INSIDE


/area/prishtina/german/cafeteria
	name = "Cafeteria"
	icon_state = "blue4"
	location = AREA_INSIDE

/area/prishtina/german/kitchen
	name = "Kitchen"
	icon_state = "blue5"
	location = AREA_INSIDE

/area/prishtina/german/kitchen/storage
	name = "Kitchen Storage"
	icon_state = "blue4"

/area/prishtina/german/kitchen/cellar
	name = "Kitchen Cellar"
	icon_state = "blue3"
	location = AREA_INSIDE
	parent_area_type = /area/prishtina/german/kitchen/storage
	is_void_area = TRUE
	capturable = FALSE

/area/prishtina/german/shower1
	name = "Showers #1"
	icon_state = "red2"
	location = AREA_INSIDE

/area/prishtina/german/shower2
	name = "Showers #2"
	icon_state = "red2"
	location = AREA_INSIDE

/area/prishtina/german/shower3
	name = "Showers #3"
	icon_state = "red2"
	location = AREA_INSIDE

/area/prishtina/german/drying1
	name = "Drying Room #1"
	icon_state = "blue2"
	location = AREA_INSIDE

/area/prishtina/german/drying2
	name = "Drying Room #2"
	icon_state = "blue2"
	location = AREA_INSIDE

/area/prishtina/german/drying3
	name = "Drying Room #3"
	icon_state = "blue2"
	location = AREA_INSIDE

/area/prishtina/german/ss_torture_room
	name = "Interrogation Room" // "Interrogation"
	icon_state = "blue1"
	location = AREA_INSIDE

/area/prishtina/german/ss_torture_room/tools
	name = "Interrogation Room Tools"
	icon_state = "blue2"
	location = AREA_INSIDE

/area/prishtina/german/ss_torture_room/cell1
	name = "Interrogation Room Cell #1"
	icon_state = "blue3"
	location = AREA_INSIDE
	capturable = FALSE

/area/prishtina/german/ss_torture_room/cell2
	name = "Interrogation Room Cell #2"
	icon_state = "blue4"
	location = AREA_INSIDE
	capturable = FALSE

/area/prishtina/german/command
	name = "Command"
	icon_state = "green1"
	location = AREA_INSIDE

/area/prishtina/german/command/office
	name = "Hauptmann's Office"
	icon_state = "green2"
	location = AREA_INSIDE

/area/prishtina/german/briefing
	name = "Briefing"
	icon_state = "green1"

/area/prishtina/german/base_defenses
	name = "Base Defenses"
	icon_state = "green2"
	capturable = FALSE

// prevents snowing on some walls
/area/prishtina/german/base_defenses/wall
	location = AREA_INSIDE

/area/prishtina/german/engineering
	name = "Engineering"
	icon_state = "blue1"
	location = AREA_INSIDE

/area/prishtina/german/ss_armory
	name = "SS Armory"
	icon_state = "green1"
	location = AREA_INSIDE
	is_void_area = TRUE
	capturable = FALSE

/area/prishtina/german/ss_prison
	name = "SS Prison"
	icon_state = "green2"
	location = AREA_INSIDE
	capturable = FALSE

/area/prishtina/german/janitor
	name = "Janitor's Closet"
	icon_state = "blue2"
	location = AREA_INSIDE

/area/prishtina/german/medical
	name = "Medical Area"
	icon_state = "blue3"
	location = AREA_INSIDE

/area/prishtina/german/medical/storage
	name = "Medical Storage"
	icon_state = "blue4"

/area/prishtina/german/medical/hallway
	name = "Medical Hallway"
	icon_state = "blue5"

/area/prishtina/german/medical/surgery1
	name = "Surgery Room #1"
	icon_state = "blue1"

/area/prishtina/german/medical/surgery2
	name = "Surgery Room #2"
	icon_state = "blue2"

/area/prishtina/german/medical/chemistry
	name = "Chemistry Room"
	icon_state = "blue3"

/area/prishtina/german/medical/morgue
	name = "Morgue"
	icon_state = "blue4"
	parent_area_type = /area/prishtina/german/medical/hallway
	is_void_area = TRUE
	capturable = FALSE

// special german areas

/area/prishtina/german/bunker
	name = "Bunker"
	location = AREA_INSIDE
	base_turf = /turf/floor/dirt
	artillery_integrity = 200

/area/prishtina/german/lift
	name = "Lift"
	location = AREA_INSIDE

/area/prishtina/german/lift/up
	name = "Upper Lift"

/area/prishtina/german/lift/down
	name = "Lower Lift"

// italian areas
/area/prishtina/italian_base
	name = "Italian Base"
	icon_state = "green3"
	location = AREA_INSIDE

// soviet areas

/area/prishtina/soviet
	name = "soviet"

// for the small map

/area/prishtina/soviet/small_map/main_area
	name = "Main Area"
	icon_state = "blue1"

/area/prishtina/soviet/small_map/inside
	name = "Inside Area"
	icon_state = "red2"
	location = AREA_INSIDE

/area/prishtina/soviet/small_map/inside/armory
	name = "Armory"
	icon_state = "red3"

/area/prishtina/soviet/small_map/inside/engineering
	name = "Engineering Area"
	icon_state = "red3"

/area/prishtina/soviet/small_map/inside/resting_area
	name = "Resting Area"
	icon_state = "red4"

/area/prishtina/soviet/small_map/inside/gearing
	name = "Gearing Up Area"
	icon_state = "red5"

/area/prishtina/soviet/small_map/inside/relaxation
	name = "Relaxation Area"
	icon_state = "red5"

/area/prishtina/soviet/small_map/inside/kitchen
	name = "Kitchen"
	icon_state = "blue1"

/area/prishtina/soviet/small_map/inside/kitchen/cellar
	name = "Kitchen Cellar"
	icon_state = "blue2"
	is_void_area = TRUE
	capturable = FALSE

/area/prishtina/soviet/small_map/inside/commander_bedroom
	name = "Kapitan's Office"
	icon_state = "blue1"

/area/prishtina/soviet/small_map/inside/command_post
	name = "Soviet Command Post"
	icon_state = "blue3"
	capturable = FALSE

/area/prishtina/soviet/small_map/inside/command_post/storage
	name = "Soviet Command Post Storage"
	icon_state = "blue3"

/area/prishtina/soviet/small_map/inside/medical
	name = "Medical Main Area"
	icon_state = "blue2"
	capturable = FALSE

/area/prishtina/soviet/small_map/inside/medical/storage
	name = "Medical Storage"

/area/prishtina/soviet/small_map/inside/medical/chemistry
	name = "Chemistry Room"
	icon_state = "blue3"

/area/prishtina/soviet/small_map/inside/medical/hallway
	name = "Medical Hallway"
	icon_state = "blue4"

/area/prishtina/soviet/small_map/inside/medical/surgery1
	name = "Surgery Room #1"
	icon_state = "blue5"

/area/prishtina/soviet/small_map/inside/medical/surgery2
	name = "Surgery Room #2"
	icon_state = "blue4"

/area/prishtina/soviet/small_map/inside/medical/morgue
	name = "Morgue"
	icon_state = "blue5"
	parent_area_type = /area/prishtina/soviet/small_map/inside/medical/hallway
	is_void_area = TRUE
	capturable = FALSE

/area/prishtina/soviet/small_map/inside/mparea
	name = "MP Area"
	icon_state = "green1"

/area/prishtina/soviet/small_map/inside/prison
	name = "Prison"
	icon_state = "green2"
	is_void_area = TRUE
	parent_area_type = /area/prishtina/soviet/small_map/inside/mparea
	capturable = FALSE

/area/prishtina/soviet/small_map/main_area/supplypad
	name = "Supply Pad"
	icon_state = "green2"

/area/prishtina/soviet/small_map/soviet_command_center
	name = "Soviet Command Center"
	is_void_area = TRUE
	location = AREA_INSIDE
	parent_area_type = /area/prishtina/soviet/small_map/inside/armory

/area/prishtina/soviet/small_map/briefing
	icon_state = "green3"
	name = "Briefing"
	location = AREA_OUTSIDE
// for the large map

/area/prishtina/soviet/bunker_entrance
	name = "Bunker Entrance"
	icon_state = "red2"
	location = AREA_INSIDE
	artillery_integrity = 200

/area/prishtina/soviet/immediate_outside_defenses
	name = "Bunker Defenses"
	icon_state = "red3"

/area/prishtina/soviet/dogshed
	name = "Dog Shed"
	icon_state = "blue1"
	location = AREA_INSIDE

/area/prishtina/soviet/immediate_outside_defenses/houses
	icon_state = "blue2"
	location = AREA_INSIDE

/area/prishtina/soviet/forward_defenses
	name = "Bunker Defenses"
	icon_state = "blue3"

/area/prishtina/soviet/forward_defenses/inside
	location = AREA_INSIDE
	icon_state = "blue4"
// bunker areas

/area/prishtina/soviet/bunker
	name = "Bunker"
	location = AREA_INSIDE
	artillery_integrity = 200

/area/prishtina/soviet/bunker/tunnel
	icon_state = "red2"
	name = "Bunker Tunnel"
	capturable = FALSE

/area/prishtina/soviet/bunker/entrance
	icon_state = "green1"
	name = "entrance"
	capturable = FALSE

/area/prishtina/soviet/bunker/main_hallway
	icon_state = "green2"
	name = "Bunker Main Hallway"

/area/prishtina/soviet/bunker/briefing
	icon_state = "green3"
	name = "Briefing"

/area/prishtina/soviet/bunker/cargo
	icon_state = "green4"
	name = "Cargo"

/area/prishtina/soviet/bunker/engineering
	icon_state = "green5"
	name = "Engineering"

/area/prishtina/soviet/bunker/medical
	icon_state = "blue1"
	name = "Medical Area"

/area/prishtina/soviet/bunker/janitor
	icon_state = "blue2"
	name = "Janitor's Closet"

/area/prishtina/soviet/bunker/command
	icon_state = "blue3"
	name = "Command"

/area/prishtina/soviet/bunker/command/office
	icon_state = "blue4"
	name = "Commandir's Office"

/area/prishtina/soviet/bunker/armory
	icon_state = "blue5"
	name = "Armory"

/area/prishtina/soviet/bunker/showers
	icon_state = "red1"
	name = "Showers"

/area/prishtina/soviet/bunker/cafeteria
	icon_state = "red2"
	name = "Cafeteria"

/area/prishtina/soviet/bunker/kitchen
	icon_state = "red3"
	name = "Kitchen"

/area/prishtina/soviet/bunker/resting_area
	icon_state = "red4"
	name = "Resting Area"

/area/prishtina/soviet/bunker/prison
	icon_state = "red5"
	name = "Prison"

/area/prishtina/soviet/bunker/prison/cell1
	icon_state = "red1"
	name = "Prison Cell #1"
	capturable = FALSE

/area/prishtina/soviet/bunker/prison/cell2
	icon_state = "red2"
	name = "Prison Cell #2"
	capturable = FALSE

/area/prishtina/soviet/backup_armory
	icon_state = "blue2"
	name = "Backup Armory"
	location = AREA_INSIDE

