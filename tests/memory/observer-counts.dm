// Standalone: includes production event registration and cleanup code, no game startup.

#define GLOBAL_LIST_EMPTY(NAME) /datum/test_globals/var/list/##NAME = list()
#define CRASH(message) throw message
var/global/datum/test_globals/GLOB = new
var/global/failures = 0
/datum/test_globals
    var/list/all_observable_events = list()
/decl
/proc/log_debug(message)
    return
/proc/error(message)
    world.log << message
#include "../../code/datums/observation/observation.dm"
#include "../../code/datums/observation/~cleanup.dm"
/datum/test_listener/proc/first(source)
    return
/datum/test_listener/proc/second(source)
    return
/proc/check(condition, message)
    if (!condition)
        failures++
        world.log << "FAIL [message]"
/world/New()
    var/decl/observ/event = new
    var/decl/observ/other_event = new
    for (var/cycle = 1 to 100)
        var/datum/source = new
        var/datum/test_listener/listener = new
        var/datum/test_listener/other_listener = new
        event.register(source, listener, /datum/test_listener/proc/first)
        event.register(source, listener, /datum/test_listener/proc/second)
        event.unregister(source, listener)
        check(!event.event_sources.len, "source callbacks removed")
        check(!GLOB.event_sources_count.len && !GLOB.event_listen_count.len, "bulk unregister retained source/listener keys")
        cleanup_events(source)
        cleanup_events(listener)
        event.register_global(listener, /datum/test_listener/proc/first)
        check(!event.register_global(listener, /datum/test_listener/proc/first), "duplicate global registration must return false")
        check(GLOB.global_listen_count[listener] == 1, "duplicate global registration inflated count")
        event.unregister_global(listener, /datum/test_listener/proc/first)
        check(!GLOB.global_listen_count.len, "single global unregister retained key")
        cleanup_events(listener)
        event.register_global(listener, /datum/test_listener/proc/first)
        event.register_global(listener, /datum/test_listener/proc/second)
        event.unregister_global(listener)
        check(!GLOB.global_listen_count.len, "bulk global unregister retained key")
        cleanup_events(listener)
        event.register(source, listener, /datum/test_listener/proc/first)
        event.register(source, listener, /datum/test_listener/proc/second)
        event.register(source, other_listener, /datum/test_listener/proc/first)
        other_event.register(source, listener, /datum/test_listener/proc/first)
        cleanup_events(source)
        check(!event.event_sources.len && !other_event.event_sources.len, "source cleanup skipped callbacks")
        check(!GLOB.event_listen_count.len && !GLOB.event_sources_count.len, "source cleanup retained count keys")
        cleanup_events(listener)
        cleanup_events(other_listener)
        del(source)
        del(listener)
        del(other_listener)
    if (failures)
        world.log << "FAILED observer bookkeeping: [failures] assertions"
    else
        world.log << "PASS observer bookkeeping: 100 cycles, duplicate and bulk unregister, source cleanup"
    del(world)
    return
