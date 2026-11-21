// Daughter languages (docs/language-drift.md, part 2).
//
// When the world enters a new era, every speech community whose drift has
// reached LANGUAGE_SPLIT_DRIFT and that has LANGUAGE_SPLIT_MIN_NATIVES living
// native speakers becomes ready to split. The nation's leader, with a
// Discord-verified account, names the new language (Name Our Language); an
// admin can name it too. Naming is the split: the nation's living natives get
// the daughter at their score in the parent, it becomes their mother tongue
// and the language they speak by default, and they keep the parent.
//
// A daughter is a runtime /datum/language/daughter, registered in
// all_languages under its own name. Every daughter shares that one type, so a
// daughter is told apart by name wherever languages are otherwise compared by
// type (language_same, language_kin_key). It writes in its root language's
// script: a Conversational speaker reads and writes papers in the root.
//
// Records live in map.language_lineage_state (field version 6):
//   "daughters" = list(name = list("parent", "root", "nation", "era", "kin", "key", "syllables"[, "imported"]))
// An imported daughter arrived with a traveller from another land
// (region_travel_tongues.dm) and does not count towards this world's cap.
//   "pending"   = list("Nation|Language" = era it became ready)
// "kin" is how much of the parent a daughter speaker follows, and the parent
// speaker the daughter: LANGUAGE_DAUGHTER_KIN at the split, then lower by
// LANGUAGE_DAUGHTER_KIN_STEP at each era change the daughter has drifted far
// again, to LANGUAGE_DAUGHTER_KIN_MIN. A root language has at most
// LANGUAGE_DAUGHTERS_PER_ROOT daughters on a world.

/datum/language/daughter
	name = "a daughter language"
	desc = "A language that grew apart from its parent."
	flags = RESTRICTED | COMMON_VERBS | NONGLOBAL
	var/parent_name
	var/root_name
	var/nation
	var/born_era = 0

/mob/living/human/var/native_tongue = null

// The record table, repaired in place if a restore left it malformed.
/proc/language_lineage_part(part)
	language_drift_table()
	var/list/state = map ? map.language_lineage_state : null
	if (!islist(state))
		return list()
	var/list/L = state[part]
	if (!islist(L))
		L = list()
		state[part] = L
	return L

/proc/is_daughter_language(datum/language/L)
	return istype(L, /datum/language/daughter)

// Kinship tables are keyed by type for the built-in languages and by name for
// daughters, which all share one type.
/proc/language_kin_key(datum/language/L)
	if (!istype(L))
		return null
	return is_daughter_language(L) ? L.name : L.type

/proc/language_same(datum/language/A, datum/language/B)
	if (!istype(A) || !istype(B))
		return FALSE
	if (A == B)
		return TRUE
	if (is_daughter_language(A) || is_daughter_language(B))
		return is_daughter_language(A) && is_daughter_language(B) && A.name == B.name
	return A.type == B.type

/proc/language_kinship(datum/language/listener_lang, datum/language/heard_lang)
	if (!istype(listener_lang) || !istype(heard_lang) || !islist(listener_lang.mutual_intelligibility))
		return 0
	var/value = listener_lang.mutual_intelligibility[language_kin_key(heard_lang)]
	return isnum(value) ? value : 0

/proc/set_language_kinship(datum/language/A, datum/language/B, value)
	if (!istype(A) || !istype(B) || language_same(A, B))
		return
	A.mutual_intelligibility[language_kin_key(B)] = value
	B.mutual_intelligibility[language_kin_key(A)] = value

// The built-in language a daughter descends from, or L itself.
/proc/language_root(datum/language/L)
	L = canonical_language(L)
	if (is_daughter_language(L))
		var/datum/language/daughter/D = L
		var/datum/language/R = all_languages[D.root_name]
		return istype(R) && !is_daughter_language(R) ? R : null
	return L

// ------------------------------------------------------------
// Making and restoring daughters
// ------------------------------------------------------------

// Sound changes: each daughter picks some of these by a seed taken from its
// name, so the same name always sounds the same and two daughters differ.
var/global/list/language_sound_changes = list(
	list("c", "ch"), list("ct", "tt"), list("p", "b"), list("t", "d"),
	list("u", "o"), list("a", "e"), list("e", "ie"), list("o", "ue"),
	list("s", "h"), list("f", "h"), list("l", "ll"), list("n", "gn"),
	list("ae", "e"), list("um", "on"), list("us", "o"), list("x", "s"),
	list("k", "q"), list("i", "y"), list("r", "rr"), list("g", "j"))

