// Native probe for the Haircut window's server side
// (code/game/objects/items/weapons/material/haircut_window.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/razor_grooming/haircut_probe.dm 300
// It has no client, so the window's ownership and action guards are covered by
// tests/razor_grooming/test_razor.py, not here. With `-params dump=1` run by
// hand in the evidence folder it also writes the pictures and the snapshot.
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/haircut_probe/New()
	return
var/cut_failures = 0
var/cut_runtime_error = FALSE
/proc/cut_check(condition, label)
	if (!condition)
		cut_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	cut_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	sleep(1)
	try
		config = new
		config.webhook_can_fire = FALSE
		makeDatumRefLists()
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		movementMachine = new
		map = new /obj/map_metadata/haircut_probe
		Master.start_timer_loop()
		cut_checks()
	catch(var/exception/e)
		cut_check(FALSE, "exception [e] [e.file]:[e.line] [e.desc]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = cut_failures, "runtime_error" = cut_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/cut_names(list/rows)
	. = list()
	for (var/list/row in rows)
		. += row["name"]

/proc/cut_checks()
	map.persistence = FALSE
	var/mob/living/human/H = new /mob/living/human(locate(5, 5, 1))
	sleep(2)
	H.gender = MALE
	H.real_name = "Tomas Reed"
	H.name = "Tomas Reed"
	H.r_hair = 96
	H.g_hair = 56
	H.b_hair = 24
	H.r_facial = 96
	H.g_facial = 56
	H.b_facial = 24
	H.h_style = "Shoulder-length Hair"
	H.h_growth = 3
	H.f_style = "Full Beard"
	H.f_growth = 3
	H.equip_to_slot_or_del(new /obj/item/clothing/under/medieval/leather(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/leather(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/head/strawhat(H), slot_head)
	H.update_hair()
	H.regenerate_icons()
	var/obj/item/weapon/material/kitchen/utensil/knife/razorblade/R = new(H)
	H.put_in_active_hand(R)
	cut_check(H.get_active_hand() == R, "the probe body holds the razor")

	// The shared style sheet: one row per style, four facings.
	var/started = world.timeofday
	var/icon/sheet = grooming_sheet()
	var/took = world.timeofday - started
	var/total = hair_styles_list.len + facial_hair_styles_list.len
	cut_check(sheet.Width() == 128 && sheet.Height() == 32 * total, "the style sheet is four facings wide and one row per style ([sheet.Width()]x[sheet.Height()], [total] styles)")
	cut_check(grooming_sheet() == sheet, "the style sheet is built once")
	cut_check(took < 20, "building the style sheet is quick ([took] ds)")
	cut_check(grooming_sheet_rows["hair|Bald"] == 0 && grooming_sheet_rows["beard|Shaved"] == hair_styles_list.len, "rows are counted from the top, hair first")
	var/mohawk = grooming_sheet_rows["hair|Mohawk"]
	var/filled = FALSE
	for (var/x = 1 to 32)
		for (var/y = 1 to 32)
			if (sheet.GetPixel(x, (total - 1 - mohawk) * 32 + y))
				filled = TRUE
	cut_check(filled, "a style's row holds its picture")

	// The figure: body and clothes under the hair, no hair and no hat.
	var/before_hair = H.h_style
	var/icon/body = H.grooming_body_sheet()
	cut_check(body.Width() == 128 && body.Height() == 64, "the figure sheet is two rows of four facings")
	cut_check(body.GetPixel(16, 32 + 12) && body.GetPixel(32 + 16, 32 + 12) && body.GetPixel(64 + 16, 32 + 12) && body.GetPixel(96 + 16, 32 + 12), "every facing of the figure is drawn")
	cut_check(!body.GetPixel(16, 32 + 32) && !body.GetPixel(16, 32 + 31), "the hat and hair are left off the figure")
	cut_check(H.h_style == before_hair && H.head, "drawing the figure changes nothing on the body")

	// What the window offers.
	var/datum/grooming_preview/P = new(H, H, R)
	var/list/hair = P.style_rows(R.grooming_hair_choices(H), hair_styles_list, "hair", H.h_style)
	var/list/beard = P.style_rows(R.grooming_beard_choices(H), facial_hair_styles_list, "beard", H.f_style)
	var/list/hair_names = cut_names(hair)
	cut_check(("Bald" in hair_names) && ("Mohawk" in hair_names) && ("Shoulder-length Hair" in hair_names), "shorter styles and the current one are offered")
	cut_check(!("Long Hair" in hair_names) && !("Flaired Hair" in hair_names), "longer and other-gender styles are not offered")
	var/ordered = TRUE
	for (var/i = 2 to hair.len)
		if (hair[i]["length"] < hair[i - 1]["length"])
			ordered = FALSE
	cut_check(ordered && hair[1]["length"] == 0, "styles are listed shortest first")
	cut_check(("Shaved" in cut_names(beard)) && ("Full Beard" in cut_names(beard)) && !("Very Long Beard" in cut_names(beard)), "facial hair follows the same rule")
	H.h_growth = 1
	cut_check("Shoulder-length Hair" in cut_names(P.style_rows(R.grooming_hair_choices(H), hair_styles_list, "hair", H.h_style)), "the current style is listed even when no longer eligible")
	H.h_growth = 3
	var/mob/living/human/W = new /mob/living/human(locate(6, 5, 1))
	sleep(2)
	W.gender = FEMALE
	cut_check(!length(R.grooming_beard_choices(W)), "a woman is offered no facial hair")

	// A window without its player does nothing.
	cut_check(!P.valid(), "a preview without a connected player is not valid")
	P.ui_act("cut", list("value" = "Bald", "beard" = "Shaved"), H, null)
	cut_check(H.h_style == "Shoulder-length Hair" && H.f_style == "Full Beard", "an invalid preview cannot start a cut")

	if (world.params["dump"])
		fcopy(sheet, "civ13_haircut_styles.png")
		fcopy(body, "haircut_body.png")
		text2file(json_encode(list("sheet" = "civ13_haircut_styles.png", "body" = "haircut_body.png", "self" = 1, "name" = H.name, "hair" = H.h_style, "beard" = H.f_style,
			"hair_color" = rgb(H.r_hair, H.g_hair, H.b_hair), "beard_color" = rgb(H.r_facial, H.g_facial, H.b_facial), "hair_styles" = hair, "beard_styles" = beard, "seconds" = 8)), "haircut_data.json")

	// The timed cut: refused choices change nothing, a valid pair is applied.
	cut_check(!R.groom_cut(H, H, "Shoulder-length Hair", "Full Beard"), "cutting to the same styles does nothing")
	H.h_growth = 1
	cut_check(!R.groom_cut(H, H, "Dreadlocks", "Full Beard") && H.h_style == "Shoulder-length Hair", "a style longer than the hair is refused after the wait")
	H.h_growth = 3
	cut_check(!R.groom_cut(H, H, "No Such Style", "Full Beard") && H.h_style == "Shoulder-length Hair", "an unknown style is refused")
	cut_check(R.groom_cut(H, H, "Mohawk", "Full Beard") && H.h_style == "Mohawk" && H.f_style == "Full Beard", "hair is cut and the beard kept")
	cut_check(H.h_growth == hair_styles_list["Mohawk"].growth, "the cut sets the hair's length")
	cut_check(R.groom_cut(H, H, "Mohawk", "Shaved") && H.f_style == "Shaved" && H.f_growth == 0, "the beard is cut and the hair kept")
	cut_check(!R.groom_cut(W, H, "Bald", W.f_style) || W.h_style == "Bald", "a neighbour can be barbered")
	H.drop_from_inventory(R)
	cut_check(!R.groom_cut(H, H, "Bald", "Shaved") && H.h_style == "Mohawk", "no cut without the razor in hand")

	// Use the live item-click route; substitute only the client colour prompt.
	build_research_tree()
	map.persistence = TRUE
	H.a_intent = I_HELP
	H.targeted_organ = "head"
	H.h_style = "Mohawk"
	H.f_style = "Full Beard"
	var/hair_length = H.h_growth
	var/beard_length = H.f_growth
	var/original_beard = hair_dye_current(H, TRUE)
	H.known_recipe_nodes = list("weaving")
	var/obj/item/stack/material/cloth/dye_probe/C = new(H, 4, FALSE)
	H.put_in_active_hand(C)
	C.answer = "#3e5a86"
	C.resolve_attackby(H, H)
	cut_check(C.amount == 4 && hair_dye_current(H, FALSE) != "#3e5a86", "a locked tailoring dye does not charge or change hair")
	C.answer = "#6e4c30"
	C.resolve_attackby(H, H)
	cut_check(C.amount == 3 && hair_dye_current(H, FALSE) == "#6e4c30" && hair_dye_current(H, TRUE) == original_beard, "self-click dyes scalp hair only and consumes one sheet")
	C.resolve_attackby(H, H)
	cut_check(C.amount == 3, "choosing the current colour costs nothing")
	H.targeted_organ = "mouth"
	H.known_recipe_nodes = list("weaving", "textile_mills")
	C.answer = "#be46aa"
	C.resolve_attackby(H, H)
	cut_check(C.amount == 2 && hair_dye_current(H, TRUE) == "#be46aa" && hair_dye_current(H, FALSE) == "#6e4c30", "Textile Mills allows a mixed beard colour without touching scalp hair")
	cut_check(H.h_style == "Mohawk" && H.f_style == "Full Beard" && H.h_growth == hair_length && H.f_growth == beard_length, "dye preserves style and growth")
	C.answer = null
	C.resolve_attackby(H, H)
	cut_check(C.amount == 2, "cancelling costs nothing")
	C.answer = "#987xyz"
	C.resolve_attackby(H, H)
	cut_check(C.amount == 2 && hair_dye_current(H, TRUE) == "#be46aa", "invalid RGB cannot change hair")
	C.answer = "#e36622"
	var/other_colour = hair_dye_current(W, FALSE)
	C.resolve_attackby(W, H)
	cut_check(C.amount == 2 && hair_dye_current(W, FALSE) == other_colour, "another player cannot apply dye to the recipient")
	H.f_style = "Shaved"
	C.resolve_attackby(H, H)
	cut_check(C.amount == 2, "a shaved face does not take dye")
	H.f_style = "Full Beard"
	spawn(5)
		H.drop_from_inventory(C)
	C.resolve_attackby(H, H)
	cut_check(C.amount == 2 && hair_dye_current(H, TRUE) == "#be46aa", "dropping the sheet during application does not pay or recolour")

	// Optional render output uses the same BYOND blend and existing character sprites.
	if (world.params["dump"])
		H.h_style = "Shoulder-length Hair"
		H.f_style = "Full Beard"
		hair_dye_sample(H, "#6e4c30", "#6e4c30", "walnut")
		hair_dye_sample(H, "#3e5a86", "#2a2826", "woad")
		hair_dye_sample(H, "#a8342c", "#6e4c30", "madder")
		hair_dye_sample(H, "#be46aa", "#3a8a80", "custom")

/proc/hair_dye_sample(mob/living/human/H, scalp, beard, label)
	var/datum/sprite_accessory/S = hair_styles_list[H.h_style]
	var/datum/sprite_accessory/F = facial_hair_styles_list[H.f_style]
	var/list/parts = list(list(F.icon, "[F.icon_state]_s", beard), list(S.icon, "[S.icon_state]_s", scalp))
	var/icon/face = cached_face_icon(parts)
	var/icon/body = H.grooming_body_sheet()
	var/list/dirs = grooming_sheet_dirs()
	for (var/d in list(1, 2))
		var/x = (d - 1) * 32 + 1
		var/icon/card = icon(body)
		card.Crop(x, 33, x + 31, 64)
		card.Blend(icon(face, dir = dirs[d]), ICON_OVERLAY)
		var/icon/top = icon(body)
		top.Crop(x, 1, x + 31, 32)
		card.Blend(top, ICON_OVERLAY)
		fcopy(card, "hair-dye-[label]-[d].png")

/obj/item/stack/material/cloth/dye_probe
	var/answer

/obj/item/stack/material/cloth/dye_probe/choose_hair_dye(mob/living/human/H, part, previous)
	return answer
