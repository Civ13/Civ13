// Track laying fixture: real track_laying.dm and trains.dm procs on a small map.
// The do_after/item wrappers are not driven; their state changes are the procs
// called here (track_place_bed, place_rails, spike, pry, pry_apart).
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 12
	maxz = 1
	turf = /turf/floor/dirt
	area = /area/caribbean
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/Topic(T, addr, master, key)
	return "Closed track laying fixture"

var/global/list/track_probe_checks = list()
var/global/list/track_probe_failed = list()
var/global/track_probe_runtime_error = FALSE

/world/Error(exception/E)
	track_probe_runtime_error = TRUE
	world.log << "Unexpected fixture runtime: [E] at [E.file]:[E.line]"
	return ..()

/proc/track_probe_check(label, passed)
	track_probe_checks += list(list("label" = label, "passed" = !!passed))
	if (!passed)
		track_probe_failed += label

/proc/track_probe_turf(x, y)
	return locate(x, y, 1)

/proc/track_probe_lay(x, y, facing)
	return track_place_bed(track_probe_turf(x, y), facing)

/proc/track_probe_finish(x, y, facing)
	var/obj/structure/rail_bed/B = track_probe_lay(x, y, facing)
	B.place_rails()
	return B.spike()

/proc/track_probe_dirs(x, y)
	var/list/dirs = track_piece_dirs(track_piece_at(track_probe_turf(x, y)))
	var/list/names = list()
	for (var/d in cardinal)
		if (d in dirs)
			names += dir2text(d)
	return jointext(names, "+")

