// Native probe for mercury roasting, the retort and the burden.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/mercury/probe.dm
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
/obj/map_metadata/mercury_probe/New()
	return
/mob/living/human/mercury_probe/New()
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
		initialize_chemical_reagents()
		initialize_chemical_reactions()
		map = new /obj/map_metadata/mercury_probe
		map.ordinal_age = 3
		mercury_probe_checks()
	catch(var/exception/e)
		eco_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = eco_failures, "runtime_error" = eco_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/mercury_probe_checks()
	var/turf/T = locate(5, 5, 1)
	var/mob/living/human/mercury_probe/A = new(T)
	var/mob/living/human/mercury_probe/B = new(locate(6, 5, 1))
	var/mob/living/human/mercury_probe/C = new(locate(15, 15, 1))
	eco_check(A.mercury_burden == 0 && A.mercury_stage == 0, "a fresh body carries no burden")
	var/area/AR = get_area(T)
	AR.location = AREA_INSIDE
	var/hit = mercury_vapour(T, 10, "a probe")
	eco_check(hit == 2, "vapour reaches the two people within 2 tiles, not the far one ([hit])")
	eco_check(A.mercury_burden == 10 && C.mercury_burden == 0, "indoors a person breathes the whole release")
	B.mercury_burden = 0
	B.wear_mask = new /obj/item/clothing/mask/gas(B)
	mercury_vapour(T, 10, "a probe")
	eco_check(abs(B.mercury_burden - 1) < 0.001, "a gas mask lets a tenth through ([B.mercury_burden])")
	AR.location = AREA_OUTSIDE
	A.mercury_burden = 0
	mercury_vapour(T, 10, "a probe")
	eco_check(A.mercury_burden == 5, "under the open sky half the vapour reaches anyone")
	A.mercury_burden = 45
	A.handle_mercury_burden()
	eco_check(A.mercury_stage == 2 && A.mercury_told, "45 burden is the tremor stage and names its cause")
	A.mercury_burden = 101 // one tick of drain comes first
	A.handle_mercury_burden()
	// The fixture body has no organs, so brain damage itself is not measured here.
	eco_check(A.mercury_stage == 4, "over 100 burden is the deadly stage")
	A.mercury_burden = 0.04
	A.handle_mercury_burden()
	eco_check(A.mercury_burden == 0 && A.mercury_stage == 0, "a trace drains to nothing")
	var/obj/item/weapon/doctor_handbook/HB = new(T)
	A.mercury_burden = 75
	A.handle_mercury_burden()
	var/list/lines = HB.diagnose_poisons(A)
	eco_check(lines.len && findtext(lines[lines.len], "Mercury poisoning, heavy"), "the handbook names heavy mercury poisoning")
	var/list/ill = A.illness_summary()
	eco_check(ill && ill["type"] == "mercury" && ill["severe"], "admin Check Illnesses lists it")
	// The retort and the flask.
	var/obj/structure/workshop_machine/mercury_retort/R = new(locate(10, 10, 1))
	eco_check(R.reagents && R.reagents.maximum_volume == 60 && R.icon_state == "retort", "a retort holds 60 units")
	var/obj/item/weapon/reagent_containers/glass/mercury_flask/F = new(T)
	F.reagents.add_reagent("mercury", 10)
	eco_check(F.icon_state == "flask_full", "a filled flask shows it")
	R.seal = 20
	R.update_icon()
	eco_check(R.icon_state == "retort_cracked", "a worn seal shows cracked")
	// Cinnabar from mining.
	var/found = 0
	for (var/i in 1 to 2000)
		found += T.mining_cinnabar(null) ? 1 : 0
	for (var/obj/item/stack/ore/mercury/M in T)
		qdel(M)
	eco_check(found > 5 && found < 50, "cinnabar turns up in about 1% of mining ([found]/2000)")
	map.cinnabar_rich = TRUE
	var/rich = 0
	for (var/i in 1 to 2000)
		rich += T.mining_cinnabar(null) ? 1 : 0
	eco_check(rich > found, "a mercury belt gives more ([rich] vs [found])")
	map.ordinal_age = 0
	eco_check(!T.mining_cinnabar(null), "no cinnabar in the Stone Age")
