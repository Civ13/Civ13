// A ship holds the destination a world was woken for (code/modules/naval/
// ship_crossing.dm crossing_wake(), ship_voyage.dm, shard_group.dm ask_wake()):
// two crews choosing different lands, a slow wake, a refusal, a lost reply, a
// wake that runs out, a retry, a departure, a stale continuation and courses on
// the world chart. The doorman, peer polls, the transfer agent and departures
// are all stubbed here: nothing is woken or sent anywhere.
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

// ---------------------------------------------------------------- stubs

// Every wake asked of the doorman, by port; what it answers next; how long it takes.
var/list/probe_wakes = list()
var/probe_doorman_reply = null
var/probe_doorman_delay = 0
// Ports whose world answers a poll, and how many polls each had.
var/list/probe_awake = list()
var/list/probe_polls = list()
/datum/shard_group/ask_doorman(query)
	var/list/params = params2list(query)
	if (params["wake"])
		probe_wakes[params["port"]] = (probe_wakes[params["port"]] || 0) + 1
	if (probe_doorman_delay)
		sleep(probe_doorman_delay)
	return probe_doorman_reply
/datum/shard_group/poll_peer(id)
	var/list/peer = peers[id]
	probe_polls[id] = (probe_polls[id] || 0) + 1
	if (peer && probe_awake[id])
		peer["state"] = "UP"
		return TRUE
	return FALSE
/proc/probe_wakes_to(id)
	var/list/peer = shard_group.peers[id]
	return probe_wakes["[shard_address_port(peer["address"])]"] || 0

// The transfer agent: every course asked, and what it answers.
var/list/probe_requests = list()
var/probe_bridge_reply = null
var/probe_bridge_delay = 0
/datum/transfer_bridge/ready()
	return TRUE
/datum/transfer_bridge/request(path, list/body)
	probe_requests += list(body.Copy())
	if (probe_bridge_delay)
		sleep(probe_bridge_delay)
	return probe_bridge_reply

// A departure: the crew leave as one party, each carrying what the gate holds for them.
var/list/probe_departed = list()
/obj/structure/region_gate/sea_crossing/depart_party(list/members)
	var/list/gone = list()
	for (var/mob/living/human/H in members)
		var/list/extra = pending ? pending[H] : null
		probe_departed += list(list("who" = H.real_name, "to" = destination, "voyage" = extra ? extra["voyage"] : null, "ship" = extra && extra["ship"] ? TRUE : FALSE))
		gone += H
	for (var/mob/living/human/H in gone)
		qdel(H)
	return list("departed" = gone, "stayed" = list())

// ---------------------------------------------------------------- fixture

/proc/naval_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/R = locate(x, y, 1)
			R.ChangeTurf(/turf/wall/rockwall)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(x <= 20 ? /turf/floor/beach/sand : /turf/floor/beach/water/deep/saltwater)
			var/turf/S = locate(x, y, 3)
			S.ChangeTurf(/turf/sky/building)

