// this was flooring_decal.dm. I renamed it to fit the type name better - Kachnov

// These are objects that destroy themselves and add themselves to the
// decal list of the floor under them. Use them rather than distinct icon_states
// when mapping in interesting floor designs.
var/list/floor_decals = list()
/turf/var/list/floor_decal_cache_keys = list()

/obj/effect/floor_decal
	name = "floor decal"
	icon = 'icons/turf/flooring/decals.dmi'
	layer = TURF_LAYER + 0.2
	anchored = TRUE
	var/supplied_dir

/obj/effect/floor_decal/New(var/newloc, var/newdir, var/newcolour)
	supplied_dir = newdir
	if (newcolour) color = newcolour
	..(newloc)

/obj/effect/floor_decal/initialize()
	if (supplied_dir) set_dir(supplied_dir)
	var/turf/T = get_turf(src)
	for(var/obj/covers/R in T)
		var/cache_key = "[alpha]-[color]-[dir]-[icon_state]-[layer]"
		if (!floor_decals[cache_key])
			var/image/I = image(icon = icon, icon_state = icon_state, dir = dir)
			I.layer = 2.01
			I.color = color
			I.alpha = alpha
			floor_decals[cache_key] = I
		R.overlays |= floor_decals[cache_key]
		qdel(src)
		return
	if (istype(T, /turf/floor))
		var/cache_key = "[alpha]-[color]-[dir]-[icon_state]-[layer]"
		if (!floor_decals[cache_key])
			var/image/I = image(icon = icon, icon_state = icon_state, dir = dir)
			I.layer = 2.01
			I.color = color
			I.alpha = alpha
			floor_decals[cache_key] = I
		if (!T.decals) T.decals = list()
		T.decals |= floor_decals[cache_key]
		T.overlays |= floor_decals[cache_key]
		T.floor_decal_cache_keys |= cache_key
	qdel(src)
	return

/obj/effect/floor_decal/reset
	name = "reset marker"

/obj/effect/floor_decal/reset/initialize()
	var/turf/T = get_turf(src)
	if (T.decals && T.decals.len)
		T.decals.Cut()
		T.update_icon()
	qdel(src)
	return

/obj/effect/floor_decal/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			qdel(src)
			return
		if (3.0)
			if (prob(75))
				qdel(src)
			return
		else
	return

/obj/effect/floor_decal/attackby(obj/item/W, mob/user)
	return

/obj/effect/floor_decal/corner
	icon_state = "corner_white"

/* Decal Corner (Black)*/

/obj/effect/floor_decal/corner/black
	name = "black corner"
	color = "#505050"

/obj/effect/floor_decal/corner/black/diagonal
	icon_state = "corner_white_diagonal"

/obj/effect/floor_decal/corner/black/three_quarters
	icon_state = "corner_white_three_quarters"

/obj/effect/floor_decal/corner/black/border
	icon_state = "bordercolor"

/obj/effect/floor_decal/corner/black/bordercorner
	icon_state = "bordercolorcorner"

/obj/effect/floor_decal/corner/black/bordercorner2
	icon_state = "bordercolorcorner2"

/obj/effect/floor_decal/corner/black/borderfull
	icon_state = "bordercolorfull"

/obj/effect/floor_decal/corner/black/bordercee
	icon_state = "bordercolorcee"

/* Decal Corner (Blue)*/

/obj/effect/floor_decal/corner/blue
	name = "blue corner"
	color = COLOR_BLUE_GRAY

/obj/effect/floor_decal/corner/blue/diagonal
	icon_state = "corner_white_diagonal"

/obj/effect/floor_decal/corner/blue/three_quarters
	icon_state = "corner_white_three_quarters"

/obj/effect/floor_decal/corner/blue/border
	icon_state = "bordercolor"

/obj/effect/floor_decal/corner/blue/bordercorner
	icon_state = "bordercolorcorner"

/obj/effect/floor_decal/corner/blue/bordercorner2
	icon_state = "bordercolorcorner2"

/obj/effect/floor_decal/corner/blue/borderfull
	icon_state = "bordercolorfull"

/obj/effect/floor_decal/corner/blue/bordercee
	icon_state = "bordercolorcee"

/* Decal Corner (Pale-Blue)*/

/obj/effect/floor_decal/corner/paleblue
	name = "pale blue corner"
	color = COLOR_PALE_BLUE_GRAY

/obj/effect/floor_decal/corner/paleblue/diagonal
	icon_state = "corner_white_diagonal"

/obj/effect/floor_decal/corner/paleblue/three_quarters
	icon_state = "corner_white_three_quarters"

/obj/effect/floor_decal/corner/paleblue/border
	icon_state = "bordercolor"

/obj/effect/floor_decal/corner/paleblue/bordercorner
	icon_state = "bordercolorcorner"

/obj/effect/floor_decal/corner/paleblue/bordercorner2
	icon_state = "bordercolorcorner2"

