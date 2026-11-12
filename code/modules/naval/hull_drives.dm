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
// rigged mast pushes CRAFT_SAIL_THRUST tiles of hull at half ahead.
// ============================================================

#define CRAFT_THRUST_HALF 1
#define CRAFT_THRUST_FULL 2
#define CRAFT_SAIL_THRUST 31

/datum/craft_drive
	// The fastest telegraph step this kind of drive can make.
	var/top_step = VESSEL_SPEED_FULL

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
	return enabled && source && !QDELETED(source) && craft && craft.body && craft.body.contains(get_turf(source)) && isturf(source.loc)

// The drive this thing gives a craft it stands on, or null.
/atom/movable/proc/craft_drive()
	return null

// ---- Sails ----

/datum/craft_drive/fitted/sail
	thrust = CRAFT_SAIL_THRUST
	top_step = VESSEL_SPEED_HALF

/datum/craft_drive/fitted/sail/ready()
	var/obj/structure/vehicleparts/movement/sail/M = source
	return ..() && istype(M) && M.sails && !M.broken

/datum/craft_drive/fitted/sail/under_way(state)
	var/obj/structure/vehicleparts/movement/sail/M = source
	if (!istype(M) || QDELETED(M) || !M.sails)
		return
	M.sails_on = state ? TRUE : FALSE
	M.update_icon()

// A mast standing free on a deck (not fitted to a modular ship's frame).
/obj/structure/vehicleparts/movement/sail/craft_drive()
	return (isturf(loc) && !axis) ? new /datum/craft_drive/fitted/sail(src) : null

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
	for (var/atom/movable/M in body.aboard())
		var/datum/craft_drive/D = M.craft_drive()
		if (D)
			add_drive(D)
	return drives.len

/datum/craft/max_speed()
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

// Sails are set while she is under way and furled when she is not.
/datum/craft/proc/show_drives()
	var/moving = speed > 0 && !anchored
	for (var/datum/craft_drive/D in drives)
		D.under_way(moving && D.ready())

// What drives she has, for the helm.
/datum/craft/proc/drives_text()
	var/list/speeds = list("all stop", "slow ahead", "half ahead", "full ahead")
	var/working = 0
	for (var/datum/craft_drive/D in drives)
		if (D.ready())
			working++
	if (!working)
		return "No sail is rigged: she is poled along at slow ahead."
	return "Under [working] sail[working == 1 ? "" : "s"]: [speeds[max_speed() + 1]] at best."
