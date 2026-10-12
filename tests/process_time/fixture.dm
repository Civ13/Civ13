#define SECOND * 10
#define FALSE 0
/process
    var/schedule_interval = 20
/obj/proc/process(actor, tank)
    return 77
/obj/legacy/process(actor, tank)
    check(isnull(actor) && isnull(tank), "legacy received time as actor")
    return 77
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
    check(F.fuel == 7.5, "lag must not add elapsed time")
    F.process_interval(20)
    check(F.fuel == 0 && F.expired == 1, "flare clamped expiry")
    world.log << "PASS process time"
    del(world)
