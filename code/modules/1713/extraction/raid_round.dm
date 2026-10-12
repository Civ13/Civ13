// A finite district round. This does not resume an active raid after a restart.
/obj/map_metadata/extraction_survival
	var/datum/extraction_insurance_returns/returns
	var/round_id
	var/round_deadline = 0
	var/round_duration = 30 MINUTES
	var/round_closing = FALSE
	var/round_notice = FALSE
	var/game_over = FALSE
	var/round_warning = FALSE
	var/list/round_participants = list()
	var/insured_nodes_issued = 0
	proc/round_briefing()
		return "This district closes after thirty minutes. Extract or ship gear before closure."
	proc/confirm_insurance(mob/living/human/H, list/offer)
		return WWinput(H, "Pay [offer["cost"]] workshop parts to insure eligible carried equipment for this round? Returns keep lost condition and require one additional full completed round before reclaim. Ammunition and consumed supplies are excluded. Expiration: to be implemented.", "Insurance quote", "Cancel", list("Pay and deploy", "Cancel")) == "Pay and deploy"
	proc/ensure_round()
		if (!returns) returns = new(accounts, codec)
		if (!returns.ready()) return FALSE
		if (!round_id)
			if (!ensure_loot_epoch()) return FALSE
			round_id = "district[loot_epoch]"
			round_deadline = world.time + round_duration
		return TRUE
	proc/apply_issued_tokens(list/roots, list/issued)
		var/list/tokens = list()
		for (var/list/entry in issued)
			for (var/list/node in entry["equipment"]["nodes"]) tokens[node["id"]] = node["insurance_token"]
		var/list/pending = roots.Copy()
		var/list/seen = list()
		while (pending.len)
			var/obj/item/I = pending[1]
			pending.Cut(1, 2)
			if (seen[I] || seen.len >= 2048) return FALSE
			seen[I] = TRUE
			I.extraction_insurance_token = tokens[I.extraction_item_id]
			for (var/obj/item/child in I.contents) pending += child
		return TRUE
	proc/contains_insured(obj/item/root)
		var/list/pending = list(root)
		var/list/seen = list()
		while (pending.len)
			var/obj/item/I = pending[1]
			pending.Cut(1, 2)
			if (seen[I] || seen.len >= EXTRACTION_EQUIPMENT_NODES) return TRUE
			seen[I] = TRUE
			if (I.extraction_insurance_token) return TRUE
			for (var/obj/item/child in I.contents) pending += child
		return FALSE
	proc/claim_mail(mob/living/human/H, list/selected_ids)
		if (!owned(H) || H.stat != CONSCIOUS || !H.Adjacent(H.extraction_session.house)) return FALSE
		var/datum/extraction_session/S = H.extraction_session
		if (!save_home(S)) return FALSE
		if (!ensure_round() || !S.stamp_legacy_mail(returns.profile["completed_generation"])) return FALSE
		var/list/inspection = S.inspect_insurance_mail(null)
		var/list/mail = inspection?["entries"]
		var/free = min(16, S.capacity() - S.profile["stash"].len)
		if (!islist(mail) || (!mail.len && !islist(selected_ids)) || free < 1)
			to_chat(H, "No insurance mail can be delivered. Check your mailbox and free stash space.")
			return FALSE
		var/list/ids = list()
		if (islist(selected_ids))
			if (!selected_ids.len || selected_ids.len > free) return FALSE
			ids = selected_ids.Copy()
		else
			for (var/list/entry in mail)
				if (ids.len >= free) break
				if (entry["state"] != "eligible") continue
				ids += entry["item_id"]
		if (!ids.len)
			to_chat(H, "Insurance returns are pending another full completed round. Expiration: to be implemented.")
			return FALSE
		var/list/claimed = S.claim_insurance_mail(ids)
		if (!claimed) return FALSE
		var/list/materialized = list()
		for (var/list/entry in claimed)
			var/obj/item/I = codec.decode(entry["equipment"], get_turf(S.house))
			if (!I)
				for (var/obj/item/partial in materialized) qdel(partial)
				S.locked = TRUE
				to_chat(H, "Mail is committed to your stash, but restoration failed. Account locked for recovery.")
				return FALSE
			materialized += I
		to_chat(H, "Delivered [claimed.len] returned equipment items to your private house.")
		return TRUE
	proc/manage_insurance_mail(mob/living/human/H)
		if (!owned(H) || H.stat != CONSCIOUS || !H.Adjacent(H.extraction_session.house)) return FALSE
		var/datum/extraction_session/S = H.extraction_session
		if (!save_home(S) || !ensure_round()) return FALSE
		var/cursor
		for (var/interaction in 1 to 32)
			if (!owned(H) || H.extraction_session != S || H.stat != CONSCIOUS || !H.Adjacent(S.house)) return FALSE
			var/list/data = S.inspect_insurance_mail(cursor)
			if (!data)
				to_chat(H, "Insurance mail changed or requires recovery. Reopen the mailbox.")
				return FALSE
			var/list/options = list()
			for (var/list/E in data["entries"])
				var/label = "[E["name"]] - [E["state"]] - [E["item_id"]]"
				options[label] = E
			var/list/choices = options.Copy()
			if (data["next_cursor"]) choices += "Next page"
			choices += list("First page", "Cancel")
			var/choice = WWinput(H, "Returns require one additional full completed round. Completed generation: [data["completed_generation"]]. Expiration: [data["expiration"]]. Select a return to inspect its condition and reclaim eligible equipment.", "Insurance mail", "Cancel", choices)
			if (!owned(H) || H.extraction_session != S || H.stat != CONSCIOUS || !H.Adjacent(S.house)) return FALSE
			if (choice == "Cancel" || isnull(choice)) return TRUE
			if (choice == "Next page" && data["next_cursor"])
				cursor = data["next_cursor"]
				continue
			if (choice == "First page")
				cursor = null
				continue
			var/list/E = options[choice]
			if (!E) return FALSE
			var/list/condition = E["condition"]
			var/list/actions = E["state"] == "eligible" ? list("Reclaim", "Back") : list("Back")
			var/action = WWinput(H, "[E["name"]]. Item [E["item_id"]]. Condition [condition["health"]]/[condition["maxhealth"]]. Found in raid: [E["found_in_raid"] ? "yes" : "no"]. Returned generation [E["returned_generation"]]; eligible generation [E["eligible_generation"]]. Expiration: to be implemented.", "Returned equipment", "Back", actions)
			if (!owned(H) || H.extraction_session != S || H.stat != CONSCIOUS || !H.Adjacent(S.house)) return FALSE
			if (action != "Reclaim") continue
			var/list/fresh = S.inspect_insurance_mail(cursor)
			if (!fresh || fresh["mail_revision"] != data["mail_revision"] || fresh["account_revision"] != data["account_revision"]) return FALSE
			if (!claim_mail(H, list(E["item_id"]))) return FALSE
			cursor = null
		return TRUE
	proc/close_round()
		if (hub_vote) hub_vote.cancel()
		round_closing = TRUE
		if (!round_notice)
			round_notice = TRUE
			world << "The district has closed. Unsaved raid equipment is forfeited; insured reusable equipment is being reconciled."
		// No yielding here. Closing denies new interactions and cancels exit waits.
		for (var/owner in accounts.sessions.Copy())
			var/datum/extraction_session/S = accounts.sessions[owner]
			if (S.locked) return FALSE
			S.transitioning = FALSE
			var/mob/living/human/H = S.body
			if (S.profile["state"] == "raid")
				if (!S.forfeit(S.profile["raid_sequence"])) return FALSE
				if (H)
					H.death()
					H.do_rotting()
				if (!release(S, FALSE)) return FALSE
			else if (!release(S)) return FALSE
			if (H?.client) H.ghostize()
		if (returns.profile && returns.profile["phase"] == "prepared")
			if (!returns.retire()) return FALSE
		else if (returns.profile && returns.profile["phase"] == "retired")
			if (!returns.finish()) return FALSE
		else if (!returns.profile || returns.profile["resolved_round"] != round_id)
			var/list/roots = list()
			for (var/obj/item/I in raid_items)
				var/turf/T = get_turf(I)
				if (!I.loc || !T || T.z != 1) continue
				var/obj/item/root = I
				for (var/depth in 1 to EXTRACTION_EQUIPMENT_DEPTH)
					if (!istype(root.loc, /obj/item)) break
					root = root.loc
				if (istype(root.loc, /obj/item)) return FALSE
				roots |= root
			if (!returns.prepare(round_id, roots, round_deadline > 0 && world.time >= round_deadline)) return FALSE
		retire_raid_vehicles()
		game_over = TRUE
		if (ticker) ticker.finished = TRUE
		return TRUE
