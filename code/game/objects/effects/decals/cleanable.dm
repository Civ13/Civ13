/obj/effect/decal/cleanable
	var/list/random_icon_states = list()
	var/decay_timer = 0
	var/tmp/decay_deadline = null
	var/tmp/decay_index = 0
/obj/effect/decal/cleanable/clean_blood(var/ignore = FALSE)
	if (!ignore)
		qdel(src)
		return
	..()

/obj/effect/decal/cleanable/New()
	var/bare_water = FALSE
	if (istype(loc, /turf/floor/beach/water))
		var/found = FALSE
		for(var/obj/covers/C in loc)
			found = TRUE
			break
		if (!found)
			bare_water = TRUE
	if (random_icon_states && length(random_icon_states) > 0)
		icon_state = pick(random_icon_states)
	..()
	cleanables += src
	if (decay_timer)
		do_decay()
	if (bare_water)
		schedule_decay(10)

/obj/effect/decal/cleanable/Destroy()
	unregister_decay()
	cleanables -= src
	..()

/obj/effect/decal/cleanable/proc/do_decay()
	if (decay_timer > 0)
		schedule_decay(decay_timer)

// Legacy custom saves export tmp vars unless explicitly excluded.
/obj/effect/decal/cleanable/persistence_runtime_var(key)
	if (key == "decay_deadline" || key == "decay_index")
		return TRUE
	return ..()

/obj/effect/decal/cleanable/after_load()
	..()
	unregister_decay()
	do_decay()

/obj/effect/decal/cleanable/Del()
	unregister_decay()
	cleanables -= src
	return ..()

/obj/effect/decal/cleanable/proc/schedule_decay(delay)
	if (gcDestroyed || delay < 0)
		return
	var/deadline = world.time + delay
	if (isnull(decay_deadline) || deadline < decay_deadline)
		decay_deadline = deadline
	if (!decay_index)
		timed_cleanables += src
		decay_index = timed_cleanables.len

/obj/effect/decal/cleanable/proc/unregister_decay()
	if (!decay_index)
		return
	var/obj/effect/decal/cleanable/last = timed_cleanables[timed_cleanables.len]
	timed_cleanables[decay_index] = last
	last.decay_index = decay_index
	timed_cleanables.Cut(timed_cleanables.len, timed_cleanables.len + 1)
	decay_index = 0
	decay_deadline = null

/obj/effect/decal/cleanable/graffiti
	name = "graffiti"
	desc = "A graffiti made with paint."
	icon = 'icons/obj/decals.dmi'
	icon_state = "graffiti1"

	New()
		..()
		icon_state = "graffiti[rand(1,3)]"

/obj/effect/decal/cleanable/graffiti_grove
	name = "Grove Street graffiti"
	desc = "A graffiti made with a spraycan."
	icon = 'icons/obj/decals.dmi'
	icon_state = "graffiti_grove"

/obj/effect/decal/cleanable/graffiti_ballas
	name = "Rollin Heights Ballas graffiti"
	desc = "A graffiti made with a spraycan."
	icon = 'icons/obj/decals.dmi'
	icon_state = "graffiti_ballas"