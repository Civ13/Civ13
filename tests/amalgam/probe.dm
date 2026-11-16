// Native probe for amalgamation and river bed mercury.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/amalgam/probe.dm
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
/obj/map_metadata/amalgam_probe/New()
	return
/mob/living/human/amalgam_probe/New()
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
		map = new /obj/map_metadata/amalgam_probe
		map.ordinal_age = 1
		amalgam_probe_checks()
	catch(var/exception/e)
		eco_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = eco_failures, "runtime_error" = eco_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/amalgam_probe_checks()
	var/datum/river_flood/F = new
	F.count = 4
	F.down = list(2, 3, 4, 0)
	F.deposit_mercury(1, 10)
	eco_check(abs(F.bed_mercury[1] - 6) < 0.001 && abs(F.bed_mercury[2] - 2.5) < 0.001 && abs(F.bed_mercury[3] - 1.5) < 0.001 && F.bed_mercury[4] == 0, "a spill settles 60/25/15 down three reaches")
	F.deposit_mercury(4, 10)
	eco_check(abs(F.bed_mercury[4] - 10) < 0.001, "the last reach keeps what cannot go further")
	for (var/i in 1 to 60)
		F.step_bed_mercury()
	eco_check(abs(F.bed_mercury[1] - 5.94) < 0.01, "the bed loses about 1% an hour ([F.bed_mercury[1]])")
	var/obj/structure/workshop_machine/mercury_retort/R = new(locate(5, 5, 1))
	var/obj/item/stack/ore/amalgam/gold/A = new(locate(2, 2, 1))
	A.amount = 4
	R.load_amalgam(A, null)
	var/obj/item/stack/ore/mercury/C = new(locate(2, 2, 1))
	C.amount = 2
	R.load_cinnabar(C, null)
	eco_check(R.retort_charge() == 6 && QDELETED(A), "the retort takes amalgam beside cinnabar ([R.retort_charge()])")
	var/units = R.retort_empty(null)
	var/obj/item/stack/ore/gold/sponge/S = locate() in get_turf(R)
	eco_check(abs(units - (12 + 7.2)) < 0.01 && S && S.amount == 4 && R.retort_charge() == 0, "firing returns 90% of the amalgam's quicksilver and leaves sponge gold ([units])")
	var/obj/structure/patio_heap/P = new(locate(10, 10, 1))
	P.loads = 20
	P.copper = 1
	P.reagents.add_reagent("mercury", 20)
	P.reagents.add_reagent("sodiumchloride", 10)
	eco_check(P.charged(), "a full patio is charged")
	P.finish(null)
	var/obj/item/stack/ore/amalgam/silver/SA = locate() in get_turf(P)
	var/obj/item/stack/ore/tailings/amalgam/AT = locate() in get_turf(P)
	eco_check(SA && SA.amount == 7 && AT && AT.amount == 20 && !P.charged() && P.loads == 0, "the patio gives 7 silver amalgam and 20 tailings")
	var/obj/structure/stone_crusher/K = new(locate(14, 14, 1))
	eco_check(K.reagents && K.water_capacity == 20 && K.arrastra_mercury() == 0, "the crusher has a trough for quicksilver and water")
	K.reagents.add_reagent("mercury", 5)
	K.arrastra_update_overlay()
	eco_check(K.overlays.len == 1, "a charged crusher shows its quicksilver")
	eco_check(amalgam_type_for(/obj/item/stack/ore/silver) == /obj/item/stack/ore/amalgam/silver && amalgam_type_for(/obj/item/stack/ore/gold) == /obj/item/stack/ore/amalgam/gold, "crushed ore gives amalgam of its own metal")
	var/obj/item/weapon/reagent_containers/food/snacks/rawfish/fish = new(locate(3, 3, 1))
	eco_check(!fish.mercury_taint, "fish start clean")
