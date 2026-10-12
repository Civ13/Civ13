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
	var/obj/structure/table/carboot/boot
	for (var/obj/structure/table/carboot/B in originals) boot = B
	equipment_assert(boot, "assembled car supplies actual boot cargo tile")
	var/obj/item/extraction_salvage/boot_item = new(get_turf(boot))
	boot_item.extraction_item_id = new_extraction_item_id()
	boot_item.extraction_found_in_raid = TRUE
	var/cargo_id = boot_item.extraction_item_id
	var/obj/item/weapon/storage/backpack/cargo_bag = new(get_turf(boot))
	var/obj/item/extraction_salvage/cargo_child = new(cargo_bag)
	cargo_child.health = 37
	equipment_assert(!transfer.capture(A) && transfer.capture(A, TRUE), "boot cargo requires explicit bounded transfer policy")
	var/list/extra_cargo = list()
	for (var/i in 1 to 7) extra_cargo += new /obj/item/extraction_salvage(get_turf(boot))
	equipment_assert(!transfer.capture(A, TRUE), "nine cargo roots exceed boot capacity before movement")
	for (var/obj/item/I in extra_cargo) qdel(I)
	equipment_assert(transfer.capture(A, TRUE), "removing excess cargo restores bounded transfer eligibility")
	cargo_child.health = 36
	equipment_assert(!transfer.current(), "nested cargo change invalidates captured transfer")
	cargo_child.health = 37
	equipment_assert(transfer.current(), "unchanged nested cargo validates before physical relocation")
	var/list/snapshot = codec.encode(A)
	equipment_assert(snapshot && codec.validate(snapshot), "vehicle codec captures actual bounded parts and fuel: [codec.last_error]")
	equipment_assert(snapshot["cargo"].len == 2 && snapshot["cargo"][1]["id"] == cargo_id, "garage cargo records original equipment identity")
	var/list/invalid = json_decode(json_encode(snapshot))
	invalid["cargo"][1]["dx"] = 3
	invalid["cargo"][1]["dy"] = 3
	equipment_assert(!codec.validate(invalid), "cargo cannot restore away from an actual boot tile")
	invalid = json_decode(json_encode(snapshot))
	invalid["cargo"][1]["id"] = snapshot["id"]
	invalid["cargo"][1]["equipment"]["nodes"][1]["id"] = snapshot["id"]
	equipment_assert(!codec.validate(invalid), "cargo and car part identities cannot collide")
	invalid = json_decode(json_encode(snapshot))
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
	equipment_assert(owned_ids[snapshot["id"]] && owned_ids[cargo_id] && owned_ids[cargo_child.extraction_item_id] && owned_ids.len == snapshot["nodes"].len + 3, "garage parts and nested cargo participate in account ownership inventory")
	equipment_assert(!A.should_save && !damaged.should_save && !E.should_save && !tank.should_save && !boot_item.should_save && !cargo_bag.should_save && !cargo_child.should_save, "account vehicle parts and nested cargo cannot also enter world-save ownership")
	var/list/collision = session.copy_profile()
	collision["stash"] = list(snapshot["cargo"][1])
	equipment_assert(!C.store.recovery_ids(collision), "stash cannot also own committed garage cargo")
	session.close()
	qdel(boot_item)
	qdel(cargo_child)
	qdel(cargo_bag)
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
	equipment_assert(cleanup.capture(restored, TRUE) && cleanup.cargo.len == 2, "restored car remains eligible for bounded cargo transfer")
	var/obj/item/restored_cargo = cleanup.cargo[1]
	equipment_assert(restored_cargo.extraction_item_id == cargo_id && restored_cargo.extraction_found_in_raid, "cargo roundtrip retains identity and raid provenance")
	var/obj/item/weapon/storage/backpack/restored_bag = cleanup.cargo[2]
	var/obj/item/restored_child = locate(/obj/item/extraction_salvage) in restored_bag
	equipment_assert(restored_child && restored_child.extraction_item_id == cargo_child.extraction_item_id && restored_child.health == 37, "nested cargo retains original identity containment and condition")
	equipment_assert(cleanup.relocate(locate(40,40,3)), "bounded car relocates with actual boot cargo")
	var/turf/moved_cargo_turf = get_turf(restored_cargo)
	equipment_assert(moved_cargo_turf.z == 3 && get_dist(moved_cargo_turf, get_turf(restored)) <= 3 && restored_child.loc == restored_bag && restored_child.health == 37, "physical cargo transfer retains actual root and nested atoms")
	for (var/atom/movable/O in cleanup.parts) qdel(O)
	session.close()
	qdel(W)
	var/obj/map_metadata/extraction_survival/M = map
	var/datum/extraction_session/seed = M.accounts.open("garageguest")
	profile = seed.copy_profile()
	profile["garage"] = list(snapshot)
	equipment_assert(seed.commit(profile), "private bay fixture owns committed vehicle before admission")
	seed.close()
	var/mob/living/human/owner = new(locate(3,3,1))
	owner.m_intent = "stealth"
	M.test_owners[owner] = "garageguest"
	equipment_assert(M.admit(owner), "account admission restores car into private bay")
	var/datum/extraction_session/private_session = owner.extraction_session
	equipment_assert(private_session.garage_vehicle && get_turf(private_session.garage_vehicle) == M.garage_anchor(private_session) && !M.home_roots(private_session).len, "private tank car parts and cargo do not duplicate into loose stash")
	var/obj/structure/vehicleparts/axis/private_car = private_session.garage_vehicle
	var/datum/extraction_vehicle_transfer/private_transfer = new
	equipment_assert(private_transfer.capture(private_car, TRUE) && private_transfer.cargo.len == 2, "private bay materializes committed cargo once")
	var/obj/item/unloaded = private_transfer.cargo[1]
	var/turf/boot_turf = get_turf(unloaded)
	unloaded.forceMove(get_turf(private_session.house))
	equipment_assert(M.save_home(private_session) && private_session.profile["stash"].len == 1 && private_session.profile["garage"][1]["cargo"].len == 1, "unloading cargo transfers ownership into stash in one snapshot")
	unloaded.forceMove(boot_turf)
	equipment_assert(M.save_home(private_session) && !private_session.profile["stash"].len && private_session.profile["garage"][1]["cargo"].len == 2, "loading cargo removes duplicate stash ownership in same snapshot")
	private_car.engine.fueltank.reagents.remove_any(3)
	var/obj/structure/vehicleparts/frame/private_frame = private_car.loc
	private_frame.w_front[5] = 61
	equipment_assert(M.save_home(private_session), "private garage condition checkpoints through same account transaction")
	private_car.moving = TRUE
	var/revision = private_session.profile["revision"]
	equipment_assert(!M.save_home(private_session) && !M.release(private_session) && private_session.profile["revision"] == revision && private_session.garage_vehicle == private_car, "moving garage blocks save and release without changing ownership")
	private_car.moving = FALSE
	var/list/private_parts = private_session.garage_parts.Copy()
	var/turf/bay = M.garage_anchor(private_session)
	equipment_assert(M.release(private_session), "private bay release commits before retiring actual parts")
	equipment_assert(!private_car.loc, "private release also retires nested vehicle controller")
	for (var/obj/O in private_parts) equipment_assert(!O.loc, "released bay retains no materialized top part")
	var/obj/bay_blocker = new(bay)
	equipment_assert(!M.admit(owner) && !owner.extraction_session, "blocked bay cannot expose partial account restoration")
	qdel(bay_blocker)
	equipment_assert(M.admit(owner), "cleared private bay restores acknowledged car once")
	private_session = owner.extraction_session
	private_car = private_session.garage_vehicle
	private_frame = private_car.loc
	equipment_assert(private_car.engine.fueltank.reagents.total_volume == 14 && private_frame.w_front[5] == 61 && private_car.extraction_vehicle_part_id == snapshot["id"], "private reconnect retains paid fuel condition and identity")
	equipment_assert(M.release(private_session), "private garage fixture releases account cleanly")
	qdel(owner)
	var/mob/living/human/buyer = new(locate(3,3,1))
	buyer.m_intent = "stealth"
	M.test_owners[buyer] = "carbuyer"
	equipment_assert(M.admit(buyer), "car buyer receives ordinary private account")
	var/datum/extraction_session/buyer_session = buyer.extraction_session
	equipment_assert(!M.buy_car(buyer), "level-one account cannot acquire dealer car")
	for (var/i in 1 to 5) new /obj/item/extraction_salvage(get_turf(buyer_session.house))
	equipment_assert(M.upgrade_house(buyer_session), "dealer buyer pays real house upgrade before purchasing")
	for (var/i in 1 to EXTRACTION_CAR_PRICE) new /obj/item/extraction_salvage(get_turf(buyer_session.house))
	M.test_car_confirmation = FALSE
	equipment_assert(!M.buy_car(buyer) && !buyer_session.garage_vehicle && buyer_session.profile["stash"].len == 29, "declined car purchase retains every actual payment part")
	M.test_car_confirmation = "move"
	equipment_assert(!M.buy_car(buyer) && !buyer_session.garage_vehicle && buyer_session.profile["stash"].len == 29, "movement during dealer confirmation invalidates quote without spending parts")
	buyer.forceMove(get_turf(buyer_session.house))
	M.test_car_confirmation = TRUE
	equipment_assert(M.buy_car(buyer), "dealer consumes real home payment before assembling and saving car")
	equipment_assert(buyer_session.garage_vehicle && buyer_session.garage_vehicle.engine.fueltank.reagents.total_volume == 0 && buyer_session.profile["stash"].len == 4 && buyer_session.profile["garage_purchase"]["status"] == "complete", "paid dealer car contains no free fuel or refunded workshop parts")
	equipment_assert(!M.buy_car(buyer) && buyer_session.profile["garage"].len == 1, "occupied garage cannot repeat dealer acquisition")
	equipment_assert(M.release(buyer_session) && M.admit(buyer), "paid dealer car survives private account release and reconnect")
	buyer_session = buyer.extraction_session
	equipment_assert(buyer_session.garage_vehicle && buyer_session.profile["stash"].len == 4, "reconnect restores one acknowledged dealer car without payment refund")
	var/obj/structure/vehicleparts/axis/deployed_car = buyer_session.garage_vehicle
	var/obj/structure/table/carboot/dealer_boot
	for (var/obj/structure/table/carboot/B in buyer_session.garage_parts) dealer_boot = B
	var/obj/item/extraction_salvage/raid_cargo = new(get_turf(dealer_boot))
	raid_cargo.extraction_found_in_raid = TRUE
	var/obj/item/extraction_salvage/carried_part = new(buyer)
	carried_part.extraction_found_in_raid = TRUE
	equipment_assert(M.save_home(buyer_session), "vehicle fixture checkpoints carried loadout and boot cargo before quote")
	var/list/stored_vehicle = buyer_session.profile["garage"][1]
	equipment_assert(!buyer_session.plan_vehicle_raid(list(), buyer_session.profile["revision"] - 1, stored_vehicle["id"], md5(json_encode(stored_vehicle))), "stale vehicle deployment quote cannot debit garage")
	deployed_car.engine.on = TRUE
	equipment_assert(!M.deploy_vehicle(buyer) && buyer_session.profile["state"] == "home" && buyer_session.profile["garage"].len == 1, "running engine rejects deployment without garage debit")
	deployed_car.engine.on = FALSE
	var/list/raid_markers = extraction_raid_markers.Copy()
	extraction_raid_markers.Cut()
	equipment_assert(!M.deploy_vehicle(buyer) && buyer_session.profile["garage"].len == 1 && !buyer_session.raid_vehicle, "missing clear raid entry rejects before durable car debit")
	extraction_raid_markers = raid_markers
	equipment_assert(M.deploy_vehicle(buyer) && buyer_session.raid_vehicle == deployed_car && !buyer_session.garage_vehicle && !buyer_session.profile["garage"].len && buyer_session.profile["state"] == "raid", "solo deployment debits saved garage before moving actual car")
	equipment_assert(M.raid_vehicles[deployed_car] && get_turf(deployed_car) != M.garage_anchor(buyer_session), "deployed car remains registered as actual raid ownership")
	equipment_assert(!raid_cargo.extraction_found_in_raid && !carried_part.extraction_found_in_raid && buyer_session.profile["stash"].len == 4 && M.raid_items[raid_cargo] && M.raid_items[carried_part], "carried gear and cargo lose brought-in provenance and leave acknowledged home inventory together")
	for (var/x in 80 to 92)
		for (var/y in 80 to 92)
			var/turf/F = locate(x,y,1)
			for (var/atom/movable/O in F)
				if (O != buyer) qdel(O)
			F.ChangeTurf(/turf/floor, FALSE, FALSE)
	var/datum/extraction_vehicle_transfer/raid_transfer = new
	equipment_assert(raid_transfer.capture(deployed_car, TRUE) && raid_transfer.relocate(locate(85,85,1)), "actual deployed car parks at bounded exit fixture")
	var/obj/effect/extraction_exit/car_exit = new(locate(81,84,1))
	buyer.forceMove(locate(81,83,1))
	M.test_wait = "cancel"
	var/raid_revision = buyer_session.profile["revision"]
	equipment_assert(!M.extract_vehicle(buyer, car_exit) && !buyer_session.transitioning && buyer_session.profile["revision"] == raid_revision && !buyer_session.profile["garage"].len, "cancelled vehicle exit retains durable raid debit")
	M.test_wait = "complete"
	deployed_car.engine.on = TRUE
	equipment_assert(!M.extract_vehicle(buyer, car_exit) && buyer_session.profile["revision"] == raid_revision, "running parked car cannot be credited at extraction")
	deployed_car.engine.on = FALSE
	var/obj/structure/vehicleparts/frame/raid_frame = deployed_car.loc
	raid_frame.w_front[5] = 49
	var/obj/item/extraction_salvage/new_cargo = new(get_turf(dealer_boot))
	new_cargo.extraction_found_in_raid = TRUE
	equipment_assert(M.track_loot(new_cargo), "new raid cargo enters actual loot registry")
	equipment_assert(M.extract_vehicle(buyer, car_exit) && buyer_session.garage_vehicle == deployed_car && buyer_session.profile["garage"].len == 1 && buyer_session.profile["state"] == "home" && !M.raid_vehicles[deployed_car], "vehicle exit credits actual car before private bay relocation")
	equipment_assert(buyer_session.profile["stash"].len == 5 && buyer_session.profile["garage"][1]["cargo"].len == 2 && raid_cargo.loc && new_cargo.loc && new_cargo.extraction_found_in_raid && !raid_cargo.extraction_found_in_raid && !M.raid_items[new_cargo], "vehicle extraction banks carried gear and actual cargo with distinct retained provenance")
	equipment_assert(raid_frame.w_front[5] == 49 && get_turf(deployed_car) == M.garage_anchor(buyer_session), "raid damage survives actual car extraction")
	equipment_assert(!buyer_session.credit_vehicle_extraction(buyer_session.profile["raid_sequence"], list(), buyer_session.profile["garage"][1]), "vehicle extraction cannot credit twice")
	equipment_assert(M.deploy_vehicle(buyer), "acknowledged extracted car may deploy into next paid-risk raid")
	equipment_assert(buyer_session.forfeit(buyer_session.profile["raid_sequence"]) && M.release(buyer_session, FALSE) && deployed_car.loc && M.raid_vehicles[deployed_car], "death forfeiture leaves actual raid car available without deleting it during account release")
	equipment_assert(M.admit(buyer) && !buyer.extraction_session.garage_vehicle && !buyer.extraction_session.profile["garage"].len, "reconnect cannot reissue forfeited deployed car")
	equipment_assert(M.release(buyer.extraction_session), "vehicle raid fixture releases account cleanly")
	var/mob/living/human/looter = new(locate(3,3,1))
	looter.m_intent = "stealth"
	M.test_owners[looter] = "carlooter"
	equipment_assert(M.admit(looter) && M.deploy(looter), "independent looter deploys without any saved car")
	var/datum/extraction_session/looter_session = looter.extraction_session
	equipment_assert(raid_transfer.capture(deployed_car, TRUE) && raid_transfer.relocate(locate(85,85,1)), "forfeited car remains physical loot available to another participant")
	looter.forceMove(locate(81,83,1))
	equipment_assert(M.nearby_raid_vehicle(looter, car_exit) == deployed_car, "exit resolves actual nearby registered car without an ownership receipt")
	var/datum/extraction_session/conflict = M.accounts.open("carconflict")
	var/list/conflict_profile = conflict.copy_profile()
	conflict_profile["garage"] = list(M.vehicle_codec.encode(deployed_car))
	equipment_assert(conflict.commit(conflict_profile), "adversarial fixture records an already acknowledged car identity")
	var/looter_revision = looter_session.profile["revision"]
	equipment_assert(!M.extract_vehicle(looter, car_exit, deployed_car) && looter_session.profile["revision"] == looter_revision && deployed_car.loc && !looter_session.garage_vehicle, "looted car cannot duplicate an acknowledged garage in another account")
	conflict_profile = conflict.copy_profile()
	conflict_profile["garage"] = list()
	equipment_assert(conflict.commit(conflict_profile), "fixture resolves conflicting acknowledgement before retry")
	conflict.close()
	equipment_assert(M.extract_vehicle(looter, car_exit, deployed_car) && looter_session.garage_vehicle == deployed_car && looter_session.profile["garage"][1]["id"] == deployed_car.extraction_vehicle_part_id && looter_session.profile["garage"][1]["cargo"].len == 2, "independent looter banks original forfeited car and actual cargo once")
	equipment_assert(M.deploy_vehicle(looter) && looter_session.forfeit(looter_session.profile["raid_sequence"]) && M.release(looter_session, FALSE), "reissued acknowledged car returns to finite raid registry after new forfeiture")
	qdel(looter)
	qdel(car_exit)
	qdel(buyer)
