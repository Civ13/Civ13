// ============================================================
// Tow lines between modular vehicles (docs/craft-core.md)
// ------------------------------------------------------------
// A rope hitches one vehicle behind another: line the towed vehicle up
// behind the tug, facing the same way, within TOW_REACH tiles, and use a rope
// on it. From then on the towed vehicle repeats what the tug does, as many
// tiles later as it stands behind: it rolls forward when the tug rolls
// forward and turns where the tug turned. It needs no engine, fuel or sound
// tracks of its own, but its weight is added to the tug's.
//
// The line parts when the towed vehicle falls more than TOW_SLACK tiles
// behind (something is in its way, or it cannot make a turn), when either
// vehicle is destroyed, or when somebody casts it off. A tug cannot reverse
// with a line out. Nothing of it is saved.
//
// Everything here hooks the vehicle code by overriding its procs and calling
// on to them, so the vehicle files stay as they are.
// ============================================================

#define TOW_REACH 2
#define TOW_SLACK 3
#define TOW_MOVE "move"

/obj/structure/vehicleparts/axis
	var/tmp/datum/vehicle_tow/tow_out    // the line to what this vehicle tows
	var/tmp/datum/vehicle_tow/tow_in     // the line to what tows this vehicle

/obj/structure/vehicleparts/axis/persistence_runtime_var(key)
	return key == "tow_out" || key == "tow_in" || ..(key)

/datum/vehicle_tow
	var/obj/structure/vehicleparts/axis/tug
	var/obj/structure/vehicleparts/axis/towed
	// Tiles the towed vehicle stands behind the tug.
	var/gap = 1
	// What the towed vehicle has still to do: TOW_MOVE, "left" or "right".
	var/list/queue = list()
	var/last_warning = 0

/datum/vehicle_tow/New(obj/structure/vehicleparts/axis/new_tug, obj/structure/vehicleparts/axis/new_towed, new_gap)
	..()
	tug = new_tug
	towed = new_towed
	gap = max(1, new_gap)
	for (var/i = 1, i <= gap, i++)
		queue += TOW_MOVE
	tug.tow_out = src
	towed.tow_in = src
	for (var/obj/structure/vehicleparts/frame/F in (tug.components | towed.components))
		F.verbs |= /obj/structure/vehicleparts/frame/proc/cast_off_tow_line

/datum/vehicle_tow/Destroy()
	for (var/obj/structure/vehicleparts/axis/A in list(tug, towed))
		var/still = (A.tow_out && A.tow_out != src) || (A.tow_in && A.tow_in != src)
		if (!still)
			for (var/obj/structure/vehicleparts/frame/F in A.components)
				F.verbs -= /obj/structure/vehicleparts/frame/proc/cast_off_tow_line
	if (tug && tug.tow_out == src)
		tug.tow_out = null
	if (towed && towed.tow_in == src)
		towed.tow_in = null
	tug = null
	towed = null
	queue = list()
	return ..()

// Moves the towed vehicle still owes the tug.
/datum/vehicle_tow/proc/owed()
	. = -gap
	for (var/act in queue)
		if (act == TOW_MOVE)
			.++

// Lets the line go. With give_rope the rope lands beside the towed vehicle.
/datum/vehicle_tow/proc/part(reason = null, give_rope = FALSE)
	var/obj/structure/vehicleparts/axis/B = towed
	var/turf/T = B ? get_turf(B) : null
	if (reason && T)
		T.visible_message(SPAN_WARNING(reason))
	if (give_rope && T)
		new /obj/item/stack/material/rope(T)
	qdel(src)

// Why the towed vehicle cannot roll one tile forward, or null.
/datum/vehicle_tow/proc/blocked_ahead()
	var/obj/structure/vehicleparts/axis/B = towed
	B.add_transporting(FALSE)
	var/afloat = istype(B, /obj/structure/vehicleparts/axis/ship)
	for (var/obj/structure/vehicleparts/frame/F in B.components)
		if (QDELETED(F) || F.axis != B || !isturf(F.loc))
			continue
		var/turf/T = get_step(F, B.dir)
		if (!T)
			return "the edge of the world"
		var/own = FALSE
		for (var/obj/structure/vehicleparts/frame/O in T)
			if (O.axis == B)
				own = TRUE
			else
				return "[O.name]"
		if (own)
			continue
		if (T.density)
			return "[T.name]"
		var/wet = istype(T, /turf/floor/beach/water) || istype(T, /turf/floor/trench/flooded)
		if (afloat && !wet)
			return "[T.name]"
		if (!afloat && istype(T, /turf/floor/beach/water/deep))
			var/bridged = FALSE
			for (var/obj/covers/C in T)
				if (!C.density)
					bridged = TRUE
			if (!bridged)
				return "deep water"
		for (var/atom/movable/M in T)
			if (M.loc != T || (M in B.transporting))
				continue
			if (isliving(M))
				return "[M.name]"
			if (isobj(M) && M.density)
				return "[M.name]"
	return null

