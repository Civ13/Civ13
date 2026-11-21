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
		actions += list("Initiate a follower", "Teach an invocation", "Take back an invocation", "Release a follower", "List followers", "List apostates", "Set customs", "Set rites", "List enchantments", "Strip enchantment", "Pending prayers", "Stop speaking as a god")
	else
		actions += "Speak as a god"
	actions += "Set my divine name"
	actions += "Tend repositories"
	actions += "Heteromorph forms"
	var/label = divine_identity_label(divine_identity_of(ckey))
	var/action = input(usr, claim ? "You speak as [divine_label_for(claim)]." : "You are not speaking as any god.[label ? " Players see you as [label]." : " Set your divine name first."]", "Divine Patron") as null|anything in actions
	if (!action || !check_rights(R_ADMIN))
		return
	claim = divine_claim_of(src)
	var/claim_label = divine_label_for(claim)
	switch (action)
		if ("Set my divine name")
			divine_edit_identity()
		if ("Tend repositories")
			divine_tend_repositories() // repository_nations.dm
		if ("Heteromorph forms")
			divine_heteromorph_menu() // heteromorph.dm
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
			if (!H.arcane_apostate_may_join(claim)) // arcane_apostate.dm
				to_chat(usr, SPAN_WARNING("[H.real_name] renounced another god too recently. Only that god can take them in yet."))
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
			H.arcane_apostate_return(claim) // arcane_apostate.dm
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
				if (magic_repo_rite_spell(spell)) // repository_tiers.dm: they come with the grant
					continue
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
				to_chat(H, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("You understand a new prayer: [picked]. Use Beseech, with your stick in hand and something in your pouch.[spell == "repository" ? " Hold something small of your own in your other hand when you ask." : ""][spell == "imbue" ? " Hold the thing in your other hand and keep what it needs in your pouch." : ""][spell == "bless" ? " Stand at an altar with the thing in your other hand and your sacrifice laid on the altar." : ""]")))
				if (spell == "repository")
					H.magic_grant_received() // repository.dm
			else
				H.divine_known -= spell
				if (H.divine_covenant)
					H.divine_break_covenant()
				if (spell == "repository")
					H.magic_repo_withdraw_all() // repository.dm
					H.divine_refresh_verbs()
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
		if ("Set customs")
			arcane_edit_customs(claim) // arcane_devotion.dm
		if ("Set rites")
			arcane_edit_rites(claim) // arcane_rites.dm
		if ("List apostates")
			arcane_list_apostates(claim) // arcane_apostate.dm
		if ("List enchantments", "Strip enchantment") // arcane_enchant.dm
			var/mob/living/human/H = divine_pick_human("Whose enchantments?", claim)
			if (!H || !H.ckey)
				return
			var/list/found = list()
			for (var/obj/item/I in arcane_enchantments_of(H.ckey))
				found["[I.name] ([I.type]): [arcane_enchant_names[I.arcane_enchant]], [I.arcane_charges] left, at [arcane_enchant_place(I)]"] = I
			for (var/obj/O in arcane_wards_of(H.ckey)) // arcane_ward.dm
				var/list/owners = list()
				for (var/key in O.arcane_ward_owners)
					owners += "[O.arcane_ward_owners[key]] ([key])"
				found["[O.name] ([O.type]): Warding for [english_list(owners)], [O.arcane_ward_charges] left, at [arcane_enchant_place(O)]"] = O
			if (!found.len)
				to_chat(usr, SPAN_NOTICE("[H.real_name] has no enchantments in this world."))
				return
			if (action == "List enchantments")
				var/list/lines = list()
				for (var/line in found)
					lines += line
				to_chat(usr, "<b>Enchantments made by [H.real_name] ([H.ckey]):</b><br>[jointext(lines, "<br>")]")
				return
			var/picked = input(usr, "Strip which enchantment?", "Divine Patron") as null|anything in found
			var/obj/item/I = found[picked]
			if (I && !istype(I) && !QDELETED(I) && I.arcane_ward_live() && divine_claim_of(src) == claim)
				log_admin("[key_name(usr)] as [claim] stripped the ward made by [I.arcane_ward_by] from [I] ([I.type]).")
				I.arcane_ward_end()
				to_chat(usr, SPAN_NOTICE("Stripped the ward from [I]."))
				return
			if (!istype(I) || QDELETED(I) || !I.arcane_enchant_live() || divine_claim_of(src) != claim)
				return
			log_admin("[key_name(usr)] as [claim] stripped [I.arcane_enchant] made by [I.arcane_enchanter] from [I] ([I.type]).")
			I.arcane_enchant_end()
			to_chat(usr, SPAN_NOTICE("Stripped the enchantment from [I]."))
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

