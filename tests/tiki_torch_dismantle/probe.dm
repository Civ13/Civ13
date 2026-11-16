// Native probe for taking tiki torches apart.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/tiki_torch_dismantle/probe.dm 300
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/tiki_probe/New()
	return
var/eco_failures = 0
var/eco_runtime_error = FALSE
/proc/eco_check(condition, label)
	if (!condition)
		eco_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	eco_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/tiki_probe
		tiki_dismantle_checks()
	catch(var/exception/e)
		eco_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = eco_failures, "runtime_error" = eco_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/tiki_probe_count(turf/T, path)
	. = 0
	for (var/obj/item/stack/S in T)
		if (S.type == path)
			. += S.amount

/proc/tiki_probe_clear(turf/T)
	for (var/obj/O in T)
		qdel(O)

/proc/tiki_dismantle_checks()
	var/turf/T = locate(5, 5, 1)
	// Tools: hammers and blades take it apart, a bare handle does not.
	eco_check(tiki_torch_dismantle_tool(new /obj/item/weapon/hammer(T)), "a hammer takes a tiki torch apart")
	eco_check(tiki_torch_dismantle_tool(new /obj/item/weapon/material/kitchen/utensil/knife(T)), "a knife takes a tiki torch apart")
	eco_check(tiki_torch_dismantle_tool(new /obj/item/weapon/material/hatchet(T)), "a hatchet takes a tiki torch apart")
	eco_check(!tiki_torch_dismantle_tool(new /obj/item/weapon/material/handle(T)), "a bare handle does not")
	eco_check(!tiki_torch_dismantle_tool(null), "nothing does not")
	tiki_probe_clear(T)

	// A burnt-out wooden torch leaves a wooden handle and two logs.
	var/obj/item/flashlight/tiki_torch/wood = new(T)
	wood.fuel = 0
	eco_check(wood.frame_material == "wood", "tiki torches default to a wooden pole")
	var/obj/item/weapon/material/handle/H = wood.take_apart_tiki_torch()
	eco_check(istype(H) && H.loc == T, "a wooden tiki torch leaves a handle on its tile")
	eco_check(H && H.material && H.material.name == "wood", "the handle is wooden")
	eco_check(tiki_probe_count(T, /obj/item/stack/material/wood) == 2, "a wooden tiki torch leaves two logs")
	qdel(wood)
	tiki_probe_clear(T)

	// A bamboo torch returns bamboo, not logs.
	var/obj/item/flashlight/tiki_torch/bamboo = new(T)
	bamboo.frame_material = "bamboo"
	H = bamboo.take_apart_tiki_torch()
	eco_check(H && H.material && H.material.name == "bamboo", "a bamboo tiki torch leaves a bamboo handle")
	eco_check(tiki_probe_count(T, /obj/item/stack/material/bamboo) == 2, "a bamboo tiki torch leaves two bamboo bundles")
	eco_check(tiki_probe_count(T, /obj/item/stack/material/wood) == 0, "and no logs")
	qdel(bamboo)
	tiki_probe_clear(T)

	// An unknown material falls back to wood rather than losing the refund.
	var/obj/item/flashlight/tiki_torch/odd = new(T)
	odd.frame_material = "no_such_material"
	H = odd.take_apart_tiki_torch()
	eco_check(H && H.material && H.material.name == "wood", "an unknown pole material falls back to wood")
	eco_check(tiki_probe_count(T, /obj/item/stack/material/wood) == 2, "with two logs")
	qdel(odd)
	tiki_probe_clear(T)

	// Lit torches and mapped fixtures refuse before any wait.
	var/obj/item/flashlight/tiki_torch/lit = new(T)
	lit.on = TRUE
	eco_check(!lit.dismantle_tiki_torch(null) && !QDELETED(lit), "a lit tiki torch is not taken apart")
	var/obj/item/flashlight/tiki_torch/on/anchor/fixture = new(T)
	fixture.on = FALSE
	eco_check(!fixture.dismantle_tiki_torch(null) && !QDELETED(fixture), "a mapped unlimited tiki torch is not taken apart")
