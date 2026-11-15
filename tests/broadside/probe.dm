// The Broadside map, headless (run.py): the real map is compiled in, both
// ships are commissioned as built hulls, crewmen join aboard, a ship sails at
// the battle pace carrying her guns, the call lays guns on the enemy hull and
// fires them, and the sink and capture checks answer.

/mob/living/human/bs_probe/New()
	return

var/bs_failures = 0
/proc/bs_check(cond, msg)
	if (!cond)
		bs_failures++
	text2file("[cond ? "ok" : "FAIL"]: [msg]\n", "bs_log.txt")

/world/Error(exception/e)
	bs_check(FALSE, "runtime error [e] [e.file]:[e.line]")

/world/New()
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	spawn(5)
		bs_run()

/obj/map_metadata/broadside/faction1_can_cross_blocks()
	return TRUE
/obj/map_metadata/broadside/faction2_can_cross_blocks()
	return TRUE

/proc/bs_run()
	Master.start_timer_loop()
	try
		bs_cases()
	catch (var/exception/e)
		bs_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file("DONE\n", "bs_log.txt")
	del(world)

/proc/bs_man(faction)
	var/mob/living/human/bs_probe/M = new(locate(1, 2, 1))
	M.faction_text = faction
	M.m_intent = "stealth" // no footstep sounds without the movement process
	return M

/proc/bs_cases()
	bs_check(istype(map, /obj/map_metadata/broadside), "the Broadside metadata is on the map")
	var/obj/structure/hull_tiller/broadside/F = broadside_tiller_of(FRENCH)
	var/obj/structure/hull_tiller/broadside/P = broadside_tiller_of(PIRATES)
	bs_check(F && P && broadside_tillers.len == 2, "each side has one ship's tiller")
	if (!F || !P)
		return
	sleep(30) // a plank on the deep sea that is not afloat sinks after a second and a half
	broadside_launch_all()
	bs_check(F.craft && P.craft, "both ships are commissioned")
	if (!F.craft || !P.craft)
		return
	var/datum/craft/FC = F.craft
	var/datum/craft/PC = P.craft
	var/datum/craft_body/built/FB = FC.body
	var/datum/craft_body/built/PB = PC.body
	bs_check(FC.name == "Foudroyant" && PC.name == "Black Gull", "the ships carry their names")
	bs_check(FB.dir == EAST && PB.dir == WEST, "the French bow points east, the pirate bow west")
	bs_check(FC.anchored && PC.anchored, "both ships start at anchor")
	bs_check(F.start_planks == FB.tile_count() && F.start_planks > 100, "the planking is counted ([F.start_planks] of [FB.tile_count()])")
	bs_check(FC.max_speed() >= VESSEL_SPEED_HALF && PC.max_speed() >= VESSEL_SPEED_HALF, "four rigged masts drive each ship at half ahead")

	// Crewmen join on their own ship.
	var/mob/living/human/bs_probe/frenchman = bs_man(FRENCH)
	var/mob/living/human/bs_probe/pirate = bs_man(PIRATES)
	bs_check(broadside_spawn_aboard(frenchman) && craft_at(get_turf(frenchman)) == FC, "a French sailor joins aboard the Foudroyant")
	bs_check(broadside_spawn_aboard(pirate) && craft_at(get_turf(pirate)) == PC, "a pirate joins aboard the Black Gull")

	// She sails at the battle pace, guns and all.
	var/list/guns = list()
	var/loaded = 0
	for (var/obj/structure/cannon/C in world)
		C.explosion = FALSE // no explosion subsystem in the probe
		if (craft_at(get_turf(C)) == FC)
			guns += C
			if (C.loaded.len)
				loaded++
	bs_check(guns.len == 10, "the Foudroyant carries ten guns ([guns.len])")
	bs_check(loaded == 10, "her guns are run out loaded ([loaded] of 10)")
	FC.set_anchor(FALSE)
	FC.set_speed(VESSEL_SPEED_HALF)
	bs_check(FC.speed == VESSEL_SPEED_HALF && FC.sail_interval() <= 20, "at half ahead she makes a tile in under two seconds ([FC.sail_interval()] ticks)")
	var/obj/structure/cannon/first = guns[1]
	var/x0 = FB.px
	var/gx = first.x
	var/moved = 0
	for (var/i = 1 to 3)
		if (FC.sail_hop())
			moved++
	bs_check(moved == 3 && FB.px == x0 + 3 && first.x == gx + 3, "three steps carry her and her guns three tiles east")
	FC.set_speed(VESSEL_SPEED_STOP)
	FC.set_anchor(TRUE)

	// Bring the pirate under the French guns, then blow the call.
	var/list/box = PB.box(PB.offsets)
	var/target_px = FB.px + 18
	var/target_py = FB.py - 15
	bs_check(PB.move_to(target_px + box[1], target_py + box[2], WEST), "the Black Gull comes abeam of the Foudroyant")
	var/list/sides = broadside_guns(get_turf(F))
	var/list/south = sides["[SOUTH]"]
	bs_check(south && south.len == 5, "the call finds five guns on the starboard side")
	if (!south)
		return
	var/laid = 0
	for (var/obj/structure/cannon/C in south)
		if (broadside_lay_gun(C) && craft_at(locate(C.x, C.y - C.distance, C.z)) == PC)
			laid++
	bs_check(laid == 5, "every starboard gun is laid on the enemy deck ([laid] of 5)")
	bs_check(broadside_fire(south) == 5, "the starboard side is ordered to fire")
	sleep(60)
	var/still = 0
	for (var/obj/structure/cannon/C in south)
		if (C.loaded.len)
			still++
	bs_check(still == 0, "every starboard gun fired")

	// Boarders hold a tiller only while her crew are away.
	frenchman.forceMove(get_step(P, NORTH))
	pirate.forceMove(locate(1, 3, 1))
	bs_check(P.boarders_hold(), "a French boarder alone at the pirate tiller holds it")
	pirate.forceMove(get_step(P, SOUTH))
	bs_check(!P.boarders_hold(), "a pirate at the tiller contests it")
	frenchman.stat = DEAD
	bs_check(!P.boarders_hold(), "a dead boarder holds nothing")

	// A ship that loses too much planking is sunk.
	bs_check(!P.is_sunk(), "a whole ship is afloat")
	var/cut = 0
	for (var/turf/T in PB.cells())
		if (cut >= round(P.start_planks * 0.45))
			break
		for (var/obj/covers/C in T)
			qdel(C)
		cut++
	bs_check(P.is_sunk(), "a ship with almost half her planking shot away is sunk")
	bs_check(!F.is_sunk(), "the other ship is still afloat")
