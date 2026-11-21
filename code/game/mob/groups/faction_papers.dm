// Census, citizenship papers, travel passes, permits and border doors
// (docs/faction-papers.md). Anyone with a faction's papers power (the leader,
// an appointed office holder or the bearer of such an office's seal,
// faction_offices.dm) issues sealed papers to a person standing beside them:
// citizenship papers, good until revoked, or a travel pass good for a number
// of days. Papers name their holder and only count for that holder's account,
// so a stolen or copied paper opens nothing. A faction door (key_door.dm) can
// be set to open for citizens, or for citizens and pass holders, as well as
// for members. Any member can read the census: members, offices, land held,
// dues paid and the papers in force. The game turns nobody away by itself
// except at a door its faction set.
//
// The register lives in map.faction_recruitment["papers"] (durable, renamed
// with the faction):
//   faction -> list("seq" = last serial, "open" = list(serial text ->
//                   list(kind, holder name, holder account, issued, expires or 0, issued by)))
// Nothing sleeps except the prompts, which recheck after.

#define PAPERS_OPEN_MAX 200
#define PAPERS_PASS_DAYS_MAX 30
#define PAPERS_DAY 864000
#define PAPERS_ADMIT_MEMBERS 0
#define PAPERS_ADMIT_CITIZENS 1
#define PAPERS_ADMIT_PASSES 2

var/global/list/faction_paper_items = list()
// Kinds of papers and what they are called. Permits are in faction_permits.dm.
var/global/list/faction_paper_kinds = list("citizenship" = "citizenship papers", "pass" = "travel pass", "build" = "building permit", "trade" = "trading licence", "substance" = "substance licence")

// --- Register ------------------------------------------------------------------

/obj/map_metadata/proc/papers_state()
	var/list/S = recruitment_state()
	if (!islist(S["papers"]))
		S["papers"] = list()
	return S["papers"]

/obj/map_metadata/proc/papers_record(faction)
	var/list/S = papers_state()
	var/list/R = S[faction]
	if (!islist(R))
		R = list()
		S[faction] = R
	if (!isnum(R["seq"]) || R["seq"] < 0 || R["seq"] != round(R["seq"]))
		R["seq"] = 0
	if (!islist(R["open"]))
		R["open"] = list()
	return R

/proc/papers_row_valid(list/row)
	return islist(row) && row.len == 6 && (row[1] in faction_paper_kinds) && istext(row[2]) && istext(row[3]) && length(row[3]) && isnum(row[4]) && isnum(row[5]) && istext(row[6])

/obj/map_metadata/proc/papers_normalize()
	var/list/S = papers_state()
	for (var/faction in S.Copy())
		if (!istext(faction) || !islist(S[faction]))
			S -= faction
			continue
		var/list/R = papers_record(faction)
		var/list/open = R["open"]
		for (var/serial in open.Copy())
			if (!istext(serial) || !papers_row_valid(open[serial]))
				open -= serial
		permits_required(faction)
		substance_rules(faction) // faction_substances.dm

/obj/map_metadata/proc/papers_rename(old_name, new_name)
	faction_rename_assoc_key(papers_state(), old_name, new_name)
	for (var/obj/item/faction_papers/P in faction_paper_items)
		if (P.faction == old_name)
			P.faction = new_name
			P.update_papers_name()

// Registers papers and returns the serial, or null when the register is full.
/obj/map_metadata/proc/papers_issue(faction, kind, name, account, days, issuer)
	if (!(kind in faction_paper_kinds) || !istext(account) || !length(account))
		return null
	var/list/R = papers_record(faction)
	var/list/open = R["open"]
	papers_prune(faction)
	if (open.len >= PAPERS_OPEN_MAX)
		return null
	R["seq"]++
	var/serial = "[R["seq"]]"
	var/now = recruitment_now()
	// A pass always runs out; a permit may (0 days: until revoked); citizenship never does.
	var/expires = 0
	if (kind == "pass")
		expires = now + clamp(round(days), 1, PAPERS_PASS_DAYS_MAX) * PAPERS_DAY
	else if (kind != "citizenship" && isnum(days) && days >= 1)
		expires = now + clamp(round(days), 1, PAPERS_PASS_DAYS_MAX) * PAPERS_DAY
	open[serial] = list(kind, istext(name) ? name : "", account, now, expires, istext(issuer) ? issuer : "")
	return serial

// Drops passes that have run out.
/obj/map_metadata/proc/papers_prune(faction)
	var/list/R = papers_record(faction)
	var/list/open = R["open"]
	var/now = recruitment_now()
	for (var/serial in open.Copy())
		var/list/row = open[serial]
		if (!papers_row_valid(row) || (row[5] && now > row[5]))
			open -= serial

