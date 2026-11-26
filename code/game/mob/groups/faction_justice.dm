// Laws, courts and warrants (docs/faction-justice.md). A faction's leader
// writes its laws. Anyone with the justice power (faction_offices.dm: the
// leader, an appointed Judge, or whoever carries the seal of such an office)
// holds trials at a gavel block, issues warrants and pardons. A trial ends in
// a written judgment: a fine (paid into the strongbox), jail (served behind
// a door with a cell timer, which the justice power may now set), banishment
// from the faction's lands, outlawry, or a warning. Warrants and outlaws show
// when anyone examines the person, and a warrant prints as a wanted poster.
// The game enforces none of it beyond the cell timer: players do.
//
// State in map.faction_recruitment["justice"] (durable, renamed with the
// faction):
//   faction -> list("laws" = list(text),
//                   "warrants" = list(account = list(name, charge, issued by, time)),
//                   "outlaws" = list(account = list(name, reason, time)),
//                   "fines" = list(account = list(name, silver owed)),
//                   "record" = list(text, newest last))
// Nothing sleeps except the prompts, which recheck after.

#define JUSTICE_LAWS_MAX 20
#define JUSTICE_TEXT_MAX 160
#define JUSTICE_RECORD_MAX 40
#define JUSTICE_FINE_MAX 500
#define JUSTICE_JAIL_MAX 30
#define JUSTICE_TRIAL_RANGE 5

// --- State -------------------------------------------------------------------

/obj/map_metadata/proc/justice_state()
	var/list/S = recruitment_state()
	if (!islist(S["justice"]))
		S["justice"] = list()
	return S["justice"]

/obj/map_metadata/proc/justice_record(faction)
	var/list/S = justice_state()
	var/list/R = S[faction]
	if (!islist(R))
		R = list()
		S[faction] = R
	for (var/key in list("laws", "warrants", "outlaws", "fines", "record"))
		if (!islist(R[key]))
			R[key] = list()
	return R

/obj/map_metadata/proc/justice_normalize()
	var/list/S = justice_state()
	for (var/faction in S.Copy())
		if (!istext(faction) || !islist(S[faction]))
			S -= faction
			continue
		var/list/R = justice_record(faction)
		for (var/key in list("laws", "record"))
			var/list/L = R[key]
			for (var/line in L.Copy())
				if (!istext(line))
					L -= line
		var/list/rows = list("warrants" = 4, "outlaws" = 3, "fines" = 2)
		for (var/key in rows)
			var/list/L = R[key]
			for (var/account in L.Copy())
				var/list/row = L[account]
				if (!istext(account) || !islist(row) || row.len != rows[key] || !istext(row[1]))
					L -= account
				else if (key == "fines" && (!isnum(row[2]) || row[2] <= 0))
					L -= account

/obj/map_metadata/proc/justice_rename(old_name, new_name)
	faction_rename_assoc_key(justice_state(), old_name, new_name)

/obj/map_metadata/proc/justice_log(faction, text)
	var/list/R = justice_record(faction)
	var/list/record = R["record"]
	record += "[faction_seal_date(recruitment_now())]: [text]"
	while (record.len > JUSTICE_RECORD_MAX)
		record.Cut(1, 2)

/proc/justice_text_clean(value)
	if (!istext(value))
		return ""
	var/clean = sanitize(value, JUSTICE_TEXT_MAX + 1, FALSE)
	if (!istext(clean))
		return ""
	clean = trim(clean)
	return length(clean) <= JUSTICE_TEXT_MAX ? clean : ""

// Numbered labels are menu choices, never the law text or a reserved control.
/proc/justice_law_choices(list/laws)
	var/list/choices = list()
	for (var/i in 1 to laws.len)
		choices["[i]. [laws[i]]"] = i
	return choices

// An open prompt cannot repeal a different row after the list changes.
/proc/justice_repeal_law_at(list/laws, list/offered, index)
	if (!isnum(index) || index < 1 || index > offered.len || laws.len != offered.len)
		return null
	for (var/i in 1 to offered.len)
		if (laws[i] != offered[i])
			return null
	var/law = laws[index]
	laws.Cut(index, index + 1)
	return law

// --- Rulings -----------------------------------------------------------------------

/obj/map_metadata/proc/justice_warrant(faction, account, name, charge, issuer)
	if (!istext(account) || !length(account))
		return FALSE
	var/list/R = justice_record(faction)
	R["warrants"][account] = list(name, charge, issuer, recruitment_now())
	justice_log(faction, "[issuer] issued a warrant for [name]: [charge].")
	return TRUE

