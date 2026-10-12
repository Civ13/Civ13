#define SECOND * 10
#define FALSE 0
#define TRUE 1
#define DEAD 2
#define PROCESS_KILL 26
var/list/processing_objects = list()
var/list/probabilities = list()
/proc/test_probability(percent)
    probabilities += percent
    return 0
/proc/isDeleted(obj/O)
    return O.retired
/process
    var/schedule_interval = 20
    var/current
    var/list/current_list
    var/priority = PROCESS_PRIORITY_MEDIUM
    var/run_time_tick_usage = 0
    var/run_time_tick_usage_allowance = 100
    var/errors = 0
    proc/catchException(exception/e, obj/O)
        errors++
    proc/catchBadType(obj/O)
        errors++
/obj
    var/retired = 0
    proc/visible_message(message)
        return
/obj/proc/process(actor, tank)
    return 77
/obj/legacy/process(actor, tank)
    check(isnull(actor) && isnull(tank), "legacy received time as actor")
    return 77
/obj/kill/process()
    return PROCESS_KILL
/obj/throws/process()
    throw new/exception("controlled test failure")
/obj/item
    var/lit = 1
    var/wax = 10
    var/smoketime = 5
    var/fuel = 10
    var/on = 1
    var/expired = 0
    proc/update_icon()
        return
    proc/dropped()
        return
    proc/burn_out()
        expired++
        on = 0
        lit = 0
/obj/item/trash/candle/lard
/mob/living/proc/IgniteMob()
    return
/mob/living
    var/stat = 0
    var/lying = 0
    var/oxygen_loss = 0
    proc/forceMove(atom/destination)
        loc = destination
    proc/adjustOxyLoss(amount)
        oxygen_loss += amount
    proc/death()
        stat = DEAD
/obj/structure/noose
    var/mob/living/hanging
/obj/structure/gallows
    var/mob/living/hanging
    var/roped = 1
/proc/playsound(atom/A, sound/S)
    return
/proc/to_chat(mob/M, message)
    return
/proc/isliving(atom/A)
    return istype(A, /mob/living)
/proc/qdel(atom/A)
    A:expired++
/proc/check(condition, message)
    if (!condition)
        world.log << "FAIL [message]"
        del(world)
/world
    sleep_offline = 1
/world/New()
    world.OpenPort(0)
    var/process/P = new
    check(P.configured_interval_seconds() == 2, "deciseconds conversion")
    P.schedule_interval = 5
    check(P.configured_interval_seconds() == 0.5, "fractional interval")
    var/obj/legacy/L = new
    check(L.process_interval(12) == 77, "legacy return propagation")
    for (var/path in list(/obj/item/weapon/flame/candle, /obj/item/weapon/flame/candle/lard))
        var/obj/item/C = new path
        C.process()
        check(C.wax == 9, "direct candle balance")
        C.process_interval(1)
        check(C.wax == 8.5, "fractional candle consumption")
        C.lit = 0
        C.process_interval(4)
        check(C.wax == 8.5, "unlit candle consumption")
        C.lit = 1
        C.wax = 0.25
        C.process_interval(1)
        check(C.expired == 1 && C.wax == 0, "fractional candle expiry")
    var/obj/item/weapon/flame/match/M = new
    M.process()
    check(M.smoketime == 4, "direct match balance")
    M.process_interval(1)
    check(M.smoketime == 3.5 && !M.expired, "fractional match lifetime")
    M.process_interval(7)
    check(M.expired == 1, "match expiry")
    var/obj/item/flashlight/flare/F = new
    F.process()
    check(F.fuel == 9, "direct flare balance")
    F.process_interval(1)
    check(F.fuel == 8.5, "fractional flare lifetime")
    // Configured seconds are supplied explicitly, independent of wall time.
    F.process_interval(2)
    check(F.fuel == 7.5, "explicit configured cadence")
    F.process_interval(20)
    check(F.fuel == 0 && F.expired == 1, "flare clamped expiry")
    check(object_interval_probability(5, 2) == 5, "legacy probability balance")
    check(object_interval_probability(5, 0) == 0, "zero interval probability")
    check(object_interval_probability(0, 2) == 0 && object_interval_probability(100, 1) == 100, "probability endpoints")
    var/half = object_interval_probability(5, 1) / 100
    check(abs((1 - half) ** 2 - 0.95) < 0.00001, "probability survival composition")
    for (var/path in list(/obj/structure/noose, /obj/structure/gallows))
        var/obj/N = new path
        var/mob/living/H = new
        N:hanging = H
        N.process()
        check(H.oxygen_loss == 5, "direct damage balance")
        N:fire()
        check(H.oxygen_loss == 10, "direct fire default balance")
        probabilities.Cut()
        N.process_interval(1)
        check(H.oxygen_loss == 12.5, "fractional damage rate")
        check(probabilities.Find(object_interval_probability(5, 1)), "production probability argument")
        H.stat = DEAD
        N.process_interval(4)
        check(H.oxygen_loss == 12.5, "dead target damage guard")
    var/process/obj/loop = new
    loop.schedule_interval = 10
    var/obj/item/flashlight/flare/S = new
    var/obj/kill/K = new
    var/obj/throws/E = new
    var/obj/retired/R = new
    R.retired = 1
    processing_objects = list(L, K, E, R, S)
    loop.current_list = processing_objects.Copy()
    loop.fire()
    check(S.fuel == 9.5, "production loop seconds dispatch")
    check(!(K in processing_objects) && !(R in processing_objects), "loop kill/deleted removal")
    check(loop.errors == 2 && !loop.current_list.len, "loop exception and snapshot semantics")
    var/obj/item/flashlight/flare/A = new
    var/obj/item/flashlight/flare/B = new
    processing_objects = list(A, B)
    loop.current_list = processing_objects.Copy()
    loop.run_time_tick_usage_allowance = -1
    check(loop.fire() == PROCESS_TICK_CHECK_RETURNED_EARLY, "loop budget yield result")
    check(loop.current_list.len == 1 && A.fuel == 9.5 && B.fuel == 10, "yield retains only unfinished snapshot")
    loop.run_time_tick_usage_allowance = 100
    loop.fire()
    check(A.fuel == 9.5 && B.fuel == 9.5 && !loop.current_list.len, "resume does not replay configured time")
    world.log << "PASS process time"
    del(world)