// The towed vehicle does what it has reached in the queue: any turns that
// come first, then one roll forward for each tile it has fallen behind.
/datum/vehicle_tow/proc/follow()
	var/obj/structure/vehicleparts/axis/B = towed
	if (!tug || !B || QDELETED(tug) || QDELETED(B))
		qdel(src)
		return FALSE
	var/steps = 0
	while (queue.len && steps < 2)
		var/act = queue[1]
		if (act == TOW_MOVE)
			if (owed() <= 0)
				break
			if (blocked_ahead())
				break
			var/was_reverse = B.reverse
			B.reverse = FALSE
			var/rolled = B.do_move()
			B.reverse = was_reverse
			if (!rolled)
				break
			queue.Cut(1, 2)
			steps++
			continue
		if (isemptylist(B.corners) || !B.corners[1])
			B.check_corners()
		if (isemptylist(B.matrix))
			B.check_matrix()
		if (!B.do_matrix(B.dir, turn(B.dir, act == "left" ? 90 : -90), act))
			break
		queue.Cut(1, 2)
	if (owed() > TOW_SLACK)
		var/why = blocked_ahead()
		part("The tow line to \the [B] snaps[why ? ": [why] is in its way" : ""]!")
		return FALSE
	return TRUE

/datum/vehicle_tow/proc/tug_moved()
	queue += TOW_MOVE
	return follow()

/datum/vehicle_tow/proc/tug_turned(tdir)
	queue += tdir
	return follow()

// ---- Hooks into the vehicle ----

/obj/structure/vehicleparts/axis/do_move()
	if (tow_out && reverse)
		if (world.time >= tow_out.last_warning + 50)
			tow_out.last_warning = world.time
			visible_message(SPAN_WARNING("\The [src] cannot reverse with a tow line out. Cast it off first."))
		return FALSE
	. = ..()
	if (. && tow_out)
		tow_out.tug_moved()

/obj/structure/vehicleparts/axis/do_matrix(var/olddir = 0, var/newdir = 0, var/tdir = "none", var/mob/user = null)
	. = ..()
	if (. && tow_out)
		tow_out.tug_turned(tdir)

// A tug pulls the weight of what it tows.
/obj/structure/vehicleparts/axis/get_weight()
	. = ..()
	if (tow_out && tow_out.towed && !QDELETED(tow_out.towed))
		current_weight += tow_out.towed.get_weight()
		. = current_weight

/obj/structure/vehicleparts/axis/Destroy()
	if (tow_out)
		tow_out.part("The tow line falls slack.")
	if (tow_in)
		tow_in.part("The tow line falls slack.")
	return ..()

// ---- Hitching ----

// The vehicle this one could be hitched behind: list(tug axis, tiles between
// the two axes along their heading), or null with a reason in tow_refusal.
/obj/structure/vehicleparts/axis/var/tmp/tow_refusal = ""

/obj/structure/vehicleparts/axis/proc/tow_plan()
	tow_refusal = "no vehicle stands within [TOW_REACH] tiles ahead of it"
	var/obj/structure/vehicleparts/axis/found = null
	for (var/obj/structure/vehicleparts/frame/F in components)
		if (QDELETED(F) || F.axis != src || !isturf(F.loc))
			continue
		var/turf/T = F.loc
		for (var/n = 0, n <= TOW_REACH, n++)
			T = get_step(T, dir)
			if (!T || T.density)
				break
			var/obj/structure/vehicleparts/axis/other = null
			var/own = FALSE
			for (var/obj/structure/vehicleparts/frame/O in T)
				if (O.axis == src)
					own = TRUE
				else if (O.axis && !QDELETED(O.axis))
					other = O.axis
			if (own)
				break
			if (other)
				found = other
				break
		if (found)
			break
	if (!found)
		return null
	if (found.dir != dir)
		tow_refusal = "it must face the same way as \the [found]"
		return null
	if (istype(src, /obj/structure/vehicleparts/axis/aircraft) || istype(found, /obj/structure/vehicleparts/axis/aircraft))
		tow_refusal = "aircraft are not towed"
		return null
	if (istype(src, /obj/structure/vehicleparts/axis/ship) != istype(found, /obj/structure/vehicleparts/axis/ship))
		tow_refusal = "a boat tows a boat and a vehicle tows a vehicle"
		return null
	if (found.tow_out)
		tow_refusal = "\the [found] already tows something"
		return null
	if (moving || currentspeed > 0 || found.moving || found.currentspeed > 0)
		tow_refusal = "both must stand still"
		return null
	// Never a ring of tows.
	var/obj/structure/vehicleparts/axis/up = found
	while (up)
		if (up == src)
			tow_refusal = "\the [found] is towed by this one"
			return null
		up = up.tow_in ? up.tow_in.tug : null
	var/turf/mine = get_turf(src)
	var/turf/theirs = get_turf(found)
	var/between = (dir & (NORTH | SOUTH)) ? abs(theirs.y - mine.y) : abs(theirs.x - mine.x)
	return list(found, max(1, between))

