// Rocket reuse (code/modules/space/rocket_reuse.dm, docs/rocket-plans.md):
// reuse belongs to each section. A returned section needs inspecting before
// it mounts; steel, an overhaul kit or cloth restore it. A crew capsule with
// a heat shield and parachutes carries its record to orbit and home again,
// and where it comes down sets its wear. From 2013 landing legs on the first
// stage fly it back, at the cost of the propellant it keeps to land.
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 40
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/rocket_reuse_probe
	ordinal_age = 7
/obj/map_metadata/rocket_reuse_probe/New()
	return
/obj/map_metadata/rocket_reuse_probe/is_node_done(faction, node_id)
	return TRUE
/obj/map_metadata/rocket_reuse_probe/book_research_enabled()
	return FALSE
var/ru_failures = 0
var/ru_runtime_error = FALSE
/proc/ru_check(condition, label)
	if (!condition)
		ru_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	ru_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/ru_count(type, turf/T)
	. = 0
	for (var/atom/A in T)
		if (istype(A, type))
			.++

/proc/ru_checks()
	if (!research_nodes.len)
		build_research_tree()
	ru_check(get_recipe_node_req("/obj/item/engine_overhaul_kit") == "orbital_flight", "the overhaul kit is an Orbital Flight recipe")

	// ---- Inspection and repair ----
	var/datum/rocket_plan/orbiter = rocket_plan_examples()[1]
	var/obj/structure/rocket_section/engine = rocket_section_returned(locate(4, 5, 1), "E", null, 30, 2, 20)
	ru_check(engine.condition == 10 && engine.flights == 3 && !engine.inspected, "a returned section is worn, counts its flight and needs inspecting")
	ru_check(findtext(engine.mount_refusal(), "too worn"), "the stand refuses it")
	var/obj/item/engine_overhaul_kit/kit = new(locate(1, 1, 1))
	var/obj/structure/rocket_section/tank = new(locate(1, 1, 1), "T", "a")
	tank.condition = 50
	ru_check(tank.engine() == FALSE && engine.engine(), "only engines take an overhaul kit")
	engine.condition = 100
	engine.inspected = FALSE
	ru_check(findtext(engine.mount_refusal(), "nspect"), "an uninspected engine is refused even at full condition ([engine.mount_refusal()])")
	ru_check(engine.inspect(null) && engine.inspected, "inspecting clears it")
	ru_check(!engine.mount_refusal(), "and it mounts ([engine.mount_refusal()])")
	qdel(kit)

	// ---- The capsule's record ----
	var/obj/structure/crewed_lander/modular_rocket/R = new(locate(20, 20, 1))
	R.plan_code = orbiter.to_code()
	for (var/key in orbiter.stack)
		var/obj/structure/rocket_section/S = new(R, key, orbiter.frame)
		if (key == "C")
			S.condition = 90
			S.flights = 1
	R.refresh()
	var/list/record = R.capsule_record()
	ru_check(islist(record) && record["x"] == "X" && record["r"] == 1 && record["l"] == 0 && record["c"] == 90 && record["f"] == 1, "a capsule with a heat shield and parachutes carries its record ([json_encode(record)])")
	ru_check(rocket_capsule_record_ok(record) && rocket_capsule_can_return(record), "the record is well formed and can come home")
	var/list/flight = list()
	R.flight_extras(flight)
	ru_check(flight["capsule"] ~= record, "the flight to orbit carries it")
	ru_check(space_flight_payload_ok(list("lander" = "probe-1", "orbit" = 1, "capsule" = record)), "a flight to orbit with a record is a valid payload")
	ru_check(space_flight_payload_ok(list("lander" = "probe-1", "return" = 1, "capsule" = record)), "so is the flight home")
	ru_check(!space_flight_payload_ok(list("lander" = "probe-1", "landing" = list(5, 5), "surveyed" = 0, "rough" = 0, "capsule" = record)), "a lunar landing carries no record")
	var/list/bad = record.Copy()
	bad["c"] = 500
	ru_check(!space_flight_payload_ok(list("lander" = "probe-1", "orbit" = 1, "capsule" = bad)) && !rocket_capsule_record_ok(list("c" = 1)), "a malformed record is refused")
	ru_check(!space_flight_payload_ok(list("capsule" = record)), "a record without a flight is refused")

	// ---- In orbit ----
	var/obj/structure/landed_lander/capsule/C = new(locate(30, 30, 1))
	ru_check(C.can_lift_off(), "a plain capsule always comes home")
	C.recovery = record
	ru_check(C.can_lift_off(), "so does one with a shield and parachutes")
	var/list/home = list("lander" = "probe-1", "return" = 1)
	C.flight_home_extras(home)
	ru_check(home["capsule"] ~= record, "the flight home carries the record")
	var/list/no_chutes = record.Copy()
	no_chutes["r"] = 0
	C.recovery = no_chutes
	ru_check(!C.can_lift_off() && findtext(C.deorbit_refusal(null), "parachutes"), "without parachutes the capsule cannot come home")

	// ---- Coming down ----
	// Water east of x = 30: parachutes alone splash down by the shore.
	for (var/x in 31 to 40)
		for (var/y in 1 to 15)
			new /turf/floor/beach/water(locate(x, y, 1))
	var/turf/home_turf = locate(25, 8, 1)
	var/obj/structure/rocket_section/back = rocket_capsule_recover(list("lander" = "flight-a", "return" = 1, "capsule" = record), home_turf)
	ru_check(back && back.piece == "C" && back.condition == 75 && back.flights == 2 && !back.inspected, "a splashdown capsule comes back towed in, worn 15 ([back ? back.condition : "none"])")
	var/turf/at = get_turf(back)
	ru_check(at && at.x == 30, "on the shore ([at ? "[at.x],[at.y]" : "nowhere"])")
	ru_check(ru_count(/obj/structure/rocket_section, at) == 2, "with its parachutes to repack")
	ru_check(!rocket_capsule_recover(list("lander" = "flight-a", "return" = 1, "capsule" = record), home_turf), "each crew member's arrival brings it down only once")
	var/list/soft = record.Copy()
	soft["l"] = 1
	soft["lc"] = 80
	var/turf/inland = locate(10, 30, 1)
	var/obj/structure/rocket_section/landed = rocket_capsule_recover(list("lander" = "flight-b", "return" = 1, "capsule" = soft), inland)
	ru_check(landed && landed.condition == 80 && get_dist(landed, inland) <= 7, "landing rockets set it down softly on dry ground ([landed ? landed.condition : "none"])")
	var/obj/structure/rocket_section/hard = rocket_capsule_recover(list("lander" = "flight-c", "return" = 1, "capsule" = record), inland)
	ru_check(hard && hard.condition == 50, "parachutes alone far from water come down hard ([hard ? hard.condition : "none"])")

	// ---- Repairs ----
	var/obj/structure/rocket_section/chutes = null
	for (var/obj/structure/rocket_section/S in get_turf(hard))
		if (S.piece == "R")
			chutes = S
	ru_check(chutes && chutes.condition == 0, "the parachutes come back needing a repack")

	// ---- Flying back ----
	var/datum/rocket_plan/legs = rocket_plan_make("Flyback", "a", 4, "EETTTTGDVTTTKK")
	var/datum/rocket_plan/plain = rocket_plan_make("Plain", "a", 4, "EETTTTDVTTTKK")
	ru_check(!legs.first_stage_recovers(), "in 1969 landing legs fly no first stage back")
	map.ordinal_age = ROCKET_FLYBACK_AGE
	ru_check(legs.first_stage_recovers() && !plain.first_stage_recovers(), "from 2013 landing legs on the first stage fly it back")
	var/dv_legs = legs.total_dv(0)
	var/dv_plain = plain.total_dv(0)
	ru_check(dv_legs < dv_plain, "keeping propellant to land costs delta-v ([rocket_dv_text(dv_legs)] against [rocket_dv_text(dv_plain)])")
	var/list/errs = legs.problems()
	ru_check(!length(errs), "the checks allow legs on a recoverable first stage ([json_encode(errs)])")
	var/obj/structure/crewed_lander/modular_rocket/F = new(locate(20, 25, 1))
	F.plan_code = legs.to_code()
	for (var/key in legs.stack)
		new /obj/structure/rocket_section(F, key, legs.frame)
	F.refresh()
	var/list/recs = F.flyback_records()
	ru_check(recs.len == 8, "the first stage's seven sections and its decoupler fly back ([recs.len])")
	map.ordinal_age = 7

/proc/ru_run()
	try
		ru_checks()
	catch(var/exception/e)
		ru_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ru_failures, "runtime_error" = ru_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/rocket_reuse_probe
	catch(var/exception/e)
		ru_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		ru_run()
