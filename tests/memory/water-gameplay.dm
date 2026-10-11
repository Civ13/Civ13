// Test-only extension. Include after civ13.dme in a LOCAL validation build.
// Never include in the production environment or run on a production server.
/client/proc/verify_water_registry_gameplay()
    set name = "LOCAL Verify Water Registry"
    set category = "Debug"
    if (!holder || (address && address != "127.0.0.1" && address != "::1"))
        return
    // Allow deterministic CLI entry from the local lobby using the real job spawn path.
    if (istype(mob, /mob/new_player))
        if (!ticker || ticker.current_state != GAME_STATE_PLAYING || !ticker.players_can_join)
            to_chat(src, "FAIL local water test: wait for the round to start")
            return
        var/mob/new_player/player = mob
        player.close_spawn_windows()
        player.AttemptLateSpawn("Nomad")
    var/turf/floor/target
    for (var/turf/floor/F in orange(1, mob))
        if (!istype(F, /turf/floor/beach/water) && !F.density && !locate(/obj/structure) in F)
            target = F
            break
    if (!target)
        to_chat(src, "FAIL water test: no clear adjacent floor")
        return
    var/original_type = target.type
    var/baseline = water_turf_list.len
    for (var/cycle = 1 to 20)
        target = target.ChangeTurf(/turf/floor/beach/water)
        if (water_turf_list.len != baseline + 1)
            to_chat(src, "FAIL water registration, cycle [cycle]")
            return
        target = target.ChangeTurf(/turf/floor/beach/water/deep)
        if (water_turf_list.len != baseline + 1)
            to_chat(src, "FAIL water subtype replacement, cycle [cycle]")
            return
        target = target.ChangeTurf(original_type)
        if (water_turf_list.len != baseline)
            to_chat(src, "FAIL water cleanup, cycle [cycle]")
            return
    // Leave one visible shallow-water tile for ordinary movement/Examine checks.
    target.ChangeTurf(/turf/floor/beach/water)
    to_chat(src, "<b>PASS local water registry: 20 wet/deep/dry cycles; baseline [baseline], final [water_turf_list.len] (one visible water tile).</b>")
