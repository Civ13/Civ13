// Native probe for shooting down from an upper storey
// (code/modules/projectiles/storey_fire.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/storey_fire/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 8
	maxz = 2
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/sf_probe/New()
	return
/mob/living/human/sf_fixture
	m_intent = "stealth"
	var/mood_gain = 0
/mob/living/human/sf_fixture/New()
	return
/mob/living/human/sf_fixture/adaptStat(stat, amount)
	return
/mob/living/human/sf_fixture/update_body(update_icons = 1, forced = FALSE)
	return
/mob/living/human/sf_fixture/update_icons()
	return
/mob/living/human/sf_fixture/regenerate_icons()
	return
/mob/living/human/sf_fixture/adjust_mood(amount, reason)
	mood_gain += amount
var/sf_failures = 0
var/sf_runtime_error = FALSE
/proc/sf_check(condition, label)
	if (!condition)
		sf_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	sf_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/sf_probe
		sf_checks()
	catch(var/exception/e)
		sf_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = sf_failures, "runtime_error" = sf_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/mob/living/simple_animal/sf_target
	health = 100
	maxHealth = 100
/mob/living/simple_animal/sf_target/New()
	return
/mob/living/simple_animal/sf_target/Life()
	return

/proc/sf_shot(turf/from, turf/aim)
	var/obj/item/projectile/bullet/P = new(from)
	P.starting = from
	P.original = aim
	P.damage = 30
	P.firedfrom = new /obj/item/weapon/gun/projectile(null)
	return P

/proc/sf_checks()
	for (var/x = 1 to 10)
		new /turf/sky/building(locate(x, 4, 2))
	var/turf/shooter = locate(1, 2, 2)
	var/turf/air = locate(5, 4, 2)
	var/turf/under = locate(5, 4, 1)
	sf_check(building_open_turf(air) && multiz_level_below(2) == 1, "the fixture has open air over the ground")

	var/mob/living/simple_animal/sf_target/T = new(under)
	var/obj/item/projectile/bullet/P = sf_shot(shooter, air)
	sf_check(P.storey_drop_shot(air), "a shot aimed at open air drops through it")
	sf_check(QDELETED(P), "the dropped shot is spent")
	sf_check(T.health < 100, "it hits the one standing below ([T.health])")

	var/obj/item/projectile/bullet/P2 = sf_shot(shooter, locate(7, 4, 2))
	sf_check(!P2.storey_drop_shot(air), "a shot aimed further on passes over the open air")
	sf_check(!QDELETED(P2), "and keeps flying")

	var/turf/ground = locate(3, 2, 2)
	var/obj/item/projectile/bullet/P3 = sf_shot(shooter, ground)
	sf_check(!P3.storey_drop_shot(ground), "a shot at a solid floor does not drop")

	new /obj/covers/repairedfloor(locate(7, 4, 2))
	var/obj/item/projectile/bullet/P4 = sf_shot(shooter, locate(7, 4, 2))
	sf_check(!P4.storey_drop_shot(locate(7, 4, 2)), "a floor laid over the gap stops the drop")

	// Through the projectile's own turf step, as in flight.
	var/mob/living/simple_animal/sf_target/T2 = new(under)
	var/obj/item/projectile/bullet/P5 = sf_shot(shooter, air)
	P5.handleTurf(air)
	sf_check(QDELETED(P5) && T2.health < 100 || T.health < 100 && QDELETED(P5), "a shot reaching the open air in flight drops through it")
