// Admin tools for peoples and languages: read a character's people and
// language scores, move them to another people, and set a language score.
// For fixing characters made before peoples existed, events, and bug reports.

// One row per language the character speaks or is learning, best first.
/mob/living/human/proc/language_rows()
	var/list/rows = list()
	var/list/seen = list()
	var/datum/language/own = mother_tongue()
	var/datum/language/speaking = canonical_language(default_language)
	for (var/datum/language/known in languages)
		var/datum/language/L = canonical_language(known)
		if (!language_learnable(L) || (L.name in seen))
			continue
		seen += L.name
	for (var/lname in partial_languages)
		var/datum/language/L = all_languages[lname]
		if (language_learnable(L) && !(L.name in seen) && language_score(L) >= 1)
			seen += L.name
	for (var/lname in seen)
		var/datum/language/L = all_languages[lname]
		var/score = round(language_score(L))
		var/list/row = list("name" = L.name, "score" = score, "level" = language_level_name(score), "key" = L.key)
		row["speakable"] = knows_language(L) ? TRUE : FALSE
		if (L == own)
			row["mother_tongue"] = TRUE
		if (L == speaking)
			row["default"] = TRUE
		var/at = 1
		while (at <= rows.len && rows[at]["score"] >= score)
			at++
		rows.Insert(at, null)
		rows[at] = row
	return rows

/mob/living/human/proc/origin_language_report()
	var/list/lines = list()
	var/summary = origin_summary()
	lines += "<b>[real_name]</b>: [summary ? summary : "no people recorded"]"
	for (var/list/row in language_rows())
		var/list/tags = list()
		if (row["mother_tongue"])
			tags += "mother tongue"
		if (row["default"])
			tags += "speaking it by default"
		if (!row["speakable"])
			tags += "not yet speakable"
		lines += "[row["name"]]: [row["score"]]% ([row["level"]])[tags.len ? ", [jointext(tags, ", ")]" : ""]"
	return lines

// Move a character to another people. With give_tongue they also become a
// native speaker of its language; name, looks and other languages stay.
/mob/living/human/proc/admin_set_origin(datum/origin/O, land = null, give_tongue = TRUE)
	if (!istype(O))
		return FALSE
	var/old_summary = origin_summary()
	if (old_summary)
		remove_note("Origin", old_summary)
	origin_id = O.id
	if (land)
		origin_land = land
	if (give_tongue)
		admin_set_language_score(all_languages[O.language], 100)
	add_note("Origin", origin_summary())
	return TRUE

// Set a language to an exact score. Below Broken the language leaves the
// spoken list; a character always keeps at least one language to speak.
/mob/living/human/proc/admin_set_language_score(datum/language/L, score)
	L = canonical_language(L)
	if (!language_learnable(L) || !isnum(score))
		return FALSE
	score = max(0, min(100, round(score)))
	if (score < LANGUAGE_BROKEN)
		if (knows_language(L))
			var/others = 0
			for (var/datum/language/known in languages)
				if (canonical_language(known) != L && language_learnable(known))
					others++
			if (!others)
				return FALSE
			remove_language(L.name)
			remove_note("Known Languages", L.name)
		partial_languages[L.name] = score * L.difficulty / 100
	else
		partial_languages[L.name] = score * L.difficulty / 100
		if (!knows_language(L) && add_language(L.name, FALSE, score >= LANGUAGE_FLUENT))
			add_note("Known Languages", L.name)
	if (!default_language || !knows_language(default_language))
		var/datum/language/own = mother_tongue()
		if (own && knows_language(own))
			default_language = own
		else
			for (var/datum/language/known in languages)
				if (language_learnable(known))
					default_language = canonical_language(known)
					break
	return TRUE

/client/proc/cmd_admin_check_languages(mob/living/human/H as mob in human_mob_list)
	set category = "Admin"
	set name = "Check Origin and Languages"
	set desc = "Show a character's people, birthplace and language scores."
	if (!check_rights(R_ADMIN))
		return
	if (!istype(H) || QDELETED(H))
		return
	to_chat(usr, jointext(H.origin_language_report(), "<br>"))

/client/proc/cmd_admin_check_language_drift()
	set category = "Admin"
	set name = "Check Language Drift"
	set desc = "Show how far each nation's native speakers have drifted from other speakers of their language."
	if (!check_rights(R_ADMIN))
		return
	to_chat(usr, jointext(language_drift_report(), "<br>"))

