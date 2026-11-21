// Vehicle sheets built in a workshop (code/modules/craft/vehicle_sheet_works.dm,
// docs/vehicle-sheets.md): the automobile workshop builds car, truck and tank
// sheets, the aircraft hangar builds plane sheets and the helicopter, each
// from its stock, refusing sheets that fail their checks.
/world
	hub = ""
	hub_password = ""
	maxx = 60
	maxy = 60
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/naval_research_done = FALSE
/obj/map_metadata/naval_probe/New()
	return
/obj/map_metadata/naval_probe/is_node_done(faction, node_id)
	return naval_research_done
/mob/living/human/naval_probe/New()
	return
var/naval_failures = 0
var/naval_runtime_error = FALSE
/proc/naval_check(condition, label)
	if (!condition)
		naval_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	naval_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/works_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/T = locate(x, y, 1)
			T.ChangeTurf(/turf/floor/dirt)

// Clears the square northeast of P for the next build.
/proc/works_clear_bay(obj/structure/car_workshop/P, size)
	for (var/dx = 1, dx <= size, dx++)
		for (var/dy = 1, dy <= size, dy++)
			var/turf/T = locate(P.x + dx, P.y + dy, P.z)
			for (var/atom/movable/M in T)
				if (M.simulated)
					qdel(M)

/proc/works_fill(obj/structure/car_workshop/P)
	P.stock = list("steel" = 200, "wood" = 200, "aluminium" = 200, "glass" = 200, "cloth" = 200, "cable" = 200, "wheels" = 4)

/proc/naval_checks()
	works_fixture()
	if (!research_nodes.len)
		build_research_tree()
	var/list/examples = vehicle_draught_examples()
	var/datum/vehicle_draught/car = examples[1]
	var/datum/vehicle_draught/tank = examples[3]
	var/datum/vehicle_draught/plane = examples[4]

	// ---- The automobile workshop ----
	var/obj/structure/car_workshop/W = new(locate(5, 5, 1))
	naval_check(("car" in W.sheet_axes()) && ("heavy" in W.sheet_axes()) && !("plane" in W.sheet_axes()), "the automobile workshop builds light and heavy axis sheets")
	naval_check(W.stock_cap("steel") == 1000 && W.stock_cap("glass") == 200, "a sheet press holds enough steel for a big sheet (cap [W.stock_cap("steel")])")
	var/obj/structure/car_workshop/shipyard/yard = new(null)
	naval_check(yard.stock_cap("steel") == 400, "the shipyard office holds the carrier's 400 steel (cap [yard.stock_cap("steel")])")
	qdel(yard)
	var/list/costs = W.sheet_costs(car)
	naval_check(costs["wheels"] == 4 && costs["cable"] == 10 && costs["steel"] == car.costs()["steel"] - 4, "a car sheet costs its parts, with corner wheels from the wheel stock ([json_encode(costs)])")
	var/refusal = W.sheet_refusal(null, car)
	naval_check(findtext(refusal, "The press needs"), "an empty press says what it lacks ([refusal])")
	refusal = W.sheet_refusal(null, plane)
	naval_check(findtext(refusal, "aircraft hangar"), "a plane sheet is sent to the hangar ([refusal])")
	var/datum/vehicle_draught/broken = vehicle_draught_from_rows("broken car", "car", "gasoline", 2000, list("sWE sWT", "s.. s.C", "sW. sW."))
	refusal = W.sheet_refusal(null, broken)
	naval_check(findtext(refusal, "checks fail"), "a sheet that fails its checks is refused ([refusal])")
	works_fill(W)
	naval_check(isnull(W.sheet_refusal(null, car)), "a stocked press with a clear bay takes the car sheet")
	new /obj/item/stack/material/steel(locate(W.x + 2, W.y + 2, 1))
	naval_check(findtext(W.sheet_refusal(null, car), "clear"), "a loose item in the bay is refused")
	works_clear_bay(W, 3)
	var/steel_before = W.stock["steel"]
	var/obj/structure/vehicleparts/axis/A = W.build_sheet_vehicle(car)
	naval_check(istype(A, /obj/structure/vehicleparts/axis/car) && A.components.len && A.dir == NORTH, "the press assembles the field car facing north ([A])")
	if (istype(A))
		naval_check(A.engine && A.engine:enginesize == 2000 && A.engine.fueltank && !A.engine.fueltank.reagents.total_volume, "with its 2000cc engine and an empty tank")
		naval_check(A.wheel && A.wheels.len == 4 && A.keyed_vehicle_id, "a seat at the controls, four wheels and a key (wheels [A.wheels.len])")
		naval_check(W.stock["steel"] == steel_before - costs["steel"] && !W.stock["wheels"] && W.stock["cable"] == 190, "and spends the stock (steel [W.stock["steel"]], wheels [W.stock["wheels"]])")
		naval_check(A.y + 0 == W.y + 3 && A.x == W.x + 1, "its front left corner is the bay's north-west tile ([A.x],[A.y])")
		var/datum/vehicle_draught/drawn = vehicle_draught_survey(A)
		if (istype(drawn))
			var/list/want = splittext(car.to_code(), "/")
			var/list/got = splittext(drawn.to_code(), "/")
			naval_check(want[want.len] == got[got.len], "it is the sheet tile for tile ([got[got.len]])")
		else
			naval_check(FALSE, "its lines can be drawn ([drawn])")
	naval_check(findtext(W.sheet_refusal(null, car), "clear"), "the built car fills the bay")
	works_clear_bay(W, 5)

	works_fill(W)
	refusal = W.sheet_refusal(null, tank)
	naval_check(findtext(refusal, "research"), "a tank sheet needs mechanised war research ([refusal])")
	A = W.build_sheet_vehicle(tank)
	naval_check(istype(A, /obj/structure/vehicleparts/axis/heavy) && A.components.len, "the press assembles the light tank on a heavy axis ([A])")
	if (istype(A))
		naval_check(locate(/obj/structure/turret/built) in range(3, A), "with its turret")
	works_clear_bay(W, 5)

	// ---- The hangar ----
	var/obj/structure/car_workshop/hangar/G = new(locate(30, 5, 1))
	naval_check(G.sheet_axes() ~= list("plane"), "the hangar builds plane sheets")
	works_fill(G)
	naval_check(findtext(G.sheet_refusal(null, car), "automobile workshop"), "a car sheet is sent to the automobile workshop")
	A = G.build_sheet_vehicle(plane)
	naval_check(istype(A, /obj/structure/vehicleparts/axis/aircraft) && A.components.len, "the hangar assembles the light plane from its sheet ([A])")
	works_clear_bay(G, 7)

	works_fill(G)
	naval_check(("Helicopter" in G.models()) && G.model_size("Helicopter") == 7 && aircraft_model_node("Helicopter") == "rocketry", "the hangar offers the helicopter in a 7x7 square after Rocketry")
	var/obj/structure/vehicleparts/axis/aircraft/helicopter/huey/heli = G.complete_assembly("Helicopter")
	naval_check(istype(heli) && heli.engine && heli.engine.fueltank && !heli.engine.fueltank.reagents.total_volume && heli.keyed_vehicle_id, "the hangar builds the helicopter with an empty tank and a key")
	naval_check(G.stock["aluminium"] == 120 && !G.stock["wheels"], "and spends its stock (aluminium [G.stock["aluminium"]])")

/proc/naval_run()
	try
		naval_checks()
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = naval_failures, "runtime_error" = naval_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/naval_probe
		naval_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		naval_run()
