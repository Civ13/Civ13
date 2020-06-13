/* Wall Types */
/* Generic & Mineral*/

/turf/wall/diamond/New(var/newloc)
	..(newloc,"diamond")
/turf/wall/gold/New(var/newloc)
	..(newloc,"gold")
/turf/wall/silver/New(var/newloc)
	..(newloc,"silver")
/turf/wall/iron/New(var/newloc)
	..(newloc,"iron")
/turf/wall/iron/low/New(var/newloc)
	..(newloc,"iron")
	opacity = FALSE

/* Building Material*/

/* Clay Walls*/
/turf/wall/brick
	icon_state = "new_brick0"
/turf/wall/brick/New(var/newloc)
	..(newloc,"brick")

/turf/wall/cement
	icon_state = "cement_wall0"
/turf/wall/cement/New(var/newloc)
	..(newloc,"concrete")

/* Wood Walls*/
/turf/wall/wood
	icon_state = "wood0"
	ref_state = "wood"
/turf/wall/wood/New(var/newloc)
	..(newloc,"hardwood")
/turf/wall/wood/low/New(var/newloc)
	..(newloc,"hardwood")
	opacity = FALSE
/turf/wall/wood/straw/New(var/newloc)
	..(newloc,"straw")
/turf/wall/wood/soft/New(var/newloc)
	..(newloc,"wood")

/* Stone Walls */

/turf/wall/old_stone
	icon = 'icons/turf/walls.dmi'
	icon_state = "old_stone_wall"

/turf/wall/old_stone/New()
	return
/turf/wall/old_stone/update_icon()
	return
/turf/wall/sandstone
	icon_state = "stone_block_wall0"
/turf/wall/sandstone/New(var/newloc)
	..(newloc,"sandstone")
/turf/wall/stone
	icon_state = "stone_block_wall0"
/turf/wall/stone/New(var/newloc)
	..(newloc,"stone")
/turf/wall/stone/stonebrick
	icon_state = "new_stonebrick0"
/turf/wall/stone/stonebrick/New(var/newloc)
	..(newloc,"stonebrick")
/turf/wall/fortress
	icon = 'icons/turf/walls.dmi'
	icon_state = "fortress_brickwall"
	flags = TURF_HAS_EDGES | SMOOTH_ONLY_WITH_ITSELF

/turf/wall/indestructable
	icon = 'icons/turf/walls.dmi'
	icon_state = "black" // so we look better on the map
	layer=10
/turf/wall/indestructable/black
	color = "#000000"
	density = TRUE
	opacity = TRUE
	layer=10
/turf/wall/indestructable/New(var/newloc)
	icon_state = initial(icon_state)
	..(newloc,"indestructable")
/turf/wall/indestructable/ex_act(severity)
	return FALSE
/turf/wall/silvergold/New(var/newloc)
	..(newloc,"silver","gold")
