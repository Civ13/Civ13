// Test-only extension for a LOCAL validation build; no production include.
/decl/observ/memory_gameplay_probe
    name = "Local memory validation"
/datum/memory_gameplay_listener
    var/hits = 0
/datum/memory_gameplay_listener/proc/first(source)
    hits++
/datum/memory_gameplay_listener/proc/second(source)
    hits++
/client/proc/verify_observer_cleanup_gameplay()
    set name = "LOCAL Verify Observer Cleanup"
    set category = "Debug"
    if (!holder || (address && address != "127.0.0.1" && address != "::1"))
        return
    var/decl/observ/memory_gameplay_probe/event = new
    var/failures = 0
    for (var/cycle = 1 to 100)
        var/datum/source = new
        var/datum/memory_gameplay_listener/listener = new
        event.register(source, listener, /datum/memory_gameplay_listener/proc/first)
        event.register(source, listener, /datum/memory_gameplay_listener/proc/second)
        event.raise_event(source)
        if (listener.hits != 2)
            failures++
        event.unregister(source, listener)
        if (GLOB.event_sources_count[source] || GLOB.event_listen_count[listener])
            failures++
        event.register_global(listener, /datum/memory_gameplay_listener/proc/first)
        event.register_global(listener, /datum/memory_gameplay_listener/proc/first)
        if (GLOB.global_listen_count[listener] != 1)
            failures++
        event.unregister_global(listener)
        if (GLOB.global_listen_count[listener])
            failures++
        cleanup_events(source)
        cleanup_events(listener)
        qdel(source)
        qdel(listener)
    GLOB.all_observable_events -= event
    qdel(event)
    if (failures)
        to_chat(src, "FAIL local observer cleanup: [failures] assertions")
    else
        to_chat(src, "<b>PASS local observer cleanup: 100 cycles; callbacks delivered and no probe references retained.</b>")
