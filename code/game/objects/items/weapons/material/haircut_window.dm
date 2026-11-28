// The Haircut window (tgui/src/interfaces/Haircut.tsx): what a razor shows the
// player holding it, for their own hair or the hair of someone next to them.
// The window draws every eligible style on the real figure and sends back one
// pair of styles; nothing about the character changes before the timed cut.

/client/var/tmp/datum/grooming_preview/grooming_preview

// Every hair and facial hair style, one row each, facing south, east, north
// and west. Built once and sent under one name, so a client fetches it once.
var/global/icon/grooming_sheet_icon = null
var/global/list/grooming_sheet_rows = null
var/global/list/grooming_design_sprite_rows = null
#define GROOMING_SHEET_FILE "civ13_haircut_styles.png"
#define GROOMING_CELL 32

/proc/grooming_blank_sheet(width, height)
	var/icon/sheet = icon('icons/32x32.dmi', "nothing")
	sheet.Insert(icon('icons/effects/effects.dmi', "nothing"), "", SOUTH, 1, 0)
	sheet.Scale(width, height)
	return sheet

/proc/grooming_sheet_dirs()
	return list(SOUTH, EAST, NORTH, WEST)

/proc/grooming_sheet()
	if (grooming_sheet_icon)
		return grooming_sheet_icon
	var/list/rows = list()
	var/list/styles = list()
	for (var/group in list("hair", "beard"))
		var/list/source = group == "hair" ? hair_styles_list : facial_hair_styles_list
		for (var/style in source)
			rows["[group]|[style]"] = styles.len
			styles += source[style]
	var/list/dirs = grooming_sheet_dirs()
	var/icon/sheet = grooming_blank_sheet(GROOMING_CELL * dirs.len, GROOMING_CELL * max(1, styles.len))
	var/list/known_states = list()
	var/list/sprite_rows = list()
	for (var/i = 1 to styles.len)
		var/datum/sprite_accessory/S = styles[i]
		var/list/states = known_states["[S.icon]"]
		if (!states)
			states = icon_states(S.icon)
			known_states["[S.icon]"] = states
		var/state = "[S.icon_state]_s"
		if (!(state in states))
			continue
		sprite_rows += i - 1
		for (var/d = 1 to dirs.len)
			// Blend() counts rows from the bottom; the window counts from the top.
			sheet.Blend(icon(S.icon, state, dirs[d]), ICON_OVERLAY, (d - 1) * GROOMING_CELL + 1, (styles.len - i) * GROOMING_CELL + 1)
	grooming_sheet_rows = rows
	grooming_design_sprite_rows = sprite_rows
	grooming_sheet_icon = sheet
	return sheet

// Rectangles use canvas coordinates: source zone, left, top, width, height.
// The same partition drives the actual icon and the four-direction preview.
/proc/grooming_design_regions(direction)
	// In profile, preserve the ties and braids above the rear hairline.
	switch (direction)
		if (EAST)
			return list(list(1, 0, 0, 32, 2), list(3, 0, 2, 13, 10), list(1, 13, 2, 19, 2), list(3, 13, 4, 3, 8), list(2, 16, 4, 16, 8), list(3, 0, 12, 32, 20))
		if (WEST)
			return list(list(1, 0, 0, 32, 2), list(3, 19, 2, 13, 10), list(1, 0, 2, 19, 2), list(3, 16, 4, 3, 8), list(2, 0, 4, 16, 8), list(3, 0, 12, 32, 20))
		if (NORTH)
			return list(list(1, 0, 0, 32, 2), list(2, 0, 2, 11, 10), list(3, 11, 2, 10, 10), list(2, 21, 2, 11, 10), list(3, 0, 12, 32, 20))
	return list(list(1, 0, 0, 32, 4), list(2, 0, 4, 14, 8), list(1, 14, 4, 4, 8), list(2, 18, 4, 14, 8), list(3, 0, 12, 32, 20))

/proc/grooming_design_valid(list/design)
	if (!islist(design) || design.len != 3)
		return FALSE
	for (var/i = 1 to 3)
		var/style = design[i]
		// Require a positional list of canonical names, not an associative map.
		if (!istext(style) || !hair_styles_list[style] || !isnull(design[style]))
			return FALSE
	return TRUE

/proc/grooming_pattern_name(value)
	if (!istext(value) || !length(value) || length(value) > 32)
		return null
	var/name = trim(value)
	if (!length(name) || name != strip_html_properly(name))
		return null
	return name

/proc/grooming_patterns_clean(list/patterns)
	. = list()
	if (!islist(patterns) || patterns.len > 8)
		return
	for (var/key in patterns)
		var/name = grooming_pattern_name(key)
		if (name && name == key && grooming_design_valid(patterns[key]))
			.[name] = patterns[key].Copy()

