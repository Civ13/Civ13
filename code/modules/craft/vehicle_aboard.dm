// ============================================================
// Vehicles aboard a craft (docs/craft-core.md)
// ------------------------------------------------------------
// A modular vehicle parked on a ship's deck or a built hull rides with her:
// every part stands on one of her tiles, so a hop carries it and a turn
// swings it round with the deck. Two things keep it whole:
//
//   - the axis and the wheels of a vehicle sit inside its frames, not on the
//     deck, so the frame that holds the axis turns the vehicle's heading and
//     wheels when the craft turns it. Without that the car would drive off
//     sideways after the ship came about;
//   - a vehicle that stands only partly aboard would be torn in two by a
//     hop, so the craft refuses to move until it is wholly on or wholly off.
// ============================================================

/obj/structure/vehicleparts/frame/craft_turned(datum/craft/C, angle)
	..()
	if (!angle)
		return
	// The frame that holds the axis turns the whole vehicle's heading, and
	// the wheels follow it by the vehicle's own rule (axis.do_matrix()).
	var/obj/structure/vehicleparts/axis/A = axis
	if (A && A.loc == src)
		A.dir = turn(A.dir, angle)
		for (var/obj/structure/vehicleparts/movement/W in A.wheels)
			W.dir = W.reversed ? OPPOSITE_DIR(A.dir) : A.dir
			W.update_icon()
	update_icon()

// The first vehicle with a frame on these turfs and another frame off them,
// or null. turfs is every tile of the craft.
/proc/craft_overhang(list/turfs)
	var/list/seen = list()
	for (var/turf/T in turfs)
		for (var/obj/structure/vehicleparts/frame/F in T)
			var/obj/structure/vehicleparts/axis/A = F.axis
			if (F.loc != T || !A || QDELETED(A) || seen[A])
				continue
			seen[A] = TRUE
			for (var/obj/structure/vehicleparts/frame/O in A.components)
				var/turf/P = get_turf(O)
				if (P && !(P in turfs))
					return A
	return null

// Why a craft on these turfs may not move for what stands half aboard, or null.
/proc/craft_overhang_refusal(list/turfs)
	var/obj/structure/vehicleparts/axis/A = craft_overhang(turfs)
	return A ? "[A.name] stands half aboard and would be torn in two" : null
