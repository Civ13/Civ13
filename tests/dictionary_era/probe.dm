// Dictionary fixture probe: runs every corpus line through the old and new
// speech dictionaries and writes results.json. Built by prepare.py.

/world/New()
	var/list/inputs = json_decode(file2text("inputs.json"))
	legacy_dictionary_list = legacy_parse_dictionary_lines(splittext(file2text("legacy_dictionary.txt"), "\n"))
	load_speech_dictionary(splittext(file2text("dictionary.txt"), "\n"))
	var/list/records = list()
	for (var/list/record in inputs["records"])
		var/text = record[1]
		var/era = record[2]
		if (era < 0)
			map = null
		else
			if (!map)
				map = new
			map.ordinal_age = era
		if (record[3] == "whisper")
			records += list(list(visible(legacy_whisper(text)), visible(fixture_whisper(text))))
		else
			records += list(list(visible(legacy_say(text)), visible(fixture_say(text))))
	var/list/parser = list()
	for (var/line in inputs["parser"])
		var/list/rows = parse_dictionary_lines(list(line))
		parser += rows.len ? TRUE : FALSE
	var/list/result = list("engine" = speech_dictionary.use_rustg ? "rust_g" : "regex", "records" = records, "parser" = parser)
	text2file(json_encode(result), "results.json")
	del src

// Control characters do not survive json_encode, so spell them out.
/proc/visible(var/text)
	for (var/code in 1 to 31)
		text = replacetext(text, ascii2text(code), "\\x[code < 16 ? "0" : ""][num2text(code, 1, 16)]")
	return text
