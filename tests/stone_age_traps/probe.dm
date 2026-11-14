// Native trap probe, included by tests/ecology_spawning/run_linux.py, never by
// the game DME. It drives code/modules/1713/stone_age_traps.dm.
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 30
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/trap_probe/New()
	map = src
/mob/living/human/trap_probe/New()
	icon_update = FALSE
	return
var/trap_failures = 0
var/trap_runtime_error = FALSE
/proc/trap_check(condition, label)
	if (!condition)
		trap_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	trap_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/obj/structure/stone_age_trap/snare/always/catch_chance()
	return 100
/obj/structure/stone_age_trap/snare/never/catch_chance()
	return 0

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/trap_probe
		season = "SUMMER"
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		for (var/turf/T in block(locate(20, 1, 1), locate(22, 5, 1)))
			T.ChangeTurf(/turf/floor/beach/water, FALSE, FALSE)
		locate(23, 1, 1):ChangeTurf(/turf/floor/beach/water/deep, FALSE, FALSE)
		locate(24, 1, 1):ChangeTurf(/turf/floor/beach/water/shallowsaltwater, FALSE, FALSE)
		trap_ground_checks()
		trap_snare_checks()
		trap_weir_checks()
		trap_pit_checks()
	catch(var/exception/e)
		trap_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = trap_failures, "runtime_error" = trap_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/trap_ground_checks()
	trap_check(trap_ground_ok(locate(3, 3, 1)), "grass outdoors takes a snare")
	trap_check(!trap_ground_ok(locate(20, 1, 1)), "water does not take a snare")
	trap_check(weir_water_ok(locate(20, 1, 1)), "shallow fresh water takes a weir")
	trap_check(!weir_water_ok(locate(23, 1, 1)), "deep water refuses a weir")
	trap_check(!weir_water_ok(locate(24, 1, 1)), "salt water refuses a weir")
	trap_check(!weir_water_ok(locate(3, 3, 1)), "grass refuses a weir")
	trap_check(trap_minutes(trap_minutes_text(13900123)) == 13900123, "minutes survive as text")

/proc/trap_snare_checks()
	var/now = trap_now_minutes()
	var/obj/structure/stone_age_trap/snare/always/S = new(locate(5, 5, 1))
	S.arm()
	trap_check(S.icon_state == "snare_set" && S.armed, "a set snare shows set")
	trap_check(S.settle(now) == 0 && !S.catch_type, "no rolls before ten minutes")
	S.last_roll = trap_minutes_text(now - 25)
	trap_check(S.settle(now) == 2 && S.catch_type && !S.armed, "two intervals roll and catch")
	trap_check(S.icon_state == "snare_sprung", "a caught snare shows sprung")
	trap_check(trap_minutes(S.caught_at) == now - 15, "caught at the first roll")
	trap_check(trap_minutes(S.last_roll) == now - 5, "the remainder carries over")
	var/mob/living/human/trap_probe/H = new(locate(5, 6, 1))
	trap_check(S.take_catch(H), "a fresh catch is taken")
	var/mob/living/simple_animal/A = locate() in locate(5, 5, 1)
	trap_check(A && A.stat == DEAD, "the catch is a dead animal")
	S.arm()
	S.last_roll = trap_minutes_text(now - 2000)
	S.settle(now)
	trap_check(S.catch_type && !S.take_catch(H), "a day-old catch is lost to scavengers")
	var/obj/structure/stone_age_trap/snare/never/N = new(locate(7, 5, 1))
	N.arm()
	N.last_roll = trap_minutes_text(now - 100000)
	trap_check(N.settle(now) == TRAP_MAX_ROLLS && N.armed && !N.catch_type, "rolls are capped and a miss stays set")
	trap_check(trap_minutes(N.last_roll) == now - 100000 + round(100000 / TRAP_SNARE_INTERVAL) * TRAP_SNARE_INTERVAL, "capped rolls still advance the clock")
	N.last_roll = trap_minutes_text(now + 500)
	trap_check(N.settle(now) == 0 && trap_minutes(N.last_roll) == now, "a clock from the future resets")
	var/obj/structure/stone_age_trap/snare/plain = new(locate(9, 9, 1))
	trap_check(plain.catch_chance() == TRAP_BASE_CHANCE, "base chance with no animals")
	season = "WINTER"
	trap_check(plain.catch_chance() == TRAP_BASE_CHANCE / 2, "winter halves the chance")
	season = "SUMMER"