/obj/effect/floor_decal/corner/paleblue/borderfull
	icon_state = "bordercolorfull"

/obj/effect/floor_decal/corner/paleblue/bordercee
	icon_state = "bordercolorcee"

/* Decal Corner (Green)*/

/obj/effect/floor_decal/corner/green
	name = "green corner"
	color = COLOR_GREEN_GRAY

/obj/effect/floor_decal/corner/green/diagonal
	icon_state = "corner_white_diagonal"

/obj/effect/floor_decal/corner/green/three_quarters
	icon_state = "corner_white_three_quarters"

/obj/effect/floor_decal/corner/green/border
	icon_state = "bordercolor"

/obj/effect/floor_decal/corner/green/bordercorner
	icon_state = "bordercolorcorner"

/obj/effect/floor_decal/corner/green/bordercorner2
	icon_state = "bordercolorcorner2"

/obj/effect/floor_decal/corner/green/borderfull
	icon_state = "bordercolorfull"

/obj/effect/floor_decal/corner/green/bordercee
	icon_state = "bordercolorcee"

/* Decal Corner (Lime)*/

/obj/effect/floor_decal/corner/lime
	name = "lime corner"
	color = "#C0E9AD"

/obj/effect/floor_decal/corner/lime/diagonal
	icon_state = "corner_white_diagonal"

/obj/effect/floor_decal/corner/lime/three_quarters
	icon_state = "corner_white_three_quarters"

/obj/effect/floor_decal/corner/lime/border
	icon_state = "bordercolor"

/obj/effect/floor_decal/corner/lime/bordercorner
	icon_state = "bordercolorcorner"

/obj/effect/floor_decal/corner/lime/bordercorner2
	icon_state = "bordercolorcorner2"

/obj/effect/floor_decal/corner/lime/borderfull
	icon_state = "bordercolorfull"

/obj/effect/floor_decal/corner/lime/bordercee
	icon_state = "bordercolorcee"

/* Decal Corner (Yellow)*/

/obj/effect/floor_decal/corner/yellow
	name = "yellow corner"
	color = "#D2C273"

/obj/effect/floor_decal/corner/yellow/diagonal
	icon_state = "corner_white_diagonal"

/obj/effect/floor_decal/corner/yellow/three_quarters
	icon_state = "corner_white_three_quarters"

/obj/effect/floor_decal/corner/yellow/full
	icon_state = "corner_white_full"

/obj/effect/floor_decal/corner/yellow/border
	icon_state = "bordercolor"

/obj/effect/floor_decal/corner/yellow/bordercorner
	icon_state = "bordercolorcorner"

/obj/effect/floor_decal/corner/yellow/bordercorner2
	icon_state = "bordercolorcorner2"

/obj/effect/floor_decal/corner/yellow/borderfull
	icon_state = "bordercolorfull"

/obj/effect/floor_decal/corner/yellow/bordercee
	icon_state = "bordercolorcee"

/* Decal Corner (Beige)*/

/obj/effect/floor_decal/corner/beige
	name = "beige corner"
	color = COLOR_BEIGE

/obj/effect/floor_decal/corner/beige/diagonal
	icon_state = "corner_white_diagonal"

/obj/effect/floor_decal/corner/beige/three_quarters
	icon_state = "corner_white_three_quarters"

/obj/effect/floor_decal/corner/beige/border
	icon_state = "bordercolor"

/obj/effect/floor_decal/corner/beige/bordercorner
	icon_state = "bordercolorcorner"

/obj/effect/floor_decal/corner/beige/bordercorner2
	icon_state = "bordercolorcorner2"

/obj/effect/floor_decal/corner/beige/borderfull
	icon_state = "bordercolorfull"

/obj/effect/floor_decal/corner/beige/bordercee
	icon_state = "bordercolorcee"

/* Decal Corner (Red)*/

/obj/effect/floor_decal/corner/red
	name = "red corner"
	color = COLOR_RED_GRAY

/obj/effect/floor_decal/corner/red/diagonal
	icon_state = "corner_white_diagonal"

/obj/effect/floor_decal/corner/red/three_quarters
	icon_state = "corner_white_three_quarters"

/obj/effect/floor_decal/corner/red/full
	icon_state = "corner_white_full"

/obj/effect/floor_decal/corner/red/border
	icon_state = "bordercolor"

/obj/effect/floor_decal/corner/red/bordercorner
	icon_state = "bordercolorcorner"

/obj/effect/floor_decal/corner/red/bordercorner2
	icon_state = "bordercolorcorner2"

/obj/effect/floor_decal/corner/red/borderfull
	icon_state = "bordercolorfull"

/obj/effect/floor_decal/corner/red/bordercee
	icon_state = "bordercolorcee"

/* Decal Corner (Pink)*/

/obj/effect/floor_decal/corner/pink
	name = "pink corner"
	color = COLOR_PALE_RED_GRAY

