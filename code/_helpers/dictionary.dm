// Speech dictionary: slang rows from config/dictionary.txt, applied to say and
// whisper lines after sanitize(). See docs/dictionary.md for the rules.
//
// Every message gets one pass: leftmost-longest, whole-word, ASCII
// case-insensitive, and a replacement is never rescanned. rust_g's
// Aho-Corasick does the matching when it loads; otherwise one BYOND regex per
// table picks exactly the same matches, so both give the same output.
//
// Aho-Corasick knows nothing about words, so the words go into the text. Each
// run of word characters is wrapped in DICTIONARY_MARK, in the message and in
// every source, so a plain substring match can only land on whole words.

#define DICTIONARY_MARK "\x01"
#define DICTIONARY_TOKEN_START "\x02"
#define DICTIONARY_TOKEN_END "\x03"
// Separators: whitespace, ! " ( ) , . : ; ? [ ] { }, and & # because
// sanitize() turns quotes and apostrophes into entities like &#39;.
#define DICTIONARY_WORD_RUN @{"[^\s!"(),.:;?\[\]{}&#]+"}
#define DICTIONARY_NO_ERA "none"

var/global/datum/speech_dictionary/speech_dictionary
// The table the fallback regex is matching right now, for its callback.
var/global/datum/dictionary_table/dictionary_active_table

// Parses config lines into rows of list(source, replacement, era or null).
// Bad rows are logged with their line number and skipped.
/proc/parse_dictionary_lines(var/list/lines)
	var/list/entries = list()
	var/list/seen = list()
	var/line_number = 0
	for (var/line in lines)
		line_number++
		if (length(line) && text2ascii(line, length(line)) == 13)
			line = copytext(line, 1, -1)
		if (!findtext(line, ",") || copytext(line, 1, 2) == "#")
			continue
		var/list/fields = splittext(line, ",")
		if (fields.len != 2 && fields.len != 3)
			world.log << "Error! config/dictionary.txt line [line_number] has [fields.len] fields (expected 2 or 3); skipped."
			continue
		var/source = fields[1]
		var/replacement = fields[2]
		var/era = null
		if (fields.len == 3)
			var/selector = trim(fields[3])
			if (!(selector in list("0", "1", "2", "3", "4", "5", "6", "7", "8")))
				world.log << "Error! config/dictionary.txt line [line_number] has invalid era selector '[selector]' (expected 0-8); skipped."
				continue
			era = text2num(selector)
		if (!dictionary_valid_text(source))
			world.log << "Error! config/dictionary.txt line [line_number] has an invalid source (expected printable ASCII without outer spaces); skipped."
			continue
		if (!dictionary_valid_text(replacement))
			world.log << "Error! config/dictionary.txt line [line_number] has an invalid replacement (expected printable ASCII without outer spaces); skipped."
			continue
		var/identity = "[lowertext(source)]|[isnull(era) ? DICTIONARY_NO_ERA : era]"
		if (seen[identity])
			world.log << "Error! config/dictionary.txt line [line_number] repeats the source '[source]' from line [seen[identity]]; skipped."
			continue
		seen[identity] = line_number
		entries += list(list(source, replacement, era))
	return entries

/proc/dictionary_valid_text(var/text)
	if (!length(text) || text != trim(text))
		return FALSE
	for (var/position = 1, position <= length(text), position++)
		var/code = text2ascii(text, position)
		if (code < 32 || code > 126)
			return FALSE
	return TRUE

// Escapes a source for the fallback regex; everything in it is literal.
/proc/dictionary_regex_escape(var/text)
	var/list/out = list()
	for (var/position = 1, position <= length(text), position++)
		var/character = copytext(text, position, position + 1)
		if (findtext(@"\^$.|?*+()[]{}/", character))
			out += "\\"
		out += character
	return jointext(out, "")

// Copies the typed casing onto a replacement, the way replacetext() always
// did for these rows: LOL -> HAHAHA, Lol -> Hahaha, anything else as written.
// Like replacetext(), a source written with capitals (SS13) never recases.
/proc/dictionary_match_case(var/typed, var/source, var/replacement)
	if (source != lowertext(source))
		return replacement
	var/first = text2ascii(typed, 1)
	if (first < 65 || first > 90)
		return replacement
	var/second = length(typed) >= 2 ? text2ascii(typed, 2) : 0
	if (second >= 65 && second <= 90)
		return uppertext(replacement)
	return uppertext(copytext(replacement, 1, 2)) + copytext(replacement, 2)

// The rows that apply in one era (or with no map), ready for both engines.
/datum/dictionary_table
	var/key
	var/list/sources = list() // html-encoded sources, as speech arrives
	var/list/patterns = list() // the same, with each word wrapped
	var/list/replacements = list()
	var/list/index_of = list() // lowertext(pattern) -> index
	var/regex/matcher // fallback: all patterns, longest first

/datum/dictionary_table/New(var/key, var/list/rows, var/regex/word_run)
	src.key = key
	for (var/list/row in rows)
		var/source = html_encode(row[1])
		var/pattern = word_run.Replace(source, DICTIONARY_MARK + "$0" + DICTIONARY_MARK)
		sources += source
		patterns += pattern
		replacements += row[2]
		index_of[lowertext(pattern)] = patterns.len
	if (!patterns.len)
		return
	// Longest first, so the first alternative that matches is the longest.
	var/list/order = list()
	for (var/index in 1 to patterns.len)
		var/position = 1
		while (position <= order.len && length(patterns[order[position]]) >= length(patterns[index]))
			position++
		order.Insert(position, index)
	var/list/alternatives = list()
	for (var/index in order)
		alternatives += dictionary_regex_escape(patterns[index])
	matcher = regex(jointext(alternatives, "|"), "gi")

