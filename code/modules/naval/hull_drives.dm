// ============================================================
// Drives for player-built hulls (docs/craft-core.md)
// ------------------------------------------------------------
// What pushes a built hull is whatever drive stands on her floors. Each
// thing aboard is asked for a drive (craft_drive()); the craft adds up their
// push against her tiles of hull to find the best telegraph step she makes:
//
//   - slow ahead needs nothing: a hull can always be poled along;
//   - half ahead needs CRAFT_THRUST_HALF of push for every tile of hull;
//   - full ahead needs CRAFT_THRUST_FULL per tile from drives that can make
//     full ahead at all. Sails cannot.
//
// A ship mast (15 planks) with a sail rigged on it is the first drive: one
// rigged mast pushes CRAFT_SAIL_THRUST tiles of hull at half ahead on a reach,
// less running before the wind and much less beating into it
// (points_of_sail.dm).
//
// A manned rowing bench is the third (rowing_bench.dm): it can make full
// ahead, and its rower's stamina is the fuel.
//
// Any engine standing aboard and running is the second: it pushes its power
// output, can make full ahead, and burns from its own fuel tank at every hop
// by the telegraph step (an external engine's boiler fire is its fuel).
// ============================================================

#define CRAFT_THRUST_HALF 1
#define CRAFT_THRUST_FULL 2
#define CRAFT_SAIL_THRUST 31

/datum/craft_drive
	// The fastest telegraph step this kind of drive can make.
	var/top_step = VESSEL_SPEED_FULL
	// What the helm calls it.
	var/kind = "drive"
	// FALSE for a drive that tires (oars): a voyage on the world chart is
	// paced by the drives that can keep it up for days.
	var/sustained = TRUE

// Told when the craft gets under way or stops, for sails and smoke.
/datum/craft_drive/proc/under_way(state)
	return

// A drive that is a thing standing aboard.
/datum/craft_drive/fitted
	var/atom/movable/source

/datum/craft_drive/fitted/New(atom/movable/new_source)
	..()
	source = new_source
	if (source)
		name = source.name

/datum/craft_drive/fitted/Destroy()
	source = null
	return ..()

/datum/craft_drive/fitted/ready()
	return enabled && source && !QDELETED(source) && craft && craft.body && craft.body.carries(get_turf(source)) && isturf(source.loc)

// The drive this thing gives a craft it stands on, or null.
/atom/movable/proc/craft_drive()
	return null

// ---- Sails ----

/datum/craft_drive/fitted/sail
	kind = "sail"
	thrust = CRAFT_SAIL_THRUST
	top_step = VESSEL_SPEED_HALF

/datum/craft_drive/fitted/sail/ready()
	var/obj/structure/vehicleparts/movement/sail/M = source
	return ..() && istype(M) && M.sails && !M.broken

// A sail pushes as the wind stands to her bow.
/datum/craft_drive/fitted/sail/push()
	if (!ready())
		return 0
	var/heading = craft && craft.body ? craft.body.heading() : 0
	return round(thrust / sail_delay_factor(heading))

/datum/craft_drive/fitted/sail/under_way(state)
	var/obj/structure/vehicleparts/movement/sail/M = source
	if (!istype(M) || QDELETED(M) || !M.sails)
		return
	M.sails_on = state ? TRUE : FALSE
	M.update_icon()

// A mast standing free on a deck (not fitted to a modular ship's frame).
/obj/structure/vehicleparts/movement/sail/craft_drive()
	return (isturf(loc) && !axis) ? new /datum/craft_drive/fitted/sail(src) : null

// ---- Engines ----

/datum/craft_drive/fitted/engine
	kind = "engine"

/datum/craft_drive/fitted/engine/ready()
	var/obj/structure/engine/E = source
	return ..() && istype(E) && E.on && !E.broken

// An engine pushes what it puts out now: a steam engine with one fire lit
// under it pushes less than one with three.
/datum/craft_drive/fitted/engine/push()
	var/obj/structure/engine/E = source
	return ready() ? max(0, E.maxpower) : 0

/datum/craft_drive/fitted/engine/burn(share = 1)
	var/obj/structure/engine/E = source
	return ready() ? E.craft_burn(share, VESSEL_HOP_INTERVAL / 10) : 0

