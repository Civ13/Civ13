// Opt-in adapter for isolated evidence builds only. Excluded from civ13.dme.
#ifndef MEMORY_EVIDENCE_TOKEN
#error Define a per-run MEMORY_EVIDENCE_TOKEN before including this file.
#endif
/world/Topic(T, addr, master, key)
    var/list/request = params2list(T)
    if (request["memory-evidence"] != MEMORY_EVIDENCE_TOKEN)
        return ..()
    // Native world.Export callers include their listening port in addr.
    var/list/caller = splittext(addr, ":")
    if (addr && addr != "::1" && !(caller.len >= 1 && caller.len <= 2 && caller[1] == "127.0.0.1"))
        return "LOCAL ONLY"
    var/client/C
    for (var/client/local_client in clients)
        if (local_client.holder && (!local_client.address || local_client.address == "127.0.0.1" || local_client.address == "::1"))
            C = local_client
            break
    var/list/result = list("commit" = MEMORY_EVIDENCE_COMMIT, "map" = map ? map.title : "", "dimensions" = list(world.maxx,world.maxy,world.maxz), "client" = !!C, "state" = ticker ? ticker.current_state : -1)
    if (!C)
        return json_encode(result)
    var/action = request["action"]
    if (action == "prepare")
        if (ticker && ticker.current_state == GAME_STATE_PREGAME)
            round_progressing = TRUE
            ticker.pregame_timeleft = 1
            ticker.admin_started = TRUE
    if (action == "join")
        if (ticker && ticker.current_state == GAME_STATE_PLAYING && ticker.players_can_join && istype(C.mob, /mob/new_player))
            var/mob/new_player/player = C.mob
            player.close_spawn_windows()
            player.AttemptLateSpawn("Nomad")
        C << browse(null, "window=memory")
        result["joined"] = istype(C.mob, /mob/living)
        to_chat(C, "LOCAL evidence commit: [MEMORY_EVIDENCE_COMMIT]")
    if (action == "run")
#ifdef MEMORY_EVIDENCE_WATER
        result["passed"] = C.verify_water_registry_gameplay()
        result["registry"] = water_turf_list.len
#endif
#ifdef MEMORY_EVIDENCE_OBSERVER
        result["passed"] = C.verify_observer_cleanup_gameplay()
#endif
#ifdef MEMORY_EVIDENCE_SEASON
        map.seasons(FALSE, TRUE)
        result["season"] = global.season
#endif
    if (action == "move" && istype(C.mob, /mob/living))
        result["moved"] = step(C.mob, text2num(request["direction"]))
    if (action == "examine" && istype(C.mob, /mob/living))
        for (var/obj/structure/wild/tree/tree in view(2, C.mob))
            tree.examine(C.mob)
            result["examined"] = tree.name
            break
    var/turf/location = get_turf(C.mob)
    if (location)
        result["position"] = list(location.x, location.y, location.z)
    world.log << "LOCAL EVIDENCE [action]: [json_encode(result)]"
    return json_encode(result)

