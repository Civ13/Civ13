// Uncrewed rocket missions (code/modules/space/rocket_missions.dm,
// docs/rocket-plans.md): a rocket's payload picks its mission. A one-way
// lunar probe needs the transfer and landing legs and an idle mission console
// nearby; it lands anywhere flat, records the landing as a surveyed site a
// crewed lander can choose, and maps the Moon without ever ascending. The
// heavy cargo launch is checked through the transfer bridge in
// tests/orbit_world/probe.dm (orbit_rocket_cargo_checks).
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 30
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/rocket_missions_probe
	ordinal_age = 7
/obj/map_metadata/rocket_missions_probe/New()
	return
/obj/map_metadata/rocket_missions_probe/is_node_done(faction, node_id)
	return TRUE
/obj/map_metadata/rocket_missions_probe/book_research_enabled()
	return FALSE
var/rm_failures = 0
var/rm_runtime_error = FALSE
/proc/rm_check(condition, label)
	if (!condition)
		rm_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	rm_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/rm_rocket(datum/rocket_plan/D, turf/T)
	var/obj/structure/crewed_lander/modular_rocket/R = new(T)
	R.plan_code = D.to_code()
	for (var/key in D.stack)
		new /obj/structure/rocket_section(R, key, D.frame)
	R.refresh()
	R.propellant = R.propellant_needed
	return R

/proc/rm_checks()
	var/list/examples = rocket_plan_examples()
	var/obj/structure/crewed_lander/modular_rocket/crew = rm_rocket(examples[1], locate(3, 3, 1))
	var/obj/structure/crewed_lander/modular_rocket/hauler = rm_rocket(examples[2], locate(5, 3, 1))
	rm_check(crew.mission_kind() == "crew" && hauler.mission_kind() == "cargo", "a capsule makes a crewed flight and bays alone a cargo launch")
	rm_check(findtext(hauler.cargo_refusal(null), "launch pad"), "a cargo rocket needs a pad")
	qdel(crew)
	qdel(hauler)

	// ---- The one-way lunar probe ----
	var/obj/structure/crewed_lander/modular_rocket/R = rm_rocket(examples[3], locate(10, 10, 1))
	rm_check(R.mission_kind() == "probe", "a probe and no capsule makes a probe mission")
	rm_check(findtext(R.probe_refusal(), "launch pad"), "the probe needs a pad")
	new /obj/structure/region_gate/trail_marker/launch_pad(locate(11, 10, 1))
	rm_check(findtext(R.probe_refusal(), "mission console"), "and an idle mission console nearby ([R.probe_refusal()])")
	var/obj/structure/survey_console/far = new(locate(25, 25, 1))
	rm_check(findtext(R.probe_refusal(), "mission console"), "a console far away does not count")
	var/obj/structure/survey_console/C = new(locate(10, 14, 1))
	R.propellant = 0
	rm_check(findtext(R.probe_refusal(), "propellant"), "it needs its propellant")
	R.propellant = R.propellant_needed
	rm_check(!R.probe_refusal(), "a lunar probe rocket is ready ([R.probe_refusal()])")

	// A probe that only reaches orbit is told what it lacks.
	var/datum/rocket_plan/small = rocket_plan_make("Small probe", "s", 0, "ETTDVTQ")
	var/obj/structure/crewed_lander/modular_rocket/low = rm_rocket(small, locate(12, 11, 1))
	rm_check(findtext(low.probe_refusal(), "lunar transfer"), "an orbit-only probe names the missing lunar transfer ([low.probe_refusal()])")
	qdel(low)

	var/turf/stand_turf = get_turf(R)
	rm_check(isnull(R.launch_probe()), "the probe flies")
	rm_check(QDELETED(R), "the rocket is spent")
	var/left = 0
	for (var/obj/structure/rocket_section/S in world)
		if (!QDELETED(S))
			left++
	rm_check(!left, "with every section ([left] left; no first stage flies back in 1969)")
	rm_check(C.mission && C.one_way && C.map_region == "moon" && !far.mission, "the nearest console flies a one-way Moon mission")
	var/site = "[C.land_x],[C.land_y]"
	rm_check(site in C.landing_sites_for("moon"), "the landing is recorded as a surveyed site ([site])")
	rm_check(findtext(C.ascend(), "no ascent stage") && C.mission, "the probe never ascends")
	rm_check(findtext(C.take_sample(), "full"), "and carries no samples home")
	var/obj/structure/crewed_lander/lander = new(locate(12, 12, 1))
	var/list/sites = lander.surveyed_sites("moon")
	rm_check(("Surveyed site [site]" in sites), "a crewed lander nearby can choose the site ([json_encode(sites)])")
	C.abandon()
	rm_check(!C.mission && !C.one_way, "abandoning ends the one-way mission")
	rm_check(site in C.landing_sites_for("moon"), "and the site stays on the record")
	rm_check(stand_turf, "the stand's tile stays")

/proc/rm_run()
	try
		rm_checks()
	catch(var/exception/e)
		rm_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = rm_failures, "runtime_error" = rm_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/rocket_missions_probe
	catch(var/exception/e)
		rm_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		rm_run()
