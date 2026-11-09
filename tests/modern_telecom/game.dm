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
/mob/living/human/telecom_fixture
	var/relayed_heard = 0
	var/relayed_last = ""
/mob/living/human/telecom_fixture/hear_relayed_radio(message, verbage, datum/remote_speaker/speaker, obj/destination)
	relayed_heard++
	relayed_last = "[speaker.real_name]@[speaker.region]/[speaker.relay]: [message]"
/mob/living/human/telecom_fixture
	var/station_heard = 0
	var/station_last = ""
/mob/living/human/telecom_fixture/hear_station_line(message)
	station_heard++
	station_last = message
/proc/telecom_check(condition, label)
	if (!condition)
		telecom_failures++
	world.log << "[condition ? "PASS" : "FAIL:"] [label]"
/world/Error(exception/e)
	telecom_failures++
	world.log << "runtime error: [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	generate_gameid()
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
		map.ordinal_age = 4
		S.transmit_lesson()
		telecom_check(!S.program_line && !listener.broadcast_lessons.len, "real station emission rejects pre-1903")
		map.ordinal_age = 5
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
		telecom_check(civ_telecom_era_allowed(/obj/structure/telecom) && !civ_telecom_era_allowed(/obj/structure/telecom/tv) && !civ_telecom_era_allowed(/obj/structure/telecom/station/tv), "1903 radio does not unlock TV")
		listener.station_heard = 0
		var/mob/living/human/telecom_fixture/presenter = new(locate(3,3,1))
		S.presenter = presenter
		S.station_name = "Test station"
		S.faction_tag = "Roleplay"
		telecom_check(S.transmit_live(presenter, "Hello listeners", null) >= 1 && listener.station_heard == 1 && findtext(listener.station_last, "Test station"), "live station delivers named speech")
		telecom_check(!S.transmit_live(presenter, "Too fast", null) && listener.station_heard == 1, "live station rate limit")
		S.next_live_broadcast = 0
		R.frequency = 201
		S.transmit_live(presenter, "Wrong channel", null)
		telecom_check(listener.station_heard == 1, "live frequency mismatch")
		R.frequency = 200
		S.next_live_broadcast = 0
		E.on = FALSE
		telecom_check(!S.transmit_live(presenter, "No power", null), "live power loss")
		E.on = TRUE
		presenter.loc = locate(8,3,1)
		telecom_check(!S.transmit_live(presenter, "Away", null), "presenter must stay at desk")
		presenter.loc = locate(3,3,1)
		presenter.stat = UNCONSCIOUS
		telecom_check(!S.transmit_live(presenter, "Asleep", null), "presenter consciousness")
		presenter.stat = CONSCIOUS
		S.next_live_broadcast = 0
		listener.ear_deaf = 1
		S.transmit_live(presenter, "Deaf listener", null)
		telecom_check(listener.station_heard == 1, "deaf audience excluded")
		listener.ear_deaf = 0
		S.next_live_broadcast = 0
		antenna.anchored = FALSE
		telecom_check(!S.transmit_live(presenter, "No antenna", null), "live antenna required")
		antenna.anchored = TRUE
		var/list/crowd = list()
		for (var/i = 1, i <= 35, i++)
			crowd += new /mob/living/human/telecom_fixture(locate(4,4,1))
		telecom_check(S.transmit_live(presenter, "Bounded audience", null) == 32, "live audience cap is 32")
		for (var/mob/living/human/member in crowd)
			qdel(member)
		S.presenter = null
		telecom_check(!S.transmit_live(presenter, "Off air", null), "explicit stop presenting")
		telecom_check(S.persistence_runtime_var("presenter") && S.persistence_runtime_var("next_live_broadcast"), "live identity and rate clock never saved")
		qdel(presenter)
		map.ordinal_age = 8
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
		// A cut cable republishes both halves at once (cables.dm disconnect()).
		C.rebuild_supply()
		D.rebuild_supply()
		civ_check_landlines()
		telecom_check(P.draw_cable_power() && Q.draw_cable_power() && !P.origincall && !Q.origincall && !P.dial(Q.phonenumber), "powered split ends call and blocks dialing")
		C.connections |= D
		D.connections |= C
		C.rebuild_supply()
		D.rebuild_supply()
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
		// #4222: restored phones whose saved numbers are each other's temporary
		// constructor numbers keep their saved numbers; a real duplicate does not.
		var/obj/item/weapon/telephone/landline/swap_a = new(locate(6,6,1))
		var/obj/item/weapon/telephone/landline/swap_b = new(locate(7,6,1))
		var/temp_a = swap_a.phonenumber
		var/temp_b = swap_b.phonenumber
		swap_a.phonenumber = temp_b
		swap_b.phonenumber = temp_a
		swap_a.after_load()
		swap_b.after_load()
		telecom_check(swap_a.phonenumber == temp_b && swap_b.phonenumber == temp_a && swap_a.registered_number == temp_b && swap_b.registered_number == temp_a && (temp_a in phone_numbers) && (temp_b in phone_numbers), "saved landline numbers survive a reversed restore order")
		var/obj/item/weapon/telephone/landline/dup = new(locate(8,6,1))
		var/dup_temp = dup.phonenumber
		dup.phonenumber = temp_a
		dup.after_load()
		telecom_check(swap_b.phonenumber == temp_a && dup.phonenumber != temp_a && dup.phonenumber == dup.registered_number && !(dup_temp in phone_numbers && dup_temp != dup.phonenumber), "a real duplicate saved number is still replaced")
		qdel(swap_a)
		qdel(swap_b)
		qdel(dup)
		// Cross-region relay (radio_relay.dm): keyed, powered, worn and repaired; heard through local receivers.
		var/fixture_group = json_encode(list("group" = "g", "region" = "alpha", "regions" = list(list("id" = "alpha", "name" = "Alpha Land", "kind" = "SURFACE", "address" = "127.0.0.1:1731"), list("id" = "beta", "name" = "Beta Land", "kind" = "SURFACE", "address" = "127.0.0.1:1732"))))
		telecom_check(shard_group.configure(fixture_group) && ("beta" in shard_group.peers), "fixture region group with one peer")
		var/obj/structure/telecom/relay/relay = new(locate(2,4,1))
		relay.enabled = TRUE
		relay.powersource = C
		C.connections |= relay
		telecom_check(civ_relay_key_valid("village-1") && !civ_relay_key_valid("Village") && !civ_relay_key_valid("") && !civ_relay_key_valid("abcdefghijklmnopq"), "network key charset and length")
		telecom_check(relay.running() && !relay.on_air(), "powered relay with antenna runs but is off the air without a key")
		relay.network_key = "village"
		telecom_check(relay.on_air() && civ_relay_on_air_list().len == 1, "keyed relay is on the air")
		E.on = FALSE
		other_supply.on = FALSE
		telecom_check(!relay.running() && !relay.on_air() && !civ_relay_on_air_list().len, "unpowered relay is off the air")
		E.on = TRUE
		other_supply.on = TRUE
		relay.wear(3)
		telecom_check(relay.condition == 97, "wear takes condition while running")
		E.on = FALSE
		other_supply.on = FALSE
		relay.wear(3)
		E.on = TRUE
		other_supply.on = TRUE
		telecom_check(relay.condition == 97, "no wear while unpowered")
		telecom_check(relay.garble("steady") == "steady", "no garbling above the threshold")
		var/sends = 0
		for (var/i = 1, i <= 12, i++)
			if (relay.allow_send())
				sends++
		telecom_check(sends == 10, "ten outbound messages per window")
		var/mob/living/human/telecom_fixture/far_listener = new(locate(6,3,1))
		human_mob_list |= far_listener
		var/obj/item/weapon/radio/handset = new(far_listener)
		handset.freq = 150
		R.frequency = 150
		var/list/envelope = list("key" = "village", "frequency" = 150, "name" = "Bea", "message" = "hello alpha", "language" = "-", "verb" = "says", "relay" = "south mast", "condition" = 90, "source" = "beta", "ckey" = "bea")
		telecom_check(civ_relay_receive(envelope) && far_listener.relayed_heard == 1 && far_listener.relayed_last == "Bea@Beta Land/south mast: hello alpha", "arrival on the key is heard through a receiver on the frequency")
		telecom_check(far_listener.station_heard == 1 && findtext(far_listener.station_last, "hello alpha"), "regional arrival reaches powered tuned broadcast receiver")
		envelope["frequency"] = 151
		telecom_check(!civ_relay_receive(envelope) || far_listener.relayed_heard == 1, "wrong frequency is not heard")
		envelope["frequency"] = 150
		envelope["key"] = "raiders"
		telecom_check(!civ_relay_receive(envelope) && far_listener.relayed_heard == 1, "no relay on that key drops the arrival")
		envelope["key"] = "village"
		envelope["source"] = "gamma"
		telecom_check(!civ_relay_receive(envelope), "unknown source region is dropped")
		envelope["source"] = "beta"
		envelope["message"] = ""
		telecom_check(!civ_relay_receive(envelope), "empty message is dropped")
		envelope["message"] = "<b>bold</b> hi"
		telecom_check(civ_relay_receive(envelope) && findtext(far_listener.relayed_last, "&lt;b&gt;"), "arrival text is html-encoded")
		relay.network_key = ""
		telecom_check(!civ_relay_receive(envelope) && far_listener.relayed_heard == 2, "relay with no key hears nothing")
		relay.network_key = "village"
		relay.condition = 0
		telecom_check(!relay.on_air() && !civ_relay_receive(envelope), "worn-out relay is silent")
		relay.condition = 97
		var/relay_x = relay.x
		var/relay_y = relay.y
		qdel(far_listener)
		qdel(handset)
		qdel(antenna)
		var/mob/living/human/telecom_fixture/H = new(locate(2,2,1))
		H.stats["crafting"] = list(100,100)
		telecom_fixture_time = 600
		map.ordinal_age = 4
		telecom_check(!civ_broadcast_slot("crafting",600) && !H.learn_broadcast("crafting",1) && !H.broadcast_lessons.len, "pre-1903 emission and award rejected")
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
		S = locate(/obj/structure/telecom/station) in locate(3,3,1)
		telecom_check(S && S.station_name == "Test station" && S.faction_tag == "Roleplay" && !S.presenter && !S.next_live_broadcast, "station identity saves, live session does not")
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
		var/obj/structure/telecom/relay/restored_relay = locate(/obj/structure/telecom/relay) in locate(relay_x,relay_y,1)
		telecom_check(restored_relay && restored_relay.network_key == "village" && restored_relay.condition == 97, "relay key and condition survive a save")
	catch (var/exception/e)
		telecom_check(FALSE,"exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit"=world.params["tested_commit"],"failures"=telecom_failures,"byond_build"=world.byond_build)),"result.json")
	del(world)
