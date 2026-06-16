/obj/effect/decal/point
	name = "arrow"
	desc = "It's an arrow hanging in mid-air. There may be a wizard about."
	icon = 'icons/mob/screen/effects.dmi'
	icon_state = "arrow"
	layer = 16.0
	anchored = TRUE
	mouse_opacity = FALSE
	should_save = 0

// Used for spray that you spray at walls, tables, hydrovats etc
/obj/effect/decal/spraystill
	density = FALSE
	anchored = TRUE
	layer = 50

/obj/effect/decal/rubbish
	name = "rubbish"
	desc = "A pile of rubbish."
	icon = 'icons/obj/trash.dmi'
	icon_state = "trash_1"
	var/random = TRUE

/obj/effect/decal/rubbish/New()
	..()
	if (random)
		icon_state = "trash_[rand(1,17)]"
		update_icon()

/obj/effect/decal/piping
	name = "pipes"
	desc = "A bunch of pipes taking something somewhere."
	icon = 'icons/obj/machines/pipes.dmi'
	icon_state = "intact"
	layer = 2.99

/obj/effect/decal/piping/manifold
	icon_state = "manifold"

/obj/effect/decal/piping/blue
	icon_state = "intact-db"

/obj/effect/decal/piping/blue/manifold
	icon_state = "manifold-db"

/obj/effect/decal/piping/yellow
	icon_state = "intact-y"

/obj/effect/decal/piping/green
	icon_state = "intact-g-f"

/obj/effect/decal/piping/purple
	icon_state = "intact-p"

/obj/effect/decal/piping/red
	icon_state = "intact-r"

/obj/effect/decal/piping/meter
	name = "pipe meter"
	desc = "A pipe meter."
	icon_state = "meter"
	layer = 3.01