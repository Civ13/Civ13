// Native probe for horse breeding (code/modules/1713/horse_breeding.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/horse_breeding/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 8
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/horse_probe/New()
	return
var/hb_failures = 0
var/hb_runtime_error = FALSE
/proc/hb_check(condition, label)
	if (!condition)
		hb_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	hb_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/horse_probe
		hb_checks()
	catch(var/exception/e)
		hb_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = hb_failures, "runtime_error" = hb_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)


/proc/hb_checks()
	// Battle maps keep their horses tame.
	map.persistence = FALSE
	var/mob/living/simple_animal/horse/B = new /mob/living/simple_animal/horse(locate(2, 2, 1))
	hb_check(!B.make_wild() && !B.wild, "horses on a battle map stay tame")
	hb_check(B.horse_speed >= 35 && B.horse_speed <= 65 && B.stamina >= 35, "a new horse has speed and stamina ([B.horse_speed], [B.stamina])")
	map.persistence = TRUE
	var/mob/living/simple_animal/horse/W = new /mob/living/simple_animal/horse/black(locate(4, 2, 1))
	hb_check(W.make_wild() && W.wild, "horses in the wild on a persistence map are wild")
	hb_check(domestication_refused(new /obj/item/animal_tack/saddle(W.loc)), "a wild horse refuses a saddle")

	// A tame mare beside a tame stallion carries a foal.
	var/mob/living/simple_animal/horse/mare = new /mob/living/simple_animal/horse/white(locate(6, 4, 1))
	mare.female = TRUE
	mare.horse_speed = 70
	mare.stamina = 60
	var/mob/living/simple_animal/horse/stallion = new /mob/living/simple_animal/horse/beige(locate(7, 4, 1))
	stallion.female = FALSE
	stallion.horse_speed = 60
	stallion.stamina = 40
	var/now = trap_now_minutes()
	mare.horse_tick(now)
	hb_check(mare.foal_due && mare.sire_type == /mob/living/simple_animal/horse/beige, "a mare beside a stallion is in foal")
	mare.horse_tick(now + 30)
	hb_check(mare.foal_due, "she carries it until her time")
	mare.horse_tick(now + 61)
	var/mob/living/simple_animal/horse/F = null
	for (var/mob/living/simple_animal/horse/H in range(1, mare))
		if (H.foal)
			F = H
	hb_check(F && !mare.foal_due, "the foal is born")
	if (F)
		hb_check(F.icon_state == replacetext(F.adult_state, "horse", "foal") && !F.can_ride, "a foal looks young and can't be ridden ([F.icon_state])")
		hb_check(F.horse_speed >= 55 && F.horse_speed <= 75 && F.stamina >= 40 && F.stamina <= 60, "a foal takes after its parents ([F.horse_speed], [F.stamina])")
		F.horse_tick(now + 200)
		hb_check(!F.foal && F.can_ride && F.icon_state == F.adult_state, "a foal grows into a horse that can be ridden")

	// Speed and shoes.
	var/mob/living/simple_animal/horse/fast = new /mob/living/simple_animal/horse(locate(10, 2, 1))
	fast.horse_speed = 75
	var/mob/living/simple_animal/horse/slow = new /mob/living/simple_animal/horse(locate(10, 4, 1))
	slow.horse_speed = 25
	hb_check(fast.ride_delay() < slow.ride_delay(), "a faster horse is ridden faster")
	var/turf/rough = new /turf/floor/gravel(locate(10, 6, 1))
	var/mob/living/simple_animal/horse/S = new /mob/living/simple_animal/horse(rough)
	S.horse_speed = 50
	var/unshod = S.ride_delay()
	S.shod = TRUE
	var/shod = S.ride_delay()
	hb_check(unshod > shod, "an unshod horse is slower on rocky ground ([unshod] vs [shod])")
	S.shoe_wear = 1999
	S.ride_delay()
	hb_check(!S.shod && (locate(/obj/item/horseshoes/worn) in rough), "shoes wear out on stone and are cast")
	var/mob/living/simple_animal/horse/G = new /mob/living/simple_animal/horse(locate(12, 2, 1))
	G.stamina = 70
	var/mob/living/simple_animal/horse/G2 = new /mob/living/simple_animal/horse(locate(12, 4, 1))
	G2.stamina = 30
	hb_check(G.animal_draft_hunger_cost() <= G2.animal_draft_hunger_cost(), "a hardier horse hungers less hauling")