/proc/track_probe_run()
	// A lone tile follows the direction its layer faces.
	var/obj/structure/rail_bed/B = track_probe_lay(2, 2, EAST)
	track_probe_check("lone/east", B.dir == EAST && !B.curved)
	B = track_probe_lay(2, 6, NORTH)
	track_probe_check("lone/north", B.dir == NORTH && !B.curved)

	// A line laid northwards stays straight even when the layer faces sideways.
	track_probe_lay(5, 2, NORTH)
	track_probe_lay(5, 3, WEST)
	track_probe_lay(5, 4, EAST)
	track_probe_check("line/follows_track", track_probe_dirs(5, 3) == "north+south" && track_probe_dirs(5, 4) == "north+south")

	// Turning east: the corner sleepers bend to meet the new tile.
	track_probe_lay(5, 5, NORTH)
	track_probe_lay(6, 5, EAST)
	track_probe_check("corner/bed_bends", track_probe_dirs(5, 5) == "south+east")
	track_probe_check("corner/new_tile_straight", track_probe_dirs(6, 5) == "east+west")

	// Finished track at a loose end bends too, and stays a train turn.
	track_probe_finish(9, 2, NORTH)
	track_probe_finish(9, 3, NORTH)
	track_probe_lay(8, 3, WEST)
	var/obj/structure/rails/turn/RT = locate(/obj/structure/rails/turn) in track_probe_turf(9, 3)
	track_probe_check("finished_corner/turn", RT && track_probe_dirs(9, 3) == "south+west")
	track_probe_check("finished_corner/train_exit", RT && RT.turn_dir == WEST && OPPOSITE_DIR(RT.dir) == SOUTH)
	track_probe_check("finished_corner/straight_kept", istype(track_piece_at(track_probe_turf(9, 2)), /obj/structure/rails/regular))

	// A middle tile (two linked ends) never bends.
	track_probe_finish(12, 2, NORTH)
	track_probe_finish(12, 3, NORTH)
	track_probe_finish(12, 4, NORTH)
	track_probe_lay(13, 3, EAST)
	track_probe_check("middle/unbent", track_probe_dirs(12, 3) == "north+south")

	// A parallel line laid alongside finished track is not pulled into it.
	for (var/y in 2 to 6)
		track_probe_finish(16, y, NORTH)
	for (var/y in 2 to 6)
		track_probe_lay(17, y, NORTH)
	var/parallel = TRUE
	for (var/y in 2 to 6)
		if (track_probe_dirs(17, y) != "north+south" || track_probe_dirs(16, y) != "north+south")
			parallel = FALSE
	track_probe_check("parallel/kept_apart", parallel)

	// Filling the gap between two loose ends joins them with a curve.
	track_probe_finish(20, 2, NORTH)
	track_probe_finish(21, 3, EAST)
	track_probe_lay(20, 3, NORTH)
	track_probe_check("gap/curve", track_probe_dirs(20, 3) == "south+east")

	// A crossing of two whole lines picks the layer's axis.
	track_probe_finish(24, 2, NORTH)
	track_probe_finish(24, 4, NORTH)
	track_probe_finish(23, 3, EAST)
	track_probe_finish(25, 3, EAST)
	track_probe_lay(24, 3, EAST)
	track_probe_check("crossing/layer_axis", track_probe_dirs(24, 3) == "east+west")

	// Unfinished track is not rail: stations and trains ignore it.
	B = track_probe_lay(28, 2, NORTH)
	track_probe_check("unfinished/not_rail", !rail_at(track_probe_turf(28, 2)))
	B.place_rails()
	track_probe_check("unfinished/railed_not_rail", B.railed && !rail_at(track_probe_turf(28, 2)))
	var/serial = rail_network_serial
	var/obj/structure/rails/R = B.spike()
	track_probe_check("spiked/rail", istype(R, /obj/structure/rails/regular) && rail_at(track_probe_turf(28, 2)) && rail_network_serial > serial)

	// Taking it apart again, step by step.
	B = R.pry_apart()
	track_probe_check("pry/loose_rails", istype(B, /obj/structure/rail_bed) && B.railed && B.dir == NORTH && !rail_at(track_probe_turf(28, 2)))
	var/obj/item/stack/rail_lengths/L = B.pry()
	track_probe_check("pry/rails_back", istype(L) && L.amount == 1 && !B.railed && !QDELETED(B))
	var/obj/item/stack/rail_sleepers/S = B.pry()
	track_probe_check("pry/sleepers_back", istype(S) && S.amount == 1 && QDELETED(B) && !track_piece_at(track_probe_turf(28, 2)))
	track_probe_check("pry/tile_free", !track_lay_problem(track_probe_turf(28, 2)))

	// A curve keeps its shape through pry and re-spike.
	RT = locate(/obj/structure/rails/turn) in track_probe_turf(9, 3)
	B = RT.pry_apart()
	track_probe_check("pry/curve_kept", B && B.curved && track_probe_dirs(9, 3) == "south+west")
	R = B.spike()
	track_probe_check("respike/curve", istype(R, /obj/structure/rails/turn) && track_probe_dirs(9, 3) == "south+west")

	// Nothing comes apart under a wagon.
	R = track_probe_finish(31, 2, NORTH)
	new /obj/structure/trains(track_probe_turf(31, 2))
	track_probe_check("wagon/blocks_pry", !R.pry_apart() && !QDELETED(R))

	// Switches give their iron back.
	var/obj/structure/rails/split/switcher/SW = new(track_probe_turf(34, 2))
	var/obj/item/stack/material/iron/I = SW.pry_apart()
	track_probe_check("switch/iron", istype(I) && I.amount == 2 && QDELETED(SW))

	// The tile a switcher's split route shifts onto stays parallel to it.
	track_probe_finish(1, 10, EAST)
	track_probe_finish(3, 10, EAST)
	var/obj/structure/rails/split/switcher/SL = new(track_probe_turf(2, 10))
	SL.set_dir(EAST)
	track_probe_lay(2, 11, EAST)
	track_probe_check("switch/side_parallel", track_probe_dirs(2, 11) == "east+west" && track_probe_dirs(2, 10) == "east+west")

	// Track cannot be laid twice or on water.
	track_probe_check("lay/occupied", track_lay_problem(track_probe_turf(5, 2)))
	var/turf/W = track_probe_turf(36, 2)
	W.ChangeTurf(/turf/floor/beach/water)
	track_probe_check("lay/water", track_lay_problem(track_probe_turf(36, 2)))

/world/New()
	OpenPort("none")
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	track_probe_run()
	text2file(json_encode(list("commit" = world.params["tested_commit"], "check_count" = track_probe_checks.len, "failed_labels" = track_probe_failed, "runtime_error" = track_probe_runtime_error, "checks" = track_probe_checks)), "result.json")
	world.log << "COMPLETE track laying fixture"
	del(world)
