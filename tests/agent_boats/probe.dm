/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 40
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/boat_failures = 0
var/boat_checks = 0
var/boat_runtime_error = FALSE
/obj/map_metadata/boat_probe/New()
	return
/proc/boat_check(condition, label)
	boat_checks++
	if (!condition)
		boat_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	boat_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		movementMachine = new
		map = new /obj/map_metadata/boat_probe
		if (!all_species.len)
			makeDatumRefLists()
		boat_ground()
		boat_route_checks()
		boat_raft_checks()
		boat_motor_checks()
		agent_player_action_checks()
		boat_unconscious_checks()
	catch(var/exception/e)
		boat_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("checks" = boat_checks, "failures" = boat_failures, "runtime_error" = boat_runtime_error)), "result.json")
	del(world)

// Grass, with a river running north-south: shallow water at x 18, deep water at x 19-22.
/proc/boat_ground()
	var/area/A = get_area(locate(1, 1, 1))
	A.location = AREA_OUTSIDE
	A.climate = "temperate"
	for (var/turf/T in block(locate(1, 1, 1), locate(40, 40, 1)))
		if (T.x == 18)
			T.ChangeTurf(/turf/floor/beach/water, FALSE, FALSE)
		else if (T.x >= 19 && T.x <= 22)
			T.ChangeTurf(/turf/floor/beach/water/deep, FALSE, FALSE)
		else
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)

/proc/boat_character(x, y, name)
	var/mob/living/human/H = new(locate(x, y, 1))
	H.name = name
	var/datum/agent_character/C = new
	C.body = H
	C.owner_agent = "probe"
	agent_characters[H] = C
	return C

/proc/boat_identity()
	var/static/datum/agent_identity/A
	if (!A)
		A = new
		A.name = "probe"
		A.scopes = list("characters")
	return A

/proc/boat_step(datum/agent_character/C, list/req)
	try
		var/list/result = agent_control.perform_step(boat_identity(), C, req, TRUE)
		return result
	catch(var/exception/e)
		return "[e.desc || e.name]"

/proc/boat_route(datum/agent_character/C, x, y)
	try
		return agent_control.act_character_route(boat_identity(), list("character" = agent_ref(C.body), "x" = x, "y" = y))
	catch(var/exception/e)
		return "[e.desc || e.name]"

/proc/boat_route_checks()
	boat_check(agent_deep_water(locate(20, 20, 1)), "open deep water is deep")
	boat_check(!agent_deep_water(locate(18, 20, 1)), "shallow water is walkable")
	var/datum/agent_character/C = boat_character(10, 20, "Router")
	var/list/route = boat_route(C, 30, 20)
	boat_check(islist(route) && route["reachable"] && route["needs_boat"], "a river without a bridge needs a boat")
	if (islist(route))
		boat_check(route["launch"] ~= list(17, 20), "the raft launches from the last dry tile ([json_encode(route["launch"])])")
		boat_check(route["landing"] ~= list(23, 20), "it lands on the first dry tile ([json_encode(route["landing"])])")
		var/list/legs = route["legs"]
		boat_check(legs.len == 3 && legs[1]["mode"] == "walk" && legs[2]["mode"] == "boat" && legs[3]["mode"] == "walk", "walk, boat, walk")
		if (legs.len == 3)
			boat_check(legs[1]["moves"] == "eeeeeee", "walk to the shore ([legs[1]["moves"]])")
			boat_check(legs[2]["moves"] == "eeeee", "the boat takes the shallows too ([legs[2]["moves"]])")
			boat_check(legs[3]["moves"] == "eeeeeeee", "walk on from the landing ([legs[3]["moves"]])")
		var/list/raft = route["raft"]
		boat_check(islist(raft) && raft["amount"] == 10 && raft["recipe"] == "raft", "the raft recipe is offered")
		var/list/boats = route["boats"]
		boat_check(islist(boats) && !boats.len, "no boat is near the launch yet")
	// A bridge makes the walk possible, and walking wins over a boat.
	for (var/x = 19, x <= 22, x++)
		var/turf/bridge = locate(x, 25, 1)
		bridge.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
	route = boat_route(C, 30, 20)
	boat_check(islist(route) && route["reachable"] && !route["needs_boat"], "a bridge is walked instead of sailing")
	for (var/x = 19, x <= 22, x++)
		var/turf/river = locate(x, 25, 1)
		river.ChangeTurf(/turf/floor/beach/water/deep, FALSE, FALSE)
	route = boat_route(C, 10, 39)
	boat_check(islist(route) && route["reachable"], "an open goal on this bank is reachable")
	route = boat_route(C, 200, 20)
	boat_check(islist(route) && route["goal"][1] == 40, "a goal off the map is clamped to its edge")
	agent_characters -= C.body
	qdel(C.body)