/client/proc/cmd_admin_set_origin(mob/living/human/H as mob in human_mob_list)
	set category = "Admin"
	set name = "Set Origin"
	set desc = "Move a character to another people. Name and looks stay as they are."
	if (!check_rights(R_ADMIN))
		return
	if (!istype(H) || QDELETED(H))
		return
	var/list/peoples = list()
	for (var/origin_type in typesof(/datum/origin) - /datum/origin)
		var/datum/origin/candidate = origin_type
		var/datum/origin/O = origin_by_id(initial(candidate.id))
		if (O)
			peoples["[O.name] ([O.language])"] = O
	var/picked = input(usr, "Which people does [H.real_name] belong to?", "Set Origin") as null|anything in peoples
	if (!picked || !istype(H) || QDELETED(H))
		return
	var/datum/origin/O = peoples[picked]
	var/land = input(usr, "Which land were they born on? Leave it as it is to keep the record.", "Set Origin", H.origin_land ? H.origin_land : land_display_name(map)) as text|null
	if (isnull(land) || !istype(H) || QDELETED(H))
		return
	land = sanitize(copytext(land, 1, 41))
	var/give = alert(usr, "Make [H.real_name] a native speaker of [O.language] as well?", "Set Origin", "Yes", "No", "Cancel")
	if (give == "Cancel" || !istype(H) || QDELETED(H))
		return
	if (!H.admin_set_origin(O, land, give == "Yes"))
		return
	log_admin("[key_name(usr)] set the origin of [key_name(H)] to [O.name] of [land][give == "Yes" ? " with the language" : ""].")
	message_admins("[key_name_admin(usr)] set the origin of [key_name_admin(H)] to [O.name].")
	to_chat(usr, jointext(H.origin_language_report(), "<br>"))

/client/proc/cmd_admin_set_language_score(mob/living/human/H as mob in human_mob_list)
	set category = "Admin"
	set name = "Set Language Score"
	set desc = "Set how well a character knows a language, from 0 to 100."
	if (!check_rights(R_ADMIN))
		return
	if (!istype(H) || QDELETED(H))
		return
	var/list/choices = list()
	for (var/lname in all_languages)
		var/datum/language/L = all_languages[lname]
		if (language_learnable(L))
			choices["[L.name] ([round(H.language_score(L))]%)"] = L
	var/picked = input(usr, "Which language?", "Set Language Score for [H.real_name]") as null|anything in sortList(choices)
	if (!picked || !istype(H) || QDELETED(H))
		return
	var/datum/language/L = choices[picked]
	var/score = input(usr, "Score from 0 to 100. Broken is [LANGUAGE_BROKEN], Conversational [LANGUAGE_CONVERSATIONAL], Fluent [LANGUAGE_FLUENT].", "Set Language Score", round(H.language_score(L))) as num|null
	if (isnull(score) || !istype(H) || QDELETED(H))
		return
	if (!H.admin_set_language_score(L, score))
		to_chat(usr, SPAN_WARNING("That would leave [H.real_name] with no language to speak. Give them another one first."))
		return
	log_admin("[key_name(usr)] set [key_name(H)]'s [L.name] to [round(H.language_score(L))]%.")
	message_admins("[key_name_admin(usr)] set [key_name_admin(H)]'s [L.name] to [round(H.language_score(L))]%.")
	to_chat(usr, jointext(H.origin_language_report(), "<br>"))

// ------------------------------------------------------------
// Language splits (code/game/mob/language/daughter.dm)
// ------------------------------------------------------------

