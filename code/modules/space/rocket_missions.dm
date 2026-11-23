// ============================================================
// Uncrewed rocket missions (docs/rocket-plans.md)
// ------------------------------------------------------------
// What a modular rocket (rocket_works.dm) does at launch follows its payload:
//
// - A crew capsule: the crew fly to orbit (lander.dm, orbital_flight.dm).
// - Cargo bays and no capsule: a heavy cargo launch. The hold flies to the
//   pad's orbit as freight (orbit_freight.dm) and lands beside the
//   launcher's party station hatch, or at the usual arrival point. It needs
//   the orbit leg with the hold actually loaded.
// - A probe and no capsule: a one-way lunar probe. It needs the lunar
//   transfer and landing legs, an idle mission console near the rocket and
//   the Moon's survey map. It lands anywhere flat (that landing is recorded
//   as a surveyed site crews can land at) and maps the Moon from the console
//   until the mission is abandoned: it has no ascent stage.
//
// Each mission spends the rocket; a first stage with landing legs still
// flies back (rocket_reuse.dm).
// ============================================================

#define ROCKET_PROBE_CONSOLE_RANGE 7
#define ROCKET_PROBE_REGION "moon"

// "crew", "cargo", "probe", or null for a rocket with no payload.
/obj/structure/crewed_lander/modular_rocket/proc/mission_kind()
	var/datum/rocket_plan/D = plan()
	if (!D)
		return null
	. = null
	if (D.count("C"))
		. = "crew"
	else if (D.count("Q"))
		. = "probe"
	else if (D.count("K"))
		. = "cargo"
	qdel(D)

// Names this rocket's cargo flight, so a world that reloads a save from
// before the launch finds it again (orbit_freight_replay_departure).
/obj/structure/crewed_lander/modular_rocket/var/rocket_id = null

// Every rocket on the stands of this world, for replays.
/proc/modular_rockets()
	var/static/list/rockets
	if (!rockets)
		rockets = list()
	return rockets

/obj/structure/crewed_lander/modular_rocket/New()
	..()
	var/list/rockets = modular_rockets()
	rockets |= src

/obj/structure/crewed_lander/modular_rocket/proc/flight_id()
	if (!rocket_id)
		rocket_id = "rocket-[shard_group && shard_group.region ? shard_group.region : "world"]-[num2text(world.realtime, 20)]-[rand(1000, 9999)]"
	return rocket_id

// Why the stack cannot fly at all, or null: unfinished or unfit sections.
/obj/structure/crewed_lander/modular_rocket/proc/stack_refusal()
	if (!complete())
		return "\The [src] is not finished: mount every section first."
	for (var/obj/structure/rocket_section/S in sections())
		var/reason = S.mount_refusal()
		if (reason)
			return reason
	if (propellant < propellant_needed)
		return "\The [src] needs [propellant_needed] units of rocket propellant or methalox ([propellant] loaded)."
	return null

/obj/structure/crewed_lander/modular_rocket/launch_prompt(mob/living/human/H)
	switch (mission_kind())
		if ("crew")
			return ..()
		if ("cargo")
			return cargo_prompt(H)
		if ("probe")
			return probe_prompt(H)
	to_chat(H, SPAN_WARNING("\The [src] carries no capsule, cargo bay or probe: there is nothing to fly."))

// ---------------------------------------------------------------- heavy cargo

/obj/structure/crewed_lander/modular_rocket/proc/cargo_refusal(mob/living/human/H)
	var/obj/structure/region_gate/trail_marker/launch_pad/pad = find_pad()
	if (!pad)
		return "\The [src] must stand beside a launch pad."
	var/reason = pad.closed_reason() || stack_refusal()
	if (reason)
		return reason
	if (!space_flight_orbit_ok(pad.destination))
		return "A cargo rocket flies to orbit. Point the pad at an orbit to launch it."
	if (!length(hold()))
		return "The cargo bays are empty."
	var/datum/rocket_plan/D = plan()
	var/list/L = D.legs(cargo_tonnes())
	var/list/orbit = L[ROCKET_LEG_ORBIT]
	qdel(D)
	if (!orbit["ok"])
		return "The launch planner says it cannot reach orbit with this load: [orbit["why"]]."
	if (!istype(H) || !H.client || IsGuestKey(H.client.key))
		return "Only players with a BYOND account can launch a cargo rocket."
	if (!party_train_party_of(H))
		return "You have no party to send it for."
	if (persistence_save_active())
		return "The world is saving. Try again in a moment."
	if (!transfer_bridge.ready() || !(pad.destination in transfer_bridge.peers))
		return "The flight network is down. Try again later."
	return null

/obj/structure/crewed_lander/modular_rocket/proc/cargo_prompt(mob/living/human/H)
	var/reason = cargo_refusal(H)
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	var/obj/structure/region_gate/trail_marker/launch_pad/pad = find_pad()
	var/region = pad.destination
	if (WWinput(H, "Launch \the [src] with [length(hold())] item\s in its bays to your party's station at [pad.destination_name()]? The rocket is spent.", "Launch", "Cancel", list("Launch", "Cancel")) != "Launch")
		return
	if (QDELETED(src) || !H.client || !in_range(src, H))
		return
	reason = cargo_refusal(H)
	if (!reason && (find_pad() != pad || pad.destination != region))
		reason = "The launch pad changed."
	if (!reason)
		reason = launch_cargo(pad, H)
	if (reason)
		to_chat(H, SPAN_WARNING(reason))

