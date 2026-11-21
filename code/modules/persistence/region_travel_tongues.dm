// A traveller's people and languages (origins.dm, proficiency.dm) cross
// between lands with them: every language score, the language they speak by
// default, their people and birthplace, and what they have already gained
// today, so a crossing neither wipes a language nor resets a day's learning.
//
// The record rides in the travel payload as "tongues":
// {"known": {"Latin": 100, "Old Norse": 41.5}, "default": "Latin",
//  "origin": "latins", "land": "North America", "day": 20772, "today": {...},
//  "native": "Vulgar", "daughters": {"Vulgar": {daughter record}}}
// A daughter language (daughter.dm) travels with its record, so a land that
// has never heard it learns it on arrival.

#define REGION_TRAVEL_LAND_NAME_MAX 40

/mob/living/human/proc/region_travel_tongues()
	var/list/known = list()
	for(var/datum/language/held in languages)
		var/datum/language/L = canonical_language(held)
		// Anything spoken arrives spoken, even a score a hair under Broken.
		if(language_learnable(L))
			known[L.name] = max(LANGUAGE_BROKEN, round(language_score(L), 0.01))
	for(var/lname in partial_languages)
		var/datum/language/L = all_languages[lname]
		if(!language_learnable(L) || (L.name in known)) continue
		var/score = round(language_score(L), 0.01)
		if(score > 0)
			known[L.name] = score
	if(!known.len) return null
	var/list/T = list("known" = known)
	var/list/daughters = region_travel_daughter_records(known)
	if(daughters.len) T["daughters"] = daughters
	if(istext(native_tongue) && (native_tongue in known)) T["native"] = native_tongue
	var/datum/language/speaking = canonical_language(default_language)
	if(speaking && (speaking.name in known) && knows_language(speaking))
		T["default"] = speaking.name
	if(origin_id && origin_by_id(origin_id))
		T["origin"] = origin_id
		if(istext(origin_land) && length(origin_land))
			T["land"] = copytext(origin_land, 1, REGION_TRAVEL_LAND_NAME_MAX + 1)
	if(isnum(language_gain_day) && language_gain_day > 0 && islist(language_gain_today))
		var/list/today = list()
		for(var/bucket in language_gain_today)
			if(region_travel_gain_bucket_valid(bucket, known) && isnum(language_gain_today[bucket]) && language_gain_today[bucket] > 0)
				today[bucket] = min(100, round(language_gain_today[bucket], 0.01))
		if(today.len)
			T["day"] = language_gain_day
			T["today"] = today
	return T

// The records of every daughter in known, with their daughter ancestors.
/proc/region_travel_daughter_records(list/known)
	var/list/records = language_lineage_part("daughters")
	var/list/result = list()
	var/list/todo = list()
	for(var/lname in known)
		todo += lname
	while(todo.len)
		var/lname = todo[todo.len]
		todo.len--
		if((lname in result) || !is_daughter_language(all_languages[lname]) || !islist(records[lname])) continue
		var/list/record = records[lname]
		result[lname] = record.Copy()
		if(is_daughter_language(all_languages[record["parent"]])) todo += record["parent"]
	return result

/proc/region_travel_daughter_record_valid(lname, list/record, list/daughters)
	if(!istext(lname) || length(lname) > 24 || !islist(record)) return FALSE
	for(var/key in record)
		if(!(key in list("parent", "root", "nation", "era", "kin", "key", "syllables", "imported"))) return FALSE
	if(!istext(record["parent"]) || !istext(record["root"]) || !istext(record["nation"]) || !isnum(record["era"]) || !isnum(record["kin"])) return FALSE
	var/datum/language/root = all_languages[record["root"]]
	if(!language_learnable(root) || is_daughter_language(root)) return FALSE
	if(record["parent"] != record["root"] && !(record["parent"] in daughters) && !is_daughter_language(all_languages[record["parent"]])) return FALSE
	var/list/syllables = record["syllables"]
	if(!isnull(syllables))
		if(!islist(syllables) || syllables.len > 400) return FALSE
		for(var/s in syllables)
			if(!istext(s) || length(s) > 24) return FALSE
	var/datum/language/here = all_languages[lname]
	return !here || is_daughter_language(here)

// "Latin", "lesson:Latin" or "study:Latin", for a language in the record.
/proc/region_travel_gain_bucket_valid(bucket, list/known)
	if(!istext(bucket)) return FALSE
	var/lname = bucket
	for(var/prefix in list("lesson:", "study:"))
		if(findtext(bucket, prefix) == 1)
			lname = copytext(bucket, length(prefix) + 1)
	return (lname in known)

