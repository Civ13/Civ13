// Gun ports, barred gates and cargo hatches (code/modules/naval/hull_ports.dm):
// a shut port is a wall to shots and climbers, a gate bars only shut and from
// aboard, an open port on an awash deck ships water, a cargo hatch lowers
// cargo into the hold under it, and the ship designer checks them.
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

/proc/steel_lay(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/steelplating/C = new(T)
	C.updateturf()
	return C

/proc/bilge_hull(x1, y1, x2, y2, hull_name, steel = FALSE)
	for (var/x = x1, x <= x2, x++)
		for (var/y = y1, y <= y2, y++)
			if (steel)
				steel_lay(x, y)
			else
				hull_lay(x, y)
	var/obj/structure/hull_tiller/tiller = new(locate(x1, y1, 2))
	naval_check(isnull(tiller.commission(hull_name, NORTH)) && tiller.craft, "the [hull_name] is commissioned")
	return tiller


// A plain hull drawn on the sheet: w by h planks, the tiller in the middle.
/proc/draught_box(w, h, name = "Box")
	var/datum/ship_draught/D = new
	D.name = name
	for (var/x = 0, x < w, x++)
		for (var/y = 0, y < h, y++)
			D.set_floor(x, y, "w")
	D.set_piece(round(w / 2), round(h / 2), "T")
	return D

/proc/naval_checks()
	hull_ledger_timer_off = TRUE
	naval_fixture()
	var/obj/structure/hull_tiller/tiller = bilge_hull(30, 10, 33, 19, "Frigate")
	var/datum/hull_ledger/L = tiller.craft.ledger
	L.seep_tiles = 0

	// ---- A gun port in her starboard side ----
	var/obj/structure/railing/built/gunwale/gun_port/port = new(locate(33, 14, 2))
	port.dir = EAST
	naval_check(hull_gun_port(port) && port.gate && port.density && port.icon_state == "gunport_wood_gate", "a wooden gun port is a shut gate in her side")
	var/obj/item/projectile/shot = new(locate(33, 14, 2))
	naval_check(!port.CanPass(shot, locate(34, 14, 2)) && !port.CheckExit(shot, locate(34, 14, 2)), "shut, a shot does not pass it")
	naval_check(!port.can_climb(null), "shut, nobody climbs over it")
	port.set_gate_open(TRUE)
	naval_check(!port.density && port.icon_state == "gunport_wood_gate_open" && port.CheckExit(shot, locate(34, 14, 2)), "open, it lets shots and boarders through")
	qdel(shot)
	naval_check(!port.set_barred(TRUE) && !port.barred, "an open port cannot be barred")

	// ---- Water through an open port ----
	naval_check(port.loc in hull_open_ports(tiller.craft.body.cells()), "the open port is listed")
	naval_check(L.step_ports(60) == 0 && L.water == 0, "on a dry deck an open port ships nothing")
	L.add_water(L.limit())
	var/before = L.water
	naval_check(L.deck_awash() && L.step_ports(60) == 1 && L.water > before, "awash, an open port ships water ([before] to [L.water])")
	port.set_gate_open(FALSE)
	before = L.water
	naval_check(L.step_ports(60) == 0 && L.water == before, "shut, it ships no more")
	L.water = 0
	L.bays_sync()

	// ---- Barring ----
	naval_check(port.set_barred(TRUE) && port.barred, "shut, it is barred")
	var/mob/living/human/naval_probe/crew = new(locate(31, 14, 2))
	var/mob/living/human/naval_probe/swimmer = new(locate(35, 14, 2))
	naval_check(port.user_aboard(crew) && !port.user_aboard(swimmer), "the crew stand aboard her and a swimmer alongside does not")
	naval_check(port.gate_knock(swimmer) && !port.gate_knock(swimmer), "from outside a barred port can only be hammered on, and not twice at once")
	naval_check(port.set_barred(FALSE) && !port.barred, "unbarred from aboard")
	var/obj/structure/railing/built/gunwale/bulwark/gun_port/steel_port = new(locate(33, 16, 2))
	steel_port.dir = EAST
	naval_check(hull_gun_port(steel_port) && steel_port.icon_state == "gunport_steel_gate" && !steel_port.can_climb(null), "a steel gun port is the same")
	var/obj/structure/railing/built/gunwale/gangway/gangway = new(locate(30, 14, 2))
	gangway.dir = WEST
	naval_check(gangway.set_barred(TRUE) && gangway.barred, "a gangway bars the same way")
	var/obj/structure/railing/built/gunwale/plain = new(locate(30, 16, 2))
	naval_check(!plain.set_barred(TRUE), "a plain gunwale has nothing to bar")
	qdel(crew)
	qdel(swimmer)

	// ---- The cargo hatch ----
	var/turf/hold = locate(31, 17, 1)
	hull_hold_lay(hold)
	var/obj/structure/cargo_hatch/hatch = new(locate(31, 17, 2))
	var/obj/structure/cargo_hatch/blind = new(locate(32, 18, 2))
	naval_check(hatch.hold_below() == hold && !blind.hold_below(), "a hatch finds the hold under it, and one over rock finds none")
	var/obj/structure/closet/crate/crate = new(locate(31, 17, 2))
	naval_check(!hatch.lower(crate, null) && crate.loc == locate(31, 17, 2), "battened down, nothing goes down through it")
	hatch.set_open(TRUE)
	naval_check(hatch.open && hatch.icon_state == "cargo_hatch_open", "it opens")
	naval_check(hatch.lower(crate, null) && crate.loc == hold, "open, a crate is lowered into the hold")
	blind.set_open(TRUE)
	var/obj/structure/closet/crate/other = new(locate(32, 18, 2))
	naval_check(!blind.lower(other, null) && other.loc == locate(32, 18, 2), "with no hold under it, nothing is lowered")
	hatch.set_open(FALSE)
	naval_check(hatch.icon_state == "cargo_hatch", "it battens down again")

	// ---- Lifeboat davits ----
	var/obj/structure/lifeboat_davit/davit = new(locate(33, 12, 2))
	davit.dir = EAST
	var/obj/structure/vehicle/raft/raft = new(locate(35, 12, 2))
	naval_check(davit.hoist_refusal(raft) && !davit.hoist(raft) && raft.loc == locate(35, 12, 2), "a boat not right under the davits is not hoisted")
	raft.forceMove(locate(34, 12, 2))
	naval_check(davit.hoist(raft) && raft.loc == davit && davit.stowed() == raft && davit.icon_state == "davit_boat", "a boat alongside under them is hoisted and stowed")
	var/obj/structure/vehicle/raft/second = new(locate(34, 12, 2))
	naval_check(findtext(davit.hoist_refusal(second), "already"), "a second boat is refused")
	naval_check(findtext(davit.lower_refusal(), "in the way"), "the boat is not lowered onto another")
	qdel(second)
	tiller.craft.set_speed(VESSEL_SPEED_HALF)
	naval_check(findtext(davit.lower_refusal(), "stopped"), "not while she is under way")
	tiller.craft.set_speed(VESSEL_SPEED_STOP)
	naval_check(davit.lower() == raft && raft.loc == locate(34, 12, 2) && !davit.stowed() && davit.icon_state == "davit", "lowered, it floats beside her")
	davit.hoist(raft)
	qdel(davit)
	naval_check(raft.loc == locate(33, 12, 2) && !QDELETED(raft), "a davit that goes drops its boat on deck")
	qdel(raft)

	// ---- On the designer's sheet ----
	var/datum/ship_draught/D = draught_box(6, 10, "Frigate")
	var/sides = length(D.gunwale_sides())
	D.set_piece(0, 5, "GP", WEST)
	naval_check(length(D.gunwale_sides()) == sides - 1 && !findtext(jointext(D.problems(), " "), "gun port"), "a gun port on her edge closes the side it faces ([jointext(D.problems(), " ")])")
	D.set_piece(0, 5, "GS", EAST)
	naval_check(findtext(jointext(D.problems(), " "), "gun port faces her own deck"), "a gun port facing inboard is refused ([jointext(D.problems(), " ")])")
	D.set_piece(0, 5, null)
	D.set_piece(2, 2, "CH")
	naval_check(findtext(jointext(D.problems(), " "), "no hold under it"), "a cargo hatch with no hold under it is refused ([jointext(D.problems(), " ")])")
	D.set_deck(-1, 2, 2, TRUE)
	naval_check(!findtext(jointext(D.problems(), " "), "no hold under"), "drawn over her hold it is not ([jointext(D.problems(), " ")])")
	D.set_piece(0, 2, "LD", WEST)
	naval_check(!findtext(jointext(D.problems(), " "), "davits"), "davits on her edge facing out are fine ([jointext(D.problems(), " ")])")
	D.set_piece(0, 2, "LD", EAST)
	naval_check(findtext(jointext(D.problems(), " "), "her own deck: davits stand"), "davits facing inboard are refused ([jointext(D.problems(), " ")])")
	D.set_piece(0, 2, null)
	for (var/key in list("GP", "GS", "CH", "LD"))
		var/list/P = ship_draught_pieces()[key]
		naval_check(P && ispath(P["path"]) && P["cost"], "the sheet's [key] is a [P ? P["name"] : "missing piece"] with a cost")
	qdel(D)

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