// Sends the bays to the pad's orbit for H's party. Null once it left.
/obj/structure/crewed_lander/modular_rocket/proc/launch_cargo(obj/structure/region_gate/trail_marker/launch_pad/pad, mob/living/human/H)
	var/destination = pad.destination
	var/party = party_train_party_of(H)
	if (!party)
		return "You have no party to send it for."
	var/list/cargo = pack_cargo()
	if (!length(cargo))
		return "Nothing in the bays can make the flight."
	var/turf/T = get_turf(src)
	var/payload = orbit_freight_payload(flight_id(), party, T, cargo, H && H.client ? H.client.ckey : null)
	if (!orbit_freight_decode(payload))
		return "Something in the bays cannot make the flight. Ask an admin."
	var/list/back = flyback_records()
	var/list/result = transfer_bridge.begin_escrow(destination, list(payload), TRUE)
	if (!result)
		return "The flight network is busy. Try again in a moment."
	if (QDELETED(src))
		return null
	for (var/obj/item/I in hold())
		qdel(I)
	visible_message(SPAN_DANGER("\The [src] roars off the pad on a column of fire!"))
	log_game("Modular rocket: cargo flight [rocket_id] left [T.x],[T.y],[T.z] for [destination] with [length(cargo)] item\s for [party].")
	qdel(src)
	rocket_flyback_land(T, back)
	return null

// A replayed departure finds the rocket that flew by its saved id.
/proc/rocket_cargo_replay_departure(id)
	for (var/obj/structure/crewed_lander/modular_rocket/R in modular_rockets().Copy())
		if (R.rocket_id != id || QDELETED(R))
			continue
		for (var/obj/item/I in R.hold())
			qdel(I)
		qdel(R)
		log_game("Modular rocket: replayed cargo flight [id]'s departure.")

// ---------------------------------------------------------------- lunar probe

/obj/structure/crewed_lander/modular_rocket/proc/probe_console()
	for (var/obj/structure/survey_console/C in range(ROCKET_PROBE_CONSOLE_RANGE, src))
		if (!C.mission && !QDELETED(C))
			return C
	return null

/obj/structure/crewed_lander/modular_rocket/proc/probe_refusal()
	if (!find_pad())
		return "\The [src] must stand beside a launch pad."
	var/reason = stack_refusal() || survey_region_closed_reason(ROCKET_PROBE_REGION)
	if (reason)
		return reason
	var/datum/rocket_plan/D = plan()
	var/list/L = D.legs(cargo_tonnes())
	qdel(D)
	for (var/leg in list(ROCKET_LEG_ORBIT, ROCKET_LEG_TRANSFER, ROCKET_LEG_LANDING))
		var/list/entry = L[leg]
		if (!entry["ok"])
			return "The launch planner says the probe cannot reach the Moon's surface: [lowertext(entry["name"])] - [entry["why"]]."
	if (!get_space_survey_map(ROCKET_PROBE_REGION))
		return "There is no survey map of the Moon to land by."
	if (!probe_console())
		return "No idle mission console within [ROCKET_PROBE_CONSOLE_RANGE] tiles to fly the probe from."
	return null

/obj/structure/crewed_lander/modular_rocket/proc/probe_prompt(mob/living/human/H)
	var/reason = probe_refusal()
	if (reason)
		to_chat(H, SPAN_WARNING(reason))
		return
	if (WWinput(H, "Launch \the [src]'s probe to the Moon? It lands anywhere flat, records the site for crewed landings and maps the Moon from the mission console until you abandon it. It never comes back, and the rocket is spent.", "Launch", "Cancel", list("Launch", "Cancel")) != "Launch")
		return
	if (QDELETED(src) || !H.client || !in_range(src, H))
		return
	reason = probe_refusal() || launch_probe()
	if (reason)
		to_chat(H, SPAN_WARNING(reason))

// Starts the probe's mission at a console nearby. Null once it flew.
/obj/structure/crewed_lander/modular_rocket/proc/launch_probe()
	var/obj/structure/survey_console/C = probe_console()
	var/datum/survey_map/M = get_space_survey_map(ROCKET_PROBE_REGION)
	if (!C || !M)
		return "No idle mission console or survey map."
	var/obj/item/space_probe/P = new(null)
	P.name = "lunar probe"
	// The probe rides on its rocket: no relay drops beyond the console's own.
	if (!C.begin_mission(P, M))
		qdel(P)
		return "There is no flat ground to land on."
	qdel(P)
	C.one_way = TRUE
	C.sample_capacity = 0
	var/turf/T = get_turf(src)
	var/list/back = flyback_records()
	for (var/obj/item/I in hold())
		qdel(I)
	visible_message(SPAN_DANGER("\The [src] roars off the pad, bound for the Moon!"))
	C.visible_message(SPAN_NOTICE("\The [C] picks up the lunar probe: it has landed at [C.land_x],[C.land_y]."))
	log_game("Modular rocket: lunar probe landed at [C.land_x],[C.land_y] for the console at [C.x],[C.y],[C.z].")
	qdel(src)
	rocket_flyback_land(T, back)
	return null

#undef ROCKET_PROBE_CONSOLE_RANGE
#undef ROCKET_PROBE_REGION