/proc/boat_raft_checks()
	var/datum/agent_character/C = boat_character(17, 20, "Rafter")
	var/mob/living/human/H = C.body
	var/obj/structure/vehicle/raft/R = new(locate(17, 20, 1))
	var/result = boat_step(C, list("do" = "board", "target" = agent_ref(R)))
	boat_check(islist(result) && H.driver && H.driver_vehicle == R, "boarding a raft makes the character its driver ([islist(result) ? "ok" : result])")
	var/list/state = agent_control.character_state(C)
	var/list/vehicle = state["vehicle"]
	boat_check(islist(vehicle) && vehicle["role"] == "driver" && state["can_steer"], "the state reports the raft and that it can be steered")
	var/moved = 0
	for (var/i = 1, i <= 5, i++)
		sleep(R.vehicle_m_delay + 1)
		result = boat_step(C, list("do" = "move", "dir" = "east"))
		if (islist(result) && result["moved"])
			moved++
	boat_check(moved == 5 && R.x == 22 && H.x == 22, "five steering moves cross the shallows and deep water ([moved], raft at [R.x])")
	var/list/route = boat_route(C, 10, 20)
	if (islist(route))
		var/list/legs = route["legs"]
		boat_check(route["needs_boat"] && legs[1]["mode"] == "boat", "afloat, the route home starts with a boat leg")
	sleep(R.vehicle_m_delay + 1)
	result = boat_step(C, list("do" = "move", "dir" = "east"))
	boat_check(islist(result) && result["moved"] == FALSE && R.x == 22, "a raft does not go onto land")
	result = boat_step(C, list("do" = "disembark"))
	boat_check(islist(result) && !H.driver && !H.buckled && !agent_vehicle_of(H), "disembarking leaves the raft ([islist(result) ? "ok" : result])")
	sleep(10)
	C.next_action = 0
	result = boat_step(C, list("do" = "move", "dir" = "east"))
	boat_check(H.x == 23 && R.x == 22, "the character steps ashore and the raft stays moored")
	route = boat_route(C, 10, 20)
	if (islist(route))
		var/list/boats = route["boats"]
		boat_check(islist(boats) && boats.len == 1 && boats[1]["ref"] == agent_ref(R), "the moored raft is offered for the way back")
		// A raft covers its tile, so the way back walks onto it and boards there.
		boat_check(route["launch"] ~= list(22, 20), "the way back launches from the raft's own tile ([json_encode(route["launch"])])")
		if (islist(boats) && boats.len)
			boat_check(boats[1]["board_from"] ~= list(22, 20), "it is boarded where it lies ([json_encode(boats[1]["board_from"])])")
	var/list/seen = agent_control.act_character_observe(boat_identity(), list("character" = agent_ref(H)))
	var/raft_listed = FALSE
	for (var/list/row in seen["nearby"])
		if (row["ref"] == agent_ref(R) && row["boat"])
			raft_listed = TRUE
	boat_check(raft_listed, "nearby boats carry their boat details")
	result = boat_step(C, list("do" = "board", "target" = agent_ref(R)))
	boat_check(H.driver_vehicle == R, "the moored raft can be boarded again")
	result = boat_step(C, list("do" = "board", "target" = agent_ref(R)))
	boat_check(istext(result) && findtext(result, "aboard"), "boarding twice is refused")
	boat_step(C, list("do" = "disembark"))
	agent_characters -= H

