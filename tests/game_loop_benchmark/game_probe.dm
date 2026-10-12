// Isolated normal-game benchmark. Subtype instrumentation inherits production Life.
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
var/global/game_loop_tick_checks = 0
var/global/game_loop_early_returns = 0
var/global/game_loop_runtime_error = FALSE
/world/Error(exception/error)
    game_loop_runtime_error = TRUE
    world.log << "GAME LOOP runtime error: [error]"
    return ..()
/mob/living/human/game_loop_actor
    var/life_calls = 0
    var/last_probe_life = 0
    var/natural_max_gap_deciseconds = 0
    var/restart_max_gap_deciseconds = 0
/mob/living/human/game_loop_actor/ssd_check()
    return FALSE // Only disconnected-client sleep is adapted for headless actors.
/mob/living/human/game_loop_actor/Life()
    if(last_probe_life)
        if(game_loop_benchmark.phase == "natural")
            natural_max_gap_deciseconds = max(natural_max_gap_deciseconds, world.time-last_probe_life)
        else
            restart_max_gap_deciseconds = max(restart_max_gap_deciseconds, world.time-last_probe_life)
    last_probe_life = world.time
    life_calls++
    return ..()
var/global/datum/game_loop_benchmark/game_loop_benchmark = new
/datum/game_loop_benchmark
    var/callbacks = 0
    var/list/callback_delays = list()
    var/list/actors = list()
    var/list/rows = list()
    var/phase = "natural"
/datum/game_loop_benchmark/New()
    if(config)
        config.webhook_can_fire = FALSE
        config.ToRban = FALSE
    spawn(10)
        run_probe()
/datum/game_loop_benchmark/proc/callback(expected)
    callbacks++
    callback_delays += world.time - expected
