// Building a rocket (code/modules/space/rocket_works.dm, docs/rocket-plans.md):
// the rocket works builds a sheet's sections from its stock, in order and
// in the sheet's frame; the launch stand mounts them in order, refuses the
// wrong section, mounts upper storeys only from the level above (where a
// crane would set them) and raises the rocket's body there; the finished
// rocket takes the sheet's propellant and seats, carries the launch planner,
// flies only to orbit, and takes its storeys and sections with it.
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 3
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/rocket_works_probe
	ordinal_age = 7
/obj/map_metadata/rocket_works_probe/New()
	return
/obj/map_metadata/rocket_works_probe/is_node_done(faction, node_id)
	return TRUE
/obj/map_metadata/rocket_works_probe/book_research_enabled()
	return FALSE
var/rw_failures = 0
var/rw_runtime_error = FALSE
/proc/rw_check(condition, label)
	if (!condition)
		rw_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	rw_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/rw_checks()
	if (!research_nodes.len)
		build_research_tree()
	// The column over the stand is open sky on both levels above.
	new /turf/sky/building(locate(10, 10, 2))
	new /turf/sky/building(locate(10, 10, 3))
	var/obj/structure/region_gate/trail_marker/launch_pad/pad = new(locate(11, 10, 1))
	var/obj/structure/rocket_stand/stand = new(locate(10, 10, 1))
	rw_check(stand.find_pad() == pad, "the stand finds the pad beside it")

	rw_check(get_recipe_node_req("/obj/structure/rocket_works") == "orbital_flight" && get_recipe_node_req("/obj/structure/rocket_stand") == "orbital_flight", "the works and the stand are Orbital Flight recipes")
	rw_check(findtext(file2text("config/crafting/material_recipes_global.txt"), ",two-stage rocket,") == 0, "the fixed two-stage rocket is no longer a recipe")
	rw_check(/obj/structure/rocket_section in hoist_only_types, "sections need a hoist between levels")

	var/datum/rocket_plan/D = rocket_plan_examples()[1]
	var/code = D.to_code()

	// ---- The works ----
	var/obj/structure/rocket_works/W = new(locate(5, 5, 1))
	W.order_code = code
	rw_check(!W.build_next(null), "an empty works builds nothing")
	for (var/key in rocket_works_stock_types())
		W.stock[key] = 400
	var/list/sections = list()
	for (var/i in 1 to D.stack.len)
		var/obj/structure/rocket_section/S = W.build_next(null)
		if (!S)
			break
		sections += S
		S.forceMove(locate(1, 1, 1)) // out of the way
	rw_check(sections.len == D.stack.len && W.built == D.stack.len, "the works builds every piece of the sheet ([sections.len]/[D.stack.len])")
	rw_check(!W.build_next(null), "and then stops")
	var/list/costs = D.costs()
	rw_check(W.stock["aluminium"] == 400 - costs["aluminium"] && W.stock["electronics"] == 400 - costs["electronics"], "it spends what the sheet costs ([json_encode(W.stock)] for [json_encode(costs)])")
	var/obj/structure/rocket_section/tank = sections[2]
	rw_check(tank.piece == "T" && tank.frame == "a" && tank.name == "aluminium propellant tank", "a tank comes out in the sheet's frame ([tank.name])")
	var/obj/structure/rocket_section/engine = sections[1]
	rw_check(engine.piece == "E" && !engine.frame, "an engine has no frame")

	// ---- The stand ----
	var/turf/beside = locate(9, 10, 1)
	rw_check(findtext(stand.mount_refusal(null, engine), "rocket sheet"), "a stand with no sheet mounts nothing")
	stand.plan_code = code
	tank.forceMove(beside)
	rw_check(findtext(stand.mount_refusal(null, tank), "sea-level engine"), "the wrong section is refused and the right one named")
	engine.forceMove(locate(1, 1, 1))
	rw_check(findtext(stand.mount_refusal(null, engine), "beside"), "a section far from the stand is refused")
	var/obj/structure/rocket_section/steel_engine = new(beside, "E")
	steel_engine.condition = 10
	rw_check(findtext(stand.mount_refusal(null, steel_engine), "too worn"), "a worn section is refused")
	qdel(steel_engine)
	var/mounted = 0
	for (var/i in 1 to D.stack.len)
		var/obj/structure/rocket_section/S = sections[i]
		var/storey = rocket_storey_of(D, i)
		var/turf/column = stand.storey_turf(storey)
		if (storey > 1)
			// Left on the ground, an upper storey's section is refused.
			S.forceMove(beside)
			if (!stand.mount_refusal(null, S))
				rw_check(FALSE, "section [i] on storey [storey] mounts from the ground")
			S.forceMove(locate(column.x - 1, column.y, column.z))
		else
			S.forceMove(beside)
		if (stand.mount(null, S))
			mounted++
		else
			rw_check(FALSE, "section [i] mounts: [stand.mount_refusal(null, S)]")
	rw_check(mounted == D.stack.len, "every section mounts in order across three storeys")
	rw_check(stand.storey_turf(2).z == 2 && stand.storey_turf(3).z == 3, "storeys 2 and 3 mount from the levels above")
	rw_check(locate(/obj/structure/rocket_storey) in locate(10, 10, 2), "the rocket rises through the level above")
	rw_check(locate(/obj/structure/rocket_storey) in locate(10, 10, 3), "and the one above that")
	var/obj/structure/crewed_lander/modular_rocket/R = stand.rocket()
	rw_check(R && R.complete(), "the stack is a finished rocket on the stand's tile")
	rw_check(R.propellant_needed == D.propellant_units() && R.seats == 3, "it takes the sheet's propellant ([R.propellant_needed]) and seats three")
	rw_check(findtext(R.planner_text(), "Come home from orbit: yes"), "its launch planner shows the legs")
	rw_check(findtext(R.vehicle_refusal("nowhere"), "flies to orbit"), "it flies only to orbit")
	rw_check(R.find_pad() == pad, "it stands beside the pad")

	// Taking the top section down and putting it back.
	var/obj/structure/rocket_section/top = stand.take_down(null)
	rw_check(top && top.z == 3 && !R.complete(), "the top section comes down onto the platform of its storey")
	rw_check(stand.mount(null, top) && R.complete(), "and goes back up")

	// The rocket leaves with its storeys and sections.
	qdel(R)
	rw_check(!(locate(/obj/structure/rocket_storey) in locate(10, 10, 2)) && !(locate(/obj/structure/rocket_storey) in locate(10, 10, 3)), "a launched rocket takes its storeys with it")
	var/left = 0
	for (var/obj/structure/rocket_section/S in world)
		if (!QDELETED(S))
			left++
	rw_check(!left, "and its sections ([left] left)")

	// With no level above, every storey mounts from the ground.
	var/obj/structure/rocket_stand/low = new(locate(15, 15, 3))
	rw_check(low.storey_turf(3) == locate(15, 15, 3), "on the top level every storey mounts from the stand's own level")

/proc/rw_run()
	try
		rw_checks()
	catch(var/exception/e)
		rw_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = rw_failures, "runtime_error" = rw_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/rocket_works_probe
	catch(var/exception/e)
		rw_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		rw_run()
