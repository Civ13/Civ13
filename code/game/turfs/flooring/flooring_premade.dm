/turf/floor/carpet
	name = "carpet"
	icon = 'icons/turf/floors.dmi'
	icon_state = "carpet"
	initial_flooring = /decl/flooring/carpet

/turf/floor/carpet/bcarpet
	name = "black carpet"
	icon_state = "bcarpet"
	initial_flooring = /decl/flooring/carpet/bcarpet

/turf/floor/carpet/blucarpet
	name = "blue carpet"
	icon_state = "blucarpet"
	initial_flooring = /decl/flooring/carpet/blucarpet

/turf/floor/carpet/turcarpet
	name = "tur carpet"
	icon_state = "turcarpet"
	initial_flooring = /decl/flooring/carpet/turcarpet

/turf/floor/carpet/sblucarpet
	name = "sblue carpet"
	icon_state = "sblucarpet"
	initial_flooring = /decl/flooring/carpet/sblucarpet

/turf/floor/carpet/gaycarpet
	name = "clown carpet"
	icon_state = "gaycarpet"
	initial_flooring = /decl/flooring/carpet/gaycarpet

/turf/floor/carpet/purcarpet
	name = "purple carpet"
	icon_state = "purcarpet"
	initial_flooring = /decl/flooring/carpet/purcarpet

/turf/floor/carpet/oracarpet
	name = "orange carpet"
	icon_state = "oracarpet"
	initial_flooring = /decl/flooring/carpet/oracarpet

/turf/floor/bluegrid
	name = "mainframe floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "bcircuit"
	initial_flooring = /decl/flooring/reinforced/circuit

/turf/floor/greengrid
	name = "mainframe floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "gcircuit"
	initial_flooring = /decl/flooring/reinforced/circuit/green

/turf/floor/wood
	name = "wooden floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood"
	initial_flooring = /decl/flooring/wood

/turf/floor/grass
	name = "grass patch"
	icon = 'icons/turf/floors.dmi'
	icon_state = "grass0"
	initial_flooring = /decl/flooring/grass

/turf/floor/dirt
	name = "dirt"
	icon = 'icons/turf/floors.dmi'
	icon_state = "dirt"
	uses_winter_overlay = TRUE
	may_become_muddy = TRUE


/turf/floor/hull/New()
	if (icon_state != "hullcenter0")
		overrided_icon_state = icon_state
	..()

/turf/floor/tiled
	name = "floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "steel"
	initial_flooring = /decl/flooring/tiling

/turf/floor/tiled/techmaint
	name = "floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "techmaint"
	initial_flooring = /decl/flooring/tiling/new_tile/techmaint

/turf/floor/tiled/monofloor
	name = "floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "monofloor"
	initial_flooring = /decl/flooring/tiling/new_tile/monofloor

/turf/floor/tiled/techfloor
	name = "floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "techfloor_gray"
	initial_flooring = /decl/flooring/tiling/tech

/turf/floor/tiled/monotile
	name = "floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "monotile"
	initial_flooring = /decl/flooring/tiling/new_tile/monotile

/turf/floor/tiled/steel_grid
	name = "floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "steel_grid"
	initial_flooring = /decl/flooring/tiling/new_tile/steel_grid

/turf/floor/tiled/steel_ridged
	name = "floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "steel_ridged"
	initial_flooring = /decl/flooring/tiling/new_tile/steel_ridged

/turf/floor/tiled/old_tile
	name = "floor"
	icon_state = "tile_full"
	initial_flooring = /decl/flooring/tiling/new_tile
/turf/floor/tiled/old_tile/white
	color = "#d9d9d9"
/turf/floor/tiled/old_tile/blue
	color = "#8ba7ad"
/turf/floor/tiled/old_tile/yellow
	color = "#8c6d46"
/turf/floor/tiled/old_tile/gray
	color = "#687172"
/turf/floor/tiled/old_tile/beige
	color = "#385e60"
/turf/floor/tiled/old_tile/red
	color = "#964e51"
/turf/floor/tiled/old_tile/purple
	color = "#906987"
/turf/floor/tiled/old_tile/green
	color = "#46725c"



/turf/floor/tiled/old_cargo
	name = "floor"
	icon_state = "cargo_one_full"
	initial_flooring = /decl/flooring/tiling/new_tile/cargo_one
/turf/floor/tiled/old_cargo/white
	color = "#d9d9d9"
/turf/floor/tiled/old_cargo/blue
	color = "#8ba7ad"
/turf/floor/tiled/old_cargo/yellow
	color = "#8c6d46"
/turf/floor/tiled/old_cargo/gray
	color = "#687172"
/turf/floor/tiled/old_cargo/beige
	color = "#385e60"
/turf/floor/tiled/old_cargo/red
	color = "#964e51"
/turf/floor/tiled/old_cargo/purple
	color = "#906987"
/turf/floor/tiled/old_cargo/green
	color = "#46725c"


