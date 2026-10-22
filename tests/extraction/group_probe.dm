/datum/live_group_gate_observer
	var/list/members = list()
	proc/check(datum/extraction_service/S)
		if (S.open("livegroupvisitor")) return FALSE
		for (var/datum/extraction_session/member in members)
			if (member.active()) return FALSE
		return TRUE

/proc/extraction_group_probe(obj/map_metadata/extraction_survival/M)
	world.log << "GROUP: start"
	var/list/bodies = list()
	var/list/guns = list()
	for (var/i in 1 to 5)
		var/mob/living/human/H = new(locate(3,3,1))
		H.m_intent = "stealth"
		M.test_owners[H] = "partyplayer[i]"
		equipment_assert(M.admit(H), "group member admitted to exclusive private house")
		var/obj/item/weapon/gun/G
		for (var/obj/item/weapon/gun/candidate in M.home_roots(H.extraction_session)) G = candidate
		equipment_assert(G, "group test uses actual issued starter gun")
		G.forceMove(H)
		bodies += H
		guns += G
	var/mob/living/human/A = bodies[1]
	var/mob/living/human/B = bodies[2]
	for (var/i in 1 to 8) new /obj/item/extraction_salvage(get_turf(A))
	var/datum/extraction_party/P = M.create_party(A)
	equipment_assert(P && !M.create_party(A), "one group per owner")
	M.test_party_confirmation = "decline"
	equipment_assert(!M.invite_party(A, B) && P.members.len == 1, "declined invitation cannot enroll a player")
	M.test_party_confirmation = "stale"
	equipment_assert(!M.invite_party(A, B) && P.members.len == 1, "invitation invalidated during confirmation cannot enroll")
	M.test_party_confirmation = "accept"
	equipment_assert(M.invite_party(A, B) && M.ready_party(A) && M.ready_party(B), "two consenting members can ready their loadouts")
	equipment_assert(M.invite_party(A, bodies[3]) && !P.ready.len, "membership change invalidates earlier readiness")
	equipment_assert(M.invite_party(A, bodies[4]), "fourth member explicitly accepts invitation")
	equipment_assert(P.members.len == 4 && !M.invite_party(A, bodies[5]), "group capped at four")
	equipment_assert(!M.deploy_party(A) && !M.deploy_party(B), "missing readiness and nonleader deployment rejected")
	for (var/i in 1 to 4) equipment_assert(M.ready_party(bodies[i]), "each account readies its own exact loadout")
	equipment_assert(M.leave_party(B.extraction_session.owner) && !P.ready.len && M.invite_party(A, B), "withdrawal clears every ready vote and rejoin requires fresh consent")
	for (var/i in 1 to 4) equipment_assert(M.ready_party(bodies[i]), "every member readies after membership replacement")
	var/obj/item/weapon/gun/changed = guns[1]
	changed.health--
	equipment_assert(!M.deploy_party(A), "changed physical condition invalidates group readiness before any debit")
	for (var/i in 1 to 4) equipment_assert(bodies[i]:z == 2 && bodies[i]:extraction_session.profile["state"] == "home", "readiness rejection leaves all members home")
	equipment_assert(M.ready_party(A), "changed member can explicitly ready revised condition")
	M.test_insurance_confirmation = FALSE
	equipment_assert(!M.ready_party(A, TRUE), "declined group premium does not replace readiness or charge")
	M.test_insurance_confirmation = TRUE
	equipment_assert(M.ready_party(A, TRUE), "member authorizes their own group premium")
	var/list/offer = P.ready[A.extraction_session.owner]["insurance"]
	var/cost = offer["cost"]
	equipment_assert(cost > 0 && A.extraction_session.profile["stash"].len == 12 && !A.extraction_session.profile["insurance_claims"], "readiness does not debit premium or issue claim")
	M.accounts.group_journal.test_fail_at = "before_receipt"
	equipment_assert(!M.deploy_party(A), "pre-receipt failure cannot partially deploy group")
	for (var/i in 1 to 4) equipment_assert(bodies[i]:z == 2 && !bodies[i]:extraction_session.transitioning && bodies[i]:extraction_session.profile["state"] == "home", "pre-receipt failure releases all transition flags without account debit")
	M.accounts.group_journal.test_fail_at = null
	for (var/i in 1 to 4) equipment_assert(M.ready_party(bodies[i]), "all members renew readiness after failed request")
	equipment_assert(M.ready_party(A, TRUE), "insured member renews premium authorization after failed receipt")
	var/datum/live_group_gate_observer/observer = new
	for (var/i in 1 to 4) observer.members += bodies[i]:extraction_session
	M.accounts.group_journal.test_access_observer = observer
	world.log << "GROUP: ready, starting observed commit"
	equipment_assert(M.deploy_party(A), "four-account durable group deployment succeeds")
	world.log << "GROUP: observed commit complete"
	M.accounts.group_journal.test_access_observer = null
	for (var/i in 1 to 4)
		var/mob/living/human/H = bodies[i]
		var/obj/item/weapon/gun/G = guns[i]
		var/expected_stash = i == 1 ? 11 - cost : 3
		equipment_assert(H.z == 1 && get_turf(H) == get_turf(A) && H.extraction_session.profile["state"] == "raid" && H.extraction_session.profile["stash"].len == expected_stash && G.loc == H, "all members enter same raid spawn with original atoms after all debits")
		equipment_assert(i == 1 ? (!!G.extraction_insurance_token && H.extraction_session.profile["insurance_claims"].len == 1) : !G.extraction_insurance_token, "only consenting insured member receives a paid identity token")
		if (i == 1)
			for (var/obj/item/I in M.home_roots(H.extraction_session)) equipment_assert(!(I.extraction_item_id in offer["payment"]), "charged group premiums are physically retired after durable debit")
	equipment_assert(!P.alive && !M.deploy_party(A), "deployed party cannot replay")
	for (var/i in 1 to 4)
		var/mob/living/human/H = bodies[i]
		var/obj/effect/extraction_exit/exit
		for (var/obj/effect/extraction_exit/E in world)
			if (E.type == /obj/effect/extraction_exit) exit = E
		equipment_assert(exit, "ordinary extraction exists for each group member")
		H.forceMove(get_turf(exit))
		equipment_assert(M.extract_player(H, exit) && H.extraction_session.profile["stash"].len == (i == 1 ? 12 - cost : 4), "group members independently extract exactly their carried gear")
		equipment_assert(M.release(H.extraction_session), "group account released after extraction")
		qdel(H)
	var/mob/living/human/last = bodies[5]
	var/datum/extraction_party/expired = M.create_party(last)
	expired.expires = world.time
	M.tick_parties()
	equipment_assert(!expired.alive && !M.party_by_owner[last.extraction_session.owner], "expired party releases membership and readiness")
	equipment_assert(M.release(last.extraction_session), "unused invite target released")
	qdel(last)
	extraction_group_car_probe(M)
	world.log << "GROUP: complete"