// The register row if the papers are still in force, else null.
/obj/map_metadata/proc/papers_row(faction, serial)
	var/list/R = papers_record(faction)
	var/list/row = R["open"][serial]
	if (!papers_row_valid(row))
		return null
	if (row[5] && recruitment_now() > row[5])
		R["open"] -= serial
		return null
	return row

/obj/map_metadata/proc/papers_revoke(faction, serial)
	var/list/R = papers_record(faction)
	var/list/row = R["open"][serial]
	if (!islist(row))
		return FALSE
	R["open"] -= serial
	return TRUE

// --- The papers ----------------------------------------------------------------------

/obj/item/faction_papers
	name = "faction papers"
	desc = "Sealed papers from a faction."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "paper_seal-gaul"
	w_class = ITEM_SIZE_TINY
	var/faction = ""
	var/serial = ""
	var/kind = "citizenship"
	var/holder = ""
	var/holder_account = ""

/obj/item/faction_papers/New()
	..()
	faction_paper_items |= src

/obj/item/faction_papers/Destroy()
	faction_paper_items -= src
	return ..()

/obj/item/faction_papers/after_load()
	..()
	update_papers_name()

/obj/item/faction_papers/proc/update_papers_name()
	icon_state = kind == "citizenship" ? "paper_seal-gaul" : "paper_stamp-gaul"
	if (!length(faction))
		name = initial(name)
		desc = initial(desc)
		return
	switch (kind)
		if ("pass")
			name = "travel pass to [faction] for [holder]"
			desc = "[faction] lets [holder] pass through its lands. No. [serial]."
		if ("build")
			name = "building permit of [faction] for [holder]"
			desc = "[faction] lets [holder] build on its registered land. No. [serial]."
		if ("trade")
			name = "trading licence of [faction] for [holder]"
			desc = "[faction] lets [holder] set up a stall on its registered land. No. [serial]."
		else
			name = "citizenship papers of [faction] for [holder]"
			desc = "[faction] counts [holder] among its citizens. No. [serial]."

/obj/item/faction_papers/proc/in_force()
	return map && length(faction) && map.papers_row(faction, serial) && TRUE

/obj/item/faction_papers/examine(mob/user, distance = -1)
	..()
	if (!length(faction))
		return
	var/list/row = map ? map.papers_row(faction, serial) : null
	if (!row)
		to_chat(user, SPAN_WARNING("The register of [faction] knows no papers in force with this number: they ran out, were revoked, or are false."))
	else if (row[5])
		to_chat(user, SPAN_NOTICE("Good until [faction_seal_date(row[5])]."))

/obj/item/faction_papers/attack_self(mob/user)
	examine(user)

/obj/map_metadata/proc/papers_make(faction, serial, atom/where)
	var/list/row = papers_row(faction, serial)
	if (!row)
		return null
	var/obj/item/faction_papers/P = new(where)
	P.faction = faction
	P.serial = serial
	P.kind = row[1]
	P.holder = row[2]
	P.holder_account = row[3]
	P.update_papers_name()
	return P

// Whether H carries papers that a door of faction set to admits takes. Papers
// count only in the hands or worn directly, and only for their own holder.
/proc/papers_admit(mob/living/human/H, faction, admits)
	if (!map || !istype(H) || admits <= PAPERS_ADMIT_MEMBERS)
		return FALSE
	var/account = faction_roster_account(H)
	if (!account)
		return FALSE
	for (var/obj/item/faction_papers/P in H.contents)
		if (P.faction != faction || P.holder_account != account)
			continue
		var/list/row = map.papers_row(faction, P.serial)
		if (row && row[3] == account && (row[1] == "citizenship" || (row[1] == "pass" && admits >= PAPERS_ADMIT_PASSES)))
			return TRUE
	return FALSE

/proc/papers_admit_label(admits)
	switch (admits)
		if (PAPERS_ADMIT_CITIZENS)
			return "members and citizens"
		if (PAPERS_ADMIT_PASSES)
			return "members, citizens and pass holders"
	return "members only"

// --- Census ----------------------------------------------------------------------------

// The name a roster account goes by: a living character, an office holder or papers.
/obj/map_metadata/proc/census_name(faction, account)
	for (var/mob/living/human/H in human_mob_list)
		if (H.stat != DEAD && H.civilization == faction && faction_roster_account(H) == account)
			return H.real_name
	var/list/O = office_record(faction)
	for (var/office in O["holders"])
		var/list/row = O["holders"][office]
		if (islist(row) && row[1] == account && length(row[2]))
			return row[2]
	var/list/P = papers_record(faction)
	for (var/serial in P["open"])
		var/list/row = P["open"][serial]
		if (papers_row_valid(row) && row[3] == account && length(row[2]))
			return row[2]
	return "an absent member"

