// Native probe for cascading building collapse (code/game/objects/building_collapse.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/building_collapse/probe.dm 300
/world
	hub = ""
	hub_password = ""
	maxx = 16
	maxy = 12
	maxz = 3
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/building_collapse_probe/New()
	return
var/bc_failures = 0
var/bc_runtime_error = FALSE
/proc/bc_check(condition, label)
	if (!condition)
		bc_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	bc_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	sleep(1)
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		map = new /obj/map_metadata/building_collapse_probe
		map_storage.record_compiled_dimensions()
		for (var/turf/T in world)
			if (T.z > 1)
				new /turf/sky/building(T)
		Master.start_timer_loop()
		bc_checks()
	catch(var/exception/e)
		bc_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = bc_failures, "runtime_error" = bc_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/bc_wait_for_queue(limit = 200)
	for (var/i in 1 to limit)
		if (!building_collapse_pending())
			return TRUE
		sleep(1)
	return FALSE

/proc/bc_checks()
	// A one-storey room: a pillar holds a roof, and a wall and a crate stand on
	// the floor above it.
	var/turf/site = locate(4, 4, 1)
	var/obj/structure/roof_support/P = new /obj/structure/roof_support(site)
	var/obj/roof/R = building_construct_roof(site, /obj/roof/wood, null)
	bc_check(R && R.building_floor(), "a supported roof gets a floor above")
	var/obj/covers/F = R.building_floor()
	var/turf/upper = get_turf(F)
	var/obj/covers/wood_wall/W = new /obj/covers/wood_wall(upper)
	var/obj/item/stack/material/wood/crate = new /obj/item/stack/material/wood(upper)
	sleep(50)
	bc_check(!QDELETED(R) && !building_collapse_pending(), "a supported roof stays up and leaves no work queued")

	// Knock the pillar out: the roof creaks, then falls, and the floor and
	// what stood on it come down a level.
	P.structure_impact(1000)
	bc_check(QDELETED(P), "the impact breaks the pillar")
	sleep(35)
	bc_check(!QDELETED(R), "the roof creaks before it falls")
	bc_wait_for_queue()
	bc_check(QDELETED(R) && QDELETED(F), "then the roof and its floor fall")
	bc_check(QDELETED(W), "the wall that stood on the floor falls too")
	bc_check(crate.z == 1, "loose items on the floor drop a level (z [crate.z])")
	var/obj/structure/rubble/RB = locate() in site
	bc_check(RB && RB.salvage_type, "the fallen roof leaves rubble to salvage")

	// Clearing rubble gives back part of what it was made of.
	var/obj/structure/rubble/clear_me = new /obj/structure/rubble(locate(9, 9, 1), /obj/item/stack/material/wood, 3)
	bc_check(findtext(clear_me.icon_state, "rubble_wood") == 1 && (clear_me.icon_state in icon_states(clear_me.icon)), "wooden rubble looks like wood ([clear_me.icon_state])")
	var/obj/structure/rubble/stone_rubble = new /obj/structure/rubble(locate(10, 9, 1), /obj/item/stack/material/stone, 2)
	bc_check(findtext(stone_rubble.icon_state, "rubble_stone") == 1 && (stone_rubble.icon_state in icon_states(stone_rubble.icon)), "stone rubble looks like stone ([stone_rubble.icon_state])")
	building_collapse_dust(locate(10, 10, 1))
	bc_check(locate(/obj/effect/collapse_dust) in locate(10, 10, 1), "a collapse raises a dust cloud")
	clear_me.rubble_salvage()
	var/obj/item/stack/material/wood/salvaged = locate() in locate(9, 9, 1)
	bc_check(salvaged && salvaged.amount == 3, "rubble salvage returns its stack ([salvaged ? salvaged.amount : 0])")

	// Heavy debris breaks a weak floor below it: a two-storey wooden building
	// pancakes when concrete lands on its first floor.
	var/turf/base = locate(10, 4, 1)
	new /obj/structure/roof_support(base)
	var/obj/roof/R1 = building_construct_roof(base, /obj/roof/wood, null)
	var/obj/covers/F1 = R1 ? R1.building_floor() : null
	var/turf/first = F1 ? get_turf(F1) : null
	var/obj/structure/roof_support/P2 = first ? new /obj/structure/roof_support(first) : null
	var/obj/roof/R2 = first ? building_construct_roof(first, /obj/roof/wood, null) : null
	bc_check(F1 && P2 && R2, "a second storey stands on the first floor")
	sleep(50)
	building_debris_land(first, building_debris_weight("concrete"), null)
	bc_check(QDELETED(F1) && QDELETED(R1), "concrete debris breaks the wooden first floor and its ceiling")
	bc_check(QDELETED(P2), "the pillar on that floor falls with it")
	bc_wait_for_queue()
	bc_check(QDELETED(R2), "and the roof it held comes down after")

	// The queue's budget: one pass handles at most its share.
	var/list/fake = list()
	for (var/i in 1 to 100)
		fake[new /obj/roof/canopy(locate(1 + (i % 15), 10, 1))] = 0
	var/handled = building_collapse_run(fake, 40, "final")
	bc_check(handled == 40 && fake.len == 60, "a pass handles at most its budget ([handled], [fake.len] left)")

	// Lighter debris is not as deadly: thatch hurts less than stone.
	bc_check(building_debris_weight("thatch") < building_debris_weight("Wood") && building_debris_weight("Wood") < building_debris_weight("Stone"), "debris weight follows the material")
