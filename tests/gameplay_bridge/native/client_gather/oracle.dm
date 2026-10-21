// Passive, private fixture output only. No constructor, authority or mechanic overrides.
// Normal clients, consent, native local R_ADMIN assignment and controller are external.
/hook/startup/proc/client_gather_fixture_start()
	var/datum/gameplay_client_gather_observer/probe = new
	spawn(0)
		probe.monitor()
	return TRUE

/datum/gameplay_client_gather_observer
	should_save = FALSE
	var/mob/living/human/body
	var/client/session
	var/obj/item/weapon/flint/tool
	var/datum/gameplay_action_lease/captured
	var/generation
	var/phase = "await_assignment"
	var/failure = ""
	var/sequence = 0
	var/list/samples = list()
	var/list/requests = list()
	var/list/receipts = list()
	var/bound_tick = 0
	var/first_life = 0
	var/cancel_tick = 0
	var/returned_tick = 0

/datum/gameplay_client_gather_observer/proc/advertised(turf/T)
	var/datum/gameplay_bridge/B = gameplay_bridge
	if (!islist(B.current_observation) || !B.current_observation["complete"] || !islist(B.current_observation["entities"]))
		return FALSE
	var/id = B.entity_ids[T]
	var/visited = 0
	for (var/list/row in B.current_observation["entities"])
		if (++visited > 128)
			return FALSE
		if (row["id"] == id && islist(row["actions"]) && ("gather" in row["actions"]))
			return TRUE
	return FALSE

/datum/gameplay_client_gather_observer/proc/cuttings()
	var/total = 0
	var/visited = 0
	for (var/atom/A in locate(5,5,1))
		if (++visited > 64)
			return -1
		if (istype(A, /obj/item/stack/grass_cuttings))
			var/obj/item/stack/grass_cuttings/G = A
			total += G.amount
	return total

/datum/gameplay_client_gather_observer/proc/emit(final = FALSE)
	var/list/result = list("schema"=1, "kind"="ordinary_client_gather", "commit"=world.params["tested_commit"], "run_id"=world.params["fixture_run"], "sequence"=sequence, "phase"=phase, "failure"=failure, "final"=final, "tick"=world.time, "bound_tick"=bound_tick, "dimensions"=list(world.maxx,world.maxy,world.maxz), "samples"=samples, "request_ids"=requests, "receipts"=receipts, "cancel_tick"=cancel_tick, "returned_tick"=returned_tick, "cleaned_refs"=final)
	// These two fixed private output files are the observer's only external effects.
	var/destination = final ? "client-gather-result.json" : "client-gather-status.json"
	fdel(destination)
	text2file(json_encode(result), destination)

/datum/gameplay_client_gather_observer/proc/monitor()
	var/bootstrap_deadline = world.time + 9000
	var/visited = 0
	for (var/atom/A in locate(5,5,1))
		if (++visited > 64)
			failure = "bootstrap_cell_bound"
			break
		if (A.type == /obj/item/weapon/flint/sharpened)
			if (tool)
				failure = "duplicate_supplied_tool"
			tool = A // Retain the original ground item before any client admission.
	if (!tool)
		failure = "supplied_tool_missing"
	if (world.maxx != 9 || world.maxy != 9 || world.maxz != 1 || !config.skip_persistence_saving)
		failure = "geometry_or_autosave_precondition"
	if (!failure)
		while (!gameplay_bridge.enabled && world.time < bootstrap_deadline)
			sleep(1)
		var/datum/gameplay_bridge/B = gameplay_bridge
		body = B.actor
		session = B.actor_client
		generation = B.generation
		if (!B.enabled || !body || !session || session.holder || session.mob != body || body.client != session || !session.gameplay_bridge_consent || session.gameplay_bridge_consent_mob != body || body.loc != locate(5,5,1) || body.type != /mob/living/human || !istype(body.original_job, /datum/job/civilian/civnomad) || !istype(map, /obj/map_metadata/testing) || !ticker || ticker.current_state != GAME_STATE_PLAYING || body.life_tick < 1 || body.stat || !body.may_do_after || body.survival_actions)
			failure = "ordinary_bootstrap_unavailable"
		else
			phase = "observe"
			bound_tick = world.time
			first_life = body.life_tick
			var/observation_deadline = bound_tick + 1200
			while (world.time <= observation_deadline && !failure)
				if (!B.enabled || B.generation != generation || B.actor != body || B.actor_client != session || session.mob != body || body.client != session || session.holder || !session.gameplay_bridge_consent || session.gameplay_bridge_consent_mob != body || body.loc != locate(5,5,1) || body.stat)
					failure = "ownership_or_actor_changed"
					break
				var/turf/left = locate(4,5,1)
				var/turf/right = locate(6,5,1)
				var/obj/item/held = body.get_active_hand()
				var/datum/gameplay_action_lease/L = B.action_lease
				if (L && L.kind == "gather")
					if (L.body != body || L.owner != B || L.run_generation != generation || L.tool != tool || (L.target != left && L.target != right))
						failure = "foreign_gather_context"
						break
					if (!(L.request_id in requests))
						if (requests.len >= 2 || (requests.len == 0 && L.target != left) || (requests.len == 1 && L.target != right))
							failure = "gather_order_or_limit"
							break
						requests += L.request_id
						captured = L
				if (requests.len == 2 && captured && captured.cancelled && !cancel_tick)
					cancel_tick = world.time // Retained original lease, even if return was between samples.
				if (captured && !L && requests.len == 2 && !returned_tick)
					returned_tick = world.time
				for (var/request_id in requests)
					var/list/cached = B.seen[request_id]
					if (islist(cached) && islist(cached["receipt"]))
						var/list/R = cached["receipt"]
						receipts[request_id] = list("status"=R["status"], "reason"=R["reason"])
				sequence++
				samples += list(list("sequence"=sequence, "tick"=world.time, "life_tick"=body.life_tick, "same_tool"=!!(tool && held == tool && tool.loc == body), "cuttings"=cuttings(), "left_grass"=!!istype(left,/turf/floor/grass), "right_grass"=!!istype(right,/turf/floor/grass), "left_lit"=!!(left.get_lumcount() >= 0.5), "right_lit"=!!(right.get_lumcount() >= 0.5), "left_advertised"=advertised(left), "right_advertised"=advertised(right), "may_do_after"=body.may_do_after, "survival_actions"=body.survival_actions, "worker"=!!L, "claimed"=!!(L && L.wait_claimed), "cancelled"=!!(captured && captured.cancelled), "request_index"=requests.len))
				if (sequence % 10 == 0)
					emit()
				var/next_sample_tick = world.time + 1
				while (world.time < next_sample_tick)
					sleep(1) // Ticklag may be fractional; cap samples by elapsed world time.
			if (!failure && (body.life_tick <= first_life || !cancel_tick || !returned_tick || world.time - returned_tick < 35))
				failure = "incomplete_life_or_cancel_horizon"
	phase = failure ? "failed" : "observation_complete"
	// Release observer-owned references only; never stop the bridge/world or reset locks.
	body = null
	session = null
	tool = null
	captured = null
	emit(TRUE)