/turf/floor/tiled/kafel_full
	name = "floor"
	icon_state = "kafel_full"
	initial_flooring = /decl/flooring/tiling/new_tile/kafel
/turf/floor/tiled/kafel_full/white
	color = "#d9d9d9"
/turf/floor/tiled/kafel_full/blue
	color = "#8ba7ad"
/turf/floor/tiled/kafel_full/yellow
	color = "#8c6d46"
/turf/floor/tiled/kafel_full/gray
	color = "#687172"
/turf/floor/tiled/kafel_full/beige
	color = "#385e60"
/turf/floor/tiled/kafel_full/red
	color = "#964e51"
/turf/floor/tiled/kafel_full/purple
	color = "#906987"
/turf/floor/tiled/kafel_full/green
	color = "#46725c"


/turf/floor/tiled/techfloor/grid
	name = "floor"
	icon_state = "techfloor_grid"
	initial_flooring = /decl/flooring/tiling/tech/grid

/turf/floor/reinforced
	name = "reinforced floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "reinforced"
	initial_flooring = /decl/flooring/reinforced

/turf/floor/reinforced/airless
//	oxygen = FALSE
//	nitrogen = FALSE

/turf/floor/reinforced/airmix
//	oxygen = MOLES_O2ATMOS
//	nitrogen = MOLES_N2ATMOS

/turf/floor/reinforced/nitrogen
//	oxygen = FALSE
//	nitrogen = ATMOSTANK_NITROGEN

/turf/floor/reinforced/oxygen
	//oxygen = ATMOSTANK_OXYGEN
	//nitrogen = FALSE

/turf/floor/reinforced/plasma
//	oxygen = FALSE
//	nitrogen = FALSE
//	plasma = ATMOSTANK_PLASMA

/turf/floor/reinforced/carbon_dioxide
//	oxygen = FALSE
//	nitrogen = FALSE
//	carbon_dioxide = ATMOSTANK_CO2

/turf/floor/reinforced/n20
//	oxygen = FALSE
//	nitrogen = FALSE

/turf/floor/reinforced/n20/New()
	..()
	sleep(-1)
	//if (!air) make_air()
//	air.adjust_gas("sleeping_agent", ATMOSTANK_NITROUSOXIDE)
/*
/turf/floor/cult
	name = "engraved floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "cult"
	initial_flooring = /decl/flooring/reinforced/cult
*/
/turf/floor/tiled/dark
	name = "floor"
	icon_state = "dark"
	initial_flooring = /decl/flooring/tiling/dark

/turf/floor/tiled/steel
	name = "floor"
	icon_state = "steel_dirty"
	initial_flooring = /decl/flooring/tiling/steel

/turf/floor/tiled/steel/airless
//	oxygen = FALSE
//	nitrogen = FALSE

/turf/floor/tiled/white
	name = "floor"
	icon_state = "white"
	initial_flooring = /decl/flooring/tiling/white

/turf/floor/tiled/freezer
	name = "floor"
	icon_state = "freezer"
	initial_flooring = /decl/flooring/tiling/freezer


//ATMOS PREMADES
/turf/floor/reinforced/airless
	name = "reinforced floor"
//	oxygen = FALSE
//	nitrogen = FALSE
	temperature = TCMB

/turf/floor/airless
	name = "plating"
//	oxygen = FALSE
//	nitrogen = FALSE
	temperature = TCMB

/turf/floor/tiled/airless
	name = "floor"
//	oxygen = FALSE
//	nitrogen = FALSE
	temperature = TCMB

/turf/floor/bluegrid/airless
	name = "floor"
//	oxygen = FALSE
//	nitrogen = FALSE
	temperature = TCMB

/turf/floor/greengrid/airless
	name = "floor"
//	oxygen = FALSE
//	nitrogen = FALSE
	temperature = TCMB

/turf/floor/greengrid/nitrogen
//	oxygen = FALSE

/turf/floor/tiled/white/airless
	name = "floor"
//	oxygen = FALSE
//	nitrogen = FALSE
	temperature = TCMB

// Placeholders
/turf/floor/airless/lava
/turf/floor/light
/turf/floor/snow
///turf/floor/beach/coastline
/turf/floor/plating/snow
/turf/floor/airless/ceiling
/*
/turf/floor/beach
	name = "beach"
	icon = 'icons/turf/floors.dmi'

/turf/floor/beach/sand
	name = "sand"
	icon_state = "sand"

/turf/floor/beach/sand/desert
	icon_state = "desert"

/turf/floor/beach/coastline
	name = "coastline"
	icon = 'icons/turf/floors.dmi'
	icon_state = "sandwater"

/turf/floor/beach/water
	name = "water"
	icon_state = "water"

/turf/floor/beach/water/update_dirt()
	return	// Water doesn't become dirty

/turf/floor/beach/water/ocean
	icon_state = "seadeep"

/turf/floor/beach/water/New()
	..()
	overlays += image("icon"='icons/misc/beach.dmi',"icon_state"="water5","layer"=MOB_LAYER+0.1)

*/