// Loose on a deck, not fitted to a vehicle's frame.
/obj/structure/engine/craft_drive()
	if (!isturf(loc) || (locate(/obj/structure/vehicleparts/frame) in loc))
		return null
	return new /datum/craft_drive/fitted/engine(src)

// ---- Fitting and speed ----

// Finds every drive aboard again. Called when the hull is commissioned or
// refitted, when a speed is rung and before each hop, so a mast that was
// raised, stripped or shot away counts at once.
/datum/craft/proc/fit_drives()
	for (var/datum/craft_drive/fitted/D in drives)
		D.under_way(FALSE)
		remove_drive(D)
		qdel(D)
	if (!body)
		return 0
	// The same walk weighs her load for the ledger (hull_load.dm).
	var/weighs = ledger && ledger.carries_load()
	var/weight = 0
	var/rigged = 0
	for (var/atom/movable/M in body.aboard())
		var/datum/craft_drive/D = M.craft_drive()
		if (D)
			add_drive(D)
			if (weighs && istype(D, /datum/craft_drive/fitted/sail) && D.ready())
				rigged++
		if (weighs)
			weight += M.hull_load()
	if (weighs)
		ledger.set_load(weight, rigged)
	return drives.len

/datum/craft/max_speed()
	// Running dark (craft_signals.dm) she makes no more than slow ahead.
	if (running_dark)
		return VESSEL_SPEED_SLOW
	var/all = 0
	var/fast = 0
	for (var/datum/craft_drive/D in drives)
		var/push = D.push()
		all += push
		if (D.top_step >= VESSEL_SPEED_FULL)
			fast += push
	var/tiles = mass()
	if (fast / tiles >= CRAFT_THRUST_FULL)
		return VESSEL_SPEED_FULL
	if (all / tiles >= CRAFT_THRUST_HALF)
		return VESSEL_SPEED_HALF
	return VESSEL_SPEED_SLOW

// TRUE when drives that never tire can make full ahead: engines, not oars.
/datum/craft/proc/sustained_full_ahead()
	if (running_dark)
		return FALSE
	var/fast = 0
	for (var/datum/craft_drive/D in drives)
		if (D.sustained && D.top_step >= VESSEL_SPEED_FULL)
			fast += D.push()
	return fast / mass() >= CRAFT_THRUST_FULL

// Sails are set while she is under way and furled when she is not.
/datum/craft/proc/show_drives()
	var/moving = speed > 0 && !anchored
	for (var/datum/craft_drive/D in drives)
		D.under_way(moving && D.ready())

// Every working drive pays for the hop just made, by the telegraph step.
/datum/craft/proc/burn_drives()
	var/share = clamp(speed / VESSEL_SPEED_FULL, 0, 1)
	for (var/datum/craft_drive/D in drives)
		D.burn(share)

// What drives she has, for the helm.
/datum/craft/proc/drives_text()
	var/list/speeds = list("all stop", "slow ahead", "half ahead", "full ahead")
	var/sails = 0
	var/engines = 0
	var/oars = 0
	for (var/datum/craft_drive/D in drives)
		if (!D.ready())
			continue
		switch (D.kind)
			if ("sail")
				sails++
			if ("oars")
				oars++
			else
				engines++
	if (!sails && !engines && !oars)
		return "No sail is rigged, no engine is running and nobody is at the oars: she is poled along at slow ahead."
	var/list/under = list()
	if (sails)
		under += "[sails] sail[sails == 1 ? "" : "s"]"
	if (oars)
		under += "[oars] manned bench[oars == 1 ? "" : "es"] of oars"
	if (engines)
		under += "[engines] engine[engines == 1 ? "" : "s"]"
	var/tiles = mass()
	. = "Under [english_list(under)]: [speeds[max_speed() + 1]] at best. Her drives push [thrust()]; [tiles] tile[tiles == 1 ? "" : "s"] of hull need [tiles * CRAFT_THRUST_HALF] for half ahead and [tiles * CRAFT_THRUST_FULL] from engines or oars for full ahead."
	if (sails && body)
		. += " Her sails are [point_of_sail_name(body.heading())]."
