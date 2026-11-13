// Wild West mounted raids on SStimer, headless (run.py).
/world
	maxx = 30
	maxy = 30
	maxz = 1
	turf = /turf/floor/dirt
	area = /area

/obj/map_metadata/raid_probe/New()
	return
/mob/living/human/raid_probe/New()
	return
/mob/living/human/raid_probe/adaptStat(stat, amount)
	return
/area/raid_probe_inside
	location = AREA_INSIDE

var/ww_failures = 0
/proc/ww_check(cond, msg)
	if (!cond)
		ww_failures++
	text2file("[cond ? "ok" : "FAIL"]: [msg]\n", "ww_log.txt")

/world/Error(exception/e)
	ww_check(FALSE, "runtime error [e] [e.file]:[e.line]")

/world/New()
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	movementMachine = new // Footsteps read its tick count.
	spawn(5)
		ww_run()

/proc/ww_rider(x, y)
	var/mob/living/human/H = new /mob/living/human/raid_probe(locate(x, y, 1))
	human_mob_list |= H
	return H

/proc/ww_horses()
	. = 0
	for (var/mob/living/simple_animal/horse/A in world)
		if (!QDELETED(A))
			.++

/proc/ww_dust()
	. = 0
	for (var/obj/effect/hoof_dust/D in world)
		if (!QDELETED(D))
			.++

/proc/ww_run()
	if (!fexists("skip_start.txt"))
		Master.start_timer_loop()
	try
		ww_cases()
	catch (var/exception/e)
		ww_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file("DONE\n", "ww_log.txt")
	del(world)

/proc/ww_cases()
	map = new /obj/map_metadata/raid_probe
	map.ID = MAP_LITTLE_CREEK
	var/mob/living/human/H = ww_rider(10, 10)
	ww_check(!wildwest_mount_outlaw(H) && !H.riding, "off the raid map nobody is put on a horse")

	map.ID = MAP_LITTLE_CREEK_TDM
	var/mob/living/simple_animal/horse/dead = new(locate(9, 10, 1))
	dead.stat = DEAD
	var/mob/living/simple_animal/horse/black/free = new(locate(13, 10, 1))
	var/before = ww_horses()
	ww_check(wildwest_mount_outlaw(H), "an outlaw at the camp is put in the saddle")
	ww_check(H.riding && H.riding_mob == free && free.rider == H && free.ride, "they take the free horse standing nearby, not the dead one")
	ww_check(free.loc == H.loc && ww_horses() == before, "the horse is brought to them and no new horse is made")
	ww_check(!wildwest_mount_outlaw(H), "someone already riding is left alone")

	var/mob/living/human/second = ww_rider(10, 10)
	ww_check(wildwest_mount_outlaw(second) && second.riding_mob && second.riding_mob != free, "with no free horse nearby a second outlaw gets a new one")
	ww_check(ww_horses() == before + 1 && istype(second.riding_mob, /mob/living/simple_animal/horse), "exactly one horse was added")

	// Dust.
	var/turf/open = locate(20, 20, 1)
	ww_check(hoof_dust(free, open) && ww_dust() == 1, "a ridden horse leaves a puff of dust on open ground")
	ww_check(!hoof_dust(free, open) && ww_dust() == 1, "a second puff right away is held back")
	var/turf/water = new /turf/floor/beach/water(locate(21, 20, 1))
	var/mob/living/simple_animal/horse/beige/other = new(locate(25, 25, 1))
	ww_check(!hoof_dust(other, water), "no dust on water")
	var/turf/porch = locate(22, 20, 1)
	var/area/raid_probe_inside/I = new
	I.contents += porch
	ww_check(!hoof_dust(other, porch), "no dust indoors")
	ww_check(!hoof_dust(H, open), "only horses kick up dust")
	sleep(4)
	ww_check(hoof_dust(free, open) && ww_dust() == 2, "after the interval the horse kicks up dust again")
	sleep(25)
	ww_check(ww_dust() == 0, "the dust settles and every puff is deleted")

	// A rider's move takes the horse along and leaves dust behind it.
	var/turf/start = locate(15, 15, 1)
	H.forceMove(start)
	free.forceMove(start)
	sleep(4)
	H.Move(locate(16, 15, 1), EAST)
	var/turf/hf = get_turf(free)
	var/turf/hh = get_turf(H)
	ww_check(hh && hh.x == 16 && hf && hf != start && get_dist(hf, hh) <= 1 && H.riding_mob == free, "the horse moves with its rider (rider [hh ? "[hh.x],[hh.y]" : "-"], horse [hf ? "[hf.x],[hf.y]" : "-"])")
	var/found = FALSE
	for (var/obj/effect/hoof_dust/D in start)
		if (!QDELETED(D))
			found = TRUE
	ww_check(found, "riding across open ground leaves dust where the horse was")
