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
	if (istype(src, /area/prishtina/british))
		name = "(British) [name]"
	else if (istype(src, /area/prishtina/pirates))
		name = "(Pirates) [name]"
// Basic Area Definitions

/* note: BYOND reaches some kind of limit when it encounters areas with massive
 * contents lists (around 30,000 - 65,000 maybe), causing any movement in those areas
 * to slow down dramatically. The forest area reached this limit, but only
 * when there were snow objects, so its been split into 9 separate areas.
*/
/area/prishtina/sea
	name = "Island"
	base_turf = /turf/floor/plating/beach/sand
	icon_state = "purple1"

/area/prishtina/sea/beach
	name = "Beach"
	base_turf = /turf/floor/plating/beach/sand
	icon_state = "red4"

/area/prishtina/sea/shallow
	name = "Shallow Water"
	base_turf = /turf/floor/plating/beach/water
	icon_state = "blue1"

/area/prishtina/sea/sea
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


/area/prishtina/forest
	name = "The Forest"
	icon_state = "purple1"

/area/prishtina/forest/north/invisible_wall
	dynamic_lighting = TRUE

/area/prishtina/forest/north/invisible_wall/train
	dynamic_lighting = FALSE

/area/prishtina/forest/south/invisible_wall
/area/prishtina/forest/south/invisible_wall2



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


// end of wormhole areas

// british areas

/area/prishtina/british

/area/prishtina/british/main_area
	name = "Base"
	icon_state = "red1"

/area/prishtina/british/main_area/inside
	location = AREA_INSIDE
	icon_state = "red2"

/area/prishtina/british/main_area/sector1
/area/prishtina/british/main_area/sector2
/area/prishtina/british/main_area/sector3


/area/prishtina/british/outside

/area/prishtina/british/outside/indoors
	location = AREA_INSIDE


/area/prishtina/british/resting_area_1
	name = "Resting Area #1"
	icon_state = "green1"
	location = AREA_INSIDE

/area/prishtina/british/resting_area_2
	name = "Resting Area #2"
	icon_state = "green2"
	location = AREA_INSIDE

/area/prishtina/british/resting_area_3
	name = "Resting Area #3"
	icon_state = "green3"
	location = AREA_INSIDE

/area/prishtina/british/resting_area_4
	name = "Resting Area #4"
	icon_state = "green4"
	location = AREA_INSIDE

/area/prishtina/british/gearing
	name = "Cargo"
	icon_state = "blue1"
	location = AREA_INSIDE

/area/prishtina/british/armory
	name = "Armory"
	icon_state = "blue2"
	location = AREA_INSIDE


/area/prishtina/british/armory/room1
	icon_state = "green1"
	location = AREA_INSIDE

/area/prishtina/british/armory/room2
	icon_state = "green2"
	location = AREA_INSIDE

/area/prishtina/british/armory/room3
	icon_state = "green3"
	location = AREA_INSIDE

/area/prishtina/british/mparea
	name = "MP Area"
	icon_state = "green1"
	location = AREA_INSIDE

/area/prishtina/british/prison
	name = "Prison"
	icon_state = "green2"
	capturable = FALSE
	location = AREA_INSIDE


/area/prishtina/british/cafeteria
	name = "Cafeteria"
	icon_state = "blue4"
	location = AREA_INSIDE

/area/prishtina/british/kitchen
	name = "Kitchen"
	icon_state = "blue5"
	location = AREA_INSIDE

/area/prishtina/british/kitchen/storage
	name = "Kitchen Storage"
	icon_state = "blue4"

/area/prishtina/british/command
	name = "Command"
	icon_state = "green1"
	location = AREA_INSIDE

/area/prishtina/british/command/office
	name = "Hauptmann's Office"
	icon_state = "green2"
	location = AREA_INSIDE

// pirates areas

/area/prishtina/pirates
	name = "pirates"

/area/prishtina/pirates/bunker_entrance
	name = "Bunker Entrance"
	icon_state = "red2"
	location = AREA_INSIDE
	artillery_integrity = 200

/area/prishtina/pirates/immediate_outside_defenses
	name = "Bunker Defenses"
	icon_state = "red3"

/area/prishtina/pirates/dogshed
	name = "Dog Shed"
	icon_state = "blue1"
	location = AREA_INSIDE

/area/prishtina/pirates/immediate_outside_defenses/houses
	icon_state = "blue2"
	location = AREA_INSIDE

/area/prishtina/pirates/forward_defenses
	name = "Bunker Defenses"
	icon_state = "blue3"

/area/prishtina/pirates/forward_defenses/inside
	location = AREA_INSIDE
	icon_state = "blue4"
// bunker areas

/area/prishtina/pirates/bunker
	name = "Bunker"
	location = AREA_INSIDE
	artillery_integrity = 200


