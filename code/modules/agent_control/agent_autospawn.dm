// A character for an agent every round. An "autospawn <agent> <name> [goal]"
// line in config/agent-control.txt (docs/agent-control.md) makes the world
// spawn that agent a character at round start on whatever land it runs, and
// again later in the round if that character has died. The character waits for
// a driver exactly like one from the Spawn AI Character verb, so an autopilot
// started with --watch for the agent takes it over.
//
// A persistent world restores the body it saved: the spawned body belongs to
// the agent's account (agent@<name>), so a restored one is re-adopted instead
// of a second one being spawned.

#define AGENT_AUTOSPAWN_FIRST_DELAY 600 // ds after round start: lets a persistent world finish restoring bodies
#define AGENT_AUTOSPAWN_RECHECK 12000 // ds between checks for a dead character

/proc/agent_autospawn_default_goal()
	return "Survive, explore, gather food and be friendly to other players."

var/global/agent_autospawn_started = FALSE

/hook/roundstart/proc/agent_autospawn_start()
	agent_autospawn_begin()
	return TRUE

// A round a persistent world restores resumes without the round start hooks
// (restore_round_state), so the loop starts with the world and waits for a
// round that is playing, fresh or restored. It starts once per world.
/hook/startup/proc/agent_autospawn_watch()
	agent_autospawn_begin()
	return TRUE

/proc/agent_autospawn_begin()
	if (agent_autospawn_started)
		return
	agent_autospawn_started = TRUE
	spawn(0)
		while (!ticker || ticker.current_state < GAME_STATE_PLAYING)
			sleep(50)
		sleep(AGENT_AUTOSPAWN_FIRST_DELAY)
		while (agent_control)
			// Bodies are only adoptable once a load or save in flight has finished.
			while (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
				sleep(50)
			agent_control.autospawn_all()
			sleep(AGENT_AUTOSPAWN_RECHECK)

/datum/agent_control/proc/autospawn_all()
	reload()
	for (var/agent_name in autospawns)
		try
			autospawn_one(agent_name)
		catch(var/exception/E)
			world.log << "agent-control: autospawn for [agent_name] failed: [istype(E) && E.name == "agent_control_error" ? E.desc : "[E]"]"

// The agent's living character, adopting a restored or arrived body first.
/datum/agent_control/proc/autospawn_living(datum/agent_identity/A)
	adopt_travellers(A)
	prune_characters()
	for (var/mob/living/M in agent_characters)
		var/datum/agent_character/C = agent_characters[M]
		if (C.owner_agent == A.name && M.stat != DEAD && !QDELETED(M))
			return C
	return null

/datum/agent_control/proc/autospawn_one(agent_name)
	var/datum/agent_identity/A = agents[agent_name]
	var/list/entry = autospawns[agent_name]
	if (!A || !entry || !A.has_scope("characters"))
		return null
	if (autospawn_living(A))
		return null
	var/list/req = list("name" = entry["name"])
	var/list/jobs = agent_map_jobs()
	var/datum/job/job
	if (jobs.len)
		req["job"] = ("Nomad" in jobs) ? "Nomad" : jobs[1]
		job = job_master.GetJob(req["job"])
	var/turf/T = autospawn_turf(job)
	if (!T)
		world.log << "agent-control: autospawn for [agent_name] found no place to start"
		return null
	req["target"] = "turf:[T.x],[T.y],[T.z]"
	// A land that starts nomads on random open ground (nomads_start.dm) has no spawn point to send the job to.
	if (job && map && map.uses_random_new_player_spawn(job))
		req["stay"] = TRUE
	var/list/state = act_character_spawn(A, req)
	var/mob/living/M = locate(state["ref"])
	var/datum/agent_character/C = agent_characters[M]
	if (!C)
		return null
	if (ishuman(M))
		var/mob/living/human/H = M
		H.persistence_owner_ckey = agent_account_for(agent_name)
	C.awaiting_driver = TRUE
	C.requested_goal = entry["goal"]
	message_admins("[M] was spawned for agent [agent_name] (autospawn).")
	return C

/datum/agent_control/proc/autospawn_turf(datum/job/job)
	if (job && istype(map, /obj/map_metadata/nomads) && map.uses_random_new_player_spawn(job))
		var/obj/map_metadata/nomads/N = map
		var/turf/ground = N.pick_new_player_ground()
		if (ground)
			return ground
	// The job's own spawn point, then the ordinary late-join spots; never a special-purpose landmark.
	var/list/spots = list("JoinLateCiv", "JoinLate")
	if (job && job.spawn_location)
		spots.Insert(1, job.spawn_location)
	for (var/spot in spots)
		var/list/starts = latejoin_turfs ? latejoin_turfs[spot] : null
		if (length(starts))
			return pick(starts)
	return null

#undef AGENT_AUTOSPAWN_FIRST_DELAY
#undef AGENT_AUTOSPAWN_RECHECK
