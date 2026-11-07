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
/atom/proc/update_icon()
	return
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

#define SPAN_WARNING(X) X
/proc/playsound()
	return
/proc/get_turf(atom/A)
	return A
/obj/item/weapon/gun/projectile/flintlock
	var/cocked = FALSE
	var/base_checks = 0
/obj/item/weapon/gun/projectile/flintlock/proc/special_check(mob/user)
	base_checks++
	return cocked
/obj/item/weapon/gun/projectile/flintlock/proc/can_hit(atom/target, mob/living/user)
	return special_check(user)
/obj/item/weapon/gun/projectile/flintlock/proc/handle_post_fire()
	cocked = FALSE

/proc/gunflint_checks()
	var/failures = 0
	var/obj/item/weapon/gun/projectile/flintlock/G = new
	var/life = G.gunflint_left()
	if (life < 25 || life > 40)
		failures++
		world.log << "FAIL fresh gunflint life [life], expected 25-40"
	var/fired = 0
	for (var/i = 1, i <= 200 && G.gunflint_left() > 0, i++)
		G.cocked = TRUE
		if (!G.special_check(null))
			failures++
			world.log << "FAIL a sharp gunflint misfired"
			break
		G.handle_post_fire()
		fired++
	if (fired != life || G.gunflint_shots != 0)
		failures++
		world.log << "FAIL gunflint wore after [fired] shots, expected [life]"
	var/misfires = 0
	var/aim_misfires = 0
	for (var/i = 1, i <= 4000, i++)
		G.cocked = TRUE
		if (!G.can_hit(null, null) || !G.cocked)
			aim_misfires++
		G.cocked = TRUE
		if (!G.special_check(null))
			misfires++
			if (G.cocked)
				failures++
				world.log << "FAIL a misfire must uncock the gun"
				break
	if (aim_misfires)
		failures++
		world.log << "FAIL aiming checks misfired [aim_misfires] times"
	if (misfires < 1800 || misfires > 2200)
		failures++
		world.log << "FAIL worn gunflint misfired [misfires]/4000, expected about half"
	G.cocked = FALSE
	if (G.special_check(null))
		failures++
		world.log << "FAIL uncocked flintlock fired"
	world.log << "gunflint life [life] worn misfires [misfires]/4000"
	return failures

/world/New()
	..()
	var/failures = gunflint_checks()
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
