// The character setup window: appearance, traits and personal settings in one
// tgui screen (tgui/src/interfaces/CharacterSetup.tsx). Every button is one
// immediate action; nothing here waits on a prompt, so a choice is always
// checked against the preferences as they are when it arrives.

/datum/preferences
	var/tmp/setup_notice = null
	var/tmp/preview_key = null

// Only the owner of these preferences may see or change them.
/datum/topic_state/character_setup/can_use_topic(var/src_object, var/mob/user)
	var/datum/preferences/P = src_object
	if (!istype(P) || !user || !user.client || user.client.prefs != P)
		return STATUS_CLOSE
	return STATUS_INTERACTIVE

/datum/preferences/ui_actions(ui_key)
	return list("name", "random_name", "always_random_name", "gender", "age", "blood", "skin_tone", "hair_style", "hair_color", "facial_style", "facial_color", "eye_color", "randomize", "always_random_body", "trait_add", "trait_swap", "trait_remove", "trait_random", "trait_clear", "ui_style", "cursor", "client_fps", "reset_tutorial", "toggle_on", "toggle_off", "tap_step", "hover_text", "hover_text_scale", "hud_scale", "edit_hud_layout", "reset_hud_layout", "keybindings", "birth_chart", "verify_discord")

/datum/preferences/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = TRUE)
	if (!user || !user.client || user.client.prefs != src)
		return
	open_tgui(user, ui_key, "character_setup.tmpl", "Character Setup", 860, 720, character_setup_data(user), ui, force_open, /datum/topic_state/character_setup)

// A living character keeps the body and traits it was made with.
/datum/preferences/proc/setup_locked(mob/user)
	return ishuman(user) && user.stat != DEAD

/datum/preferences/proc/setup_species()
	return all_species[(species && (species in all_species)) ? species : "Human"]

/datum/preferences/proc/setup_hair_styles()
	. = list()
	var/datum/species/S = setup_species()
	for (var/style in hair_styles_list)
		var/datum/sprite_accessory/A = hair_styles_list[style]
		if (S && (S.get_bodytype() in A.species_allowed))
			. += style

/datum/preferences/proc/setup_facial_styles()
	. = list()
	var/datum/species/S = setup_species()
	for (var/style in facial_hair_styles_list)
		var/datum/sprite_accessory/A = facial_hair_styles_list[style]
		if ((gender == MALE && A.gender == FEMALE) || (gender == FEMALE && A.gender == MALE))
			continue
		if (S && (S.get_bodytype() in A.species_allowed))
			. += style

/datum/preferences/proc/setup_cursors()
	return list("Default" = null, "Red Crosshair" = 'icons/effects/red_cursors.dmi', "Green Crosshair" = 'icons/effects/green_cursors.dmi', "White Crosshair" = 'icons/effects/white_cursors.dmi')

// Sends the preview pictures under names that change with the appearance, so
// the window never shows a stale one, and rebuilds them only when it changed.
/datum/preferences/proc/setup_previews(mob/user)
	var/key = md5("[species]|[gender]|[body_build]|[s_tone]|[r_skin],[g_skin],[b_skin]|[r_eyes],[g_eyes],[b_eyes]|[h_style]|[r_hair],[g_hair],[b_hair]|[f_style]|[r_facial],[g_facial],[b_facial]")
	if (key != preview_key || !preview_icons.len)
		update_preview_icons()
		preview_key = key
	. = list()
	var/list/labels = list("Body", "Clothed")
	for (var/v = 1 to preview_icons.len)
		var/list/views = list("label" = v <= labels.len ? labels[v] : "View [v]")
		var/list/sides = list("front" = preview_icons_front, "east" = preview_icons_east, "back" = preview_icons_back, "west" = preview_icons_west)
		for (var/side in sides)
			var/list/icons = sides[side]
			if (v > icons.len || !isicon(icons[v]))
				continue
			var/file_name = "setup_[copytext(key, 1, 13)]_[v]_[side].png"
			user << browse_rsc(icons[v], file_name)
			views[side] = file_name
		. += list(views)

/datum/preferences/proc/setup_colors(list/named)
	. = list()
	for (var/color_name in named)
		. += list(list("name" = color_name, "hex" = named[color_name]))

// RGB drives both the preview and the character. Stored labels can be stale
// after randomisation or loading old preferences.
/datum/preferences/proc/setup_color_name(list/named, red, green, blue)
	var/actual = lowertext(rgb(red, green, blue))
	for (var/color_name in named)
		if (lowertext(named[color_name]) == actual)
			return color_name
	return null

