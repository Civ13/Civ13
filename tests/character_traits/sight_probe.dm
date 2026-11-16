// Native probe: Nearsighted/Farsighted traits and corrective eyewear.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/character_traits/sight_probe.dm
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
/obj/map_metadata/ps_probe/New()
	return
/mob/living/human/ps_probe/New()
	return
/mob/living/human/ps_probe/update_icons()
	return

var/ps_failures = 0
var/ps_runtime_error = FALSE
/proc/ps_check(condition, label)
	if (!condition)
		ps_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	ps_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/ps_probe
		sight_checks()
	catch(var/exception/e)
		ps_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ps_failures, "runtime_error" = ps_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/ps_human(x, y, trait = null)
	var/mob/living/human/ps_probe/H = new(locate(x, y, 1))
	H.stat = CONSCIOUS
	H.traits = trait ? list(trait) : list()
	H.traits_dirty = TRUE
	return H

/proc/sight_checks()
	var/mob/living/human/plain = ps_human(1, 1)
	ps_check(!plain.needs_sight_fog() && plain.farsight_reading_mult() == 1, "no trait: no fog, normal reading")
	ps_check(farsight_can_read(plain, plain), "no trait: pages open at once")

	var/mob/living/human/N = ps_human(2, 2, "Nearsighted")
	ps_check(N.needs_sight_fog(), "nearsighted needs fog")
	ps_check(N.farsight_reading_mult() == 1, "nearsighted reads normally")
	N.eyes = new /obj/item/clothing/glasses/sunglasses(N)
	ps_check(N.needs_sight_fog(), "sunglasses do not correct")
	N.eyes = new /obj/item/clothing/glasses/regular(N)
	ps_check(!N.needs_sight_fog(), "corrective glasses clear the fog")
	N.eyes = new /obj/item/clothing/glasses/regular/circle(N)
	ps_check(!N.needs_sight_fog(), "circle glasses correct too")
	N.eyes = new /obj/item/clothing/glasses/monocle(N)
	ps_check(!N.needs_sight_fog(), "a monocle corrects")
	N.eyes = null
	N.stat = DEAD
	ps_check(!N.needs_sight_fog(), "no fog once dead")

	var/mob/living/human/W = ps_human(3, 3)
	W.disabilities |= NEARSIGHTED
	ps_check(W.needs_sight_fog(), "welding nearsightedness also fogs")

	var/mob/living/human/F = ps_human(4, 4, "Farsighted")
	ps_check(!F.needs_sight_fog(), "farsighted sees far")
	ps_check(F.farsight_reading_mult() == 1.5, "farsighted reads 50% slower")
	F.eyes = new /obj/item/clothing/glasses/regular(F)
	ps_check(F.farsight_reading_mult() == 1 && farsight_can_read(F, F), "glasses fix farsighted reading")

	ps_check(trait_list["Nearsighted"][1] == -2 && trait_list["Farsighted"][1] == -1, "point costs")
	ps_check(get_trait_selection_error(list("Nearsighted", "Blind"), FALSE) && get_trait_selection_error(list("Blind", "Farsighted"), FALSE), "both exclude Blind")
	ps_check(!get_trait_selection_error(list("Nearsighted", "Farsighted")), "both together are allowed")