/obj/effect/floor_decal/corner/pink/diagonal
	icon_state = "corner_white_diagonal"

/obj/effect/floor_decal/corner/pink/three_quarters
	icon_state = "corner_white_three_quarters"

/obj/effect/floor_decal/corner/pink/border
	icon_state = "bordercolor"

/obj/effect/floor_decal/corner/pink/bordercorner
	icon_state = "bordercolorcorner"

/obj/effect/floor_decal/corner/pink/bordercorner2
	icon_state = "bordercolorcorner2"

/obj/effect/floor_decal/corner/pink/borderfull
	icon_state = "bordercolorfull"

/obj/effect/floor_decal/corner/pink/bordercee
	icon_state = "bordercolorcee"

/* Decal Corner (Purple)*/

/obj/effect/floor_decal/corner/purple
	name = "purple corner"
	color = COLOR_PURPLE_GRAY

/obj/effect/floor_decal/corner/purple/diagonal
	icon_state = "corner_white_diagonal"

/obj/effect/floor_decal/corner/purple/three_quarters
	icon_state = "corner_white_three_quarters"

/obj/effect/floor_decal/corner/purple/border
	icon_state = "bordercolor"

/obj/effect/floor_decal/corner/purple/bordercorner
	icon_state = "bordercolorcorner"

/obj/effect/floor_decal/corner/purple/bordercorner2
	icon_state = "bordercolorcorner2"

/obj/effect/floor_decal/corner/purple/borderfull
	icon_state = "bordercolorfull"

/obj/effect/floor_decal/corner/purple/bordercee
	icon_state = "bordercolorcee"

/* Decal Corner (Mauve)*/

/obj/effect/floor_decal/corner/mauve
	name = "mauve corner"
	color = COLOR_PALE_PURPLE_GRAY

/obj/effect/floor_decal/corner/mauve/diagonal
	icon_state = "corner_white_diagonal"

/obj/effect/floor_decal/corner/mauve/three_quarters
	icon_state = "corner_white_three_quarters"

/obj/effect/floor_decal/corner/mauve/border
	icon_state = "bordercolor"

/obj/effect/floor_decal/corner/mauve/bordercorner
	icon_state = "bordercolorcorner"

/obj/effect/floor_decal/corner/mauve/bordercorner2
	icon_state = "bordercolorcorner2"

/obj/effect/floor_decal/corner/mauve/borderfull
	icon_state = "bordercolorfull"

/obj/effect/floor_decal/corner/mauve/bordercee
	icon_state = "bordercolorcee"

/* Decal Corner (Orange)*/

/obj/effect/floor_decal/corner/orange
	name = "orange corner"
	color = "#D06E22"

/obj/effect/floor_decal/corner/orange/diagonal
	icon_state = "corner_white_diagonal"

/obj/effect/floor_decal/corner/orange/three_quarters
	icon_state = "corner_white_three_quarters"

/obj/effect/floor_decal/corner/orange/border
	icon_state = "bordercolor"

/obj/effect/floor_decal/corner/orange/bordercorner
	icon_state = "bordercolorcorner"

/obj/effect/floor_decal/corner/orange/bordercorner2
	icon_state = "bordercolorcorner2"

/obj/effect/floor_decal/corner/orange/borderfull
	icon_state = "bordercolorfull"

/obj/effect/floor_decal/corner/orange/bordercee
	icon_state = "bordercolorcee"

/* Decal Corner (Brown)*/

/obj/effect/floor_decal/corner/brown
	name = "brown corner"
	color = COLOR_BROWN

/obj/effect/floor_decal/corner/brown/diagonal
	icon_state = "corner_white_diagonal"

/obj/effect/floor_decal/corner/brown/three_quarters
	icon_state = "corner_white_three_quarters"

/obj/effect/floor_decal/corner/brown/border
	icon_state = "bordercolor"

/obj/effect/floor_decal/corner/brown/bordercorner
	icon_state = "bordercolorcorner"

/obj/effect/floor_decal/corner/brown/bordercorner2
	icon_state = "bordercolorcorner2"

/obj/effect/floor_decal/corner/brown/borderfull
	icon_state = "bordercolorfull"

/obj/effect/floor_decal/corner/brown/bordercee
	icon_state = "bordercolorcee"

/* Decal Corner (White)*/

/obj/effect/floor_decal/corner/white
	name = "white corner"
	icon_state = "corner_white"
	color = "#D1D1D1"

/obj/effect/floor_decal/corner/white/diagonal
	icon_state = "corner_white_diagonal"

/obj/effect/floor_decal/corner/white/three_quarters
	icon_state = "corner_white_three_quarters"

/obj/effect/floor_decal/corner/white/border
	icon_state = "bordercolor"

/obj/effect/floor_decal/corner/white/bordercorner
	icon_state = "bordercolorcorner"

/obj/effect/floor_decal/corner/white/bordercorner2
	icon_state = "bordercolorcorner2"

