// The craft core (docs/craft-core.md).
//
// A craft is an identity: its name, its crew register, its token on a chart,
// the berth it lies at and the crafts it carries. It has no shape of its own.
// How it physically moves is its body (/datum/craft_body) and what pushes it
// are its drives (/datum/craft_drive), so a new kind of craft is a new body or
// drive and never a second copy of the crew, berth and chart code.
//
// Turf-built vessels (naval/vessel.dm) are the first body: a template body
// wraps a /datum/vessel and forwards to it, so the carrier and the slipway
// ships are crafts without any change to how they sail or save.
//
// Nothing here stores world.time. Crafts are rebuilt from their bodies after
// a load; what must outlive a restart lives in the saved objects that own
// them (a helm's vessel_state, a register's saved fields).

var/global/list/crafts = list()

/datum/craft
	var/name = "craft"
	var/datum/craft_body/body
	var/list/drives = list()             // /datum/craft_drive
	var/datum/craft_register/register
	var/datum/chart_token/token
	var/obj/structure/berth/berth        // Where it lies, or null when under way.
	var/datum/berth_ticket/ticket        // A docking in progress.
	var/datum/craft/carrier              // The craft carrying this one, if any.
	var/list/carried = list()            // Crafts berthed aboard this one.

/datum/craft/New(datum/craft_body/new_body)
	..()
	crafts += src
	if (new_body)
		set_body(new_body)

/datum/craft/Destroy()
	crafts -= src
	stop_sailing()
	turning_to = 0
	clear_path()
	if (grapple)
		grapple.release()
	if (ticket)
		ticket.release()
	if (berth && berth.occupant == src)
		berth.occupant = null
	berth = null
	if (carrier)
		carrier.carried -= src
		carrier = null
	for (var/datum/craft/C in carried)
		C.carrier = null
	carried.Cut()
	if (body)
		body.craft = null
		body = null
	for (var/datum/craft_drive/D in drives)
		D.craft = null
	drives.Cut()
	if (token)
		token.craft = null
		token = null
	register = null
	return ..()

/datum/craft/proc/set_body(datum/craft_body/new_body)
	if (body)
		body.craft = null
	body = new_body
	if (body)
		body.craft = src
		name = body.craft_name() || name

/datum/craft/proc/add_drive(datum/craft_drive/D)
	if (!D || (D in drives))
		return FALSE
	drives += D
	D.craft = src
	return TRUE

/datum/craft/proc/remove_drive(datum/craft_drive/D)
	if (!(D in drives))
		return FALSE
	drives -= D
	D.craft = null
	return TRUE

// The party that owns it, or null while nobody has registered it.
/datum/craft/proc/party()
	return register ? register.party : null

// Tiles of hull: what the drives have to push.
/datum/craft/proc/mass()
	return body ? max(1, body.tile_count()) : 1

// Push from every drive that is switched on and has fuel.
/datum/craft/proc/thrust()
	. = 0
	for (var/datum/craft_drive/D in drives)
		. += D.push()

// Push per tile of hull: what speed and acceleration are worked out from.
/datum/craft/proc/thrust_per_tile()
	return thrust() / mass()

// TRUE when this mob may take the helm. A craft nobody registered is open.
/datum/craft/proc/may_steer(mob/user)
	return register ? register.may_steer(user) : TRUE

// Every craft carried aboard, and those carried by them, nearest first.
/datum/craft/proc/all_carried()
	. = list()
	var/list/queue = carried.Copy()
	while (queue.len)
		var/datum/craft/C = queue[1]
		queue.Cut(1, 2)
		if (C in .)
			continue
		. += C
		queue += C.carried

// Hooks for subtypes and for the systems built on the core. Called by the body
// after a move or a turn it made.
/datum/craft/proc/on_hop(turf/old_origin)
	// A craft that moves has left her berth.
	if (berth)
		cast_off()
	if (token)
		token.follow_craft()

/datum/craft/proc/on_turn(angle)
	if (berth)
		cast_off()

