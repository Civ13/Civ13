/obj/effect/decal/cleanable
	var/list/random_icon_states = list()
	var/decay_timer = 0
/obj/effect/decal/cleanable/clean_blood(var/ignore = FALSE)
	if (!ignore)
		qdel(src)
		return
	..()

/obj/effect/decal/cleanable/New()
	if (random_icon_states && length(random_icon_states) > 0)
		icon_state = pick(random_icon_states)
	..()
	cleanables += src
	if (decay_timer)
		do_decay()

/obj/effect/decal/cleanable/Destroy()
	cleanables -= src
	..()

/obj/effect/decal/cleanable/proc/do_decay()
	spawn(decay_timer)
		if (src)
			Destroy()