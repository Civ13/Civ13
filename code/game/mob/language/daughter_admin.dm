// Undoing and renaming daughter languages (docs/language-drift.md, part 4).
// The admin verbs that call these live in code/modules/admin/verbs/origin_languages.dm.
//
// Merging a daughter back gives every character in the world who has it the
// better of their two scores in its parent, makes the parent their mother
// tongue and default where the daughter was, and forgets the daughter: its
// record, say key, kinship, drift and any wait to split. A daughter that has
// daughters of its own cannot be merged until they are.
//
// Renaming moves everything kept under the old name to the new one: scores,
// mother tongues, today's learning, notes, kinship, drift and the records of
// its own daughters. Travellers already in another land keep the old name there.

// Daughters whose parent is name.
/proc/daughter_language_children(name)
	var/list/children = list()
	var/list/records = language_lineage_part("daughters")
	for (var/other in records)
		var/list/record = records[other]
		if (islist(record) && record["parent"] == name)
			children += other
	return children

// Moves community keys "Nation|old" to "Nation|new_name" (or drops them with no new_name).
/proc/rename_language_community_keys(list/table, old, new_name)
	for (var/key in table.Copy())
		var/list/parts = language_community_parts(key)
		if (!parts || parts[2] != old)
			continue
		var/value = table[key]
		table -= key
		if (new_name)
			table["[parts[1]]|[new_name]"] = value

// Today's learning buckets ("X", "lesson:X", "study:X") under a new name, or dropped.
/mob/living/human/proc/rename_language_buckets(old, new_name)
	if (!islist(language_gain_today))
		return
	for (var/prefix in list("", "lesson:", "study:"))
		var/bucket = "[prefix][old]"
		if (!(bucket in language_gain_today))
			continue
		var/value = language_gain_today[bucket]
		language_gain_today -= bucket
		if (new_name)
			language_gain_today["[prefix][new_name]"] = value

// Returns how many characters had the daughter, or null when it cannot be merged.
/proc/merge_daughter_language(name)
	ensure_daughter_languages()
	var/datum/language/daughter/D = all_languages[name]
	if (!is_daughter_language(D) || daughter_language_children(name).len)
		return null
	var/datum/language/parent = canonical_language(all_languages[D.parent_name])
	if (!parent)
		return null
	. = 0
	for (var/mob/living/human/H in human_mob_list)
		var/had = !isnull(H.partial_languages[name]) || H.knows_language(D) || H.native_tongue == name
		if (!had)
			continue
		.++
		var/daughter_score = H.partial_languages[name] ? min(100, H.partial_languages[name] * 100 / D.difficulty) : (H.knows_language(D) ? 100 : 0)
		var/parent_score = max(H.language_score(parent), daughter_score)
		H.partial_languages[parent.name] = parent_score * parent.difficulty / 100
		if (parent_score >= LANGUAGE_BROKEN && !H.knows_language(parent) && H.add_language(parent.name, FALSE, FALSE))
			H.add_note("Known Languages", parent.name)
		var/was_default = language_same(canonical_language(H.default_language), D)
		for (var/datum/language/known in H.languages.Copy())
			if (language_same(known, D))
				H.languages -= known
		H.partial_languages -= name
		H.remove_note("Known Languages", name)
		H.rename_language_buckets(name, null)
		if (H.native_tongue == name)
			H.native_tongue = is_daughter_language(parent) ? parent.name : null
		if (was_default)
			H.default_language = H.knows_language(parent) ? parent : null
		if (H.client)
			to_chat(H, SPAN_NOTICE("<b>[name]</b> is counted as [parent.name] again. You keep what you knew of it as [parent.name]."))
	for (var/lname in all_languages)
		var/datum/language/L = all_languages[lname]
		if (islist(L.mutual_intelligibility))
			L.mutual_intelligibility -= name
	if (D.key && language_keys[D.key] == D)
		language_keys -= D.key
	all_languages -= name
	var/list/records = language_lineage_part("daughters")
	records -= name
	rename_language_community_keys(language_drift_table(), name, null)
	rename_language_community_keys(language_lineage_part("pending"), name, null)

// Returns how many characters had the daughter, or null when it cannot be renamed.
/proc/rename_daughter_language(old, new_name)
	ensure_daughter_languages()
	var/datum/language/daughter/D = all_languages[old]
	if (!is_daughter_language(D) || language_name_problem(new_name))
		return null
	new_name = language_clean_name(new_name)
	var/list/records = language_lineage_part("daughters")
	var/list/record = records[old]
	if (!islist(record))
		return null
	records -= old
	records[new_name] = record
	for (var/child in daughter_language_children(old))
		var/list/child_record = records[child]
		child_record["parent"] = new_name
		var/datum/language/daughter/C = all_languages[child]
		if (is_daughter_language(C))
			C.parent_name = new_name
	all_languages -= old
	D.name = new_name
	all_languages[new_name] = D
	for (var/lname in all_languages)
		var/datum/language/L = all_languages[lname]
		if (islist(L.mutual_intelligibility) && (old in L.mutual_intelligibility))
			L.mutual_intelligibility[new_name] = L.mutual_intelligibility[old]
			L.mutual_intelligibility -= old
	rename_language_community_keys(language_drift_table(), old, new_name)
	rename_language_community_keys(language_lineage_part("pending"), old, new_name)
	. = 0
	for (var/mob/living/human/H in human_mob_list)
		var/had = !isnull(H.partial_languages[old]) || H.knows_language(D) || H.native_tongue == old
		if (!had)
			continue
		.++
		if (!isnull(H.partial_languages[old]))
			H.partial_languages[new_name] = H.partial_languages[old]
			H.partial_languages -= old
		if (H.native_tongue == old)
			H.native_tongue = new_name
		H.rename_language_buckets(old, new_name)
		if (H.knows_language(D))
			H.remove_note("Known Languages", old)
			H.add_note("Known Languages", new_name)
		if (H.client)
			to_chat(H, SPAN_NOTICE("<b>[old]</b> is now called <b>[new_name]</b>."))
