// Native check for the flint nodule roll and antler counts, compiled against
// procs extracted from code/modules/1713/flint_mining.dm by run.py.
#define SPAN_GREEN_BOLD(X) X

/proc/get_area(atom/A)
	return isturf(A) ? A.loc : null
/proc/to_chat(target, message)
	target << message
// The depth table is checked by tests/building_levels (--cave); here only
// that the roll uses it.
var/global/flint_probe_depth_factor = 1
/proc/underground_ore_factor(resource, turf/T)
	return resource == "flint" ? flint_probe_depth_factor : 1

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

/proc/check_nodules(turf/rock, area/above, label, min_rate, max_rate, min_count, max_count, expected_mean)
	var/trials = 20000
	var/hits = 0
	var/total = 0
	var/failures = 0
	for (var/i = 1, i <= trials, i++)
		var/count = rock.mining_flint_nodules(null, above)
		if (count)
			hits++
			total += count
			if (count < min_count || count > max_count)
				failures++
	for (var/obj/item/weapon/flint/F in rock)
		del(F)
	var/rate = hits / trials
	var/mean = hits ? total / hits : 0
	world.log << "[label]: hit rate [rate], mean per hit [mean]"
	if (failures || rate < min_rate || rate > max_rate || abs(mean - expected_mean) > 0.2)
		world.log << "FAIL [label] flint drop distribution"
		return 1
	return 0

/world/New()
	..()
	var/failures = gunflint_checks()
	var/turf/plain = locate(1, 1, 1)
	plain = new /turf/floor/dirt/underground(plain)
	var/turf/sandy = locate(2, 1, 1)
	sandy = new /turf/floor/dirt/underground/sandy(sandy)
	var/turf/special_sandy = locate(3, 1, 1)
	special_sandy = new /turf/floor/dirt/underground/sandy(special_sandy)
	var/area/special = new /area/caribbean/void/caves/special
	special.contents += special_sandy
	var/area/desert = new /area/desert_test
	failures += check_nodules(plain, null, "plain rock", 0.18, 0.22, 1, 3, 2)
	failures += check_nodules(sandy, null, "shallow sandy rock", 0.085, 0.115, 1, 1, 1)
	failures += check_nodules(plain, desert, "shallow rock under desert", 0.085, 0.115, 1, 1, 1)
	failures += check_nodules(special_sandy, null, "special cave sandy rock", 0.035, 0.065, 2, 6, 4)
	flint_probe_depth_factor = 0.5
	failures += check_nodules(sandy, null, "depth two sandy rock", 0.015, 0.035, 1, 3, 2)
	flint_probe_depth_factor = 0
	failures += check_nodules(plain, null, "deep plain rock", 0, 0, 1, 3, 0)
	failures += check_nodules(sandy, null, "deep sandy rock", 0, 0, 1, 3, 0)
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
	if (!failures)
		world.log << "PASS flint mining probe"
	del(world)
