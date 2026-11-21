// The Haircut window (tgui/src/interfaces/Haircut.tsx): what a razor shows the
// player holding it, for their own hair or the hair of someone next to them.
// The window draws every eligible style on the real figure and sends back one
// pair of styles; nothing about the character changes before the timed cut.

/client/var/tmp/datum/grooming_preview/grooming_preview

// Every hair and facial hair style, one row each, facing south, east, north
// and west. Built once and sent under one name, so a client fetches it once.
var/global/icon/grooming_sheet_icon = null
var/global/list/grooming_sheet_rows = null
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
	for (var/i = 1 to styles.len)
		var/datum/sprite_accessory/S = styles[i]
		var/list/states = known_states["[S.icon]"]
		if (!states)
			states = icon_states(S.icon)
			known_states["[S.icon]"] = states
		var/state = "[S.icon_state]_s"
		if (!(state in states))
			continue
		for (var/d = 1 to dirs.len)
			// Blend() counts rows from the bottom; the window counts from the top.
			sheet.Blend(icon(S.icon, state, dirs[d]), ICON_OVERLAY, (d - 1) * GROOMING_CELL + 1, (styles.len - i) * GROOMING_CELL + 1)
	grooming_sheet_rows = rows
	grooming_sheet_icon = sheet
	return sheet

// One private review of a proposed cut. Only the player holding the razor can answer.
/datum/grooming_preview
	should_save = FALSE
	var/mob/living/human/viewer
	var/client/viewer_client
	var/obj/item/weapon/material/kitchen/utensil/knife/razorblade/razor
	var/mob/living/human/subject
	var/cutting = FALSE
	var/body_file = null

/datum/grooming_preview/New(mob/living/human/user, mob/living/human/M, obj/item/weapon/material/kitchen/utensil/knife/razorblade/blade)
	..()
	viewer = user
	viewer_client = user?.client
	subject = M
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
	return list("cut", "cancel")

/datum/grooming_preview/ui_action_fields(ui_key, action)
	return action == "cut" ? list("beard") : null

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
	return data

/datum/grooming_preview/ui_act(action, list/params, mob/user, datum/nanoui/ui)
	if (user != viewer || cutting || !valid())
		return TRUE
	if (action == "cancel")
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