/proc/language_name_seed(text)
	. = 7
	for (var/i in 1 to length(text))
		. = (. * 31 + text2ascii(text, i)) % 65521

/proc/language_sound_changed(list/syllables, seed)
	var/list/changes = list()
	var/count = 3 + seed % 3
	var/at = seed % language_sound_changes.len
	while (changes.len < count)
		var/list/change = language_sound_changes[at + 1]
		changes += list(change)
		at = (at + 7 + seed % 5) % language_sound_changes.len
	var/list/result = list()
	for (var/syllable in syllables)
		var/changed = syllable
		for (var/list/change in changes)
			changed = replacetext(changed, change[1], change[2])
		result += changed
	return result

// A free two-letter say key for a daughter: its name's first letters if free.
/proc/language_free_key(name)
	var/clean = lowertext(replacetext(name, " ", ""))
	var/list/tries = list()
	if (length(clean) >= 2)
		tries += copytext(clean, 1, 3)
		for (var/i in 3 to length(clean))
			tries += "[copytext(clean, 1, 2)][copytext(clean, i, i + 1)]"
	var/list/letters = splittext("abcdefghijklmnopqrstuvwxyz", "")
	for (var/a in letters)
		for (var/b in letters)
			tries += "[a][b]"
	for (var/key in tries)
		if (!language_keys[key] && length(key) == 2)
			return key
	return null

// Registers a daughter from its record, or returns the one already there.
/proc/register_daughter_language(name, list/record)
	if (!istext(name) || !islist(record))
		return null
	var/datum/language/existing = all_languages[name]
	if (existing)
		return is_daughter_language(existing) ? existing : null
	var/datum/language/parent = all_languages[record["parent"]]
	var/datum/language/root = all_languages[record["root"]]
	if (!istype(parent) || !istype(root) || is_daughter_language(root) || !language_learnable(parent))
		return null
	var/datum/language/daughter/D = new
	D.name = name
	D.desc = "Grew apart from [parent.name] among the [record["nation"]] in the [ordinal_age_name(record["era"])]."
	D.parent_name = parent.name
	D.root_name = root.name
	D.nation = record["nation"]
	D.born_era = isnum(record["era"]) ? record["era"] : 0
	D.difficulty = parent.difficulty
	D.speech_verb = parent.speech_verb
	D.ask_verb = parent.ask_verb
	D.exclaim_verb = parent.exclaim_verb
	D.whisper_verb = parent.whisper_verb
	D.colour = parent.colour
	D.flags = parent.flags & ~NONGLOBAL
	D.native = parent.native
	D.syllables = islist(record["syllables"]) && length(record["syllables"]) ? record["syllables"] : parent.syllables
	D.key = istext(record["key"]) && !language_keys[record["key"]] ? record["key"] : language_free_key(name)
	D.mutual_intelligibility = list()
	all_languages[name] = D
	if (D.key)
		language_keys[D.key] = D
	var/kin = isnum(record["kin"]) ? record["kin"] : LANGUAGE_DAUGHTER_KIN
	set_language_kinship(D, parent, kin)
	// The parent's relatives follow the daughter a little less than the parent.
	for (var/kin_key in parent.mutual_intelligibility)
		var/datum/language/relative = language_by_kin_key(kin_key)
		if (relative && !language_same(relative, D))
			var/value = round(parent.mutual_intelligibility[kin_key] * kin / 100)
			if (value > language_kinship(D, relative))
				set_language_kinship(D, relative, value)
	return D

/proc/language_by_kin_key(kin_key)
	if (istext(kin_key))
		var/datum/language/L = all_languages[kin_key]
		return is_daughter_language(L) ? L : null
	for (var/lname in all_languages)
		var/datum/language/L = all_languages[lname]
		if (L.type == kin_key && !is_daughter_language(L))
			return L
	return null

// Registers every saved daughter, parents before children. Safe to repeat.
/proc/ensure_daughter_languages()
	var/list/records = language_lineage_part("daughters")
	var/progress = TRUE
	while (progress)
		progress = FALSE
		for (var/name in records)
			if (!all_languages[name] && register_daughter_language(name, records[name]))
				progress = TRUE

