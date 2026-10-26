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
	var/list/legacy = splittext(file2text("dictionary.txt"), "\n")
	dictionary_list = parse_dictionary_lines(legacy)
	var/legacy_count = dictionary_list.len
	dictionary_assert(legacy_count == 66, "unchanged legacy row count")
	for (var/era = 0 to 8)
		map.ordinal_age = era
		for (var/list/entry in dictionary_list)
			var/message = " [entry[1]] [uppertext(entry[1])] <b> [entry[1]]! "
			dictionary_assert(fixture_say(message) == legacy_say(message), "legacy say parity era [era]")
			dictionary_assert(fixture_whisper(message) == legacy_whisper(message), "legacy whisper parity era [era]")

	// Invalid rows must be diagnosed and omitted, including a trailing comma.
	var/list/invalid = list("a,b,", "a,b,9", "a,b,-1", "a,b,01", "a,b,1.0", "a,b,1x", "a,b,1943", "a,b,WW2", "a,b,0,1", "a,b,*")
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
	world.log << "DICTIONARY RESULT failures=[dictionary_failures] legacy_rows=[legacy_count]"
	del(world)
	return
