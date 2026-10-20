// Actual ordinary Save_World/load_map_metadata disk paths, not extraction policy.
/proc/write_round_metadata_fixture(text)
	if(copytext(text, length(text)) == "\n") text = copytext(text, 1, length(text))
	check(fdel("map_saves/map.txt"), "fixture metadata replacement failed")
	check(text2file(text, "map_saves/map.txt"), "fixture metadata write failed")
	// Keep the envelope valid so malformed-format controls reach the parser,
	// rather than passing because an unrelated metadata hash check rejected it.
	if(fexists("map_saves/round.json"))
		var/list/state = json_decode(file2text("map_saves/round.json"))
		state["metadata"] = md5(file2text("map_saves/map.txt"))
		check(fdel("map_saves/round.json"), "fixture round envelope replacement failed")
		check(text2file(json_encode(state), "map_saves/round.json"), "fixture round envelope write failed")

/proc/check_round_metadata()
	check(!errors.len, "unexpected errors before round metadata fixture")
	var/list/keys = list("persistence", "research_active", "resourceresearch", "perschadplus")
	for(var/pass = 1, pass <= 2, pass++)
		for(var/i = 1, i <= keys.len, i++) map.vars[keys[i]] = (i % 2 == pass % 2)
		map.age = "saved round epoch"
		check(map_storage.Save_World(), "round-mode export failed")
		for(var/key in keys) map.vars[key] = !map.vars[key]
		map.age = "unsaved epoch"
		check(map_storage.load_map_metadata(), "round-mode metadata import failed")
		for(var/i = 1, i <= keys.len, i++)
			check(map.vars[keys[i]] == (i % 2 == pass % 2), "round-mode flag lost: [keys[i]]")
		check(map.age == "saved round epoch", "ordinary round epoch lost")
	var/saved = file2text("map_saves/map.txt")
	var/saved_marker = file2text("map_saves/save_complete.txt")
	var/list/rows = splittext(saved, "\n")
	// A syntactically valid modern header with a stale digest must be rejected
	// before either direct preflight or the ordinary wrapper changes the world.
	var/list/tampered = rows.Copy()
	tampered[2] = "tampered epoch"
	var/tampered_text = jointext(tampered, "\n")
	if(copytext(tampered_text, length(tampered_text)) == "\n") tampered_text = copytext(tampered_text, 1, length(tampered_text))
	check(fdel("map_saves/map.txt"), "fixture tamper replacement failed")
	check(text2file(tampered_text, "map_saves/map.txt"), "fixture tamper write failed")
	var/error_count = errors.len
	var/turf/sentinel_turf = locate(1,1,1)
	var/obj/item/test/sentinel_item = locate(/obj/item/test) in sentinel_turf
	check(!map_storage.validate_world_save(), "modern metadata tamper passed preflight")
	var/datum/controller/gameticker/tamper_ticker = new
	check(!tamper_ticker.loadmap(), "modern metadata tamper admitted by wrapper")
	check(locate(1,1,1) == sentinel_turf && sentinel_item.loc == sentinel_turf && map.age == "saved round epoch", "modern metadata tamper mutated live world")
	check(errors.len == error_count + 3, "unexpected integrity rejection message count")
	for(var/i = error_count + 1, i <= error_count + 2, i++)
		check(errors[i] == "Save rejected before clearing the world: Round state does not match completed generation", "unexpected integrity rejection message")
	check(findtext(errors[error_count + 3], "Import failed during restoration; restart from the original map before retrying: Round state does not match completed generation on ") == 1, "unexpected wrapper integrity rejection")
	errors.Cut(error_count + 1)
	write_round_metadata_fixture(saved)
	// Legacy nine fields and timestamp-bearing ten fields have no mode extension.
	check(fdel("map_saves/save_complete.txt"), "fixture legacy marker replacement failed")
	check(text2file("legacy-completed", "map_saves/save_complete.txt"), "fixture legacy marker write failed")
	for(var/legacy_length in list(9, 10))
		write_round_metadata_fixture(jointext(rows.Copy(1, legacy_length + 1), "\n"))
		map.age = "legacy reset"
		for(var/key in keys) map.vars[key] = FALSE
		check(map_storage.validate_world_save() && map_storage.load_map_metadata(), "legacy ordinary metadata rejected")
		check(map.age == "saved round epoch", "legacy base metadata lost")
		for(var/key in keys) check(map.vars[key] == FALSE, "legacy mode defaults changed")
	check(fdel("map_saves/save_complete.txt"), "fixture marker restoration failed")
	check(text2file(trim(saved_marker), "map_saves/save_complete.txt"), "fixture marker write failed")
	// Malformed extensions must fail preflight and leave all live metadata alone.
	for(var/bad in list("partial", "nonboolean", "empty", "extra"))
		var/parser_error_count = errors.len
		var/list/invalid = rows.Copy(1, 15)
		if(bad == "partial") invalid.Cut(12)
		if(bad == "nonboolean") invalid[11] = "2"
		if(bad == "empty") invalid[14] = ""
		if(bad == "extra") invalid += "unexpected"
		write_round_metadata_fixture(jointext(invalid, "\n"))
		map.age = "live sentinel"
		for(var/key in keys) map.vars[key] = FALSE
		check(!map_storage.validate_world_save(), "invalid round extension passed preflight: [bad]")
		var/turf/live_turf = locate(1,1,1)
		var/obj/item/test/live_item = locate(/obj/item/test) in live_turf
		var/datum/controller/gameticker/ticker = new
		check(!ticker.loadmap(), "invalid round extension admitted by ordinary wrapper: [bad]")
		check(locate(1,1,1) == live_turf && live_item.loc == live_turf, "invalid round extension disposed live state: [bad]")
		check(!map_storage.load_map_metadata(), "invalid round extension imported: [bad]")
		check(map.age == "live sentinel", "invalid round extension changed base metadata: [bad]")
		for(var/key in keys) check(map.vars[key] == FALSE, "invalid round extension changed mode: [bad]")
		// Direct preflight and wrapper preflight each report the malformed save;
		// the wrapper also reports its caught failure without mutating the world.
		check(errors.len == parser_error_count + 3, "unexpected rejection message count: [bad]")
		for(var/i = parser_error_count + 1, i <= parser_error_count + 2, i++)
			check(errors[i] == "Save rejected before clearing the world: Save round-mode metadata is malformed", "unexpected rejection message: [bad]")
		var/wrapper_report = errors[parser_error_count + 3]
		check(findtext(wrapper_report, "Import failed during restoration; restart from the original map before retrying: Save round-mode metadata is malformed on ") == 1, "unexpected wrapper rejection message: [bad]")
		errors.Cut(parser_error_count + 1)
	write_round_metadata_fixture(saved)
	check(map_storage.load_map_metadata() && map_storage.validate_world_save(), "round fixture did not restore completed save")