/proc/boat_motor_checks()
	var/obj/structure/vehicle/boat/b400/B = new(locate(5, 6, 1))
	sleep(5)
	boat_check(findtext(agent_vehicle_stalled(B), "fuel"), "an empty motor boat asks for fuel")
	B.fueltank.reagents.add_reagent("diesel", 50)
	boat_check(findtext(agent_vehicle_stalled(B), "engine is off"), "a fuelled boat with its engine off asks to start it")
	B.engine.on = TRUE
	boat_check(isnull(agent_vehicle_stalled(B)), "a running engine can be steered")
	var/list/row = agent_vehicle_row(B)
	boat_check(row["fuel"] == 50 && row["cargo_space"] == 1 && row["needs_free_hand"], "the boat row reports fuel, cargo space and the rudder")
	var/datum/agent_character/C = boat_character(4, 6, "Loader")
	var/obj/structure/closet/crate/crate = new(locate(4, 7, 1))
	var/result = boat_step(C, list("do" = "drag", "target" = agent_ref(crate), "onto" = agent_ref(B)))
	boat_check(islist(result) && (crate in B.ontop_o), "dragging a crate onto a boat loads it ([islist(result) ? "ok" : result])")
	var/obj/item/weapon/material/spear/far = new(locate(30, 30, 1))
	result = boat_step(C, list("do" = "drag", "target" = agent_ref(far), "onto" = agent_ref(B)))
	boat_check(istext(result) && findtext(result, "out_of_reach"), "dragging something out of reach is refused")
	B.engine.on = FALSE
	agent_characters -= C.body

