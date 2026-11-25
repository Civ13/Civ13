// Native virtual weapon loading probe.
// python3 tests/ecology_spawning/run_linux.py . tests/gun_chamber/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 4
	maxz = 1
	fps = 20
	turf = /turf/floor/dirt
	area = /area
	visibility = 0

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/obj/map_metadata/loading_fixture/New()
	return

var/loading_failures = 0
var/loading_runtime_error = FALSE

/world/Error(exception/e)
	loading_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/loading_check(condition, label)
	if (!condition)
		loading_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"

/proc/loading_hold(mob/living/human/H, obj/item/I)
	H.drop_from_inventory(H.get_active_hand())
	H.put_in_active_hand(I)

/world/New()
	OpenPort("none")
	try
		generate_gameid()
		if (config)
			config.webhook_can_fire = FALSE
			config.ToRban = FALSE
		GLOB.all_observable_events = list()
		GLOB.moved_event = new /decl/observ/moved
		GLOB.dir_set_event = new /decl/observ/dir_set
		GLOB.name_set_event = new /decl/observ/name_set
		GLOB.stat_set_event = new /decl/observ/stat_set
		makeDatumRefLists()
		map = new /obj/map_metadata/loading_fixture
		map.ID = MAP_NOMADS_CONTINENTAL
		map.persistence = TRUE
		season = "SUMMER"
		var/mob/living/human/H = new(locate(2, 2, 1))
		check_virtual_loading(H)
	catch (var/exception/e)
		loading_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = loading_failures, "runtime_error" = loading_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/check_virtual_loading(mob/living/human/H)
	var/turf/T = get_turf(H)
	var/obj/item/weapon/gun/projectile/revolver/derringer/D = new(T)
	H.put_in_inactive_hand(D)
	D.recentpump = world.time - 10
	D.attack_self(H)
	var/obj/item/ammo_casing/a41/first = new(T)
	loading_hold(H, first)
	D.load_ammo(first, H)
	sleep(2)
	var/obj/item/ammo_casing/a41/second = new(T)
	qdel(second.BB)
	second.BB = null
	loading_hold(H, second)
	D.load_ammo(second, H)
	D.recentpump = world.time - 10
	D.attack_self(H)
	loading_check(!D.open && D.chambered == second && D.loaded.len == 1 && D.loaded[1] == first, "closing the in-game Derringer feeds the first list entry")
	D.recentpump = world.time - 10
	D.attack_self(H)
	loading_check(D.open && !D.chambered && D.loaded.len == 2 && D.loaded[1] == second && D.loaded[2] == first, "reopening exposes both live and spent entries in their original order")
	var/obj/item/ammo_casing/a41/extra = new(T)
	loading_hold(H, extra)
	sleep(2)
	D.load_ammo(extra, H)
	loading_check(H.get_active_hand() == extra && D.loaded.len == 2, "both reopened entries count against capacity")
	H.drop_from_inventory(extra)
	D.attack_hand(H)
	loading_check(H.get_active_hand() == first, "the usual inactive-hand unload action retrieves the live entry")
	H.drop_from_inventory(first)
	D.attack_hand(H)
	loading_check(H.get_active_hand() == second && !D.loaded.len, "the usual unload action also retrieves the formerly trapped spent entry")
	H.drop_from_inventory(second)
	H.drop_from_inventory(D)
	qdel(D)
	qdel(first)
	qdel(second)
	qdel(extra)

	var/obj/item/weapon/gun/projectile/revolver/R = new(T)
	H.put_in_inactive_hand(R)
	var/obj/item/ammo_casing/a45/existing = new(R)
	R.loaded += existing
	R.chamber_offset = 2
	var/obj/item/ammo_casing/a41/wrong = new(T)
	loading_hold(H, wrong)
	R.load_ammo(wrong, H)
	loading_check(R.chamber_offset == 2 && R.loaded.len == 1 && H.get_active_hand() == wrong, "rejected virtual ammunition leaves the revolver position unchanged")
	loading_check(!R.consume_next_projectile() && R.chamber_offset == 1 && R.loaded[1] == existing, "the next in-game chamber stays empty")
	var/obj/item/ammo_casing/a45/accepted = new(T)
	loading_hold(H, accepted)
	R.chamber_offset = 2
	R.load_delay = 20
	spawn(2)
		H.stat = UNCONSCIOUS
	R.load_ammo(accepted, H)
	H.stat = CONSCIOUS
	loading_check(R.chamber_offset == 2 && R.loaded.len == 1 && H.get_active_hand() == accepted, "an interrupted wait does not change the virtual chamber position or move the round")
	R.load_delay = 0
	R.load_ammo(accepted, H)
	loading_check(R.chamber_offset == 0 && R.loaded.len == 2 && accepted.loc == R, "a successful loose transfer resets the virtual chamber position")
	var/obj/item/ammo_magazine/c45/loader = new(T)
	R.good_mags |= loader.type
	loading_hold(H, loader)
	R.chamber_offset = 2
	sleep(2)
	var/before = loader.stored_ammo.len
	R.load_ammo(loader, H)
	loading_check(R.chamber_offset == 0 && R.loaded.len > 2 && loader.stored_ammo.len < before, "a successful speedloader transfer also resets the virtual chamber position")
	R.chamber_offset = 2
	sleep(2)
	R.load_ammo(loader, H)
	loading_check(R.chamber_offset == 2 && R.loaded.len == R.max_shells, "a speedloader cannot change the position of an already full cylinder")
	H.drop_from_inventory(loader)
	H.drop_from_inventory(R)
	qdel(loader)
	qdel(R)
	qdel(wrong)
