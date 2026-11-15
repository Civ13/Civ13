// Native probe for aqueducts (code/modules/1713/aqueducts.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/aqueducts/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 8
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/aqueduct_probe/New()
	return
var/aq_failures = 0
var/aq_runtime_error = FALSE
/proc/aq_check(condition, label)
	if (!condition)
		aq_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	aq_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/aqueduct_probe
		aq_checks()
	catch(var/exception/e)
		aq_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = aq_failures, "runtime_error" = aq_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

// Heights by "x,y"; everything else is 0.
/datum/terrain_heights/aqueduct_probe
	var/list/heights = list("1,3" = 3, "2,3" = 3, "3,3" = 3, "4,3" = 2, "5,3" = 2, "6,3" = 3,
		"1,6" = 2, "2,6" = 2, "3,6" = 2, "4,6" = 0, "5,6" = 0, "6,6" = 2, "7,6" = 4, "8,6" = 1)
/datum/terrain_heights/aqueduct_probe/at(x, y, z)
	var/h = heights["[x],[y]"]
	return h ? h : 0

/proc/aq_flow()
	aqueduct_last_flow = -1000
	aqueduct_flow_all()

/proc/aq_checks()
	map.terrain_height_file = "probe"
	map.terrain_heights_cache = new /datum/terrain_heights/aqueduct_probe
	map.persistence = TRUE

	// Row 3: river at x 1, intake at x 2, channel x 3 to 6. x 6 stands higher
	// than the water reaching it.
	new /turf/floor/beach/water(locate(1, 3, 1))
	var/obj/structure/aqueduct_intake/I = new /obj/structure/aqueduct_intake(locate(2, 3, 1))
	aq_check(I.dir == WEST, "an intake faces the water beside it")
	aq_check(!I.idle_reason(), "an intake on fresh water draws ([I.idle_reason()])")
	var/list/row = list()
	for (var/x in 3 to 6)
		row += new /obj/structure/aqueduct/channel(locate(x, 3, 1))
	var/obj/structure/aqueduct/A3 = row[1]
	var/obj/structure/aqueduct/A4 = row[2]
	var/obj/structure/aqueduct/A5 = row[3]
	var/obj/structure/aqueduct/A6 = row[4]
	aq_check(A4.icon_state == "channel12" && A3.icon_state == "channel4", "a straight run joins east and west ([A3.icon_state], [A4.icon_state])")
	var/obj/structure/sink/aqueduct_fountain/F = new /obj/structure/sink/aqueduct_fountain(locate(5, 4, 1))
	aq_check(F.volume == 0, "a new fountain starts dry")
	var/obj/structure/reagent_dispensers/cistern/C = new /obj/structure/reagent_dispensers/cistern(locate(6, 4, 1))
	var/cistern_before = C.reagents.total_volume
	var/obj/structure/workshop_machine/mover/mill_wheel/M = new /obj/structure/workshop_machine/mover/mill_wheel(locate(3, 2, 1))
	aq_check(M.idle_reason(), "a mill wheel with no river or race is idle")
	var/obj/structure/sewer_piece/drain/stone/D = new /obj/structure/sewer_piece/drain/stone(locate(5, 2, 1))
	D.set_clogged(TRUE)

	aq_flow()
	aq_check(A3.wet && A4.wet && A5.wet, "water runs downhill along the channel")
	aq_check(!A6.wet, "water does not climb into a channel laid higher than it")
	aq_check(A5.wet_level == 2, "water sits at the ground of the channel it runs in ([A5.wet_level])")
	aq_check(F.volume > 0 && !F.dirty, "a fountain beside a wet channel fills with clean water ([F.volume])")
	aq_check(C.reagents.total_volume > cistern_before, "a cistern beside a wet channel fills")
	aq_check(!M.idle_reason(), "a mill race turns a mill wheel beside the channel")
	aq_check(!D.clogged, "running water flushes a clogged drain beside it")

	// Waste in the channel fouls the water from there on.
	var/obj/item/weapon/reagent_containers/food/snacks/poo/P = new /obj/item/weapon/reagent_containers/food/snacks/poo(A4.loc)
	aq_flow()
	aq_check(!A3.foul && A4.foul && A5.foul, "waste fouls the water below it, not above")
	aq_check(F.dirty, "a fountain below fouled water gives foul water")
	var/obj/item/weapon/reagent_containers/glass/bucket/B = new /obj/item/weapon/reagent_containers/glass/bucket(locate(5, 5, 1))
	aq_check(F.draw_foul(B) > 0 && B.reagents.has_reagent("cholera"), "water drawn from a foul fountain carries cholera")
	qdel(P)
	aq_flow()
	aq_check(!A5.foul && !F.dirty, "the water runs clean again once the waste is gone")

	// Breaking a piece cuts everything below it.
	qdel(A4)
	aq_flow()
	aq_check(A3.wet && !A5.wet, "breaking a piece dries the channel below it")
	var/before = F.volume
	aq_flow()
	aq_check(F.volume == before, "a fountain on a cut aqueduct gets no more water")

	// Row 6: arches keep the level over a hollow, a plain channel does not; a
	// qanat keeps it through a hill.
	new /turf/floor/beach/water(locate(1, 6, 1))
	new /obj/structure/aqueduct_intake(locate(2, 6, 1))
	var/obj/structure/aqueduct/R3 = new /obj/structure/aqueduct/channel(locate(3, 6, 1))
	var/obj/structure/aqueduct/R4 = new /obj/structure/aqueduct/channel(locate(4, 6, 1))
	var/obj/structure/aqueduct/R5 = new /obj/structure/aqueduct/channel(locate(5, 6, 1))
	var/obj/structure/aqueduct/R6 = new /obj/structure/aqueduct/channel(locate(6, 6, 1))
	aq_flow()
	aq_check(R3.wet && R5.wet && !R6.wet, "a channel down into a hollow can't climb out of it")
	qdel(R4)
	qdel(R5)
	var/obj/structure/aqueduct/arch/AR = new /obj/structure/aqueduct/arch(locate(4, 6, 1))
	new /obj/structure/aqueduct/flume(locate(5, 6, 1))
	aq_flow()
	aq_check(AR.wet && R6.wet && R6.wet_level == 2, "arches and a flume carry the water level across the hollow")
	var/obj/structure/aqueduct/Q = new /obj/structure/aqueduct/qanat(locate(7, 6, 1))
	var/obj/structure/aqueduct/R8 = new /obj/structure/aqueduct/channel(locate(8, 6, 1))
	aq_flow()
	aq_check(Q.wet && Q.icon_state == "qanat_wet" && R8.wet, "a qanat carries the water through a hill")
	var/obj/structure/aqueduct/AR7 = new /obj/structure/aqueduct/arch(locate(7, 5, 1))
	aq_flow()
	aq_check(!AR7.wet || AR7.wet_level <= 2, "raised pieces never lift water higher than it came in")

	// A noria needs a current; salt water feeds nothing.
	var/obj/structure/aqueduct_intake/noria/N = new /obj/structure/aqueduct_intake/noria(locate(2, 1, 1))
	aq_check(N.idle_reason(), "a noria with no river beside it is idle")
	new /turf/floor/beach/water/deep/saltwater(locate(10, 1, 1))
	var/obj/structure/aqueduct_intake/S = new /obj/structure/aqueduct_intake(locate(11, 1, 1))
	aq_check(S.idle_reason(), "an intake on seawater draws nothing")
	aq_check(aqueduct_walk(I).len >= 1, "the walk returns the reached pieces")

	// Row 7: pipes to a tap and a bath.
	new /turf/floor/beach/water(locate(1, 7, 1))
	new /obj/structure/aqueduct_intake(locate(2, 7, 1))
	var/obj/structure/aqueduct/pipe/CP = new /obj/structure/aqueduct/pipe(locate(3, 7, 1))
	var/obj/structure/aqueduct/pipe/lead/LP = new /obj/structure/aqueduct/pipe/lead(locate(4, 7, 1))
	var/obj/structure/sink/aqueduct_fountain/tap/TP = new /obj/structure/sink/aqueduct_fountain/tap(locate(5, 7, 1))
	var/obj/structure/aqueduct_bath/BA = new /obj/structure/aqueduct_bath(locate(3, 8, 1))
	aq_check(!BA.has_water(), "a new bath is empty")
	aq_flow()
	aq_check(CP.wet && LP.wet, "pipes carry the water")
	aq_check(TP.volume > 0 && TP.icon_state == "tap_running", "a tap on a pipe runs ([TP.icon_state])")
	aq_check(BA.has_water() && BA.icon_state == "bath_full", "a bath beside the water fills")
	for (var/i in 1 to 30)
		aq_flow()
	aq_check(TP.lead > 0, "water from lead pipes picks up lead now and then ([TP.lead])")
	var/obj/item/weapon/reagent_containers/glass/bucket/B2 = new /obj/item/weapon/reagent_containers/glass/bucket(locate(6, 7, 1))
	TP.give_lead(B2)
	aq_check(B2.reagents.has_reagent("lead"), "water drawn from a lead-fed tap carries lead")
	qdel(CP)
	aq_flow()
	BA.last_fed = world.time - 4000
	aq_check(!BA.has_water() && BA.icon_state == "bath", "a bath cut off from the water drains")
