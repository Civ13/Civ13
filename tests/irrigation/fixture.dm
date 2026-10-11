var/global/list/cardinal = list(NORTH,SOUTH,EAST,WEST)
var/global/icon_updates = 0
/turf/floor
    var/irrigation = FALSE
    var/flooded = FALSE
    var/salty = FALSE
    var/image/irrigation_overlay
/turf/proc/check_relatives(var/update_self = FALSE, var/update_others = FALSE)
    return
/turf/floor/proc/update_icon()
    icon_updates++
/turf/floor/beach/water
/turf/floor/trench/flooded
/proc/check(condition, message)
    if (!condition)
        world.log << "FAIL [message]"
        del(world)
/proc/reset_floor()
    for (var/x in 1 to 30)
        for (var/y in 1 to 3)
            new /turf/floor(locate(x,y,1))
/world
    maxx = 30
    maxy = 3
    turf = /turf/floor
/world/New()
    var/list/channel_states = icon_states('icons/turf/trench.dmi')
    for (var/junction in 0 to 15)
        check("irrigation[junction]" in channel_states, "missing dry channel sprite [junction]")
        check("irrigation[junction]_flooded" in channel_states, "missing flooded channel sprite [junction]")
    var/turf/floor/C = locate(3,2,1)
    var/turf/floor/F = locate(3,1,1)
    C.irrigation = TRUE
    C.flooded = TRUE
    C.check_relatives(1,0)
#ifdef BASELINE
    check(F.flooded, "baseline ordinary-floor flood mutation")
#else
    check(!F.flooded && !F.salty, "ordinary floor became water source")
#endif
    new /turf/floor(C)
    var/turf/floor/replacement = locate(4,1,1)
    replacement.irrigate("empty")
#ifdef BASELINE
    check(replacement.flooded, "baseline ghost source after channel removal")
#else
    check(!replacement.flooded, "removed channel left ghost source on floor")
#endif
    for (var/x in 1 to 30)
        for (var/y in 1 to 3)
            new /turf/floor(locate(x,y,1))
    for (var/x in 2 to 25)
        var/turf/floor/T = locate(x,2,1)
        T.irrigation = TRUE
        T.flooded = TRUE
    C = locate(2,2,1)
    C.salty = TRUE
    C.expand_flood()
    var/turf/floor/far = locate(25,2,1)
#ifdef BASELINE
    check(!far.salty, "baseline stops salt at already-flooded channel")
#else
    check(far.salty, "salt failed to reach already-flooded downstream channel")
#endif
    var/layer_before = C.layer
    C.check_relatives(1,0)
#ifdef BASELINE
    check(C.layer > layer_before, "baseline layer drift")
#else
    check(C.layer == layer_before, "overlay updates change turf layer")
#endif
#ifndef BASELINE
    // Closed channels can retain old flags, but cannot refill their neighbors.
    reset_floor()
    F = locate(3,2,1)
    F.flooded = TRUE
    F.salty = TRUE
    C = locate(4,2,1)
    C.irrigate("empty")
    check(!C.flooded && !C.salty, "filled-in channel treated as source")
    // A dry loop fills from fresh water, with disconnected channels untouched.
    reset_floor()
    for (var/x in 2 to 25)
        for (var/y in 1 to 3)
            var/turf/floor/T = locate(x,y,1)
            T.irrigation = TRUE
    var/turf/floor/beach/water/source = new(locate(1,2,1))
    C = locate(2,2,1)
    var/turf/floor/isolated = locate(30,2,1)
    isolated.irrigation = TRUE
    C.check_relatives(1,1)
    for (var/x in 2 to 25)
        for (var/y in 1 to 3)
            var/turf/floor/T = locate(x,y,1)
            check(T.flooded && !T.salty, "fresh loop failed to fill")
    check(!isolated.flooded && !isolated.salty, "disconnected channel changed")
    // Salt touching the far end reaches the whole already-wet component.
    var/turf/floor/beach/water/salt_source = new(locate(26,2,1))
    salt_source.salty = TRUE
    C.check_relatives(1,0)
    check(C.salty, "remote salt source missed")
    check(!isolated.salty, "salt crossed disconnected floors")
    // Removing natural sources leaves stored channel water, not automatic drainage.
    new /turf/floor(source)
    new /turf/floor(salt_source)
    C.check_relatives(1,0)
    check(C.flooded && C.salty, "existing stored water unexpectedly drained")
    layer_before = C.layer
    var/updates_before = icon_updates
    for (var/cycle in 1 to 100)
        C.check_relatives(1,1)
    check(C.layer == layer_before, "repeated refresh layer drift")
    check(icon_updates - updates_before < 8000, "loop refresh exceeded bounded work")
    // Flooded trenches remain valid fresh sources.
    reset_floor()
    var/turf/floor/trench/flooded/trench = new(locate(3,2,1))
    trench.flooded = TRUE
    C = locate(4,2,1)
    C.irrigate("empty")
    check(C.flooded && !C.salty, "flooded trench failed to fill channel")
#endif
    world.log << "PASS irrigation"
    del(world)

