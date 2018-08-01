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

/turf/floor/tiled
	name = "floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "steel"
	initial_flooring = /decl/flooring/tiling



/turf/floor/tiled/kafel_full
	name = "floor"
	icon_state = "bcarpet05"
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


/turf/floor/tiled/dark
	name = "floor"
	icon_state = "dark"
	initial_flooring = /decl/flooring/tiling/dark

/turf/floor/tiled/steel
	name = "floor"
	icon_state = "neutralfull"
	initial_flooring = /decl/flooring/tiling/steel

/turf/floor/tiled/white
	name = "floor"
	icon_state = "white"
	initial_flooring = /decl/flooring/tiling/white
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