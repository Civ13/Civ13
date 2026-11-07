// Smart hub fixture (code/modules/1713/smart_home.dm): pairing, rights,
// fixed voice commands, smart locks, timers and a native save round trip.
var/smart_failures = 0
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 12
	maxz = 2
	turf = /turf
	visibility = 0
/world/OpenPort(port)
	return port == "none" ? ..() : FALSE
/obj/map_metadata/smart_fixture/New()
	return
/mob/living/human/smart_fixture
	var/fixture_identity = null
/mob/living/human/smart_fixture/New()
	species = new /datum/species/human
	body_build = new /datum/body_build
	bloodstr = new /datum/reagents/metabolism(1000, src, CHEM_BLOOD)
	ingested = new /datum/reagents/metabolism(1000, src, CHEM_INGEST)
	touching = new /datum/reagents/metabolism(1000, src, CHEM_TOUCH)
	reagents = bloodstr
	vessel = new /datum/reagents(1000, src)
/mob/living/human/smart_fixture/smart_hub_identity()
	return fixture_identity
/proc/smart_check(condition, label)
	if (!condition)
		smart_failures++
	world.log << "[condition ? "PASS" : "FAIL:"] [label]"
/world/Error(exception/e)
	smart_failures++
	world.log << "runtime error: [e] [e.file]:[e.line]"
/proc/smart_fixture_person(x, identity, name)
	var/mob/living/human/smart_fixture/P = new(locate(x, 5, 1))
	P.fixture_identity = identity
	P.real_name = name
	P.name = name
	P.stat = CONSCIOUS
	return P
