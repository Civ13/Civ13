// Naval mines and the hull magnetic signature (code/modules/naval/
// naval_mines.dm, magnetic_signature.dm, docs/naval-mines.md): what each hull
// is worth to a magnetic mine, where a mine may be laid, a contact mine under a
// hull, a magnetic mine that a wooden hull passes over and a steel hull sets
// off, the distance rule, and mines staying where they were laid.
/world
	hub = ""
	hub_password = ""
	maxx = 70
	maxy = 60
	maxz = 3
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/naval_research_done = FALSE
/obj/map_metadata/naval_probe/New()
	return
/obj/map_metadata/naval_probe/is_node_done(faction, node_id)
	return naval_research_done
/mob/living/human/naval_probe/New()
	return
var/naval_failures = 0
var/naval_runtime_error = FALSE
/proc/naval_check(condition, label)
	if (!condition)
		naval_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	naval_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

// Rock under everything, sand ashore (x 1-20) and deep sea beyond, sky above.
/proc/naval_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/R = locate(x, y, 1)
			R.ChangeTurf(/turf/wall/rockwall)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(x <= 20 ? /turf/floor/beach/sand : /turf/floor/beach/water/deep/saltwater)
			var/turf/S = locate(x, y, 3)
			S.ChangeTurf(/turf/sky/building)

/obj/structure/probe_gun
	name = "probe gun"
	anchored = TRUE
/obj/structure/probe_rock
	name = "probe rock"
	anchored = TRUE
	density = TRUE