/obj/effect/floor_decal/corner/white/borderfull
	icon_state = "bordercolorfull"

/obj/effect/floor_decal/corner/white/bordercee
	icon_state = "bordercolorcee"

/* Decal Corner (Grey)*/

/obj/effect/floor_decal/corner/grey
	name = "grey corner"
	color = "#8D8C8C"

/obj/effect/floor_decal/corner/grey/diagonal
	icon_state = "corner_white_diagonal"

/obj/effect/floor_decal/corner/grey/three_quarters
	icon_state = "corner_white_three_quarters"

/obj/effect/floor_decal/corner/grey/border
	icon_state = "bordercolor"

/obj/effect/floor_decal/corner/grey/bordercorner
	icon_state = "bordercolorcorner"

/obj/effect/floor_decal/corner/grey/bordercorner
	icon_state = "bordercolorcorner"

/obj/effect/floor_decal/corner/grey/borderfull
	icon_state = "bordercolorfull"

/obj/effect/floor_decal/corner/grey/bordercee
	icon_state = "bordercolorcee"

/* Decal Corner (Light-Grey)*/

/obj/effect/floor_decal/corner/lightgrey
	name = "lightgrey corner"
	color = "#A8B2B6"

/obj/effect/floor_decal/corner/lightgrey/diagonal
	icon_state = "corner_white_diagonal"

/obj/effect/floor_decal/corner/lightgrey/three_quarters
	icon_state = "corner_white_three_quarters"

/obj/effect/floor_decal/corner/lightgrey/border
	icon_state = "bordercolor"

/obj/effect/floor_decal/corner/lightgrey/bordercorner
	icon_state = "bordercolorcorner"

/obj/effect/floor_decal/corner/lightgrey/bordercorner2
	icon_state = "bordercolorcorner2"

/obj/effect/floor_decal/corner/lightgrey/borderfull
	icon_state = "bordercolorfull"

/obj/effect/floor_decal/corner/lightgrey/bordercee
	icon_state = "bordercolorcee"

/* Spline Decal*/

/obj/effect/floor_decal/spline/plain
	name = "spline - plain"
	icon_state = "spline_plain"

/obj/effect/floor_decal/spline/fancy
	name = "spline - fancy"
	icon_state = "spline_fancy"

/obj/effect/floor_decal/spline/fancy/wood
	name = "spline - wood"
	color = "#CB9E04"

/obj/effect/floor_decal/spline/fancy/wood/corner
	icon_state = "spline_fancy_corner"

/obj/effect/floor_decal/spline/fancy/wood/cee
	icon_state = "spline_fancy_cee"

/obj/effect/floor_decal/spline/fancy/wood/three_quarters
	icon_state = "spline_fancy_full"

/* Industrial Warning Decal*/

/obj/effect/floor_decal/industrial/warning
	name = "hazard stripes"
	icon_state = "warning"

/obj/effect/floor_decal/industrial/warning/corner
	icon_state = "warningcorner"

/obj/effect/floor_decal/industrial/warning/full
	icon_state = "warningfull"

/obj/effect/floor_decal/industrial/warning/cee
	icon_state = "warningcee"

/* Industrial Warning Decal (Danger)*/

/obj/effect/floor_decal/industrial/danger
	name = "hazard stripes"
	icon_state = "danger"

/obj/effect/floor_decal/industrial/danger/corner
	icon_state = "dangercorner"

/obj/effect/floor_decal/industrial/danger/full
	icon_state = "dangerfull"

/obj/effect/floor_decal/industrial/danger/cee
	icon_state = "dangercee"

/* Industrial Warning Decal (Dust)*/

/obj/effect/floor_decal/industrial/warning/dust
	name = "hazard stripes"
	icon_state = "warning_dust"

/obj/effect/floor_decal/industrial/warning/dust/corner
	name = "hazard stripes"
	icon_state = "warningcorner_dust"

/* Hatch Decal*/

/obj/effect/floor_decal/industrial/hatch
	name = "hatched marking"
	icon_state = "delivery"

/obj/effect/floor_decal/industrial/hatch/yellow
	color = "#CFCF55"

/* Industrial Outline Decal*/

/obj/effect/floor_decal/industrial/outline
	name = "white outline"
	icon_state = "outline"

/obj/effect/floor_decal/industrial/outline/blue
	name = "blue outline"
	color = "#00B8B2"

/obj/effect/floor_decal/industrial/outline/yellow
	name = "yellow outline"
	color = "#CFCF55"

/obj/effect/floor_decal/industrial/outline/grey
	name = "grey outline"
	color = "#808080"

/* Industrial Loading Decal*/

/obj/effect/floor_decal/industrial/loading
	name = "loading area"
	icon_state = "loadingarea"

/* Signage Decal*/

/obj/effect/floor_decal/safensound
	name = "SafeNSound"
	icon_state = "safensound"

