// Included only by the isolated Windows launcher. No production startup recorder.
/world/OpenPort(port)
    if(port == "none") return ..()
    return FALSE
/world/New()
    OpenPort("none")
    if(config)
        config.webhook_can_fire = FALSE
        config.ToRban = FALSE
    ..()
    if(config)
        config.webhook_can_fire = FALSE
        config.ToRban = FALSE

/datum/memory_lifetime_recorder/game_probe/record_snapshot()
    var/list/row = ..()
    row["native_world_time_deciseconds"] = world.time
    row["native_timeofday_deciseconds"] = world.timeofday
    return row

var/global/datum/memory_telemetry_game_probe/memory_telemetry_game_probe = new
/datum/memory_telemetry_game_probe
    var/list/owned_effects = list()
    var/created_effects = 0
    var/created_systems = 0
    var/peak_owned_effects = 0
    var/datum/memory_lifetime_recorder/game_probe/recorder
/datum/memory_telemetry_game_probe/New()
    if(config)
        config.webhook_can_fire = FALSE
        config.ToRban = FALSE
    spawn(10)
        run_probe()
/datum/memory_telemetry_game_probe/proc/clear_effects()
    for(var/obj/effect/E in owned_effects)
        qdel(E)
    owned_effects.Cut()
/datum/memory_telemetry_game_probe/proc/run_probe()
    try
        var/attempts = 0
        while(!map || !ticker || !processScheduler || !processes.garbage || !processes.callproc || !processes.scheduler)
            if(attempts++ >= 150) throw EXCEPTION("Normal startup not ready within fifteen seconds")
            sleep(1)
        if(!istype(map, /obj/map_metadata/nomads)) throw EXCEPTION("Expected native Nomads startup")
        if(world.port || world.OpenPort(0) || world.port) throw EXCEPTION("Isolated port did not stay closed")
        if(config.webhook_can_fire || config.ToRban) throw EXCEPTION("Outbound adapters enabled")
        var/turf/T = locate(world.maxx - 2, world.maxy - 2, 1)
        if(!T) throw EXCEPTION("No bounded effect exercise turf")
        recorder = new
        var/start_timeofday = world.timeofday
        var/start_world_time = world.time
        text2file(json_encode(list("native_timeofday_deciseconds" = start_timeofday, "native_world_time_deciseconds" = start_world_time, "tested_commit" = world.params["tested_commit"])), "telemetry-ready.json")
        if(!recorder.start(40) || recorder.start(40)) throw EXCEPTION("Recorder single active invocation contract")
        // 25 cadences x (20 directly constructed effects + one system spark) = 525.
        // Direct construction exercises idle-pool caps and real GC enqueue rates.
        // Only test-created ephemera are retired. No useful assets or seasons change.
        for(var/cadence in 1 to 25)
            clear_effects()
            for(var/i in 1 to 20)
                var/obj/effect/E
                if(i % 2)
                    E = new /obj/effect/effect/smoke(T)
                else
                    E = new /obj/effect/sparks(T)
                owned_effects += E
                created_effects++
            var/list/prior_sparks = list()
            for(var/obj/effect/sparks/S in T) prior_sparks += S
            var/datum/effect/effect/system/spark_spread/system = PoolOrNew(/datum/effect/effect/system/spark_spread)
            system.set_up(1, FALSE, T)
            system.start()
            created_systems++
            sleep(1)
            for(var/obj/effect/sparks/S in T)
                if(!(S in prior_sparks))
                    owned_effects += S
                    created_effects++
            qdel(system)
            peak_owned_effects = max(peak_owned_effects, owned_effects.len)
            if(owned_effects.len > 40 || created_effects > 600) throw EXCEPTION("Effect exercise exceeded finite bounds")
            sleep(9)
        clear_effects()
        var/wait_started = world.timeofday
        while(recorder.active)
            var/wait_elapsed = world.timeofday - wait_started
            if(wait_elapsed < 0) wait_elapsed += 864000
            if(wait_elapsed >= 600) break
            sleep(1)
        if(recorder.active) throw EXCEPTION("Recorder did not stop at finite sample count")
        var/list/rows = recorder.export_rows()
        if(rows.len != 40 || recorder.tick_intervals.len > 120 || recorder.rows.len > 120) throw EXCEPTION("Recorder sample bounds")
        var/list/result = list("passed" = TRUE, "tested_commit" = world.params["tested_commit"], "map_id" = map.ID, "byond_version" = world.byond_version, "byond_build" = world.byond_build, "port" = world.port, "native_clock" = "world.timeofday deciseconds modulo midnight; actual sample fields retain world.time", "sample_seconds" = recorder.elapsed_seconds, "created_effects" = created_effects, "created_systems" = created_systems, "peak_owned_effects" = peak_owned_effects, "max_created_effects" = 600, "max_owned_effects" = 40, "max_native_rows" = 120, "tick_metric_scope" = "awake scheduling intervals over latest <=120 observations, not CPU duration or production tick p95", "native_rows" = rows)
        text2file(json_encode(result), "telemetry-result.json")
        text2file("PASS: finite native Nomads telemetry and effect churn", "telemetry-result.txt")
        qdel(recorder)
    catch(var/exception/e)
        world.log << "TELEMETRY FAIL: [e] at [e.file]:[e.line]"
        text2file("FAIL: [e]", "telemetry-result.txt")
    del(world)
