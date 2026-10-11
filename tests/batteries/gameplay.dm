#ifndef BATTERY_EVIDENCE_TOKEN
#error Define BATTERY_EVIDENCE_TOKEN before including this opt-in adapter.
#endif
var/obj/structure/battery/lead_acid/battery_evidence_storage
var/obj/structure/battery/battery_evidence_primary
var/obj/structure/engine/battery_evidence_generator
var/obj/structure/cable/battery_evidence_cut
/world/Topic(T, addr, master, key)
	var/list/request = params2list(T)
	if (request["battery-evidence"] != BATTERY_EVIDENCE_TOKEN) return ..()
	var/list/address_parts = splittext(addr, ":")
	if (addr && addr != "::1" && !(address_parts.len >= 1 && address_parts.len <= 2 && address_parts[1] == "127.0.0.1")) return "LOCAL ONLY"
	var/client/C
	for (var/client/local_client in clients)
		if (local_client.holder && (!local_client.address || local_client.address == "127.0.0.1" || local_client.address == "::1"))
			C = local_client
			break
	var/list/result = list("commit" = BATTERY_EVIDENCE_COMMIT, "map" = map ? map.title : "", "dimensions" = list(world.maxx,world.maxy,world.maxz), "client" = !!C, "state" = ticker ? ticker.current_state : -1)
	if (!C) return json_encode(result)
	usr = C.mob
	var/action = request["action"]
	if (action == "prepare" && ticker && ticker.current_state == GAME_STATE_PREGAME)
		round_progressing = TRUE
		ticker.pregame_timeleft = 1
		ticker.admin_started = TRUE
	if (action == "join" && ticker && ticker.current_state == GAME_STATE_PLAYING && ticker.players_can_join && istype(C.mob, /mob/new_player))
		var/mob/new_player/player = C.mob
		player.close_spawn_windows()
		player.AttemptLateSpawn("Nomad")
		C << browse(null, "window=memory")
		to_chat(C, "LOCAL BATTERY evidence commit: [BATTERY_EVIDENCE_COMMIT]")
	if (action == "run" && istype(C.mob, /mob/living/human) && !battery_evidence_storage)
		var/turf/center = get_turf(C.mob)
		var/ox = min(world.maxx - 5, max(2, center.x))
		var/oy = min(world.maxy - 5, max(2, center.y))
		var/list/chain = list()
		for (var/x = ox, x <= ox + 3, x++)
			var/turf/tile = locate(x,oy,center.z)
			for (var/obj/structure/obstacle in tile) qdel(obstacle)
			var/obj/structure/cable/CB = new(tile)
			CB.tilepos = "over"
			CB.layer = 3
			CB.tiledir = "horizontal"
			CB.update_icon()
			if (chain.len)
				var/obj/structure/cable/previous = chain[chain.len]
				CB.connections |= previous
				previous.connections |= CB
			chain += CB
		battery_evidence_cut = chain[4]
		battery_evidence_generator = new(locate(ox,oy,center.z))
		battery_evidence_generator.name = "isolated test generator (20 PU)"
		battery_evidence_generator.anchored = TRUE
		battery_evidence_generator.on = TRUE
		battery_evidence_generator.maxpower = 20
		battery_evidence_generator.connections = list(chain[1])
		var/obj/structure/cable/root = chain[1]
		root.connections |= battery_evidence_generator
		battery_evidence_storage = new(locate(ox+2,oy,center.z))
		battery_evidence_storage.anchored = TRUE
		var/obj/item/weapon/reagent_containers/glass/beaker/R = new(center)
		R.reagents.add_reagent("sacid",20)
		battery_evidence_storage.attackby(R,C.mob)
		var/obj/structure/cable/port = chain[3]
		battery_evidence_storage.powersource = port
		port.connections |= battery_evidence_storage
		var/obj/structure/lamp/lamp_small/lamp = new(locate(ox+3,oy,center.z))
		lamp.anchored = TRUE
		lamp.powersource = chain[4]
		battery_evidence_cut.connections |= lamp
		lamp.do_light()
		battery_evidence_primary = new(locate(ox+2,oy+2,center.z))
		battery_evidence_primary.assembled = TRUE
		var/obj/item/stack/material/iron/I = new(center,1,FALSE)
		battery_evidence_primary.attackby(I,C.mob)
		R.reagents.add_reagent("grapejuice",10)
		battery_evidence_primary.attackby(R,C.mob)
		qdel(R)
		root.rebuild_supply()
		to_chat(C, "LOCAL TEST: 20 PU fixture generator, empty lead-acid accumulator and 1 PU lamp. Primary jar commissioned with real iron/electrolyte. Generator is an adapter; this does not test fuel combustion.")
	if (action == "charge" && battery_evidence_storage)
		battery_evidence_storage.mode = "off"
		battery_evidence_storage.attack_hand(C.mob)
	if (action == "discharge" && battery_evidence_storage)
		battery_evidence_generator.on = FALSE
		for (var/obj/structure/cable/CB in battery_evidence_generator.connections) CB.rebuild_supply()
		battery_evidence_storage.mode = "charge"
		battery_evidence_storage.attack_hand(C.mob)
	if (action == "cut" && battery_evidence_cut)
		var/obj/item/weapon/wirecutters/W = new(get_turf(C.mob))
		battery_evidence_cut.attackby(W,C.mob)
		qdel(W)
	if (action == "examine")
		if (battery_evidence_storage) battery_evidence_storage.examine(C.mob)
		if (battery_evidence_primary) battery_evidence_primary.examine(C.mob)
	if (battery_evidence_storage)
		result["energy"] = battery_evidence_storage.stored_energy
		result["mode"] = battery_evidence_storage.mode
		result["source_running"] = battery_evidence_generator.on
	if (battery_evidence_primary) result["primary_energy"] = battery_evidence_primary.stored_energy
	world.log << "LOCAL BATTERY EVIDENCE [action]: [json_encode(result)]"
	return json_encode(result)
