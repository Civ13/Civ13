// Consent and readiness bind exact account revisions and physical loadouts.
/datum/extraction_party
	var/leader
	var/faction = "PMC"
	var/list/members = list()
	var/list/ready = list()
	var/version = 1
	var/expires
	var/alive = TRUE
	proc/invalidate()
		version++
		ready.Cut()

/obj/map_metadata/extraction_survival
	var/list/parties = list()
	var/list/party_by_owner = list()
	proc/group_eligible(mob/living/human/H)
		if (!owned(H) || H.stat != CONSCIOUS) return FALSE
		var/datum/extraction_session/S = H.extraction_session
		return !S.transitioning && S.profile["state"] == "home" && S.house && H.z == S.house.z && get_dist(H, S.house) <= 4
	proc/create_party(mob/living/human/H, faction = "PMC")
		if (!group_eligible(H) || party_by_owner[H.extraction_session.owner] || parties.len >= 16 || !(faction in list("PMC", "Scav"))) return null
		var/datum/extraction_party/P = new
		P.leader = H.extraction_session.owner
		P.faction = faction
		P.members += P.leader
		P.expires = world.time + 5 MINUTES
		parties += P
		party_by_owner[P.leader] = P
		return P
	proc/party_current(datum/extraction_party/P)
		return P && P.alive && (P in parties) && world.time < P.expires && !round_closing
	proc/confirm_party(mob/living/human/H, leader, faction)
		return WWinput(H, "Join [leader]'s [faction] raid group? You must ready your own loadout at your private house before the group can deploy.", "Raid group invitation", "Decline", list("Join", "Decline")) == "Join"
	proc/invite_party(mob/living/human/leader, mob/living/human/target)
		if (!group_eligible(leader) || !group_eligible(target) || leader == target) return FALSE
		var/datum/extraction_party/P = party_by_owner[leader.extraction_session.owner]
		var/target_owner = target.extraction_session.owner
		if (!party_current(P) || P.leader != leader.extraction_session.owner || P.members.len >= 4 || party_by_owner[target_owner]) return FALSE
		var/version = P.version
		if (!confirm_party(target, P.leader, P.faction)) return FALSE
		if (!party_current(P) || P.version != version || !group_eligible(leader) || !group_eligible(target) || target.extraction_session.owner != target_owner || party_by_owner[target_owner]) return FALSE
		P.members += target_owner
		party_by_owner[target_owner] = P
		P.invalidate()
		to_chat(target, "Joined the raid group. Ready your loadout at your private house.")
		return TRUE
	proc/leave_party(owner)
		var/datum/extraction_party/P = party_by_owner[owner]
		if (!P) return FALSE
		party_by_owner -= owner
		P.members -= owner
		P.invalidate()
		if (owner == P.leader || !P.members.len) disband_party(P)
		return TRUE
	proc/disband_party(datum/extraction_party/P)
		if (!P || !P.alive) return
		P.alive = FALSE
		for (var/owner in P.members)
			if (party_by_owner[owner] == P) party_by_owner -= owner
		P.members.Cut()
		P.ready.Cut()
		parties -= P
	proc/tick_parties()
		for (var/datum/extraction_party/P in parties.Copy())
			if (!party_current(P)) disband_party(P)
	proc/ready_party(mob/living/human/H)
		if (!group_eligible(H)) return FALSE
		var/datum/extraction_session/S = H.extraction_session
		var/datum/extraction_party/P = party_by_owner[S.owner]
		if (!party_current(P) || !save_home(S)) return FALSE
		var/list/carried = player_roots(H)
		var/list/graphs = records(carried)
		if (!graphs || carried.len > 16) return FALSE
		var/list/ids = list()
		for (var/obj/item/I in carried) ids += I.extraction_item_id
		P.ready[S.owner] = list("version" = P.version, "revision" = S.profile["revision"], "profile_digest" = md5(json_encode(S.profile)), "carried_digest" = md5(json_encode(graphs)), "selected" = ids)
		to_chat(H, "Group loadout ready. Changing equipment or saving your stash requires readying again. Group deployment is uninsured.")
		return TRUE
	proc/deploy_party(mob/living/human/leader)
		if (!group_eligible(leader) || !extraction_raid_markers.len) return FALSE
		var/datum/extraction_party/P = party_by_owner[leader.extraction_session.owner]
		if (!party_current(P) || P.leader != leader.extraction_session.owner || P.members.len < 2 || P.members.len > 4) return FALSE
		var/list/parts = list()
		var/list/bodies = list()
		var/list/carried_sets = list()
		var/total_nodes = 0
		for (var/owner in P.members)
			var/datum/extraction_session/S = accounts.sessions[owner]
			var/list/ready = P.ready[owner]
			if (!S || !ready || !group_eligible(S.body) || ready["version"] != P.version || ready["revision"] != S.profile["revision"] || ready["profile_digest"] != md5(json_encode(S.profile))) return FALSE
			var/list/carried = player_roots(S.body)
			var/list/graphs = records(carried)
			if (!graphs || ready["carried_digest"] != md5(json_encode(graphs)) || json_encode(records(home_roots(S))) != json_encode(S.profile["stash"])) return FALSE
			for (var/list/entry in graphs) total_nodes += entry["equipment"]["nodes"].len
			var/list/plan = S.plan_raid(ready["selected"], P.faction, null, null, null, ready["revision"])
			if (!plan) return FALSE
			var/list/after = plan["candidate"]
			after["revision"] = S.profile["revision"] + 1
			parts += list(list("owner" = owner, "before" = S.copy_profile(), "after" = after, "selected" = ready["selected"].Copy(), "faction" = P.faction, "issued" = plan["issued"]))
			bodies[owner] = S.body
			carried_sets[owner] = carried
		if (raid_items.len + total_nodes > 2048) return FALSE
		var/datum/extraction_settlement/groups/J = accounts.group_journal
		for (var/owner in P.members) accounts.sessions[owner]:transitioning = TRUE
		if (!J.submit(J.profile["sequence"] + 1, parts))
			for (var/owner in P.members)
				var/datum/extraction_session/S = accounts.sessions[owner]
				if (J.blocked) S.locked = TRUE
				else S.transitioning = FALSE
			P.invalidate()
			return FALSE
		// All account debits are now durable. Move the existing atoms together;
		// never decode a second physical copy of a selected loadout.
		var/turf/destination = get_turf(pick(extraction_raid_markers))
		for (var/list/part in parts) accounts.sessions[part["owner"]]:profile = part["after"]
		for (var/list/part in parts)
			var/owner = part["owner"]
			var/datum/extraction_session/S = accounts.sessions[owner]
			var/mob/living/human/H = bodies[owner]
			for (var/obj/item/I in carried_sets[owner])
				codec.set_raid_provenance(I, FALSE)
				track_loot(I)
			H.forceMove(destination)
			H.status_flags &= ~GODMODE
			S.transitioning = FALSE
			to_chat(H, "Group raid started. Extract before district closure to keep your loadout and loot.")
		disband_party(P)
		return TRUE
	proc/manage_party(mob/living/human/H)
		if (!group_eligible(H)) return FALSE
		var/datum/extraction_party/P = party_by_owner[H.extraction_session.owner]
		var/version = P ? P.version : 0
		var/prompt = "Groups contain two to four consenting players. Each member readies their own loadout. Group deployment is uninsured and waits for all account debits. Groups expire after five minutes."
		var/list/actions = list("Create PMC group", "Create Scav group", "Cancel")
		if (P)
			prompt += "\nLeader: [P.leader]. Faction: [P.faction]. Members: [jointext(P.members, ", ")]. Ready: [P.ready.len]/[P.members.len]."
			actions = P.leader == H.extraction_session.owner ? list("Invite player", "Ready loadout", "Deploy group", "Leave group", "Cancel") : list("Ready loadout", "Leave group", "Cancel")
		var/choice = WWinput(H, prompt, "Raid group", "Cancel", actions)
		if (!group_eligible(H)) return FALSE
		if (P && (!party_current(P) || P.version != version || party_by_owner[H.extraction_session.owner] != P)) return FALSE
		switch (choice)
			if ("Create PMC group") return !!create_party(H)
			if ("Create Scav group") return !!create_party(H, "Scav")
			if ("Ready loadout") return ready_party(H)
			if ("Deploy group") return deploy_party(H)
			if ("Leave group") return leave_party(H.extraction_session.owner)
			if ("Invite player")
				var/list/options = list()
				for (var/owner in accounts.sessions)
					var/datum/extraction_session/S = accounts.sessions[owner]
					if (S.body != H && group_eligible(S.body) && !party_by_owner[owner]) options[owner] = S.body
				if (!options.len) return FALSE
				var/selected = WWinput(H, "Invite a player currently in their private house.", "Raid group", null, options)
				return selected ? invite_party(H, options[selected]) : FALSE
		return FALSE
