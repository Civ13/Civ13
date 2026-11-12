// ============================================================
// Torpedoes (docs/naval-mines.md)
// ------------------------------------------------------------
// A torpedo tube is bolted to a deck (or a quay), trained by hand while it is
// unbolted, loaded with a torpedo and fired. The torpedo runs straight out
// along the tube's line, TORPEDO_STEPS_PER_RUN tiles at most, just under the
// surface:
//
//   - A contact pistol goes off when the torpedo strikes a hull: its course
//     has to cross her.
//   - A magnetic pistol also goes off under a steel hull it passes close to,
//     by the same felt-signature rule as a magnetic mine, out to
//     TORPEDO_MAGNETIC_REACH tiles. A wiped or coiled hull lets it run past.
//
// A running torpedo is a naval mine on the move, so it blasts under the hull
// it hits exactly as a mine does, and a hull that runs onto it sets it off.
// It never goes off under the ship that fired it. It stops and sinks when it
// runs out of water or out of run.
// ============================================================

#define TORPEDO_STEPS_PER_RUN 40
#define TORPEDO_STEP_DELAY 2
#define TORPEDO_MAGNETIC_REACH 2
#define TORPEDO_LOAD_TIME (4 SECONDS)

// ---- The torpedo ----

/obj/item/naval_torpedo
	name = "torpedo"
	desc = "A long steel fish of explosive, compressed air and gyroscope, with a contact pistol in its nose. Load it into a torpedo tube."
	icon = 'icons/obj/naval_gear.dmi'
	icon_state = "torpedo"
	w_class = ITEM_SIZE_HUGE
	force = 8
	throwforce = 2
	throw_range = 1
	flags = CONDUCT
	var/run_type = /obj/structure/naval_mine/torpedo

/obj/item/naval_torpedo/magnetic
	name = "magnetic torpedo"
	desc = "A long steel fish of explosive, compressed air and gyroscope, with a magnetic pistol that also fires under a steel hull it passes close to. Load it into a torpedo tube."
	icon_state = "torpedo_magnetic"
	run_type = /obj/structure/naval_mine/torpedo/magnetic

// ---- The running torpedo ----

/obj/structure/naval_mine
	// FALSE for a mine that is not moored, so an Oropesa sweep has nothing to cut.
	var/moored = TRUE

// TRUE when this craft never sets the mine off.
/obj/structure/naval_mine/proc/ignores(datum/craft/C)
	return FALSE

/obj/structure/naval_mine/torpedo
	name = "running torpedo"
	desc = "The wake of a torpedo running just under the surface."
	icon = 'icons/obj/naval_gear.dmi'
	icon_state = "torpedo_running"
	moored = FALSE
	item_type = /obj/item/naval_torpedo
	blast = list(1, 2, 4)
	var/run_left = TORPEDO_STEPS_PER_RUN
	// Off for the probe, which steps the torpedo itself.
	var/run_by_timer = TRUE
	// The craft that fired it (runtime only).
	var/tmp/datum/craft/launcher = null

/obj/structure/naval_mine/torpedo/magnetic
	name = "running magnetic torpedo"
	item_type = /obj/item/naval_torpedo/magnetic
	magnetic = TRUE
	reach = TORPEDO_MAGNETIC_REACH
	blast = list(1, 3, 5)

/obj/structure/naval_mine/torpedo/ignores(datum/craft/C)
	return C && C == launcher

/obj/structure/naval_mine/torpedo/Destroy()
	launcher = null
	return ..()

// After a load it keeps running on whatever run it had left.
/obj/structure/naval_mine/torpedo/after_load()
	..()
	if (run_by_timer)
		addtimer(CALLBACK(src, PROC_REF(run_step)), TORPEDO_STEP_DELAY)

/obj/structure/naval_mine/torpedo/proc/start(datum/craft/from)
	launcher = from
	if (strike_here())
		return
	if (run_by_timer)
		addtimer(CALLBACK(src, PROC_REF(run_step)), TORPEDO_STEP_DELAY)

// One tile of run. FALSE once the torpedo is spent: gone off or sunk.
/obj/structure/naval_mine/torpedo/proc/run_step()
	if (QDELETED(src) || fired)
		return FALSE
	if (run_left <= 0)
		sink("runs out of air and sinks")
		return FALSE
	var/turf/T = get_step(src, dir)
	if (!T)
		sink("sinks")
		return FALSE
	var/datum/craft/C = torpedo_craft_at(T)
	if (!C && !torpedo_water(T))
		sink("runs into the shallows and sinks")
		return FALSE
	run_left--
	forceMove(T)
	if (strike_here())
		return FALSE
	if (run_by_timer)
		addtimer(CALLBACK(src, PROC_REF(run_step)), TORPEDO_STEP_DELAY)
	return TRUE

// Goes off if it is under a hull, or (magnetic) close under a steel one.
/obj/structure/naval_mine/torpedo/proc/strike_here()
	var/turf/T = get_turf(src)
	if (!T)
		return FALSE
	var/datum/craft/C = torpedo_craft_at(T)
	if (C && !ignores(C))
		detonate(C)
		return TRUE
	if (!magnetic)
		return FALSE
	for (var/datum/craft/N in crafts_near(T, reach))
		if (ignores(N) || !N.body)
			continue
		var/list/B = N.body.mine_box()
		if (!B || B[5] != z)
			continue
		var/dx = max(B[1] - x, 0, x - B[3])
		var/dy = max(B[2] - y, 0, y - B[4])
		if (feels(N.magnetic_signature(), max(dx, dy)))
			detonate(N)
			return TRUE
	return FALSE

