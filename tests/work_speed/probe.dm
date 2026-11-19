// Native probe for labour speed (code/modules/materials/work_speed.dm).
// Full production sources with ordinary startup disabled; run with
// python3 tests/ecology_spawning/run_linux.py . tests/work_speed/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 5
	maxy = 5
	maxz = 1
	turf = /turf/floor/dirt
	area = /area/caribbean/void/caves
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/work_speed_probe/New()
	return
/mob/living/human/work_speed_probe/New()
	return
/mob/living/human/work_speed_probe/update_icons()
	return

var/work_speed_failures = 0
var/work_speed_runtime_error = FALSE
/proc/work_speed_check(condition, label)
	if (!condition)
		work_speed_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	work_speed_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/work_speed_probe
		work_speed_probe_run()
	catch(var/exception/e)
		work_speed_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = work_speed_failures, "runtime_error" = work_speed_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/work_speed_human(strength = 100, stamina = 100, dexterity = 100, farming = 100)
	var/mob/living/human/work_speed_probe/H = new(locate(1, 1, 1))
	H.stats = list("strength" = list(strength, strength), "stamina" = list(stamina, stamina), "dexterity" = list(dexterity, dexterity), "farming" = list(farming, farming), "crafting" = list(100, 100))
	H.mood_modifier = 1
	H.traits = list()
	H.traits_dirty = TRUE
	return H

/proc/work_speed_probe_run()
	var/turf/T = locate(1, 1, 1)
	var/obj/item/weapon/material/shovel/iron_shovel = new(T)
	var/obj/item/weapon/material/shovel/steel/steel_shovel = new(T)
	var/obj/item/weapon/material/shovel/bone/bone_shovel = new(T)
	var/obj/item/weapon/material/pickaxe/iron_pick = new(T)
	var/obj/item/weapon/material/pickaxe/steel/steel_pick = new(T)
	var/obj/item/weapon/material/hatchet/iron_hatchet = new(T)
	var/obj/item/weapon/material/hatchet/tribal/stone_hatchet = new(T)
	var/mob/living/human/average = work_speed_human()
	var/mob/living/human/strong = work_speed_human(strength = 200, stamina = 200, dexterity = 200)
	var/mob/living/human/weak = work_speed_human(strength = 10, stamina = 10, dexterity = 10, farming = 10)

	work_speed_check(iron_shovel.usespeed == 1.5 && steel_shovel.usespeed == 2 && iron_pick.usespeed == 2 && steel_pick.usespeed == 3 && iron_hatchet.chopping_speed == 1.7, "reference tools keep their speeds")
	work_speed_check(work_delay(average, 100, WORK_DIG, iron_shovel) == 100, "an average digger with an iron shovel keeps the base wait")
	work_speed_check(work_delay(average, 120, WORK_MINE, iron_pick) == 120, "an average miner with an iron pickaxe keeps the base wait")
	work_speed_check(work_delay(average, CHOP_TREE_TIME, WORK_CHOP, iron_hatchet) == 51, "an average woodcutter with an iron hatchet keeps 30 x 1.7")
	work_speed_check(work_delay(average, 120, WORK_MINE, iron_pick) == work_delay_per_speed(average, 240, WORK_MINE, iron_pick), "per-speed waits divide by the reference tool")

	work_speed_check(work_delay(average, 100, WORK_DIG, steel_shovel) == 75, "a steel shovel digs a third faster than iron")
	work_speed_check(work_delay(average, 100, WORK_DIG, bone_shovel) == 250, "a bone shovel digs at 0.6 / 1.5 of iron")
	work_speed_check(work_delay(average, 120, WORK_MINE, steel_pick) == 80, "a steel pickaxe mines half again as fast as iron")
	work_speed_check(work_delay(average, CHOP_TREE_TIME, WORK_CHOP, stone_hatchet) > CHOP_TREE_TIME, "a stone hatchet chops slower than iron")
	work_speed_check(work_delay(average, 100, WORK_DIG, null) == 100, "no tool counts as the reference tool")

	work_speed_check(work_delay(strong, 100, WORK_DIG, iron_shovel) == 50, "doubled strength and stamina halve the dig wait")
	work_speed_check(work_delay(strong, CHOP_TREE_TIME, WORK_CHOP, iron_hatchet) < CHOP_TREE_TIME, "strength now shortens tree chopping")
	work_speed_check(work_delay(weak, 100, WORK_DIG, iron_shovel) == 200, "a very weak worker is floored at half speed")
	work_speed_check(work_delay(weak, 100, WORK_DIG, bone_shovel) == 300, "the slowest combination is capped at three times the base")
	work_speed_check(work_delay(strong, 100, WORK_MINE, /obj/item/weapon/material/pickaxe/jackhammer) == 50, "a type path is not a tool")
	var/obj/item/weapon/material/pickaxe/jackhammer/jack = new(T)
	work_speed_check(work_delay(strong, 100, WORK_MINE, jack) == 25, "the fastest combination is capped at a quarter of the base")

	var/mob/living/human/farmer = work_speed_human(farming = 200)
	work_speed_check(work_delay(farmer, 70, WORK_TILL, null) == 44, "farming weighs 0.6 of tilling speed")

	var/kind_before = trade_focus_time["miner"]
	trade_focus_time["miner"] = 0.75
	average.traits = list("Miner")
	average.traits_dirty = TRUE
	trade_traits["Miner"] = "miner"
	work_speed_check(work_delay(average, 120, WORK_MINE, iron_pick) == 90, "a matching trade shortens its own work")
	trade_traits -= "Miner"
	if (isnull(kind_before))
		trade_focus_time -= "miner"
	else
		trade_focus_time["miner"] = kind_before
