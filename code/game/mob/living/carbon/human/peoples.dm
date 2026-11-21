// Peoples as world records (docs/peoples.md).
//
// The peoples in origins.dm are the roots. Peoples that form in play (a split
// after long isolation, a blend of two peoples living together) are records
// saved with the world, next to the daughter languages, in
//   map.language_lineage_state["peoples"] = list(id = record)
//   record = list("name", "root", "parents", "language", "homeland",
//                 "nation", "year"[, "imported"])
// "root" is the root people (origins.dm) whose name style and dress a world
// people keeps; "parents" are the peoples it formed from. A record becomes a
// runtime /datum/origin, so every reader of a character's people (mother
// tongue, notes, travel, admin) treats roots and world peoples alike.
//
// A people is a story, never a target: no game rule reads a character's
// people (tests/origins), and examine never names it.

#define PEOPLE_NAME_MIN 3
#define PEOPLE_NAME_MAX 24
#define PEOPLE_RECORD_KEYS list("name", "root", "parents", "language", "homeland", "nation", "year", "imported")

/datum/origin
	var/root_id = null			// the root people a world people keeps its name style and dress from
	var/list/parents = null		// ids of the peoples a world people formed from
	var/homeland = null			// where a world people formed
	var/nation = null			// the nation it formed in, if any
	var/formed_year = 0			// world calendar year it formed (world peoples)
	var/world_record = FALSE	// TRUE for a people that formed in play
	var/imported = FALSE		// arrived with a traveller from another land
	// Kept open for peoples of other worlds (for example heteromorphic races on
	// Yggdrasil): a root people there would set its own world and body plan.
	var/world_name = "Earth"
	var/body_plan = "human"

// ------------------------------------------------------------
// Gaia's own peoples
// ------------------------------------------------------------
// Gaia is not Earth, so its roots carry names of the land rather than
// real-world peoples. They keep the languages and name styles of the peoples
// they replace; characters born on Gaia before this keep their place in
// these peoples (gaia_root_renames, settle_people_record).

// (The Gaia roots themselves are in origins.dm with the other roots.)

// Real-world root -> Gaia root, for characters born on a Gaia land.
// No initialised static or global lists in this file: the world's global
// init proc is near the compiler's size limit.
/proc/gaia_root_renames()
	return list(
		"northmen" = "fjordfolk",
		"latins" = "hearthlanders",
		"hellenes" = "isleborn",
		"egyptians" = "dunefolk",
		"swahili" = "grasslanders",
		"yamato" = "mistwood")

// Lands whose peoples are Gaia's own (land_display_name of their maps).
/proc/gaia_land_names()
	return list("Gaia", "Continents", "Pangea")

// ------------------------------------------------------------
// The calendar year
// ------------------------------------------------------------

// Whole world-calendar years since the calendar's start: a year is four
// seasons of config.season_duration_minutes (4 real hours by default). Every
// region reads the same real clock, so every land agrees on the year.
/proc/world_calendar_year()
	var/list/now = world_calendar_now()
	var/year_minutes = world_calendar_season_minutes() * 4
	return round(now[1] * (1440 / year_minutes) + (now[2] / 600) / year_minutes)

// ------------------------------------------------------------
// Records
// ------------------------------------------------------------

/proc/people_records()
	return language_lineage_part("peoples")

var/global/list/world_peoples_cache = null

// The /datum/origin for a world people, built from its record and cached
// while the record is unchanged. Null if there is no valid record.
/proc/world_people(id)
	if (!istext(id))
		return null
	var/list/records = people_records()
	var/list/record = records[id]
	if (!world_peoples_cache)
		world_peoples_cache = list()
	if (!people_record_valid(id, record))
		world_peoples_cache -= id
		return null
	var/datum/origin/O = world_peoples_cache[id]
	if (istype(O) && O.name == record["name"] && O.language == record["language"])
		return O
	var/datum/origin/root = origins_by_id[record["root"]]
	O = new /datum/origin
	O.id = id
	O.name = record["name"]
	O.language = record["language"]
	O.name_style = root.name_style
	O.root_id = root.id
	O.parents = islist(record["parents"]) ? record["parents"] : list()
	O.homeland = record["homeland"]
	O.nation = record["nation"]
	O.formed_year = isnum(record["year"]) ? record["year"] : 0
	O.world_record = TRUE
	O.imported = record["imported"] ? TRUE : FALSE
	O.world_name = root.world_name
	O.body_plan = root.body_plan
	world_peoples_cache[id] = O
	return O