/obj/map_metadata/proc/justice_fine(faction, account, name, silver)
	silver = clamp(round(silver), 1, JUSTICE_FINE_MAX)
	var/list/R = justice_record(faction)
	var/list/row = R["fines"][account]
	if (islist(row))
		row[2] += silver
		row[1] = name
	else
		R["fines"][account] = list(name, silver)
	return silver

/obj/map_metadata/proc/justice_pay_fine(faction, account, worth)
	var/list/R = justice_record(faction)
	var/list/row = R["fines"][account]
	if (!islist(row) || worth <= 0)
		return -1
	row[2] = round(max(0, row[2] - worth), 0.1)
	if (row[2] <= 0)
		R["fines"] -= account
		return 0
	return row[2]

// Carries out a guilty verdict. sentence is one of the JUSTICE sentence names;
// amount is silver for a fine and minutes for jail. Returns the judgment line.
/obj/map_metadata/proc/justice_sentence(faction, account, name, charge, sentence, amount, judge)
	var/list/R = justice_record(faction)
	R["warrants"] -= account
	var/line
	switch (sentence)
		if ("Fine")
			var/silver = justice_fine(faction, account, name, amount)
			line = "fined [silver] silver, to be paid into the treasury of [faction]"
		if ("Jail")
			line = "sentenced to [clamp(round(amount), 1, JUSTICE_JAIL_MAX)] minutes in jail"
		if ("Banishment")
			line = "banished from the lands of [faction]"
		if ("Outlawry")
			R["outlaws"][account] = list(name, charge, recruitment_now())
			line = "declared an outlaw of [faction]"
		else
			line = "warned"
	justice_log(faction, "[judge] found [name] guilty of [charge]: [line].")
	return line

/obj/map_metadata/proc/justice_pardon(faction, account, judge)
	var/list/R = justice_record(faction)
	var/name = null
	for (var/key in list("warrants", "outlaws", "fines"))
		var/list/row = R[key][account]
		if (islist(row))
			name = row[1]
			R[key] -= account
	if (name)
		justice_log(faction, "[judge] pardoned [name].")
	return name

// Every roster account of the person behind account: a court mark on one of
// a player's characters marks their kin too (docs/character-slots.md).
/proc/justice_kin_accounts(account)
	. = list(account)
	var/person = owner_key_account(account)
	if (!person)
		return
	for (var/slot = 1 to character_slots_max)
		var/key = owner_key_for(person, slot)
		if (key)
			. |= key

// Lines for examining someone: warrants and outlawry against them, or their
// kin, anywhere.
/proc/justice_examine_lines(mob/living/human/H)
	var/list/lines = list()
	if (!map || !istype(H))
		return lines
	var/own = faction_roster_account(H)
	if (!own)
		return lines
	var/list/S = map.justice_state()
	for (var/account in justice_kin_accounts(own))
		var/kin = account != own
		for (var/faction in S)
			var/list/R = S[faction]
			if (!islist(R))
				continue
			if (islist(R["outlaws"]) && islist(R["outlaws"][account]))
				lines += kin ? "[H.real_name] is kin to [R["outlaws"][account][1]], an outlaw of [faction]." : "[H.real_name] is an outlaw of [faction]."
			else if (islist(R["warrants"]) && islist(R["warrants"][account]))
				lines += kin ? "[faction] has a warrant out for [R["warrants"][account][1]], kin to [H.real_name]." : "[faction] has a warrant out for [H.real_name]."
	return lines

/mob/living/human/examine(mob/user)
	. = ..()
	if (user && user != src)
		for (var/line in justice_examine_lines(src))
			to_chat(user, SPAN_WARNING(line))

// The justice power also sets cell timers (cmss13_ops.dm).
/proc/justice_can_jail(mob/living/human/H)
	return map && istype(H) && H.civilization && H.civilization != "none" && map.faction_power(H, H.civilization, "justice")

// --- Papers -------------------------------------------------------------------------

/proc/justice_paper(atom/where, title, body)
	var/obj/item/weapon/paper/P = new /obj/item/weapon/paper(where)
	P.name = title
	P.info = body
	P.update_icon()
	return P