// Hitches this vehicle behind the one ahead. Returns the line, or null with
// tow_refusal set.
/obj/structure/vehicleparts/axis/proc/hitch_tow()
	if (tow_in)
		tow_refusal = "it is already on a tow line"
		return null
	var/list/plan = tow_plan()
	if (!plan)
		return null
	return new /datum/vehicle_tow(plan[1], src, plan[2])

/obj/structure/vehicleparts/axis/proc/tow_text()
	var/list/lines = list()
	if (tow_in && tow_in.tug)
		lines += "A tow line runs from it to \the [tow_in.tug] ahead."
	if (tow_out && tow_out.towed)
		lines += "It tows \the [tow_out.towed]."
	return jointext(lines, " ")

/obj/structure/vehicleparts/frame/examine(mob/user)
	..()
	if (axis && (axis.tow_in || axis.tow_out))
		to_chat(user, SPAN_NOTICE("[axis.tow_text()] Right-click it and choose Cast Off Tow Line to let go."))

// A rope on a vehicle hitches it behind the vehicle ahead.
/obj/structure/vehicleparts/frame/attackby(var/obj/item/I, var/mob/living/human/H)
	if (!istype(I, /obj/item/stack/material/rope) || !axis || !istype(H))
		return ..()
	var/obj/item/stack/material/rope/R = I
	if (axis.tow_in)
		to_chat(H, SPAN_WARNING("[axis.tow_text()] Right-click it and choose Cast Off Tow Line to let go."))
		return
	var/obj/structure/vehicleparts/axis/A = axis
	var/list/plan = A.tow_plan()
	if (!plan)
		to_chat(H, SPAN_WARNING("You cannot hitch \the [A] to a tow: [A.tow_refusal]. Line it up behind the towing vehicle, facing the same way, within [TOW_REACH] tiles."))
		return
	var/obj/structure/vehicleparts/axis/tug = plan[1]
	H.visible_message(SPAN_NOTICE("[H] starts making a tow line fast between \the [tug] and \the [A]..."))
	if (!do_after(H, 50, src) || QDELETED(A) || QDELETED(R) || R.loc != H)
		return
	if (!R.can_use(1))
		return
	if (!A.hitch_tow())
		to_chat(H, SPAN_WARNING("You cannot hitch \the [A] to a tow: [A.tow_refusal]."))
		return
	R.use(1)
	log_game("[key_name(H)] hitched [A] behind [tug] at [x],[y],[z].")
	H.visible_message(SPAN_NOTICE("[H] hitches \the [A] behind \the [tug]. It follows wherever the [tug.name] drives, and comes loose if it is left more than [TOW_SLACK] tiles behind."))

// Added to the frames of both vehicles while a line joins them.
/obj/structure/vehicleparts/frame/proc/cast_off_tow_line()
	set name = "Cast Off Tow Line"
	set category = null
	set src in view(1)
	var/mob/living/human/H = usr
	if (!istype(H) || H.incapacitated() || !in_range(src, H) || !axis)
		return
	var/datum/vehicle_tow/line = axis.tow_in || axis.tow_out
	if (!line)
		verbs -= /obj/structure/vehicleparts/frame/proc/cast_off_tow_line
		return
	var/obj/structure/vehicleparts/axis/tug = line.tug
	var/obj/structure/vehicleparts/axis/towed = line.towed
	if (tug.moving && tug.currentspeed > 0)
		to_chat(H, SPAN_WARNING("Stop \the [tug] before casting off the tow line."))
		return
	log_game("[key_name(H)] cast off the tow line between [tug] and [towed] at [x],[y],[z].")
	H.visible_message(SPAN_NOTICE("[H] casts off the tow line between \the [tug] and \the [towed]."))
	line.part(null, TRUE)
