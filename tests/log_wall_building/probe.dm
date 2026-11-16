// Native probe for log walls built in steps
// (code/game/objects/covers_types/log_wall_building.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/log_wall_building/probe.dm 300
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/log_wall_probe/New()
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
		map = new /obj/map_metadata/log_wall_probe
		Master.start_timer_loop()
		vr_checks()
	catch(var/exception/e)
		vr_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = vr_failures, "runtime_error" = vr_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/vr_hold(mob/living/human/U, obj/item/I)
	if (U.l_hand)
		U.l_hand.loc = null
	I.loc = U
	U.hand = TRUE
	U.l_hand = I

/proc/vr_tool(flag)
	for (var/path in typesof(/obj/item))
		var/obj/item/I = path
		if (initial(I.tool_flags) & flag)
			return new path
	return null

/proc/vr_count_logs(turf/T)
	. = 0
	for (var/obj/item/stack/material/wood/S in T)
		. += S.amount

/proc/vr_checks()
	var/mob/living/human/U = new /mob/living/human(locate(5, 4, 1))
	U.a_intent = I_HELP
	var/turf/site = locate(5, 5, 1)
	var/obj/covers/wood_wall/log_build/B = new /obj/covers/wood_wall/log_build(site)
	vr_check(B.stage == 1 && !B.opacity && B.density && B.health == 60 && B.incomplete, "the sill is one log, low, solid and see-through")
	vr_check(building_insulation_edge_base(site) == 0.3, "a half-built wall holds little warmth")

	var/obj/item/stack/material/wood/L = new /obj/item/stack/material/wood(null, 10)
	vr_hold(U, L)
	B.attackby(L, U)
	vr_check(B.stage == 2 && !B.opacity && L.amount == 9 && B.health == 150, "a log raises it to waist height")
	B.attackby(L, U)
	vr_check(B.stage == 3 && B.opacity && L.amount == 8, "the upper courses block sight")
	B.attackby(L, U)
	var/obj/covers/wood_wall/log/W = locate() in site
	vr_check(QDELETED(B) && W && L.amount == 7, "the top plate finishes the wall: 4 logs in all")
	vr_check(W && !W.notched && !W.chinked && W.health == 350, "a new wall is unnotched and unchinked")
	vr_check(building_insulation_edge_base(site) == 0.5, "an unchinked wall lets warmth out")

	var/obj/item/hatchet = vr_tool(TOOL_HATCHET)
	vr_hold(U, hatchet)
	W.attackby(hatchet, U)
	vr_check(W.notched && W.health == 450, "an axe notches the corners to full strength")

	var/obj/item/stack/hay/H = new /obj/item/stack/hay(null, 1)
	vr_hold(U, H)
	W.attackby(H, U)
	vr_check(!W.chinked && H.amount == 1, "one hay is not enough to chink")
	H.amount = 3
	W.attackby(H, U)
	vr_check(W.chinked && H.amount == 1, "two hay chink the wall")
	vr_check(building_insulation_edge_base(site) == 0.8, "a chinked log wall holds warmth well")

	var/obj/covers/wood_wall/log/mapped = new /obj/covers/wood_wall/log(locate(9, 5, 1))
	vr_check(mapped.notched && mapped.chinked && mapped.health == 450, "a mapped log wall is a finished wall")

	var/turf/corner_site = locate(12, 5, 1)
	var/obj/covers/wood_wall/log_build/far = new /obj/covers/wood_wall/log_build(locate(12, 8, 1))
	vr_hold(U, L)
	far.attackby(L, U)
	vr_check(far.stage == 1 && L.amount == 7, "a builder out of reach adds nothing")
	var/obj/covers/wood_wall/log_build/corner/C = new /obj/covers/wood_wall/log_build/corner(corner_site)
	U.loc = locate(12, 4, 1)
	vr_hold(U, L)
	C.attackby(L, U)
	C.attackby(L, U)
	C.attackby(L, U)
	vr_check(locate(/obj/covers/wood_wall/log/corner) in corner_site, "a corner sill finishes as a corner wall")

	var/turf/down_site = locate(15, 5, 1)
	var/obj/covers/wood_wall/log_build/D = new /obj/covers/wood_wall/log_build(down_site)
	U.loc = locate(15, 4, 1)
	vr_hold(U, L)
	D.attackby(L, U)
	vr_check(D.stage == 2, "the builder next to it adds a log")
	var/obj/item/hammer = vr_tool(TOOL_HAMMER)
	vr_hold(U, hammer)
	D.attackby(hammer, U)
	vr_check(QDELETED(D) && vr_count_logs(down_site) == 2, "a hammer takes a half-built wall down for its logs")