/proc/justice_warrant_text(faction, name, charge, issuer)
	return "<center><b>WANTED</b><hr>by order of [html_encode(faction)]</center><br>[html_encode(name)] is to be brought before the court of [html_encode(faction)] for [html_encode(charge)].<br><br>Issued by [html_encode(issuer)], [faction_seal_date(recruitment_now())]."

/proc/justice_judgment_text(faction, name, charge, verdict, judge)
	return "<center><b>JUDGMENT</b><hr>Court of [html_encode(faction)]</center><br>In the matter of [html_encode(name)], charged with [html_encode(charge)]:<br><br>[html_encode(verdict)].<br><br>Given by [html_encode(judge)], [faction_seal_date(recruitment_now())]."

// --- Faction Justice verb ------------------------------------------------------------

/proc/justice_court_near(mob/user)
	for (var/obj/item/weapon/gavelblock/G in range(1, user))
		return G
	return null

/proc/justice_list_text(faction, list/R, key)
	var/list/lines = list()
	for (var/account in R[key])
		var/list/row = R[key][account]
		switch (key)
			if ("warrants")
				lines += "Warrant: [row[1]], for [row[2]] (issued by [row[3]])."
			if ("outlaws")
				lines += "Outlaw: [row[1]], for [row[2]]."
			if ("fines")
				lines += "Fine owed: [row[1]], [row[2]] silver."
	return lines

/mob/living/human/proc/faction_justice()
	set name = "Faction Justice"
	set category = "Faction"
	var/faction = civilization
	if (!map || !faction || faction == "none")
		to_chat(src, SPAN_NOTICE("You belong to no faction."))
		return
	var/leader = map.is_faction_leader(src, faction)
	var/judge = map.faction_power(src, faction, "justice")
	var/list/choices = list("Read the laws", "Read warrants, outlaws and fines", "Read the court record")
	if (leader)
		choices += list("Write a law", "Repeal a law")
	if (judge)
		choices += list("Hold a trial", "Issue a warrant", "Pardon")
	choices += "Cancel"
	var/choice = WWinput(src, "Justice of [faction]", "Faction justice", "Read the laws", choices)
	if (!choice || choice == "Cancel" || !(choice in choices) || civilization != faction || stat != CONSCIOUS)
		return
	if ((choice in list("Write a law", "Repeal a law")) && !map.is_faction_leader(src, faction))
		return
	if ((choice in list("Hold a trial", "Issue a warrant", "Pardon")) && !map.faction_power(src, faction, "justice"))
		return
	var/list/R = map.justice_record(faction)
	switch (choice)
		if ("Read the laws")
			var/list/lines = list("<b>Laws of [faction]</b>")
			var/i = 0
			for (var/law in R["laws"])
				lines += "[++i]. [law]"
			if (!i)
				lines += "[faction] has written no laws."
			lines += map.substance_rule_lines(faction) // faction_substances.dm
			to_chat(src, SPAN_NOTICE(jointext(lines, "<br>")))
		if ("Read warrants, outlaws and fines")
			var/list/lines = list("<b>Justice of [faction]</b>") + justice_list_text(faction, R, "warrants") + justice_list_text(faction, R, "outlaws") + justice_list_text(faction, R, "fines")
			if (lines.len == 1)
				lines += "Nobody is wanted, outlawed or owes a fine."
			to_chat(src, SPAN_NOTICE(jointext(lines, "<br>")))
		if ("Read the court record")
			var/list/record = R["record"]
			to_chat(src, SPAN_NOTICE(record.len ? "<b>Court record of [faction]</b><br>[jointext(record, "<br>")]" : "The court of [faction] has no record yet."))
		if ("Write a law")
			if (length(R["laws"]) >= JUSTICE_LAWS_MAX)
				to_chat(src, SPAN_WARNING("[faction] already has [JUSTICE_LAWS_MAX] laws. Repeal one first."))
				return
			var/law = justice_text_clean(player_input(src, "Write the law, in at most [JUSTICE_TEXT_MAX] letters:", "New law", "", "text", null, TRUE))
			if (!length(law) || !map.is_faction_leader(src, faction))
				return
			R["laws"] += law
			map.justice_log(faction, "[real_name] made a law: [law]")
			map.office_announce(faction, "A new law of [faction]: [law]")
		if ("Repeal a law")
			var/list/laws = R["laws"]
			if (!laws.len)
				to_chat(src, SPAN_NOTICE("[faction] has no laws to repeal."))
				return
			var/list/offered = laws.Copy()
			var/list/options = justice_law_choices(offered)
			var/pick = WWinput(src, "Repeal which law?", "Repeal", "Cancel", options + "Cancel")
			if (!pick || !(pick in options) || civilization != faction || stat != CONSCIOUS || !map.is_faction_leader(src, faction))
				return
			var/list/current = map.justice_record(faction)
			var/law = justice_repeal_law_at(current["laws"], offered, options[pick])
			if (isnull(law))
				return
			map.justice_log(faction, "[real_name] repealed a law: [law]")
			map.office_announce(faction, "[faction] repeals a law: [law]")
		if ("Hold a trial")
			justice_hold_trial(faction)
		if ("Issue a warrant")
			justice_issue_warrant(faction)
		if ("Pardon")
			var/list/options = list()
			for (var/key in list("warrants", "outlaws", "fines"))
				for (var/account in R[key])
					options[R[key][account][1]] = account
			if (!options.len)
				to_chat(src, SPAN_NOTICE("Nobody is wanted, outlawed or fined by [faction]."))
				return
			var/pick = WWinput(src, "Pardon whom? This clears their warrant, outlawry and fines.", "Pardon", "Cancel", options + "Cancel")
			if (!pick || pick == "Cancel" || !(pick in options) || !map.faction_power(src, faction, "justice"))
				return
			if (map.justice_pardon(faction, options[pick], real_name))
				map.office_announce(faction, "[real_name] pardons [pick].")