/mob/living/human/proc/grooming_design_choices()
	if (!species || !body_build || body_build.nohair || body_build.nofacialhair || h_growth <= 0)
		return list()
	grooming_sheet()
	var/list/choices = generate_valid_hairstyles(TRUE, TRUE)
	for (var/style in choices.Copy())
		if (!(grooming_sheet_rows["hair|[style]"] in grooming_design_sprite_rows))
			choices -= style
	return choices

/mob/living/human/proc/grooming_can_style(list/design)
	if (!grooming_design_valid(design) || !species || !body_build || body_build.nohair || body_build.nofacialhair || h_growth <= 0)
		return FALSE
	grooming_sheet()
	for (var/style in design)
		if (!(grooming_sheet_rows["hair|[style]"] in grooming_design_sprite_rows))
			return FALSE
		var/datum/sprite_accessory/S = hair_styles_list[style]
		if (!S.species_allowed || !(species.get_bodytype() in S.species_allowed) || S.growth > h_growth)
			return FALSE
		if ((gender == MALE && S.gender == FEMALE) || (gender == FEMALE && S.gender == MALE))
			return FALSE
	return TRUE

/proc/grooming_design_icon(list/design, colour)
	var/icon/result = icon('icons/mob/human_face.dmi', "bald_s")
	for (var/direction in grooming_sheet_dirs())
		var/icon/facing = grooming_blank_sheet(32, 32)
		var/list/layers = list()
		for (var/i = 1 to 3)
			var/datum/sprite_accessory/S = hair_styles_list[design[i]]
			var/icon/layer = icon(S.icon, "[S.icon_state]_s", direction)
			if (S.do_colouration)
				layer.Blend(colour, ICON_ADD)
			layers += layer
		for (var/list/R in grooming_design_regions(direction))
			var/icon/part = icon(layers[R[1]])
			var/x = R[2] + 1
			var/y = 33 - R[3] - R[5]
			part.Crop(x, y, x + R[4] - 1, y + R[5] - 1)
			facing.Blend(part, ICON_OVERLAY, x, y)
		result.Insert(facing, "", direction)
	return result

// One private review of a proposed cut. Only the player holding the razor can answer.
/datum/grooming_preview
	should_save = FALSE
	var/mob/living/human/viewer
	var/client/viewer_client
	var/obj/item/weapon/material/kitchen/utensil/knife/razorblade/razor
	var/mob/living/human/subject
	var/cutting = FALSE
	var/body_file = null
	var/opened_hair

/datum/grooming_preview/New(mob/living/human/user, mob/living/human/M, obj/item/weapon/material/kitchen/utensil/knife/razorblade/blade)
	..()
	viewer = user
	viewer_client = user?.client
	subject = M
	opened_hair = M?.h_style
	razor = blade

/datum/grooming_preview/Destroy()
	GLOB.nanomanager.close_uis(src)
	if (viewer_client?.grooming_preview == src)
		viewer_client.grooming_preview = null
	viewer = null
	viewer_client = null
	subject = null
	razor = null
	return ..()

/datum/grooming_preview/proc/valid()
	return viewer_client && viewer_client.mob == viewer && viewer_client.grooming_preview == src && !QDELETED(razor) && razor.grooming_valid(subject, viewer)

// The window closes itself when the razor is put away or the two step apart.
/datum/topic_state/grooming/can_use_topic(var/src_object, var/mob/user)
	var/datum/grooming_preview/P = src_object
	if (!istype(P) || user != P.viewer || P.cutting || !P.valid())
		return STATUS_CLOSE
	return STATUS_INTERACTIVE

/datum/grooming_preview/ui_actions(ui_key)
	return list("cut", "cancel", "style", "reset_style", "save_pattern", "delete_pattern")

/datum/grooming_preview/ui_action_fields(ui_key, action)
	switch (action)
		if ("cut")
			return list("beard")
		if ("style")
			return list("sides", "back")
		if ("save_pattern")
			return list("sides", "back", "pattern_name")

/datum/grooming_preview/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = TRUE)
	if (user != viewer || !valid())
		return
	open_tgui(user, ui_key, "haircut.tmpl", "Haircut", 800, 660, window_data(), ui, force_open, /datum/topic_state/grooming)

// Eligible styles as rows the window can draw, shortest first.
/datum/grooming_preview/proc/style_rows(list/names, list/source, group, current)
	. = list()
	if (current && source[current] && !(current in names))
		names = list(current) + names
	for (var/length = 0 to 4)
		for (var/style in names)
			var/datum/sprite_accessory/S = source[style]
			if (!S || clamp(S.growth, 0, 4) != length)
				continue
			var/row = grooming_sheet_rows["[group]|[style]"]
			if (isnull(row))
				continue
			. += list(list("name" = style, "length" = length, "row" = row, "tint" = S.do_colouration ? 1 : 0))

