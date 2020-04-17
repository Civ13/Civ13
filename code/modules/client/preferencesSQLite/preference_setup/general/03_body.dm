var/global/list/valid_bloodtypes = list("A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-")

/datum/category_item/player_setup_item/general/body
	name = "Body"
	sort_order = 3

/datum/category_item/player_setup_item/general/body/sanitize_character()
	if (!pref.species || !(pref.species in playable_species))
		pref.species = "Human"
	pref.r_hair			= sanitize_integer(pref.r_hair, FALSE, 255, initial(pref.r_hair))
	pref.g_hair			= sanitize_integer(pref.g_hair, FALSE, 255, initial(pref.g_hair))
	pref.b_hair			= sanitize_integer(pref.b_hair, FALSE, 255, initial(pref.b_hair))
	pref.r_facial		= sanitize_integer(pref.r_facial, FALSE, 255, initial(pref.r_facial))
	pref.g_facial		= sanitize_integer(pref.g_facial, FALSE, 255, initial(pref.g_facial))
	pref.b_facial		= sanitize_integer(pref.b_facial, FALSE, 255, initial(pref.b_facial))
	pref.s_tone			= sanitize_integer(pref.s_tone, -185, 34, initial(pref.s_tone))
	pref.r_skin			= sanitize_integer(pref.r_skin, FALSE, 255, initial(pref.r_skin))
	pref.g_skin			= sanitize_integer(pref.g_skin, FALSE, 255, initial(pref.g_skin))
	pref.b_skin			= sanitize_integer(pref.b_skin, FALSE, 255, initial(pref.b_skin))
	pref.h_style		= sanitize_inlist(pref.h_style, hair_styles_list, initial(pref.h_style))
	pref.f_style		= sanitize_inlist(pref.f_style, facial_hair_styles_list, initial(pref.f_style))
	pref.r_eyes			= sanitize_integer(pref.r_eyes, FALSE, 255, initial(pref.r_eyes))
	pref.g_eyes			= sanitize_integer(pref.g_eyes, FALSE, 255, initial(pref.g_eyes))
	pref.b_eyes			= sanitize_integer(pref.b_eyes, FALSE, 255, initial(pref.b_eyes))
	pref.b_type			= sanitize_text(pref.b_type, initial(pref.b_type))


/datum/category_item/player_setup_item/general/body/content(var/mob/user)
	if (ishuman(user) && user.stat != DEAD)
		. += "<center><font size='5' color='red'><b>YOU CAN'T CHANGE YOUR CHARACTER PREFERENCES WHILE PLAYING!</b></font><br><br>"
		. += "<font size='2' color='red'>Come back after your character dies.</font></center>"
	else
		var/mob_species = all_species[pref.species]
		. += "<table><tr style='vertical-align:top'><td>"
		. += "<b>You are a [age2agedescription(pref.age)] [skintone2racedescription(pref.s_tone)] [pref.gender].</b><br><br>"
		. += "<b>Gender:</b> <a href='?src=\ref[src];gender=1'>[capitalize(lowertext(pref.gender))]</a><br>"
		. += "<b>Age:</b> <a href='?src=\ref[src];age=1'>[pref.age]</a><br>"
		. += "<b>Blood Type: </b><a href='?src=\ref[src];blood_type=1'>[pref.b_type]</a><br>"
		if (has_flag(mob_species, HAS_SKIN_TONE))
			. += "<b>Skin Tone: </b><a href='?src=\ref[src];skin_tone=1'>[-pref.s_tone + 35]/220</a><br>"
		. += "<br>"
		. += "<font face='fixedsys' size='3' color='[hair_colors[pref.hair_color]]'><table style='display:inline;' bgcolor='[hair_colors[pref.hair_color]]'><tr><td><font color='[hair_colors[pref.hair_color]]'>__</font></td></tr></table></font>&nbsp;<b>Hair</b><br>"
		if (has_flag(mob_species, HAS_HAIR_COLOR))
			. += "<b>Color:</b> <a href='?src=\ref[src];hair_color=1'>[pref.hair_color]</a>"
		. += "<br><b>Style:</b> <a href='?src=\ref[src];hair_style=1'>[pref.h_style]</a><br>"

		. += "<br><font face='fixedsys' size='3' color='[hair_colors[pref.facial_color]]'><table  style='display:inline;' bgcolor='[hair_colors[pref.facial_color]]'><tr><td><font color='[hair_colors[pref.facial_color]]'>__</font></td></tr></table></font>&nbsp;<b>Facial Hair</b><br>"
		if (has_flag(mob_species, HAS_HAIR_COLOR))
			. += "<b>Color:</b> <a href='?src=\ref[src];facial_color=1'>[pref.facial_color]</a>"
		. += "<br><b>Style:</b> <a href='?src=\ref[src];facial_style=1'>[pref.f_style]</a><br>"

		if (has_flag(mob_species, HAS_EYE_COLOR))
			. += "<br><font face='fixedsys' size='3' color='[eye_colors[pref.eye_color]]'><table  style='display:inline;' bgcolor='[eye_colors[pref.eye_color]]'><tr><td><font color='[eye_colors[pref.eye_color]]'>__</font></td></tr></table></font>&nbsp;<b>Eyes</b><br>"
			. += "<b>Color:</b> <a href='?src=\ref[src];eye_color=1'>[pref.eye_color]</a>"
		. += "<br><br>"
		. += "(<a href='?src=\ref[src];random=1'>Randomize</A>)<br><br>"
		. += "<b>Always Randomize Body:</b> <a href='?src=\ref[src];always_random_body=1'>[pref.be_random_body ? "Yes" : "No"]</a>"