// The people nearby who can stand trial or be named in a warrant.
/mob/living/human/proc/justice_people(range_tiles)
	var/list/people = list()
	for (var/mob/living/human/M in range(range_tiles, src))
		if (M != src && M.stat != DEAD && faction_roster_account(M))
			people["[M.real_name]"] = M
	return people

/mob/living/human/proc/justice_charge(faction, question)
	var/list/R = map.justice_record(faction)
	var/list/laws = R["laws"]
	var/list/offered = laws.Copy()
	var/list/options = justice_law_choices(offered)
	var/pick = WWinput(src, question, "Charge", "Something else", options + list("Something else", "Cancel"))
	if (pick == "Something else")
		return justice_text_clean(player_input(src, "Name the charge:", "Charge", "", "text", null, TRUE))
	if (!pick || !(pick in options))
		return ""
	return offered[options[pick]]

/mob/living/human/proc/justice_hold_trial(faction)
	var/obj/item/weapon/gavelblock/G = justice_court_near(src)
	if (!G)
		to_chat(src, SPAN_WARNING("Trials are held at a gavel block. Stand beside one."))
		return
	var/list/people = justice_people(JUSTICE_TRIAL_RANGE)
	if (!people.len)
		to_chat(src, SPAN_NOTICE("Nobody stands before the court."))
		return
	var/pick = WWinput(src, "Who stands trial?", "Trial", "Cancel", people + "Cancel")
	if (!pick || pick == "Cancel" || !(pick in people))
		return
	var/mob/living/human/A = people[pick]
	var/charge = justice_charge(faction, "What is [pick] charged with?")
	if (!length(charge))
		return
	var/verdict = WWinput(src, "[pick], charged with [charge]. Your verdict?", "Trial", "Cancel", list("Guilty", "Not guilty", "Cancel"))
	if (!verdict || verdict == "Cancel")
		return
	var/sentence = "Warning"
	var/amount = 0
	if (verdict == "Guilty")
		sentence = WWinput(src, "The sentence?", "Trial", "Warning", list("Fine", "Jail", "Banishment", "Outlawry", "Warning"))
		if (sentence == "Fine")
			amount = player_input(src, "Fine in silver (1 to [JUSTICE_FINE_MAX]):", "Fine", 10, "num", null, TRUE)
		else if (sentence == "Jail")
			amount = player_input(src, "Minutes in jail (1 to [JUSTICE_JAIL_MAX]):", "Jail", 5, "num", null, TRUE)
		if (!(sentence in list("Fine", "Jail", "Banishment", "Outlawry", "Warning")) || ((sentence in list("Fine", "Jail")) && !isnum(amount)))
			return
	// Everything is checked again after the prompts.
	if (QDELETED(A) || get_dist(src, A) > JUSTICE_TRIAL_RANGE || !justice_court_near(src) || civilization != faction || !map.faction_power(src, faction, "justice"))
		return
	var/account = faction_roster_account(A)
	if (!account)
		return
	var/line
	if (verdict == "Guilty")
		line = "Guilty: [A.real_name] is [map.justice_sentence(faction, account, A.real_name, charge, sentence, amount, real_name)]"
	else
		var/list/R = map.justice_record(faction)
		R["warrants"] -= account
		map.justice_log(faction, "[real_name] found [A.real_name] not guilty of [charge].")
		line = "Not guilty: [A.real_name] goes free"
	playsound(get_turf(G), 'sound/effects/gavel.ogg', 90, 1)
	visible_message(SPAN_NOTICE("<b>The court of [faction] finds [A.real_name] [lowertext(verdict)] of [charge].</b>"))
	var/obj/item/weapon/paper/P = justice_paper(get_turf(src), "judgment on [A.real_name]", justice_judgment_text(faction, A.real_name, charge, line, real_name))
	put_in_hands(P)
	to_chat(src, SPAN_NOTICE("You write out the judgment. Seal it to make it official.[sentence == "Jail" ? " Shut [A.real_name] behind a door and set its Cell Timer." : ""]"))
	log_game("[key_name(src)] tried [key_name(A)] for [faction] on '[charge]': [line].")
	accolade_judged(A) // accolades.dm: Magistrate

