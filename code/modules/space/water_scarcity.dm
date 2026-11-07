// ============================================================
// Water on airless worlds (space settlement)
// ------------------------------------------------------------
// An ordinary sink, well, puddle, shower or bathtub draws on ground water
// that never runs out. Mars and the Moon have none, so there a newly built
// one starts dry and never refills: settlers get water from ice (the ice
// melter, the electrolyser), the habitat water recycler, or a water tap and
// piped shower on a pipe network (factory_plumbing.dm), all of which run out.
// Nothing is changed on a restored fixture; it just stops refilling.
// ============================================================

// TRUE on a barren world (Mars, the Moon and their colonies).
/proc/barren_world()
	return istype(map, /obj/map_metadata/nomads/barren)

/obj/structure/sink/on_runtime_spawn()
	..()
	if (barren_world())
		volume = 0

// Keeps the refill loop alive, so a sink carried back to a world with
// ground water would refill, but adds nothing here.
/obj/structure/sink/refill()
	if (!barren_world())
		return ..()
	spawn(60)
		refill()

/obj/structure/shower/attack_hand(mob/M as mob)
	if (!on && barren_world() && !istype(src, /obj/structure/shower/piped))
		to_chat(M, SPAN_WARNING("Nothing comes out of \the [src]. There is no ground water here; use a piped shower."))
		return
	return ..()

// A shower left running from before stops on a barren world.
/obj/structure/shower/process()
	if (on && barren_world() && !istype(src, /obj/structure/shower/piped))
		on = FALSE
		update_icon()
		return
	return ..()

// The big bathtub has its own procs that never reach the shower ones above.
/obj/structure/shower/bathtub/big/attack_hand(mob/living/M)
	if (!on && barren_world())
		to_chat(M, SPAN_WARNING("Nothing comes out of \the [src]. There is no ground water here."))
		return
	return ..()

/obj/structure/shower/bathtub/big/process()
	if (on && barren_world())
		on = FALSE
		update_icon()
		return
	return ..()