// Player actions beyond clicks (code/modules/agent_control/agent_verbs.dm): verbs,
// throwing, and seeing someone else's wounds for first aid.
/proc/agent_player_action_checks()
	var/datum/agent_character/C = boat_character(30, 30, "Verber")
	var/mob/living/human/H = C.body
	var/list/state = agent_control.character_state(C)
	boat_check(islist(state["verbs"]) && ("Rest" in state["verbs"]), "the state lists the character's own verbs ([length(state["verbs"])])")
	boat_check(!("Succumb" in state["verbs"]) && !("Ghost" in state["verbs"]), "verbs that end the character are not offered")
	var/result = boat_step(C, list("do" = "verb", "name" = "rest"))
	boat_check(islist(result) && H.resting, "the Rest verb makes the character rest ([islist(result) ? "ok" : result])")
	boat_step(C, list("do" = "verb", "name" = "Rest"))
	boat_check(!H.resting, "and again stands it up")
	result = boat_step(C, list("do" = "verb", "name" = "succumb"))
	boat_check(istext(result) && findtext(result, "not_found"), "a forbidden verb is refused ([result])")
	var/obj/item/weapon/material/spear/far = new(locate(36, 36, 1))
	result = boat_step(C, list("do" = "verb", "target" = agent_ref(far), "name" = "anything"))
	boat_check(istext(result) && findtext(result, "out_of_reach"), "a far object's verbs are out of reach")
	// Held and worn items' verbs are listed as "item: verb".
	var/obj/item/stack/material/wood/held = new(get_turf(H))
	H.put_in_active_hand(held)
	state = agent_control.character_state(C)
	var/list/item_verbs = state["item_verbs"]
	boat_check(islist(item_verbs), "the state lists held and worn items' verbs ([length(item_verbs)])")
	H.drop_item()
	qdel(held)
	// Throwing: the held item lands away from the character.
	var/obj/item/stack/material/wood/logs = new(get_turf(H))
	H.put_in_active_hand(logs)
	result = boat_step(C, list("do" = "throw", "target" = agent_ref(locate(34, 30, 1))))
	sleep(10)
	// The flight itself needs the running game's throw processing; here it is enough that the throw let go of it.
	boat_check(islist(result) && isturf(logs.loc) && H.get_active_hand() != logs, "throw lets go of the held item ([islist(result) ? "ok" : result], at [logs.x],[logs.y])")
	try
		agent_control.perform_step(boat_identity(), C, list("do" = "throw", "target" = agent_ref(H)), FALSE)
		boat_check(FALSE, "a direct throw must use the queue")
	catch(var/exception/e)
		boat_check(findtext("[e.desc || e.name]", "use_queue"), "a direct throw must use the queue")
	// A hurt person next to the character shows their wounds.
	var/datum/agent_character/P = boat_character(31, 30, "Patient")
	var/mob/living/human/patient = P.body
	var/obj/item/organ/external/arm = patient.get_organ("l_arm")
	arm.status |= ORGAN_BLEEDING
	arm.take_damage(15, 0, sharp = TRUE, edge = TRUE)
	var/list/look = agent_control.act_character_observe(boat_identity(), list("character" = agent_ref(H), "radius" = 3))
	var/list/seen = null
	for (var/list/row in look["nearby"])
		if (row["ref"] == agent_ref(patient))
			seen = row
	boat_check(islist(seen) && islist(seen["wounds"]) && length(seen["wounds"]) >= 1, "a hurt person nearby carries their wounds")
	if (islist(seen) && islist(seen["wounds"]) && length(seen["wounds"]))
		var/found = FALSE
		for (var/list/wound in seen["wounds"])
			if (wound["zone"] == "l_arm" && wound["bleeding"])
				found = TRUE
		boat_check(found, "the wound rows name the bleeding arm ([json_encode(seen["wounds"])])")
	// A serious illness, a campfire and a puddle carry what boiling and treatment need.
	H.disease = TRUE
	H.disease_type = "cholera"
	H.disease_progression = 300
	state = agent_control.character_state(C)
	var/list/illness = state["illness"]
	boat_check(islist(illness) && illness["type"] == "cholera" && illness["severe"] && illness["stage"] == "worsening" && !illness["treated"], "a serious illness is in the state ([json_encode(illness)])")
	H.disease = FALSE
	H.disease_type = "none"
	var/obj/structure/oven/fireplace/fire = new(locate(29, 30, 1))
	var/obj/structure/sink/puddle/puddle = new(locate(30, 31, 1))
	look = agent_control.act_character_observe(boat_identity(), list("character" = agent_ref(H), "radius" = 3))
	var/list/fire_row = null
	var/list/puddle_row = null
	for (var/list/row in look["nearby"])
		if (row["ref"] == agent_ref(fire))
			fire_row = row
		if (row["ref"] == agent_ref(puddle))
			puddle_row = row
	boat_check(islist(fire_row) && fire_row["lit"] == FALSE && fire_row["fuel"] == 4, "a campfire row says whether it is lit and its fuel ([json_encode(fire_row)])")
	boat_check(islist(puddle_row) && puddle_row["sickness"] == 1, "a puddle is marked unclean ([json_encode(puddle_row)])")
	qdel(fire)
	qdel(puddle)
	agent_characters -= patient
	qdel(patient)
	agent_characters -= H
	qdel(H)

// Passing out or dying at the controls empties the hands: the rudder goes back
// to the boat (engine stopped), a seat's machinegun back to its seat, and a
// click picks them up again after waking.
/proc/boat_take_helm(mob/living/human/H, obj/structure/vehicle/V)
	H.forceMove(get_turf(V))
	H.put_in_active_hand(V.dwheel)
	H.driver = TRUE
	H.driver_vehicle = V
	V.driver = H
	V.ontop += H
	V.buckle_mob(H)

/proc/boat_knock_out(mob/living/human/H)
	H.Paralyse(5)
	H.handle_regular_status_updates()