/proc/people_record_valid(id, list/record)
	if (!istext(id) || !length(id) || length(id) > 40 || !islist(record))
		return FALSE
	for (var/key in record)
		if (!(key in PEOPLE_RECORD_KEYS))
			return FALSE
	if (!istext(record["name"]) || length(record["name"]) < PEOPLE_NAME_MIN || length(record["name"]) > PEOPLE_NAME_MAX)
		return FALSE
	origin_by_id(null) // builds the root table
	var/datum/origin/root = origins_by_id[record["root"]]
	if (!istype(root))
		return FALSE
	if (!istext(record["language"]) || !all_languages[record["language"]])
		return FALSE
	var/list/parents = record["parents"]
	if (!isnull(parents))
		if (!islist(parents) || parents.len > 8)
			return FALSE
		for (var/parent in parents)
			if (!istext(parent) || parent == id)
				return FALSE
	for (var/key in list("homeland", "nation"))
		if (!isnull(record[key]) && (!istext(record[key]) || length(record[key]) > 40))
			return FALSE
	if (!isnull(record["year"]) && !isnum(record["year"]))
		return FALSE
	return TRUE

// The root people a people keeps its name style and dress from.
/proc/origin_root(datum/origin/O)
	if (!istype(O))
		return null
	if (O.root_id)
		var/datum/origin/root = origins_by_id[O.root_id]
		if (root)
			return root
	return O

// Every people a character can belong to here: roots and world records, by
// display name.
/proc/all_people_choices()
	var/list/choices = list()
	origin_by_id(null)
	for (var/id in origins_by_id)
		var/datum/origin/O = origins_by_id[id]
		choices["[O.name] ([O.language])"] = O
	for (var/id in people_records())
		var/datum/origin/O = world_people(id)
		if (O)
			choices["[O.name] ([O.language], formed)"] = O
	return choices

// The id a new world people gets: "p_" and its name, made unique.
/proc/people_free_id(name)
	var/base = "p_[ckey(name)]"
	var/list/records = people_records()
	var/id = base
	var/n = 2
	while ((id in records) || origins_by_id[id])
		id = "[base][n++]"
	return id

// Records a new people and returns it, or null. parents are origin ids.
/proc/found_people(name, list/parents, language_name, homeland = null, nation = null, imported = FALSE)
	origin_by_id(null)
	var/list/parent_origins = list()
	for (var/pid in parents)
		var/datum/origin/P = origin_by_id(pid)
		if (P)
			parent_origins += P
	if (!parent_origins.len)
		return null
	var/datum/origin/first = parent_origins[1]
	var/datum/origin/root = origin_root(first)
	if (!istext(language_name) || !all_languages[language_name])
		language_name = first.language
	var/list/parent_ids = list()
	for (var/datum/origin/P in parent_origins)
		parent_ids += P.id
	var/list/record = list("name" = name, "root" = root.id, "parents" = parent_ids, "language" = language_name, "year" = world_calendar_year())
	if (istext(homeland) && length(homeland))
		record["homeland"] = copytext(homeland, 1, 41)
	if (istext(nation) && length(nation) && nation != "none")
		record["nation"] = copytext(nation, 1, 41)
	if (imported)
		record["imported"] = TRUE
	var/id = people_free_id(name)
	if (!people_record_valid(id, record))
		return null
	var/list/records = people_records()
	records[id] = record
	return world_people(id)

// Living characters who belong to a people.
/proc/people_members(id)
	. = 0
	for (var/mob/living/human/H in human_mob_list)
		if (H.stat != DEAD && H.origin_id == id)
			.++

// ------------------------------------------------------------
// Names
// ------------------------------------------------------------
// A new people's name (and a new language's) is checked against
// config/people_names_blocked.txt: one word a line, lower case. A plain word
// blocks a name that has it as a whole word (real-world peoples, nations,
// races); a word starting with * blocks a name that contains it anywhere
// (slurs). Lines starting with # are comments. The names of every root people
// and language are always blocked as whole words too.

