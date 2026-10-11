#define MAP_NOMADS_CONTINENTAL "continental"
#define MAP_NOMADS_PANGEA "pangea"
#define MAP_NOMADS_NEW_WORLD "new_world"
#define MAP_NOMADS_MEDITERRANEAN "mediterranean"
#define MAP_NOMADS_EUROPE "europe"
#define MAP_NOMADS_GAIA "gaia"
var/global/growth_calls = 0
var/global/season = "SUMMER"
var/global/datum/map_fixture/map = new
/datum/map_fixture
    var/ID = "continental"
    var/heat_wave = FALSE
/area
    var/location = 1
    var/climate = "temperate"
/turf/floor
    var/irrigation = FALSE
    var/flooded = FALSE
    var/salty = FALSE
/turf/floor/dirt
    var/soil_nutrition = 150
    var/min_soil_nutrition = 0
/turf/floor/dirt/ploughed
/turf/floor/beach/water
/turf/floor/trench/flooded
/obj/structure/farming/plant
    var/stage = 1
    var/readyStageMin = 7
    var/readyStageMax = 10
    var/vstatic = FALSE
    var/sprite_plant
    var/plant = "tomato"
    var/list/biomes = list("temperate")
    var/list/seasons = list("SUMMER")
    var/water = 60
    var/max_water = 60
    var/plant_nutrition = 100
/obj/structure/farming/plant/mushroom
/obj/structure/farming/plant/mushroompsy
/proc/check(condition, message)
    if (!condition)
        world.log << "FAIL [message]"
        del(world)
/world
    maxx = 8
    maxy = 1
    fps = 20
    turf = /turf/floor/dirt/ploughed
/world/New()
    var/turf/floor/dirt/D = locate(1,1,1)
    var/obj/structure/farming/plant/P = new(D)
    P.water = 0
    P.growth()
    check(P.stage == 11, "drought death")
#ifndef BASELINE
    check(P.desc == "A dry tomato plant.", "specific death description")
#endif
    var/soil_after_death = D.soil_nutrition
    var/before = growth_calls
    sleep(12)
    world.log << "DEAD recurring_entries=[growth_calls-before] soil_debit=[soil_after_death-D.soil_nutrition]"
#ifdef BASELINE
    check(growth_calls > before, "baseline dead callbacks reproduced")
#else
    check(growth_calls == before, "dead plant rescheduled")
    check(D.soil_nutrition == soil_after_death, "dead plant consumes soil")
#endif
    del(P)
    P = new(locate(2,1,1))
    P.vstatic = TRUE
    P.growth()
#ifndef BASELINE
    check(P.water == 60, "static water consumed")
#endif
    del(P)
    P = new(locate(3,1,1))
    // Fresh nearby water keeps the living cadence deterministic.
    new /turf/floor/beach/water(locate(4,1,1))
    P.growth()
    sleep(3)
    check(P.stage == 2, "living one-wait cadence changed")
    P.set_dead("frozen")
    before = growth_calls
    sleep(5)
#ifndef BASELINE
    check(growth_calls == before, "pending wait revived terminal crop")
    check(P.desc == "A frozen tomato plant.", "pending wait overwrote death")
#endif
    del(P)
    P = new(locate(5,1,1))
    P.stage = 10
    P.growth()
    sleep(3)
    check(P.stage == 11, "overripe transition changed")
    del(P)
    P = new(locate(6,1,1))
    P.growth()
    del(P)
    sleep(5)
    P = new(locate(7,1,1))
    P.growth()
    P.vstatic = TRUE
    before = growth_calls
    sleep(3)
#ifndef BASELINE
    check(growth_calls == before, "pending static crop rescheduled")
#endif
    del(P)
    var/turf/floor/dirt/replaced = locate(8,1,1)
    P = new(replaced)
    P.growth()
    new /turf/floor(replaced)
    sleep(3)
    before = growth_calls
    sleep(5)
    check(growth_calls == before, "nonploughed replacement keeps scheduling")
    del(P)
    world.log << "PASS plant lifecycle"
    del(world)
/proc/get_turf(atom/A)
    while (A && !isturf(A))
        A = A.loc
    return A
/proc/get_area(atom/A)
    while (A && !isarea(A))
        A = A.loc
    return A
