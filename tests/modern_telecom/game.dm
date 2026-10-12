var/telecom_fixture_time = 0
var/telecom_failures = 0
/world
	hub = ""
	hub_password = ""
	maxx = 200
	maxy = 8
	maxz = 2
	turf = /turf
	visibility = 0
/world/OpenPort(port)
	return port == "none" ? ..() : FALSE
/obj/map_metadata/telecom_fixture/New()
	return
/mob/living/human/telecom_fixture
	var/online = TRUE
/mob/living/human/telecom_fixture/New()
	species = new /datum/species/human
	body_build = new /datum/body_build
	bloodstr = new /datum/reagents/metabolism(1000, src, CHEM_BLOOD)
	ingested = new /datum/reagents/metabolism(1000, src, CHEM_INGEST)
	touching = new /datum/reagents/metabolism(1000, src, CHEM_TOUCH)
	reagents = bloodstr
	vessel = new /datum/reagents(1000, src)
/mob/living/human/telecom_fixture/broadcast_online()
	return online
/proc/telecom_check(condition, label)
	if (!condition)
		telecom_failures++
	world.log << "[condition ? "PASS" : "FAIL:"] [label]"
/world/Error(exception/e)
	telecom_failures++
	world.log << "runtime error: [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	movementMachine = new
	map = new /obj/map_metadata/telecom_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	map.ordinal_age = 8
	map.abandonment_season_cycle = TRUE
	map.abandonment_season_autonomous = TRUE
	season = "FALL"
	try
		telecom_check(!world.port, "offline fixture")
		telecom_check(!civ_broadcast_slot("crafting",599) && civ_broadcast_slot("crafting",600) == 1 && civ_broadcast_slot("crafting",1199) == 6 && !civ_broadcast_slot("crafting",1200), "start/end boundaries")
		telecom_check(civ_broadcast_slot("crafting",6600) == 1, "ten-minute rerun")
		var/obj/structure/cable/C = new(locate(3,3,1))
		var/obj/structure/engine/E = new(locate(3,3,1))
		E.on = TRUE
		E.maxpower = 100
		C.connections |= E
		E.connections |= C
		var/obj/structure/telecom/station/S = new(locate(3,3,1))
		var/obj/structure/telecom/R = new(locate(4,3,1))
		var/obj/structure/telecom/antenna/antenna = new(locate(3,4,1))
		S.enabled = TRUE
		S.prepared = TRUE
		S.program = "medical"
		R.enabled = TRUE
		S.powersource = C
		R.powersource = C
		C.connections |= S
		C.connections |= R
		var/mob/living/human/telecom_fixture/listener = new(locate(4,4,1))
		telecom_fixture_time = 3000
		map.ordinal_age = 7
		S.transmit_lesson()
		telecom_check(!S.program_line && !listener.broadcast_lessons.len, "real station emission rejects pre-Modern")
		map.ordinal_age = 8
		S.next_broadcast = 0
		R.frequency = 201
		S.transmit_lesson()
		telecom_check(!listener.broadcast_lessons.len, "frequency mismatch blocks award")
		S.next_broadcast = 0
		R.frequency = 200
		E.on = FALSE
		S.transmit_lesson()
		telecom_check(!listener.broadcast_lessons.len, "unpowered station blocks award")
		E.on = TRUE
		S.next_broadcast = 0
		S.transmit_lesson()
		telecom_check(listener.broadcast_lessons.len == 1, "powered matching station and receiver award real lesson")
		qdel(listener)
		var/obj/item/weapon/telephone/landline/P = new(locate(3,3,1))
		var/obj/item/weapon/telephone/landline/Q = new(locate(4,3,1))
		P.powersource = C
		Q.powersource = C
		P.name = "saved phone P"
		Q.name = "saved phone Q"
		C.connections |= P
		C.connections |= Q
		telecom_check(P.dial(Q.phonenumber) && Q.answer() && P.connected == Q.phonenumber && Q.connected == P.phonenumber, "phones call over the power cable")
		E.on = FALSE
		civ_check_landlines()
		telecom_check(!P.origincall && !Q.origincall, "power loss clears both phone peers")
		E.on = TRUE
		var/obj/structure/cable/D = new(locate(4,3,1))
		var/obj/structure/engine/other_supply = new(locate(4,3,1))
		other_supply.on = TRUE
		other_supply.maxpower = 100
		D.connections |= other_supply
		other_supply.connections |= D
		C.connections -= Q
		Q.powersource = D
		D.connections |= Q
		C.connections |= D
		D.connections |= C
		telecom_check(P.dial(Q.phonenumber) && Q.answer(), "reciprocal cable bridge routes calls")
		C.connections -= D
		D.connections -= C
		civ_check_landlines()
		telecom_check(P.draw_cable_power() && Q.draw_cable_power() && !P.origincall && !Q.origincall && !P.dial(Q.phonenumber), "powered split ends call and blocks dialing")
		C.connections |= D
		D.connections |= C
		telecom_check(P.dial(Q.phonenumber) && Q.answer(), "reconnecting cable restores route")
		P.hang_up()
		// Larger than the former 128-cable route cap, with power at both ends.
		var/list/long_grid = list()
		for (var/x = 1, x <= 200, x++)
			var/obj/structure/cable/link = new(locate(x,7,1))
			if (long_grid.len)
				var/obj/structure/cable/previous = long_grid[long_grid.len]
				previous.connections |= link
				link.connections |= previous
			long_grid += link
		var/obj/structure/cable/left = long_grid[1]
		var/obj/structure/cable/right = long_grid[200]
		var/obj/structure/engine/long_supply = new(left.loc)
		long_supply.on = TRUE
		long_supply.maxpower = 20
		left.connections |= long_supply
		long_supply.connections |= left
		var/obj/item/weapon/telephone/landline/long_phone = new(locate(1,6,1))
		var/obj/item/weapon/telephone/landline/far_phone = new(locate(200,6,1))
		long_phone.powersource = left
		far_phone.powersource = right
		left.connections |= long_phone
		right.connections |= far_phone
		telecom_check(long_phone.dial(far_phone.phonenumber) && far_phone.answer() && left.component_size == 200, "200-cable route has no telecom cable-count cutoff")
		qdel(long_phone)
		telecom_check(!far_phone.origincall, "deleting phone releases surviving peer")
		qdel(far_phone)
		qdel(long_supply)
		for (var/obj/structure/cable/link in long_grid)
			qdel(link)
		var/obj/structure/telecom/terminal/T = new(locate(3,3,1))
		var/obj/structure/telecom/terminal/U = new(locate(4,3,1))
		T.enabled = TRUE
		U.enabled = TRUE
		T.powersource = C
		U.powersource = C
		C.connections |= T
		C.connections |= U
		telecom_check(T.send_network_message("local test") == 1 && !T.send_network_message("rate limited"), "terminals share power cable and rate limit")
		var/p_number = P.phonenumber
		var/q_number = Q.phonenumber
		qdel(antenna)
		var/mob/living/human/telecom_fixture/H = new(locate(2,2,1))
		H.stats["crafting"] = list(100,100)
		telecom_fixture_time = 600
		map.ordinal_age = 7
		telecom_check(!civ_broadcast_slot("crafting",600) && !H.learn_broadcast("crafting",1) && !H.broadcast_lessons.len, "pre-Modern emission and award rejected")
		map.ordinal_age = 8
		season = "SPRING"
		var/decay_before = abandonment_season_changes
		telecom_check(!H.learn_broadcast("crafting",1) && civ_broadcast_slot("farming",1800) == 1, "cycling seasonal eligibility")
		season = "WINTER"
		telecom_check(!civ_broadcast_slot("farming",1800) && civ_broadcast_slot("medical",3000) == 1, "winter farming blocked, medical eligible")
		telecom_check(abandonment_season_changes == decay_before, "eligibility does not age debris")
		map.seasons(FALSE, TRUE)
		telecom_check(season == "SPRING" && civ_broadcast_slot("farming",1800) == 1 && !civ_broadcast_slot("crafting",600) && abandonment_season_changes == decay_before, "actual forced season changes eligibility without aging debris")
		map.abandonment_season_cycle = FALSE
		season = "WET SEASON"
		telecom_check(civ_broadcast_slot("crafting",600) == 1 && civ_broadcast_slot("farming",1800) == 1, "fixed/no-cycle evergreen compatibility")
		H.ear_deaf = 1
		telecom_check(!H.learn_broadcast("crafting",1), "deaf learner receives no credit")
		H.ear_deaf = 0
		telecom_check(!H.learn_broadcast("crafting",2), "lesson must match current authoritative slot")
		for (var/line = 1, line <= 6, line++)
			telecom_fixture_time = 600 + (line-1)*100
			telecom_check(H.learn_broadcast("crafting",line), "unique lesson [line]")
		var/gain = H.stats["crafting"][2]
		telecom_check(gain > 103.03 && gain < 103.05 && H.broadcast_lessons.len == 6, "finite native baseline-100 curriculum gain")
		telecom_fixture_time = 6600
		telecom_check(!H.learn_broadcast("crafting",1) && H.stats["crafting"][2] == gain, "rerun cannot duplicate XP")
		H.online = FALSE
		telecom_fixture_time = 1800
		telecom_check(!H.learn_broadcast("farming",1), "offline learner rejected")
		H.online = TRUE
		telecom_check(H.learn_broadcast("farming",1) && !H.learn_broadcast("farming",1), "reconnect cannot repeat a credit")
		H.stats["medical"] = list(124.9,124.9)
		telecom_fixture_time = 3000
		telecom_check(H.learn_broadcast("medical",1) && H.stats["medical"][2] == 125, "reward capped at 125")
		telecom_fixture_time = 3100
		telecom_check(!H.learn_broadcast("medical",2), "advanced training requires practice/books")
		telecom_check(P.dial(Q.phonenumber) && Q.answer(), "active call before save")
		telecom_check(map_storage.Save_World() && map_storage.validate_world_save(), "native learner and equipment save")
		map_storage.ClearMap()
		telecom_check(map_storage.Load_World(), "native learner reload")
		H = locate(/mob/living/human/telecom_fixture) in locate(2,2,1)
		telecom_fixture_time = 600
		telecom_check(H && H.broadcast_lessons.len == 8 && !H.learn_broadcast("crafting",1), "restart preserves credits and rejects rerun")
		P = null
		Q = null
		for (var/obj/item/weapon/telephone/landline/phone in civ_landlines)
			if (phone.name == "saved phone P")
				P = phone
			if (phone.name == "saved phone Q")
				Q = phone
		telecom_check(P && Q && P.phonenumber == p_number && Q.phonenumber == q_number && !P.origincall && !Q.origincall && !P.connected && !Q.connected, "phone numbers survive; runtime calls do not")
		telecom_check(P && Q && P.dial(Q.phonenumber) && Q.answer(), "restored phones route over restored cable")
	catch (var/exception/e)
		telecom_check(FALSE,"exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit"=world.params["tested_commit"],"failures"=telecom_failures,"byond_build"=world.byond_build)),"result.json")
	del(world)
