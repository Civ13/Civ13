var/global/list/player_list = list()
var/global/list/grass_turf_list = list()
var/global/list/water_turf_list = list()
var/global/list/global_colour_matrix
var/global/global_radiation = 0
var/global/blasts = 0
/atom
    var/radiation = 0
    var/received = 0
/atom/proc/ex_act(severity)
    return
/turf/floor
/turf/floor/dirt
/turf/floor/dirt/burned
/turf/floor/grass
/turf/floor/grass/New()
    ..()
    grass_turf_list += src
/turf/floor/grass/Del()
    grass_turf_list -= src
    ..()
/turf/floor/plating
/turf/floor/beach/sand
/turf/floor/beach/water
/turf/floor/beach/water/New()
    ..()
    water_turf_list += src
/turf/proc/ChangeTurf(path)
    return new path(src)
/turf/floor/proc/update_icon()
    return
/area
    var/location = 1
/area/interior
    location = 0
/obj/effect/fire
/obj/structure/window
    var/shatters = 0
/obj/structure/window/proc/shatter()
    shatters++
/obj/structure/wild
/obj/structure/wild/rad_act(amount)
    radiation += amount
    received++
/obj/structure/farming
/obj/structure/farming/rad_act(amount)
    radiation += amount
    received++
/obj/item/weapon/geiger_counter
/obj/item/organ/external
/mob/living
/mob/living/human
    var/inducedSSD = FALSE
    var/orc = FALSE
    var/ant = FALSE
    var/crab = FALSE
    var/list/organs = list()
    var/list/HUDtech = list()
/mob/living/human/New()
    ..()
    for (var/i = 1 to 11)
        organs += new /obj/item/organ/external(src)
/mob/living/human/proc/get_organ(organ)
    return null
/mob/living/human/proc/getarmor_organ(organ, kind)
    return 0
/mob/living/human/proc/Weaken(amount)
    return
/proc/get_turf(atom/A)
    while (A && !isturf(A))
        A = A.loc
    return A
/proc/get_area(atom/A)
    var/turf/T = get_turf(A)
    return T ? T.loc : null
/proc/ishuman(atom/A)
    return istype(A, /mob/living/human)
/proc/change_global_radiation(amount)
    global_radiation += amount
/proc/log_game(message)
    return
/proc/shake_camera(mob/M, duration, strength)
    return
/proc/explosion(turf/T, devastation, heavy, light, flash)
    blasts++
/proc/check(condition, message)
    if (!condition)
        world.log << "FAIL [message]"
        del(world)
/proc/close_to(value, expected)
    return abs(value - expected) < 0.001
/world
    maxx = 140
    maxy = 4
    maxz = 2
    turf = /turf/floor
/world/New()
    world.OpenPort("none")
    var/turf/floor/dirt/center = new(locate(30,2,1))
    var/turf/floor/grass/near_grass = new(locate(70,1,1))
    var/turf/floor/grass/far_grass = new(locate(139,1,1))
    var/turf/floor/grass/other_grass = new(locate(139,1,2))
    var/turf/floor/beach/water/water = new(locate(70,3,1))
    var/turf/floor/beach/water/other_water = new(locate(70,3,2))
    var/obj/structure/window/window = new(locate(139,2,1))
    var/obj/structure/window/other_window = new(locate(139,2,2))
    var/obj/structure/wild/wild = new(locate(139,3,1))
    var/obj/structure/wild/other_wild = new(locate(139,3,2))
    var/obj/structure/farming/farm = new(locate(139,4,1))
    var/obj/structure/farming/other_farm = new(locate(139,4,2))
    var/mob/living/human/outdoor = new(locate(139,2,1))
    var/mob/living/human/near_human = new(locate(50,2,1))
    var/turf/inside = locate(138,2,1)
    inside.loc = new /area/interior
    var/mob/living/human/indoor = new(inside)
    var/mob/living/human/immune = new(locate(137,2,1))
    immune.inducedSSD = TRUE
    var/mob/living/human/other = new(locate(139,2,2))
    check(!nuke_map(null, 200, 1, FALSE), "null epicenter rejected")
    var/obj/holder = new(locate(30,2,1))
    var/obj/contained = new(holder)
    check(nuke_map(contained, 200, 1, FALSE), "contained epicenter normalized")
    sleep(70)
    check(blasts == 1 && global_radiation == 310, "one event and intentional global fallout")
    var/turf/replacement = locate(30,2,1)
    check(istype(replacement, /turf/floor/dirt/burned) && replacement.radiation == 20, "replacement turf irradiated")
    check(close_to(near_grass.radiation, 200/3) && close_to(far_grass.radiation, 200/3), "same-z near and far grass")
    check(other_grass.radiation == 0 && other_water.radiation == 0, "other-z registries unchanged")
    check(close_to(water.radiation, 200/3), "same-z water")
    check(window.shatters == 1 && other_window.shatters == 0, "windows scoped and once")
    check(wild.received == 1 && farm.received == 1 && wild.radiation == 22 && farm.radiation == 22, "same-z plants exactly once")
    check(other_wild.received == 0 && other_farm.received == 0, "other-z plants unchanged")
    check(close_to(outdoor.radiation, 200/30) && close_to(indoor.radiation, 2), "existing outdoor and interior dose")
    check(close_to(near_human.radiation, 200/30), "near and far mapwide dose preserved")
    check(immune.radiation == 0 && other.radiation == 0, "SSD and other-z dose exclusions")
    check(nuke_map(replacement, 200, 1, FALSE), "independent second event")
    sleep(70)
    check(blasts == 2 && global_radiation == 620 && window.shatters == 2 && wild.received == 2, "one application per independent event")
    check(other_window.shatters == 0 && other_farm.received == 0, "second event remains scoped")
    var/mob/living/human/pulse_near = new(locate(31,2,1))
    var/mob/living/human/pulse_far = new(locate(40,2,1))
    var/mob/living/human/pulse_other = new(locate(31,2,2))
    var/mob/living/human/pulse_immune = new(locate(31,1,1))
    pulse_immune.inducedSSD = TRUE
    check(radiation_pulse(replacement, 5, 100, 3, FALSE), "bounded pulse accepted")
    sleep(35)
    check(close_to(pulse_near.radiation, 3), "existing pulse duration applies exactly three doses")
    check(pulse_far.radiation == 0 && pulse_other.radiation == 0 && pulse_immune.radiation == 0, "pulse radius, z and immunity unchanged")
    world.log << "PASS radiation scope"
    del(world)
