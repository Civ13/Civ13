// Modern bridge fixture: real bridges.dm, covers and rail_network.dm procs on a
// small map with a strip of deep sea. The do_after/item wrappers are not
// driven; their state changes are the procs called here.
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 8
	maxz = 1
	turf = /turf/floor/dirt
	area = /area/caribbean
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/Topic(T, addr, master, key)
	return "Closed modern bridge fixture"

var/global/list/bridge_probe_checks = list()
var/global/list/bridge_probe_failed = list()
var/global/bridge_probe_runtime_error = FALSE

/world/Error(exception/E)
	bridge_probe_runtime_error = TRUE
	world.log << "Unexpected fixture runtime: [E] at [E.file]:[E.line]"
	return ..()

/proc/bridge_probe_check(label, passed)
	bridge_probe_checks += list(list("label" = label, "passed" = !!passed))
	if (!passed)
		bridge_probe_failed += label

/proc/bridge_probe_turf(x, y)
	return locate(x, y, 1)

/proc/bridge_probe_run()
	// Columns 6-12 are deep sea between two shores.
	for (var/x in 6 to 12)
		for (var/y in 1 to 8)
			var/turf/T = bridge_probe_turf(x, y)
			T.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
	var/turf/shore = bridge_probe_turf(5, 4)
	var/turf/first = bridge_probe_turf(6, 4)
	var/mob/builder = new(shore)

	bridge_probe_check("span/dry_land_refused", bridge_span_problem(bridge_probe_turf(4, 4), builder))
	bridge_probe_check("span/ocean_from_shore", isnull(bridge_span_problem(first, builder)))
	bridge_probe_check("span/diagonal_refused", bridge_span_problem(bridge_probe_turf(6, 5), builder))

	var/obj/covers/bridge/D = new(first)
	sleep(10) // covers update their turf after spawn(5)
	bridge_probe_check("deck/covers_water", first.iscovered() && first.water_level == 0)
	bridge_probe_check("deck/does_not_sink", !QDELETED(D) && D.loc == first)
	bridge_probe_check("span/occupied_refused", bridge_span_problem(first, builder))
	bridge_probe_check("track/layable_on_deck", isnull(track_lay_problem(first)) && track_lay_problem(bridge_probe_turf(7, 4)))

	// Out on the deck the builder carries on; a swimmer cannot.
	builder.loc = first
	bridge_probe_check("span/from_deck", isnull(bridge_span_problem(bridge_probe_turf(7, 4), builder)))
	builder.loc = bridge_probe_turf(7, 6)
	bridge_probe_check("span/swimmer_refused", bridge_span_problem(bridge_probe_turf(8, 6), builder))
	builder.loc = shore

	// Deck the whole crossing in steel and concrete, then run track over it to
	// the western map edge.
	for (var/x in 7 to 12)
		if (x % 2)
			new /obj/covers/bridge(bridge_probe_turf(x, 4))
		else
			new /obj/covers/bridge/concrete(bridge_probe_turf(x, 4))
	sleep(10)
	for (var/x in 1 to 14)
		new /obj/structure/rails/regular/horizontal(bridge_probe_turf(x, 4))
	bridge_probe_check("rail/crosses_bridge_to_edge", rail_network_reaches_edge(list(bridge_probe_turf(14, 4))))
	bridge_probe_check("deck/is_deck", bridge_deck_at(bridge_probe_turf(9, 4)) && bridge_deck_at(bridge_probe_turf(10, 4)) && !bridge_deck_at(bridge_probe_turf(5, 4)))

	// Track has to come off before a deck is taken apart.
	var/turf/mid = bridge_probe_turf(9, 4)
	bridge_probe_check("clear/blocked_by_track", bridge_clear_problem(mid))

	// Shelling a deck drops its track into the sea and breaks the line.
	var/obj/structure/rails/R = locate(/obj/structure/rails) in mid
	qdel(bridge_deck_at(mid))
	bridge_probe_check("destroy/track_falls", QDELETED(R) && !(locate(/obj/structure/rails) in mid))
	bridge_probe_check("destroy/water_back", mid.water_level == 200 && !mid.iscovered())
	bridge_probe_check("rail/broken_line", !rail_network_reaches_edge(list(bridge_probe_turf(14, 4))))

	// A bare deck comes apart; fire does not burn it.
	var/turf/side = bridge_probe_turf(8, 4)
	for (var/obj/structure/rails/SR in side)
		qdel(SR)
	bridge_probe_check("clear/bare_deck", isnull(bridge_clear_problem(side)))
	var/obj/covers/bridge/F = bridge_deck_at(side)
	F.fire_act(5000)
	F.fire_act(5000)
	bridge_probe_check("deck/fireproof", !QDELETED(F) && !F.flammable)

/world/New()
	OpenPort("none")
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	bridge_probe_run()
	text2file(json_encode(list("commit" = world.params["tested_commit"], "check_count" = bridge_probe_checks.len, "failed_labels" = bridge_probe_failed, "runtime_error" = bridge_probe_runtime_error, "checks" = bridge_probe_checks)), "result.json")
	world.log << "COMPLETE modern bridge fixture"
	del(world)
