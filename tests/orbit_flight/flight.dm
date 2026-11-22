// Local two-world flight test. Test-only: tests/orbit_flight/native_flight.py appends it
// to a temporary copy of civ13.dme for each world and starts both worlds with
// their own transfer agents. flight.json in the world's folder says which side
// this is. Nothing runs without it.
//
// The mainland ("gaia") sets a pad for orbit, builds a launch complex office
// beside it, gives it a station plan sheet and every delivery, and sends a crew
// of two up through the office. The orbit world waits for them, checks that
// the station was founded from the plan (not the starter), and sends the crew
// home through the return capsule hatch. The mainland waits for them at the
// office. Each side writes result-<role>.json and keeps running until native_flight.py
// stops it.
var/global/datum/orbit_flight_test/orbit_flight_test = new

/datum/orbit_flight_test
	var/role = null
	var/phase = "startup"
	var/list/checks = list()
	var/list/crew_keys = list("flightone", "flighttwo")
	var/faction = "Skyward"
	var/plan_name = "hub station"
	var/started_at = 0
	// The first failed requirement, kept here as well as thrown.
	var/failed_with = null

/datum/orbit_flight_test/New()
	if (!fexists("flight.json"))
		return
	var/list/S = json_decode(file2text("flight.json"))
	role = S["role"]
	started_at = world.timeofday
	spawn(50)
		drive()

/datum/orbit_flight_test/proc/pass(name, details = null)
	checks += list(list("check" = name, "passed" = TRUE, "details" = details, "at" = round((world.timeofday - started_at) / 10)))
	world.log << "FLIGHT [role]: [name] [isnull(details) ? "" : json_encode(details)]"

/datum/orbit_flight_test/proc/require(condition, message)
	if (!condition)
		if (!failed_with)
			failed_with = message
		throw EXCEPTION(message)

/datum/orbit_flight_test/proc/wait_until(callable, deciseconds, message)
	var/until = world.time + deciseconds
	while (!call(src, callable)())
		if (world.time > until)
			throw EXCEPTION(message)
		sleep(10)

/datum/orbit_flight_test/proc/scheduler_ready()
	return ticker && processScheduler && processes && ticker.current_state >= GAME_STATE_PREGAME

/datum/orbit_flight_test/proc/game_playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/orbit_flight_test/proc/bridge_ready()
	return transfer_bridge.ready()

/datum/orbit_flight_test/proc/peer()
	return role == "gaia" ? "orbit" : "gaia"

/datum/orbit_flight_test/proc/peer_up()
	var/id = peer()
	shard_group.poll_peer(id)
	var/list/P = shard_group.peers[id]
	return P && P["state"] == "UP"

/datum/orbit_flight_test/proc/crew()
	. = list()
	for (var/mob/living/human/H in human_mob_list)
		if (!QDELETED(H) && (H.persistence_owner_ckey in crew_keys))
			. += H

/datum/orbit_flight_test/proc/crew_here()
	return length(crew()) == length(crew_keys)

/datum/orbit_flight_test/proc/hub_plan()
	for (var/datum/station_plan/D in station_plan_examples())
		if (D.name == plan_name)
			return D
	return null

// Each module relative to the command module, as "dcol,drow,key", sorted.
/datum/orbit_flight_test/proc/relative(datum/station_plan/D)
	var/list/C = splittext(D.piece_cells("C")[1], ",")
	. = list()
	for (var/at in D.cells)
		var/list/xy = splittext(at, ",")
		. += "[text2num(xy[1]) - text2num(C[1])],[text2num(xy[2]) - text2num(C[2])],[D.cells[at]]"
	. = sortList(.)

