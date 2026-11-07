// Steel barrels on pipe networks (factory_pipes.dm). Wrench a steel barrel
// that stands on or beside a fluid pipe to fit it to the network; it then
// supplies what it holds, like a draining barrel station. An open barrel left
// outside keeps catching rain while connected (rain_barrel.dm), so a rain
// barrel can feed taps and tanks. Moving or picking the barrel up detaches it.
// Reuses the steel barrel sprite; no new art.

/obj/item/weapon/reagent_containers/glass/barrel/modern
	var/pipe_connected = FALSE

// The open pipe this barrel stands on or beside, if any.
/obj/item/weapon/reagent_containers/glass/barrel/modern/proc/pipe_beside()
	if (!isturf(loc))
		return null
	var/list/turfs = list(loc)
	for (var/d in cardinal)
		var/turf/T = get_step(loc, d)
		if (T)
			turfs += T
	for (var/turf/T in turfs)
		for (var/obj/structure/fluid_pipe/P in T)
			if (P.fluid_open() && !QDELETED(P))
				return P
	return null

/obj/item/weapon/reagent_containers/glass/barrel/modern/proc/pipe_disconnect(mob/user)
	if (!pipe_connected)
		return
	pipe_connected = FALSE
	fluid_mark_dirty()
	if (user)
		to_chat(user, SPAN_NOTICE("You detach \the [src] from the pipe."))

/obj/item/weapon/reagent_containers/glass/barrel/modern/fluid_pipe_joinable()
	return pipe_connected

/obj/item/weapon/reagent_containers/glass/barrel/modern/fluid_supply_tier()
	return pipe_connected && pipe_beside() ? FLUID_TIER_SOURCE : 0

/obj/item/weapon/reagent_containers/glass/barrel/modern/fluid_supply_holder()
	return pipe_connected ? reagents : null

/obj/item/weapon/reagent_containers/glass/barrel/modern/attackby(obj/item/I, mob/living/user)
	if (!istype(I, /obj/item/weapon/wrench))
		return ..()
	if (pipe_connected)
		playsound(loc, 'sound/items/Ratchet.ogg', 50, TRUE)
		pipe_disconnect(user)
		return TRUE
	if (!isturf(loc) || !pipe_beside())
		to_chat(user, SPAN_WARNING("\The [src] needs to stand on or next to a fastened pipe."))
		return TRUE
	pipe_connected = TRUE
	fluid_mark_dirty()
	playsound(loc, 'sound/items/Ratchet.ogg', 50, TRUE)
	to_chat(user, SPAN_NOTICE("You fit \the [src] to the pipe. While a pump runs, the network draws what it holds."))
	return TRUE

/obj/item/weapon/reagent_containers/glass/barrel/modern/Move()
	. = ..()
	if (. && pipe_connected)
		pipe_disconnect()

/obj/item/weapon/reagent_containers/glass/barrel/modern/forceMove(atom/destination, var/special_event, list/throw_hop_token = null)
	var/atom/old = loc
	. = ..()
	if (pipe_connected && loc != old)
		pipe_disconnect()

/obj/item/weapon/reagent_containers/glass/barrel/modern/Destroy()
	if (pipe_connected)
		pipe_connected = FALSE
		fluid_mark_dirty()
	return ..()

/obj/item/weapon/reagent_containers/glass/barrel/modern/after_load()
	. = ..()
	if (pipe_connected)
		fluid_mark_dirty()

/obj/item/weapon/reagent_containers/glass/barrel/modern/examine(mob/user)
	..()
	if (pipe_connected)
		to_chat(user, SPAN_NOTICE("It is fitted to a pipe, and supplies its network while a pump runs. Use a wrench to detach it."))
	else
		to_chat(user, SPAN_NOTICE("Use a wrench while it stands on or next to a pipe to fit it to the network."))
