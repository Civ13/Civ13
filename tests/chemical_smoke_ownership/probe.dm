// Production constructors, emission, particles, qdel and reagent cleanup.
/world
    hub = ""
    hub_password = ""
    maxx = 9
    maxy = 9
    maxz = 1
    turf = /turf
    area = /area/smoke_ownership_probe
/area/smoke_ownership_probe
    dynamic_lighting = FALSE
/obj/map_metadata/smoke_ownership_probe/New()
    return
/world/OpenPort(port)
    if(port == "none") return ..()
    return FALSE
var/smoke_ownership_failures = 0
var/smoke_ownership_emissions = 0
var/list/smoke_ownership_particles = list()
/world/Error(exception/E)
    smoke_ownership_failures++
    world.log << "RUNTIME [E.name]"
/proc/smoke_check(condition, message)
    if(!condition)
        smoke_ownership_failures++
        world.log << "FAIL [message]"
/proc/smoke_fixture_observe(obj/effect/effect/smoke/chem/smoke, duration, dist)
    smoke_ownership_emissions++
    smoke_ownership_particles += smoke
    smoke_check(smoke.reagents && smoke.reagents.get_reagent_amount("water") == 40 / dist, "emissions preserve reagent yield")
    smoke_check(smoke.time_to_live >= duration && smoke.time_to_live <= duration + 20, "emissions preserve particle lifetime")
/proc/smoke_fixture_empty()
    for(var/obj/effect/effect/smoke/chem/S in smoke_ownership_particles)
        qdel(S)
    smoke_ownership_particles.Cut()
    for(var/datum/D in pool_idle)
        pool_idle[D] = 0
    while(pool_idle.len)
        ExpirePools(32)
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
    processes.chemistry = new /process/chemistry
    initialize_chemical_reagents()
    initialize_chemical_reactions()
    processes.chemistry.setup()
    config = new
    config.tts_on = FALSE
    config.webhook_can_fire = FALSE
    map = new /obj/map_metadata/smoke_ownership_probe
    var/turf/T = locate(5,5,1)
    var/obj/feed = new(T)
    feed.create_reagents(100)
    feed.reagents.add_reagent("water", 40, safety = TRUE)
    sleep(1) // Begin after an ordinary tick, before testing queued callbacks.
    var/released = TRUE
    for(var/i = 1 to 32)
        var/datum/effect/effect/system/smoke_spread/chem/S = new
        S.show_log = FALSE
        S.set_up(feed.reagents, 3, FALSE, T)
        var/obj/H = S.chemholder
        var/datum/reagents/R = H.reagents
        processes.chemistry.active_holders |= R
        S.start()
        smoke_check(S.chemholder == H && R.my_atom == H, "queued emission keeps holder alive")
        sleep(1)
        released = released && !S.chemholder && !R.my_atom && !(R in processes.chemistry.active_holders)
        // Test-owned handles allow lifecycle inspection; then remove all owners.
        if(S.chemholder) qdel(H)
        qdel(S)
        H = null
        R = null
        S = null
        smoke_fixture_empty()
    smoke_check(released, "automatic systems release hidden holders")
    smoke_check(smoke_ownership_emissions == 32, "one center emission per transient system")
    smoke_check(feed.reagents.get_reagent_amount("water") == 40, "source mixture remains unchanged")
    // Historical control intentionally selects only this discriminating workload.
    if(world.params["historical"] != "1")
        var/datum/effect/effect/system/smoke_spread/chem/canceled = new
        canceled.show_log = FALSE
        canceled.set_up(feed.reagents, 3, FALSE, T)
        var/obj/old_holder = canceled.chemholder
        var/datum/reagents/old_reagents = old_holder.reagents
        canceled.start()
        var/before = smoke_ownership_emissions
        qdel(canceled)
        qdel(canceled)
        sleep(1)
        smoke_check(smoke_ownership_emissions == before && !canceled.chemholder && !old_reagents.my_atom, "cancellation is idempotent and cancels pending emission")
        var/datum/effect/effect/system/smoke_spread/chem/empty = new
        old_reagents = empty.chemholder.reagents
        empty.start()
        smoke_check(!empty.chemholder && !old_reagents.my_atom, "no-location start releases hidden holder")
        var/datum/effect/effect/system/smoke_spread/chem/multiple = new
        multiple.show_log = FALSE
        multiple.set_up(feed.reagents, 10, FALSE, T)
        before = smoke_ownership_emissions
        multiple.start()
        smoke_check(multiple.chemholder, "multiple emissions keep shared source until callbacks")
        sleep(1)
        smoke_check(smoke_ownership_emissions > before + 1 && !multiple.chemholder, "last callback retires multiple-emission source")
        smoke_fixture_empty()
    qdel(feed)
    world.log << "DONE chemical smoke ownership"
    if(!smoke_ownership_failures) world.log << "PASS chemical smoke ownership"
    del(world)
