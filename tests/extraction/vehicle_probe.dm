/proc/extraction_vehicle_probe()
	// Paid acquisition is covered by car_workshop. This fixture exercises the
	// real assembled graph and relocation without account/garage credit claims.
	for (var/x in 30 to 47)
		for (var/y in 30 to 47)
			var/turf/T = locate(x,y,3)
			for (var/atom/movable/O in T) qdel(O)
			T.ChangeTurf(/turf/floor, FALSE, FALSE)
	var/obj/structure/car_workshop/W = new(locate(30,30,3))
	var/obj/effects/premadevehicles/asno/piccolino/template = new(null, TRUE)
	var/obj/structure/vehicleparts/axis/A = W.assemble_layout(template, 3)
	qdel(template)
	equipment_assert(A && A.engine && A.engine.fueltank && A.wheel, "vehicle probe uses real assembled car graph")
	var/obj/structure/engine/internal/E = A.engine
	var/obj/item/tank = E.fueltank
	var/obj/structure/vehicleparts/frame/damaged = A.loc
	damaged.w_front[5] = 73
	E.fueltank.reagents.add_reagent(E.fuels[1], 17, safety = TRUE)
	var/datum/extraction_vehicle_transfer/transfer = new
	A.moving = TRUE
	equipment_assert(!transfer.capture(A), "moving vehicle cannot enter garage transfer")
	A.moving = FALSE
	var/captured = transfer.capture(A)
	equipment_assert(captured, "stopped empty bounded car can be captured: [transfer.last_error]")
	var/turf/start = get_turf(A)
	var/obj/item/cargo = new(start)
	equipment_assert(!transfer.relocate(locate(40,40,3)) && get_turf(A) == start, "unexpected cargo invalidates preflight without moving car")
	qdel(cargo)
	cargo = new(A.loc)
	equipment_assert(!transfer.relocate(locate(40,40,3)) && get_turf(A) == start, "unexpected nested cargo cannot hitchhike inside frame")
	qdel(cargo)
	var/obj/blocker = new(locate(40,40,3))
	equipment_assert(!transfer.relocate(locate(40,40,3)) && get_turf(A) == start, "occupied garage preflight leaves actual vehicle in place")
	qdel(blocker)
	A.engine = null
	equipment_assert(!transfer.relocate(locate(40,40,3)) && get_turf(A) == start, "detached engine rejects stale vehicle transfer")
	A.engine = E
	var/list/originals = transfer.parts.Copy()
	equipment_assert(transfer.relocate(locate(40,40,3)), "clear garage relocates actual assembled car")
	equipment_assert(get_turf(A) == locate(40,40,3) && A.engine == E && E.fueltank == tank && damaged.w_front[5] == 73 && E.fueltank.reagents.total_volume == 17, "same engine tank wall damage and fuel survive physical transfer")
	for (var/atom/movable/O in originals)
		var/turf/T = get_turf(O)
		equipment_assert(O.loc && T && T.z == 3 && get_dist(O, get_turf(A)) <= 3, "original vehicle atom retained at garage footprint")
	equipment_assert(!transfer.relocate(start), "consumed transfer cannot replay")
	equipment_assert(A.check_matrix() && A.wheels.len == 4 && A.wheel.control:axis == A, "turning wheel and steering links remain assembled")
	for (var/atom/movable/O in originals) qdel(O)
	qdel(W)