/datum/preferences/proc/character_setup_data(mob/user)
	var/list/data = list()
	var/locked = setup_locked(user)
	var/datum/species/S = setup_species()
	data["locked"] = locked
	data["notice"] = setup_notice
	// The Game Menu's "Controls and HUD" entry opens straight on Settings.
	if (setup_open_tab)
		data["tab"] = setup_open_tab

	var/list/character = list()
	character["name"] = real_name
	character["name_max"] = MAX_NAME_LEN
	character["random_name"] = be_random_name
	character["random_body"] = be_random_body
	character["summary"] = "[capitalize(age2agedescription(age))], [skintone2racedescription(s_tone)], [gender]."
	character["gender"] = gender
	character["age"] = age
	character["age_min"] = S ? S.min_age : 18
	character["age_max"] = S ? S.max_age : 80
	character["blood"] = b_type
	character["blood_types"] = valid_bloodtypes
	if (S && (S.appearance_flags & HAS_SKIN_TONE))
		character["skin_tone"] = 35 - s_tone
	character["hair_style"] = h_style
	character["hair_styles"] = setup_hair_styles()
	character["facial_style"] = f_style
	character["facial_styles"] = setup_facial_styles()
	if (S && (S.appearance_flags & HAS_HAIR_COLOR))
		character["hair_color"] = setup_color_name(hair_colors, r_hair, g_hair, b_hair)
		character["facial_color"] = setup_color_name(hair_colors, r_facial, g_facial, b_facial)
		character["hair_colors"] = setup_colors(hair_colors)
	if (S && (S.appearance_flags & HAS_EYE_COLOR))
		character["eye_color"] = setup_color_name(eye_colors, r_eyes, g_eyes, b_eyes)
		character["eye_colors"] = setup_colors(eye_colors)
	if (!locked)
		character["previews"] = setup_previews(user)
	data["character"] = character

	data["traits"] = trait_setup_data()
	data["chart"] = birth_chart_setup_data(user)

	var/list/settings = list()
	settings["ui_style"] = UI_style
	settings["ui_styles"] = all_ui_styles
	var/list/cursors = setup_cursors()
	settings["cursor"] = "Default"
	for (var/cursor_name in cursors)
		if (cursors[cursor_name] == cursor)
			settings["cursor"] = cursor_name
	var/list/cursor_names = list()
	for (var/cursor_name in cursors)
		cursor_names += cursor_name
	settings["cursors"] = cursor_names
	settings["client_fps"] = client_fps
	settings["fps_choices"] = client_fps_choices()
	if (client)
		settings["tutorial"] = client.tutorial_status_text()
	// Controls and HUD: the same settings as the OOC verbs.
	settings["tap_step"] = tap_step ? 1 : 0
	settings["hover_text"] = hover_text_enabled ? (hover_text_bottom ? 2 : 1) : 0
	var/list/scales = list()
	settings["hud_scale"] = "100%"
	settings["hover_text_scale"] = "100%"
	for (var/label in hud_scale_choices)
		scales += label
		if (hud_scale_choices[label] == hud_scale)
			settings["hud_scale"] = label
		if (hud_scale_choices[label] == hover_text_scale)
			settings["hover_text_scale"] = label
	settings["scales"] = scales
	settings["hud_editing"] = (client && client.hud_edit_mode) ? 1 : 0
	var/list/toggles = list()
	for (var/cp in get_client_preferences())
		var/datum/client_preference/client_pref = cp
		if (!client_pref.may_toggle(user))
			continue
		toggles += list(list("key" = client_pref.key, "label" = client_pref.description, "on" = (client_pref.key in preferences_enabled) ? 1 : 0,
			"on_label" = client_pref.enabled_description, "off_label" = client_pref.disabled_description))
	settings["toggles"] = toggles
	data["settings"] = settings
	return data

