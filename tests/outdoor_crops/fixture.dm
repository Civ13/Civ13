#define ITEM_SIZE_TINY 1
var/global/selected_biome
var/global/datum/map_fixture/map = new
/datum/map_fixture
    var/ID = MAP_NOMADS_EUROPE
    var/heat_wave = FALSE
/area
    var/climate = "temperate"
/area/caribbean
/obj/item
    var/w_class
    var/value
/obj/item/stack
    var/amount
    var/max_amount
    var/singular_name
/obj/structure/wild
/turf/floor
    var/irrigation = FALSE
    var/flooded = FALSE
    var/salty = FALSE
/turf/floor/beach/water
/turf/floor/trench/flooded
/obj/structure/farming/plant
    var/winter_hardy = FALSE
    var/stage = 1
    var/plant = "tomato"
    var/sprite_plant
    var/water = 60
    var/max_water = 60
/obj/structure/farming/plant/mushroom
/obj/structure/farming/plant/mushroompsy
/proc/qdel(datum/D)
    del(D)
/proc/get_turf(atom/A)
    while (A && !isturf(A))
        A = A.loc
    return A
/proc/get_area(atom/A)
    while (A && !isarea(A))
        A = A.loc
    return A
/proc/check(condition, message)
    if (!condition)
        world.log << "FAIL [message]"
        del(world)
/world
    maxx = 8
    maxy = 1
    turf = /turf/floor
    area = /area/caribbean
/world/New()
    var/obj/structure/wild/B = new(locate(4,1,1))
    var/list/biomes = list("sea", "temperate", "tundra", "taiga", "desert", "semiarid", "savanna", "jungle")
    for (var/biome in biomes)
        B.generate_seed_list(biome)
    var/list/catalogs = list(seed_list_sea, seed_list_temperate, seed_list_tundra, seed_list_taiga, seed_list_desert, seed_list_semiarid, seed_list_savanna, seed_list_jungle)
    for (var/index in 1 to biomes.len)
        var/list/catalog = catalogs[index]
        check(catalog.len > 0, "empty biome catalog [biomes[index]]")
        for (var/path in catalog)
            var/obj/item/stack/farming/seeds/S = new path
            check(biomes[index] in S.biomes, "incompatible seed [path] in [biomes[index]]")
            check(path != /obj/item/stack/farming/seeds/herbs, "herbs pseudo-seed leaked into forage")
            del(S)
        world.log << "CATALOG [biomes[index]] types=[catalog.len]"
    var/area/caribbean/A = get_area(B)
    for (var/id in list(MAP_NOMADS_PANGEA, MAP_NOMADS_CONTINENTAL, MAP_NOMADS_NEW_WORLD, MAP_NOMADS_MEDITERRANEAN, MAP_NOMADS_GAIA, MAP_NOMADS_EUROPE))
        map.ID = id
        for (var/biome in biomes)
            A.climate = biome
            var/path = B.pickseed()
            check(path, "seed selection returned no type")
#ifdef BASELINE
            if (id == MAP_NOMADS_EUROPE)
                check(selected_biome == "", "baseline Europe unfiltered dispatch")
            else
                check(selected_biome == biome, "existing nomad dispatch changed")
#else
            check(selected_biome == biome, "nomad seed dispatch [id] [biome]")
            var/obj/item/stack/farming/seeds/S = new path
            check(biome in S.biomes, "nomad bootstrap mismatch")
            del(S)
#endif
    map.ID = "fixed_era_fixture"
    B.pickseed()
    check(selected_biome == "", "fixed-era generic seed access changed")
    del(B)
    A.climate = "temperate"
    var/obj/structure/farming/plant/P = new(locate(4,1,1))
    A.icon_state = "rain"
    P.water_proc()
#ifdef BASELINE
    check(P.water == 75, "baseline rain overflow")
#else
    check(P.water == 60, "rain exceeds capacity")
    P.water = 40
    P.water_proc()
    check(P.water == 55, "rain recharge changed")
    P.water_proc()
    check(P.water == 60, "rain recharge not bounded")
#endif
    A.icon_state = ""
    P.water = 60
    P.water_proc()
    check(P.water == 45, "temperate dry cost")
    A.climate = "desert"
    P.water = 60
    P.water_proc()
    check(P.water == 35, "arid dry cost")
    map.heat_wave = TRUE
    P.water = 60
    P.water_proc()
    check(P.water == 25, "heat-wave cost")
    map.heat_wave = FALSE
    A.climate = "temperate"
    var/turf/floor/beach/water/W = new(locate(7,1,1))
    P.water = 60
    P.water_proc()
    check(P.water == 45, "water beyond two tiles irrigates")
    new /turf/floor(W)
    W = new(locate(6,1,1))
    W.salty = TRUE
    P.water = 60
    P.water_proc()
    check(P.water == 45, "saltwater irrigates")
    W.salty = FALSE
    P.water = 1
    P.water_proc()
    check(P.water == 60, "fresh water within two tiles")
    var/turf/floor/IR = new /turf/floor(W)
    IR.irrigation = TRUE
    P.water = 60
    P.water_proc()
    check(P.water == 45, "empty channel irrigates")
    IR.flooded = TRUE
    IR.salty = TRUE
    P.water = 60
    P.water_proc()
    check(P.water == 45, "saltwater channel irrigates")
    IR.salty = FALSE
    P.water = 1
    P.water_proc()
    check(P.water == 60, "fresh channel irrigates")
    var/turf/floor/trench/flooded/TR = new(IR)
    TR.flooded = FALSE
    P.water = 60
    P.water_proc()
    check(P.water == 45, "unfilled trench irrigates")
    TR.flooded = TRUE
    TR.salty = TRUE
    P.water = 60
    P.water_proc()
    check(P.water == 45, "saltwater trench irrigates")
    TR.salty = FALSE
    P.water = 1
    P.water_proc()
    check(P.water == 60, "fresh flooded trench irrigates")
    A.icon_state = "snow_storm"
    P.water_proc()
    check(P.stage == 11, "snow storm death")
    del(P)
    var/obj/structure/farming/plant/mushroom/M = new(locate(4,1,1))
    M.water = 0
    M.max_water = 0
    M.water_proc()
    check(M.stage == 1 && M.water == 0, "mushroom watering exemption")
    del(M)
    world.log << "PASS outdoor crops"
    del(world)



// Seed admission is exercised separately in tests/winter_crops; this fixture tests forage/water.
/proc/winter_crop_plot_error(turf/T)
    return null

/obj/item/stack/farming/seeds/proc/planting_error(turf/T)
    return null