/obj/map_metadata/proc/census_lines(faction)
	var/list/lines = list("<b>Census of [faction]</b>")
	var/list/roster = faction_roster(faction)
	var/list/plots_by_name = list()
	for (var/id in land_plots(faction))
		var/list/plot = land_plot(faction, id)
		if (plot && length(plot[10]))
			plots_by_name[plot[10]] = (plots_by_name[plot[10]] || 0) + 1
	lines += "Members: [roster.len] of [faction_member_limit(faction)]."
	for (var/account in roster)
		var/list/row = roster[account]
		var/name = census_name(faction, account)
		var/list/parts = list("[name], joined [faction_seal_date(row[1])]")
		var/paid = treasury_dues_paid(faction, account)
		if (paid > 0)
			parts += "dues paid [paid] silver"
		if (plots_by_name[name])
			parts += "[plots_by_name[name]] plot\s registered"
		lines += "- [jointext(parts, ", ")]"
	var/list/O = office_record(faction)
	var/offices = 0
	for (var/office in O["offices"])
		var/list/held = office_holder_row(faction, office)
		lines += "Office of [office]: [held ? held[2] : "vacant"]"
		offices++
	if (!offices)
		lines += "No offices are defined."
	papers_prune(faction)
	var/list/P = papers_record(faction)
	var/list/counts = list()
	for (var/serial in P["open"])
		var/list/row = P["open"][serial]
		counts[row[1]] = (counts[row[1]] || 0) + 1
	var/list/parts = list()
	for (var/kind in faction_paper_kinds)
		if (counts[kind])
			parts += "[counts[kind]] [faction_paper_kinds[kind]]\s"
	lines += "Papers in force: [parts.len ? english_list(parts) : "none"]."
	var/list/require = permits_required(faction)
	if (require.len)
		lines += "Required on its registered land: [english_list(require)]."
	var/list/renames = papers_name_change_lines(faction)
	if (renames.len)
		lines += "Changes of name on record:"
		for (var/line in renames)
			lines += "- [line]"
	return lines

/obj/map_metadata/proc/papers_lines(faction)
	papers_prune(faction)
	var/list/lines = list("<b>Papers of [faction] in force</b>")
	var/list/P = papers_record(faction)
	for (var/serial in P["open"])
		var/list/row = P["open"][serial]
		lines += "No. [serial]: [faction_paper_kinds[row[1]]] for [row[2]], issued by [row[6]][row[5] ? ", good until [faction_seal_date(row[5])]" : ""]."
	if (lines.len == 1)
		lines += "[faction] has no papers in force."
	return lines

// --- Faction Papers verb -----------------------------------------------------------------

