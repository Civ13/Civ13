// Taking a new name (Val, 2026-11-16; docs/name-changes.md). People take new
// names for many reasons (a faith, a trade, exile, a fresh start); there is
// no marriage. There are two ways to do it:
// - A member of a faction files the change with whoever keeps its papers
//   (the papers power, faction_papers.dm). The clerk records it for a member
//   standing beside them and writes a record of change of name on a blank
//   sheet. Papers the member holds are rewritten to the new name.
// - Someone in no faction takes a new name themselves with Take a new name.
// Either way the character then waits NAME_CHANGE_LOCK (7 real days) before
// changing it again. Only in persistent worlds.
//
// The old name is never lost. The character keeps its former names: its own
// locks, traps and crew places still answer to them, and a craft that barred
// it still bars it. The region keeps a dated record per account, and admins
// see both in the player panel. Bans, notes, rosters, warrants and fines key on
// the account (ckey), so a new name dodges none of them; faction records that
// show a name for the account take the new one. Books, paintings, signatures
// and other things already written keep the name they were made under.
// Nothing here sleeps except the prompts, which recheck after.

#define NAME_CHANGE_LOCK (7 * 24 * 36000)
#define NAME_HISTORY_MAX 20
#define NAME_HISTORY_LINE_MAX 200

/mob/living/human
	var/name_change_lock = 0     // world.realtime before which the name can't change in play
	var/list/former_names = null // names this character went by before, oldest first
	var/list/name_history = null // dated lines, for admins

/proc/name_change_enabled()
	return map && (map.persistence || map.nomads)

// --- Answering to a name ----------------------------------------------------------

// Whether this mob goes, or went, by name. Used where things were left keyed
// by a character's name (locks, traps, craft crews), so a new name keeps them.
/mob/proc/answers_to_name(name)
	return istext(name) && length(name) && real_name == name

/mob/living/human/answers_to_name(name)
	if (..())
		return TRUE
	return istext(name) && length(name) && islist(former_names) && (name in former_names)

// The value an assoc list keyed by character name holds for this mob, trying
// the current name first and then former names, newest first.
/mob/proc/value_by_name(list/L)
	if (!islist(L))
		return null
	return L[real_name]

/mob/living/human/value_by_name(list/L)
	. = ..()
	if (!isnull(.) || !islist(former_names) || !islist(L))
		return
	for (var/i = former_names.len, i >= 1, i--)
		var/old = former_names[i]
		if (istext(old) && !isnull(L[old]))
			return L[old]
	return null

/mob/proc/any_name_in(list/L)
	if (!islist(L))
		return FALSE
	for (var/entry in L)
		if (answers_to_name(entry))
			return TRUE
	return FALSE

// --- Rules ---------------------------------------------------------------------

/mob/living/human/proc/name_change_wait_text()
	var/left = name_change_lock - world.realtime
	if (left <= 0)
		return null
	var/hours = round(left / 36000)
	if (hours >= 24)
		return "[round(hours / 24)] day\s and [hours % 24] hour\s"
	return hours >= 1 ? "[hours] hour\s" : "less than an hour"

// The cleaned name, or null.
/mob/living/human/proc/name_change_clean(raw)
	if (!istext(raw))
		return null
	return sanitize_name(copytext(trim(raw), 1, MAX_NAME_LEN + 1), species ? species.name : "Human")

// Why new_name can't be taken now, or null when it can.
/mob/living/human/proc/name_change_refusal(new_name)
	if (!name_change_enabled())
		return "Names can only be changed in persistent worlds."
	if (stat == DEAD)
		return "The dead keep their names."
	var/wait = name_change_wait_text()
	if (wait)
		return "[real_name] changed name recently and can take another in [wait]."
	if (isnull(new_name))
		return null
	if (!istext(new_name) || !length(new_name))
		return "A name is 2 to [MAX_NAME_LEN] letters. It may also hold spaces, hyphens, apostrophes and full stops."
	if (new_name == real_name)
		return "That is already the name."
	for (var/mob/living/human/M in human_mob_list)
		if (M != src && M.stat != DEAD && M.real_name == new_name)
			return "Someone here already goes by [new_name]."
	return null

// --- Changing it --------------------------------------------------------------------

// Takes new_name now, with no checks: callers check name_change_refusal()
// after their prompts. how is a short note for the record.
/mob/living/human/proc/take_new_name(new_name, how)
	var/old_name = real_name
	if (!new_name || new_name == old_name || !fully_replace_character_name(old_name, new_name))
		return FALSE
	if (name != real_name)
		name = real_name
	name_change_lock = world.realtime + NAME_CHANGE_LOCK
	// A chosen name replaces an adopted family name for good.
	if (adoption_original_name)
		adoption_original_name = null
		adoption_refresh_verbs()
	record_name_change(old_name, new_name, how)
	return TRUE

