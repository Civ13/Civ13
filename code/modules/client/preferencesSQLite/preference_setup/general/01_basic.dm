/datum/preferences
	var/identifying_gender = MALE

/datum/category_item/player_setup_item/general/basic
	name = "Basic"
	sort_order = 1
	var/list/valid_player_genders = list(MALE, FEMALE)
	var/list/valid_second_languages = list(ENGLISH, FRENCH, SPANISH, PORTUGUESE)

datum/preferences/proc/set_biological_gender(var/set_gender)
	gender = set_gender
	identifying_gender = set_gender

/datum/category_item/player_setup_item/general/basic/sanitize_character()

	var/datum/species/S = all_species[pref.species ? pref.species : "Human"]
	pref.age			= sanitize_integer(pref.age, S.min_age, S.max_age, initial(pref.age))
	pref.gender 		= sanitize_inlist(pref.gender, valid_player_genders, pick(valid_player_genders))
	pref.real_name		= sanitize_name(pref.real_name, pref.species)

	if (!pref.real_name)
		pref.real_name	= random_name(pref.gender, pref.species)

	/*										*/

/datum/category_item/player_setup_item/general/basic/content(var/mob/user)
	pref.update_preview_icons()

	for (var/v in TRUE to pref.preview_icons.len)
		if (isicon(pref.preview_icons_front[v]))
			user << browse_rsc(pref.preview_icons_front[v], "previewicon_[v]_front.png")
		if (isicon(pref.preview_icons_back[v]))
			user << browse_rsc(pref.preview_icons_back[v], "previewicon_[v]_back.png")
		if (isicon(pref.preview_icons_east[v]))
			user << browse_rsc(pref.preview_icons_east[v], "previewicon_[v]_east.png")
		if (isicon(pref.preview_icons_west[v]))
			user << browse_rsc(pref.preview_icons_west[v], "previewicon_[v]_west.png")
	. = "<b>Preview</b><br><br>"

	for (var/v in TRUE to pref.preview_icons.len)
		. += "<img src=previewicon_[v]_front.png height=64 width=64>"
		. += "<img src=previewicon_[v]_back.png height=64 width=64>"
		. += "<img src=previewicon_[v]_east.png height=64 width=64>"
		. += "<img src=previewicon_[v]_west.png height=64 width=64>"
		. += "<br><br><br>"
	// name
	. += "<b>Name:</b> "
	. += "<a href='?src=\ref[src];rename=1'><b>[pref.real_name]</b></a><br><br>"
	. += "(<a href='?src=\ref[src];random_name=1'>Random Name</A>) <br><br>"
	. += "(<a href='?src=\ref[src];always_random_name=1'>Always Random Name: [pref.be_random_name ? "Yes" : "No"]</a>)"
	. += "<br><br>"
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
				user << "<span class='warning'>Invalid name. Your name should be at least 2 and at most [MAX_NAME_LEN] characters long. It may only contain the characters A-Z, a-z, -, ' and .</span>"
				return TOPIC_NOACTION

	else if (href_list["random_name"])
		pref.real_name = random_name(pref.gender, pref.species)
		return TOPIC_REFRESH

	else if (href_list["always_random_name"])
		pref.be_random_name = !pref.be_random_name
		return TOPIC_REFRESH

	else if (href_list["gender"])
		pref.gender = next_in_list(pref.gender, valid_player_genders)
		return TOPIC_REFRESH

	else if (href_list["age"])
		var/datum/species/S = all_species[pref.species]
		var/new_age = input(user, "Choose your character's age:\n([S.min_age]-[S.max_age])", "Character Preference", pref.age) as num|null
		if (new_age && CanUseTopic(user))
			pref.age = max(min(round(text2num(new_age)), S.max_age), S.min_age)
			return TOPIC_REFRESH

	return ..()
