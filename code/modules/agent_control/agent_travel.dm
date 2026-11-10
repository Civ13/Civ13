// Region travel for agent characters (docs/agent-control.md#travel).
//
// A player walks through a region gate and joins the destination with their
// BYOND account. An agent's own character has no account, so it travels under
// an agent account, "agent@" + the agent's name: no BYOND ckey holds "@", so it
// never names a player. The gate records where the character went; at the
// destination, the same agent's character_list takes the arrived body back
// (and any body of that account found after a reload).

#define AGENT_DEPARTURES_MAX 20

var/global/list/agent_departures = list()

// The account an agent's own character travels under, or null. Opted-in
// player characters travel only with their player, so they have none.
/proc/agent_travel_account(mob/living/human/H)
	if (!istype(H) || H.client)
		return null
	var/datum/agent_character/C = agent_character_for(H)
	if (!C || !C.owner_agent || C.handover_ckey)
		return null
	return agent_account_for(C.owner_agent)

/proc/agent_account_for(agent_name)
	var/name = copytext(ckey("[agent_name]"), 1, 27)
	return length(name) ? "agent@[name]" : null

// Called by the gate before it deletes the departing body.
/proc/agent_note_departure(mob/living/human/H, destination, destination_name)
	var/datum/agent_character/C = agent_character_for(H)
	if (!C || !C.owner_agent)
		return
	var/list/row = list("agent" = C.owner_agent, "name" = H.real_name, "ref" = agent_ref(H), "account" = H.persistence_owner_ckey,
		"destination" = destination, "destination_name" = destination_name, "time" = world.time)
	var/list/peer = shard_group && shard_group.enabled ? shard_group.peers[destination] : null
	if (peer && istext(peer["address"]))
		row["address"] = peer["address"]
	agent_departures += list(row)
	if (agent_departures.len > AGENT_DEPARTURES_MAX)
		agent_departures.Cut(1, 2)
	game_log("AGENT", "[C.owner_agent]'s character [H.real_name] left for [destination]")

/proc/agent_departure_rows(agent_name)
	. = list()
	for (var/list/row in agent_departures)
		if (row["agent"] == agent_name)
			. += list(row.Copy())

// Bodies of this agent's account that no agent drives yet (an arrival, or a
// body a reload restored) become its characters again.
/datum/agent_control/proc/adopt_travellers(datum/agent_identity/A)
	var/account = agent_account_for(A.name)
	if (!account)
		return
	for (var/mob/living/human/H in human_mob_list)
		if (H.persistence_owner_ckey != account || H.client || H.key || H.stat == DEAD || QDELETED(H) || agent_characters[H])
			continue
		var/owned = 0
		for (var/mob/M in agent_characters)
			var/datum/agent_character/O = agent_characters[M]
			if (O.owner_agent == A.name)
				owned++
		if (owned >= max_characters)
			return
		if (!H.mind)
			var/datum/mind/agent_mind = new /datum/mind("agent_[A.name]")
			agent_mind.name = H.real_name
			agent_mind.original = H
			agent_mind.transfer_to(H)
		H.region_arrival_pending = FALSE
		var/datum/agent_character/C = new
		C.body = H
		C.owner_agent = A.name
		agent_characters[H] = C
		var/turf/T = get_turf(H)
		audit(A, "character_arrived", "[H] ([agent_ref(H)]) at [T ? "[T.x],[T.y],[T.z]" : "nowhere"]")

#undef AGENT_DEPARTURES_MAX