// Keeps the trail of a change already made (here, or by adoption) and moves
// the faction records that show a name for this account onto the new one.
/mob/living/human/proc/record_name_change(old_name, new_name, how)
	if (!istext(old_name) || !length(old_name) || old_name == new_name)
		return
	if (!islist(former_names))
		former_names = list()
	former_names -= old_name
	former_names -= new_name
	former_names += old_name
	while (former_names.len > NAME_HISTORY_MAX)
		former_names.Cut(1, 2)
	var/line = copytext("[faction_seal_date(world.realtime)]: [old_name] became [new_name] ([how]).", 1, NAME_HISTORY_LINE_MAX + 1)
	if (!islist(name_history))
		name_history = list()
	name_history += line
	while (name_history.len > NAME_HISTORY_MAX)
		name_history.Cut(1, 2)
	var/account = faction_roster_account(src)
	if (map && account)
		map.character_renamed(account, old_name, new_name, civilization, line)
	log_game("[key_name(src)] changed name from [old_name] to [new_name] ([how]).")
	log_admin("[key_name(src)] changed name from [old_name] to [new_name] ([how]).")

// Faction records keyed by account that also show the holder's name.
/obj/map_metadata/proc/character_renamed(account, old_name, new_name, faction, line)
	var/list/S = recruitment_state()
	if (!islist(S["names"]))
		S["names"] = list()
	var/list/N = S["names"]
	var/list/rows = N[account]
	if (!islist(rows))
		rows = list()
		N[account] = rows
	rows += line
	while (rows.len > NAME_HISTORY_MAX)
		rows.Cut(1, 2)
	// Wages follow the account and preserve their accrued balance.
	treasury_refresh_wage_name(account, old_name, new_name)
	// Offices and candidates.
	for (var/f in office_state())
		if (!istext(f))
			continue
		var/list/R = office_record(f)
		for (var/office in R["holders"])
			var/list/row = R["holders"][office]
			if (islist(row) && row.len == 3 && row[1] == account)
				row[2] = new_name
		var/list/E = R["election"]
		if (islist(E) && E.len >= 3 && islist(E[3]) && (account in E[3]))
			E[3][account] = new_name
	// Papers stay in force under the new name, on the register and on paper.
	for (var/f in papers_state())
		if (!istext(f))
			continue
		var/list/R = papers_record(f)
		for (var/serial in R["open"])
			var/list/row = R["open"][serial]
			if (papers_row_valid(row) && row[3] == account)
				row[2] = new_name
	for (var/obj/item/faction_papers/P in faction_paper_items)
		if (P.holder_account == account)
			P.holder = new_name
			P.update_papers_name()
	// Warrants, outlawry and fines follow the account; their names follow too.
	for (var/f in justice_state())
		if (!istext(f))
			continue
		var/list/R = justice_record(f)
		var/moved = FALSE
		for (var/key in list("warrants", "outlaws", "fines"))
			var/list/row = R[key][account]
			if (islist(row) && row.len && istext(row[1]))
				row[1] = new_name
				moved = TRUE
		if (moved)
			justice_log(f, "[old_name] now goes by [new_name].")
	// Plots registered to the old name in the character's own faction.
	if (istext(faction) && faction != "none")
		for (var/id in land_plots(faction))
			var/list/plot = land_plot(faction, id)
			if (plot && plot[10] == old_name)
				plot[10] = new_name

// --- Admin view ------------------------------------------------------------------------

/mob/proc/name_history_admin_html()
	return ""

/mob/living/human/name_history_admin_html()
	var/list/lines = list()
	if (islist(name_history))
		lines |= name_history
	var/account = faction_roster_account(src)
	if (map && account)
		var/list/S = map.recruitment_state()
		var/list/N = S["names"]
		if (islist(N) && islist(N[account]))
			lines |= N[account]
	if (!lines.len)
		return ""
	var/list/out = list()
	for (var/line in lines)
		if (istext(line))
			out += html_encode(line)
	return "<b>Name history</b>:<br>[jointext(out, "<br>")]<br><br>"

// --- Take a new name (no faction) ----------------------------------------------------------

/mob/living/human/verb/take_a_new_name()
	set name = "Take a new name"
	set category = "IC"
	set desc = "Take a new name. Faction members file it with whoever keeps their faction's papers."
	if (!name_change_enabled())
		to_chat(src, SPAN_WARNING("Names can only be changed in persistent worlds."))
		return
	if (stat != CONSCIOUS)
		return
	if (civilization && civilization != "none")
		to_chat(src, SPAN_NOTICE("You belong to [civilization], so a change of name is filed with whoever keeps its papers. Stand beside them; they record it with Faction Papers and write you a record of it."))
		return
	var/refusal = name_change_refusal(null)
	if (refusal)
		to_chat(src, SPAN_WARNING(refusal))
		return
	var/raw = player_input(src, "What name do you take? Your old name stays on record, and you can't change it again for 7 real days.", "Take a new name", real_name, "text", null, TRUE)
	if (!raw)
		return
	var/new_name = name_change_clean(raw)
	// Everything is checked again after the prompt.
	if (stat != CONSCIOUS || (civilization && civilization != "none"))
		return
	refusal = name_change_refusal(new_name)
	if (refusal)
		to_chat(src, SPAN_WARNING(refusal))
		return
	var/old_name = real_name
	if (take_new_name(new_name, "taken by themselves"))
		to_chat(src, SPAN_NOTICE("You are [new_name] now. People who knew you as [old_name] will have to be told."))