// The picker's view of the chosen traits: every known trait in its category
// with what taking it would cost and what stands in its way.
/datum/preferences/proc/trait_setup_data()
	var/list/data = list()
	var/list/chosen = islist(traits) ? traits : list()
	var/spent = 0
	var/earned = 0
	var/list/taken = list()
	var/list/invalid = list()
	for (var/choice in chosen)
		if (!istext(choice) || !(choice in trait_list) || (choice in taken))
			invalid += "[choice]"
			continue
		taken += choice
		var/cost = trait_list[choice][1]
		if (cost > 0)
			spent += cost
		else
			earned -= cost
	if (!islist(traits))
		invalid += "Unreadable saved traits"
	data["spent"] = spent
	data["earned"] = earned
	data["chosen"] = taken
	data["invalid"] = invalid
	data["error"] = get_trait_selection_error(traits)

	// Catalog order first, so paired traits sit side by side; the rest follow.
	var/list/ordered = list()
	for (var/category in trait_category_members)
		for (var/member in trait_category_members[category])
			if (member in trait_list)
				ordered += member
	for (var/trait_name in trait_list)
		if (!(trait_name in ordered))
			ordered += trait_name
	var/list/by_category = list()
	for (var/trait_name in ordered)
		var/list/definition = trait_list[trait_name]
		var/category = trait_category_id(trait_name)
		var/list/conflicts = list()
		for (var/other in taken)
			if (other == trait_name)
				continue
			if ((other in definition[2]) || (trait_name in trait_list[other][2]))
				conflicts += other
		var/is_taken = (trait_name in taken)
		var/list/entry = list("name" = trait_name, "cost" = definition[1], "desc" = definition[3], "taken" = is_taken ? 1 : 0, "conflicts" = conflicts)
		if (trait_notes[trait_name])
			entry["note"] = trait_notes[trait_name]
		var/block = trait_change_block(trait_name, !is_taken)
		if (block)
			entry["block"] = block
		if (!by_category[category])
			by_category[category] = list()
		by_category[category] += list(entry)
	var/list/categories = list()
	for (var/list/category in trait_categories)
		var/list/members = by_category[category["id"]]
		if (!members || !members.len)
			continue
		categories += list(list("id" = category["id"], "title" = category["title"], "note" = category["note"], "pick_one" = category["pick_one"] ? 1 : 0, "traits" = members))
	data["categories"] = categories
	return data

// Adds one trait. replace = TRUE first drops the chosen traits it cannot be
// combined with. The budget is not checked here: a perk may be taken before
// the drawback that pays for it, and an unbalanced set cannot join a round.
/datum/preferences/proc/setup_add_trait(trait_name, replace = FALSE)
	if (!istext(trait_name) || !(trait_name in trait_list) || !islist(traits) || (trait_name in traits))
		return FALSE
	if (trait_change_block(trait_name, TRUE))
		return FALSE
	var/list/candidate = traits.Copy()
	if (replace)
		for (var/other in traits)
			if (!istext(other) || !(other in trait_list))
				continue
			if ((other in trait_list[trait_name][2]) || (trait_name in trait_list[other][2]))
				if (trait_change_block(other, FALSE))
					return FALSE
				candidate -= other
	candidate += trait_name
	if (get_trait_selection_error(candidate, FALSE))
		return FALSE
	traits = candidate
	return TRUE

/datum/preferences/proc/setup_remove_trait(trait_name)
	if (!islist(traits) || !(trait_name in traits) || trait_change_block(trait_name, FALSE))
		return FALSE
	// Every copy goes, so a repeated saved entry is cleared in one press.
	var/list/kept = list()
	for (var/choice in traits)
		if (choice != trait_name)
			kept += choice
	traits = kept
	return TRUE

// Drops everything that may be dropped, including entries no longer known.
/datum/preferences/proc/setup_clear_traits()
	var/list/kept = list()
	if (islist(traits))
		for (var/choice in traits)
			if (istext(choice) && (choice in trait_list) && !(choice in kept) && trait_change_block(choice, FALSE))
				kept += choice
	traits = kept
	return TRUE

/datum/preferences/proc/setup_named_color(list/named, picked, part)
	var/hex = istext(picked) ? named[picked] : null
	if (!hex)
		return FALSE
	vars["[part]_color"] = picked
	var/suffix = part == "eye" ? "eyes" : part
	vars["r_[suffix]"] = hex2num(copytext(hex, 2, 4))
	vars["g_[suffix]"] = hex2num(copytext(hex, 4, 6))
	vars["b_[suffix]"] = hex2num(copytext(hex, 6, 8))
	return TRUE