// A plank laid the way a player lays one, with its first update already run.
/proc/hull_lay(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/repairedfloor/ship/C = new(T)
	C.updateturf()
	return C

/proc/hull_planks(turf/T)
	. = 0
	for (var/obj/covers/C in T)
		.++

// The steps a half minute covers at her speed: a gliding hull makes one tile
// a step. TRUE when every step moved her.
/proc/hull_leg(datum/craft/C)
	var/steps = 0
	while (steps < C.speed * VESSEL_TILES_PER_STEP)
		if (!C.sail_tick())
			return FALSE
		steps++
	return steps > 0


// A steel plate laid the way a player lays one.
/proc/hull_plate(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/steelplating/C = new(T)
	C.updateturf()
	return C

// The blasts are recorded, not set off: the fixture has no explosion config.
var/list/mine_blasts = list()
/obj/structure/naval_mine/blast_at(turf/hit)
	mine_blasts += hit

/proc/hull_steps(datum/craft/C, n)
	for (var/i = 1, i <= n, i++)
		if (!C.sail_tick())
			return FALSE
	return TRUE

/proc/naval_checks()
	naval_fixture()
	for (var/x = 22, x <= 68, x++)
		for (var/y = 4, y <= 56, y++)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(/turf/floor/beach/water)

	// ---- What a hull is worth ----
	var/datum/vessel/freighter/fr = new
	var/datum/vessel/carrier/cv = new
	var/datum/vessel/schooner/sc = new
	naval_check(fr.magnetic_base == 140 && cv.magnetic_base == 600 && sc.magnetic_base == 0, "a freighter is worth 140, a carrier 600 and a schooner nothing")
	qdel(fr)
	qdel(cv)
	qdel(sc)
	naval_check(magnetic_reading(0) == "none" && magnetic_reading(5) == "faint" && magnetic_reading(40) == "strong" && magnetic_reading(140) == "very strong", "the helm reads none, faint, strong and very strong")
	var/obj/structure/naval_mine/magnetic/probe_mine = new(locate(66, 54, 2))
	naval_check(probe_mine.feels(140, 3) && !probe_mine.feels(140, 4), "a freighter sets a magnetic mine off from 3 tiles, not 4")
	naval_check(probe_mine.feels(600, 4) && !probe_mine.feels(600, 5), "a carrier sets one off from 4 tiles, never from 5")
	naval_check(probe_mine.feels(30, 0) && probe_mine.feels(30, 1) && !probe_mine.feels(30, 2), "a 30 boat sets one off over it or beside it, not 2 tiles off")
	naval_check(!probe_mine.feels(0, 0), "a wooden hull never sets one off")
	qdel(probe_mine)
	var/obj/structure/naval_mine/contact/probe_contact = new(locate(66, 54, 2))
	naval_check(probe_contact.feels(0, 0) && !probe_contact.feels(600, 1), "a contact mine goes off only under a hull, wooden or steel")
	qdel(probe_contact)
	naval_check(!naval_mines.len, "deleted mines leave the list")

	// ---- Laying ----
	naval_check(findtext(naval_mine_lay_problem(locate(10, 10, 2)), "open water"), "a mine cannot be laid on sand")
	naval_check(isnull(naval_mine_lay_problem(locate(40, 40, 2))), "a mine can be laid on open water")
	var/obj/item/naval_mine/carried = new(locate(19, 40, 2))
	var/mob/living/human/naval_probe/layer_mob = new(locate(20, 40, 2))
	layer_mob.real_name = "Ida"
	naval_check(carried.laid_type == /obj/structure/naval_mine/contact && ispath(/obj/item/naval_mine/magnetic) && initial(carried.w_class) == ITEM_SIZE_HUGE, "a mine is a heavy item that lays a contact mine")
	qdel(carried)
	qdel(layer_mob)

	// ---- A wooden hull: eleven planks ----
	for (var/x = 30, x <= 34, x++)
		hull_lay(x, 10)
		hull_lay(x, 11)
	var/obj/structure/hull_tiller/tiller = new(locate(32, 10, 2))
	naval_check(isnull(tiller.commission("Wren", EAST)) && tiller.craft, "a wooden hull is commissioned")
	var/datum/craft/W = tiller.craft
	naval_check(W.magnetic_signature() == 0 && findtext(tiller.status_text(), "Magnetic signature: none"), "a wooden hull has no signature, and the tiller says so ([tiller.status_text()])")
	naval_check(findtext(naval_mine_lay_problem(locate(31, 10, 2)), "hull"), "a mine cannot be laid on a hull")
	// A magnetic mine in her path: she passes over it.
	var/obj/structure/naval_mine/magnetic/under = new(locate(37, 10, 2))
	W.set_anchor(FALSE)
	W.set_speed(VESSEL_SPEED_SLOW)
	naval_check(hull_steps(W, 4) && tiller.x == 36, "she sails four tiles east, over the magnetic mine ([tiller.x])")
	naval_check(!QDELETED(under) && under.x == 37 && under.y == 10 && !mine_blasts.len, "the magnetic mine stays where it was laid and does not go off")
	naval_check(!(under in W.body.aboard()), "a mine under her is not counted aboard")
	// A contact mine ahead: she sets it off.
	var/obj/structure/naval_mine/contact/horned = new(locate(40, 11, 2))
	naval_check(hull_steps(W, 2) && QDELETED(horned) && mine_blasts.len == 1, "a contact mine under her hull goes off ([mine_blasts.len])")
	var/turf/hit = mine_blasts.len ? mine_blasts[1] : null
	naval_check(hit && W.body.contains(hit) && hit == locate(40, 11, 2), "the blast is under her hull where the mine lay")
	W.set_speed(VESSEL_SPEED_STOP)
	qdel(under)

	// ---- A steel hull: twenty plates ----
	mine_blasts = list()
	for (var/x = 30, x <= 34, x++)
		for (var/y = 30, y <= 33, y++)
			hull_plate(x, y)
	var/obj/structure/hull_tiller/steel_tiller = new(locate(32, 31, 2))
	naval_check(isnull(steel_tiller.commission("Iron Duke", EAST)) && steel_tiller.craft, "a steel hull is commissioned")
	var/datum/craft/S = steel_tiller.craft
	naval_check(S.magnetic_signature() == 20 && findtext(steel_tiller.status_text(), "Magnetic signature: strong"), "twenty steel plates are worth 20 ([S.magnetic_signature()])")
	// Two tiles off her course she passes by; one tile off it goes off.
	var/obj/structure/naval_mine/magnetic/wide = new(locate(40, 36, 2))
	var/obj/structure/naval_mine/magnetic/close = new(locate(44, 34, 2))
	S.set_anchor(FALSE)
	S.set_speed(VESSEL_SPEED_SLOW)
	naval_check(hull_steps(S, 7) && !QDELETED(wide) && !mine_blasts.len, "a magnetic mine three tiles off her course does not go off")
	naval_check(hull_steps(S, 3) && QDELETED(close) && mine_blasts.len == 1, "one tile off her course it goes off ([mine_blasts.len])")
	hit = mine_blasts.len ? mine_blasts[1] : null
	naval_check(hit && S.body.contains(hit) && hit.y == 33, "the blast is under her nearest plate")
	S.set_speed(VESSEL_SPEED_STOP)
	qdel(wide)
	naval_check(!naval_mines.len, "no mines are left")

	// ---- A submarine ----
	mine_blasts = list()
	var/obj/structure/vehicleparts/axis/ship/submarine/boat = build_submarine(locate(55, 40, 2), "Probe boat")
	var/datum/craft/SC = craft_of_axis(boat)
	naval_check(SC && SC.body.magnetic_base() == 30, "a Scout submarine's fifteen steel frames are worth 30 ([SC ? SC.body.magnetic_base() : "-"])")
	naval_check(findtext(boat.systems_report(), "Magnetic signature: strong"), "the systems report reads her signature ([boat.systems_report()])")
	var/turf/beside = null
	for (var/turf/T in SC.body.cells())
		var/turf/E = locate(T.x + 1, T.y, T.z)
		if (E && !SC.body.contains(E))
			beside = E
			break
	var/obj/structure/naval_mine/magnetic/sub_mine = new(beside)
	naval_check(SC.check_naval_mines() == 1 && QDELETED(sub_mine) && mine_blasts.len == 1, "a magnetic mine beside her goes off")
	naval_check(boat.hull_leaks == 2, "and springs two leaks in her hull ([boat.hull_leaks])")
/proc/naval_run()
	try
		naval_checks()
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = naval_failures, "runtime_error" = naval_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/naval_probe
		naval_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		naval_run()
