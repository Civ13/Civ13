/datum/preferences

/datum/category_item/player_setup_item/general/basic
	name = "Basic"
	sort_order = 1

/datum/category_item/player_setup_item/general/basic/sanitize_character()
	var/list/valid_player_genders = list(MALE, FEMALE)
	var/datum/species/S = all_species[pref.species ? pref.species : "Human"]
	pref.age			= sanitize_integer(pref.age, S.min_age, S.max_age, initial(pref.age))
	pref.gender 		= sanitize_inlist(pref.gender, valid_player_genders, pick(valid_player_genders))
	pref.real_name		= sanitize_name(pref.real_name, pref.species)

	if (!pref.real_name)
		pref.real_name	= random_name(pref.gender, pref.species)

	/*										*/

/datum/category_item/player_setup_item/general/basic/content(var/mob/user)
	pref.update_preview_icons()
	. = "<b>UI Style: </b><a href='?src=\ref[src];select_style=1'><b>[pref.UI_style]</b></A><br><br>"
	var/currcursor = "Default"
	if (pref.cursor == 'icons/effects/red_cursors.dmi')
		currcursor = "Red Crosshair"

	else if (pref.cursor == 'icons/effects/white_cursors.dmi')
		currcursor = "White Crosshair"

	else if (pref.cursor == 'icons/effects/green_cursors.dmi')
		currcursor = "Green Crosshair"
	else
		currcursor = "Default"
	. += "<b>Cursor Style: </b><a href='?src=\ref[src];select_cursor=1'><b>[currcursor]</b></A><br><br>"
	if (ishuman(user) && user.stat != DEAD)
		. += "<br>"
	else
		for (var/v in TRUE to pref.preview_icons.len)
			if (isicon(pref.preview_icons_front[v]))
				user << browse_rsc(pref.preview_icons_front[v], "previewicon_[v]_front.png")
			#ifndef OPENDREAM
				if (isicon(pref.preview_icons_back[v]))
					user << browse_rsc(pref.preview_icons_back[v], "previewicon_[v]_back.png")
				if (isicon(pref.preview_icons_east[v]))
					user << browse_rsc(pref.preview_icons_east[v], "previewicon_[v]_east.png")
				if (isicon(pref.preview_icons_west[v]))
					user << browse_rsc(pref.preview_icons_west[v], "previewicon_[v]_west.png")
			#endif
		. += "<b>Preview</b><br>"

		for (var/v in TRUE to pref.preview_icons.len)
			#ifndef OPENDREAM
			. += "<img src=previewicon_[v]_front.png height=64 width=64>"
			. += "<img src=previewicon_[v]_back.png height=64 width=64>"
			. += "<img src=previewicon_[v]_east.png height=64 width=64>"
			. += "<img src=previewicon_[v]_west.png height=64 width=64>"
			#endif
			#ifdef OPENDREAM
			. += "<img src=previewicon_[v]_front.png height=64 width=256>"
			#endif
			. += "<br><br>"
		// name
		. += "<b>Name:</b> "
		. += "<a href='?src=\ref[src];rename=1'><b>[pref.real_name]</b></a><br><br>"
		. += "(<a href='?src=\ref[src];random_name=1'>Randomize Name</a>)<br><br>"
		. += "<b>Always Randomize Name:</b> <a href='?src=\ref[src];always_random_name=1'>[pref.be_random_name ? "Yes" : "No"]</a><br><br>"
		. += "<b>Traits: ([check_trait_points(pref.traits)])</b><br>"
		. += "<i>(The sum of trait values has to be less or equal to <b>0</b>)</i><br>"
		. += "<a href='?src=\ref[src];add_traits=1'>Add</a> <a href='?src=\ref[src];remove_traits=1'>Remove</a><br><br>"
		var/trait_error = get_trait_selection_error(pref.traits)
		if (trait_error)
			. += "<b>[html_encode(trait_error)]</b><br>Saved choices are preserved until you remove them.<br>"
		if (islist(pref.traits))
			for (var/choice in pref.traits)
				var/list/definition = istext(choice) ? trait_list[choice] : null
				var/cost_label = definition ? "[definition[1]]" : "unknown"
				. += "[html_encode("[choice]")] ([cost_label])<br>"

