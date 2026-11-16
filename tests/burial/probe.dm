// Native probe for being buried alive (code/modules/1713/burial.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/burial/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 8
	maxy = 8
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/burial_probe/New()
	return
/mob/living/human/burial_probe/update_icons()
	return
/mob/living/human/burial_probe/update_hair(update_icons = 1)
	return
/mob/living/human/burial_probe/update_inv_head(update_icons = 1)
	return
/mob/living/human/burial_probe/handle_hud_list()
	return
/mob/living/human/burial_probe/update_inv_wear_mask(update_icons = 1)
	return
/mob/living/human/burial_probe/New()
	species = new /datum/species/human
	return
var/burial_failures = 0
var/burial_runtime_error = FALSE
/proc/burial_check(condition, label)
	if (!condition)
		burial_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	burial_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/burial_probe
		burial_checks()
	catch(var/exception/e)
		burial_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = burial_failures, "runtime_error" = burial_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/burial_checks()
	// Bare earth: a held breath, then suffocation every tick.
	var/obj/structure/religious/grave/G = new(locate(2, 2, 1))
	var/mob/living/human/burial_probe/H = new(locate(2, 2, 1))
	G.cover_grave()
	burial_check(H.loc == G && H.buriedalive && H.anchored && burial_grave(H) == G, "filling a grave over a living person buries them alive")
	burial_check(H.burial_air == 10, "bare earth leaves a held breath ([H.burial_air])")
	for (var/i in 1 to 10)
		H.burial_life_tick()
	burial_check(H.burial_air == 0 && !H.getOxyLoss(), "the held breath runs out without harm")
	H.burial_life_tick()
	H.burial_life_tick()
	burial_check(H.getOxyLoss() == 10, "then they suffocate every tick, not just once ([H.getOxyLoss()])")
	G.uncover_grave()
	burial_check(H.loc == G.loc && !H.buriedalive && !H.anchored, "digging the grave up frees them")
	H.burial_life_tick()
	burial_check(H.getOxyLoss() == 10, "no more suffocation once free")

	// Clawing out of bare earth with Resist.
	H.adjustOxyLoss(-200)
	G.cover_grave()
	var/presses = 0
	while (H.buriedalive && presses < 200)
		H.burial_air = 10
		H.burial_resist()
		presses++
	burial_check(!H.buriedalive && G.open && H.loc == G.loc, "Resist claws a buried person out ([presses] presses)")
	burial_check(presses >= 15, "clawing out takes at least 15 presses")

	// A coffin holds air, and its lid must be forced first.
	var/obj/structure/closet/coffin/C = new(locate(2, 2, 1))
	H.forceMove(C)
	C.opened = FALSE
	G.cover_grave()
	burial_check(C.loc == G && H.loc == C && H.buriedalive && !H.anchored, "a person shut in a coffin is buried with it")
	burial_check(H.burial_air == 90, "a closed coffin holds more air ([H.burial_air])")
	C.locked = TRUE
	H.burial_resist()
	burial_check(H.burial_work == 0 && !H.burial_lid_forced, "a nailed coffin lid will not give")
	C.locked = FALSE
	for (var/i in 1 to 4)
		H.burial_resist()
	burial_check(H.burial_lid_forced && H.buriedalive, "four pushes force the lid, still under the earth")
	burial_check(H.burial_air == 82, "each push costs air ([H.burial_air])")
	presses = 0
	while (H.buriedalive && presses < 200)
		H.burial_air = 90
		H.burial_resist()
		presses++
	burial_check(!H.buriedalive && G.open && C.opened && H.loc == G.loc, "clawing out of a coffin opens the grave and the coffin")

	// A burial mound doubles the earth.
	var/obj/structure/closet/coffin/C2 = new(locate(2, 2, 1))
	qdel(C)
	H.forceMove(locate(2, 2, 1))
	G.cover_grave()
	G.mound_raised = TRUE
	presses = 0
	while (H.buriedalive && presses < 400)
		H.burial_air = 10
		H.burial_resist()
		presses++
	burial_check(presses >= 30 && !H.buriedalive, "a burial mound takes twice the digging ([presses] presses)")
	burial_check(!G.mound_raised, "a dug-up mound is a plain open grave again")
	qdel(C2)

	// Restored from a save: still buried, and the state stays put.
	G.cover_grave()
	H.burial_air = -1
	H.burial_life_tick()
	burial_check(H.buriedalive && H.burial_air == 9, "a buried person with no air count gets one on the next tick")
	H.forceMove(locate(5, 5, 1))
	H.burial_life_tick()
	burial_check(!H.buriedalive && !H.anchored, "out of the grave any other way, they are no longer buried")

	// The dead are laid in, not buried alive.
	G.uncover_grave()
	H.forceMove(G.loc)
	H.stat = DEAD
	G.cover_grave()
	burial_check(H.loc == G && !H.buriedalive, "the dead are buried, not buried alive")