/world/New()
	OpenPort("none")
	generate_gameid()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	movementMachine = new
	map = new /obj/map_metadata/smart_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	map.ordinal_age = 9
	try
		smart_check(smart_clean_text("What's the TIME, hub?!", 200) == "whats the time hub", "speech is cleaned to plain lowercase words")
		build_research_tree()
		var/datum/research_node/node = get_research_node("smart_home")
		smart_check(node && node.era_tier == 9 && ("consumer_electronics" in node.prereqs), "Smart Home node follows Consumer Electronics in 2026")
		smart_check(get_recipe_node_req("/obj/structure/smart_hub") == "smart_home" && get_recipe_node_req("/obj/structure/smart_speaker") == "smart_home" && get_recipe_node_req("/obj/item/weapon/smart_lock") == "smart_home", "smart home recipes need the Smart Home node")
		// One powered cable run along y = 3, a device on each tile.
		var/list/run = list()
		for (var/x = 3, x <= 8, x++)
			var/obj/structure/cable/link = new(locate(x, 3, 1))
			if (run.len)
				var/obj/structure/cable/previous = run[run.len]
				previous.connections |= link
				link.connections |= previous
			run += link
		var/obj/structure/cable/C3 = run[1]
		var/obj/structure/engine/E = new(C3.loc)
		E.on = TRUE
		E.maxpower = 100
		C3.connections |= E
		E.connections |= C3
		var/obj/structure/smart_hub/hub = new(locate(3, 3, 1))
		var/obj/structure/lamp/lamp_big/led/lamp = new(locate(4, 3, 1))
		var/obj/structure/simple_door/door = new(locate(5, 3, 1))
		var/obj/structure/telecom/radio = new(locate(6, 3, 1))
		var/obj/structure/smart_speaker/speaker = new(locate(8, 3, 1))
		radio.enabled = TRUE
		var/list/devices = list(hub, lamp, door, radio, speaker)
		for (var/i = 1, i <= devices.len, i++)
			var/obj/O = devices[i]
			var/obj/structure/cable/under = locate(/obj/structure/cable) in O.loc
			O.powersource = under
			under.connections |= O
		var/obj/item/weapon/smart_lock/lock = new(locate(5, 4, 1))
		door.smart_lock_fitted = TRUE
		door.powerneeded = 0.2
		qdel(lock)
		// A second, separate network a few tiles away.
		var/obj/structure/cable/far_cable = new(locate(12, 3, 1))
		var/obj/structure/engine/far_engine = new(far_cable.loc)
		far_engine.on = TRUE
		far_engine.maxpower = 100
		far_cable.connections |= far_engine
		far_engine.connections |= far_cable
		var/obj/structure/lamp/lamp_big/led/far_lamp = new(far_cable.loc)
		far_lamp.powersource = far_cable
		far_cable.connections |= far_lamp
		smart_check(hub.hub_id && hub.operational() && (hub in smart_hubs), "a powered hub runs and has an id")
		smart_check(far_lamp.draw_cable_power() && lamp.draw_cable_power() && door.draw_cable_power() && radio.draw_cable_power(), "every device draws power")
		smart_check(hub.reaches(lamp) && hub.reaches(door) && hub.reaches(radio) && !hub.reaches(far_lamp), "the hub reaches its own network only")
		smart_check(lamp.smart_kind() == "light" && door.smart_kind() == "lock" && radio.smart_kind() == "plug" && !speaker.smart_kind() && !hub.smart_kind(), "device kinds")
		var/list/pairable = hub.pairable()
		smart_check((lamp in pairable) && (door in pairable) && (radio in pairable) && !(far_lamp in pairable), "pairing offers only its network's devices")
		smart_check(hub.pair(lamp, "Kitchen Light") == "Paired kitchen light." && hub.pair(door, "front door") == "Paired front door." && hub.pair(radio, "radio") == "Paired radio.", "pair three devices")
		smart_check(hub.pair(far_lamp, "barn light") != "Paired barn light." && !far_lamp.smart_hub_id, "a device on another network is refused")
		smart_check(hub.devices().len == 3, "three paired devices")
		var/mob/living/human/smart_fixture/owner = smart_fixture_person(3, "owner", "Ola")
		var/mob/living/human/smart_fixture/resident = smart_fixture_person(4, "resident", "Remy")
		var/mob/living/human/smart_fixture/guest = smart_fixture_person(5, "guest", "Gus")
		hub.owner_ckey = "owner"
		hub.owner_name = "Ola"
		hub.residents["resident"] = "Remy"
		smart_check(hub.access_level(owner) == 2 && hub.access_level(resident) == 1 && hub.access_level(guest) == 0, "owner, resident and guest rights")
		smart_check(hub.strip_wake("Hub, lights off!") == "lights off" && hub.strip_wake("hey hub status") == "status" && hub.strip_wake("hub") == "", "wake name starts a command")
		smart_check(isnull(hub.strip_wake("the hub is broken")) && isnull(hub.strip_wake("Hubert, lights off")), "lines not starting with the name are ignored")
		smart_check(findtext(hub.run_command(guest, "kitchen light off"), "Only residents") && !lamp.smart_off, "a guest cannot switch devices")
		smart_check(hub.run_command(resident, "turn off the kitchen light") == "Kitchen light off." && lamp.smart_off, "a resident switches the light off")
		smart_check(!lamp.draw_cable_power() && !hub.reaches(far_lamp) && hub.reaches(lamp), "a switched-off light draws no power but stays reachable")
		smart_check(hub.run_command(resident, "lights on") == "Kitchen light on." && !lamp.smart_off && lamp.draw_cable_power(), "lights on")
		smart_check(hub.run_command(owner, "radio off") == "Radio off." && !radio.draw_cable_power() && !radio.operational(), "a plug cuts a machine's power")
		smart_check(hub.run_command(owner, "toggle radio") == "Radio on." && radio.draw_cable_power(), "toggle switches it back")
		smart_check(findtext(hub.run_command(owner, "lock the front door"), "Front door locked") && door.locked, "lock a door by voice")
		smart_check(!door.canOpen(guest) && door.door_hand_locked(guest), "a guest cannot open the locked door")
		smart_check(door.canOpen(resident) && !door.locked, "a resident's hand opens the smart lock")
		door.locked = TRUE
		E.on = FALSE
		smart_check(!hub.operational() && door.door_hand_locked(resident) && door.locked, "with no power the lock stays shut")
		E.on = TRUE
		smart_check(hub.run_command(resident, "unlock front door") == "Front door unlocked." && !door.locked, "unlock by voice")
		door.state = TRUE
		smart_check(findtext(hub.run_command(resident, "lock up"), "front door is open") && !door.locked, "an open door is not locked")
		door.state = FALSE
		smart_check(hub.run_command(resident, "lock up") == "Front door locked." && door.locked, "lock up")
		smart_check(findtext(hub.run_command(guest, "status"), "online") && findtext(hub.run_command(owner, "status"), "1 of 1 light on"), "status by rights")
		smart_check(findtext(hub.run_command(resident, "devices"), "front door locked"), "device list")
		smart_check(findtext(hub.run_command(guest, "what time is it"), "It is "), "time of day")
		smart_check(findtext(hub.run_command(guest, "sing a song"), "help"), "unknown requests point to help")
		smart_check(hub.run_command(resident, "set a timer for 5 minutes") == "Timer set for 5 minutes." && hub.timer_left.len == 1 && hub.timer_left[1] == 3000 && (hub in processing_objects), "set a timer")
		smart_check(findtext(hub.run_command(resident, "timer 2 hours"), "1 hour") && hub.timer_left.len == 1, "timers are capped at an hour")
		hub.advance_timers(600)
		smart_check(hub.timer_left[1] == 2400 && findtext(hub.run_command(resident, "timers"), "4 minutes left"), "a timer counts down")
		smart_check(hub.run_command(resident, "cancel timers") == "Cancelled 1 timer." && !hub.timer_left.len, "cancel timers")
		hub.run_command(resident, "timer 10 seconds")
		smart_check(hub.advance_timers(100) == PROCESS_KILL && !hub.timer_left.len, "a finished timer rings and stops processing")
		smart_check(hub.heard(resident, "Hub, status", hub) && !hub.heard(resident, "Hub, status", hub), "one reply per two seconds")
		hub.last_reply = -100
		smart_check(!hub.heard(resident, "lights off", hub) && !lamp.smart_off, "speech without the name is ignored")
		var/mob/living/human/smart_fixture/visitor = smart_fixture_person(9, "resident", "Remy far")
		visitor.loc = locate(9, 3, 1)
		smart_check(!hub.heard(visitor, "hub, lights off", hub) && !lamp.smart_off, "too far from the hub")
		speaker.hear_talk(visitor, "hub, lights off", "says", null)
		smart_check(lamp.smart_off, "a satellite speaker carries the command to the hub")
		hub.residents -= "resident"
		smart_check(hub.access_level(resident) == 0 && findtext(hub.run_command(resident, "lights on"), "Only residents"), "a removed resident loses access")
		hub.residents["resident"] = "Remy"
		resident.civilization = "Harbour"
		guest.civilization = "Harbour"
		hub.share_faction = TRUE
		hub.owner_faction = "Harbour"
		smart_check(hub.access_level(guest) == 1, "sharing with the owner's faction")
		hub.share_faction = FALSE
		smart_check(findtext(hub.pair(lamp, "radio"), "Another device") || findtext(hub.pair(lamp, "radio"), "not on"), "names stay unique")
		smart_check(hub.pair(far_lamp, "lights") == "Pick another name.", "reserved names are refused")
		hub.hub_name = "jarvis two"
		smart_check(hub.strip_wake("Jarvis two, lights on") == "lights on" && isnull(hub.strip_wake("hub, lights on")), "renamed hub answers its new name")
		hub.run_command(resident, "timer 3 minutes")
		var/hub_id = hub.hub_id
		qdel(owner)
		qdel(resident)
		qdel(guest)
		qdel(visitor)
		smart_check(map_storage.Save_World() && map_storage.validate_world_save(), "native save")
		map_storage.ClearMap()
		smart_check(map_storage.Load_World(), "native reload")
		var/obj/structure/smart_hub/restored = locate(/obj/structure/smart_hub) in locate(3, 3, 1)
		var/obj/structure/lamp/lamp_big/led/restored_lamp = locate(/obj/structure/lamp/lamp_big/led) in locate(4, 3, 1)
		var/obj/structure/simple_door/restored_door = locate(/obj/structure/simple_door) in locate(5, 3, 1)
		smart_check(restored && restored.hub_id == hub_id && restored.owner_ckey == "owner" && restored.residents["resident"] == "Remy" && restored.hub_name == "jarvis two" && (restored in smart_hubs), "hub settings survive a save")
		smart_check(restored && restored.timer_left.len == 1 && restored.timer_left[1] == 1800 && (restored in processing_objects), "a running timer resumes after a load")
		smart_check(restored_lamp && restored_lamp.smart_hub_id == hub_id && restored_lamp.smart_label == "kitchen light" && restored_lamp.smart_off, "light pairing and state survive")
		smart_check(restored_door && restored_door.smart_lock_fitted && restored_door.locked && restored_door.smart_label == "front door", "smart lock survives")
		smart_check(restored && restored.operational() && restored.devices().len == 3 && restored.reaches(restored_lamp), "restored hub reaches its devices")
	catch (var/exception/e)
		smart_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = smart_failures, "byond_build" = world.byond_build)), "result.json")
	del(world)