// --- Recorded by a faction clerk (Faction Papers) --------------------------------------------

/mob/living/human/proc/papers_record_name_change(faction)
	var/list/people = list()
	for (var/mob/living/human/M in range(1, src))
		if (M.stat != DEAD && M.civilization == faction && faction_roster_account(M))
			people["[M.real_name][M == src ? " (yourself)" : ""]"] = M
	if (!people.len)
		to_chat(src, SPAN_NOTICE("A change of name is recorded for a member of [faction] standing beside you."))
		return
	var/pick = WWinput(src, "Record a change of name for whom?", "Change of name", "Cancel", people + "Cancel")
	if (!pick || pick == "Cancel" || !(pick in people))
		return
	var/mob/living/human/M = people[pick]
	var/refusal = M.name_change_refusal(null)
	if (refusal)
		to_chat(src, SPAN_WARNING(refusal))
		return
	if (!length(bill_blank_supply(src)))
		to_chat(src, SPAN_WARNING("You need a blank sheet of paper in your hands or at your feet."))
		return
	if (M != src)
		to_chat(src, SPAN_NOTICE("You ask [M.real_name] what name to record."))
	var/raw = player_input(M, M == src ? "What name do you take? The old one stays on the register of [faction], and it can't change again for 7 real days." : "[real_name] will record a change of name for you in the register of [faction]. What name do you take? Your old name stays on record, and it can't change again for 7 real days.", "Change of name", M.real_name, "text", null, TRUE)
	if (!raw)
		if (M != src)
			to_chat(src, SPAN_NOTICE("[M.real_name] gives no new name."))
		return
	var/new_name = M.name_change_clean(raw)
	// Everything is checked again after the prompt.
	if (QDELETED(M) || M.stat == DEAD || get_dist(src, M) > 1 || M.civilization != faction || civilization != faction || !map.faction_power(src, faction, "papers"))
		return
	refusal = M.name_change_refusal(new_name)
	if (refusal)
		to_chat(src, SPAN_WARNING(refusal))
		if (M != src)
			to_chat(M, SPAN_WARNING(refusal))
		return
	var/list/paper = bill_blank_supply(src)
	if (!paper.len)
		to_chat(src, SPAN_WARNING("You need a blank sheet of paper in your hands or at your feet."))
		return
	var/old_name = M.real_name
	if (!M.take_new_name(new_name, "recorded by [real_name] for [faction]"))
		return
	var/obj/item/weapon/paper/blank = paper[1]
	drop_from_inventory(blank)
	qdel(blank)
	map.papers_name_change_log(faction, "[old_name] took the name [new_name], recorded by [real_name].")
	var/obj/item/weapon/paper/P = justice_paper(get_turf(M), "record of change of name for [new_name]", name_change_record_text(faction, old_name, new_name, real_name))
	if (P && !M.put_in_hands(P))
		P.forceMove(get_turf(M))
	visible_message(SPAN_NOTICE("[src] records in the register of [faction] that [old_name] is now [new_name]."))
	to_chat(M, SPAN_NOTICE("You are [new_name] now. Your papers of any faction name you so."))

/proc/name_change_record_text(faction, old_name, new_name, clerk)
	return "<center><b>CHANGE OF NAME</b><hr>Register of [html_encode(faction)]</center><br>The member formerly known as [html_encode(old_name)] is from this day known as [html_encode(new_name)].<br><br>Recorded by [html_encode(clerk)], [faction_seal_date(recruitment_now())]."

// A faction's own list of changes of name, read with its census.
/obj/map_metadata/proc/papers_name_change_log(faction, text)
	var/list/R = papers_record(faction)
	if (!islist(R["names"]))
		R["names"] = list()
	var/list/L = R["names"]
	L += copytext("[faction_seal_date(recruitment_now())]: [text]", 1, NAME_HISTORY_LINE_MAX + 1)
	while (L.len > 40)
		L.Cut(1, 2)

/obj/map_metadata/proc/papers_name_change_lines(faction)
	var/list/R = papers_record(faction)
	var/list/L = R["names"]
	var/list/out = list()
	if (islist(L))
		for (var/line in L)
			if (istext(line))
				out += line
	return out

// Travel (region_travel.dm): former names and the wait go with the body.
/proc/name_history_valid(list/L)
	if (!islist(L) || L.len > NAME_HISTORY_MAX)
		return FALSE
	for (var/entry in L)
		if (!istext(entry) || !length(entry) || length(entry) > NAME_HISTORY_LINE_MAX)
			return FALSE
	return TRUE

#undef NAME_HISTORY_LINE_MAX
