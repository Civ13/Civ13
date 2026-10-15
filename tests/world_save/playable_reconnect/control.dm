// Isolated acceptance observer. Never included by the production DME.
/world/IsBanned(key, address, computer_id, type)
	if(world.params["gaia_intent_seed"] == "1" || address != "127.0.0.1" || ckey(key) != "valzargaming")
		return list("reason" = "isolated acceptance host", "message" = "Only the test operator may join")
	return ..()

/proc/gaia_probe_seed_intent()
	world.OpenPort(0)
	world.visibility = FALSE
	var/list/result = list("passed" = FALSE)
	try
		if(persistence_restart.exists()) throw EXCEPTION("Refusing existing intent")
		persistence_save_in_progress = TRUE
		if(!map_storage.prepare_saved_dimensions()) throw EXCEPTION("Dimension validation failed: [map_storage.last_error]")
		var/list/I = persistence_restart.current_identity()
		persistence_restart.publish(I)
		result["passed"] = TRUE
		result["identity"] = I
	catch(var/exception/e)
		result["error"] = "[e] on [e.file]:[e.line]"
	text2file(json_encode(result), "seed-result.json")
	del(world)

/proc/gaia_probe_status()
	var/list/humans = list()
	for(var/mob/living/human/H in world)
		if(H.persistence_owner_ckey != "valzargaming" && (!H.client || H.client.ckey != "valzargaming")) continue
		var/turf/T = get_turf(H)
		var/list/items = list()
		for(var/obj/item/I in H.contents)
			items += list(list("type" = "[I.type]", "name" = I.name))
		humans += list(list("name" = H.name, "ref" = "\ref[H]", "owner" = H.persistence_owner_ckey, "restored" = H.persistence_restored, "client" = !!H.client, "client_ref" = H.client ? "\ref[H.client]" : null, "mind_current_is_body" = H.mind ? H.mind.current == H : FALSE, "account" = H.client ? H.client.ckey : null, "mind_active" = H.mind ? H.mind.active : null, "stat" = H.stat, "health" = H.health, "x" = T ? T.x : 0, "y" = T ? T.y : 0, "z" = T ? T.z : 0, "inventory" = items))
	var/list/accounts = list()
	for(var/client/C in clients)
		accounts += list(list("account" = C.ckey, "client_ref" = "\ref[C]", "mob_type" = "[C.mob.type]", "mob_ref" = "\ref[C.mob]"))
	var/list/S = nomads_lifecycle.snapshot()
	S["import_started"] = persistence_restart.import_started
	S["players_ready"] = persistence_restart.players_ready
	S["state"] = ticker ? ticker.current_state : -1
	S["game_id"] = game_id
	S["world_time"] = world.time
	S["season"] = season
	S["time_of_day"] = time_of_day
	S["research_clock"] = map ? map.research_time() : 0
	S["humans"] = humans
	S["accounts"] = accounts
	return S

/proc/gaia_probe_topic(T, addr)
	var/list/Q = params2list(T)
	var/list/peer = istext(addr) ? splittext(addr, ":") : list("")
	var/token = nomads_lifecycle.read_token()
	if(peer[1] != "127.0.0.1" || !nomads_lifecycle_hex(token, 32) || Q["token"] != token || Q.len != 3 || Q["gaia_probe"] != "1" || Q["action"] != "status")
		return "rejected"
	return json_encode(gaia_probe_status())

