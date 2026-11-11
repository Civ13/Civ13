// Native probe: a body in a dug pocket under a pit on a two-level world climbs
// out on every side, and each refusal names its cause.
/world
	hub = ""
	visibility = 0
	maxx = 10
	maxy = 10
	maxz = 2
	fps = 20
	turf = /turf/floor/dirt/underground
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/pit_climbing_native/New()
	map = src

/mob/living/human/pit_climbing_native/human_subtile_authority(client/owner)
	return TRUE

var/list/pit_probe_log = list()

/proc/pit_probe_run()
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
	map = new /obj/map_metadata/pit_climbing_native
	for (var/tx in 1 to 10)
		for (var/ty in 1 to 10)
			new /turf/floor/grass(locate(tx, ty, 2))
	new /turf/floor/dirt(locate(5, 5, 1))
	new /obj/structure/multiz/ladder/ww2/tunneltop/pit(locate(5, 5, 2))
	var/mob/living/human/pit_climbing_native/H = new(locate(5, 5, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.lastarea = get_area(H)
	H.set_human_subtile(TRUE)
	var/list/why = list()
	pit_probe_check(ledge_climber_ready(H) && multiz_level_above(1) == 2, "ready_and_level_above")
	for (var/d in list(NORTH, SOUTH, EAST, WEST))
		pit_probe_check(ledge_climb_destination(H, d) == get_step(locate(5, 5, 2), d), "climbs_out_[d]")
	// A diagonal facing from free movement is split into its two halves.
	pit_probe_check(ledge_climb_directions(NORTHEAST) ~= list(NORTH, EAST), "diagonal_halves")
	pit_probe_check(!ledge_climb_destination(H, NORTHEAST, why) && findtext(why[1], "Face straight"), "diagonal_reason")
	// A blocked landing names its cause and the other sides still work.
	var/obj/structure/pit_probe_block/block = new(locate(5, 6, 2))
	pit_probe_check(!ledge_climb_destination(H, NORTH, why) && findtext(why[1], "not clear"), "blocked_landing_reason")
	pit_probe_check(ledge_climb_destination(H, SOUTH), "other_side_still_climbs")
	qdel(block)
	// Away from the hole the ceiling is solid.
	H.loc = locate(5, 4, 1)
	new /turf/floor/dirt(locate(5, 4, 1))
	pit_probe_check(!ledge_under_shaft(H) && !ledge_climb_destination(H, WEST, why) && findtext(why[1], "solid ceiling"), "solid_ceiling_reason")
	H.loc = locate(5, 5, 1)
	pit_probe_check(ledge_under_shaft(H), "under_shaft")
	// Hands: one free hand is enough, none refuses with a reason.
	H.r_hand = new /obj/item/stack/rods(H)
	pit_probe_check(ledge_climb_destination(H, NORTH), "one_free_hand")
	H.l_hand = new /obj/item/stack/rods(H)
	pit_probe_check(!ledge_climb_destination(H, NORTH, why) && findtext(why[1], "free hand"), "no_free_hand_reason")

/obj/structure/pit_probe_block
	density = TRUE

/proc/pit_probe_check(ok, label)
	pit_probe_log += label
	if (!ok)
		throw EXCEPTION(label)

/world/New()
	OpenPort("none")
	var/error = null
	try
		pit_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] [probe_error.file]:[probe_error.line]"
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("log" = pit_probe_log, "error" = error)), "receipt.json")
	del(world)