var/global/list/people_blocked_words = null
var/global/list/people_blocked_parts = null

/proc/load_people_blocklist()
	people_blocked_words = list()
	people_blocked_parts = list()
	if (fexists("config/people_names_blocked.txt"))
		for (var/line in splittext(file2text("config/people_names_blocked.txt"), "\n"))
			line = lowertext(trim(line))
			if (!length(line) || copytext(line, 1, 2) == "#")
				continue
			if (copytext(line, 1, 2) == "*")
				line = copytext(line, 2)
				if (length(line) >= 3)
					people_blocked_parts += line
			else
				people_blocked_words[line] = TRUE
	origin_by_id(null)
	for (var/id in origins_by_id)
		var/datum/origin/O = origins_by_id[id]
		for (var/word in splittext(lowertext("[O.name] [O.language]"), " "))
			if (length(word) >= 3 && word != "folk" && word != "old")
				people_blocked_words[word] = TRUE

// TRUE when a name has a blocked word in it.
/proc/name_blocked(text)
	if (!istext(text))
		return TRUE
	if (isnull(people_blocked_words))
		load_people_blocklist()
	var/lower = lowertext(text)
	var/squashed = replacetext(replacetext(replacetext(lower, " ", ""), "-", ""), "'", "")
	for (var/part in people_blocked_parts)
		if (findtext(squashed, part))
			return TRUE
	for (var/word in splittext(replacetext(lower, "-", " "), " "))
		word = replacetext(word, "'", "")
		if (people_blocked_words[word])
			return TRUE
		// "Gaulish" and "Gauls" for a blocked "gaul"
		for (var/ending in list("s", "es", "ish", "ian", "ians", "ic", "an", "ans", "ese", "i"))
			var/end_at = length(word) - length(ending)
			if (end_at >= 3 && copytext(word, end_at + 1) == ending && people_blocked_words[copytext(word, 1, end_at + 1)])
				return TRUE
	return FALSE

/proc/people_clean_name(text)
	text = trim(sanitize(copytext(text, 1, 40)))
	return capitalize(text)

// Why a people's name will not do, or null.
/proc/people_name_problem(text)
	if (!istext(text))
		return "That is not a name."
	text = people_clean_name(text)
	if (length(text) < PEOPLE_NAME_MIN || length(text) > PEOPLE_NAME_MAX)
		return "A people's name is [PEOPLE_NAME_MIN] to [PEOPLE_NAME_MAX] letters long."
	if (!findtext(text, regex("^\[A-Za-z\]\[A-Za-z' -\]*$")))
		return "Use only letters, spaces, hyphens and apostrophes."
	if (name_blocked(text))
		return "That name is taken from a real-world people, nation or slur. Choose a name of this world."
	origin_by_id(null)
	for (var/id in origins_by_id)
		var/datum/origin/O = origins_by_id[id]
		if (lowertext(O.name) == lowertext(text))
			return "There is already a people called [O.name]."
	var/list/records = people_records()
	for (var/id in records)
		var/list/record = records[id]
		if (islist(record) && istext(record["name"]) && lowertext(record["name"]) == lowertext(text))
			return "There is already a people called [record["name"]]."
	return null

// ------------------------------------------------------------
// Characters
// ------------------------------------------------------------

// At login: a Gaia-born character of a real-world root takes Gaia's own
// people, and a character whose world people was merged back follows it.
/mob/living/human/proc/settle_people_record()
	if (!istext(origin_id))
		return FALSE
	var/old_summary = origin_summary()
	var/new_id = origin_id
	var/list/renames = gaia_root_renames()
	if ((new_id in renames) && (origin_land in gaia_land_names()))
		new_id = renames[new_id]
	if (!origin_by_id(new_id))
		var/list/merged = language_lineage_part("peoples_merged")
		var/guard = 0
		while (istext(merged[new_id]) && guard++ < 16)
			new_id = merged[new_id]
	if (new_id == origin_id || !origin_by_id(new_id))
		return FALSE
	origin_id = new_id
	if (old_summary)
		remove_note("Origin", old_summary)
	add_note("Origin", origin_summary())
	return TRUE

#undef PEOPLE_NAME_MIN
#undef PEOPLE_NAME_MAX
#undef PEOPLE_RECORD_KEYS