/obj/effect/floor_decal/plaque
	name = "plaque"
	icon_state = "plaque"

/obj/effect/floor_decal/washit
	name = "Wash it"
	icon_state = "washit"

/* Dirt wall Decal*/

/obj/effect/floor_decal/dirtwall
	name = "dirt wall"
	icon = 'icons/obj/structures.dmi'
	icon_state = "dirt_wall"

/obj/effect/floor_decal/dirtwall/inc66
	name = "dirt wall"
	icon = 'icons/obj/structures.dmi'
	icon_state = "dirt_wall_66%"

/obj/effect/floor_decal/dirtwall/inc33
	name = "dirt wall"
	icon = 'icons/obj/structures.dmi'
	icon_state = "dirt_wall_33%"

/* Carpet Floor Decal*/

/obj/effect/floor_decal/carpet
	name = "carpet"
	icon = 'icons/turf/flooring/carpet.dmi'
	icon_state = "carpet_edges"

/obj/effect/floor_decal/carpet/blue
	name = "carpet"
	icon = 'icons/turf/flooring/carpet.dmi'
	icon_state = "bcarpet_edges"

/obj/effect/floor_decal/carpet/corners
	name = "carpet"
	icon = 'icons/turf/flooring/carpet.dmi'
	icon_state = "carpet_corners"

/* Chapel Floor*/

/obj/effect/floor_decal/chapel
	name = "chapel"
	icon_state = "chapel"

/* Rust Floor*/

/obj/effect/floor_decal/rust
	name = "rust"
	icon_state = "rust"

/* Rust Floor - Mono*/

/obj/effect/floor_decal/rust/mono_rusted1
	icon_state = "mono_rusted1"

/obj/effect/floor_decal/rust/mono_rusted2
	icon_state = "mono_rusted2"

/obj/effect/floor_decal/rust/mono_rusted3
	icon_state = "mono_rusted3"

/* Rust Floor - Part Rusted*/

/obj/effect/floor_decal/rust/part_rusted1
	icon_state = "part_rusted1"

/obj/effect/floor_decal/rust/part_rusted2
	icon_state = "part_rusted2"

/obj/effect/floor_decal/rust/part_rusted3
	icon_state = "part_rusted3"

/* Rust Floor - Color Rusted*/

/obj/effect/floor_decal/rust/color_rusted
	icon_state = "color_rusted"

/obj/effect/floor_decal/rust/color_rustedcorner
	icon_state = "color_rustedcorner"

/obj/effect/floor_decal/rust/color_rustedfull
	icon_state = "color_rustedfull"

/obj/effect/floor_decal/rust/color_rustedcee
	icon_state = "color_rustedcee"

/* Rust Floor - Steel Rusted*/

/obj/effect/floor_decal/rust/steel_decals_rusted1
	icon_state = "steel_decals_rusted1"

/obj/effect/floor_decal/rust/steel_decals_rusted2
	icon_state = "steel_decals_rusted2"

//////////////////////////////////////////////|
/* Old-Tile Floor Decal (and colors, see index)

- Regular Old-Tile Floor | White Old-Tile Floor | Blue Old-Tile Floor | Yellow Old-Tile Floor | Grey Old-Tile Floor |
| Beige Old-Tile Floor | Red Old-Tile Floor | Purple Old-Tile Floor | Green Old-Tile Floor |*/

/obj/effect/floor_decal/corner_oldtile
	name = "corner oldtile"
	icon_state = "corner_oldtile"

/* Old-Tile Floor Decal (White)*/

/obj/effect/floor_decal/corner_oldtile/white
	name = "corner oldtile"
	icon_state = "corner_oldtile"
	color = "#d9d9d9"

/obj/effect/floor_decal/corner_oldtile/white/diagonal
	name = "corner oldtile diagonal"
	icon_state = "corner_oldtile_diagonal"

/obj/effect/floor_decal/corner_oldtile/white/full
	name = "corner oldtile full"
	icon_state = "corner_oldtile_full"

/* Old-Tile Floor Decal (Blue)*/

/obj/effect/floor_decal/corner_oldtile/blue
	name = "corner oldtile"
	icon_state = "corner_oldtile"
	color = "#8ba7ad"

/obj/effect/floor_decal/corner_oldtile/blue/diagonal
	name = "corner oldtile diagonal"
	icon_state = "corner_oldtile_diagonal"

/obj/effect/floor_decal/corner_oldtile/blue/full
	name = "corner oldtile full"
	icon_state = "corner_oldtile_full"

/* Old-Tile Floor Decal (Yellow)*/

/obj/effect/floor_decal/corner_oldtile/yellow
	name = "corner oldtile"
	icon_state = "corner_oldtile"
	color = "#8c6d46"

/obj/effect/floor_decal/corner_oldtile/yellow/diagonal
	name = "corner oldtile diagonal"
	icon_state = "corner_oldtile_diagonal"

