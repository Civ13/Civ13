// Native probe: manual biofuel feed respects the shared feed capacity.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/biofuel_feed/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 5
	maxy = 5
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/mob/living/human/biofuel_probe/New()
	return
/mob/living/human/biofuel_probe/update_icons()
	return
var/bf_failures = 0
var/bf_runtime_error = FALSE
/proc/bf_check(condition, label)
	if (!condition)
		bf_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	bf_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/proc/bf_barrel(H, id, amount)
	var/obj/item/weapon/reagent_containers/glass/barrel/B = new(H)
	B.reagents.add_reagent(id, amount)
	return B
/proc/bf_refinery(et, di)
	var/obj/structure/refinery/biofuel/R = new(locate(2, 2, 1))
	R.barrel += new /obj/item/weapon/reagent_containers/glass/barrel(R)
	R.volume_et = et
	R.volume_di = di
	return R
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		bf_check(!world.port, "fixture has no listening port")
		var/mob/living/human/biofuel_probe/H = new(locate(2, 3, 1))
		var/obj/structure/refinery/biofuel/R = bf_refinery(290, 0)
		var/obj/item/weapon/reagent_containers/glass/barrel/oil = bf_barrel(H, "olive_oil", 20)
		R.attackby(oil, H)
		bf_check(R.volume_et == 290 && R.volume_di == 10 && oil.reagents.get_reagent_amount("olive_oil") == 10, "olive oil only fills the shared free space")
		R = bf_refinery(290, 0)
		var/obj/item/weapon/reagent_containers/glass/barrel/fat = bf_barrel(H, "fat_oil", 20)
		R.attackby(fat, H)
		bf_check(R.volume_et == 290 && R.volume_di == 10 && fat.reagents.get_reagent_amount("fat_oil") == 10, "fat oil only fills the shared free space")
		R = bf_refinery(0, 290)
		var/obj/item/weapon/reagent_containers/glass/barrel/eth = bf_barrel(H, "ethanol", 20)
		var/yield = 1
		for (var/datum/reagent/ethanol/E in eth.reagents.reagent_list)
			E.strength = 40 // a drinkable spirit, so the purity yield is 0.6
			yield = 1 - (E.strength / 100)
		R.attackby(eth, H)
		bf_check(R.volume_di == 290 && abs(R.volume_et - 10) < 0.01 && abs(eth.reagents.get_reagent_amount("ethanol") - (20 - 10 / yield)) < 0.01, "ethanol keeps stored oil and pours only what fits")
		R = bf_refinery(0, 0)
		var/obj/item/weapon/reagent_containers/glass/barrel/plain = bf_barrel(H, "ethanol", 20)
		R.attackby(plain, H)
		bf_check(R.volume_et == 0 && plain.reagents.get_reagent_amount("ethanol") == 20, "ethanol with no purity yield is refused, not drained")
		R = bf_refinery(0, 0)
		oil = bf_barrel(H, "olive_oil", 20)
		R.attackby(oil, H)
		bf_check(R.volume_di == 20 && oil.reagents.get_reagent_amount("olive_oil") == 0, "an empty refinery takes a whole small barrel")
		R = bf_refinery(150, 150)
		oil = bf_barrel(H, "olive_oil", 20)
		R.attackby(oil, H)
		bf_check(R.volume_di == 150 && oil.reagents.get_reagent_amount("olive_oil") == 20, "a full refinery takes nothing")
	catch(var/exception/e)
		bf_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = bf_failures, "runtime_error" = bf_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