/proc/boat_wake(mob/living/human/H)
	H.SetParalysis(0)
	H.sleeping = 0
	H.set_stat(CONSCIOUS)

/proc/boat_unconscious_checks()
	var/obj/structure/vehicle/boat/b400/B = new(locate(5, 30, 1))
	sleep(5)
	B.fueltank.reagents.add_reagent("diesel", 50)
	var/datum/agent_character/C = boat_character(4, 30, "Helmsman")
	var/mob/living/human/H = C.body
	boat_take_helm(H, B)
	boat_check(B.dwheel.loc == H && B.driver == H, "the helmsman holds the rudder")
	B.engine.on = TRUE
	boat_knock_out(H)
	boat_check(H.stat == UNCONSCIOUS, "the helmsman is knocked out")
	boat_check(!H.l_hand && !H.r_hand, "an unconscious helmsman's hands are empty ([H.l_hand] [H.r_hand])")
	boat_check(B.dwheel.loc == B, "the rudder goes back to the boat")
	boat_check(!B.engine.on && !B.moving, "letting go of the rudder stops the boat")
	boat_check(B.driver == H && H.buckled == B, "the helmsman stays aboard as its driver")
	boat_wake(H)
	B.attack_hand(H)
	boat_check(B.dwheel.loc == H && (H.l_hand == B.dwheel || H.r_hand == B.dwheel), "after waking, clicking the boat takes the rudder again")
	boat_check(B.driver == H && (H in B.ontop), "and the helmsman is still aboard")
	var/datum/agent_character/P = boat_character(5, 30, "Deckhand")
	var/mob/living/human/PH = P.body
	PH.forceMove(get_turf(B))
	B.currentcap = PH
	B.ontop += PH
	B.buckle_mob(PH)
	boat_check(!B.retake_controls(PH) && B.driver == H && B.dwheel.loc == H, "a passenger cannot take the rudder from a living helmsman")
	H.death()
	boat_check(B.dwheel.loc == B && !H.l_hand && !H.r_hand, "a helmsman who dies lets go of the rudder")
	boat_check(!B.driver && !H.driver && !H.driver_vehicle && !(H in B.ontop) && H.buckled != B, "a dead helmsman gives up the driver's place")
	B.attack_hand(PH)
	boat_check(B.driver == PH && PH.driver && PH.driver_vehicle == B && B.dwheel.loc == PH && B.currentcap != PH, "the passenger takes over the boat and its rudder")
	boat_check(PH.buckled == B && (PH in B.ontop), "and stays aboard")
	agent_characters -= H
	agent_characters -= PH

	var/obj/structure/vehicle/motorcycle/M = new(locate(10, 30, 1))
	var/datum/agent_character/R = boat_character(10, 31, "Rider")
	var/mob/living/human/RH = R.body
	boat_take_helm(RH, M)
	boat_check(M.dwheel.loc == RH, "the rider holds the handlebars")
	boat_knock_out(RH)
	boat_check(M.dwheel.loc == M && !RH.l_hand && !RH.r_hand, "an unconscious rider lets go of the handlebars")
	agent_characters -= RH

	var/obj/structure/bed/chair/mgunner/pkm/S = new(locate(14, 30, 1))
	var/datum/agent_character/G = boat_character(14, 30, "Gunner")
	var/mob/living/human/GH = G.body
	S.buckle_mob(GH)
	boat_check(S.mg.loc == GH, "the seated machinegunner holds the gun")
	boat_knock_out(GH)
	boat_check(S.mg.loc == S && !GH.l_hand && !GH.r_hand, "an unconscious machinegunner's gun goes back to the seat")
	boat_check(GH.buckled == S, "the machinegunner stays seated")
	boat_wake(GH)
	S.attack_hand(GH)
	boat_check(S.mg.loc == GH && GH.buckled == S, "after waking, clicking the seat takes the gun again")
	agent_characters -= GH
