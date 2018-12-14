/turf/floor/carpet
	name = "carpet"
	icon = 'icons/turf/floors.dmi'
	icon_state = "carpet"
	initial_flooring = /decl/flooring/carpet

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
	is_diggable = TRUE

/turf/floor/dirt
	name = "dirt"
	icon = 'icons/turf/floors.dmi'
	icon_state = "dirt"
	uses_winter_overlay = TRUE
	may_become_muddy = TRUE
	available_dirt = 3
	is_diggable = TRUE

/turf/floor/dirt/winter
	name = "snowy dirt"
	icon = 'icons/turf/snow.dmi'
	icon_state = "dirt"
	uses_winter_overlay = TRUE
	may_become_muddy = TRUE
	available_snow = 2
	available_dirt = 0
	is_diggable = TRUE

/turf/floor/dirt/burned
	name = "burned ground"
	icon_state = "burned_dirt"
	uses_winter_overlay = TRUE
	may_become_muddy = TRUE
	available_dirt = 1
	is_diggable = TRUE

/turf/floor/dirt/underground
	name = "underground rock"
	icon = 'icons/turf/walls.dmi'
	icon_state = "rocky"
	uses_winter_overlay = FALSE
	may_become_muddy = TRUE
	available_dirt = 0
	is_diggable = FALSE
	is_mineable = TRUE
	opacity = TRUE
	density = TRUE
	desc = "This space is blocked off by soft earth and rocks. Can be digged."
	icon = 'icons/turf/walls.dmi'
	icon_state = "rocky"

/turf/floor/dirt/underground/empty
	name = "rock debris"
	icon_state = "rock_debris1"

/turf/floor/dirt/underground/empty/New()
	..()
	icon_state = "rock_debris[rand(1,2)]"

/turf/floor/dirt/ploughed
	name = "ploughed field"
	icon = 'icons/turf/floors.dmi'
	icon_state = "dirt_ploughed"
	is_plowed = TRUE

/turf/floor/dirt/dust
	name = "dry dirt"
	icon = 'icons/turf/floors.dmi'
	icon_state = "dust"
	interior = FALSE
	stepsound = "dirt"
	available_dirt = 2
	may_become_muddy = FALSE
	is_diggable = TRUE

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