// ------------------------------------------------------------
// The era check and the split
// ------------------------------------------------------------

/proc/language_daughter_count(datum/language/root)
	. = 0
	var/list/records = language_lineage_part("daughters")
	for (var/name in records)
		var/list/record = records[name]
		if (islist(record) && record["root"] == root.name && !record["imported"])
			.++

// Called when the world enters a new era. Returns how many communities became
// ready to split.
/proc/language_era_advanced()
	if (!map)
		return 0
	ensure_daughter_languages()
	var/list/drift = language_drift_table()
	var/list/pending = language_lineage_part("pending")
	var/list/records = language_lineage_part("daughters")
	. = 0
	for (var/key in drift.Copy())
		var/list/parts = language_community_parts(key)
		if (!parts || drift[key] < LANGUAGE_SPLIT_DRIFT)
			continue
		var/datum/language/L = all_languages[parts[2]]
		if (!L)
			continue
		// A daughter that has drifted far again grows further from its parent.
		if (is_daughter_language(L) && islist(records[L.name]))
			var/list/record = records[L.name]
			var/datum/language/daughter/D = L
			var/kin = max(LANGUAGE_DAUGHTER_KIN_MIN, (isnum(record["kin"]) ? record["kin"] : LANGUAGE_DAUGHTER_KIN) - LANGUAGE_DAUGHTER_KIN_STEP)
			record["kin"] = kin
			set_language_kinship(D, all_languages[D.parent_name], kin)
			set_language_drift(key, drift[key] / 2)
			continue
		if ((key in pending) || language_community_natives(parts[1], L) < LANGUAGE_SPLIT_MIN_NATIVES)
			continue
		var/datum/language/root = language_root(L)
		if (!root || language_daughter_count(root) >= LANGUAGE_DAUGHTERS_PER_ROOT)
			continue
		pending[key] = map.ordinal_age
		.++
		language_split_ready_notice(parts[1], L)

/proc/language_split_ready_notice(nation, datum/language/L)
	for (var/mob/living/human/H in living_mob_list)
		if (H.civilization != nation)
			continue
		if (H.mother_tongue() == L)
			to_chat(H, SPAN_NOTICE("Your people have spoken among themselves so long that their [L.name] no longer sounds like anyone else's. It is becoming a language of its own."))
		if (map.is_faction_leader(H, nation))
			H.offer_language_naming()

// The leader's verb, offered while their nation has a split to name.
/mob/living/human/proc/offer_language_naming()
	if (!(/mob/living/human/proc/name_our_language in verbs))
		verbs += /mob/living/human/proc/name_our_language
	to_chat(src, SPAN_NOTICE("As leader of the [civilization], you can name your people's new language with <b>Name Our Language</b> in the IC tab. Naming it needs a Discord-verified account."))

/proc/language_pending_for(nation)
	var/list/pending = language_lineage_part("pending")
	var/list/keys = list()
	for (var/key in pending)
		var/list/parts = language_community_parts(key)
		if (parts && parts[1] == nation)
			keys += key
	return keys

// Called at login (knowledge_spread.dm's Login).
/mob/living/human/proc/offer_pending_language_naming()
	if (map && civilization != "none" && map.is_faction_leader(src, civilization) && language_pending_for(civilization).len)
		offer_language_naming()