/proc/hull_lay(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/repairedfloor/ship/C = new(T)
	C.updateturf()
	return C

// A ship off the east edge (within 4 tiles of it) with two crew aboard who set out together.
/proc/probe_ship(name, y)
	for (var/x = 64, x <= 67, x++)
		for (var/dy = 0, dy <= 2, dy++)
			hull_lay(x, y + dy)
	var/obj/structure/hull_tiller/tiller = new(locate(65, y + 1, 2))
	tiller.commission(name, EAST)
	tiller.craft.set_anchor(TRUE)
	return tiller

/proc/probe_sailor(name, x, y, owner)
	var/mob/living/human/naval_probe/H = new(locate(x, y, 2))
	H.real_name = name
	H.name = name
	H.persistence_owner_ckey = owner
	return H

/proc/probe_peers(state = "ASLEEP")
	shard_group.peers = list(
		"far1" = list("name" = "Far One", "kind" = "EXPEDITION", "state" = state, "address" = "127.0.0.1:1811"),
		"far2" = list("name" = "Far Two", "kind" = "EXPEDITION", "state" = state, "address" = "127.0.0.1:1812"))
	probe_awake = list()
	probe_polls = list()
	probe_wakes = list()

// A voyage under way to region id, as voyage_menu() leaves one.
/proc/probe_voyage(obj/structure/hull_tiller/tiller, id, list/crew)
	tiller.voyage = list("id" = "gaia-[id]-[rand(1000, 9999)]", "kind" = "lane", "x" = id, "y" = 0, "owner" = "crew:probe", "label" = id, "by" = "probe",
		"tile" = 600, "tiles" = 1, "ends" = world.time - 10, "minute" = world.time + 600, "said" = null, "rations" = 0, "stores" = 0,
		"events" = list(), "asked" = world.time + 300, "crew" = crew)
	return tiller.voyage

// Runs a crossing in the background, keeping what it answered.
/datum/probe_crossing
	var/done = FALSE
	var/result = "not run"
/datum/probe_crossing/proc/go(obj/structure/hull_tiller/tiller, id, voyage_id)
	set waitfor = FALSE
	result = tiller.cross(id, null, voyage_id)
	done = TRUE
/datum/probe_crossing/proc/set_out(obj/structure/hull_tiller/tiller, mob/living/human/H, x, y)
	set waitfor = FALSE
	result = tiller.set_out(H, "course", x, y, "crew:probe", 2, "a land")
	done = TRUE
/proc/probe_wait(datum/probe_crossing/C, limit = 200)
	var/until = world.time + limit
	while (!C.done && world.time < until)
		sleep(1)
	return C.done

// ---------------------------------------------------------------- checks

/proc/naval_checks()
	naval_fixture()
	shard_group.enabled = TRUE
	shard_group.region = "gaia"
	shard_group.mainland = "gaia"
	shard_group.kind = "SURFACE"
	shard_group.doorman = "127.0.0.1:1700"
	var/obj/structure/hull_tiller/tiller = probe_ship("Tern", 30)
	var/datum/craft_body/built/edge = tiller.craft ? tiller.craft.body : null
	naval_check(istype(edge) && edge.at_map_edge() && isnull(tiller.crossing_refusal()), "the Tern lies off the east edge, ready to leave ([tiller.crossing_refusal()])")
	var/mob/living/human/A = probe_sailor("Ann", 64, 30, "probeann")
	var/mob/living/human/B = probe_sailor("Bea", 66, 32, "probebea")

	// ---- Two crews, two lands: a slow accepted wake holds the first ----
	probe_peers()
	probe_doorman_reply = list("ok" = 1, "eta" = 0)
	probe_doorman_delay = 5
	var/list/mine = probe_voyage(tiller, "far1", list("probeann", "probebea"))
	var/datum/probe_crossing/first = new
	first.go(tiller, "far1", mine["id"])
	sleep(1)
	naval_check(tiller.crossing_hold && tiller.crossing_hold["state"] == "asking" && tiller.crossing_hold["region"] == "far1", "her course is held while the doorman is asked")
	naval_check(findtext(tiller.cross("far2"), "on a voyage"), "the other crew member's crossing elsewhere is refused while she is on a voyage")
	naval_check(findtext(tiller.crossing_menu_refusal(B, "far2"), "on a voyage"), "and so is a stale Leave these waters prompt")
	naval_check(!tiller.set_out(B, "lane", "far2", 0, "crew:probe", 1, "Far Two"), "and a stale voyage prompt for another land")
	naval_check(findtext(tiller.voyage_turn_back(B), "cannot turn back now"), "Turn back is refused while word is sent ahead")
	sleep(10)
	naval_check(tiller.crossing_hold && tiller.crossing_hold["state"] == "committed" && tiller.crossing_hold["busy"], "the doorman took the wake: she is bound for Far One")
	naval_check(findtext(tiller.crossing_hold_text(), "Bound for Far One"), "her tiller shows where she is bound ([tiller.crossing_hold_text()])")
	naval_check(findtext(tiller.voyage_turn_back(B), "Bound for Far One") && tiller.voyage == mine, "Turn back is refused once the wake was taken")
	var/old_voyage = tiller.voyage
	tiller.voyage = null // as if her voyage were gone: a direct crossing must still be held
	naval_check(findtext(tiller.cross("far2"), "bound for Far One"), "a crossing to another land is refused while she is bound")
	naval_check(findtext(tiller.cross("far1"), "already waiting"), "a second crossing to the same land waits on the first")
	tiller.voyage = old_voyage
	naval_check(probe_wakes_to("far2") == 0 && probe_wakes_to("far1") == 1, "Far Two had no wake request, Far One exactly one")
	// A poll that fails is not the end; the land answers late but in time.
	sleep(30)
	naval_check(!first.done && probe_polls["far1"] >= 1, "polls that fail keep her waiting ([probe_polls["far1"]])")
	probe_awake["far1"] = TRUE
	naval_check(probe_wait(first), "the crossing finishes once Far One answers")
	naval_check(isnull(first.result) && QDELETED(tiller), "she left for Far One ([first.result])")
	naval_check(length(probe_departed) == 2 && probe_departed[1]["to"] == "far1" && probe_departed[1]["voyage"] == mine["id"] && probe_departed[1]["ship"], "both crew went to Far One on the same voyage, the first carrying her")
	naval_check(probe_wakes_to("far2") == 0, "Far Two was never asked to wake")
	// The live report (2026-11-19): her crew were logged out on the way, and went with her.
	naval_check(QDELETED(A) && QDELETED(B), "logged-out crew who sailed with her went too")

	// ---- A definite refusal lets her go ----
	tiller = probe_ship("Petrel", 10)
	A = probe_sailor("Ann", 64, 10, "probeann")
	probe_peers()
	probe_doorman_delay = 0
	probe_doorman_reply = list("ok" = 0, "error" = "busy")
	mine = probe_voyage(tiller, "far1", list("probeann"))
	var/refused = tiller.cross("far1", null, mine["id"])
	naval_check(findtext(refused, "cannot be woken") && isnull(tiller.crossing_hold) && !QDELETED(tiller), "a refused wake holds nothing and she stays ([refused])")
	naval_check(isnull(tiller.voyage_turn_back(A)) && isnull(tiller.voyage), "Turn back works again")
	probe_doorman_reply = list("ok" = 1, "eta" = 0)
	var/datum/probe_crossing/other = new
	other.go(tiller, "far2")
	sleep(5)
	naval_check(probe_wakes_to("far2") == 1 && tiller.crossing_hold && tiller.crossing_hold["region"] == "far2", "after a refusal the crew may choose another land")

	// ---- A stale continuation neither moves her nor clears a newer hold ----
	var/gone_before = length(probe_departed)
	var/list/newer = list("op" = "newer", "region" = "far2", "state" = "committed", "until" = world.time + 600, "busy" = FALSE)
	tiller.crossing_hold = newer
	probe_awake["far2"] = TRUE
	naval_check(probe_wait(other), "the old crossing comes back")
	naval_check(findtext(other.result, "called off") && !QDELETED(tiller) && tiller.crossing_hold == newer && length(probe_departed) == gone_before, "it was called off: she did not move and the newer hold stands ([other.result])")
	tiller.crossing_hold = null

	// ---- A lost reply is treated as accepted: no second land is woken ----
	probe_peers()
	probe_doorman_reply = null
	other = new
	other.go(tiller, "far1")
	sleep(3)
	naval_check(tiller.crossing_hold && tiller.crossing_hold["state"] == "committed" && findtext(tiller.cross("far2"), "bound for Far One"), "with no reply from the doorman she is still bound for Far One")
	naval_check(probe_wakes_to("far2") == 0, "and Far Two is not asked")
	// The wake runs out: a terminal timeout lets her go.
	tiller.crossing_hold["until"] = world.time
	naval_check(probe_wait(other), "the wait ends at the deadline")
	naval_check(findtext(other.result, "did not answer in time") && isnull(tiller.crossing_hold) && !QDELETED(tiller), "once the wake runs out she is free and still here ([other.result])")

	// ---- Late readiness after a timeout: the same voyage crosses, nothing new is woken ----
	probe_peers()
	probe_doorman_reply = list("ok" = 1, "eta" = 0)
	mine = probe_voyage(tiller, "far1", list("probeann"))
	other = new
	other.go(tiller, "far1", mine["id"])
	sleep(3)
	tiller.crossing_hold["until"] = world.time
	probe_wait(other)
	naval_check(findtext(other.result, "did not answer in time") && tiller.voyage == mine, "the wake ran out; her voyage still holds Far One")
	probe_awake["far1"] = TRUE
	shard_group.peers["far1"]["state"] = "UP"
	var/departed_before = length(probe_departed)
	naval_check(tiller.voyage_lane_landfall(mine) && QDELETED(tiller), "Far One answers late: on her next look she crosses")
	naval_check(probe_wakes_to("far1") == 1 && probe_wakes_to("far2") == 0 && length(probe_departed) == departed_before + 1, "with no second wake")

	// ---- A same-land retry while bound sends no second word ----
	tiller = probe_ship("Skua", 40)
	var/mob/living/human/C = probe_sailor("Cat", 64, 40, "probecat")
	probe_peers()
	C.handcuffed = TRUE
	mine = probe_voyage(tiller, "far1", list("probecat"))
	other = new
	other.go(tiller, "far1", mine["id"])
	sleep(3)
	probe_awake["far1"] = TRUE
	probe_wait(other)
	naval_check(findtext(other.result, "cannot make the crossing like this") && tiller.crossing_hold && !tiller.crossing_hold["busy"], "a crew problem after the wake keeps her bound ([other.result])")
	naval_check(findtext(tiller.voyage_turn_back(C), "cannot turn back now"), "she still cannot turn back")
	C.handcuffed = null
	naval_check(isnull(tiller.cross("far1", null, mine["id"])) && probe_wakes_to("far1") == 1, "the retry crosses on the first wake")

	// ---- Courses on the world chart: plotting holds her too ----
	tiller = probe_ship("Gull", 50)
	A = probe_sailor("Ann", 64, 50, "probeann")
	B = probe_sailor("Bea", 66, 52, "probebea")
	probe_peers()
	probe_requests = list()
	probe_bridge_reply = null
	probe_bridge_delay = 5
	var/datum/probe_crossing/plot = new
	plot.set_out(tiller, A, 1, 2)
	sleep(1)
	naval_check(tiller.crossing_hold && tiller.crossing_hold["state"] == "plotting", "her course is held while the world chart is asked")
	naval_check(!tiller.set_out(B, "course", 6, 3, "crew:probe", 2, "another land") && findtext(tiller.cross("far2"), "being sent"), "another course or crossing waits for it")
	probe_wait(plot)
	naval_check(plot.result && tiller.voyage && tiller.voyage["unconfirmed"] && isnull(tiller.crossing_hold), "with no answer she sails on her course, unconfirmed")
	naval_check(length(probe_requests) == 1, "only her own course was asked ([length(probe_requests)])")
	probe_bridge_delay = 0
	probe_bridge_reply = list("ok" = 1)
	mine = tiller.voyage
	mine["asked"] = world.time
	world_chart = list("courses" = list())
	tiller.voyage_refused_under_way(mine)
	var/list/again = probe_requests[length(probe_requests)]
	naval_check(length(probe_requests) == 2 && again["voyage"] == mine["id"] && again["x"] == 1 && again["y"] == 2 && !mine["unconfirmed"], "under way she asks after the same course with the same voyage")
	// Scouting and turning back before any word is sent stay as they were.
	naval_check(isnull(tiller.voyage_turn_back(A)) && isnull(tiller.voyage), "before landfall Turn back still works")
	naval_check(tiller.set_out(A, "scout", 4, 3, "crew:probe", 8, "the unknown water") && tiller.voyage["kind"] == "scout" && length(probe_requests) == 2, "a scouting voyage asks the world chart nothing")
	tiller.end_voyage(null)
	naval_check(probe_wakes_to("far1") == 0 && probe_wakes_to("far2") == 0, "no world was woken for any of it")

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
