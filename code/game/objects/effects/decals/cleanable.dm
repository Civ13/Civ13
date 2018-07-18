/obj/effect/decal/cleanable
	var/list/random_icon_states = list()

/obj/effect/decal/cleanable/clean_blood(var/ignore = FALSE)
	if (!ignore)
		qdel(src)
		return
	..()

/obj/effect/decal/cleanable/New()
	if (random_icon_states && length(random_icon_states) > 0)
		icon_state = pick(random_icon_states)
	..()

	// if we're on a lift, make us an "overlay" (actually in the turf's vis_contents list). We won't move with the lift that way, and a lot of lag will be avoided
	cleanables += src

/obj/effect/decal/cleanable/Destroy()
	cleanables -= src
	..()