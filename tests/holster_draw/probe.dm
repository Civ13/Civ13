// Native probe: a gun is drawn only into a hand (issue 6961).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/holster_draw/probe.dm
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
/obj/map_metadata/hd_probe/New()
	return

var/hd_failures = 0
var/hd_runtime_error = FALSE
/proc/hd_check(condition, label)
	if (!condition)
		hd_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	hd_runtime_error = TRUE
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
		map = new /obj/map_metadata/hd_probe
		hd_checks()
	catch(var/exception/e)
		hd_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = hd_failures, "runtime_error" = hd_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/hd_checks()
	var/mob/living/human/H = new(locate(4, 4, 1))
	var/obj/item/clothing/accessory/holster/S = new(H)
	var/obj/item/weapon/pen/G = new(S)
	S.holstered = G
	H.lying = TRUE
	S.unholster(H)
	hd_check(S.holstered == G && G.loc == S, "lying down, the gun stays in the holster")
	hd_check(!(locate(/obj/item/weapon/pen) in get_turf(H)), "lying down, nothing drops at the player's feet")
	H.lying = FALSE
	S.unholster(H)
	hd_check(!S.holstered && (H.l_hand == G || H.r_hand == G), "standing, the gun is drawn into a hand")
	var/obj/item/clothing/accessory/holster/D = new(H)
	D.capacity = 2
	var/obj/item/weapon/pen/G1 = new(D)
	var/obj/item/weapon/pen/G2 = new(D)
	D.holstered = G1
	D.holstered2 = G2
	H.drop_from_inventory(G)
	qdel(G)
	H.lying = TRUE
	D.unholster(H)
	hd_check(D.holstered2 == G2 && G2.loc == D, "a double holster also keeps its gun when the draw fails")