// Strict, like the rest of the payload: a record this land cannot read whole
// refuses the trip rather than arriving with a language missing.
/proc/region_travel_tongues_valid(value)
	if(!islist(value)) return FALSE
	for(var/key in value)
		if(!(key in list("known", "default", "origin", "land", "day", "today", "native", "daughters"))) return FALSE
	var/list/daughters = value["daughters"]
	if(!isnull(daughters))
		if(!islist(daughters) || !daughters.len || daughters.len > LANGUAGE_DAUGHTERS_PER_ROOT * 64) return FALSE
		for(var/lname in daughters)
			if(!region_travel_daughter_record_valid(lname, daughters[lname], daughters)) return FALSE
	var/list/known = value["known"]
	if(!islist(known) || !known.len || known.len > length(all_languages) + length(daughters)) return FALSE
	for(var/lname in known)
		if(!istext(lname)) return FALSE
		if(!language_learnable(all_languages[lname]) && !(islist(daughters) && (lname in daughters))) return FALSE
		var/score = known[lname]
		if(!isnum(score) || score <= 0 || score > 100) return FALSE
	if(!isnull(value["default"]))
		var/chosen = value["default"]
		if(!istext(chosen) || !(chosen in known) || known[chosen] < LANGUAGE_BROKEN) return FALSE
	if(!isnull(value["native"]) && (!istext(value["native"]) || !(value["native"] in known))) return FALSE
	if(!isnull(value["origin"]) && (!istext(value["origin"]) || !origin_by_id(value["origin"]))) return FALSE
	if(!isnull(value["land"]))
		if(isnull(value["origin"]) || !istext(value["land"]) || !length(value["land"]) || length(value["land"]) > REGION_TRAVEL_LAND_NAME_MAX) return FALSE
	if(isnull(value["day"]) != isnull(value["today"])) return FALSE
	if(!isnull(value["day"]))
		if(!isnum(value["day"]) || value["day"] <= 0 || value["day"] != round(value["day"])) return FALSE
		var/list/today = value["today"]
		if(!islist(today) || !today.len || today.len > known.len * 3) return FALSE
		for(var/bucket in today)
			if(!region_travel_gain_bucket_valid(bucket, known) || !isnum(today[bucket]) || today[bucket] <= 0 || today[bucket] > 100) return FALSE
	return TRUE

// Gives an arriving body the languages it left with, in place of the ones a
// new body starts with. A record without "tongues" leaves the body alone.
/mob/living/human/proc/region_travel_restore_tongues(list/T)
	if(!islist(T) || !islist(T["known"])) return FALSE
	var/list/known = T["known"]
	region_travel_import_daughters(T["daughters"])
	for(var/datum/language/held in languages.Copy())
		if(language_learnable(held))
			languages -= held
	partial_languages = list()
	default_language = null
	for(var/lname in known)
		var/datum/language/L = all_languages[lname]
		if(!language_learnable(L)) continue
		partial_languages[L.name] = known[lname] * L.difficulty / 100
		if(known[lname] >= LANGUAGE_BROKEN && !(L in languages))
			languages += L
	origin_id = T["origin"]
	origin_land = T["land"]
	native_tongue = istext(T["native"]) && language_learnable(all_languages[T["native"]]) ? T["native"] : null
	var/datum/language/speaking = istext(T["default"]) ? all_languages[T["default"]] : null
	if(speaking && (speaking in languages))
		default_language = speaking
	else
		var/datum/language/own = mother_tongue()
		if(own && (own in languages))
			default_language = own
		else
			for(var/datum/language/held in languages)
				if(language_learnable(held))
					default_language = held
					break
	if(isnum(T["day"]) && islist(T["today"]))
		var/list/today = T["today"]
		language_gain_day = T["day"]
		language_gain_today = today.Copy()
	region_travel_tongue_notes()
	return TRUE

// Daughters this land has not heard of are recorded as imported: they are
// saved with the world but never count towards its own daughters.
/proc/region_travel_import_daughters(list/daughters)
	if(!islist(daughters)) return
	ensure_daughter_languages()
	var/list/records = language_lineage_part("daughters")
	var/progress = TRUE
	while(progress)
		progress = FALSE
		for(var/lname in daughters)
			if(all_languages[lname]) continue
			var/list/record = daughters[lname]
			record = record.Copy()
			record["imported"] = TRUE
			records[lname] = record
			if(register_daughter_language(lname, record))
				progress = TRUE
			else
				records -= lname

// The Known Languages and Origin notes live on the mind, which a body only
// has once its player takes it, so they are written again at the claim.
/mob/living/human/proc/region_travel_tongue_notes()
	if(!mind) return
	var/list/listed = mind.notes["Known Languages"]
	for(var/datum/language/held in languages)
		if(language_learnable(held) && !(islist(listed) && (held.name in listed)))
			add_note("Known Languages", held.name)
	var/summary = origin_summary()
	var/list/origins = mind.notes["Origin"]
	if(summary && !(islist(origins) && (summary in origins)))
		add_note("Origin", summary)

#undef REGION_TRAVEL_LAND_NAME_MAX
