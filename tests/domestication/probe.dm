// Native domestication probe, included by tests/ecology_spawning/run_linux.py, never by
// the game DME. It drives code/modules/1713/domestication.dm.
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
/obj/map_metadata/tame_probe/New()
	map = src
/mob/living/human/tame_probe/New()
	icon_update = FALSE
	return
var/tame_failures = 0
var/tame_runtime_error = FALSE
/proc/tame_check(condition, label)
	if (!condition)
		tame_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	tame_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"


/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/tame_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		tame_flag_checks()
		tame_feeding_checks()
		tame_refusal_checks()
	catch(var/exception/e)
		tame_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = tame_failures, "runtime_error" = tame_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/tame_flag_checks()
	var/mob/living/simple_animal/goat/female/G = new(locate(3, 3, 1))
	tame_check(!G.wild && G.domesticable, "a goat spawned by hand starts tame")
	tame_check(G.make_wild() && G.wild, "a goat can be made wild")
	var/mob/living/simple_animal/goat/kid = new(locate(3, 3, 1))
	tame_check(kid.wild, "a kid born beside a wild goat is wild")
	var/mob/living/simple_animal/sheep/lamb = new(locate(3, 3, 1))
	tame_check(!lamb.wild, "a lamb is not wild because of a goat")
	var/mob/living/simple_animal/rabbit/R = new(locate(5, 5, 1))
	tame_check(!R.make_wild() && !R.wild, "rabbits are never domestic")
	persistence_saved_atom_construction++
	var/mob/living/simple_animal/goat/loaded = new(locate(3, 3, 1))
	persistence_saved_atom_construction--
	tame_check(!loaded.wild, "a restored goat keeps its saved state")
	var/mob/living/simple_animal/pig_boar/P = new(locate(7, 7, 1))
	var/mob/living/simple_animal/pig_gilt/Q = new(locate(7, 7, 1))
	tame_check(P.domestic_family() == Q.domestic_family(), "boar and gilt are one family")

/proc/tame_feeding_checks()
	var/mob/living/human/tame_probe/H = new(locate(10, 11, 1))
	var/mob/living/simple_animal/sheep/S = new(locate(10, 10, 1))
	S.make_wild()
	var/now = 12000000 // keep one-minute steps exact in DM float arithmetic
	tame_check(S.tame_feeding(H, now) && S.tame_trust == 1, "a first feeding counts")
	tame_check(!S.tame_feeding(H, now + 3) && S.tame_trust == 1, "feeding again at once does not count")
	for (var/i = 1 to TAME_FEEDINGS - 2)
		S.tame_feeding(H, now + i * TAME_FEED_GAP)
	tame_check(S.wild && S.tame_trust == TAME_FEEDINGS - 1, "one feeding short is still wild")
	var/last = now + (TAME_FEEDINGS - 2) * TAME_FEED_GAP
	var/last_text = S.tame_fed
	tame_check(S.tame_current_trust(last + TAME_FADE_AFTER - 1) == TAME_FEEDINGS - 1, "trust is intact just before a full day")
	tame_check(S.tame_current_trust(last + 2 * TAME_FADE_AFTER) == TAME_FEEDINGS - 3, "two days away loses two feedings")
	tame_check(S.tame_current_trust(last + 2 * TAME_FADE_AFTER) == TAME_FEEDINGS - 3 && S.tame_fed == last_text && S.tame_trust == TAME_FEEDINGS - 1, "repeated reads do not change trust or feeding time")
	var/day_boundary = last + TAME_FADE_AFTER
	tame_check(S.tame_feeding(H, day_boundary) && S.tame_trust == TAME_FEEDINGS - 1 && S.tame_fed == trap_minutes_text(day_boundary), "feeding at the day boundary offsets one point of decay")
	tame_check(!S.tame_feeding(H, day_boundary + TAME_FEED_GAP - 1) && S.tame_trust == TAME_FEEDINGS - 1, "real feeding still restarts the cooldown")
	var/old_feeding = trap_now_minutes() - TAME_FADE_AFTER
	S.tame_trust = 3
	S.tame_fed = trap_minutes_text(old_feeding)
	tame_check(findtext(S.tame_state_text(), "2 of 6") && S.tame_fed == trap_minutes_text(old_feeding) && S.tame_trust == 3, "examine shows decayed trust without recording a feeding")
	tame_check(S.tame_feeding(H, old_feeding + TAME_FADE_AFTER + 9) && S.tame_trust == 3, "feeding nine minutes after the decay boundary still counts")
	S.tame_trust = TAME_FEEDINGS - 1
	S.tame_fed = trap_minutes_text(now)
	S.tame_feeding(H, now + TAME_FEED_GAP)
	tame_check(!S.wild && !S.tame_trust, "the last feeding tames it")
	tame_check(S.tame_state_text() == "It is tame.", "examine says tame")
	var/mob/living/simple_animal/goat/G = new(locate(12, 10, 1))
	G.make_wild()
	var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/W = new(locate(12, 11, 1))
	G.simplehunger = 0
	G.feed(W, H)
	tame_check(G.tame_trust == 1, "hand-feeding grain counts toward taming")

/proc/tame_refusal_checks()
	var/mob/living/human/tame_probe/H = new(locate(20, 21, 1))
	var/mob/living/simple_animal/cattle/cow/C = new(locate(20, 20, 1))
	C.make_wild()
	var/obj/item/weapon/leash/L = new(locate(20, 21, 1))
	C.attackby(L, H)
	tame_check(!L.onedefined, "a wild cow refuses the leash")
	C.wild = FALSE
	C.attackby(L, H)
	tame_check(L.onedefined, "a tame cow takes the leash")
	tame_check(domestication_refused(new /obj/item/weapon/shears) && domestication_refused(new /obj/item/weapon/reagent_containers/glass/bucket), "shears and milk pails are refused")
	tame_check(!domestication_refused(new /obj/item/weapon/reagent_containers/food/snacks/grown/wheat), "food is not refused")
