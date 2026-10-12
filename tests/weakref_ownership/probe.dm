var/failures = 0
#define REF(X) "\ref[X]"
#define QDELETED(X) (!X || X.gc_destroyed)
#define QDEL_HINT_LETMELIVE 1
#define QDEL_HINT_QUEUE 2
/datum
    var/gc_destroyed = FALSE
    var/datum/weakref/weak_reference
/datum/proc/Destroy(force = FALSE)
    weak_reference = null
    return QDEL_HINT_QUEUE
var/qdel_calls = 0
/proc/qdel(datum/D)
    if(D)
        qdel_calls++
        D.gc_destroyed = TRUE
/proc/check(condition, message)
    if(!condition)
        failures++
        world.log << "FAIL [message]"
        return
/world/New()
    world.OpenPort("none")
    var/datum/target = new
    var/datum/weakref/handle = WEAKREF(target)
    check(handle.resolve() == target, "initial target resolution")
    check(WEAKREF(target) == handle, "cached handle identity")
    check(handle.Destroy(FALSE) == QDEL_HINT_LETMELIVE, "nonforced deletion veto")
    check(!qdel_calls && !target.gc_destroyed, "nonforced disposal preserves target")
    if(failures)
        shutdown()
        return
    check(handle.resolve() == target, "veto preserves linkage")
    check(handle.Destroy(TRUE) == QDEL_HINT_QUEUE, "forced deletion forwards parent")
    check(!qdel_calls && !target.gc_destroyed, "forced disposal preserves target")
    check(!target.weak_reference && !handle.resolve() && !handle.reference, "forced disposal detaches handle")
    var/datum/weakref/replacement = WEAKREF(target)
    check(replacement != handle && replacement.resolve() == target, "fresh handle after disposal")
    target.gc_destroyed = TRUE
    check(!replacement.resolve() && !WEAKREF(target), "queued target cannot resolve")
    target.gc_destroyed = FALSE
    target.Destroy()
    check(!replacement.resolve(), "destroyed target linkage invalidated")
    del(target)
    check(!replacement.resolve(), "native deleted target cannot resolve")
    del(handle)
    del(replacement)
    if(!failures)
        world.log << "PASS weakref ownership"
    shutdown()

/world/OpenPort(port)
    if(port == "none")
        return ..()
    return FALSE
