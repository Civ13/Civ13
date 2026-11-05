// Nomad visits for coordinators (docs/agent-control.md#nomad-visits).
// The party controller checks every order; see nomad_coordinator.dm.

/datum/agent_control/proc/act_visit_status(datum/agent_identity/A, list/req)
	if (!nomad_raid)
		return list("active" = FALSE)
	var/since = text2num("[req["since"]]")
	return nomad_raid.coordinator_status(isnum(since) ? since : 0)

/datum/agent_control/proc/act_visit_order(datum/agent_identity/A, list/req)
	if (!nomad_raid)
		agent_fail("not_found", "no nomad visit is running")
	var/list/result = nomad_raid.order(req, "agent [A.name]")
	if (!result["ok"])
		agent_fail("refused", result["detail"])
	audit(A, "visit_order", "[req["order"]]: [result["detail"]]", FALSE)
	return result

/datum/agent_control/proc/act_visit_start(datum/agent_identity/A, list/req)
	var/kind = req["kind"] == "trade" ? "trade" : "raid"
	var/size = clamp(round(text2num("[req["size"]]") || (kind == "trade" ? 2 : 4)), NOMAD_RAID_MIN_MEMBERS, NOMAD_RAID_MAX_MEMBERS)
	var/turf/T
	var/list/ckeys = list()
	if (!req["target"] || req["target"] == "auto")
		var/list/picked = nomad_raid_pick(nomad_raid_candidates())
		if (!picked)
			agent_fail("not_found", "no group of [NOMAD_RAID_MIN_DEFENDERS] or more active players is off cooldown")
		T = picked["turf"]
		ckeys = picked["ckeys"]
	else
		T = get_turf(agent_resolve_target(req["target"]))
		if (!T)
			agent_fail("bad_target", "target has no turf")
		for (var/mob/living/human/H in nomad_raid_defenders_near(T))
			ckeys += H.ckey
	var/error = start_nomad_raid(T, ckeys, size, "agent [A.name]", kind)
	if (error)
		agent_fail("refused", error)
	audit(A, "visit_start", nomad_raid.status_text())
	return list("status" = nomad_raid.status_text())
