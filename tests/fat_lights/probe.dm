// Native probe for animal fat as light fuel: partial use of a piece, burn
// times, the grease horn, the stone fat lamp and fat by species
// (code/modules/1713/light_fuel.dm, fat_lights.dm, animal_harvest.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/fat_lights/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 8
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/fl_probe/New()
	return
/mob/living/human/fl_fixture/New()
	return
/mob/living/human/fl_fixture/update_icons()
	return
/mob/living/simple_animal/cattle/cow/fl_probe/New()
	return
/mob/living/simple_animal/hostile/wolf/fl_probe/New()
	return
/mob/living/simple_animal/hostile/mammoth/fl_probe/New()
	return
/mob/living/simple_animal/hostile/bear/fl_probe/New()
	return
/mob/living/simple_animal/pig_gilt/fl_probe/New()
	return
/mob/living/simple_animal/sheep/fl_probe/New()
	return
/mob/living/simple_animal/chicken/fl_probe/New()
	return
var/fl_failures = 0
var/fl_runtime_error = FALSE
/proc/fl_check(condition, label)
	if (!condition)
		fl_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	fl_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/fl_probe
		fl_checks()
	catch(var/exception/e)
		fl_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = fl_failures, "runtime_error" = fl_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/fl_fat(turf/T)
	return new /obj/item/weapon/reagent_containers/food/snacks/animalfat(T)

/proc/fl_lard(obj/item/I)
	return (I && !QDELETED(I) && I.reagents) ? I.reagents.get_reagent_amount("lard") : 0

/proc/fl_pieces(path, turf/T)
	var/mob/living/simple_animal/S = new path(T)
	. = S.harvest_fat_pieces(min(8, max(1, S.butcher_yield())))
	S.loc = null

