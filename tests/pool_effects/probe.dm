// Real production constructors, lifecycle and pooling. Only startup is isolated.
/world
    hub = ""
    hub_password = ""
    maxx = 4
    maxy = 4
    maxz = 1
    turf = /turf
    area = /area/pool_probe
/area/pool_probe
    dynamic_lighting = FALSE
/world/OpenPort(port)
    if(port == "none") return ..()
    return FALSE
var/pool_effect_walk_calls = 0
/proc/pool_effect_walk_observed(atom/movable/A, atom/destination, minimum, delay)
    pool_effect_walk_calls++
    walk_to(A, destination, minimum, delay)
var/pool_effect_failures = 0
var/pool_effect_checks = 0
/world/Error(exception/E)
    pool_effect_failures++
    world.log << "RUNTIME [E.name]"
    return
/proc/pool_effect_check(condition, message)
    pool_effect_checks++
    if(!condition)
        pool_effect_failures++
        world.log << "FAIL [message]"
/proc/pool_effect_empty()
    for(var/datum/D in pool_idle)
        pool_idle[D] = 0
    while(pool_idle.len)
        ExpirePools(32)
/proc/pool_effect_cycle(path, turf/T)
    var/atom/movable/A = PoolOrNew(path, T)
    pool_effect_check(A && A.loc == T && !QDELETED(A) && !A.gcDestroyed, "[path] real constructor live")
    A.name = "mutated pool effect"
    A.pixel_x = 87
    qdel(A)
    pool_effect_check(A && QDELETED(A) && A.gcDestroyed && !A.loc, "[path] retired state markers and location")
    pool_effect_check((A in GlobalPool[path]) && (A in pool_idle), "[path] bounded pool owns retired effect")
    var/atom/movable/B = PoolOrNew(path, T)
    pool_effect_check(A == B && B.loc == T && !QDELETED(B) && !B.gcDestroyed, "[path] reuse identity and live markers")
    pool_effect_check(B.name != "mutated pool effect" && B.pixel_x == initial(B.pixel_x), "[path] mutable state reset")
    pool_effect_check(!(B in pool_idle), "[path] reuse releases idle ownership")
    qdel(B)
    pool_effect_empty()
var/pool_effect_task_calls = 0
/proc/pool_effect_task_call()
    pool_effect_task_calls++
/proc/pool_effect_retire_peer(datum/scheduled_task/task)
    qdel(task)
/datum/pool_effect_task_listener/proc/retire_task(datum/scheduled_task/task)
    qdel(task)
/obj/effect/effect/smoke/pool_short
    time_to_live = 6