/mob/living/human/proc/name_our_language()
	set category = "IC"
	set name = "Name Our Language"
	set desc = "Name the language your people's speech has become."
	var/list/keys = language_pending_for(civilization)
	if (!keys.len || !map.is_faction_leader(src, civilization))
		verbs -= /mob/living/human/proc/name_our_language
		to_chat(src, SPAN_WARNING("Your nation has no new language to name."))
		return
	if (!account_verified(nation_account()))
		to_chat(src, SPAN_WARNING("Naming a language needs a Discord-verified account. Use Verify Discord first."))
		return
	var/key = keys[1]
	if (keys.len > 1)
		var/list/choices = list()
		for (var/k in keys)
			choices["[language_community_parts(k)[2]]"] = k
		var/picked = input(src, "Which language has your people's speech grown out of?", "Name Our Language") as null|anything in choices
		if (!picked)
			return
		key = choices[picked]
	var/list/parts = language_community_parts(key)
	var/wanted = input(src, "Your people's [parts[2]] has become a language of its own. What is it called? (3 to 24 letters)", "Name Our Language") as text|null
	if (isnull(wanted))
		return
	var/problem = language_name_problem(wanted)
	if (problem)
		to_chat(src, SPAN_WARNING(problem))
		return
	if (!(key in language_lineage_part("pending")) || !map.is_faction_leader(src, civilization))
		return
	var/datum/language/D = split_language(key, language_clean_name(wanted))
	if (!D)
		to_chat(src, SPAN_WARNING("The language could not be named. Ask an admin."))
		return
	log_game("[key_name(src)] named [parts[1]]'s daughter of [parts[2]]: [D.name].")
	if (!language_pending_for(civilization).len)
		verbs -= /mob/living/human/proc/name_our_language

/proc/language_clean_name(text)
	text = trim(sanitize(copytext(text, 1, 40)))
	return capitalize(text)

// Why a name will not do, or null.
/proc/language_name_problem(text)
	if (!istext(text))
		return "That is not a name."
	text = language_clean_name(text)
	if (length(text) < 3 || length(text) > 24)
		return "A language name is 3 to 24 letters long."
	if (!findtext(text, regex("^\[A-Za-z\]\[A-Za-z' -\]*$")))
		return "Use only letters, spaces, hyphens and apostrophes."
	for (var/lname in all_languages)
		if (lowertext(lname) == lowertext(text))
			return "There is already a language called [lname]."
	return null

// The split itself. Returns the new language, or null.
/proc/split_language(key, name)
	var/list/pending = language_lineage_part("pending")
	var/list/parts = language_community_parts(key)
	if (!parts || !(key in pending) || language_name_problem(name))
		return null
	var/datum/language/parent = all_languages[parts[2]]
	var/datum/language/root = language_root(parent)
	if (!parent || !root || language_daughter_count(root) >= LANGUAGE_DAUGHTERS_PER_ROOT)
		pending -= key
		return null
	var/list/record = list("parent" = parent.name, "root" = root.name, "nation" = parts[1], "era" = map.ordinal_age, "kin" = LANGUAGE_DAUGHTER_KIN)
	record["syllables"] = language_sound_changed(parent.syllables ? parent.syllables : list(), language_name_seed(name))
	var/list/records = language_lineage_part("daughters")
	records[name] = record
	var/datum/language/daughter/D = register_daughter_language(name, record)
	if (!D)
		records -= name
		return null
	record["key"] = D.key
	// Earlier daughters of the same root are sisters: closer than strangers.
	for (var/other in records)
		var/datum/language/sister = all_languages[other]
		if (sister != D && is_daughter_language(sister) && language_root(sister) == root)
			set_language_kinship(D, sister, max(language_kinship(D, sister), LANGUAGE_DAUGHTER_KIN - LANGUAGE_DAUGHTER_KIN_STEP * 2))
	pending -= key
	set_language_drift(key, 0)
	for (var/mob/living/human/H in living_mob_list)
		if (H.civilization == parts[1] && H.mother_tongue() == parent)
			H.take_daughter_language(D, parent)
		else if (H.client && H.civilization == parts[1])
			to_chat(H, SPAN_NOTICE("The [parts[1]] now speak <b>[D.name]</b>, grown out of [parent.name]. You can learn it from them."))
	return D

// A native speaker of the parent at the split.
/mob/living/human/proc/take_daughter_language(datum/language/daughter/D, datum/language/parent)
	var/score = language_score(parent)
	native_tongue = D.name
	partial_languages[D.name] = score * D.difficulty / 100
	if (score >= LANGUAGE_BROKEN && add_language(D.name, FALSE, FALSE))
		add_note("Known Languages", D.name)
	if (language_same(canonical_language(default_language), parent) && knows_language(D))
		default_language = D
	to_chat(src, SPAN_NOTICE("Your people's speech has become <b>[D.name]</b>. It is your mother tongue now; you still understand [parent.name][D.key ? ", and you speak [D.name] with :[D.key]" : ""]."))

// ------------------------------------------------------------
// Admin tools
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
	pending[key] = map.ordinal_age
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