/datum/dictionary_table/proc/token(var/index)
	return DICTIONARY_TOKEN_START + "[index]" + DICTIONARY_TOKEN_END

/datum/speech_dictionary
	var/list/tables = list() // "none" and "0".."8" -> /datum/dictionary_table
	var/regex/word_run
	var/use_rustg = FALSE

/datum/speech_dictionary/New(var/list/rows, var/try_rustg = TRUE)
	word_run = regex(DICTIONARY_WORD_RUN, "g")
	var/list/eras = list(DICTIONARY_NO_ERA)
	for (var/era in 0 to 8)
		eras += "[era]"
	for (var/era in eras)
		var/list/selected = list()
		var/list/era_sources = list()
		for (var/list/row in rows)
			if (!isnull(row[3]) && "[row[3]]" == era)
				selected += list(row)
				era_sources[lowertext(row[1])] = TRUE
		// An era row replaces an unrestricted row with the same source.
		for (var/list/row in rows)
			if (isnull(row[3]) && !era_sources[lowertext(row[1])])
				selected += list(row)
		tables[era] = new /datum/dictionary_table("civ13_dictionary_[era]", selected, word_run)
	if (try_rustg)
		use_rustg = setup_rustg()

// rust_g is optional. If it is missing, or disagrees with the regex on any
// source, the regex keeps the dictionary working and that is logged once.
/datum/speech_dictionary/proc/setup_rustg()
	try
		for (var/era in tables)
			var/datum/dictionary_table/table = tables[era]
			if (!table.patterns.len)
				continue
			var/list/tokens = list()
			for (var/index in 1 to table.patterns.len)
				tokens += table.token(index)
			RUSTG_CALL(RUST_G, "setup_acreplace_with_options")(table.key, json_encode(list("ascii_case_insensitive" = 1, "match_kind" = "LeftmostLongest")), json_encode(table.patterns), json_encode(tokens))
		for (var/era in tables)
			var/datum/dictionary_table/table = tables[era]
			for (var/source in table.sources)
				var/view = word_run.Replace("Say [source], [uppertext(source)]x [source]!", DICTIONARY_MARK + "$0" + DICTIONARY_MARK)
				if (RUSTG_CALL(RUST_G, "acreplace")(table.key, view) != match_regex(table, view))
					world.log << "Dictionary: rust_g disagrees with the regex on '[source]'; using the regex."
					return FALSE
	catch
		world.log << "Dictionary: rust_g is unavailable; using the regex."
		return FALSE
	return TRUE

/datum/speech_dictionary/proc/match_regex(var/datum/dictionary_table/table, var/view)
	if (!table.matcher)
		return view
	dictionary_active_table = table
	. = table.matcher.Replace(view, /proc/dictionary_regex_token)
	dictionary_active_table = null

/proc/dictionary_regex_token(var/match)
	var/datum/dictionary_table/table = dictionary_active_table
	if (!table)
		return match
	var/index = table.index_of[lowertext(match)]
	return index ? table.token(index) : match

/datum/speech_dictionary/proc/apply(var/message, var/era)
	var/datum/dictionary_table/table = tables[isnull(era) ? DICTIONARY_NO_ERA : "[era]"]
	if (!table)
		table = tables[DICTIONARY_NO_ERA]
	if (!message || !table || !table.patterns.len)
		return message
	if (findtext(message, DICTIONARY_MARK) || findtext(message, DICTIONARY_TOKEN_START) || findtext(message, DICTIONARY_TOKEN_END))
		message = replacetext(replacetext(replacetext(message, DICTIONARY_MARK, ""), DICTIONARY_TOKEN_START, ""), DICTIONARY_TOKEN_END, "")
	var/view = word_run.Replace(message, DICTIONARY_MARK + "$0" + DICTIONARY_MARK)
	var/matched = use_rustg ? RUSTG_CALL(RUST_G, "acreplace")(table.key, view) : match_regex(table, view)
	if (!findtext(matched, DICTIONARY_TOKEN_START))
		return message
	// Rebuild: text between tokens is the view; each token stands for its
	// pattern's length of the view, which gives the typed casing.
	var/list/out = list()
	var/view_at = 1
	var/at = 1
	var/start = findtext(matched, DICTIONARY_TOKEN_START)
	while (start)
		var/stop = findtext(matched, DICTIONARY_TOKEN_END, start)
		var/kept = copytext(matched, at, start)
		out += kept
		view_at += length(kept)
		var/index = text2num(copytext(matched, start + 1, stop))
		var/span = length(table.patterns[index])
		out += dictionary_match_case(replacetext(copytext(view, view_at, view_at + span), DICTIONARY_MARK, ""), table.sources[index], table.replacements[index])
		view_at += span
		at = stop + 1
		start = findtext(matched, DICTIONARY_TOKEN_START, at)
	out += copytext(matched, at)
	return replacetext(jointext(out, ""), DICTIONARY_MARK, "")

/proc/load_speech_dictionary(var/list/lines)
	dictionary_list = parse_dictionary_lines(lines)
	speech_dictionary = new /datum/speech_dictionary(dictionary_list)
	var/datum/dictionary_table/unrestricted = speech_dictionary.tables[DICTIONARY_NO_ERA]
	world.log << "Dictionary: [dictionary_list.len] rows, [unrestricted.patterns.len] in every era, [speech_dictionary.use_rustg ? "rust_g" : "regex"] matching."

// Reads the live research era; the displayed map.age can lag discoveries.
/proc/apply_dictionary_replacements(var/message)
	if (!speech_dictionary)
		return message
	return speech_dictionary.apply(message, map ? map.ordinal_age : null)

#undef DICTIONARY_WORD_RUN