/obj/effect/floor_decal/corner_oldtile/yellow/full
	name = "corner oldtile full"
	icon_state = "corner_oldtile_full"

/* Old-Tile Floor Decal (Grey)*/

/obj/effect/floor_decal/corner_oldtile/gray
	name = "corner oldtile"
	icon_state = "corner_oldtile"
	color = "#687172"

/obj/effect/floor_decal/corner_oldtile/gray/diagonal
	name = "corner oldtile diagonal"
	icon_state = "corner_oldtile_diagonal"

/obj/effect/floor_decal/corner_oldtile/gray/full
	name = "corner oldtile full"
	icon_state = "corner_oldtile_full"

/* Old-Tile Floor Decal (Beige)*/

/obj/effect/floor_decal/corner_oldtile/beige
	name = "corner oldtile"
	icon_state = "corner_oldtile"
	color = "#385e60"

/obj/effect/floor_decal/corner_oldtile/beige/diagonal
	name = "corner oldtile diagonal"
	icon_state = "corner_oldtile_diagonal"

/obj/effect/floor_decal/corner_oldtile/beige/full
	name = "corner oldtile full"
	icon_state = "corner_oldtile_full"

/* Old-Tile Floor Decal (Red)*/

/obj/effect/floor_decal/corner_oldtile/red
	name = "corner oldtile"
	icon_state = "corner_oldtile"
	color = "#964e51"

/obj/effect/floor_decal/corner_oldtile/red/diagonal
	name = "corner oldtile diagonal"
	icon_state = "corner_oldtile_diagonal"

/obj/effect/floor_decal/corner_oldtile/red/full
	name = "corner oldtile full"
	icon_state = "corner_oldtile_full"

/* Old-Tile Floor Decal (Purple)*/

/obj/effect/floor_decal/corner_oldtile/purple
	name = "corner oldtile"
	icon_state = "corner_oldtile"
	color = "#906987"

/obj/effect/floor_decal/corner_oldtile/purple/diagonal
	name = "corner oldtile diagonal"
	icon_state = "corner_oldtile_diagonal"

/obj/effect/floor_decal/corner_oldtile/purple/full
	name = "corner oldtile full"
	icon_state = "corner_oldtile_full"

/* Old-Tile Floor Decal (Green)*/

/obj/effect/floor_decal/corner_oldtile/green
	name = "corner oldtile"
	icon_state = "corner_oldtile"
	color = "#46725c"

/obj/effect/floor_decal/corner_oldtile/green/diagonal
	name = "corner oldtile diagonal"
	icon_state = "corner_oldtile_diagonal"

/obj/effect/floor_decal/corner_oldtile/green/full
	name = "corner oldtile full"
	icon_state = "corner_oldtile_full"

///////////////////////////////////////////|
/* Kafel Floor Decal (and colors, see index)

- Regular Kafel | White Kafel | Blue Kafel | Yellow Kafel | Grey Kafel | Beige Kafel | Red Kafel | Purple Kafel | Green Kafel |*/

/obj/effect/floor_decal/corner_kafel
	name = "corner kafel"
	icon_state = "corner_kafel"

/* Kafel Floor (White) Decal*/

/obj/effect/floor_decal/corner_kafel/white
	name = "corner kafel"
	icon_state = "corner_kafel"
	color = "#d9d9d9"

/obj/effect/floor_decal/corner_kafel/white/diagonal
	name = "corner kafel diagonal"
	icon_state = "corner_kafel_diagonal"

/obj/effect/floor_decal/corner_kafel/white/full
	name = "corner kafel full"
	icon_state = "corner_kafel_full"

/* Kafel Floor (Blue) Decal*/

/obj/effect/floor_decal/corner_kafel/blue
	name = "corner kafel"
	icon_state = "corner_kafel"
	color = "#8ba7ad"

/obj/effect/floor_decal/corner_kafel/blue/diagonal
	name = "corner kafel diagonal"
	icon_state = "corner_kafel_diagonal"

/obj/effect/floor_decal/corner_kafel/blue/full
	name = "corner kafel full"
	icon_state = "corner_kafel_full"

/* Kafel Floor (Yellow) Decal*/

/obj/effect/floor_decal/corner_kafel/yellow
	name = "corner kafel"
	icon_state = "corner_kafel"
	color = "#8c6d46"

/obj/effect/floor_decal/corner_kafel/yellow/diagonal
	name = "corner kafel diagonal"
	icon_state = "corner_kafel_diagonal"

/obj/effect/floor_decal/corner_kafel/yellow/full
	name = "corner kafel full"
	icon_state = "corner_kafel_full"

/* Kafel Floor (Grey) Decal*/

/obj/effect/floor_decal/corner_kafel/gray
	name = "corner kafel"
	icon_state = "corner_kafel"
	color = "#687172"

/obj/effect/floor_decal/corner_kafel/gray/diagonal
	name = "corner kafel diagonal"
	icon_state = "corner_kafel_diagonal"

