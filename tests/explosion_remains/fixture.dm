// Offline world for explosion_remains.dm. Production procedures are appended
// by run.py; this file only supplies the types and adapters they call.
var/global/list/assertion_failures = list()
var/global/building_allocating_z = 0
/world
    fps = 10
    maxx = 16
    maxy = 16
    maxz = 4
    turf = /turf/floor/dirt
    area = /area/caribbean
/area
    var/base_turf = null
/area/caribbean
    base_turf = /turf/floor/dirt
/area/caribbean/void/caves
/atom/proc/ex_act(severity)
    return
/turf/floor
/turf/floor/dirt
/turf/floor/dirt/burned
/turf/floor/dirt/underground
/turf/floor/plating
/turf/floor/plating/steel
/turf/floor/beach
/turf/floor/broken_floor
/turf/floor/broken_floor/sky
/turf/floor/ex_act(severity)
    // Stands in for production make_grass(), which ends in become_destroyed_turf().
    become_destroyed_turf()
/turf/sky
/turf/sky/building
/turf/wall
/turf/wall/rockwall
/turf/proc/ChangeTurf(path)
    var/turf/T = new path(src)
    return T
/proc/orbit_world()
    return FALSE
/proc/multiz_level_below(z)
    return z > 1 ? z - 1 : 0
/proc/building_base_maxz()
    return 3
/proc/check(condition, message)
    if (!condition)
        assertion_failures += message
        world.log << "FAIL [message]"
/proc/fill(path, z, x1 = 1, y1 = 1, x2 = 16, y2 = 16)
    for (var/turf/T in block(locate(x1, y1, z), locate(x2, y2, z)))
        new path(T)
/world/OpenPort(port)
    if (port == "none")
        return ..()
    return FALSE
// z1 ground (cave earth for x > 12), z2 surface with one hole and a cave
// pocket for x > 12, z3 a storey that is half sky, z4 an added building level.
/world/New()
    world.OpenPort("none")
    fill(/turf/floor/dirt/underground, 1, 13, 1, 16, 16)
    new /turf/floor/plating/steel(locate(3, 3, 1))
    new /turf/floor/broken_floor(locate(8, 8, 2))
    var/area/caves = new /area/caribbean/void/caves
    for (var/turf/T in block(locate(13, 1, 2), locate(16, 16, 2)))
        caves.contents += T
    fill(/turf/floor/broken_floor/sky, 3, 1, 1, 8, 16)
    fill(/turf/floor/plating/steel, 3, 9, 1, 16, 16)
    fill(/turf/sky/building, 4)
    new /turf/floor/plating/steel(locate(10, 10, 4))

    check(!multiz_level_is_above_ground(1), "lowest level is ground")
    check(!multiz_level_is_above_ground(2), "surface with one hole is ground")
    check(multiz_level_is_above_ground(3), "half-sky storey is above ground")
    check(multiz_level_is_above_ground(4), "added building level is above ground")

    var/turf/T = locate(5, 5, 3)
    T.ex_act(1)
    check(istype(locate(5, 5, 3), /turf/floor/broken_floor/sky), "sky survives a blast")
    check(!T.scorch_ground(), "sky is never scorched")
    T = locate(10, 10, 3)
    T.ex_act(1)
    T = locate(10, 10, 3)
    check(T.type == /turf/floor/plating, "upper floor leaves plating, not dirt")
    check(!T.become_destroyed_turf(), "upper plating stays plating")
    check(!T.scorch_ground() && T.type == /turf/floor/plating, "upper floor is never scorched to dirt")
    T = locate(10, 10, 4)
    T.ex_act(1)
    check(locate(10, 10, 4):type == /turf/floor/plating, "building-level floor leaves plating")
    T = locate(5, 5, 4)
    check(!T.scorch_ground() && istype(locate(5, 5, 4), /turf/sky/building), "building sky is never scorched")
    T = locate(14, 14, 3)
    check(!turf_is_above_ground(T), "floor over a cave pocket counts as ground")
    T.ex_act(1)
    check(locate(14, 14, 3):type == /turf/floor/dirt, "floor over a cave pocket leaves earth")
    T = locate(3, 3, 1)
    T.ex_act(1)
    check(locate(3, 3, 1):type == /turf/floor/dirt, "ground floor leaves the area base turf")
    T = locate(4, 4, 2)
    check(T.scorch_ground() && locate(4, 4, 2):type == /turf/floor/dirt/burned, "surface is still scorched")
    var/turf/wall/W = new(locate(12, 2, 3))
    W.become_destroyed_turf()
    check(locate(12, 2, 3):type == /turf/floor/plating, "upper wall leaves plating")

    if (!assertion_failures.len)
        world.log << "PASS explosion remains"
    world.log << "DONE explosion remains"
    del(world)