/mob/living/human/proc/justice_issue_warrant(faction)
	var/list/people = justice_people(7)
	var/list/R = map.justice_record(faction)
	// A warrant can also name someone the faction has dealt with before.
	for (var/key in list("warrants", "outlaws", "fines"))
		for (var/account in R[key])
			var/name = R[key][account][1]
			if (!(name in people))
				people[name] = account
	if (!people.len)
		to_chat(src, SPAN_NOTICE("Name someone you can see, or someone already in the court's books."))
		return
	var/pick = WWinput(src, "A warrant for whom?", "Warrant", "Cancel", people + "Cancel")
	if (!pick || pick == "Cancel" || !(pick in people))
		return
	var/charge = justice_charge(faction, "What for?")
	if (!length(charge) || civilization != faction || !map.faction_power(src, faction, "justice"))
		return
	var/target = people[pick]
	var/account = ismob(target) ? faction_roster_account(target) : target
	if (!istext(account) || !map.justice_warrant(faction, account, pick, charge, real_name))
		return
	var/obj/item/weapon/paper/P = justice_paper(get_turf(src), "wanted: [pick]", justice_warrant_text(faction, pick, charge, real_name))
	put_in_hands(P)
	map.office_announce(faction, "[real_name] issues a warrant for [pick]: [charge].")

// --- Fines at the strongbox ------------------------------------------------------------

/obj/structure/closet/crate/faction_strongbox/proc/pay_fine(mob/living/human/user)
	var/obj/item/stack/money/M = user.get_active_hand()
	if (!istype(M) || !M.is_metal_coin() || M.amount < 1)
		to_chat(user, SPAN_NOTICE("Hold the coins you want to pay in your hand."))
		return
	var/list/R = map.justice_record(faction)
	var/list/options = list()
	for (var/account in R["fines"])
		var/list/row = R["fines"][account]
		options["[row[1]] ([row[2]] silver owed)"] = account
	if (!options.len)
		to_chat(user, SPAN_NOTICE("Nobody owes [faction] a fine."))
		return
	var/pick = WWinput(user, "Pay whose fine?", "Fine", "Cancel", options + "Cancel")
	if (!pick || pick == "Cancel" || !(pick in options) || user.get_active_hand() != M || !user.Adjacent(src))
		return
	var/list/row = R["fines"][options[pick]]
	if (!islist(row))
		return
	var/name = row[1]
	var/worth = round(M.amount * M.value, 0.1)
	user.drop_from_inventory(M)
	M.forceMove(opened ? loc : src)
	var/left = map.justice_pay_fine(faction, options[pick], worth)
	map.treasury_log(faction, "[user.real_name] paid [weighed_silver_text(worth)] toward [name]'s fine.")
	map.justice_log(faction, "[user.real_name] paid [weighed_silver_text(worth)] toward [name]'s fine.")
	to_chat(user, SPAN_NOTICE("You pay [weighed_silver_text(worth)] toward [name]'s fine. [left > 0 ? "[left] silver is still owed." : "It is paid."]"))

#undef JUSTICE_LAWS_MAX
#undef JUSTICE_TEXT_MAX
#undef JUSTICE_RECORD_MAX
#undef JUSTICE_FINE_MAX
#undef JUSTICE_JAIL_MAX
#undef JUSTICE_TRIAL_RANGE