/obj/effect/floor_decal/corner_kafel/gray/full
	name = "corner kafel full"
	icon_state = "corner_kafel_full"

/* Kafel Floor (Beige) Decal*/

/obj/effect/floor_decal/corner_kafel/beige
	name = "corner kafel"
	icon_state = "corner_kafel"
	color = "#385e60"

/obj/effect/floor_decal/corner_kafel/beige/diagonal
	name = "corner kafel diagonal"
	icon_state = "corner_kafel_diagonal"

/obj/effect/floor_decal/corner_kafel/beige/full
	name = "corner kafel full"
	icon_state = "corner_kafel_full"

/* Kafel Floor (Red) Decal*/

/obj/effect/floor_decal/corner_kafel/red
	name = "corner kafel"
	icon_state = "corner_kafel"
	color = "#964e51"

/obj/effect/floor_decal/corner_kafel/red/diagonal
	name = "corner kafel diagonal"
	icon_state = "corner_kafel_diagonal"

/obj/effect/floor_decal/corner_kafel/red/full
	name = "corner kafel full"
	icon_state = "corner_kafel_full"

/* Kafel Floor (Purple) Decal*/

/obj/effect/floor_decal/corner_kafel/purple
	name = "corner kafel"
	icon_state = "corner_kafel"
	color = "#906987"

/obj/effect/floor_decal/corner_kafel/purple/diagonal
	name = "corner kafel diagonal"
	icon_state = "corner_kafel_diagonal"

/obj/effect/floor_decal/corner_kafel/purple/full
	name = "corner kafel full"
	icon_state = "corner_kafel_full"

/* Kafel Floor (Green) Decal*/

/obj/effect/floor_decal/corner_kafel/green
	name = "corner kafel"
	icon_state = "corner_kafel"
	color = "#46725c"

/obj/effect/floor_decal/corner_kafel/green/diagonal
	name = "corner kafel diagonal"
	icon_state = "corner_kafel_diagonal"

/obj/effect/floor_decal/corner_kafel/green/full
	name = "corner kafel full"
	icon_state = "corner_kafel_full"

/* Tech-Floor*/

/obj/effect/floor_decal/techfloor
	name = "techfloor edges"
	icon_state = "techfloor_edges"

/obj/effect/floor_decal/techfloor/corner
	name = "techfloor corner"
	icon_state = "techfloor_corners"

/* Tech-Floor - Orange*/

/obj/effect/floor_decal/techfloor/orange
	name = "techfloor edges"
	icon_state = "techfloororange_edges"

/obj/effect/floor_decal/techfloor/orange/corner
	name = "techfloor corner"
	icon_state = "techfloororange_corners"

/* Tech-Floor - Hole*/

/obj/effect/floor_decal/techfloor/hole
	name = "hole left"
	icon_state = "techfloor_hole_left"

/obj/effect/floor_decal/techfloor/hole/right
	name = "hole right"
	icon_state = "techfloor_hole_right"

/* Tech-Floor - Grey*/

/obj/effect/floor_decal/corner_techfloor_gray
	name = "corner techfloorgray"
	icon_state = "corner_techfloor_gray"

/obj/effect/floor_decal/corner_techfloor_gray/diagonal
	name = "corner techfloorgray diagonal"
	icon_state = "corner_techfloor_gray_diagonal"

/obj/effect/floor_decal/corner_techfloor_gray/full
	name = "corner techfloorgray full"
	icon_state = "corner_techfloor_gray_full"

/* Tech-Floor - Grid*/

/obj/effect/floor_decal/corner_techfloor_grid
	name = "corner techfloorgrid"
	icon_state = "corner_techfloor_grid"

/obj/effect/floor_decal/corner_techfloor_grid/diagonal
	name = "corner techfloorgrid diagonal"
	icon_state = "corner_techfloor_grid_diagonal"

/obj/effect/floor_decal/corner_techfloor_grid/full
	name = "corner techfloorgrid full"
	icon_state = "corner_techfloor_grid_full"

/* Border-Floor*/

/obj/effect/floor_decal/borderfloor
	name = "border floor"
	icon_state = "borderfloor"

/obj/effect/floor_decal/borderfloor/corner
	icon_state = "borderfloorcorner"

/obj/effect/floor_decal/borderfloor/corner2
	icon_state = "borderfloorcorner2"

/obj/effect/floor_decal/borderfloor/full
	icon_state = "borderfloorfull"

/obj/effect/floor_decal/borderfloor/cee
	icon_state = "borderfloorcee"

/* Border-Floor Black*/

/obj/effect/floor_decal/borderfloorblack
	name = "border floor"
	icon_state = "borderfloor_black"

/obj/effect/floor_decal/borderfloorblack/corner
	icon_state = "borderfloorcorner_black"

/obj/effect/floor_decal/borderfloorblack/corner2
	icon_state = "borderfloorcorner2_black"

