// Full-source probe: wide portcullises (portcullis_runs.dm). Sections in a
// line join into one grid with ends and middles; a winch works the whole run it
// reaches; wider runs wind slower and a helper halves the time; destroying a
// section re-ends its neighbours.
/world
	hub = ""
	visibility = 0
	maxx = 16
	maxy = 16
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/portcullis_runs_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/portcullis_runs_probe/New()
	map = src

/turf/floor/plating/portcullis_runs_probe

var/portcullis_runs_probe_checks = 0
var/portcullis_runs_runtime = null

/world/Error(exception/e)
	if (!portcullis_runs_runtime)
		portcullis_runs_runtime = "runtime [e] ([e.file]:[e.line])"

/proc/portcullis_runs_assert(ok, label)
	portcullis_runs_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/portcullis_runs_actor(tx, ty, name)
	var/mob/living/human/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.real_name = name
	H.name = name
	H.hand = 0
	H.a_intent = I_HELP
	return H

// A door between two solid tiles north and south: people pass east-west.
/proc/portcullis_runs_probe_run()
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
	map = new /obj/map_metadata/portcullis_runs_probe

	var/list/row = list()
	for (var/x in 3 to 7)
		row += new /obj/structure/castle_gate/portcullis(locate(x, 4, 1))
	var/list/column = list()
	for (var/y in 9 to 11)
		column += new /obj/structure/castle_gate/portcullis(locate(12, y, 1))
	var/obj/structure/castle_gate/portcullis/single = new(locate(14, 14, 1))
	sleep(5)

	var/obj/structure/castle_gate/portcullis/W = row[1]
	var/obj/structure/castle_gate/portcullis/C = row[3]
	var/obj/structure/castle_gate/portcullis/E = row[5]
	portcullis_runs_assert(W.icon_state == "portcullis_closed_w" && C.icon_state == "portcullis_closed_c" && E.icon_state == "portcullis_closed_e", "row_joins")
	var/obj/structure/castle_gate/portcullis/N = column[3]
	var/obj/structure/castle_gate/portcullis/M = column[2]
	var/obj/structure/castle_gate/portcullis/S = column[1]
	portcullis_runs_assert(N.icon_state == "portcullis_closed_n" && M.icon_state == "portcullis_closed_m" && S.icon_state == "portcullis_closed_s", "column_joins")
	portcullis_runs_assert(single.icon_state == "portcullis_closed", "single_unchanged")
	portcullis_runs_assert(W.portcullis_run().len == 5 && M.portcullis_run().len == 3, "runs")

	// A winch beside one end reaches the whole run.
	var/obj/structure/castle_winch/winch = new(locate(2, 3, 1))
	var/list/G = winch.gates()
	portcullis_runs_assert(G.len == 5, "winch_reaches_whole_run")
	var/mob/living/human/H = new(locate(1, 3, 1))
	portcullis_runs_assert(winch.wind_time(G, TRUE, H) == 100, "wide_winds_slower")
	var/mob/living/human/helper = new(locate(2, 2, 1))
	helper.stat = CONSCIOUS
	portcullis_runs_assert(winch.wind_time(G, TRUE, H) == 50, "helper_halves")
	portcullis_runs_assert(winch.wind_time(G, FALSE, H) == 15, "dropping_quick")
	winch.work(TRUE)
	var/all_open = TRUE
	for (var/obj/structure/castle_gate/portcullis/P in row)
		if (!P.open || P.density)
			all_open = FALSE
	portcullis_runs_assert(all_open && C.icon_state == "portcullis_open_c", "whole_run_raised")
	portcullis_runs_assert(!N.open, "other_run_untouched")
	winch.work(FALSE)
	portcullis_runs_assert(!C.open && C.density, "whole_run_dropped")

	// Smashing the middle section leaves two shorter runs with proper ends.
	qdel(C)
	sleep(5)
	var/obj/structure/castle_gate/portcullis/B = row[2]
	var/obj/structure/castle_gate/portcullis/D = row[4]
	portcullis_runs_assert(B.icon_state == "portcullis_closed_e" && D.icon_state == "portcullis_closed_w", "rejoined_after_loss")

/world/New()
	OpenPort("none")
	var/error = null
	try
		portcullis_runs_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	if (!error && portcullis_runs_runtime)
		error = portcullis_runs_runtime
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = portcullis_runs_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
