// Native probe: carried eggs pause and resume, milking respects free space, one engine
// start owns one fuel chain, hit-embedded objects can be yanked, and a weapon's contact
// effect gets the struck zone (#6313, #6320, #6333, #6300, #6305).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/husbandry_contact/probe.dm 300
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
/obj/map_metadata/hc_probe/New()
	return

var/hc_failures = 0
var/hc_runtime_error = FALSE
/proc/hc_check(condition, label)
	if (!condition)
		hc_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	hc_runtime_error = TRUE
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
		map = new /obj/map_metadata/hc_probe
		hc_checks()
	catch(var/exception/e)
		hc_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = hc_failures, "runtime_error" = hc_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/obj/structure/engine/internal/hc_probe
	fuels = list("gasoline")
	fuelefficiency = 1
	maxpower = 100
	starting_snd_len = 5
	var/ticks = 0
/obj/structure/engine/internal/hc_probe/engine_has_air()
	return TRUE
/obj/structure/engine/internal/hc_probe/process_power_output()
	ticks++
	return 100

/obj/item/hc_contact
	var/zone_seen = "none"
/obj/item/hc_contact/on_weapon_contact(mob/living/target, mob/living/user, hit_zone = null)
	zone_seen = hit_zone

/mob/living/human/hc_target
	var/shock_zone = "none"
/mob/living/human/hc_target/electrocute_act(var/shock_damage, var/obj/source, var/base_siemens_coeff = 1.0, var/def_zone = null)
	shock_zone = def_zone
	return FALSE

/proc/hc_checks()
	var/turf/T = locate(5, 5, 1)
	var/mob/living/human/user = new(locate(4, 4, 1))

	// #6313 eggs
	var/obj/item/weapon/reagent_containers/food/snacks/egg/E = new(T)
	E.forceMove(user)
	E.growing = TRUE
	E.grow()
	sleep(50)
	hc_check(E.amount_grown == 0, "a carried egg does not develop")
	E.forceMove(T)
	sleep(100)
	hc_check(E.amount_grown >= 1, "the egg resumes developing once it is back on the ground ([E.amount_grown])")

	// #6320 milking
	var/mob/living/simple_animal/A = new /mob/living/simple_animal/cattle(locate(7, 7, 1))
	A.stat = CONSCIOUS
	var/datum/reagents/udder = new(50)
	udder.my_atom = A
	udder.add_reagent("milk", 30)
	var/obj/item/weapon/reagent_containers/glass/beaker/B = new(T)
	B.reagents.add_reagent("water", B.reagents.maximum_volume)
	A.try_milk(B, user, udder)
	hc_check(udder.get_reagent_amount("milk") == 30, "a full container leaves the udder alone ([udder.get_reagent_amount("milk")])")
	B.reagents.remove_reagent("water", 3)
	A.try_milk(B, user, udder)
	hc_check(udder.get_reagent_amount("milk") == 27 && B.reagents.get_reagent_amount("milk") == 3, "a nearly full container takes only what fits ([udder.get_reagent_amount("milk")] left)")

	// #6333 engine restart
	var/obj/structure/engine/internal/hc_probe/EN = new(locate(8, 8, 1))
	var/obj/item/weapon/reagent_containers/glass/barrel/tank = new(locate(8, 9, 1))
	tank.reagents.maximum_volume = 10000
	tank.reagents.add_reagent("gasoline", 5000)
	EN.fueltank = tank
	EN.turn_on(user)
	sleep(12)
	EN.on = FALSE
	EN.turn_on(user)
	sleep(8)
	var/before = EN.ticks
	sleep(60)
	var/rate = EN.ticks - before
	hc_check(EN.on && rate <= 7, "a restarted engine runs one fuel chain ([rate] ticks in 6 seconds)")

	// #6300 yank embedded objects
	var/mob/living/human/patient = new(locate(3, 3, 1))
	var/obj/item/organ/external/chest = patient.get_organ("chest")
	var/obj/item/weapon/material/shard/shrapnel/S = new(patient)
	S.w_class = 1
	chest.embed(S, TRUE)
	hc_check(S in patient.get_visible_implants(0), "shrapnel embedded in an organ can be yanked")
	var/obj/item/hc_contact/cavity = new(patient)
	chest.implants += cavity
	hc_check(!(cavity in patient.get_visible_implants(0)), "a surgical cavity implant stays hidden")

	// #6305 contact zone
	var/mob/living/human/hc_target/victim = new(locate(2, 2, 1))
	var/obj/item/hc_contact/C = new(user)
	victim.hit_with_weapon(C, user, 1, "chest")
	hc_check(C.zone_seen == "chest", "a weapon's contact effect gets the struck zone ([C.zone_seen])")
	var/obj/item/weapon/material/sword/magic/blade = new(user)
	blade.shocks = 100
	blade.shockpower = 1
	blade.on_weapon_contact(victim, user, "chest")
	hc_check(victim.shock_zone == "chest", "the shock lands on the struck zone ([victim.shock_zone])")
