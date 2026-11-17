// Native probe: crabs, trilobites and beetles drop chitin; crushed shell burns to quicklime.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/chitin_uses/probe.dm
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
/obj/map_metadata/cu_probe/New()
	return
/mob/living/human/cu_probe/New()
	return
/mob/living/human/cu_probe/update_icons()
	return
/mob/living/simple_animal/cattle/cow/cu_probe/New()
	return

var/cu_failures = 0
var/cu_runtime_error = FALSE
/proc/cu_check(condition, label)
	if (!condition)
		cu_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	cu_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/cu_probe
		cu_drop_checks()
		cu_kiln_checks()
		cu_item_checks()
	catch(var/exception/e)
		cu_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = cu_failures, "runtime_error" = cu_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/cu_chitin(turf/T)
	var/n = 0
	for (var/obj/item/stack/material/chitin/C in T)
		n += C.amount
	return n

/proc/cu_clear(turf/T)
	for (var/atom/movable/A in T)
		qdel(A)

/proc/cu_butcher(path, turf/T, bonus = 0)
	var/mob/living/simple_animal/S = new path(T)
	S.harvest_bonus = bonus
	S.harvest_products(T, FALSE)
	S.harvest_bonus = 0
	S.loc = null
	var/n = cu_chitin(T)
	cu_clear(T)
	return n

/proc/cu_drop_checks()
	var/turf/T = locate(3, 3, 1)
	cu_check(cu_butcher(/mob/living/simple_animal/crab/small, T) == 1, "a small crab gives one chitin")
	cu_check(cu_butcher(/mob/living/simple_animal/crab, T) == 2, "a full-grown crab gives two chitin")
	cu_check(cu_butcher(/mob/living/simple_animal/crab/small/trilobite, T) == 2, "a trilobite gives two chitin")
	cu_check(cu_butcher(/mob/living/simple_animal/hostile/phosphor_beetle, T) == 1, "a phosphor beetle gives one chitin")
	cu_check(cu_butcher(/mob/living/simple_animal/cattle/cow/cu_probe, T) == 0, "a cow gives no chitin")
	cu_check(cu_butcher(/mob/living/simple_animal/crab, T, 1) == 4, "a master hunter doubles crab chitin")
	var/mob/living/simple_animal/crab/C = new(T)
	C.harvest_products(T, FALSE)
	C.loc = null
	var/meat = 0
	for (var/obj/item/weapon/reagent_containers/food/snacks/rawcrab/R in T)
		meat++
	cu_check(meat > 0, "a crab still gives crab meat ([meat])")
	cu_clear(T)

/proc/cu_kiln_checks()
	var/turf/T = locate(6, 6, 1)
	var/obj/structure/furnace/lime_kiln/K = new(T)
	var/mob/living/human/cu_probe/H = new(locate(6, 5, 1))
	H.a_intent = I_HELP
	var/obj/item/stack/crushed_shell/S = new(H.loc, 5)
	K.attackby(S, H)
	cu_check(K.shell_charge == 5, "the kiln takes crushed shell as its charge ([K.shell_charge])")
	cu_check(K.charge() == 5, "crushed shell counts toward the kiln limit")
	K.empty()
	var/back = 0
	for (var/obj/item/stack/crushed_shell/R in T)
		back += R.amount
		qdel(R)
	cu_check(back == 5 && K.shell_charge == 0, "emptying the kiln returns the crushed shell ([back])")
	K.shell_charge = 3
	K.stone_charge = 2
	K.process()
	var/lime = 0
	for (var/obj/item/stack/ore/quicklime/Q in T)
		lime += Q.amount
	cu_check(lime == 5, "burnt shell and stone give one quicklime each ([lime])")
	cu_check(K.charge() == 0, "the burnt charge is spent")

/proc/cu_item_checks()
	var/turf/T = locate(9, 9, 1)
	var/obj/item/stack/crushed_shell/S = new(T)
	cu_check(S.fertilizer_value > 0, "crushed shell fertilises soil")
	var/obj/item/weapon/material/harpoon/chitin/P = new(T)
	cu_check(P.name == "chitin harpoon", "the chitin harpoon is named for its material ([P.name])")
	cu_check(spear_fishing_tool(P), "the chitin harpoon spear-fishes")
	cu_check("harpoon_chitin" in icon_states(P.icon), "the chitin harpoon sprite exists")
	var/obj/item/stack/barter_beads/chitin/B = new(T)
	cu_check(B.icon_state in icon_states(B.icon), "the chitin beads sprite exists")
	cu_check(S.icon_state in icon_states(S.icon), "the crushed shell sprite exists")
