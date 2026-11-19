// Full-source probe: sprinting (code/game/mob/living/carbon/human/sprint.dm).
// Starting and stopping on stamina, the faster pace Check Movement reports,
// and the collisions: people knocked over, locked doors and barricades rammed,
// open doors left to open, fixed things slammed into.
/world
	hub = ""
	visibility = 0
	maxx = 12
	maxy = 12
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/sprint_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/sprint_probe/New()
	map = src

/turf/floor/plating/sprint_probe

// A post nobody can move or break.
/obj/structure/sprint_probe_post
	density = TRUE
	anchored = TRUE

// A door that never opens for anyone.
/obj/structure/simple_door/sprint_probe_locked/canOpen(mob/user)
	return FALSE

var/sprint_probe_checks = 0
var/sprint_runtime = null

/world/Error(exception/e)
	if (!sprint_runtime)
		sprint_runtime = "runtime [e] ([e.file]:[e.line])"

/proc/sprint_assert(ok, label)
	sprint_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/sprint_actor(tx, ty, name)
	var/mob/living/human/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.real_name = name
	H.name = name
	H.mood_modifier = 1
	H.stats["strength"] = list(100, 100)
	H.stats["dexterity"] = list(100, 100)
	H.stats["stamina"] = list(100, 100)
	return H

// Back on their feet, fresh, sprinting east.
/proc/sprint_reset(mob/living/human/H)
	H.SetWeakened(0)
	H.SetStunned(0)
	H.lying = FALSE
	H.stats["stamina"] = list(100, 100)
	H.next_sprint_collision = 0
	H.m_intent = "walk"
	H.dir = EAST
	H.start_sprint(FALSE)

