// Native probe for the character setup window's data and trait actions
// (code/modules/client/preferencesSQLite/character_setup_ui.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/character_setup/setup_probe.dm
// It has no client, so the ownership guard in ui_act is covered by
// tests/character_setup/test_setup_window.py, not here.
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/setup_failures = 0
var/setup_runtime_error = FALSE
/proc/setup_check(condition, label)
	if (!condition)
		setup_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	setup_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/mob/setup_probe
// A trait with a waiting time, as a later feature would add one.
/datum/preferences/setup_probe
	var/list/held = list()
/datum/preferences/setup_probe/trait_change_block(trait_name, adding)
	return (trait_name in held) ? "You can choose again in 5 days." : null
/proc/setup_find_trait(list/data, trait_name)
	for (var/list/category in data["categories"])
		for (var/list/entry in category["traits"])
			if (entry["name"] == trait_name)
				return entry
/world/New()
	OpenPort("none")
	try
		makeDatumRefLists()
		setup_checks()
	catch(var/exception/e)
		setup_check(FALSE, "exception [e] [e.file]:[e.line] [e.desc]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = setup_failures, "runtime_error" = setup_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/setup_checks()
	var/datum/preferences/setup_probe/P = new()
	var/mob/setup_probe/user = new()
	P.gender = FEMALE
	P.real_name = "Maren Holt"

	// Every trait is shown once, in a known category.
	var/list/data = P.trait_setup_data()
	var/shown = 0
	var/list/ids = list()
	for (var/list/category in data["categories"])
		ids += category["id"]
		shown += length(category["traits"])
	setup_check(shown == trait_list.len, "every trait is listed once ([shown] of [trait_list.len])")
	setup_check(!("other" in ids), "no current trait is left uncategorised")
	setup_check(ids[1] == "playstyle", "playstyles lead the picker")
	for (var/list/category in data["categories"])
		if (!category["pick_one"])
			continue
		// A pick-one category must really be exclusive in trait_list.
		var/exclusive = TRUE
		for (var/list/a in category["traits"])
			for (var/list/b in category["traits"])
				if (a["name"] != b["name"] && !(b["name"] in trait_list[a["name"]][2]) && !(a["name"] in trait_list[b["name"]][2]))
					exclusive = FALSE
		setup_check(exclusive, "[category["id"]] traits exclude one another")

	// Taking, conflicts and swapping.
	setup_check(P.setup_add_trait("Tall") && ("Tall" in P.traits), "a trait is taken")
	setup_check(!P.setup_add_trait("Tall") && P.traits.len == 1, "a trait is not taken twice")
	setup_check(!P.setup_add_trait("Short") && !("Short" in P.traits), "a conflicting trait is refused")
	data = P.trait_setup_data()
	var/list/short = setup_find_trait(data, "Short")
	setup_check(short && length(short["conflicts"]) == 1 && short["conflicts"][1] == "Tall", "the picker names what a trait would replace")
	setup_check(data["spent"] == 1 && data["earned"] == 0 && data["error"], "an unpaid perk is reported")
	setup_check(P.setup_add_trait("Short", TRUE) && ("Short" in P.traits) && !("Tall" in P.traits), "swapping drops the conflicting trait")
	setup_check(P.setup_add_trait("Green Thumb") && P.setup_add_trait("Tinkerer", TRUE) && !("Green Thumb" in P.traits) && ("Tinkerer" in P.traits), "choosing another playstyle swaps")
	setup_check(!P.setup_add_trait("No Such Trait") && !P.setup_add_trait(null) && !P.setup_add_trait(7), "unknown traits are refused")
	data = P.trait_setup_data()
	setup_check(data["spent"] == 0 && data["earned"] == 1 && !data["error"], "the balance counts perks and drawbacks apart")
	setup_check(P.setup_remove_trait("Short") && !("Short" in P.traits), "a trait is removed")
	setup_check(!P.setup_remove_trait("Short"), "a trait not taken is not removed")

	// Old saved entries: shown, never silently dropped, cleared on request.
	P.traits = list("Agile", "Agile", "Removed Trait", "Deaf")
	data = P.trait_setup_data()
	setup_check(length(data["invalid"]) == 2 && length(data["chosen"]) == 2, "repeated and unknown saved traits are listed")
	setup_check(P.traits.len == 4, "reading does not change saved traits")
	setup_check(P.setup_remove_trait("Agile") && P.traits.len == 2, "removing clears every copy")
	P.setup_clear_traits()
	setup_check(!P.traits.len, "clear all empties the list")
	P.traits = "broken"
	data = P.trait_setup_data()
	setup_check(length(data["invalid"]) == 1 && !P.setup_add_trait("Agile"), "unreadable traits are reported and not added to")
	P.setup_clear_traits()
	setup_check(islist(P.traits) && !P.traits.len, "clear all repairs unreadable traits")

	// A trait with a waiting time cannot be taken, dropped or swapped out.
	P.traits = list("Tall")
	P.held = list("Tall", "Deaf")
	setup_check(!P.setup_remove_trait("Tall") && ("Tall" in P.traits), "a held trait is not removed")
	setup_check(!P.setup_add_trait("Short", TRUE) && ("Tall" in P.traits), "a held trait is not swapped out")
	setup_check(!P.setup_add_trait("Deaf"), "a held trait is not taken")
	P.setup_clear_traits()
	setup_check(P.traits.len == 1 && P.traits[1] == "Tall", "clear all keeps a held trait")
	data = P.trait_setup_data()
	var/list/tall = setup_find_trait(data, "Tall")
	setup_check(tall && tall["block"] == "You can choose again in 5 days.", "the picker says why a trait is held")
	P.held = list()
	P.traits = list()

	// The whole snapshot builds for a body without a client.
	data = P.character_setup_data(user)
	var/list/character = data["character"]
	setup_check(character["name"] == "Maren Holt" && character["gender"] == FEMALE, "the snapshot carries the character")
	setup_check(length(character["hair_styles"]) > 1 && ("Shaved" in character["facial_styles"]), "styles are offered")
	setup_check(length(character["previews"]) == 2 && character["previews"][2]["front"], "previews are named")
	var/first_name = character["previews"][2]["front"]
	P.setup_named_color(hair_colors, "Red", "hair")
	setup_check(P.hair_color == "Red" && P.r_hair == 181 && P.g_hair == 82 && P.b_hair == 57, "a named colour sets its red, green and blue")
	setup_check(!P.setup_named_color(hair_colors, "Puce", "hair") && P.hair_color == "Red", "an unknown colour is refused")
	data = P.character_setup_data(user)
	character = data["character"]
	setup_check(character["previews"][2]["front"] != first_name, "a changed look gets a new preview name")
	setup_check(length(data["settings"]["toggles"]) > 5 && length(data["settings"]["fps_choices"]) > 1, "settings are listed")
	setup_check(!data["locked"], "a lobby body may edit")

	// Evidence for renders: the snapshot and the preview pictures.
	if (world.params["dump"])
		P.traits = list("Green Thumb", "Agile", "Light Eater", "Deaf")
		data = P.character_setup_data(user)
		text2file(json_encode(data), "setup_data.json")
		var/list/sides = list("front" = P.preview_icons_front, "east" = P.preview_icons_east, "back" = P.preview_icons_back, "west" = P.preview_icons_west)
		for (var/v = 1 to P.preview_icons.len)
			for (var/side in sides)
				fcopy(sides[side][v], "preview_[v]_[side].png")
