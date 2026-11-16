// Native probe for the mercury crafts.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/mercury_crafts/probe.dm
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
/obj/map_metadata/mercury_crafts_probe/New()
	return
/mob/living/human/mercury_crafts_probe/New()
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
		map = new /obj/map_metadata/mercury_crafts_probe
		map.ordinal_age = 3
		mercury_crafts_probe_checks()
	catch(var/exception/e)
		eco_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = eco_failures, "runtime_error" = eco_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/mercury_crafts_probe_flask(units)
	var/obj/item/weapon/reagent_containers/glass/mercury_flask/F = new(locate(1, 1, 1))
	F.reagents.add_reagent("mercury", units)
	return F

/proc/mercury_crafts_probe_checks()
	var/turf/T = locate(5, 5, 1)
	var/mob/living/human/mercury_crafts_probe/A = new(locate(5, 6, 1))
	var/obj/item/weapon/reagent_containers/glass/mercury_flask/F = mercury_crafts_probe_flask(20)

	// The mirror
	var/obj/structure/mirror/unsilvered/U = new(T)
	U.pixel_y = 32
	U.attackby(F, A)
	eco_check(!QDELETED(U) && F.reagents.get_reagent_amount("mercury") == 20, "a bare mirror needs tin before quicksilver")
	var/obj/item/stack/material/tin/Tin = new(locate(1, 1, 1))
	Tin.amount = 3
	U.attackby(Tin, A)
	eco_check(U.tinned && Tin.amount == 2, "a sheet of tin goes on the back")
	A.mercury_burden = 0
	U.attackby(F, A)
	var/obj/structure/mirror/M = locate(/obj/structure/mirror) in T
	eco_check(QDELETED(U) && M && M.type == /obj/structure/mirror && M.pixel_y == 32, "five units of quicksilver silver it in place")
	eco_check(F.reagents.get_reagent_amount("mercury") == 15 && A.mercury_burden == (signal_fire_open_sky(T) ? 0.5 : 1), "silvering uses 5u and the silverer breathes 1 ([A.mercury_burden])")
	eco_check(M.item_type == /obj/item/mirror && initial(U.item_type) == /obj/item/mirror/unsilvered, "a bare mirror comes down bare, a silvered one silvered")

	// The instruments
	var/obj/item/weapon/barometer/empty/B = new(locate(1, 1, 1))
	B.attackby(F, A)
	eco_check(B.filled && F.reagents.get_reagent_amount("mercury") == 10, "the barometer takes 5u")
	var/obj/item/weapon/thermometer/empty/Th = new(locate(1, 1, 1))
	Th.attackby(F, A)
	eco_check(Th.filled && Th.icon_state == "thermometer" && F.reagents.get_reagent_amount("mercury") == 8, "the thermometer takes 2u")
	eco_check(findtext(thermometer_reading(A), "degrees"), "the thermometer reads the air: [thermometer_reading(A)]")
	eco_check(findtext(barometer_reading(A), "column"), "the barometer reads as a column")

	// Gilding
	var/obj/item/weapon/material/hatchet/Iron = new(locate(1, 1, 1), "iron")
	var/obj/item/weapon/material/hatchet/Bronze = new(locate(1, 1, 1), "bronze")
	eco_check(fire_gilding_refusal(Iron) && !fire_gilding_refusal(Bronze), "gold amalgam takes on bronze, not iron")
	var/value = Bronze.value
	eco_check(Bronze.fire_gild() && Bronze.plating == "gold" && findtext(Bronze.name, "gilded") == 1 && Bronze.value > value, "a gilt piece is gold-coated and worth more")
	eco_check(fire_gilding_refusal(Bronze), "a piece is gilt only once")
	var/obj/item/stack/ore/amalgam/gold/G = new(locate(1, 1, 1))
	var/obj/item/stack/ore/amalgam/silver/S = new(locate(1, 1, 1))
	eco_check(G.gilds() && !S.gilds(), "only gold amalgam gilds")

	// Felt
	eco_check(felt_hat_types.len == 3, "three felt hats")
	for (var/name in felt_hat_types)
		var/path = felt_hat_types[name]
		var/obj/item/clothing/head/H = new path(locate(1, 1, 1))
		eco_check(H.rain_resist == 30 && H.item_icons[slot_head_str] == 'icons/mob/mercury_crafts.dmi', "[name] keeps the rain off and is worn from its own sheet")

	// Dimercaprol
	var/datum/reagent/dimercaprol/D = new
	A.mercury_burden = 40
	D.affect_blood(A, 0, 5)
	eco_check(A.mercury_burden == 10, "a 5u dose draws out 30 burden")
	var/obj/item/weapon/reagent_containers/glass/beaker/K = new(locate(1, 1, 1))
	map.ordinal_age = 6
	K.reagents.add_reagent("glycerol", 2)
	K.reagents.add_reagent("bromine", 2)
	K.reagents.add_reagent("sodium_sulfide", 2)
	K.reagents.process_reactions()
	eco_check(K.reagents.get_reagent_amount("dimercaprol") == 0, "nobody can make it before Modern Medicine")
	map.ordinal_age = 7
	K.reagents.process_reactions()
	eco_check(K.reagents.get_reagent_amount("dimercaprol") == 4, "glycerol, bromine and sodium sulphide make dimercaprol ([json_encode(K.reagents.reagent_list.len)] [K.reagents.get_reagent_amount("glycerol")] [K.reagents.get_reagent_amount("bromine")] [K.reagents.get_reagent_amount("sodium_sulfide")] [K.reagents.get_reagent_amount("dimercaprol")] [K.flags])")
