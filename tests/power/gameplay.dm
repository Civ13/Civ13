// Opt-in isolated full-game evidence adapter. Never included by civ13.dme.
#ifndef POWER_EVIDENCE_TOKEN
#error Define a per-run POWER_EVIDENCE_TOKEN before including this adapter.
#endif
var/global/datum/power_evidence_scene/power_evidence = new

/datum/power_evidence_scene
	var/mob/living/human/operator
	var/obj/structure/engine/external/steam/engine
	var/obj/structure/heatsource/furnace
	var/obj/structure/lamp/near_lamp
	var/obj/structure/lamp/far_lamp
	var/obj/structure/cable/root
	var/obj/structure/cable/middle
	var/obj/structure/cable/remote
	var/stage = "not prepared"
	var/started = 0

/datum/power_evidence_scene/proc/setup()
	if (operator)
		return
	// Bounded scene inside the normal loaded map, with genuine game assets.
	for (var/x = 78, x <= 92, x++)
		for (var/y = 81, y <= 89, y++)
			var/turf/T = locate(x,y,1)
			for (var/obj/OB in T)
				qdel(OB)
			new /turf/floor/plating(T)
	operator = new(locate(83,84,1))
	operator.name = "Power verification operator"
	operator.a_intent = I_HELP
	engine = new(locate(82,85,1))
	engine.anchored = TRUE
	furnace = new(locate(81,85,1))
	var/obj/item/stack/ore/coal/coal = new(operator)
	coal.amount = 10
	operator.forceMove(locate(81,84,1))
	furnace.attackby(coal,operator)
	furnace.attack_hand(operator)
	var/obj/item/stack/cable_coil/coil = new(operator)
	coil.amount = 50
	operator.forceMove(locate(83,85,1))
	engine.attackby(coil,operator)
	for (var/obj/structure/cable/CB in engine.connections)
		root = CB
	near_lamp = new(locate(86,85,1))
	operator.forceMove(locate(85,85,1))
	near_lamp.attackby(coil,operator)
	far_lamp = new(locate(88,85,1))
	operator.forceMove(locate(87,85,1))
	far_lamp.attackby(coil,operator)
	for (var/x = 83, x <= 87, x++)
		if (x == 86)
			continue
		operator.forceMove(locate(x,85,1))
		var/obj/structure/cable/CB = coil.place_turf(get_turf(operator),operator,EAST)
		if (x == 85)
			middle = CB
	remote = far_lamp.powersource
	qdel(coil)
	operator.forceMove(locate(85,84,1))
	engine.turn_on(operator)
	started = world.time
	stage = "connected: one coal-fired engine, two lamps"

/datum/power_evidence_scene/proc/snapshot()
	return list("commit" = POWER_EVIDENCE_COMMIT, "map" = map ? map.title : "", "dimensions" = list(world.maxx,world.maxy,world.maxz), "stage" = stage, "elapsed_ds" = world.time-started, "engine_on" = engine ? engine.on : FALSE, "engine_capacity" = engine ? engine.maxpower : 0, "furnace_fuel" = furnace ? furnace.fuel : 0, "root_capacity" = root ? root.powerflow : 0, "remote_capacity" = remote ? remote.powerflow : 0, "root_demand" = root ? root.currentflow : 0, "remote_demand" = remote ? remote.currentflow : 0, "near_lamp_on" = near_lamp ? near_lamp.on : FALSE, "far_lamp_on" = far_lamp ? far_lamp.on : FALSE)

/datum/power_evidence_scene/proc/action(action,client/C)
	if (C && (!C.holder || (C.address && C.address != "127.0.0.1" && C.address != "::1")))
		return list("error" = "local test admin required")
	if (action == "setup")
		setup()
	if (!operator)
		return snapshot()
	usr = operator
	if (action == "view" && C)
		if (istype(C.mob,/mob/new_player))
			var/mob/new_player/player = C.mob
			player.close_spawn_windows()
		C.mob = operator
		C.screen -= lobby_image
		C.eye = operator
		C.view = 7
		winset(C,"mapwindow.map","is-visible=true;focus=true")
	if (action == "cut" && middle)
		operator.forceMove(locate(85,84,1))
		var/obj/item/weapon/wirecutters/cutters = new(operator)
		middle.attackby(cutters,operator)
		middle = null
		qdel(cutters)
		stage = "middle wire cut: remote lamps disconnected"
	if (action == "reconnect" && !middle)
		var/obj/item/stack/cable_coil/coil = new(operator)
		operator.forceMove(locate(85,85,1))
		middle = coil.place_turf(get_turf(operator),operator,EAST)
		qdel(coil)
		operator.forceMove(locate(85,84,1))
		stage = "middle wire replaced: power restored"
	if (action == "remove-load" && near_lamp)
		qdel(near_lamp)
		near_lamp = null
		stage = "one lamp removed: remaining demand is two"
	if (action == "stop" && engine.on)
		engine.attack_hand(operator)
		stage = "engine switched off: zero capacity"
	var/list/result = snapshot()
	world.log << "LOCAL POWER EVIDENCE [json_encode(result)]"
	if (C)
		to_chat(C,"<b>POWER EVIDENCE [copytext(POWER_EVIDENCE_COMMIT,1,10)]</b> [stage] | engine [result["engine_capacity"]] | root [result["root_capacity"]] / remote [result["remote_capacity"]] | demand [result["root_demand"]] / [result["remote_demand"]] | lamps [result["near_lamp_on"]]/[result["far_lamp_on"]] | elapsed [result["elapsed_ds"]] ds")
	return result

/world/Topic(T,addr,master,key)
	var/list/request = params2list(T)
	if (request["power-evidence"] != POWER_EVIDENCE_TOKEN)
		return ..()
	var/list/address_parts = splittext(addr,":")
	if (addr && addr != "::1" && !(address_parts.len <= 2 && address_parts[1] == "127.0.0.1"))
		return "LOCAL ONLY"
	var/action = request["action"]
	if (!(action in list("status","setup","view","cut","reconnect","remove-load","stop")))
		return "UNKNOWN ACTION"
	var/client/C
	for (var/client/local_client in clients)
		if (local_client.holder && (!local_client.address || local_client.address == "127.0.0.1" || local_client.address == "::1"))
			C = local_client
			break
	return json_encode(power_evidence.action(action,C))

/client/verb/power_evidence_status()
	set name = "Power Evidence Status"
	set category = "Power evidence"
	power_evidence.action("status",src)
/client/verb/power_evidence_cut()
	set name = "Power Evidence Cut"
	set category = "Power evidence"
	power_evidence.action("cut",src)
/client/verb/power_evidence_reconnect()
	set name = "Power Evidence Reconnect"
	set category = "Power evidence"
	power_evidence.action("reconnect",src)
/client/verb/power_evidence_remove_load()
	set name = "Power Evidence Remove Load"
	set category = "Power evidence"
	power_evidence.action("remove-load",src)
/client/verb/power_evidence_stop()
	set name = "Power Evidence Stop"
	set category = "Power evidence"
	power_evidence.action("stop",src)
