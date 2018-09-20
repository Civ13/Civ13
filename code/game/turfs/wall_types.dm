/turf/wall/iron/New(var/newloc)
	..(newloc,"iron")
/turf/wall/brick/New(var/newloc)
	..(newloc,"brick")
/turf/wall/diamond/New(var/newloc)
	..(newloc,"diamond")
/turf/wall/gold/New(var/newloc)
	..(newloc,"gold")
/turf/wall/silver/New(var/newloc)
	..(newloc,"silver")
/turf/wall/stone/New(var/newloc)
	..(newloc,"stone")
/turf/wall/sandstone/New(var/newloc)
	..(newloc,"sandstone")
/turf/wall/wood/New(var/newloc)
	..(newloc,"hardwood")
/turf/wall/wood/low/New(var/newloc)
	..(newloc,"hardwood")
	opacity = FALSE

/turf/wall/wood/straw/New(var/newloc)
	..(newloc,"staw")

/turf/wall/wood/soft/New(var/newloc)
	..(newloc,"softwood")
/turf/wall/old_stone
	icon = 'icons/turf/walls.dmi'
	icon_state = "old_stone_wall"
/turf/wall/indestructable
	icon = 'icons/turf/walls.dmi'
	icon_state = "black" // so we look better on the map
/turf/wall/indestructable/black
	color = "#000000"
	density = TRUE
	opacity = TRUE
/turf/wall/indestructable/New(var/newloc)
	icon_state = initial(icon_state)
	..(newloc,"indestructable")
/turf/wall/indestructable/ex_act(severity)
	return FALSE
/turf/wall/silvergold/New(var/newloc)
	..(newloc,"silver","gold")
