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
	var/datum/extraction_vehicle_codec/codec = new
	var/list/snapshot = codec.encode(A)
	equipment_assert(snapshot && codec.validate(snapshot), "vehicle codec captures actual bounded parts and fuel: [codec.last_error]")
	var/list/invalid = json_decode(json_encode(snapshot))
	invalid["nodes"][1]["parent"] = 1
	equipment_assert(!codec.validate(invalid) && !codec.decode(invalid, start), "self-parent vehicle graph rejected before construction")
	invalid = json_decode(json_encode(snapshot))
	invalid["nodes"][1]["type"] = 42
	equipment_assert(!codec.validate(invalid), "nontext vehicle type rejected without resolving a path")
	invalid = json_decode(json_encode(snapshot))
	invalid["nodes"][2]["id"] = invalid["nodes"][1]["id"]
	equipment_assert(!codec.validate(invalid), "duplicate physical part identities rejected")
	invalid = json_decode(json_encode(snapshot))
	invalid["nodes"][1]["scalars"]["driver"] = "untrusted"
	equipment_assert(!codec.validate(invalid), "session and driver state cannot enter restored vehicle vars")
	var/datum/extraction_service/C = new
	C.store.root = "data/vehicle_accounts/"
	var/datum/extraction_session/session = C.open("vehicleowner")
	var/list/profile = session.copy_profile()
	profile["garage"] = list(snapshot)
	equipment_assert(session.commit(profile), "actual vehicle snapshot commits through native account journal")
	var/list/owned_ids = C.store.recovery_ids(session.profile)
	equipment_assert(owned_ids[snapshot["id"]] && owned_ids.len == snapshot["nodes"].len, "every garage part participates in account ownership inventory")
	session.close()
	for (var/atom/movable/O in originals) qdel(O)
	var/datum/extraction_service/restarted = new
	restarted.store.root = C.store.root
	session = restarted.open("vehicleowner")
	equipment_assert(session && json_encode(session.profile["garage"][1]) == json_encode(snapshot), "new account service reads exact committed garage graph from disk")
	var/obj/structure/vehicleparts/axis/restored = codec.decode(session.profile["garage"][1], start)
	equipment_assert(restored && restored != A && restored.engine.fueltank.reagents.total_volume == 17 && restored.extraction_vehicle_part_id == snapshot["id"], "explicit vehicle graph restores identity and actual fuel without free constructor fuel")
	var/obj/structure/vehicleparts/frame/restored_frame = restored.loc
	equipment_assert(restored_frame.w_front[5] == 73 && restored.wheels.len == 4 && restored.wheel.control:axis == restored, "vehicle graph restores wall condition and assembled wheel links")
	var/datum/extraction_vehicle_transfer/cleanup = new
	equipment_assert(cleanup.capture(restored), "restored car remains eligible for bounded physical transfer")
	for (var/atom/movable/O in cleanup.parts) qdel(O)
	session.close()
	qdel(W)
