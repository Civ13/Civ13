// A finite district round. This does not resume an active raid after a restart.
/obj/map_metadata/extraction_survival
	var/datum/extraction_insurance_returns/returns
	var/round_id
	var/round_deadline = 0
	var/round_closing = FALSE
	var/round_notice = FALSE
	var/game_over = FALSE
	var/round_warning = FALSE
	var/list/round_participants = list()
	var/insured_nodes_issued = 0
	proc/confirm_insurance(mob/living/human/H, list/offer)
		return WWinput(H, "Pay [offer["cost"]] workshop parts to insure eligible carried equipment for this round? Returned reusable equipment keeps its lost condition. Ammunition and consumed supplies are excluded.", "Insurance quote", "Cancel", list("Pay and deploy", "Cancel")) == "Pay and deploy"
	proc/ensure_round()
		if (!returns) returns = new(accounts, codec)
		if (!returns.ready()) return FALSE
		if (!round_id)
			if (!ensure_loot_epoch()) return FALSE
			round_id = "district[loot_epoch]"
			round_deadline = world.time + 30 MINUTES
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
	proc/claim_mail(mob/living/human/H)
		if (!owned(H) || H.stat != CONSCIOUS || !H.Adjacent(H.extraction_session.house)) return FALSE
		var/datum/extraction_session/S = H.extraction_session
		if (!save_home(S)) return FALSE
		var/list/mail = S.profile["insurance_mailbox"]
		var/free = min(16, S.capacity() - S.profile["stash"].len)
		if (!islist(mail) || !mail.len || free < 1)
			to_chat(H, "No insurance mail can be delivered. Check your mailbox and free stash space.")
			return FALSE
		var/list/ids = list()
		for (var/i in 1 to min(free, mail.len))
			var/list/entry = mail[i]
			if (!codec.validate(entry["equipment"])) return FALSE
			ids += entry["id"]
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
	proc/close_round()
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
			if (!returns.prepare(round_id, roots)) return FALSE
		game_over = TRUE
		if (ticker) ticker.finished = TRUE
		return TRUE