/obj/effect/effect/steam/pool_a
/obj/effect/effect/steam/pool_b
/obj/effect/effect/steam/pool_c
/obj/effect/effect/steam/pool_d
/obj/effect/effect/steam/pool_e
/obj/effect/effect/steam/pool_f
/obj/effect/effect/steam/pool_g
/obj/effect/effect/steam/pool_h
/obj/effect/effect/steam/pool_i
/obj/effect/effect/steam/pool_j
/world/New()
    OpenPort("none")
    GLOB.all_observable_events = list()
    GLOB.global_listen_count = list()
    GLOB.event_sources_count = list()
    GLOB.event_listen_count = list()
    GLOB.moved_event = new
    GLOB.dir_set_event = new
    GLOB.destroyed_event = new
    GLOB.stat_set_event = new
    GLOB.name_set_event = new
    GLOB.task_triggered_event = new
    processes.garbage = new /process/garbage
    processes.callproc = new /process/callproc
    processes.scheduler = new /process/scheduler
    processes.scheduler.setup()
    processes.scheduler.run_time_tick_usage = world.tick_usage
    processes.scheduler.run_time_tick_usage_allowance = 100
    var/turf/T = locate(2,2,1)
    T.window_coeff_dirty = FALSE
    var/obj/effect/sparks/timed_spark = PoolOrNew(/obj/effect/sparks, T)
    timed_spark.initialize()
    pool_effect_check(processes.scheduler.scheduled_tasks.len == 1, "spark initialize schedules source-bound expiry")
    var/datum/scheduled_task/source/spark_task = processes.scheduler.scheduled_tasks[1]
    qdel(timed_spark)
    pool_effect_check(!processes.scheduler.scheduled_tasks.len && (!spark_task || (!spark_task.source && !spark_task.arguments.len)), "spark retirement cancels scheduler and target ownership")
    var/obj/effect/sparks/current_spark = PoolOrNew(/obj/effect/sparks, T)
    current_spark.initialize()
    spark_task = processes.scheduler.scheduled_tasks[1]
    spark_task.trigger_time = world.time - 1
    processes.scheduler.reset_current_list()
    processes.scheduler.fire()
    pool_effect_check(QDELETED(current_spark) && !processes.scheduler.scheduled_tasks.len, "current scheduled spark timer still retires effect")
    pool_effect_check(!processes.scheduler.current_list.len, "scheduler source retirement consumes current snapshot")
    pool_effect_empty()
    var/datum/pool_effect_task_listener/task_listener = new
    var/datum/scheduled_task/pre_deleted = schedule_task(world.time - 1, /proc/pool_effect_task_call, list())
    GLOB.task_triggered_event.register(pre_deleted, task_listener, /datum/pool_effect_task_listener/proc/retire_task)
    processes.scheduler.reset_current_list()
    processes.scheduler.fire()
    pool_effect_check(!pre_deleted && !pool_effect_task_calls && !processes.scheduler.scheduled_tasks.len && !processes.scheduler.current_list.len, "scheduler pre_process deletion skips processing and consumes snapshot")
    qdel(task_listener)
    var/datum/scheduled_task/retire_peer = schedule_task(world.time - 1, /proc/pool_effect_retire_peer, list())
    var/datum/scheduled_task/peer = schedule_task(world.time - 1, /proc/pool_effect_task_call, list())
    retire_peer.arguments += peer
    processes.scheduler.reset_current_list()
    pool_effect_check(processes.scheduler.current_list.len == 2, "scheduler captures both tasks before peer cancellation")
    processes.scheduler.fire()
    pool_effect_check(!pool_effect_task_calls && !processes.scheduler.scheduled_tasks.len && !processes.scheduler.current_list.len, "scheduler peer cancellation cannot invoke cancelled snapshot task")

    var/obj/effect/effect/smoke/chem/old_chem = PoolOrNew(/obj/effect/effect/smoke/chem, list(T, 100))
    old_chem.alpha = 0
    qdel(old_chem)
    var/obj/effect/effect/smoke/chem/new_chem = PoolOrNew(/obj/effect/effect/smoke/chem, list(T, 100, locate(4,4,1)))
    sleep(2)
    pool_effect_check(new_chem == old_chem && pool_effect_walk_calls == 1, "chemical smoke only current lifetime starts walking")
    new_chem.alpha = 0
    qdel(new_chem)
    pool_effect_empty()
    var/obj/effect/projectile/projectile = PoolOrNew(/obj/effect/projectile, T)
    projectile.activate(0)
    qdel(projectile)
    var/obj/effect/projectile/current_projectile = PoolOrNew(/obj/effect/projectile, T)
    sleep(2)
    pool_effect_check(current_projectile == projectile && !QDELETED(current_projectile), "old projectile update cannot retire unactivated reused identity")
    qdel(current_projectile)
    pool_effect_empty()

    for(var/path in list(/obj/effect/effect/steam, /obj/effect/sparks, /obj/effect/effect/smoke, /obj/effect/projectile, /obj/effect/decal/cleanable/blood/splatter, /obj/item/stack/rods))
        pool_effect_cycle(path, T)
    var/atom/movable/lighting_overlay/L = PoolOrNew(/atom/movable/lighting_overlay, list(T, TRUE))
    lighting_overlay_list += L
    lighting_update_overlays += L
    qdel(L)
    pool_effect_check(!T.lighting_overlay && T.luminosity, "lighting cleanup releases turf backlink")
    pool_effect_check(!(L in lighting_overlay_list) && !(L in lighting_update_overlays), "lighting cleanup releases both registries")
    var/atom/movable/lighting_overlay/L2 = PoolOrNew(/atom/movable/lighting_overlay, list(T, TRUE))
    pool_effect_check(L2 == L && T.lighting_overlay == L2 && !QDELETED(L2) && !L2.gcDestroyed, "lighting constructor rebuilds turf linkage on reuse")
    qdel(L2)
    pool_effect_empty()
    var/obj/effect/decal/cleanable/blood/splatter/Blood = PoolOrNew(/obj/effect/decal/cleanable/blood/splatter, T)
    var/datum/list_witness = new
    Blood.viruses += list_witness
    qdel(Blood)
    var/obj/effect/decal/cleanable/blood/splatter/Blood2 = PoolOrNew(/obj/effect/decal/cleanable/blood/splatter, T)
    pool_effect_check(!(list_witness in Blood2.viruses), "blood reuse does not preserve mutated default lists")
    qdel(Blood2)
    pool_effect_empty()
    var/obj/effect/effect/smoke/S = PoolOrNew(/obj/effect/effect/smoke, T)
    pool_effect_check(processes.callproc.queue.len == 1, "smoke constructor registers actual expiry helper")
    qdel(S)
    pool_effect_check(!processes.callproc.queue.len && !processes.callproc.by_object.len, "smoke destruction cancels expiry target")
    var/obj/effect/effect/smoke/S2 = PoolOrNew(/obj/effect/effect/smoke, T)
    pool_effect_check(S2 == S && processes.callproc.queue.len == 1, "smoke reuse creates only current lifetime helper")
    var/callproc_helper/H = processes.callproc.queue[1]
    H.time = 0
    processes.callproc.fire()
    pool_effect_check(QDELETED(S2) && !processes.callproc.queue.len, "real smoke expiry retires reused identity")
    pool_effect_empty()
    var/process/callproc/saved_callproc = processes.callproc
    processes.callproc = null
    var/obj/effect/effect/smoke/pool_short/old_smoke = PoolOrNew(/obj/effect/effect/smoke/pool_short, T)
    sleep(1)
    qdel(old_smoke)
    var/obj/effect/effect/smoke/pool_short/new_smoke = PoolOrNew(/obj/effect/effect/smoke/pool_short, T)
    sleep(5)
    pool_effect_check(new_smoke == old_smoke && !QDELETED(new_smoke), "fallback smoke old expiry cannot retire reused identity")
    sleep(2)
    pool_effect_check(QDELETED(new_smoke), "fallback smoke current expiry still runs")
    processes.callproc = saved_callproc
    pool_effect_empty()
    var/datum/effect/effect/system/steam_spread/steam_system = new
    steam_system.set_up(1, TRUE, T)
    steam_system.start()
    sleep(1)
    var/obj/effect/effect/steam/old_steam = locate() in T
    pool_effect_check(old_steam, "real steam spread creates effect")
    qdel(old_steam)
    var/turf/destination = locate(3,3,1)
    var/obj/effect/effect/steam/new_steam = PoolOrNew(/obj/effect/effect/steam, destination)
    sleep(40)
    pool_effect_check(new_steam == old_steam && !QDELETED(new_steam) && new_steam.loc == destination, "old steam spread cannot move or retire reused effect")
    qdel(new_steam)
    qdel(steam_system)
    pool_effect_empty()
    var/datum/effect/effect/system/spark_spread/spark_system = PoolOrNew(/datum/effect/effect/system/spark_spread)
    spark_system.set_up(1, TRUE, T)
    spark_system.start()
    sleep(1)
    var/obj/effect/sparks/old_spark = locate() in T
    pool_effect_check(old_spark, "real spark spread creates effect")
    qdel(old_spark)
    qdel(spark_system)
    var/obj/effect/sparks/new_spark = PoolOrNew(/obj/effect/sparks, destination)
    var/datum/effect/effect/system/spark_spread/new_spark_system = PoolOrNew(/datum/effect/effect/system/spark_spread)
    sleep(40)
    pool_effect_check(new_spark == old_spark && !QDELETED(new_spark) && new_spark.loc == destination, "old spark spread cannot move or retire reused effect")
    pool_effect_check(new_spark_system == spark_system && new_spark_system.total_sparks == 0, "old spark spread cannot mutate reused system counters")
    qdel(new_spark)
    qdel(new_spark_system)
    pool_effect_empty()
    var/datum/effect/effect/system/smoke_spread/smoke_system = PoolOrNew(/datum/effect/effect/system/smoke_spread)
    smoke_system.smoke_type = /obj/effect/effect/smoke/pool_short
    smoke_system.set_up(1, TRUE, T, NORTH)
    smoke_system.start()
    sleep(1)
    var/obj/effect/effect/smoke/pool_short/old_spread_smoke = locate() in T
    pool_effect_check(old_spread_smoke, "real smoke spread creates effect")
    qdel(old_spread_smoke)
    qdel(smoke_system)
    var/obj/effect/effect/smoke/pool_short/new_spread_smoke = PoolOrNew(/obj/effect/effect/smoke/pool_short, destination)
    var/datum/effect/effect/system/smoke_spread/new_smoke_system = PoolOrNew(/datum/effect/effect/system/smoke_spread)
    sleep(70)
    pool_effect_check(new_spread_smoke == old_spread_smoke && !QDELETED(new_spread_smoke) && new_spread_smoke.loc == destination, "old smoke spread cannot move or retire reused effect")
    pool_effect_check(new_smoke_system == smoke_system && new_smoke_system.total_smoke == 0, "old smoke spread cannot mutate reused system counters")
    qdel(new_spread_smoke)
    qdel(new_smoke_system)
    pool_effect_empty()
    var/list/batch = list()
    // Allocate before retiring: immediate reuse cannot exercise retention caps.
    PoolOrNew(/obj/effect/effect/steam, T)
    for(var/i = 1, i <= 105, i++)
        batch += new /obj/effect/effect/steam(T)
    for(var/datum/D in batch) qdel(D)
    pool_effect_check(GlobalPool[/obj/effect/effect/steam].len == 100 && pooled_count == 100, "actual steam exact per-type cap")
    pool_effect_check(pool_idle.len == 100, "overflow does not retain idle owners")
    pool_effect_empty()
    for(var/path in list(/obj/effect/effect/steam/pool_a, /obj/effect/effect/steam/pool_b, /obj/effect/effect/steam/pool_c, /obj/effect/effect/steam/pool_d, /obj/effect/effect/steam/pool_e, /obj/effect/effect/steam/pool_f, /obj/effect/effect/steam/pool_g, /obj/effect/effect/steam/pool_h, /obj/effect/effect/steam/pool_i, /obj/effect/effect/steam/pool_j))
        PoolOrNew(path, T)
        batch = list()
        for(var/i = 1, i <= 100, i++) batch += new path(T)
        for(var/datum/D in batch) qdel(D)
    pool_effect_check(pooled_count == 1000 && pool_idle.len == 1000, "actual constructor global retention cap")
    var/obj/effect/effect/steam/overflow = PoolOrNew(/obj/effect/effect/steam, T)
    qdel(overflow)
    pool_effect_check(pooled_count == 1000 && !(overflow in pool_idle), "global overflow routed outside idle pool")
    var/datum/expired = pool_idle[1]
    pool_effect_check(pool_idle[expired] == world.time + 5 MINUTES, "idle deadline is bounded five minutes")
    for(var/datum/D in pool_idle) pool_idle[D] = 0
    ExpirePools(32)
    pool_effect_check(pooled_count == 968 && pool_idle.len == 968, "idle expiration sweep bounded to 32")
    pool_effect_check(expired && expired.gcDestroyed && QDELETED(expired) && !(expired in GlobalPool[expired.type]), "idle expiry preserves retirement markers and transfers ownership")
    pool_effect_empty()
    pool_effect_check(!pooled_count && !pool_idle.len, "all idle pool owners released")
    if(!pool_effect_failures)
        world.log << "PASS pool effects [pool_effect_checks] checks"
    shutdown()
