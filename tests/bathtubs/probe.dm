// Native probe for using bathtubs (code/modules/1713/bathtubs.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/bathtubs/probe.dm 300
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 20
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/bathtub_probe/New()
	return
var/vr_failures = 0
var/vr_runtime_error = FALSE
/proc/vr_check(condition, label)
	if (!condition)
		vr_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	vr_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	sleep(1)
	try
		config = new
		config.webhook_can_fire = FALSE
		makeDatumRefLists()
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		movementMachine = new
		map = new /obj/map_metadata/bathtub_probe
		Master.start_timer_loop()
		vr_checks()
	catch(var/exception/e)
		vr_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = vr_failures, "runtime_error" = vr_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/vr_checks()
	map.persistence = FALSE
	var/obj/structure/shower/bathtub/T = new /obj/structure/shower/bathtub/wooden(locate(5, 5, 1))
	var/mob/living/human/H = new /mob/living/human(locate(6, 5, 1))
	sleep(2)
	H.hygiene = 50

	// An empty tub is filled by clicking it, not climbed into.
	vr_check(!T.climb_in(H, H) && H.loc == locate(6, 5, 1), "an empty tub cannot be climbed into")
	T.attack_hand(H)
	vr_check(T.on, "clicking an empty tub fills it")
	vr_check(H.loc == locate(6, 5, 1), "filling the tub leaves you beside it")

	// Clicking the full tub from beside it climbs in and soaks.
	spawn T.attack_hand(H)
	sleep(2)
	vr_check(H.loc == T.loc && H.buckled == T, "clicking a full tub climbs in and lies down")
	sleep(110)
	vr_check(H.hygiene >= HYGIENE_LEVEL_NORMAL, "an undressed soak gets you clean")

	// Another bather finds no room in a small tub.
	var/mob/living/human/H2 = new /mob/living/human(locate(5, 6, 1))
	sleep(2)
	vr_check(!T.climb_in(H2, H2) && H2.loc == locate(5, 6, 1), "a small tub holds one bather")

	// A direction climbs out that way; clicking climbs out to the nearest free tile.
	T.relaymove(H, WEST)
	vr_check(H.loc == locate(4, 5, 1) && !H.buckled, "pressing a direction climbs out that way")
	H.forceMove(T.loc)
	T.buckle_mob(H)
	T.attack_hand(H)
	vr_check(H.loc != T.loc && get_dist(H, T) == 1 && !H.buckled, "clicking the tub from inside climbs out")

	// A dressed soak washes nothing.
	H.equip_to_slot_or_del(new /obj/item/clothing/under/traffic_police(H), slot_w_uniform)
	H.hygiene = 50
	spawn T.climb_in(H, H)
	sleep(112)
	vr_check(H.hygiene < HYGIENE_LEVEL_NORMAL, "soaking with clothes on does not get you clean")
	T.climb_out(H)

	// Someone else can be put in and bathed.
	H2.hygiene = 50
	spawn T.climb_in(H2, H)
	sleep(2)
	vr_check(H2.loc == T.loc && H2.buckled == T, "dragging someone onto the tub puts them in")
	sleep(110)
	vr_check(H2.hygiene >= HYGIENE_LEVEL_NORMAL, "a bather put in by someone else is washed")
	T.climb_out(H2)

	// Alt-click pulls the plug.
	T.AltClick(H)
	vr_check(!T.on, "alt-click empties the tub")

	// A public tub takes one bather on each of its four tiles.
	var/obj/structure/shower/bathtub/big/B = new /obj/structure/shower/bathtub/big/stone(locate(10, 10, 1))
	var/mob/living/human/P = new /mob/living/human(locate(9, 10, 1))
	sleep(2)
	B.fill_tub(P)
	var/list/spots = list()
	for (var/i in 1 to 4)
		var/mob/living/human/Q = new /mob/living/human(locate(9, 10, 1))
		sleep(1)
		spawn B.climb_in(Q, Q)
		sleep(2)
		if (B.in_tub(Q) && !(Q.loc in spots))
			spots += Q.loc
	vr_check(spots.len == 4, "four bathers fill the four tiles of a public tub")
	vr_check(!B.climb_in(P, P) && !B.in_tub(P), "a fifth finds no room")
	vr_check(bath_water_at(locate(11, 11, 1)) && !bath_water_at(locate(12, 12, 1)), "soap finds the public tub's water on all its tiles")
	sleep(110)