/datum/orbit_flight_test/proc/drive()
	var/failure = null
	try
		phase = "startup"
		wait_until("scheduler_ready", 9000, "the scheduler never became ready")
		pass("scheduler_ready", round((world.timeofday - started_at) / 10))
		// The mainland waits in the lobby for an admin; other regions start on their own.
		var/autostarts = shard_group.autostarts_round()
		if (!autostarts)
			ticker.admin_started = TRUE
		if (ticker.pregame_timeleft > 1)
			ticker.pregame_timeleft = 1
		wait_until("game_playing", 6000, "the round never started")
		pass("round_playing", list("autostarted" = autostarts))
		phase = "bridge"
		wait_until("bridge_ready", 3000, "the transfer agent never reconciled the world")
		pass("bridge_reconciled")
		phase = "peer"
		wait_until("peer_up", 6000, "[peer()] never answered as UP")
		pass("peer_up", peer())
		if (role == "gaia")
			mainland()
		else
			orbit()
		var/list/last = checks[checks.len]
		var/expected = role == "gaia" ? "crew_home" : "station_kept"
		if (last["check"] != expected)
			failure = failed_with || "the driver stopped after [last["check"]] in phase [phase]"
	catch (var/exception/E)
		failure = failed_with || "[E.name]"
	var/list/result = list("role" = role, "passed" = isnull(failure), "failure" = failure, "failed_phase" = failure ? phase : null, "checks" = checks)
	// native_flight.py stops both worlds once each side has written its result.
	text2file(json_encode(result), "result-[role].json")
	world.log << "FLIGHT [role]: done [isnull(failure) ? "PASS" : "FAIL [failure]"]"

// ---------------------------------------------------------------- mainland

/datum/orbit_flight_test/proc/mainland()
	phase = "site"
	map.ordinal_age = ORBIT_MIN_AGE
	// An open site near the middle of the surface: the pad, the crew's tile
	// and the office in a row.
	var/cx = round(world.maxx / 2)
	var/cy = round(world.maxy / 2)
	for (var/turf/T in block(locate(cx - 3, cy - 3, 1), locate(cx + 5, cy + 3, 1)))
		for (var/obj/O in T)
			if (!istype(O, /obj/effect))
				qdel(O)
		if (T.density || !istype(T, /turf/floor/grass))
			T.ChangeTurf(/turf/floor/grass)
	var/turf/pad_turf = locate(cx, cy, 1)
	var/turf/crew_turf = locate(cx + 1, cy, 1)
	var/obj/structure/region_gate/trail_marker/launch_pad/pad = new(pad_turf)
	require(pad.approve("orbit", "flight test"), "the pad would not set for orbit")
	var/obj/structure/region_gate/launch_complex/office = new(locate(cx + 2, cy, 1))
	require(office.launch_pad() == pad, "the office does not see the pad")
	pass("pad_and_office", list("x" = cx, "y" = cy))

	phase = "crew"
	var/datum/station_plan/D = hub_plan()
	require(D && !length(D.problems()), "the [plan_name] example is not launchable")
	var/list/crew = list()
	for (var/key in crew_keys)
		var/mob/living/human/H = new(crew_turf)
		H.persistence_owner_ckey = key
		H.real_name = "Test pilot [key]"
		H.name = H.real_name
		H.civilization = faction
		H.known_recipe_nodes = D.nodes() | list("orbital_flight", "crewed_flight")
		H.recipe_knowledge_initialized = TRUE
		crew += H
	// The faction has researched what the plan needs, as a playing faction
	// would have by 1969.
	for (var/node_id in D.nodes())
		map.complete_node(faction, node_id)
	var/mob/living/human/lead = crew[1]
	for (var/node_id in D.nodes())
		require(research_node_known(lead, node_id), "the crew does not know [node_id]")
	var/party = party_train_party_of(lead)
	require(party == party_train_faction_party(faction), "crew party [party]")
	pass("crew", list("party" = party, "nodes" = D.nodes()))

	phase = "project"
	// start() asks the player through a prompt; the test takes the same checks.
	var/reason = office.start_refusal(lead, party)
	require(!reason, "the office refused the project: [reason]")
	office.party = party
	var/obj/item/ship_draught/sheet = new(crew_turf)
	sheet.take_station(D)
	require(sheet.station_plan_kind(), "the sheet does not hold a station plan")
	require(office.take_plan(lead, sheet), "the office refused the plan: [office.plan_refusal(lead, D)]")
	require(office.plan_code == D.to_code(), "office plan [office.plan_code]")
	var/list/needs = office.requirements()
	var/list/costs = D.costs()
	var/list/asked = list()
	for (var/kind in needs)
		var/list/need = needs[kind]
		asked[kind] = need[2]
		require(need[2] == costs[kind], "office asks [need[2]] [kind], the plan costs [costs[kind]]")
	pass("plan_taken", list("code" = office.plan_code, "needs" = asked))

	phase = "deliveries"
	var/stacks = 0
	for (var/kind in needs)
		var/list/need = needs[kind]
		var/stack_type = need[1]
		var/left = need[2]
		while (left > 0)
			var/obj/item/stack/S = new stack_type(crew_turf)
			S.amount = min(left, S.max_amount)
			left -= S.amount
			office.attackby(S, lead)
			stacks++
			require(stacks < 200, "deliveries never finished")
	require(office.completed, "the office is not complete: [office.progress_text()]")
	pass("station_ready", list("stacks" = stacks, "progress" = office.progress_text()))

	phase = "launch"
	require(!office.closed_reason(), "the office is closed: [office.closed_reason()]")
	// travel_refusal() wants a player's client; a host agent sends test
	// characters through depart() as travel() does after it.
	for (var/mob/living/human/H in crew)
		require(party_train_may_board(H, office.party), "[H.persistence_owner_ckey] is not of the office's party")
	// Each member sets off through depart(), as travel() does once the player
	// says yes. The agent takes one trip at a time, so a member who finds the
	// trail busy tries again, as a player would.
	var/departed = 0
	for (var/mob/living/human/H in crew)
		var/key = H.persistence_owner_ckey
		var/result = null
		for (var/attempt in 1 to 30)
			result = office.depart(H)
			if (result == "departed")
				break
			sleep(10)
		require(result == "departed", "[key] did not leave: [result]")
		departed++
	require(office.boarded, "the office did not mark the station boarded")
	pass("launched", list("crew" = departed))

	phase = "return"
	wait_until("crew_here", 9000, "the crew never came home")
	var/list/home = crew()
	for (var/mob/living/human/H in home)
		require(get_turf(H) == get_turf(office), "[H.persistence_owner_ckey] came home at [H.x],[H.y],[H.z], not the office")
		require(H.region_arrival_pending, "[H.persistence_owner_ckey] is not waiting for their player")
	pass("crew_home", list("at" = "[office.x],[office.y],[office.z]"))