/proc/sprint_probe_run()
	config = new
	config.webhook_can_fire = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.global_listen_count = list()
	GLOB.event_sources_count = list()
	GLOB.event_listen_count = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	movementMachine = new
	map = new /obj/map_metadata/sprint_probe

	var/mob/living/human/A = sprint_actor(5, 5, "Alice")
	var/mob/living/human/B = sprint_actor(6, 5, "Bob")

	// Starting: from a walk or a crawl, only with breath to spare.
	A.m_intent = "walk"
	sprint_assert(A.start_sprint(FALSE) && A.is_sprinting() && A.m_intent == "run", "sprint_starts")
	sprint_assert(A.sprint_mode_name() == "sprint", "stat_panel_says_sprint")
	sprint_assert(A.movement_check_intent_mult() == 1 / SPRINT_SPEED_MULT, "check_movement_pace")
	A.stop_sprint()
	sprint_assert(!A.is_sprinting() && A.m_intent == "run" && A.sprint_mode_name() == "run", "stop_keeps_running")
	A.m_intent = "proning"
	A.prone = TRUE
	sprint_assert(A.start_sprint(FALSE) && !A.prone && A.is_sprinting(), "sprint_from_crawl_stands")
	A.stop_sprint()
	A.stats["stamina"] = list(30, 100)
	sprint_assert(!A.start_sprint(FALSE) && !A.is_sprinting(), "too_winded_to_start")
	A.legcuffed = new /obj/item/weapon/handcuffs(A)
	A.stats["stamina"] = list(100, 100)
	sprint_assert(!A.start_sprint(FALSE), "legcuffs_stop_sprint")
	qdel(A.legcuffed)
	A.legcuffed = null

	// Dropping to a run once stamina runs low.
	sprint_reset(A)
	A.stats["stamina"] = list(25, 100)
	A.sprint_stamina_check()
	sprint_assert(A.is_sprinting(), "keeps_sprinting_above_floor")
	A.stats["stamina"] = list(15, 100)
	A.sprint_stamina_check()
	sprint_assert(!A.is_sprinting() && A.m_intent == "run", "slows_to_run_when_winded")

	// A stale flag never makes a walker sprint.
	A.sprinting = TRUE
	A.m_intent = "walk"
	sprint_assert(!A.is_sprinting(), "walking_is_not_sprinting")

	// Sprinting into someone: between equals they go down sooner or later,
	// and so does the sprinter sometimes. Running into them is no collision.
	A.m_intent = "run"
	A.sprinting = FALSE
	sprint_assert(!A.sprint_collide(B), "running_is_no_collision")
	var/knocked = FALSE
	var/self_fell = FALSE
	var/held = FALSE
	for (var/i in 1 to 300)
		sprint_reset(A)
		sprint_reset(B)
		sprint_assert(A.sprint_collide(B), "sprint_hits_person")
		sprint_assert(!A.is_sprinting() && A.stats["stamina"][1] == 100 - SPRINT_COLLIDE_STAMINA, "collision_costs_the_sprint")
		if (B.weakened > 0)
			knocked = TRUE
		else
			held = TRUE
		if (A.weakened > 0)
			self_fell = TRUE
		if (knocked && held && self_fell)
			break
	sprint_assert(knocked && held && self_fell, "person_outcomes_vary")
	sprint_reset(A)
	sprint_reset(B)
	A.sprint_collide(B)
	A.start_sprint(FALSE)
	sprint_assert(!A.sprint_collide(B), "collision_cooldown")

	// Strength and dexterity tilt it: a strong sprinter fells someone far more often.
	sprint_assert(physical_contest_chance(SPRINT_KNOCKDOWN_CHANCE, physical_contest_ratio(A, B, 2, 1)) == SPRINT_KNOCKDOWN_CHANCE, "equal_knockdown_odds")
	A.stats["strength"] = list(300, 300)
	sprint_assert(physical_contest_chance(SPRINT_KNOCKDOWN_CHANCE, physical_contest_ratio(A, B, 2, 1)) > SPRINT_KNOCKDOWN_CHANCE, "strength_knocks_harder")
	sprint_assert(A.sprint_ram_force() > SPRINT_RAM_FORCE, "strength_rams_harder")
	A.stats["strength"] = list(100, 100)

	// Someone already down, or the body being pulled, is not knocked again.
	sprint_reset(A)
	sprint_reset(B)
	B.lying = TRUE
	sprint_assert(!A.sprint_collide(B), "lying_person_skipped")
	B.lying = FALSE
	B.forceMove(locate(10, 10, 1))

	// A door that opens is left to open; one that will not is rammed.
	var/obj/structure/simple_door/open_door = new(locate(6, 6, 1), "wood")
	sprint_reset(A)
	sprint_assert(!A.sprint_collide(open_door) && A.is_sprinting(), "openable_door_opens_normally")
	var/obj/structure/simple_door/sprint_probe_locked/locked = new(locate(6, 4, 1), "wood")
	var/before = locked.health
	sprint_reset(A)
	sprint_assert(A.sprint_collide(locked) && !A.is_sprinting(), "locked_door_rammed")
	sprint_assert(locked.health < before, "ram_damages_door")

	// A barricade takes the ram as a building part.
	var/obj/structure/barricade/barricade = new(locate(4, 5, 1))
	before = barricade.health
	sprint_reset(A)
	sprint_assert(A.sprint_collide(barricade) && barricade.health < before, "barricade_rammed")

	// A fixed post head-on stops the sprinter; a glancing one does not.
	var/obj/structure/sprint_probe_post/post = new(locate(6, 5, 1))
	sprint_reset(A)
	A.dir = NORTH
	sprint_assert(!A.sprint_collide(post), "glancing_post_ignored")
	A.dir = EAST
	sprint_assert(A.sprint_collide(post) && !A.is_sprinting(), "post_slams")
	qdel(post)

	// A loose locker slides along.
	var/obj/structure/closet/locker = new(locate(6, 5, 1))
	sprint_reset(A)
	sprint_assert(A.sprint_collide(locker) && locker.x == 7, "locker_shoved")

/world/New()
	OpenPort("none")
	var/error = null
	try
		sprint_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	if (!error && sprint_runtime)
		error = sprint_runtime
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = sprint_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
