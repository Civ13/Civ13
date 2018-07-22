/area/caribbean
	requires_power = FALSE
	has_gravity = TRUE
	no_air = FALSE
	base_turf = /turf/floor/plating/beach/water //The base turf type of the area, which can be used to override the z-level's base turf
	sound_env = STANDARD_STATION
	icon_state = "purple1"
	dynamic_lighting = TRUE

/area/caribbean/New()
	..()
	if (istype(src, /area/caribbean/british))
		name = "(British) [name]"
	else if (istype(src, /area/caribbean/pirates))
		name = "(Pirates) [name]"
// Basic Area Definitions

/* note: BYOND reaches some kind of limit when it encounters areas with massive
 * contents lists (around 30,000 - 65,000 maybe), causing any movement in those areas
 * to slow down dramatically. The forest area reached this limit, but only
 * when there were snow objects, so its been split into 9 separate areas.
*/
/area/caribbean/sea
	name = "Island"
	base_turf = /turf/floor/plating/beach/sand
	icon_state = "purple1"

/area/caribbean/sea/beach
	name = "Beach"
	base_turf = /turf/floor/plating/beach/sand
	icon_state = "red4"

/area/caribbean/sea/shallow
	name = "Shallow Water"
	base_turf = /turf/floor/plating/beach/water
	icon_state = "blue1"

/area/caribbean/sea/sea
	name = "Sea"
	base_turf = /turf/floor/plating/beach/water/deep
	icon_state = "blue2"

/area/caribbean/no_mans_land
	name = "No Man's Land"
	icon_state = "purple1"

/area/caribbean/no_mans_land/invisible_wall
	icon_state = "green1"

/area/caribbean/no_mans_land/invisible_wall/inside
	location = AREA_INSIDE


/area/caribbean/forest
	name = "The Forest"
	icon_state = "purple1"




/area/caribbean/farm
	name = "Farmland"
	icon_state = "red3"


// admin zone

/area/caribbean/admin
	icon_state = "purple1"
	name = "Admin Zone"
	location = AREA_INSIDE
	artillery_integrity = INFINITY


// houses in No Man's Land

/area/caribbean/houses
	name = "Houses"
	icon_state = "red1"
	location = AREA_INSIDE

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

/area/caribbean/void/caves
	icon_state = "blue1"
	name = "the caves"
	location = AREA_INSIDE


// end of wormhole areas

// british areas

/area/caribbean/british

/area/caribbean/british/land
	name = "Land Base"
	icon_state = "red1"

/area/caribbean/british/land/inside
	location = AREA_INSIDE
	icon_state = "red2"


/area/caribbean/british/land/outside
	icon_state = "red3"


/area/caribbean/british/ship
	icon_state = "blue1"

/area/caribbean/british/ship/main_deck
	name = "Main Deck"
	icon_state = "blue1"

/area/caribbean/british/ship/poop_deck
	name = "Poop Deck"
	icon_state = "blue2"

/area/caribbean/british/ship/upper_gun
	name = "Upper Gun Deck"
	icon_state = "blue3"
	location = AREA_INSIDE

/area/caribbean/british/ship/middle
	name = "Middle Deck"
	icon_state = "blue3"
	location = AREA_INSIDE

/area/caribbean/british/ship/lower
	name = "Lower Deck"
	icon_state = "blue3"
	location = AREA_INSIDE


/area/caribbean/british/ship/orlop
	name = "Orlop Deck"
	icon_state = "blue4"
	location = AREA_INSIDE

/area/caribbean/british/ship/hold
	name = "Hold"
	icon_state = "blue4"
	location = AREA_INSIDE

/area/caribbean/british/ship/galley
	name = "Prison"
	icon_state = "blue5"
	capturable = FALSE
	location = AREA_INSIDE


/area/caribbean/british/ship/kitchen
	name = "Kitchen"
	icon_state = "blue5"
	location = AREA_INSIDE


/area/caribbean/british/ship/office
	name = "Captain's Office"
	icon_state = "green5"
	location = AREA_INSIDE

// pirates areas

/area/caribbean/pirates
	name = "pirates"
/area/caribbean/pirates/land
	name = "Land Base"
	icon_state = "red1"

/area/caribbean/pirates/land/inside
	location = AREA_INSIDE
	icon_state = "red2"


/area/caribbean/pirates/land/outside
	icon_state = "red3"


/area/caribbean/pirates/ship
	icon_state = "green1"

/area/caribbean/pirates/ship/main_deck
	name = "Main Deck"
	icon_state = "green1"

/area/caribbean/pirates/ship/poop_deck
	name = "Poop Deck"
	icon_state = "green2"

/area/caribbean/pirates/ship/upper_gun
	name = "Upper Gun Deck"
	icon_state = "green3"
	location = AREA_INSIDE

/area/caribbean/pirates/ship/middle
	name = "Middle Deck"
	icon_state = "green3"
	location = AREA_INSIDE

/area/caribbean/pirates/ship/lower
	name = "Lower Deck"
	icon_state = "green3"
	location = AREA_INSIDE


/area/caribbean/pirates/ship/orlop
	name = "Orlop Deck"
	icon_state = "green4"
	location = AREA_INSIDE

/area/caribbean/pirates/ship/hold
	name = "Hold"
	icon_state = "green4"
	location = AREA_INSIDE

/area/caribbean/pirates/ship/galley
	name = "Prison"
	icon_state = "green5"
	capturable = FALSE
	location = AREA_INSIDE


/area/caribbean/pirates/ship/kitchen
	name = "Kitchen"
	icon_state = "green5"
	location = AREA_INSIDE


/area/caribbean/pirates/ship/office
	name = "Captain's Office"
	icon_state = "green5"
	location = AREA_INSIDE