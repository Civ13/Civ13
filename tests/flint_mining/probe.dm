// Native check for the flint nodule roll and antler counts, compiled against
// procs extracted from code/modules/1713/flint_mining.dm by run.py.
#define SPAN_GREEN_BOLD(X) X

/proc/get_area(atom/A)
	return isturf(A) ? A.loc : null
/proc/to_chat(target, message)
	target << message

/world
	maxx = 3
	maxy = 1
	maxz = 1

/area
	var/climate = "temperate"
/area/desert_test
	climate = "desert"
/area/caribbean/void/caves/special

/turf/floor/dirt/underground
/turf/floor/dirt/underground/sandy

/obj/item/weapon/flint
/obj/item/weapon/material/pickaxe/antler

/mob/living/human
/mob/living/simple_animal/deer
	var/female = FALSE
	var/babydeer = FALSE
/mob/living/simple_animal/deer/female
	female = TRUE
/mob/living/simple_animal/deer/reindeer
/mob/living/simple_animal/deer/reindeer/female
	female = TRUE
/mob/living/simple_animal/deer/dikdik

/world/New()
	..()
	var/failures = 0
	var/turf/plain = locate(1, 1, 1)
	plain = new /turf/floor/dirt/underground(plain)
	var/turf/sandy = locate(2, 1, 1)
	sandy = new /turf/floor/dirt/underground/sandy(sandy)
	var/area/desert = new /area/desert_test
	var/trials = 20000
	var/hits = 0
	var/total = 0
	for (var/i = 1, i <= trials, i++)
		var/n = plain.mining_flint_nodules(null, null)
		if (n)
			hits++
			total += n
			if (n < 1 || n > 3)
				failures++
				world.log << "FAIL nodule count [n] outside 1-3"
	for (var/obj/item/weapon/flint/F in plain)
		del(F)
	var/rate = hits / trials
	if (rate < 0.18 || rate > 0.22)
		failures++
		world.log << "FAIL plain rock flint rate [rate], expected about 0.20"
	if (hits && (total / hits < 1.8 || total / hits > 2.2))
		failures++
		world.log << "FAIL mean nodules [total / hits], expected about 2"
	var/sandy_hits = 0
	var/desert_hits = 0
	for (var/i = 1, i <= trials, i++)
		if (sandy.mining_flint_nodules(null, null))
			sandy_hits++
		if (plain.mining_flint_nodules(null, desert))
			desert_hits++
	for (var/rate2 in list(sandy_hits / trials, desert_hits / trials))
		if (rate2 < 0.035 || rate2 > 0.065)
			failures++
			world.log << "FAIL sandy/desert flint rate [rate2], expected about 0.05"
	var/list/expect = list(
		/mob/living/simple_animal/deer = 2,
		/mob/living/simple_animal/deer/female = 0,
		/mob/living/simple_animal/deer/reindeer = 2,
		/mob/living/simple_animal/deer/reindeer/female = 2,
		/mob/living/simple_animal/deer/dikdik = 0)
	for (var/path in expect)
		var/mob/living/simple_animal/deer/D = new path
		if (D.antler_count() != expect[path])
			failures++
			world.log << "FAIL [path] antlers [D.antler_count()], expected [expect[path]]"
		D.babydeer = TRUE
		if (D.antler_count() != 0)
			failures++
			world.log << "FAIL baby [path] grew antlers"
	world.log << "flint rate [rate] mean [hits ? total / hits : 0] sandy [sandy_hits / trials] desert [desert_hits / trials]"
	if (!failures)
		world.log << "PASS flint mining probe"
	del(world)