// ---------------------------------------------------------------- bodies

// How a craft physically exists and moves. Subtypes: a template body (a
// turf-built vessel), later a built body (a player hull) and object bodies
// (pods, vehicles, train consists).
/datum/craft_body
	var/datum/craft/craft
	var/last_refusal = ""
	var/last_move_ms = 0

/datum/craft_body/Destroy()
	if (craft && craft.body == src)
		craft.body = null
	craft = null
	return ..()

/datum/craft_body/proc/craft_name()
	return null

// TRUE while the body stands on the map.
/datum/craft_body/proc/placed()
	return FALSE

// Every turf of the body, all levels.
/datum/craft_body/proc/cells()
	return list()

/datum/craft_body/proc/tile_count()
	return length(cells())

/datum/craft_body/proc/contains(turf/T)
	return T in cells()

// The south-west corner of the body's box on its main level, or null.
/datum/craft_body/proc/origin()
	return null

// Where the bow points: a cardinal direction.
/datum/craft_body/proc/heading()
	return NORTH

// Along the bow axis and across it, in tiles.
/datum/craft_body/proc/length_tiles()
	return 1

/datum/craft_body/proc/beam_tiles()
	return 1

// TRUE when the body could stand with its box corner at (x, y), bow to
// heading, writing nothing. The reason it could not is in last_refusal.
/datum/craft_body/proc/can_move_to(x, y, heading)
	last_refusal = "it cannot move"
	return FALSE

// Moves the whole body. TRUE when it moved; it then tells the craft.
/datum/craft_body/proc/move_to(x, y, heading)
	last_refusal = "it cannot move"
	return FALSE

/datum/craft_body/proc/turn_to(heading)
	last_refusal = "it cannot turn"
	return FALSE

// Everything movable aboard, for the move and turn hooks.
/datum/craft_body/proc/aboard()
	. = list()
	for (var/turf/T in cells())
		for (var/atom/movable/M in T)
			if (M.loc != T || QDELETED(M))
				continue
			if (istype(M, /atom/movable/lighting_overlay) || istype(M, /atom/movable/lighting_fullbright))
				continue
			. += M

// A turf-built vessel (naval/vessel.dm) as a body. The vessel keeps every
// rule it has; this only forwards.
/datum/craft_body/template
	var/datum/vessel/vessel

/datum/craft_body/template/New(datum/vessel/V)
	..()
	vessel = V

/datum/craft_body/template/Destroy()
	vessel = null
	return ..()

/datum/craft_body/template/craft_name()
	return vessel ? vessel.name : null

/datum/craft_body/template/placed()
	return vessel && vessel.placed

/datum/craft_body/template/cells()
	return placed() ? vessel.cells() : list()

/datum/craft_body/template/contains(turf/T)
	return placed() && vessel.contains(T)

/datum/craft_body/template/origin()
	return placed() ? locate(vessel.ox, vessel.oy, vessel.base_z) : null

/datum/craft_body/template/heading()
	return vessel ? vessel.dir : NORTH

/datum/craft_body/template/length_tiles()
	return vessel ? vessel.length : 1

/datum/craft_body/template/beam_tiles()
	return vessel ? vessel.beam : 1

/datum/craft_body/template/can_move_to(x, y, heading)
	if (!placed())
		last_refusal = "she is not afloat"
		return FALSE
	. = vessel.plan_move(x, y, heading, vessel.cells(), list(), list())
	if (!.)
		last_refusal = vessel.last_refusal

// The vessel itself tells its craft about every hop and turn
// (datum/vessel/relocate), whoever asked for the move.
/datum/craft_body/template/move_to(x, y, heading)
	if (!placed())
		last_refusal = "she is not afloat"
		return FALSE
	. = vessel.relocate(x, y, heading)
	last_move_ms = vessel.last_hop_ms
	if (!.)
		last_refusal = vessel.last_refusal