/obj/effect/floor_decal/borderfloorblack/full
	icon_state = "borderfloorfull_black"

/obj/effect/floor_decal/borderfloorblack/cee
	icon_state = "borderfloorcee_black"

/* Border-Floor White*/

/obj/effect/floor_decal/borderfloorwhite
	name = "border floor"
	icon_state = "borderfloor_white"

/obj/effect/floor_decal/borderfloorwhite/corner
	icon_state = "borderfloorcorner_white"

/obj/effect/floor_decal/borderfloorwhite/corner2
	icon_state = "borderfloorcorner2_white"

/obj/effect/floor_decal/borderfloorwhite/full
	icon_state = "borderfloorfull_white"

/obj/effect/floor_decal/borderfloorwhite/cee
	icon_state = "borderfloorcee_white"

/* Steel Decal*/

/obj/effect/floor_decal/steeldecal
	name = "steel decal"
	icon_state = "steel_decals1"

/obj/effect/floor_decal/steeldecal/steel_decals1
	icon_state = "steel_decals1"

/obj/effect/floor_decal/steeldecal/steel_decals2
	icon_state = "steel_decals2"

/obj/effect/floor_decal/steeldecal/steel_decals3
	icon_state = "steel_decals3"

/obj/effect/floor_decal/steeldecal/steel_decals4
	icon_state = "steel_decals4"

/obj/effect/floor_decal/steeldecal/steel_decals5
	icon_state = "steel_decals5"

/obj/effect/floor_decal/steeldecal/steel_decals6
	icon_state = "steel_decals6"

/obj/effect/floor_decal/steeldecal/steel_decals7
	icon_state = "steel_decals7"

/obj/effect/floor_decal/steeldecal/steel_decals8
	icon_state = "steel_decals8"

/obj/effect/floor_decal/steeldecal/steel_decals9
	icon_state = "steel_decals9"

/obj/effect/floor_decal/steeldecal/steel_decals10
	icon_state = "steel_decals10"

/* Steel Decal - Central*/

/obj/effect/floor_decal/steeldecal/steel_decals_central1
	icon_state = "steel_decals_central1"

/obj/effect/floor_decal/steeldecal/steel_decals_central2
	icon_state = "steel_decals_central2"

/obj/effect/floor_decal/steeldecal/steel_decals_central3
	icon_state = "steel_decals_central3"

/obj/effect/floor_decal/steeldecal/steel_decals_central4
	icon_state = "steel_decals_central4"

/obj/effect/floor_decal/steeldecal/steel_decals_central5
	icon_state = "steel_decals_central5"

/obj/effect/floor_decal/steeldecal/steel_decals_central6
	icon_state = "steel_decals_central6"

/obj/effect/floor_decal/steeldecal/steel_decals_central7
	icon_state = "steel_decals_central7"

/* Steel Decal - Grid*/

/obj/effect/floor_decal/corner_steel_grid
	name = "corner steel_grid"
	icon_state = "steel_grid"

/obj/effect/floor_decal/corner_steel_grid/diagonal
	name = "corner tsteel_grid diagonal"
	icon_state = "steel_grid_diagonal"

/obj/effect/floor_decal/corner_steel_grid/full
	name = "corner steel_grid full"
	icon_state = "steel_grid_full"

/* Grass (Landscaping)*/

/obj/effect/floor_decal/grass_edge
	name = "grass edge"
	icon_state = "grass_edges" // updated to proper one

/obj/effect/floor_decal/grass_edge/corner
	name = "grass edge"
	icon_state = "grass_edge_corner"

/obj/effect/floor_decal/grass_edge/dead
	name = "dead grass edge"
	icon_state = "dead_grass_edge"

/obj/effect/floor_decal/grass_edge/corner/dead
	name = "dead grass edge"
	icon_state = "dead_grass_edge_corner"

/* Sand (Landscaping)*/

/obj/effect/floor_decal/desert_edge
	name = "desert edge"
	icon = 'icons/misc/beach.dmi'
	icon_state = "desert_edges"
/obj/effect/floor_decal/sand_edge
	name = "sand edge"
	icon = 'icons/misc/beach.dmi'
	icon_state = "sand_edges"

/* Tatami (Bamboo Floor Bordering For Mats)*/

/obj/effect/floor_decal/tatami
	icon_state = "tatami_frame"

/obj/effect/floor_decal/tatami/angle
	icon_state = "tatami_frame_angle"

/obj/effect/floor_decal/tatami/full
	icon_state = "tatami_frame_full"

/obj/effect/floor_decal/tatami/corner
	icon_state = "tatami_frame_corner"

/obj/effect/floor_decal/tatami/cee
	icon_state = "tatami_frame_cee"

/* ship water line*/
/obj/effect/floor_decal/shipline
	name = "deep saltwater"
	icon_state = "ship_line"
	plane = FLOOR_PLANE
	mouse_opacity = FALSE