/proc/extraction_group_car_probe(obj/map_metadata/extraction_survival/M)
	var/list/bodies = list()
	for (var/i in 1 to 3)
		var/mob/living/human/H = new(locate(3,3,1))
		H.m_intent = "stealth"
		M.test_owners[H] = "grouprider[i]"
		equipment_assert(M.admit(H), "car group member admitted")
		var/list/funded = H.extraction_session.copy_profile()
		funded["credits"] = i == 2 ? 5 : 10
		equipment_assert(H.extraction_session.commit(funded), "car fee fixture seeds bounded participant wallets")
		bodies += H
	var/mob/living/human/driver = bodies[1]
	var/mob/living/human/passenger = bodies[2]
	var/datum/extraction_session/S = driver.extraction_session
	for (var/i in 1 to 5) new /obj/item/extraction_salvage(get_turf(S.house))
	equipment_assert(M.upgrade_house(S), "group car owner pays private house upgrade")
	for (var/i in 1 to EXTRACTION_CAR_PRICE) new /obj/item/extraction_salvage(get_turf(S.house))
	equipment_assert(M.buy_car(driver), "group car is paid actual dealer vehicle")
	var/obj/structure/vehicleparts/axis/A = S.garage_vehicle
	var/obj/structure/vehicleparts/frame/frame = A.loc
	var/obj/item/weapon/gun/insured_gun
	for (var/obj/item/weapon/gun/G in M.home_roots(S)) insured_gun = G
	equipment_assert(insured_gun, "group car insurance uses actual starter equipment")
	insured_gun.forceMove(driver)
	for (var/i in 1 to 8) new /obj/item/extraction_salvage(get_turf(S.house))
	var/datum/extraction_party/P = M.create_party(driver)
	equipment_assert(M.invite_party(driver, passenger) && M.select_party_vehicle(driver), "leader selects exact paid car after consenting invitation")
	M.test_ride_confirmation = FALSE
	equipment_assert(!M.ready_party(passenger), "declining ride cannot ready car deployment")
	M.test_ride_confirmation = TRUE
	equipment_assert(M.invite_party(driver, bodies[3]), "third rider joins only by consent")
	for (var/mob/living/human/H in bodies) equipment_assert(M.ready_party(H), "each car rider explicitly readies")
	equipment_assert(!M.deploy_party(driver) && S.profile["garage"].len == 1, "two-seat Piccolino rejects third rider before vehicle debit")
	M.leave_party(bodies[3]:extraction_session.owner)
	equipment_assert(M.release(bodies[3]:extraction_session), "excess rider leaves without debit")
	qdel(bodies[3])
	equipment_assert(M.ready_party(driver) && M.ready_party(passenger), "remaining riders consent again after membership change")
	var/supported_map_id = M.ID
	var/unsupported_driver_snapshot = json_encode(S.profile)
	var/unsupported_passenger_snapshot = json_encode(passenger.extraction_session.profile)
	var/unsupported_ready_snapshot = json_encode(P.ready)
	M.ID = MAP_ALLEYWAY
	equipment_assert(!M.select_party_vehicle(driver) && !M.ready_party(driver, TRUE) && !M.deploy_party(driver), "unsupported mission rejects car selection, readiness and deployment")
	equipment_assert(json_encode(S.profile) == unsupported_driver_snapshot && json_encode(passenger.extraction_session.profile) == unsupported_passenger_snapshot && json_encode(P.ready) == unsupported_ready_snapshot && S.garage_vehicle == A && driver.z == 2 && passenger.z == 2, "unsupported group mission preserves profiles, readiness, original car and riders")
	M.ID = supported_map_id
	frame.w_front[5]--
	equipment_assert(!M.deploy_party(driver) && S.profile["garage"].len == 1 && passenger.extraction_session.profile["state"] == "home", "changed actual car invalidates all readiness before debit")
	equipment_assert(M.select_party_vehicle(driver) && !P.ready.len && M.ready_party(driver) && M.ready_party(passenger), "updated selected car requires every rider to ready again")
	M.accounts.group_journal.test_fail_at = "before_receipt"
	equipment_assert(!M.deploy_party(driver) && S.garage_vehicle == A && S.profile["garage"].len == 1 && driver.z == 2 && passenger.z == 2, "failed car group receipt does not move riders or debit car")
	M.accounts.group_journal.test_fail_at = null
	equipment_assert(M.ready_party(driver, TRUE) && M.ready_party(passenger) && M.deploy_party(driver), "consenting two-account deployment transfers paid original car and riders")
	equipment_assert(insured_gun.extraction_insurance_token && S.profile["insurance_claims"].len == 1, "group car deployment composes one paid member claim with garage debit")
	equipment_assert(driver.z == 1 && passenger.z == 1 && driver.buckled && passenger.buckled && driver.buckled != passenger.buckled && A.driver == driver && !S.profile["garage"].len && S.raid_vehicle == A && M.raid_vehicles[A], "original driver and passenger occupy separate actual seats after durable garage debit")
	var/obj/structure/bed/chair/drivers/seat = driver.buckled
	var/obj/structure/bed/chair/passenger_seat = passenger.buckled
	if (A.wheel.loc == driver)
		driver.remove_from_mob(A.wheel)
		A.wheel.forceMove(seat)
	seat.unbuckle_mob()
	passenger_seat.unbuckle_mob()
	var/turf/car_origin = get_turf(A)
	driver.forceMove(locate(car_origin.x + 4, car_origin.y, 1))
	passenger.forceMove(get_turf(driver))
	for (var/x in 72 to 88)
		for (var/y in 72 to 88)
			var/turf/F = locate(x,y,1)
			for (var/atom/movable/O in F)
				if (!(O in list(driver, passenger))) qdel(O)
			F.ChangeTurf(/turf/floor, FALSE, FALSE)
	var/datum/extraction_vehicle_transfer/T = new
	equipment_assert(T.capture(A, TRUE) && T.relocate(locate(79,79,1)), "original group car parks at clear extraction fixture footprint")
	var/turf/exit_turf
	var/datum/extraction_vehicle_transfer/parked = new
	equipment_assert(parked.capture(A, TRUE), "parked original group car retains graph")
	for (var/turf/F in range(1, get_turf(seat)))
		if (!(F in parked.tiles) && !F.contents.len) exit_turf = F
	equipment_assert(exit_turf, "group vehicle exit stays outside car footprint")
	var/obj/effect/extraction_exit/exit = new(exit_turf)
	exit.extraction_fee = 6
	driver.forceMove(get_turf(seat))
	passenger.forceMove(get_turf(passenger_seat))
	equipment_assert(seat.buckle_mob(driver) && passenger_seat.buckle_mob(passenger), "original riders reboard actual parked seats")
	equipment_assert(!M.extract_vehicle(driver, exit, A) && driver.buckled == seat && passenger.buckled == passenger_seat && S.profile["credits"] == 10 && passenger.extraction_session.profile["credits"] == 5, "unfunded passenger blocks all rider fees and car return before consent")
	exit.extraction_fee = 5
	M.test_vehicle_return_confirmation = FALSE
	equipment_assert(!M.extract_vehicle(driver, exit, A) && driver.buckled == seat && passenger.buckled == passenger_seat && S.profile["state"] == "raid", "declined rider extraction preserves every occupied seat and account")
	M.test_vehicle_return_confirmation = "stale"
	equipment_assert(!M.extract_vehicle(driver, exit, A) && driver.buckled == seat && passenger.buckled == passenger_seat && S.profile["state"] == "raid", "changed carried condition during rider confirmation invalidates consent before unloading or credit")
	M.test_fee_exit = exit
	M.test_vehicle_return_confirmation = "fee"
	equipment_assert(!M.extract_vehicle(driver, exit, A) && driver.buckled == seat && passenger.buckled == passenger_seat && S.profile["credits"] == 10 && passenger.extraction_session.profile["credits"] == 5, "changed exit fee invalidates rider consent without debit or unloading")
	exit.extraction_fee = 5
	M.test_fee_exit = null
	M.test_vehicle_return_confirmation = TRUE
	M.test_wait = "cancel"
	equipment_assert(!M.extract_vehicle(driver, exit, A) && !driver.buckled && !passenger.buckled && S.profile["state"] == "raid" && passenger.extraction_session.profile["state"] == "raid" && M.raid_vehicles[A], "cancelled consenting rider extraction unboards without crediting any account")
	M.test_wait = "complete"
	driver.forceMove(get_turf(seat))
	passenger.forceMove(get_turf(passenger_seat))
	equipment_assert(seat.buckle_mob(driver) && passenger_seat.buckle_mob(passenger), "cancelled riders may board again")
	M.accounts.group_journal.test_fail_at = "before_receipt"
	equipment_assert(!M.extract_vehicle(driver, exit, A) && !S.profile["garage"].len && S.profile["state"] == "raid" && passenger.extraction_session.profile["state"] == "raid", "failed passenger receipt credits neither rider nor garage")
	M.accounts.group_journal.test_fail_at = null
	driver.forceMove(get_turf(seat))
	passenger.forceMove(get_turf(passenger_seat))
	equipment_assert(seat.buckle_mob(driver) && passenger_seat.buckle_mob(passenger), "riders explicitly board for fresh extraction request")
	var/obj/item/extraction_salvage/loot = new(passenger)
	loot.extraction_found_in_raid = TRUE
	var/returned = M.extract_vehicle(driver, exit, A)
	if (!returned) world.log << "RIDER ERROR: [M.last_vehicle_return_error]; journal=[M.accounts.group_journal.last_error]"
	equipment_assert(returned, "all consenting passenger accounts commit before actual car returns")
	equipment_assert(S.profile["credits"] == 5 && passenger.extraction_session.profile["credits"] == 0, "shared passenger receipt charges each quoted exit fee exactly once")
	equipment_assert(S.profile["state"] == "home" && passenger.extraction_session.profile["state"] == "home" && S.profile["garage"].len == 1 && S.garage_vehicle == A && driver.z == 2 && passenger.z == 2 && get_turf(driver) != get_turf(passenger) && loot.loc == passenger && loot.extraction_found_in_raid && !M.raid_vehicles[A], "each rider returns to their own house with original loot and only driver receives original car")
	equipment_assert(insured_gun.loc == driver && (insured_gun.extraction_insurance_token in S.profile["insurance_recovered"]), "passenger receipt records actual paid insured identity recovery")
	equipment_assert(!M.extract_vehicle(driver, exit, A), "passenger vehicle credit cannot replay")
	equipment_assert(M.release(S) && M.release(passenger.extraction_session), "returned rider accounts release with acknowledged ownership")
	qdel(exit)
	qdel(driver)
	qdel(passenger)
