// Native probe for buttresses, flying buttresses and corbels
// (code/game/objects/building_buttresses.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/building_buttresses/probe.dm 300
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 20
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/building_buttresses_probe/New()
	return
var/vr_failures = 0
var/vr_runtime_error = FALSE
/proc/vr_check(condition, label)
	if (!condition)
		vr_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	vr_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	sleep(1)
	try
		config = new
		config.webhook_can_fire = FALSE
		makeDatumRefLists()
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		movementMachine = new
		map = new /obj/map_metadata/building_buttresses_probe
		Master.start_timer_loop()
		vr_checks()
	catch(var/exception/e)
		vr_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = vr_failures, "runtime_error" = vr_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/vr_checks()
	// A buttress against a stone wall: one storey more, and it faces the wall.
	var/obj/covers/stone_wall/SW = new /obj/covers/stone_wall(locate(5, 5, 1))
	vr_check(SW.building_support_tier() == 4, "a bare stone wall carries 4 storeys")
	var/obj/structure/building_brace/B = new /obj/structure/building_brace(locate(5, 4, 1))
	B.set_dir(NORTH)
	vr_check(B.building_brace_wall() == SW, "the buttress braces the wall north of it")
	vr_check(SW.building_support_tier() == 5, "a buttressed stone wall carries 5 storeys")
	vr_check(building_support_reach(SW) == 1, "a plain buttress does not widen the span")

	// It turns to face a wall it can serve.
	var/obj/covers/stone_wall/SW2 = new /obj/covers/stone_wall(locate(20, 5, 1))
	var/obj/structure/building_brace/B2 = new /obj/structure/building_brace(locate(20, 4, 1))
	B2.set_dir(EAST)
	vr_check(B2.dir == NORTH && B2.building_brace_wall() == SW2, "a buttress set the wrong way turns to its wall")

	// Wood is not masonry.
	var/obj/covers/wood_wall/WW = new /obj/covers/wood_wall(locate(25, 5, 1))
	var/obj/structure/building_brace/B3 = new /obj/structure/building_brace(locate(25, 4, 1))
	B3.set_dir(NORTH)
	vr_check(!B3.building_brace_wall() && WW.building_support_tier() == 2, "a buttress does nothing for a plank wall")
	vr_check(B3.brace_dismantle_check(null), "a buttress bracing nothing can come down")

	// A flying buttress two tiles out: one storey more and a wider span.
	var/obj/covers/stone_wall/FW = new /obj/covers/stone_wall(locate(15, 5, 1))
	var/obj/structure/building_brace/flying/F = new /obj/structure/building_brace/flying(locate(15, 3, 1))
	F.set_dir(NORTH)
	vr_check(F.building_brace_wall() == FW, "the flying buttress reaches a wall two tiles off")
	vr_check(FW.building_support_tier() == 5 && building_support_reach(FW) == 2, "a flying buttress adds a storey and widens the span")

	// A corbel lets a wall hold a slab a tile further out, but adds no storey.
	var/obj/covers/wood_wall/CW = new /obj/covers/wood_wall(locate(10, 5, 1))
	var/obj/structure/building_brace/corbel/wood/C = new /obj/structure/building_brace/corbel/wood(locate(10, 4, 1))
	C.set_dir(NORTH)
	vr_check(!C.density, "people walk under a corbel")
	vr_check(C.building_brace_wall() == CW && building_support_reach(CW) == 2 && CW.building_support_tier() == 2, "a corbel lets a plank wall carry an overhang")

	// A blow that pushes the wall towards its buttress meets double resistance.
	var/obj/covers/stone_wall/plain = new /obj/covers/stone_wall(locate(5, 10, 1))
	var/before = plain.health
	plain.structure_impact(1000, IMPACT_CRUSH, null, SOUTH)
	var/plain_loss = before - plain.health
	before = SW.health
	SW.structure_impact(1000, IMPACT_CRUSH, null, SOUTH)
	var/braced_loss = before - SW.health
	vr_check(braced_loss * 2 == plain_loss, "the buttress halves a blow pushing the wall onto it ([braced_loss] vs [plain_loss])")
	before = SW.health
	SW.structure_impact(1000, IMPACT_CRUSH, null, NORTH)
	vr_check(before - SW.health == plain_loss, "a blow from the buttress side gets no help")

	// Mapped walls take braces too.
	var/turf/wall/TW = new /turf/wall(locate(28, 10, 1), "stone")
	var/obj/structure/building_brace/B4 = new /obj/structure/building_brace(locate(28, 9, 1))
	B4.set_dir(NORTH)
	vr_check(TW.building_support_tier() == 5, "a buttressed mapped wall carries 5 storeys")

	// Losing the buttress loses the bonus.
	qdel(B)
	vr_check(SW.building_support_tier() == 4, "a broken buttress no longer helps")
	vr_check(is_structure_impact_part(F) && F.density, "a flying buttress pier is a solid building part")