/datum/category_item/player_setup_item/general/basic/OnTopic(var/href,var/list/href_list, var/mob/user)

	//real names
	if (href_list["rename"])
		var/raw_name = input(user, "Choose your character's name:", "Character Name")  as text|null
		if (!isnull(raw_name) && CanUseTopic(user))
			var/new_name = sanitize_name(raw_name, pref.species)
			if (new_name)
				pref.real_name = new_name
				return TOPIC_REFRESH
			else
				to_chat(user, "<span class='warning'>Invalid name. Your name should be at least 2 and at most [MAX_NAME_LEN] characters long. It may only contain the characters A-Z, a-z, -, ' and .</span>")
				return TOPIC_NOACTION

	else if (href_list["random_name"])
		pref.real_name = random_name(pref.gender, pref.species)
		return TOPIC_REFRESH

	else if (href_list["always_random_name"])
		pref.be_random_name = !pref.be_random_name
		return TOPIC_REFRESH

	else if (href_list["select_style"])
		var/UI_style_new = input(user, "Choose UI style:", "UI Style", pref.UI_style) as null|anything in all_ui_styles
		if (!UI_style_new || !CanUseTopic(user)) return TOPIC_NOACTION
		pref.UI_style = UI_style_new
		pref.save_preferences()
		return TOPIC_REFRESH

	else if (href_list["select_cursor"])
		var/cursor_new = WWinput(usr, "Choose Cursor Style:", "Mouse Cursor", "Default", list("Default","Red Crosshair","Green Crosshair","White Crosshair"))
		if (cursor_new == "Default")
			pref.cursor = null
		else if (cursor_new == "Red Crosshair")
			pref.cursor = 'icons/effects/red_cursors.dmi'
		else if (cursor_new == "White Crosshair")
			pref.cursor = 'icons/effects/white_cursors.dmi'
		else if (cursor_new == "Green Crosshair")
			pref.cursor = 'icons/effects/green_cursors.dmi'
		else
			pref.cursor = null
		pref.save_preferences()
		return TOPIC_REFRESH

	else if (href_list["add_traits"])
		var/trait_error = get_trait_selection_error(pref.traits, FALSE)
		if (trait_error)
			WWalert(user, trait_error, "Traits")
			return TOPIC_REFRESH
		var/list/possible = list("Cancel")
		for (var/choice in trait_list)
			var/list/candidate = pref.traits.Copy()
			candidate += choice
			if (!get_trait_selection_error(candidate, FALSE))
				possible["[choice] ([trait_list[choice][1]])"] = choice
		var/add = WWinput(user, "Add Trait:", "Traits", "Cancel", possible)
		if (!add || add == "Cancel" || !CanUseTopic(user) || !(add in possible))
			return TOPIC_REFRESH
		var/choice = possible[add]
		if (alert(user, "[trait_list[choice][3]]", choice, "Add", "Cancel") != "Add" || !CanUseTopic(user))
			return TOPIC_REFRESH
		// Both prompts can yield: rebuild from current choices before committing.
		if (!islist(pref.traits))
			return TOPIC_REFRESH
		var/list/candidate = pref.traits.Copy()
		candidate += choice
		trait_error = get_trait_selection_error(candidate, FALSE)
		if (trait_error)
			WWalert(user, trait_error, "Traits")
			return TOPIC_REFRESH
		pref.traits = candidate
		pref.save_preferences()
		return TOPIC_REFRESH

	else if (href_list["remove_traits"])
		if (!islist(pref.traits))
			if (alert(user, "Clear invalid trait data? This removes the saved malformed trait value.", "Traits", "Clear", "Cancel") == "Clear" && CanUseTopic(user) && !islist(pref.traits))
				pref.traits = list()
				pref.save_preferences()
			return TOPIC_REFRESH
		// Number entries so duplicate and unknown legacy choices can be removed individually.
		var/list/snapshot = pref.traits.Copy()
		var/list/possible = list("Cancel")
		for (var/i = 1, i <= snapshot.len, i++)
			possible["[i]: [snapshot[i]]"] = i
		var/remove = WWinput(user, "Remove Trait:", "Traits", "Cancel", possible)
		if (!remove || remove == "Cancel" || !CanUseTopic(user) || !(remove in possible) || !islist(pref.traits))
			return TOPIC_REFRESH
		// Refuse stale removal rather than remove a different choice after another edit.
		if (snapshot.len != pref.traits.len)
			return TOPIC_REFRESH
		for (var/i = 1, i <= snapshot.len, i++)
			if (snapshot[i] != pref.traits[i])
				return TOPIC_REFRESH
		var/index = possible[remove]
		pref.traits.Cut(index, index + 1)
		pref.save_preferences()
		return TOPIC_REFRESH

	return ..()
/proc/check_trait_points(var/list/traitlist = list())
	if (!islist(traitlist) || !traitlist.len)
		return 0
	var/count = 0
	for (var/i in traitlist)
		if (istext(i) && trait_list[i] && trait_list[i][1]!=0)
			count += trait_list[i][1]
	return count