/proc/fl_checks()
	var/turf/T = locate(3, 3, 1)
	var/mob/living/human/fl_fixture/U = new(locate(3, 4, 1))

	// A torch: ten minutes from a whole piece, twenty at most, and only what it needs.
	var/obj/item/flashlight/torch/torch = new(T)
	fl_check(torch.fuel == 600 && torch.max_fuel == 1200, "a new torch burns ten minutes and holds twenty")
	torch.fuel = 0
	var/obj/item/F = fl_fat(T)
	torch.attackby(F, U)
	fl_check(torch.fuel == 600 && QDELETED(F), "a whole piece of fat gives a torch ten minutes and is used up")
	torch.fuel = 900
	F = fl_fat(T)
	torch.attackby(F, U)
	fl_check(torch.fuel == 1200 && !QDELETED(F) && fl_lard(F) == 5, "a torch with room for five minutes takes half a piece ([fl_lard(F)] lard left)")
	torch.attackby(F, U)
	fl_check(torch.fuel == 1200 && fl_lard(F) == 5, "a full torch takes none")
	torch.fuel = 1000
	torch.attackby(F, U)
	fl_check(torch.fuel == 1200 && !QDELETED(F), "the part-used piece tops it up and the rest is kept")
	torch.fuel = 0
	torch.attackby(F, U)
	fl_check(torch.fuel > 0 && torch.fuel < 200 && QDELETED(F), "the last of a piece is used up and gone")

	// Rendered oil is worth as much as the fat it came from: five units a piece.
	var/obj/item/weapon/reagent_containers/glass/grease_horn/horn = new(T)
	fl_check(horn.volume == 30 && (horn.slot_flags & SLOT_BELT) && horn.icon_state == "grease_horn_open", "the grease horn holds thirty units and hangs from a belt")
	horn.reagents.add_reagent("fat_oil", 5)
	torch.fuel = 0
	torch.attackby(horn, U)
	fl_check(torch.fuel == 600 && horn.reagents.total_volume < 0.1, "five units of rendered oil give a torch the same ten minutes")

	// Fat pressed into the horn is carried as lard and refuels lights from it.
	F = fl_fat(T)
	horn.attackby(F, U)
	fl_check(QDELETED(F) && horn.reagents.get_reagent_amount("lard") == 10, "a piece of fat presses into the horn as ten units")
	torch.fuel = 900
	torch.attackby(horn, U)
	fl_check(torch.fuel == 1200 && horn.reagents.get_reagent_amount("lard") == 5, "the horn tops a torch up with only what it needs")
	horn.reagents.clear_reagents()

	// Tiki torch and lantern.
	var/obj/item/flashlight/tiki_torch/tiki = new(T)
	tiki.fuel = 0
	F = fl_fat(T)
	tiki.attackby(F, U)
	fl_check(tiki.fuel == 600 && QDELETED(F), "a piece of fat gives a tiki torch ten minutes")
	var/obj/item/flashlight/lantern/lantern = new(T)
	lantern.fuel = 0
	horn.reagents.add_reagent("fat_oil", 5)
	lantern.attackby(horn, U)
	fl_check(lantern.fuel == 1200, "a rendered piece of fat gives a lantern twenty minutes")
	horn.reagents.clear_reagents()

	// The stone fat lamp: dim, half an hour a piece, an hour when full.
	var/obj/item/flashlight/lantern/fat_lamp/lamp = new(T)
	fl_check(!lamp.on && lamp.fuel == 0 && lamp.brightness_on == CANDLE_LUM && lamp.brightness_on < torch.brightness_on, "an empty fat lamp is unlit and dimmer than a torch")
	fl_check(lamp.icon_state == "fat_lamp", "unlit it shows its unlit sprite")
	lamp.attack_self(U)
	fl_check(!lamp.on, "it does not light without fat")
	F = fl_fat(T)
	lamp.attackby(F, U)
	fl_check(lamp.fuel == 1800 && QDELETED(F), "a piece of fat burns half an hour in the lamp")
	F = fl_fat(T)
	lamp.attackby(F, U)
	fl_check(lamp.fuel == 3600 && QDELETED(F), "two pieces fill it for an hour")
	F = fl_fat(T)
	lamp.attackby(F, U)
	fl_check(lamp.fuel == 3600 && fl_lard(F) == 10, "a full lamp leaves the next piece whole")
	lamp.on = TRUE
	lamp.update_icon()
	fl_check(lamp.icon_state == "fat_lamp-on" && lamp.is_open_flame(), "lit it shows its flame and is an open flame")
	for (var/state in list("grease_horn", "grease_horn_open", "fat_lamp", "fat_lamp-on"))
		fl_check(state in icon_states('icons/obj/fat_lights.dmi'), "sprite [state] exists")

	// A part-used piece says so.
	fl_check(fl_lard(F) == 10, "a fresh piece of fat holds ten units of lard")

	// Fat by species.
	fl_check(fl_pieces(/mob/living/simple_animal/hostile/wolf/fl_probe, T) == 1, "a wolf is lean: one piece")
	fl_check(fl_pieces(/mob/living/simple_animal/sheep/fl_probe, T) == 2, "a sheep gives two")
	fl_check(fl_pieces(/mob/living/simple_animal/cattle/cow/fl_probe, T) == 3, "a cow gives three")
	fl_check(fl_pieces(/mob/living/simple_animal/pig_gilt/fl_probe, T) == 3, "a pig gives three")
	fl_check(fl_pieces(/mob/living/simple_animal/hostile/bear/fl_probe, T) == 4, "a bear gives four")
	fl_check(fl_pieces(/mob/living/simple_animal/hostile/mammoth/fl_probe, T) == 8, "a mammoth gives eight")
	var/mob/living/simple_animal/cattle/cow/fl_probe/calf = new(T)
	calf.mob_size = MOB_SMALL
	fl_check(calf.harvest_fat_pieces(min(8, max(1, calf.butcher_yield()))) == 0, "a calf gives none")
	calf.loc = null
	var/mob/living/simple_animal/chicken/fl_probe/hen = new(T)
	hen.has_fat = FALSE
	fl_check(hen.harvest_fat_pieces(3) == 0, "an animal without fat gives none")
	hen.loc = null