/datum/preferences/ui_act(action, list/params, mob/user, datum/nanoui/ui)
	. = TRUE
	if (!user || !user.client || user.client.prefs != src)
		return
	var/value = params["value"]
	setup_notice = null
	if (setup_settings_act(action, value, user))
		return
	if (setup_locked(user))
		return
	var/datum/species/S = setup_species()
	switch (action)
		if ("name")
			var/new_name = istext(value) ? sanitize_name(copytext(value, 1, MAX_NAME_LEN + 1), species) : null
			if (new_name)
				real_name = new_name
			else
				setup_notice = "A name is 2 to [MAX_NAME_LEN] letters. It may also hold spaces, hyphens, apostrophes and full stops."
		if ("random_name")
			real_name = random_name(gender, species)
		if ("always_random_name")
			be_random_name = value ? TRUE : FALSE
		if ("gender")
			if (value == MALE || value == FEMALE)
				gender = value
				if (gender == FEMALE)
					f_style = "Shaved"
		if ("age")
			if (isnum(value) && S)
				age = max(min(round(value), S.max_age), S.min_age)
		if ("blood")
			if (value in valid_bloodtypes)
				b_type = value
		if ("skin_tone")
			if (isnum(value) && S && (S.appearance_flags & HAS_SKIN_TONE))
				s_tone = 35 - max(min(round(value), 220), 1)
		if ("hair_style")
			if (value in setup_hair_styles())
				h_style = value
		if ("facial_style")
			if (value in setup_facial_styles())
				f_style = value
		if ("hair_color")
			if (S && (S.appearance_flags & HAS_HAIR_COLOR))
				setup_named_color(hair_colors, value, "hair")
		if ("facial_color")
			if (S && (S.appearance_flags & HAS_HAIR_COLOR))
				setup_named_color(hair_colors, value, "facial")
		if ("eye_color")
			if (S && (S.appearance_flags & HAS_EYE_COLOR))
				setup_named_color(eye_colors, value, "eye")
		if ("randomize")
			randomize_appearance_for()
		if ("always_random_body")
			be_random_body = value ? TRUE : FALSE
		if ("trait_add")
			setup_add_trait(value)
		if ("trait_swap")
			setup_add_trait(value, TRUE)
		if ("trait_remove")
			setup_remove_trait(value)
		if ("trait_clear")
			setup_clear_traits()
		if ("birth_chart")
			setup_birth_chart(value, user)
		if ("trait_random")
			var/list/candidate = random_zero_point_traits()
			if (!islist(candidate) || !candidate.len || get_trait_selection_error(candidate) || check_trait_points(candidate) != 0)
				setup_notice = "No balanced set came up this time. Your traits are unchanged."
			else
				var/blocked = FALSE
				for (var/choice in candidate)
					if (!(choice in traits) && trait_change_block(choice, TRUE))
						blocked = TRUE
				if (islist(traits))
					for (var/choice in traits)
						if (!(choice in candidate) && istext(choice) && trait_change_block(choice, FALSE))
							blocked = TRUE
				if (blocked)
					setup_notice = "A trait you cannot change yet stood in the way. Your traits are unchanged."
				else
					traits = candidate
	player_setup.sanitize_setup()
	save_preferences()

// Settings stay open to a living character. Returns TRUE when the action was one of them.
/datum/preferences/proc/setup_settings_act(action, value, mob/user)
	switch (action)
		if ("ui_style")
			if (value in all_ui_styles)
				UI_style = value
				save_preferences()
			return TRUE
		if ("cursor")
			var/list/cursors = setup_cursors()
			if (value in cursors)
				cursor = cursors[value]
				save_preferences()
			return TRUE
		if ("client_fps")
			if (isnum(value) && (value in client_fps_choices()))
				client_fps = value
				user.client.apply_client_fps_preference()
				save_preferences()
			return TRUE
		if ("reset_tutorial")
			user.client.reset_tutorial()
			return TRUE
		if ("tap_step")
			user.client.set_tap_step(value ? TRUE : FALSE)
			return TRUE
		if ("hover_text")
			value = text2num("[value]")
			if (value in list(0, 1, 2))
				user.client.set_hover_text_mode(value)
			return TRUE
		if ("hover_text_scale")
			if (value in hud_scale_choices)
				hover_text_scale = hud_scale_choices[value]
				save_preferences()
			return TRUE
		if ("hud_scale")
			if (value in hud_scale_choices)
				hud_scale = hud_scale_choices[value]
				save_preferences()
				if (ishuman(user))
					var/mob/living/human/H = user
					H.apply_hud_layout()
			return TRUE
		if ("edit_hud_layout")
			user.client.edit_hud_layout()
			return TRUE
		if ("reset_hud_layout")
			user.client.reset_hud_layout()
			return TRUE
		if ("keybindings")
			user.client.configure_action_keybindings()
			return TRUE
		// Verifying is open to a living character; the prompt comes from the verb.
		if ("verify_discord")
			user.client.verify_discord()
			return TRUE
		if ("toggle_on", "toggle_off")
			var/datum/client_preference/client_pref = istext(value) ? get_client_preference_by_key(value) : null
			if (client_pref && client_pref.may_toggle(user))
				user.set_preference(client_pref.key, action == "toggle_on")
			return TRUE
	return FALSE

// The tab the next opened setup window starts on (escape_menu.dm).
/datum/preferences/var/tmp/setup_open_tab = null