/obj/structure/naval_mine/torpedo/proc/sink(how)
	if (fired)
		return
	fired = TRUE
	visible_message(SPAN_NOTICE("\The [src] [how]."))
	qdel(src)

// Hit by a hull or a sweep, or caught in a blast: the same as a mine.
/obj/structure/naval_mine/torpedo/attackby(obj/item/W, mob/user)
	user.visible_message(SPAN_DANGER("[user] hits \the [src]!"))
	detonate(null)

/proc/torpedo_water(turf/T)
	return istype(T, /turf/floor/beach/water) && !istype(T, /turf/floor/beach/water/ice)

// The craft over this turf, modular boats included.
/proc/torpedo_craft_at(turf/T)
	if (!T)
		return null
	for (var/obj/structure/vehicleparts/frame/F in T)
		if (F.axis)
			return craft_of_axis(F.axis)
	return craft_at(T)

// The crafts with a cell within r tiles of T.
/proc/crafts_near(turf/T, r)
	. = list()
	if (!T)
		return
	for (var/turf/N in range(r, T))
		var/datum/craft/C = torpedo_craft_at(N)
		if (C && !(C in .))
			. += C

// ---- The tube ----

/obj/structure/torpedo_tube
	name = "torpedo tube"
	desc = "A single steel torpedo tube on a training mount. Train it while it is unbolted, bolt it down with a wrench, load a torpedo and fire it along the line it points."
	icon = 'icons/obj/naval_gear.dmi'
	icon_state = "torpedo_tube"
	anchored = FALSE
	density = TRUE
	flags = CONDUCT
	dir = EAST
	var/loaded = null

/obj/structure/torpedo_tube/proc/aboard()
	if (!isturf(loc))
		return null
	for (var/obj/structure/vehicleparts/frame/F in loc)
		if (F.axis)
			return craft_of_axis(F.axis)
	return craft_at(loc)

// The first tile past her own hull along the tube's line, or null.
/obj/structure/torpedo_tube/proc/muzzle(datum/craft/C)
	var/turf/T = get_turf(src)
	for (var/i = 1, i <= 30 && T, i++)
		T = get_step(T, dir)
		if (!T)
			return null
		if (!C || !C.body || !C.body.contains(T))
			return T
	return null

// Why it cannot fire now, or null.
/obj/structure/torpedo_tube/proc/fire_problem()
	if (!loaded)
		return "\The [src] is empty."
	if (!anchored)
		return "Bolt \the [src] down first."
	var/turf/T = muzzle(aboard())
	if (!T || (!torpedo_water(T) && !torpedo_craft_at(T)))
		return "\The [src] does not point at open water."
	return null

// Fires the torpedo it holds and returns it, or null.
/obj/structure/torpedo_tube/proc/fire(mob/user)
	var/problem = fire_problem()
	if (problem)
		if (user)
			to_chat(user, SPAN_WARNING(problem))
		return null
	var/datum/craft/C = aboard()
	var/turf/T = muzzle(C)
	var/run_type = loaded
	loaded = null
	playsound(loc, 'sound/effects/bang.ogg', 40, TRUE)
	visible_message(SPAN_WARNING("\The [src] fires with a hiss of air and a splash!"))
	var/obj/structure/naval_mine/torpedo/R = new run_type(T)
	R.dir = dir
	R.start(C)
	return R

/obj/structure/torpedo_tube/attack_hand(mob/living/human/H)
	if (!istype(H))
		return ..()
	if (!anchored)
		set_dir(turn(dir, -90))
		H.visible_message(SPAN_NOTICE("[H] trains \the [src] round to face [dir2text(dir)]."))
		return
	if (!loaded)
		to_chat(H, SPAN_WARNING("\The [src] is empty."))
		return
	fire(H)

/obj/structure/torpedo_tube/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/wrench))
		anchored = !anchored
		playsound(loc, 'sound/items/Ratchet.ogg', 50, TRUE)
		user.visible_message(SPAN_NOTICE("[user] [anchored ? "bolts \the [src] to" : "unbolts \the [src] from"] the deck."))
		return
	if (istype(W, /obj/item/naval_torpedo))
		var/obj/item/naval_torpedo/P = W
		if (loaded)
			to_chat(user, SPAN_WARNING("\The [src] is already loaded."))
			return
		user.visible_message(SPAN_NOTICE("[user] starts to slide \the [P] into \the [src]."))
		if (!do_after(user, TORPEDO_LOAD_TIME, src) || QDELETED(P) || loaded)
			return
		loaded = P.run_type
		user.drop_from_inventory(P)
		qdel(P)
		user.visible_message(SPAN_NOTICE("[user] loads \the [src]."))
		return
	return ..()

/obj/structure/torpedo_tube/examine(mob/user)
	..()
	var/load_text = "empty"
	if (loaded)
		load_text = "loaded with a [ispath(loaded, /obj/structure/naval_mine/torpedo/magnetic) ? "magnetic" : "contact"] torpedo"
	to_chat(user, SPAN_NOTICE("It points [dir2text(dir)], is [load_text][anchored ? "" : " and is not bolted down"]."))
