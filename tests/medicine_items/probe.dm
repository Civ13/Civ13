// Native probe: pills only dissolve when the whole dose fits (#4226), and a
// syringe injection stops when the patient moves out of reach (#4227).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/medicine_items/probe.dm
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
/obj/map_metadata/mi_probe/New()
	return

var/mi_failures = 0
var/mi_runtime_error = FALSE
/proc/mi_check(condition, label)
	if (!condition)
		mi_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	mi_runtime_error = TRUE
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
		map = new /obj/map_metadata/mi_probe
		mi_pill_checks()
		mi_syringe_checks()
	catch(var/exception/e)
		mi_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = mi_failures, "runtime_error" = mi_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/mi_pill(turf/T)
	var/obj/item/weapon/reagent_containers/pill/P = new(T)
	P.reagents.clear_reagents()
	P.reagents.add_reagent("anti_toxin", 25)
	return P

/proc/mi_beaker(turf/T, fill)
	var/obj/item/weapon/reagent_containers/glass/beaker/B = new(T)
	B.reagents.add_reagent("water", fill)
	return B

/proc/mi_pill_checks()
	var/turf/T = locate(2, 2, 1)
	var/mob/living/human/user = new(T)
	var/obj/item/weapon/reagent_containers/glass/beaker/full = mi_beaker(T, 0)
	full.reagents.add_reagent("water", full.reagents.maximum_volume)
	var/obj/item/weapon/reagent_containers/pill/P = mi_pill(T)
	P.afterattack(full, user, TRUE)
	mi_check(!QDELETED(P) && P.reagents.get_reagent_amount("anti_toxin") == 25, "a full container leaves the pill and its dose intact")
	var/obj/item/weapon/reagent_containers/glass/beaker/nearly = mi_beaker(T, 0)
	nearly.reagents.add_reagent("water", nearly.reagents.maximum_volume - 10)
	P.afterattack(nearly, user, TRUE)
	mi_check(!QDELETED(P) && P.reagents.get_reagent_amount("anti_toxin") == 25 && !nearly.reagents.get_reagent_amount("anti_toxin"), "a container without room for the whole dose is refused")
	var/obj/item/weapon/reagent_containers/glass/beaker/roomy = mi_beaker(T, 5)
	P.afterattack(roomy, user, TRUE)
	mi_check(QDELETED(P) && roomy.reagents.get_reagent_amount("anti_toxin") == 25, "a container with room takes the whole dose")

/proc/mi_syringe_checks()
	var/mob/living/human/user = new(locate(5, 5, 1))
	var/mob/living/human/patient = new(locate(6, 5, 1))
	var/obj/item/weapon/reagent_containers/syringe/S = new(user)
	S.reagents.add_reagent("anti_toxin", 5)
	S.mode = SYRINGE_INJECT
	user.targeted_organ = "chest"
	spawn(0)
		S.afterattack(patient, user, TRUE)
	sleep(2)
	patient.forceMove(locate(10, 10, 1))
	sleep(S.time + 10)
	mi_check(!patient.reagents.get_reagent_amount("anti_toxin") && S.reagents.get_reagent_amount("anti_toxin") == 5, "a patient who moves away is not injected")
	patient.forceMove(locate(6, 5, 1))
	spawn(0)
		S.afterattack(patient, user, TRUE)
	sleep(S.time + 10)
	mi_check(S.reagents.get_reagent_amount("anti_toxin") < 5, "a patient who stays is injected")
