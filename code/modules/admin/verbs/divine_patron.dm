// Staff playing a god: speak as the god, initiate followers, teach and take
// back invocations, and answer pending prayers (code/modules/divine/covenant.dm).
// Hidden mechanic: keep it out of changelog lines and the wiki.
/client/proc/cmd_admin_divine_patron()
	set category = "Admin"
	set name = "Divine Patron"
	set desc = "Speak as a god: initiate followers, teach invocations and answer their prayers."
	if (!check_rights(R_ADMIN))
		return
	var/claim = divine_claim_of(src)
	var/list/actions = list()
	if (claim)
		actions += list("Initiate a follower", "Teach an invocation", "Take back an invocation", "Release a follower", "List followers", "Pending prayers", "Stop speaking as a god")
	else
		actions += "Speak as a god"
	actions += "Set my divine name"
	var/label = divine_identity_label(divine_identity_of(ckey))
	var/action = input(usr, claim ? "You speak as [divine_label_for(claim)]." : "You are not speaking as any god.[label ? " Players see you as [label]." : " Set your divine name first."]", "Divine Patron") as null|anything in actions
	if (!action || !check_rights(R_ADMIN))
		return
	claim = divine_claim_of(src)
	var/claim_label = divine_label_for(claim)
	switch (action)
		if ("Set my divine name")
			divine_edit_identity()
		if ("Speak as a god")
			var/list/entry = divine_identity_of(ckey)
			if (!entry)
				entry = divine_edit_identity()
			var/deity = entry ? entry["name"] : null
			var/key = divine_book_key(deity)
			if (!key || divine_claim_of(src))
				return
			if (!islist(divine_patron_claims[key]))
				divine_patron_claims[key] = list()
			divine_patron_claims[key] |= ckey
			to_chat(usr, SPAN_NOTICE("You now speak as [divine_identity_label(entry)]. Prayers from its followers come to you."))
			log_admin("[key_name(usr)] speaks as the god [deity].")
		if ("Stop speaking as a god")
			if (claim && islist(divine_patron_claims[claim]))
				divine_patron_claims[claim] -= ckey
				if (!length(divine_patron_claims[claim]))
					divine_patron_claims -= claim
			to_chat(usr, SPAN_NOTICE("You no longer speak as [claim_label]."))
			log_admin("[key_name(usr)] stopped speaking as the god [claim].")
		if ("Initiate a follower")
			var/mob/living/human/H = divine_pick_human("Initiate whom as a follower of [claim_label]?")
			if (!H || divine_claim_of(src) != claim || !magic_whitelist_admit(H))
				return
			if (H.divine_patron && divine_book_key(H.divine_patron) != claim)
				if (alert(usr, "[H.real_name] already follows [H.divine_patron]. Make them follow [claim_label] instead? They forget everything taught before.", "Divine Patron", "Yes", "No") != "Yes")
					return
				H.divine_known = list()
			var/words = sanitize(input(usr, "What does [H.real_name] hear or see when you call them? Leave empty for nothing.", "Divine Patron") as message|null)
			if (QDELETED(H) || divine_claim_of(src) != claim)
				return
			var/list/own = divine_identity_of(ckey)
			H.divine_patron = (own && divine_book_key(own["name"]) == claim) ? own["name"] : claim
			if (!islist(H.divine_known))
				H.divine_known = list()
			H.divine_refresh_verbs()
			if (words)
				to_chat(H, CHAT_TYPED(CHAT_PRAYER, "<span class='notice'><i>[words]</i></span>"))
			to_chat(usr, SPAN_NOTICE("[H.real_name] now follows [claim_label]. Teach them an invocation next."))
			log_admin("[key_name(usr)] initiated [key_name(H)] as a follower of [claim].")
		if ("Teach an invocation", "Take back an invocation")
			var/teaching = action == "Teach an invocation"
			var/mob/living/human/H = divine_pick_human("[teaching ? "Teach" : "Take back from"] which follower?", claim)
			if (!H || (teaching && !magic_whitelist_admit(H)))
				return
			var/list/options = list()
			for (var/spell in divine_invocation_names)
				if (teaching != (spell in H.divine_known))
					options[divine_invocation_names[spell]] = spell
			if (!options.len)
				to_chat(usr, SPAN_WARNING(teaching ? "[H.real_name] already knows every invocation." : "[H.real_name] knows no invocations."))
				return
			var/picked = input(usr, "Which invocation?", "Divine Patron") as null|anything in options
			var/spell = options[picked]
			if (!spell || QDELETED(H) || divine_book_key(H.divine_patron) != claim || divine_claim_of(src) != claim)
				return
			if (!islist(H.divine_known))
				H.divine_known = list()
			if (teaching)
				H.divine_known |= spell
				to_chat(H, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("You understand a new prayer: [picked]. Use Beseech, with your stick in hand and something in your pouch.")))
			else
				H.divine_known -= spell
				if (H.divine_covenant)
					H.divine_break_covenant()
				to_chat(H, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("The prayer of [picked] slips from your mind.")))
			to_chat(usr, SPAN_NOTICE("[teaching ? "Taught" : "Took back"] [picked] [teaching ? "to" : "from"] [H.real_name]."))
			log_admin("[key_name(usr)] as [claim] [teaching ? "taught" : "took back"] [spell] [teaching ? "to" : "from"] [key_name(H)].")
		if ("Release a follower")
			var/mob/living/human/H = divine_pick_human("Release which follower of [claim_label]?", claim)
			if (!H || divine_claim_of(src) != claim)
				return
			if (H.divine_covenant)
				H.divine_break_covenant()
			H.divine_patron = null
			H.divine_known = null
			H.divine_refresh_verbs()
			to_chat(usr, SPAN_NOTICE("[H.real_name] no longer follows [claim_label]."))
			log_admin("[key_name(usr)] released [key_name(H)] from following [claim].")
		if ("List followers")
			var/list/lines = list()
			for (var/mob/living/human/H in human_mob_list)
				if (!QDELETED(H) && divine_book_key(H.divine_patron) == claim)
					var/list/known = list()
					for (var/spell in H.divine_known)
						known += divine_invocation_names[spell]
					lines += "[H.real_name] ([H.ckey ? H.ckey : "no player"])[H.stat == DEAD ? ", dead" : ""][H.magic_allowed() ? "" : ", SUSPENDED (not on the magic whitelist)"]: [known.len ? english_list(known) : "nothing taught"][H.divine_slot_spent ? ", spent until rested" : ""][karma_mob_ckey(H) ? karma_staff_badge(karma_mob_ckey(H)) : ""]"
			to_chat(usr, "<b>Followers of [claim_label] in this world:</b><br>[lines.len ? jointext(lines, "<br>") : "none"]")
		if ("Pending prayers")
			var/found = FALSE
			for (var/datum/divine_use_request/R in divine_pending_requests)
				if (R.covenant && R.covenant.deity_id == claim && (ckey in R.covenant.operator_ckeys))
					found = TRUE
					if (R.state == "requested")
						divine_alert_operators(R)
					else
						to_chat(usr, SPAN_NOTICE("[R.covenant.caster.real_name]: [divine_invocation_names[R.spell_id]], already granted and under way."))
			if (!found)
				to_chat(usr, SPAN_NOTICE("No prayers are waiting for [claim_label]."))