// Give, take back or list heteromorph forms (code/modules/divine/heteromorph.dm).
// Only a god's own character or a staff-run event character may carry one.
/client/proc/divine_heteromorph_menu()
	if (!check_rights(R_ADMIN))
		return
	var/action = input(usr, "Heteromorph forms are played only by staff. Other staff see every grant and use.", "Divine Patron") as null|anything in list("Give a form", "Take back a form", "List forms")
	if (!action || !check_rights(R_ADMIN))
		return
	switch (action)
		if ("List forms")
			var/list/lines = heteromorph_staff_lines()
			to_chat(usr, lines.len ? SPAN_NOTICE(jointext(lines, "<br>")) : SPAN_NOTICE("No one carries a heteromorph form here."))
		if ("Give a form")
			var/list/kinds = list()
			for (var/id in heteromorph_kinds())
				var/datum/heteromorph/K = heteromorph_kinds[id]
				kinds[K.name] = K
			var/kind_name = input(usr, "Which form?", "Divine Patron") as null|anything in kinds
			var/datum/heteromorph/K = kind_name ? kinds[kind_name] : null
			if (!K)
				return
			var/mob/living/human/H = divine_pick_human("Give the [K.name] form to whom? Only staff-run characters can carry it.")
			if (!H || !check_rights(R_ADMIN))
				return
			var/colour = K.default_colour()
			if (length(K.colours) > 1)
				var/list/by_label = list()
				for (var/c in K.colours)
					by_label[K.colours[c]] = c
				var/label = input(usr, "Which colour?", "Divine Patron") as null|anything in by_label
				if (!label)
					return
				colour = by_label[label]
			var/problem = H.heteromorph_grant(K, colour, ckey)
			if (problem)
				to_chat(usr, SPAN_WARNING(problem))
				return
			to_chat(usr, SPAN_NOTICE("[H.real_name] is now a [K.name]."))
			if (H != usr)
				to_chat(H, SPAN_NOTICE("<i>You remember what you truly are.</i>"))
		if ("Take back a form")
			var/list/choices = list()
			for (var/mob/living/human/H in human_mob_list)
				if (!QDELETED(H) && H.heteromorph_id)
					choices["[H.real_name] ([H.ckey ? H.ckey : "no player"])"] = H
			if (!choices.len)
				to_chat(usr, SPAN_NOTICE("No one carries a heteromorph form here."))
				return
			var/pick = input(usr, "Take the form back from whom?", "Divine Patron") as null|anything in sortList(choices)
			var/mob/living/human/H = pick ? choices[pick] : null
			if (!H || QDELETED(H) || !check_rights(R_ADMIN))
				return
			if (H.heteromorph_revoke(ckey))
				to_chat(usr, SPAN_NOTICE("[H.real_name] is only human now."))

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

// A god invites someone who prays without following any god (the Invite link
// on their prayer). The player chooses to follow or decline; nothing changes
// until they accept.
/client/proc/divine_invite_follower(mob/M)
	if (!check_rights(R_ADMIN))
		return
	var/list/entry = divine_identity_of(ckey)
	if (!entry)
		to_chat(src, SPAN_WARNING("Set your divine name first (Divine Patron > Set my divine name)."))
		return
	var/deity = entry["name"]
	var/claim = divine_book_key(deity)
	var/label = divine_identity_label(entry)
	var/mob/living/human/H = M
	if (!claim || !istype(H) || QDELETED(H) || H.stat == DEAD)
		to_chat(src, SPAN_WARNING("[M ? M.real_name : "They"] can't be invited now."))
		return
	if (H.divine_patron)
		to_chat(src, SPAN_WARNING("[H.real_name] already follows [H.divine_patron]."))
		return
	if (H.divine_invite_from)
		to_chat(src, SPAN_WARNING("[H.real_name] is already weighing an invitation from [H.divine_invite_from]."))
		return
	if (!H.arcane_apostate_may_join(claim)) // arcane_apostate.dm
		to_chat(src, SPAN_WARNING("[H.real_name] renounced another god too recently. Only that god can take them in yet."))
		return
	if (!magic_whitelist_admit(H))
		return
	var/raw = input(src, "What does [H.real_name] hear or see as [label] calls them? Leave empty to invite without words; Cancel to stop.", "Invite a follower") as message|null
	if (isnull(raw))
		return
	var/words = sanitize(raw)
	if (QDELETED(H) || H.divine_patron || H.divine_invite_from || !check_rights(R_ADMIN))
		return
	to_chat(src, SPAN_NOTICE("You invite [H.real_name] to follow [label]. They are asked to accept or decline."))
	log_admin("[key_name(src)] as [deity] invited [key_name(H)] to follow them.")
	H.divine_invite_from = label
	spawn(0)
		H.divine_answer_invitation(deity, label, words, key)

// The invited player's answer. Their acceptance makes them a follower exactly
// as Divine Patron > Initiate would; a decline is passed back to the god.
/mob/living/human/proc/divine_answer_invitation(deity, label, words, god_key)
	var/claim = divine_book_key(deity)
	if (words)
		to_chat(src, CHAT_TYPED(CHAT_PRAYER, "<span class='notice'><b>[label]</b> calls to you: <i>[words]</i></span>"))
	var/answer = player_alert(src, "[label] invites you to become a follower. Will you follow [label]?", "A god calls to you", list("Follow", "Decline"))
	divine_invite_from = null
	if (QDELETED(src))
		return
	var/outcome
	if (answer != "Follow")
		outcome = "declined"
		to_chat(src, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("You turn away from [label]'s call.")))
	else if (divine_patron || stat == DEAD || !magic_allowed() || !arcane_apostate_may_join(claim))
		outcome = "could not accept"
		to_chat(src, CHAT_TYPED(CHAT_PRAYER, SPAN_WARNING("The call of [label] fades before you can answer.")))
	else
		outcome = "accepted"
		divine_patron = deity
		if (!islist(divine_known))
			divine_known = list()
		arcane_apostate_return(claim) // arcane_apostate.dm
		divine_refresh_verbs()
		to_chat(src, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("You now follow [label].")))
	var/list/told = list() + divine_staff_for(deity)
	var/client/inviter = directory[god_key]
	if (inviter)
		told |= inviter
	for (var/client/C in told)
		to_chat(C, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("[key_name(src, TRUE)] [outcome] the invitation to follow [label].[outcome == "accepted" ? " Teach them an invocation next." : ""]")))
	log_admin("[key_name(src)] [outcome] the invitation to follow [deity].")