/datum/game_loop_benchmark/proc/run_probe()
    try
        var/attempts = 0
        while(!map || !ticker || !processScheduler || !processes.garbage || !processes.callproc || !processes.mob)
            if(attempts++ >= 150) throw EXCEPTION("Startup readiness timeout")
            sleep(1)
        if(!istype(map, /obj/map_metadata/nomads) || world.port || world.OpenPort(0) || config.webhook_can_fire || config.ToRban) throw EXCEPTION("Isolation contract failed")
        var/turf/T = locate(world.maxx - 4, world.maxy - 4, 1)
        // Prepare nine bounded test cells; no map-wide terrain changes.
        T = T.ChangeTurf(/turf/floor/plating)
        var/turf/U = locate(T.x + 1, T.y, 1)
        U = U.ChangeTurf(/turf/floor/plating)
        for(var/i in 1 to 8)
            var/turf/actor_turf = locate(T.x, T.y - i + 1, 1)
            actor_turf = actor_turf.ChangeTurf(/turf/floor/plating)
            var/mob/living/human/game_loop_actor/H = new(actor_turf)
            H.density = FALSE
            actors += H
        var/mob/living/human/game_loop_actor/A = actors[1]
        var/obj/item/I = new /obj/item(T)
        var/list/retired_refs = list()
        var/moves = 0
        var/inventory_cycles = 0
        var/initial_gc_drained = processes.garbage.queued_drained
        var/constructed_effects = 0
        var/start = world.time
        var/start_tod = world.timeofday
        text2file(json_encode(list("world_time_deciseconds"=start,"timeofday_deciseconds"=start_tod)), "ready.json")
        var/previous_tod = start_tod
        var/list/natural_lives = list()
        for(var/sample in 1 to 650)
            if(sample <= 20)
                if(!A.put_in_active_hand(I) || I.loc != A) throw EXCEPTION("Production pickup identity failed sample=[sample] lying=[A.lying] stat=[A.stat] sleeping=[A.sleeping]")
                A.drop_from_inventory(I,T)
                if(I.loc != T || A.get_active_hand() == I) throw EXCEPTION("Production drop identity failed")
                inventory_cycles++
                A.last_movement = 0
                A.next_move = 0
                var/turf/destination = A.loc == T ? U : T
                step(A, A.x == T.x ? EAST : WEST)
                if(A.loc != destination) throw EXCEPTION("Production step location failed")
                if(A.loc != T && A.loc != U) throw EXCEPTION("Movement location identity failed")
                moves++
                processes.callproc.queue(src,/datum/game_loop_benchmark/proc/callback,list(world.time+2),2)
                for(var/i in 1 to 20)
                    var/obj/effect/E = new /obj/effect(T)
                    var/refID = "\ref[E]"
                    qdel(E)
                    constructed_effects++
                    retired_refs += list(list("ref"=refID,"gc_stamp"=E.gcDestroyed))
            if(sample == 601)
                for(var/mob/living/human/game_loop_actor/H in actors) natural_lives += H.life_calls
                phase = "restart"
                text2file(json_encode(list("world_time_deciseconds"=world.time,"timeofday_deciseconds"=world.timeofday)),"restart.json")
                processScheduler.stop()
                processScheduler.start()
                processScheduler.stop()
                processScheduler.start()
            sleep(1)
            var/now = world.timeofday
            var/gap = now - previous_tod
            if(gap < 0) gap += 864000
            previous_tod = now
            var/list/lives = list()
            for(var/mob/living/human/game_loop_actor/H in actors) lives += H.life_calls
            rows += list(list("sample"=sample,"phase"=phase,"elapsed_world_deciseconds"=world.time-start,"awake_gap_deciseconds"=gap,"tick_usage_percent"=world.tick_usage,"queue_entries"=processes.garbage.destroyed.len,"gc_total_dels"=processes.garbage.total_dels,"mob_ticks"=processes.mob.ticks,"life_calls"=lives,"tick_check_evaluations"=game_loop_tick_checks,"tick_check_early_returns"=game_loop_early_returns))
        if(!I || I.loc != T || I.gcDestroyed || A.loc != T) throw EXCEPTION("Live item/mob identity changed during collector drain")
        var/list/unique_refs = list()
        for(var/list/entry in retired_refs)
            unique_refs |= entry["ref"]
        var/retained = 0
        for(var/list/entry in retired_refs)
            var/datum/D = locate(entry["ref"])
            if(D && D.gcDestroyed == entry["gc_stamp"]) retained++
        var/list/final_lives = list()
        var/list/service = list()
        var/actor_index = 0
        for(var/mob/living/human/game_loop_actor/H in actors)
            actor_index++
            final_lives += H.life_calls
            var/natural_calls = natural_lives[actor_index]
            var/restart_calls = H.life_calls-natural_calls
            if(natural_calls < 10 || restart_calls < 1) throw EXCEPTION("Actor service missing in natural/restart phase")
            if(world.params["variant"] == "current" && (H.natural_max_gap_deciseconds > 15 || H.restart_max_gap_deciseconds > 20)) throw EXCEPTION("Current actor service exceeded natural/restart gap bounds")
            service += list(list("actor"=actor_index,"natural_life_calls"=natural_calls,"restart_life_calls"=restart_calls,"natural_max_gap_deciseconds"=H.natural_max_gap_deciseconds,"restart_max_gap_deciseconds"=H.restart_max_gap_deciseconds))
            if(H.life_calls < 10) throw EXCEPTION("Normal scheduler did not service every human")
        text2file(json_encode(list("rows"=rows,"actor_service"=service,"callbacks"=callbacks,"retained"=retained,"unique_refs"=unique_refs.len,"final_world_time_deciseconds"=world.time,"gc_queued_drained_delta"=processes.garbage.queued_drained-initial_gc_drained)),"observations.json")
        if(callbacks != 20 || retained || game_loop_runtime_error || !game_loop_tick_checks || processes.garbage.queued_drained <= initial_gc_drained) throw EXCEPTION("Callback/collector/runtime/tick coverage failed callbacks=[callbacks] retained=[retained] runtime=[game_loop_runtime_error] checks=[game_loop_tick_checks] garbage_ticks=[processes.garbage.ticks] gc_dels=[processes.garbage.total_dels] queue=[processes.garbage.destroyed.len]")
        text2file(json_encode(list("passed"=TRUE,"tested_commit"=world.params["tested_commit"],"variant"=world.params["variant"],"byond_version"=world.byond_version,"byond_build"=world.byond_build,"port"=world.port,"map_id"=map.ID,"moves"=moves,"inventory_cycles"=inventory_cycles,"callbacks"=callbacks,"callback_delay_deciseconds"=callback_delays,"retired_effects"=constructed_effects,"gc_queued_drained_delta"=processes.garbage.queued_drained-initial_gc_drained,"retained_effects"=retained,"human_life_calls"=final_lives,"actor_service"=service,"unique_retired_refs"=unique_refs.len,"tick_check_evaluations"=game_loop_tick_checks,"tick_check_early_returns"=game_loop_early_returns,"rows"=rows)),"result.json")
        text2file("PASS: native scheduler human Life, movement/inventory, callbacks and collector drain","result.txt")
    catch(var/exception/e)
        world.log << "GAME LOOP FAIL: [e] at [e.file]:[e.line]"
        text2file("FAIL: [e] at [e.file]:[e.line]","result.txt")
    del(world)