/client/proc/divine_pick_human(question, follower_of = null)
	var/list/choices = list()
	for (var/mob/living/human/H in human_mob_list)
		if (QDELETED(H) || H.stat == DEAD || !get_turf(H))
			continue
		if (follower_of && divine_book_key(H.divine_patron) != follower_of)
			continue
		if (!follower_of && !H.client)
			continue
		choices["[H.real_name] ([H.ckey ? H.ckey : "no player"])[H.magic_allowed() ? "" : " - not on the magic whitelist"]"] = H
	if (!choices.len)
		to_chat(usr, SPAN_WARNING(follower_of ? "No living followers are in this world." : "No one is playing a character here."))
		return null
	var/pick = input(usr, question, "Divine Patron") as null|anything in sortList(choices)
	return pick ? choices[pick] : null

// A god answers one of its own followers in words. Anyone else only gets a
// subtle message (SM): an answer needs a character who follows this god.
/client/proc/divine_answer_prayer(mob/M)
	if (!check_rights(R_ADMIN))
		return
	var/list/entry = divine_identity_of(ckey)
	if (!entry)
		to_chat(src, SPAN_WARNING("Set your divine name first (Divine Patron > Set my divine name)."))
		return
	var/mob/living/human/H = M
	var/label = divine_identity_label(entry)
	if (!istype(H) || QDELETED(H) || divine_book_key(H.divine_patron) != divine_book_key(entry["name"]))
		to_chat(src, SPAN_WARNING("[M ? M.real_name : "They"] do not follow [label]. Use SM for a subtle message instead."))
		return
	if (karma_mob_ckey(H))
		to_chat(src, SPAN_NOTICE("[H.real_name]'s hidden karma:[karma_staff_badge(karma_mob_ckey(H))]"))
	var/words = sanitize(input(src, "What does [label] say to [H.real_name]? Only they hear it.", "Answer a prayer") as message|null)
	if (!words || QDELETED(H) || !check_rights(R_ADMIN) || divine_book_key(H.divine_patron) != divine_book_key(entry["name"]))
		return
	to_chat(H, CHAT_TYPED(CHAT_PRAYER, "<span class='notice'><b>[label]</b> answers: <i>[words]</i></span>"))
	var/note = "<span class='notice'><b><font color=purple>ANSWER from [label]</font> ([key]) to [key_name(H, TRUE)]:</b> [words]</span>"
	var/list/hearers = prayer_hearers()
	hearers |= src
	for (var/client/C in hearers)
		to_chat(C, CHAT_TYPED(CHAT_PRAYER, note))
	log_admin("[key_name(src)] as [entry["name"]] answered [key_name(H)]: [words]")
