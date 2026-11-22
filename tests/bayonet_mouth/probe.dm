// Native probe: mounted bayonet mouth guard (#6742).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/bayonet_mouth/probe.dm
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
/obj/map_metadata/bm_probe/New()
	return

var/bm_failures = 0
var/bm_runtime_error = FALSE
/proc/bm_check(condition, label)
	if (!condition)
		bm_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	bm_runtime_error = TRUE
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
		map = new /obj/map_metadata/bm_probe
		bm_checks()
	catch(var/exception/e)
		bm_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = bm_failures, "runtime_error" = bm_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)


/proc/bm_checks()
	var/obj/item/weapon/gun/G = new(locate(1, 1, 1))
	var/mob/living/human/bare = new(locate(2, 2, 1))
	bm_check(isnull(G.bayonet_mouth_guard(bare)), "an uncovered mouth takes the normal roll")
	var/mob/living/human/gassed = new(locate(3, 2, 1))
	var/obj/item/clothing/mask/gas/M = new(gassed)
	gassed.equip_to_slot_or_del(M, slot_wear_mask)
	bm_check(gassed.wear_mask == M, "the gas mask is worn")
	bm_check(isnull(G.bayonet_mouth_guard(gassed)), "an ordinary mask takes the normal roll")
	var/mob/living/human/stoned = new(locate(4, 2, 1))
	var/obj/item/clothing/mask/stone/S = new(stoned)
	stoned.equip_to_slot_or_del(S, slot_wear_mask)
	bm_check(stoned.wear_mask == S, "the stone mask is worn")
	bm_check(G.bayonet_mouth_guard(stoned) == S, "a hard mask turns the bayonet")