/client/proc/cmd_admin_force_language_split()
	set category = "Admin"
	set name = "Force Language Split"
	set desc = "Make a nation's speech community ready to split now, whatever its drift, and optionally name the new language."
	if (!check_rights(R_ADMIN))
		return
	ensure_daughter_languages()
	var/list/nations = list()
	for (var/mob/living/human/H in living_mob_list)
		if (H.civilization != "none")
			nations |= H.civilization
	var/nation = input(usr, "Which nation?", "Force Language Split") as null|anything in sortList(nations)
	if (!nation)
		return
	var/list/choices = list()
	for (var/lname in all_languages)
		var/datum/language/L = all_languages[lname]
		if (language_learnable(L) && language_community_natives(nation, L))
			choices["[L.name] ([language_community_natives(nation, L)] natives, [round(language_drift(language_community_key(nation, L)))]% drift)"] = L
	var/picked = input(usr, "Which of their languages?", "Force Language Split") as null|anything in sortList(choices)
	if (!picked)
		return
	var/datum/language/L = choices[picked]
	var/datum/language/root = language_root(L)
	if (!root || language_daughter_count(root) >= LANGUAGE_DAUGHTERS_PER_ROOT)
		to_chat(usr, SPAN_WARNING("[root ? root.name : L.name] already has [LANGUAGE_DAUGHTERS_PER_ROOT] daughter languages on this world."))
		return
	var/key = language_community_key(nation, L)
	var/list/pending = language_lineage_part("pending")
	pending[key] = language_real_minute()
	var/wanted = input(usr, "Name it now? Leave empty to let the nation's leader name it.", "Force Language Split") as text|null
	if (wanted && length(trim(wanted)))
		var/problem = language_name_problem(wanted)
		if (problem)
			to_chat(usr, SPAN_WARNING("[problem] It is ready to split; the leader can name it."))
		else
			var/datum/language/D = split_language(key, language_clean_name(wanted))
			if (D)
				log_admin("[key_name(usr)] split [nation]'s [L.name] into [D.name].")
				message_admins("[key_name_admin(usr)] split [nation]'s [L.name] into [D.name].")
				return
	log_admin("[key_name(usr)] made [nation]'s [L.name] ready to split.")
	message_admins("[key_name_admin(usr)] made [nation]'s [L.name] ready to split.")
	language_split_ready_notice(nation, L)

/proc/admin_daughter_language_choices()
	ensure_daughter_languages()
	var/list/choices = list()
	var/list/records = language_lineage_part("daughters")
	for (var/name in records)
		var/list/record = records[name]
		if (is_daughter_language(all_languages[name]) && islist(record))
			choices["[name] (from [record["parent"]], [record["nation"]][record["imported"] ? ", arrived with travellers" : ""])"] = name
	return choices

/client/proc/cmd_admin_merge_language()
	set category = "Admin"
	set name = "Merge Language Back"
	set desc = "Undo a language split: everyone who has the daughter language gets it as its parent instead."
	if (!check_rights(R_ADMIN))
		return
	var/list/choices = admin_daughter_language_choices()
	if (!choices.len)
		to_chat(usr, SPAN_WARNING("This world has no daughter languages."))
		return
	var/picked = input(usr, "Which language should be merged back into its parent?", "Merge Language Back") as null|anything in sortList(choices)
	if (!picked)
		return
	var/name = choices[picked]
	var/list/children = daughter_language_children(name)
	if (children.len)
		to_chat(usr, SPAN_WARNING("[name] has daughter languages of its own ([jointext(children, ", ")]). Merge those first."))
		return
	if (alert(usr, "Merge [name] back into its parent? Everyone who has it keeps the better score in the parent. This cannot be undone.", "Merge Language Back", "Merge", "Cancel") != "Merge" || !check_rights(R_ADMIN))
		return
	var/count = merge_daughter_language(name)
	if (isnull(count))
		to_chat(usr, SPAN_WARNING("[name] could not be merged."))
		return
	log_admin("[key_name(usr)] merged the language [name] back into its parent ([count] character\s).")
	message_admins("[key_name_admin(usr)] merged the language [name] back into its parent ([count] character\s).")

/client/proc/cmd_admin_rename_language()
	set category = "Admin"
	set name = "Rename Language"
	set desc = "Rename a daughter language for everyone in this world."
	if (!check_rights(R_ADMIN))
		return
	var/list/choices = admin_daughter_language_choices()
	if (!choices.len)
		to_chat(usr, SPAN_WARNING("This world has no daughter languages."))
		return
	var/picked = input(usr, "Which language should be renamed?", "Rename Language") as null|anything in sortList(choices)
	if (!picked)
		return
	var/old = choices[picked]
	var/wanted = input(usr, "New name for [old] (3 to 24 letters). Travellers already in other lands keep the old name there.", "Rename Language", old) as text|null
	if (!wanted || !check_rights(R_ADMIN))
		return
	var/problem = language_name_problem(wanted)
	if (problem)
		to_chat(usr, SPAN_WARNING(problem))
		return
	var/new_name = language_clean_name(wanted)
	var/count = rename_daughter_language(old, new_name)
	if (isnull(count))
		to_chat(usr, SPAN_WARNING("[old] could not be renamed."))
		return
	log_admin("[key_name(usr)] renamed the language [old] to [new_name] ([count] character\s).")
	message_admins("[key_name_admin(usr)] renamed the language [old] to [new_name] ([count] character\s).")
