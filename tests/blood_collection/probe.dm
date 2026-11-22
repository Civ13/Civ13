// Native probe: collecting blood never tops up another donor's blood, which
// would relabel it with the new donor's type (#6239).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/blood_collection/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/bc_probe/New()
	return

var/bc_failures = 0
var/bc_runtime_error = FALSE
/proc/bc_check(condition, label)
	if (!condition)
		bc_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	bc_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.name_set_event = new /decl/observ/name_set
		GLOB.stat_set_event = new /decl/observ/stat_set
		makeDatumRefLists()
		movementMachine = new
		map = new /obj/map_metadata/bc_probe
		bc_collection_checks()
	catch(var/exception/e)
		bc_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = bc_failures, "runtime_error" = bc_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/bc_collect(mob/living/human/donor, obj/item/weapon/reagent_containers/glass/beaker/B, amount)
	// Mirrors the IV drip's collection step.
	var/datum/reagent/R = donor.take_blood(B, amount)
	if (R)
		B.reagents.reagent_list |= R
		B.reagents.update_total()
	return R

/proc/bc_collection_checks()
	var/mob/living/human/alpha = new(locate(5, 5, 1))
	var/mob/living/human/beta = new(locate(6, 5, 1))
	alpha.dna.b_type = "A+"
	beta.dna.b_type = "O-"
	var/obj/item/weapon/reagent_containers/glass/beaker/B = new(locate(5, 6, 1))
	bc_check(bc_collect(alpha, B, 10), "the first donor's blood is collected into an empty container")
	var/datum/reagent/blood/held = locate() in B.reagents.reagent_list
	bc_check(held && held.data["donor"] == alpha && held.data["blood_type"] == "A+" && held.volume == 10, "the container holds 10 units of the first donor's type")
	var/beta_before = beta.vessel.get_reagent_amount("blood")
	bc_check(!bc_collect(beta, B, 4), "a second donor's blood is refused")
	held = locate() in B.reagents.reagent_list
	bc_check(held.data["donor"] == alpha && held.data["blood_type"] == "A+" && held.volume == 10, "the held blood keeps its donor, type and volume")
	bc_check(beta.vessel.get_reagent_amount("blood") == beta_before, "the refused donor loses no blood")
	bc_check(bc_collect(alpha, B, 4) && held.volume == 14, "the same donor can keep filling the container")