/datum/category_item/player_setup_item/general/body/proc/has_flag(var/datum/species/mob_species, var/flag)
	return mob_species && (mob_species.appearance_flags & flag)

/datum/category_item/player_setup_item/general/body/OnTopic(var/href,var/list/href_list, var/mob/user)
	var/datum/species/mob_species = all_species[pref.species]
	var/list/valid_player_genders = list(MALE, FEMALE)
	if (href_list["random"])
		pref.randomize_appearance_for ()
		return TOPIC_REFRESH

	else if (href_list["blood_type"])
		var/new_b_type = input(user, "Choose your character's blood-type:", "Character Preference") as null|anything in valid_bloodtypes
		if (new_b_type && CanUseTopic(user))
			pref.b_type = new_b_type
			return TOPIC_REFRESH

	else if (href_list["hair_color"])
		if (!has_flag(mob_species, HAS_HAIR_COLOR))
			return TOPIC_NOACTION
		var/new_hair = input(user, "Choose your character's hair color:", "Hair Color") in hair_colors + "Cancel"
		if (new_hair == "Cancel")
			return
		pref.hair_color = new_hair
		var/hex_hair = hair_colors[new_hair]
		pref.r_hair = hex2num(copytext(hex_hair, 2, 4))
		pref.g_hair = hex2num(copytext(hex_hair, 4, 6))
		pref.b_hair = hex2num(copytext(hex_hair, 6, 8))
		return TOPIC_REFRESH

	else if (href_list["hair_style"])
		var/list/valid_hairstyles = list()
		for (var/hairstyle in hair_styles_list)
			var/datum/sprite_accessory/S = hair_styles_list[hairstyle]
			if (!(mob_species.get_bodytype() in S.species_allowed))
				continue

			valid_hairstyles[hairstyle] = hair_styles_list[hairstyle]

		var/new_h_style = input(user, "Choose your character's hair style:", "Character Preference", pref.h_style)  as null|anything in valid_hairstyles
		if (new_h_style && CanUseTopic(user))
			pref.h_style = new_h_style
			return TOPIC_REFRESH

	else if (href_list["facial_color"])
		if (!has_flag(mob_species, HAS_HAIR_COLOR))
			return TOPIC_NOACTION
		var/new_hair = input(user, "Choose your character's facial-hair color:", "Facial Hair Color") in hair_colors + "Cancel"
		if (new_hair == "Cancel")
			return
		pref.facial_color = new_hair
		var/hex_hair = hair_colors[new_hair]
		pref.r_facial = hex2num(copytext(hex_hair, 2, 4))
		pref.g_facial = hex2num(copytext(hex_hair, 4, 6))
		pref.b_facial = hex2num(copytext(hex_hair, 6, 8))
		return TOPIC_REFRESH

	else if (href_list["eye_color"])
		if (!has_flag(mob_species, HAS_EYE_COLOR))
			return TOPIC_NOACTION
		var/new_eyes = input(user, "Choose your character's eye color:", "Eye Color") in eye_colors + "Cancel"
		if (new_eyes == "Cancel")
			return
		pref.eye_color = new_eyes
		if (new_eyes && has_flag(mob_species, HAS_EYE_COLOR) && CanUseTopic(user))
			var/hex_eyes = eye_colors[new_eyes]
			pref.r_eyes = hex2num(copytext(hex_eyes, 2, 4))
			pref.g_eyes = hex2num(copytext(hex_eyes, 4, 6))
			pref.b_eyes = hex2num(copytext(hex_eyes, 6, 8))
			return TOPIC_REFRESH

	else if (href_list["skin_tone"])
		if (!has_flag(mob_species, HAS_SKIN_TONE))
			return TOPIC_NOACTION
		var/new_s_tone = input(user, "Choose your character's skin-tone:\n(Light TRUE - 220 Dark)", "Character Preference", (-pref.s_tone) + 35)  as num|null
		if (new_s_tone && has_flag(mob_species, HAS_SKIN_TONE) && CanUseTopic(user))
			pref.s_tone = 35 - max(min( round(new_s_tone), 220),1)
			return TOPIC_REFRESH

	else if (href_list["skin_color"])
		if (!has_flag(mob_species, HAS_SKIN_COLOR))
			return TOPIC_NOACTION
		var/new_skin = input(user, "Choose your character's skin color: ", "Character Preference", rgb(pref.r_skin, pref.g_skin, pref.b_skin)) as color|null
		if (new_skin && has_flag(mob_species, HAS_SKIN_COLOR) && CanUseTopic(user))
			pref.r_skin = hex2num(copytext(new_skin, 2, 4))
			pref.g_skin = hex2num(copytext(new_skin, 4, 6))
			pref.b_skin = hex2num(copytext(new_skin, 6, 8))
			return TOPIC_REFRESH

	else if (href_list["facial_style"])
		var/list/valid_facialhairstyles = list()
		for (var/facialhairstyle in facial_hair_styles_list)
			var/datum/sprite_accessory/S = facial_hair_styles_list[facialhairstyle]
			if (pref.gender == MALE && S.gender == FEMALE)
				continue
			if (pref.gender == FEMALE && S.gender == MALE)
				continue
			if (!(mob_species.get_bodytype() in S.species_allowed))
				continue

			valid_facialhairstyles[facialhairstyle] = facial_hair_styles_list[facialhairstyle]

		var/new_f_style = input(user, "Choose your character's facial-hair style:", "Character Preference", pref.f_style)  as null|anything in valid_facialhairstyles
		if (new_f_style && has_flag(mob_species, HAS_HAIR_COLOR) && CanUseTopic(user))
			pref.f_style = new_f_style
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

	else if (href_list["always_random_body"])
		pref.be_random_body = !pref.be_random_body
		return TOPIC_REFRESH
	return ..()