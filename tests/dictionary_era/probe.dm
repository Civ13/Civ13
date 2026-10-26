// Source-only fixture. Requires separately authorized native compilation/execution.
world
	maxx = 1
	maxy = 1
	maxz = 1
	hub = ""
	visibility = 0

world/OpenPort(port)
	if (port == "none")
		return ..(port)
	return 0

client/New()
	del(src)
	return

var/global/dictionary_failures = 0
/proc/dictionary_assert(condition, label)
	if (!condition)
		dictionary_failures++
		world.log << "DICTIONARY FAIL: [label]"

world/New()
	world.OpenPort("none")
	dictionary_assert(world.port == 0, "closed fixture port")
	map = new /datum/dictionary_era_map
	var/dictionary_text = file2text("dictionary.txt")
	var/list/sections = splittext(dictionary_text, "\n# Wiki slang")
	var/list/legacy = splittext(sections[1], "\n")
	var/list/legacy_dictionary = parse_dictionary_lines(legacy)
	var/list/full_dictionary = parse_dictionary_lines(splittext(dictionary_text, "\n"))
	var/legacy_count = legacy_dictionary.len
	dictionary_assert(legacy_count == 66, "unchanged legacy row count")
	for (var/era = 0 to 8)
		map.ordinal_age = era
		for (var/list/entry in legacy_dictionary)
			var/message = " [entry[1]] [uppertext(entry[1])] <b> [entry[1]]! "
			dictionary_list = legacy_dictionary
			var/original_say = legacy_say(message)
			var/original_whisper = legacy_whisper(message)
			dictionary_list = full_dictionary
			dictionary_assert(fixture_say(message) == original_say, "legacy say parity era [era]")
			dictionary_assert(fixture_whisper(message) == original_whisper, "legacy whisper parity era [era]")

	// The appended lexicon is exercised with the full legacy-plus-new pipeline.
	for (var/list/entry in full_dictionary)
		if (entry.len != 4)
			continue
		for (var/active = 0 to 8)
			map.ordinal_age = active
			var/input_message = "before [entry[1]] after"
			var/expected_message = active == entry[3] ? "before [entry[2]] after" : input_message
			dictionary_assert(apply_dictionary_replacements(input_message) == expected_message, "wiki matching/nonmatching era")
			dictionary_assert(fixture_say(input_message) == capitalize(expected_message), "wiki speech prefix")
			dictionary_assert(fixture_whisper(input_message) == expected_message, "wiki whisper prefix")
	map.ordinal_age = 4
	dictionary_assert(apply_dictionary_replacements("they were brave and fearless today") == "they were bricky and bricky today", "multiple wiki replacements")
	dictionary_assert(apply_dictionary_replacements("be brave brave now") == "be bricky bricky now", "adjacent phrase matches")
	dictionary_assert(apply_dictionary_replacements("excuse me, please") == "mind the grease, please", "phrase starts and punctuation")
	dictionary_assert(apply_dictionary_replacements("please excuse me") == "please mind the grease", "phrase ends")
	dictionary_assert(apply_dictionary_replacements("(excuse me)") == "(mind the grease)", "phrase delimiters preserved")
	for (var/neighbor in list("x", "0", "_", "-", "'", ascii2text(233), ascii2text(8212)))
		dictionary_assert(apply_dictionary_replacements("[neighbor]brave") == "[neighbor]brave", "left continuation")
		dictionary_assert(apply_dictionary_replacements("brave[neighbor]") == "brave[neighbor]", "right continuation")

	// Invalid rows must be diagnosed and omitted, including a trailing comma.
	var/list/invalid = list("a,b,", "a,b,9", "a,b,-1", "a,b,01", "a,b,1.0", "a,b,1x", "a,b,1943", "a,b,WW2", "a,b,0,1", "a,b,*", "a,b,0,", "a,b,0,literal", "a,b,0,PHRASE", "a,b,0,regex", "a,b,,phrase", "a,b,9,phrase", "a,b,0,phrase,extra", ",b,0,phrase", " a,b,0,phrase", "a ,b,0,phrase", "caf[ascii2text(233)],b,0,phrase")
	for (var/row in invalid)
		var/list/rejected = parse_dictionary_lines(list(row))
		dictionary_assert(!rejected.len, "reject [row]")
	var/list/preserved = parse_dictionary_lines(list(" a , b , 0 "))
	var/list/first = preserved[1]
	dictionary_assert(first[1] == " a " && first[2] == " b " && first[3] == 0, "preserve text; trim selector")
	var/list/crlf = parse_dictionary_lines(list("a,b,8[ascii2text(13)]"))
	first = crlf[1]
	dictionary_assert(first[3] == 8, "CRLF selector")

	for (var/era = 0 to 8)
		dictionary_list = parse_dictionary_lines(list("a,b,[era]"))
		for (var/active = 0 to 8)
			map.ordinal_age = active
			var/expected = active == era ? "b" : "a"
			dictionary_assert(apply_dictionary_replacements("a") == expected, "era matrix [era]/[active]")
			// Compare eligible paths with native legacy operations, including case.
			var/list/saved = dictionary_list
			dictionary_list = active == era ? parse_dictionary_lines(list("a,b")) : list()
			var/expected_say = legacy_say("a")
			var/expected_whisper = legacy_whisper("a")
			dictionary_list = saved
			dictionary_assert(fixture_say("a") == expected_say, "era say [era]/[active]")
			dictionary_assert(fixture_whisper("a") == expected_whisper, "era whisper [era]/[active]")

	dictionary_list = parse_dictionary_lines(list("a,b", "b,c,0", "c,d"))
	map.ordinal_age = 0
	dictionary_assert(apply_dictionary_replacements("a") == "d", "ordered mixed cascade")
	map.ordinal_age = 1
	dictionary_assert(apply_dictionary_replacements("a") == "b", "live ordinal transition")
	map.ordinal_age = 0
	dictionary_assert(apply_dictionary_replacements("a") == "d", "transition back to era zero")
	map = null
	dictionary_assert(apply_dictionary_replacements("a") == "b", "missing map unrestricted only")
	dictionary_list = parse_dictionary_lines(list("a,b", "a,c", "b,d"))
	dictionary_assert(apply_dictionary_replacements("a") == "d", "duplicate source remains ordered")
	map = new /datum/dictionary_era_map
	map.ordinal_age = 4
	dictionary_list = parse_dictionary_lines(list("lol,hahaha", "cat,dog,4", "dog,wolf,4,phrase"))
	dictionary_assert(apply_dictionary_replacements("lol catapult cat") == "hahaha dogapult wolf", "mixed literal and phrase order")
	dictionary_list = parse_dictionary_lines(list("a,a a,4,phrase"))
	dictionary_assert(apply_dictionary_replacements("a a") == "a a a a", "inserted output not rescanned")
	dictionary_list = parse_dictionary_lines(list("a.b,X,4,phrase"))
	dictionary_assert(apply_dictionary_replacements("a.b aXb") == "X aXb", "literal metacharacters")
	dictionary_list = parse_dictionary_lines(list("a a,X,4,phrase"))
	dictionary_assert(apply_dictionary_replacements("xa a a") == "xa X", "rejected overlap search advances one")
	dictionary_list = parse_dictionary_lines(list("a,b,0, phrase[ascii2text(13)]"))
	map.ordinal_age = 0
	dictionary_assert(apply_dictionary_replacements("a") == "b", "era zero and normalized mode")
	map = null
	dictionary_assert(apply_dictionary_replacements("a") == "a", "phrase missing map")
	world.log << "DICTIONARY RESULT failures=[dictionary_failures] legacy_rows=[legacy_count]"
	del(world)
	return