/datum/grooming_preview/proc/window_data()
	var/list/data = list()
	viewer_client << browse_rsc(grooming_sheet(), GROOMING_SHEET_FILE)
	if (!body_file)
		// The name changes with every opening, so an old figure is never shown.
		body_file = "haircut_[md5("\ref[src]-[world.time]-[rand(1, 99999)]")].png"
		viewer_client << browse_rsc(subject.grooming_body_sheet(), body_file)
	data["sheet"] = GROOMING_SHEET_FILE
	data["body"] = body_file
	data["self"] = subject == viewer ? 1 : 0
	data["name"] = subject.name
	data["hair"] = subject.h_style
	data["beard"] = subject.f_style
	data["hair_color"] = rgb(subject.r_hair, subject.g_hair, subject.b_hair)
	data["beard_color"] = rgb(subject.r_facial, subject.g_facial, subject.b_facial)
	data["hair_styles"] = style_rows(razor.grooming_hair_choices(subject), hair_styles_list, "hair", subject.h_style)
	data["beard_styles"] = style_rows(razor.grooming_beard_choices(subject), facial_hair_styles_list, "beard", subject.f_style)
	data["seconds"] = 8
	data["design_styles"] = style_rows(subject.grooming_design_choices(), hair_styles_list, "hair", null)
	data["design"] = subject.grooming_can_style(subject.hair_design) ? subject.hair_design : null
	data["patterns"] = list()
	var/list/patterns = grooming_patterns_clean(viewer.hair_patterns)
	for (var/name in patterns)
		data["patterns"] += list(list("name" = name, "design" = patterns[name]))
	data["design_regions"] = list()
	for (var/direction in grooming_sheet_dirs())
		data["design_regions"] += list(grooming_design_regions(direction))
	return data

/datum/grooming_preview/ui_act(action, list/params, mob/user, datum/nanoui/ui)
	if (user != viewer || cutting || !valid())
		return TRUE
	if (action == "cancel")
		qdel(src)
		return TRUE
	if (action == "delete_pattern")
		var/name = grooming_pattern_name(params["value"])
		var/list/patterns = grooming_patterns_clean(viewer.hair_patterns)
		if (name in patterns)
			patterns -= name
			viewer.hair_patterns = patterns.len ? patterns : null
		return TRUE
	if (action == "style" || action == "reset_style" || action == "save_pattern")
		if (subject.h_style != opened_hair)
			qdel(src)
			to_chat(user, SPAN_NOTICE("The base cut has changed. Open the hairstyle preview again."))
			return TRUE
		var/list/design
		if (action != "reset_style")
			design = list(params["value"], params["sides"], params["back"])
			if (!subject.grooming_can_style(design))
				return TRUE
		if (action == "save_pattern")
			var/name = grooming_pattern_name(params["pattern_name"])
			var/list/patterns = grooming_patterns_clean(viewer.hair_patterns)
			if (!name)
				return TRUE
			if (patterns.len >= 8 && !(name in patterns))
				to_chat(user, SPAN_NOTICE("Your style book is full. Remove a saved pattern first."))
				return TRUE
			patterns[name] = design
			viewer.hair_patterns = patterns
			return TRUE
		if (subject.set_hair_design(design))
			user.visible_message("[user] restyles [subject == user ? "their own" : "[subject]'s"] hair.", "You [design ? "apply the hairstyle" : "restore the stock cut"].")
			qdel(src)
		return TRUE
	if (action != "cut")
		return FALSE
	var/new_hair = params["value"]
	var/new_beard = params["beard"]
	if (isnull(new_beard))
		new_beard = subject.f_style
	if (!istext(new_hair) || !istext(new_beard))
		return TRUE
	if (new_hair != subject.h_style && !(new_hair in razor.grooming_hair_choices(subject)))
		return TRUE
	if (new_beard != subject.f_style && !(new_beard in razor.grooming_beard_choices(subject)))
		return TRUE
	if (new_hair == subject.h_style && new_beard == subject.f_style)
		return TRUE
	// The cut waits on the player; the window is gone for as long as it runs.
	cutting = TRUE
	GLOB.nanomanager.close_uis(src)
	razor.groom_cut(subject, viewer, new_hair, new_beard)
	if (!QDELETED(src))
		qdel(src)
	return TRUE

#undef GROOMING_SHEET_FILE
#undef GROOMING_CELL