/proc/trap_weir_checks()
	var/now = trap_now_minutes()
	var/obj/structure/stone_age_trap/weir/W = new(locate(21, 2, 1))
	W.arm()
	trap_check(W.icon_state == "fish_weir", "an empty weir")
	W.last_roll = trap_minutes_text(now - 100000)
	W.settle(now)
	trap_check(W.fish == WEIR_CAP && W.icon_state == "fish_weir_full", "a long-left weir fills to its cap")
	var/mob/living/human/trap_probe/H = new(locate(21, 3, 1))
	W.attack_hand(H)
	var/count = 0
	for (var/obj/item/weapon/reagent_containers/food/snacks/rawfish/F in locate(21, 3, 1))
		count++
	trap_check(count == WEIR_CAP && W.fish == 0 && W.icon_state == "fish_weir", "the fish are scooped out")
	var/obj/structure/stone_age_trap/weir/D = new(locate(5, 20, 1))
	D.arm()
	D.last_roll = trap_minutes_text(now - 100000)
	D.settle(now)
	trap_check(D.fish == 0, "a weir on dry land catches nothing")

/proc/trap_pit_checks()
	var/mob/living/human/trap_probe/digger = new(locate(14, 14, 1))
	digger.civilization = "Hunters"
	digger.real_name = "Digger"
	var/obj/structure/stone_age_trap/pit/P = new(locate(15, 15, 1))
	P.dug_by(digger)
	P.covered = TRUE
	P.update_icon()
	trap_check(P.icon_state == "pit_covered" && P.name == "branches", "a covered pit looks like branches")
	trap_check(P.tribe == "Hunters" && P.knows_pit(digger), "the digger knows the pit")
	var/mob/living/human/trap_probe/friend = new(locate(16, 16, 1))
	friend.civilization = "Hunters"
	var/mob/living/human/trap_probe/stranger = new(locate(16, 16, 1))
	stranger.civilization = "Others"
	trap_check(P.knows_pit(friend) && !P.knows_pit(stranger), "the tribe knows, strangers don't")
	friend.loc = P.loc
	P.Crossed(friend)
	trap_check(P.covered && !P.buckled_mob, "a tribe member walks over safely")
	var/mob/living/simple_animal/rabbit/R = new(locate(15, 15, 1))
	P.Crossed(R)
	trap_check(P.covered && !P.buckled_mob, "a rabbit is too small to fall in")
	var/mob/living/simple_animal/deer/D = new(locate(15, 15, 1))
	D.mob_size = MOB_LARGE
	var/before = D.health
	P.Crossed(D)
	trap_check(!P.covered && P.buckled_mob == D && D.buckled == P, "a deer falls in and is held")
	trap_check(D.health == before - PIT_FALL_DAMAGE, "the fall hurts")
	trap_check(P.icon_state == "pit_open", "the pit is left open")
	trap_check(P.persistence_runtime_var("buckled_mob"), "the hold is not saved")
	P.release_animal(D)
	trap_check(!P.buckled_mob && !D.buckled && D.loc != P.loc, "the deer scrambles out")
	P.staked = TRUE
	P.covered = TRUE
	P.update_icon()
	var/mob/living/simple_animal/deer/D2 = new(locate(15, 15, 1))
	D2.mob_size = MOB_LARGE
	before = D2.health
	P.Crossed(D2)
	trap_check(D2.health == before - PIT_FALL_DAMAGE - PIT_STAKE_DAMAGE || D2.stat == DEAD, "stakes wound")
	P.after_load()
	trap_check(!P.buckled_mob, "a load frees anyone held")
