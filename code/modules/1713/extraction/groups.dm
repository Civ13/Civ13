// Consent and readiness bind exact account revisions and physical loadouts.
/datum/extraction_party
	var/leader
	var/faction = "PMC"
	var/list/members = list()
	var/list/ready = list()
	var/version = 1
	var/expires
	var/alive = TRUE
	var/vehicle_id
	var/vehicle_digest
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
	proc/confirm_party_insurance(mob/living/human/H, list/offer)
		return WWinput(H, "Authorize [offer["cost"]] salvage parts for your group loadout insurance? Payment is charged only when the whole group deploys.", "Group insurance", "Decline", list("Authorize", "Decline")) == "Authorize"
	proc/confirm_party_vehicle(mob/living/human/H, datum/extraction_party/P)
		return WWinput(H, "Ride in [P.leader]'s selected car when this group deploys? Your loadout and any authorized premium still come from your own account.", "Group car", "Decline", list("Ride", "Decline")) == "Ride"
	proc/select_party_vehicle(mob/living/human/H)
		if (!vehicle_mission_supported() || !group_eligible(H)) return FALSE
		var/datum/extraction_session/S = H.extraction_session
		var/datum/extraction_party/P = party_by_owner[S.owner]
		if (!party_current(P) || P.leader != S.owner || P.faction != "PMC" || !save_home(S) || !S.garage_vehicle || S.profile["garage"].len != 1) return FALSE
		P.vehicle_id = S.profile["garage"][1]["id"]
		P.vehicle_digest = md5(json_encode(S.profile["garage"][1]))
		P.invalidate()
		return TRUE
	proc/ready_party(mob/living/human/H, insured = FALSE)
		if (!group_eligible(H)) return FALSE
		var/datum/extraction_session/S = H.extraction_session
		var/datum/extraction_party/P = party_by_owner[S.owner]
		if (!party_current(P) || (P.vehicle_id && !vehicle_mission_supported()) || !save_home(S)) return FALSE
		var/list/carried = player_roots(H)
		var/list/graphs = records(carried)
		if (!graphs || carried.len > 16) return FALSE
		var/list/ids = list()
		for (var/obj/item/I in carried) ids += I.extraction_item_id
		if (P.vehicle_id)
			var/version = P.version
			if (!confirm_party_vehicle(H, P)) return FALSE
			if (!vehicle_mission_supported()) return FALSE
			if (!party_current(P) || P.version != version || party_by_owner[S.owner] != P || !group_eligible(H) || json_encode(records(player_roots(H))) != json_encode(graphs) || json_encode(records(home_roots(S))) != json_encode(S.profile["stash"])) return FALSE
		var/list/offer
		if (insured)
			offer = returns.quote(S, ids, round_id)
			var/version = P.version
			if (!offer || !confirm_party_insurance(H, offer)) return FALSE
			if (P.vehicle_id && !vehicle_mission_supported()) return FALSE
			if (!party_current(P) || P.version != version || party_by_owner[S.owner] != P || !group_eligible(H) || json_encode(returns.quote(S, ids, round_id)) != json_encode(offer) || json_encode(records(player_roots(H))) != json_encode(graphs) || json_encode(records(home_roots(S))) != json_encode(S.profile["stash"])) return FALSE
		P.ready[S.owner] = list("version" = P.version, "revision" = S.profile["revision"], "profile_digest" = md5(json_encode(S.profile)), "carried_digest" = md5(json_encode(graphs)), "selected" = ids, "insurance" = offer, "vehicle_id" = P.vehicle_id, "vehicle_digest" = P.vehicle_digest)
		to_chat(H, "Group loadout ready. Changing equipment or saving your stash requires readying again.")
		return TRUE
	proc/deploy_party(mob/living/human/leader)
		if (!group_eligible(leader) || !extraction_raid_markers.len) return FALSE
		var/datum/extraction_party/P = party_by_owner[leader.extraction_session.owner]
		if (!party_current(P) || P.leader != leader.extraction_session.owner || P.members.len < 2 || P.members.len > 4) return FALSE
		if (P.vehicle_id && !vehicle_mission_supported()) return FALSE
		var/list/parts = list()
		var/list/bodies = list()
		var/list/carried_sets = list()
		var/datum/extraction_vehicle_transfer/transfer
		var/list/seats
		var/turf/car_destination
		if (P.vehicle_id)
			var/datum/extraction_session/driver = leader.extraction_session
			if (P.faction != "PMC" || raid_vehicles.len >= 32 || driver.profile["garage"].len != 1 || driver.profile["garage"][1]["id"] != P.vehicle_id || md5(json_encode(driver.profile["garage"][1])) != P.vehicle_digest) return FALSE
			transfer = new
			if (!transfer.capture(driver.garage_vehicle, TRUE)) return FALSE
			seats = group_vehicle_seats(transfer)
			car_destination = vehicle_raid_destination(transfer)
			if (!seats || seats.len < P.members.len || !car_destination) return FALSE
		var/total_nodes = 0
		var/insured_nodes = 0
		for (var/owner in P.members)
			var/datum/extraction_session/S = accounts.sessions[owner]
			var/list/ready = P.ready[owner]
			if (!S || !ready || !group_eligible(S.body) || ready["version"] != P.version || ready["revision"] != S.profile["revision"] || ready["profile_digest"] != md5(json_encode(S.profile))) return FALSE
			if (ready["vehicle_id"] != P.vehicle_id || ready["vehicle_digest"] != P.vehicle_digest || S.body.buckled || S.body.pinned.len) return FALSE
			var/list/carried = player_roots(S.body)
			var/list/graphs = records(carried)
			if (!graphs || ready["carried_digest"] != md5(json_encode(graphs)) || json_encode(records(home_roots(S))) != json_encode(S.profile["stash"]) || json_encode(garage_snapshot(S)) != json_encode(S.profile["garage"])) return FALSE
			for (var/list/entry in graphs) total_nodes += entry["equipment"]["nodes"].len
			var/list/offer = ready["insurance"]
			if (offer && (offer["round"] != round_id || json_encode(returns.quote(S, ready["selected"], round_id)) != json_encode(offer))) return FALSE
			var/list/plan = offer ? S.plan_raid(ready["selected"], P.faction, offer["insured"], offer["round"], offer["payment"], ready["revision"]) : S.plan_raid(ready["selected"], P.faction, null, null, null, ready["revision"])
			if (!plan) return FALSE
			if (P.vehicle_id && owner == P.leader)
				plan = S.plan_group_vehicle(plan, P.vehicle_id, P.vehicle_digest)
				if (!plan) return FALSE
			if (offer)
				for (var/list/entry in graphs) insured_nodes += entry["equipment"]["nodes"].len
			var/list/after = plan["candidate"]
			after["revision"] = S.profile["revision"] + 1
			var/list/part = list("owner" = owner, "before" = S.copy_profile(), "after" = after, "selected" = ready["selected"].Copy(), "faction" = P.faction, "issued" = plan["issued"])
			if (offer) part["insurance"] = offer
			if (P.vehicle_id && owner == P.leader) part["vehicle"] = list("id" = P.vehicle_id, "digest" = P.vehicle_digest)
			parts += list(part)
			bodies[owner] = S.body
			carried_sets[owner] = carried
		if (transfer)
			for (var/list/entry in transfer.cargo_record) total_nodes += entry["equipment"]["nodes"].len
		if (raid_items.len + total_nodes > 2048 || insured_nodes_issued + insured_nodes > 4096) return FALSE
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
		if (transfer)
			if (!transfer.relocate(car_destination))
				for (var/owner in P.members) accounts.sessions[owner]:locked = TRUE
				return FALSE
			var/datum/extraction_session/driver = leader.extraction_session
			driver.raid_vehicle = transfer.axis
			driver.raid_vehicle_parts = transfer.parts - transfer.cargo
			raid_vehicles[transfer.axis] = driver.raid_vehicle_parts.Copy()
			driver.garage_vehicle = null
			driver.garage_parts.Cut()
			for (var/obj/item/I in transfer.cargo)
				codec.set_raid_provenance(I, FALSE)
				track_loot(I)
		insured_nodes_issued += insured_nodes
		var/seat_index = 0
		for (var/list/part in parts)
			var/owner = part["owner"]
			var/datum/extraction_session/S = accounts.sessions[owner]
			var/mob/living/human/H = bodies[owner]
			var/list/offer = part["insurance"]
			if (offer)
				for (var/obj/item/I in home_roots(S))
					if (I.extraction_item_id in offer["payment"]) qdel(I)
				apply_issued_tokens(carried_sets[owner], part["issued"])
			for (var/obj/item/I in carried_sets[owner])
				codec.set_raid_provenance(I, FALSE)
				track_loot(I)
			if (transfer)
				var/obj/structure/bed/chair/seat = seats[++seat_index]
				H.forceMove(get_turf(seat))
				if (!seat.buckle_mob(H))
					for (var/member in P.members) accounts.sessions[member]:locked = TRUE
					return FALSE
			else H.forceMove(destination)
			H.status_flags &= ~GODMODE
			S.transitioning = FALSE
			to_chat(H, "Group raid started. Extract before district closure to keep your loadout and loot.")
		disband_party(P)
		return TRUE
	proc/manage_party(mob/living/human/H)
		if (!group_eligible(H)) return FALSE
		var/datum/extraction_party/P = party_by_owner[H.extraction_session.owner]
		var/version = P ? P.version : 0
		var/prompt = "Groups contain two to four consenting players. Each member readies their own loadout and may authorize their own insurance premium. Deployment waits for all account debits. Groups expire after five minutes."
		var/list/actions = list("Create PMC group", "Create Scav group", "Cancel")
		if (P)
			prompt += "\nLeader: [P.leader]. Faction: [P.faction]. Members: [jointext(P.members, ", ")]. Ready: [P.ready.len]/[P.members.len]."
			if (P.vehicle_id) prompt += "\nTravel: selected leader car; each readiness requires rider consent."
			actions = P.leader == H.extraction_session.owner ? list("Invite player", "Use garage car", "Travel on foot", "Ready loadout", "Ready insured loadout", "Deploy group", "Leave group", "Cancel") : list("Ready loadout", "Ready insured loadout", "Leave group", "Cancel")
		var/choice = WWinput(H, prompt, "Raid group", "Cancel", actions)
		if (!group_eligible(H)) return FALSE
		if (P && (!party_current(P) || P.version != version || party_by_owner[H.extraction_session.owner] != P)) return FALSE
		switch (choice)
			if ("Create PMC group") return !!create_party(H)
			if ("Create Scav group") return !!create_party(H, "Scav")
			if ("Ready loadout") return ready_party(H)
			if ("Ready insured loadout") return ready_party(H, TRUE)
			if ("Use garage car") return select_party_vehicle(H)
			if ("Travel on foot")
				if (!P || P.leader != H.extraction_session.owner) return FALSE
				P.vehicle_id = null
				P.vehicle_digest = null
				P.invalidate()
				return TRUE
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