/datum/craft_body/template/turn_to(heading)
	if (!placed())
		last_refusal = "she is not afloat"
		return FALSE
	. = vessel.turn_to(heading)
	last_move_ms = vessel.last_hop_ms
	if (!.)
		last_refusal = vessel.last_refusal

// The counter-clockwise angle, as turn() takes it, from one cardinal heading
// to another: 90, 180, -90 or 0.
/proc/craft_turn_angle(old_heading, new_heading)
	. = dir2angle(old_heading) - dir2angle(new_heading)
	if (. > 180)
		. -= 360
	else if (. < -90)
		. += 360

// The craft around a vessel, made the first time it is asked for.
/proc/craft_of_vessel(datum/vessel/V, make = TRUE)
	if (!V || QDELETED(V))
		return null
	for (var/datum/craft/C in crafts)
		var/datum/craft_body/template/B = C.body
		if (istype(B) && B.vessel == V)
			return C
	return make ? new /datum/craft(new /datum/craft_body/template(V)) : null

// The craft standing on this turf, or null.
/proc/craft_at(turf/T)
	if (!T)
		return null
	var/datum/vessel/V = vessel_at(T)
	if (V)
		return craft_of_vessel(V)
	for (var/datum/craft/C in crafts)
		if (C.body && !istype(C.body, /datum/craft_body/template) && C.body.contains(T))
			return C
	return null

// Drops the crafts whose vessel is gone. Called by anything that lists crafts.
/proc/crafts_prune()
	for (var/datum/craft/C in crafts)
		var/datum/craft_body/template/B = C.body
		if (istype(B) && (!B.vessel || QDELETED(B.vessel) || !(B.vessel in naval_vessels)))
			qdel(C)

// ---------------------------------------------------------------- drives

// One source of push: a sail, a bank of oars, an engine, a thruster.
/datum/craft_drive
	var/name = "drive"
	var/datum/craft/craft
	var/thrust = 0             // Push at full power.
	var/enabled = TRUE

/datum/craft_drive/Destroy()
	if (craft)
		craft.drives -= src
		craft = null
	return ..()

// Fuel it holds and can hold, in its own units; a drive that needs none
// (sails, oars) reports a full tank of 1.
/datum/craft_drive/proc/fuel_left()
	return 1

/datum/craft_drive/proc/fuel_capacity()
	return 1

/datum/craft_drive/proc/ready()
	return enabled && fuel_left() > 0

// The push it gives now.
/datum/craft_drive/proc/push()
	return ready() ? thrust : 0

// Takes fuel for a burn at that share of full power. Returns the share of
// the burn it could pay for, 0 to 1.
/datum/craft_drive/proc/burn(share = 1)
	return ready() ? 1 : 0

// ---------------------------------------------------------------- hooks aboard

// Called on everything aboard when its craft has turned. angle is
// counter-clockwise in degrees, as turn() takes it. Objects and creatures
// turn with the craft, so a cannon that pointed over the port rail still
// does. A type whose facing must not follow the hull overrides this.
/atom/movable/proc/craft_turned(datum/craft/C, angle)
	return

/obj/craft_turned(datum/craft/C, angle)
	if (!angle)
		return
	set_dir(turn(dir, angle))

// Loose things keep their place on the deck plank they lie on.
/obj/item/craft_turned(datum/craft/C, angle)
	..()
	if (!pixel_x && !pixel_y)
		return
	var/px = pixel_x
	var/py = pixel_y
	switch (angle)
		if (90)
			pixel_x = -py
			pixel_y = px
		if (-90)
			pixel_x = py
			pixel_y = -px
		if (180, -180)
			pixel_x = -px
			pixel_y = -py

/mob/craft_turned(datum/craft/C, angle)
	if (!angle)
		return
	if (facing_dir)
		facing_dir = turn(facing_dir, angle)
	dir = turn(dir, angle)

// Called on something aboard after a move that carried it, by bodies that
// move things one at a time. A template body moves whole tiles and does not
// call it on a plain hop.
/atom/movable/proc/craft_moved(datum/craft/C, turf/old_loc)
	return