/mob/living/human/proc/faction_papers()
	set name = "Faction Papers"
	set category = "Faction"
	var/faction = civilization
	if (!map || !faction || faction == "none")
		to_chat(src, SPAN_NOTICE("You belong to no faction."))
		return
	var/clerk = map.faction_power(src, faction, "papers")
	var/list/choices = list("Read the census", "Read the papers in force")
	if (clerk)
		choices += list("Issue citizenship papers", "Issue a travel pass", "Issue a building permit", "Issue a trading licence", "Issue a substance licence", "Revoke papers", "Record a change of name", "Set the border doors beside me", "Require permits on our land")
	if (map.is_faction_leader(src, faction))
		choices += "Set substance rules on our land" // faction_substances.dm
	choices += "Cancel"
	var/choice = WWinput(src, "Papers of [faction]", "Faction papers", "Read the census", choices)
	if (!choice || choice == "Cancel" || !(choice in choices) || civilization != faction || stat != CONSCIOUS)
		return
	if (choice == "Set substance rules on our land")
		substance_rules_menu(faction)
		return
	if (!(choice in list("Read the census", "Read the papers in force")) && !map.faction_power(src, faction, "papers"))
		return
	switch (choice)
		if ("Read the census")
			to_chat(src, SPAN_NOTICE(jointext(map.census_lines(faction), "<br>")))
		if ("Read the papers in force")
			to_chat(src, SPAN_NOTICE(jointext(map.papers_lines(faction), "<br>")))
		if ("Issue citizenship papers")
			papers_issue_to(faction, "citizenship")
		if ("Issue a travel pass")
			papers_issue_to(faction, "pass")
		if ("Issue a building permit")
			papers_issue_to(faction, "build")
		if ("Issue a trading licence")
			papers_issue_to(faction, "trade")
		if ("Issue a substance licence")
			papers_issue_to(faction, "substance")
		if ("Require permits on our land")
			permits_require_menu(faction)
		if ("Record a change of name")
			papers_record_name_change(faction)
		if ("Revoke papers")
			map.papers_prune(faction)
			var/list/R = map.papers_record(faction)
			var/list/options = list()
			for (var/serial in R["open"])
				var/list/row = R["open"][serial]
				options["No. [serial]: [faction_paper_kinds[row[1]]] for [row[2]]"] = serial
			if (!options.len)
				to_chat(src, SPAN_NOTICE("[faction] has no papers in force."))
				return
			var/pick = WWinput(src, "Revoke which papers?", "Revoke papers", "Cancel", options + "Cancel")
			if (!pick || pick == "Cancel" || !(pick in options) || !map.faction_power(src, faction, "papers"))
				return
			if (map.papers_revoke(faction, options[pick]))
				to_chat(src, SPAN_NOTICE("You strike [pick] from the register of [faction]."))
				log_game("[key_name(src)] revoked papers [options[pick]] of [faction].")
		if ("Set the border doors beside me")
			var/list/doors = list()
			for (var/obj/structure/simple_door/key_door/faction_door/D in range(1, src))
				if (D.faction == faction)
					doors += D
			if (!doors.len)
				to_chat(src, SPAN_WARNING("Stand beside one of [faction]'s doors."))
				return
			var/list/modes = list("Members only" = PAPERS_ADMIT_MEMBERS, "Members and citizens" = PAPERS_ADMIT_CITIZENS, "Members, citizens and pass holders" = PAPERS_ADMIT_PASSES)
			var/pick = WWinput(src, "Who may pass the [doors.len == 1 ? "door" : "[doors.len] doors"] beside you?", "Border doors", "Cancel", modes + "Cancel")
			if (!pick || pick == "Cancel" || !(pick in modes) || !map.faction_power(src, faction, "papers"))
				return
			var/set_count = 0
			for (var/obj/structure/simple_door/key_door/faction_door/D in doors)
				if (!QDELETED(D) && D.faction == faction && get_dist(src, D) <= 1)
					D.admits = modes[pick]
					set_count++
			to_chat(src, SPAN_NOTICE("[set_count] door\s now open for [papers_admit_label(modes[pick])]."))

/mob/living/human/proc/papers_issue_to(faction, kind)
	var/list/people = list()
	for (var/mob/living/human/M in range(1, src))
		if (M.stat != DEAD && faction_roster_account(M))
			people["[M.real_name]"] = M
	if (!people.len)
		to_chat(src, SPAN_NOTICE("Papers are issued to someone standing beside you."))
		return
	var/what = kind == "citizenship" ? "citizenship papers" : "a [faction_paper_kinds[kind]]"
	var/pick = WWinput(src, "Issue [what] to whom?", "Papers", "Cancel", people + "Cancel")
	if (!pick || pick == "Cancel" || !(pick in people))
		return
	var/days = 0
	if (kind == "pass")
		days = player_input(src, "How many days is the pass good for (1 to [PAPERS_PASS_DAYS_MAX])?", "Travel pass", 7, "num", null, TRUE)
		if (!isnum(days) || days < 1)
			return
	else if (kind != "citizenship")
		days = player_input(src, "How many days is it good for (1 to [PAPERS_PASS_DAYS_MAX], or 0 until revoked)?", capitalize(faction_paper_kinds[kind]), 0, "num", null, TRUE)
		if (!isnum(days) || days < 0)
			return
	var/mob/living/human/M = people[pick]
	// Everything is checked again after the prompts.
	if (QDELETED(M) || M.stat == DEAD || get_dist(src, M) > 1 || civilization != faction || !map.faction_power(src, faction, "papers"))
		return
	var/list/paper = bill_blank_supply(src)
	if (!paper.len)
		to_chat(src, SPAN_WARNING("You need a blank sheet of paper in your hands or at your feet."))
		return
	var/serial = map.papers_issue(faction, kind, M.real_name, faction_roster_account(M), days, real_name)
	if (!serial)
		to_chat(src, SPAN_WARNING("The register of [faction] holds no more papers. Revoke some first."))
		return
	var/obj/item/weapon/paper/P = paper[1]
	drop_from_inventory(P)
	qdel(P)
	var/obj/item/faction_papers/F = map.papers_make(faction, serial, get_turf(M))
	if (F && !M.put_in_hands(F))
		F.forceMove(get_turf(M))
	visible_message(SPAN_NOTICE("[src] seals [what] of [faction] for [M.real_name]."))
	log_game("[key_name(src)] issued [what] no. [serial] of [faction] to [key_name(M)].")

#undef PAPERS_OPEN_MAX
#undef PAPERS_PASS_DAYS_MAX
#undef PAPERS_DAY