// ---------------------------------------------------------------- orbit

/datum/orbit_flight_test/proc/orbit()
	phase = "arrival"
	wait_until("crew_here", 9000, "the crew never arrived in orbit")
	var/list/crew = crew()
	var/mob/living/human/lead = crew[1]
	var/party = lead.party_train_party
	require(party_train_valid_party(party), "arrived without a party: [party]")
	var/obj/structure/region_gate/station_hatch/hatch = orbit_station_hatch(party)
	require(hatch, "no return hatch for [party]")
	for (var/mob/living/human/H in crew)
		require(get_turf(H) == get_turf(hatch), "[H.persistence_owner_ckey] arrived at [H.x],[H.y],[H.z], not the hatch")
	pass("crew_aboard", list("party" = party, "plane" = hatch.z))

	phase = "station"
	var/z = hatch.z
	var/datum/station_plan/D = hub_plan()
	var/list/kinds = list()
	var/sealed = 0
	for (var/obj/structure/habitat_core/M in orbit_station_modules(z))
		kinds += M.kind
		if (!M.breaches())
			sealed++
	require(length(kinds) == D.module_count(), "[length(kinds)] modules built, the plan has [D.module_count()] (starter fallback?)")
	require(sealed == length(kinds), "[length(kinds) - sealed] modules are breached")
	var/obj/structure/orbit_console/console = locate() in orange(2, hatch)
	require(console, "no console beside the hatch")
	var/survey = station_plan_survey(z)
	require(!istext(survey), "the console survey failed: [survey]")
	var/datum/station_plan/drawn = survey
	var/want = jointext(relative(D), " ")
	var/got = jointext(relative(drawn), " ")
	require(got == want, "the station is [got], the plan is [want]")
	require(hatch.home_region == "gaia", "the hatch leads to [hatch.home_region]")
	pass("station_from_plan", list("plane" = z, "modules" = kinds, "layout" = got))

	phase = "way_home"
	require(!hatch.closed_reason(), "the hatch is closed: [hatch.closed_reason()]")
	for (var/mob/living/human/H in crew)
		require(party_train_may_board(H, hatch.party), "[H.persistence_owner_ckey] is not of the station's party")
	var/departed = 0
	for (var/mob/living/human/H in crew)
		var/key = H.persistence_owner_ckey
		var/result = null
		for (var/attempt in 1 to 30)
			result = hatch.depart(H)
			if (result == "departed")
				break
			sleep(10)
		require(result == "departed", "[key] did not leave: [result]")
		departed++
	pass("left_for_home", list("crew" = departed))
	// The station stays on its plane for the next flight.
	require(orbit_station_hatch(party) == hatch, "the station went with the crew")
	pass("station_kept")
