// Actual ordinary Save_World/load_map_metadata disk paths, not extraction policy.
/proc/write_round_metadata_fixture(text)
	if(copytext(text, length(text)) == "\n") text = copytext(text, 1, length(text))
	check(fdel("map_saves/map.txt"), "fixture metadata replacement failed")
	check(text2file(text, "map_saves/map.txt"), "fixture metadata write failed")

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
	var/list/rows = splittext(saved, "\n")
	// Legacy nine fields and timestamp-bearing ten fields have no mode extension.
	for(var/legacy_length in list(9, 10))
		write_round_metadata_fixture(jointext(rows.Copy(1, legacy_length + 1), "\n"))
		map.age = "legacy reset"
		for(var/key in keys) map.vars[key] = FALSE
		check(map_storage.validate_world_save() && map_storage.load_map_metadata(), "legacy ordinary metadata rejected")
		check(map.age == "saved round epoch", "legacy base metadata lost")
		for(var/key in keys) check(map.vars[key] == FALSE, "legacy mode defaults changed")
	// Malformed extensions must fail preflight and leave all live metadata alone.
	for(var/bad in list("partial", "nonboolean", "empty", "extra"))
		var/error_count = errors.len
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
		check(errors.len == error_count + 3, "unexpected rejection message count: [bad]")
		for(var/i = error_count + 1, i <= error_count + 2, i++)
			check(errors[i] == "Save rejected before clearing the world: Save round-mode metadata is malformed", "unexpected rejection message: [bad]")
		var/wrapper_report = errors[error_count + 3]
		check(findtext(wrapper_report, "Import failed during restoration; restart from the original map before retrying: Save round-mode metadata is malformed on ") == 1, "unexpected wrapper rejection message: [bad]")
		errors.Cut(error_count + 1)
	write_round_metadata_fixture(saved)
	check(map_storage.load_map_metadata() && map_storage.validate_world_save(), "round fixture did not restore completed save")
