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

	pref.disabilities	= sanitize_integer(pref.disabilities, FALSE, 65535, initial(pref.disabilities))
	if (!pref.organ_data) pref.organ_data = list()
	if (!pref.rlimb_data) pref.rlimb_data = list()

/datum/category_item/player_setup_item/general/body/content(var/mob/user)
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

	var/mob_species = all_species[pref.species]
	. += "<table><tr style='vertical-align:top'><td><b>Body</b> "
	. += "(<a href='?src=\ref[src];random=1'>&reg;</A>)"
	. += "<br>"
	. += "Blood Type: <a href='?src=\ref[src];blood_type=1'>[pref.b_type]</a><br>"
	if (has_flag(mob_species, HAS_SKIN_TONE))
		. += "Skin Tone: <a href='?src=\ref[src];skin_tone=1'>[-pref.s_tone + 35]/220</a><br>"
	. += "Needs Glasses: <a href='?src=\ref[src];disabilities=[NEARSIGHTED]'><b>[pref.disabilities & NEARSIGHTED ? "Yes" : "No"]</b></a><br>"
	//. += "Limbs: <a href='?src=\ref[src];limbs=1'>Adjust</a><br>"
	// . += "Internal Organs: <a href='?src=\ref[src];organs=1'>Adjust</a><br>"

	//display limbs below
	var/ind = FALSE
	for (var/name in pref.organ_data)
		var/status = pref.organ_data[name]
		var/organ_name = null
		switch(name)
			if ("l_arm")
				organ_name = "left arm"
			if ("r_arm")
				organ_name = "right arm"
			if ("l_leg")
				organ_name = "left leg"
			if ("r_leg")
				organ_name = "right leg"
			if ("l_foot")
				organ_name = "left foot"
			if ("r_foot")
				organ_name = "right foot"
			if ("l_hand")
				organ_name = "left hand"
			if ("r_hand")
				organ_name = "right hand"
			if ("heart")
				organ_name = "heart"
			if ("eyes")
				organ_name = "eyes"

		if (status == "amputated")
			++ind
			if (ind > 1)
				. += ", "
			. += "\tAmputated [organ_name]"
		else if (status == "assisted")
			++ind
			if (ind > 1)
				. += ", "
			switch(organ_name)
				if ("heart")
					. += "\tPacemaker-assisted [organ_name]"
				if ("voicebox") //on adding voiceboxes for speaking skrell/similar replacements
					. += "\tSurgically altered [organ_name]"
				if ("eyes")
					. += "\tRetinal overlayed [organ_name]"
				else
					. += "\tMechanically assisted [organ_name]"
/*	if (!ind)
		. += "\[...\]<br><br>"
	else
		. += "<br><br>"*/
	. += "<br><br>"

	. += "<b>Preview</b><br>"

	for (var/v in TRUE to pref.preview_icons.len)
		. += "<img src=previewicon_[v]_front.png height=64 width=64>"
		. += "<img src=previewicon_[v]_back.png height=64 width=64>"
		. += "<img src=previewicon_[v]_east.png height=64 width=64>"
		. += "<img src=previewicon_[v]_west.png height=64 width=64>"
		. += "<br>"

	. += "<br>"

	. += "<b>Hair</b><br>"
	if (has_flag(mob_species, HAS_HAIR_COLOR))
		. += "<a href='?src=\ref[src];hair_color=1'>Change Color</a> <font face='fixedsys' size='3' color='#[num2hex(pref.r_hair, 2)][num2hex(pref.g_hair, 2)][num2hex(pref.b_hair, 2)]'><table style='display:inline;' bgcolor='#[num2hex(pref.r_hair, 2)][num2hex(pref.g_hair, 2)][num2hex(pref.b_hair)]'><tr><td>__</td></tr></table></font> "
	. += " Style: <a href='?src=\ref[src];hair_style=1'>[pref.h_style]</a><br>"

	. += "<br><b>Facial</b><br>"
	if (has_flag(mob_species, HAS_HAIR_COLOR))
		. += "<a href='?src=\ref[src];facial_color=1'>Change Color</a> <font face='fixedsys' size='3' color='#[num2hex(pref.r_facial, 2)][num2hex(pref.g_facial, 2)][num2hex(pref.b_facial, 2)]'><table  style='display:inline;' bgcolor='#[num2hex(pref.r_facial, 2)][num2hex(pref.g_facial, 2)][num2hex(pref.b_facial)]'><tr><td>__</td></tr></table></font> "
	. += " Style: <a href='?src=\ref[src];facial_style=1'>[pref.f_style]</a><br>"

	if (has_flag(mob_species, HAS_EYE_COLOR))
		. += "<br><b>Eyes</b><br>"
		. += "<a href='?src=\ref[src];eye_color=1'>Change Color</a> <font face='fixedsys' size='3' color='#[num2hex(pref.r_eyes, 2)][num2hex(pref.g_eyes, 2)][num2hex(pref.b_eyes, 2)]'><table  style='display:inline;' bgcolor='#[num2hex(pref.r_eyes, 2)][num2hex(pref.g_eyes, 2)][num2hex(pref.b_eyes)]'><tr><td>__</td></tr></table></font><br>"

	if (has_flag(mob_species, HAS_SKIN_COLOR))
		. += "<br><b>Body Color</b><br>"
		. += "<a href='?src=\ref[src];skin_color=1'>Change Color</a> <font face='fixedsys' size='3' color='#[num2hex(pref.r_skin, 2)][num2hex(pref.g_skin, 2)][num2hex(pref.b_skin, 2)]'><table style='display:inline;' bgcolor='#[num2hex(pref.r_skin, 2)][num2hex(pref.g_skin, 2)][num2hex(pref.b_skin)]'><tr><td>__</td></tr></table></font><br>"

/datum/category_item/player_setup_item/general/body/proc/has_flag(var/datum/species/mob_species, var/flag)
	return mob_species && (mob_species.appearance_flags & flag)

/datum/category_item/player_setup_item/general/body/OnTopic(var/href,var/list/href_list, var/mob/user)
	var/datum/species/mob_species = all_species[pref.species]

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
		var/new_hair = input(user, "Choose your character's facial-hair color:", "Hair Color") in hair_colors + "Cancel"
		if (new_hair == "Cancel")
			return
		var/hex_hair = hair_colors[new_hair]
		pref.r_facial = hex2num(copytext(hex_hair, 2, 4))
		pref.g_facial = hex2num(copytext(hex_hair, 4, 6))
		pref.b_facial = hex2num(copytext(hex_hair, 6, 8))
		return TOPIC_REFRESH

	else if (href_list["eye_color"])
		if (!has_flag(mob_species, HAS_EYE_COLOR))
			return TOPIC_NOACTION
		var/new_eyes = input(user, "Choose your character's eye colour:", "Character Preference", rgb(pref.r_eyes, pref.g_eyes, pref.b_eyes)) as color|null
		if (new_eyes && has_flag(mob_species, HAS_EYE_COLOR) && CanUseTopic(user))
			pref.r_eyes = hex2num(copytext(new_eyes, 2, 4))
			pref.g_eyes = hex2num(copytext(new_eyes, 4, 6))
			pref.b_eyes = hex2num(copytext(new_eyes, 6, 8))
			return TOPIC_REFRESH

	else if (href_list["skin_tone"])
		if (!has_flag(mob_species, HAS_SKIN_TONE))
			return TOPIC_NOACTION
		var/new_s_tone = input(user, "Choose your character's skin-tone:\n(Light TRUE - 220 Dark)", "Character Preference", (-pref.s_tone) + 35)  as num|null
		if (new_s_tone > 55 && user.client.prefs.current_character_type == GERMAN)
			user << "<span class = 'danger'>This skin is too dark for a German.</span>"
			return
		if (new_s_tone && has_flag(mob_species, HAS_SKIN_TONE) && CanUseTopic(user))
			pref.s_tone = 35 - max(min( round(new_s_tone), 220),1)
			return TOPIC_REFRESH

	else if (href_list["skin_color"])
		if (!has_flag(mob_species, HAS_SKIN_COLOR))
			return TOPIC_NOACTION
		var/new_skin = input(user, "Choose your character's skin colour: ", "Character Preference", rgb(pref.r_skin, pref.g_skin, pref.b_skin)) as color|null
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

	else if (href_list["limbs"])
		var/limb_name = input(user, "Which limb do you want to change?") as null|anything in list("Left Leg","Right Leg","Left Arm","Right Arm","Left Foot","Right Foot","Left Hand","Right Hand")
		if (!limb_name && !CanUseTopic(user)) return TOPIC_NOACTION

		var/limb = null
		var/second_limb = null // if you try to change the arm, the hand should also change
		var/third_limb = null  // if you try to unchange the hand, the arm should also change
		switch(limb_name)
			if ("Left Leg")
				limb = "l_leg"
				second_limb = "l_foot"
			if ("Right Leg")
				limb = "r_leg"
				second_limb = "r_foot"
			if ("Left Arm")
				limb = "l_arm"
				second_limb = "l_hand"
			if ("Right Arm")
				limb = "r_arm"
				second_limb = "r_hand"
			if ("Left Foot")
				limb = "l_foot"
				third_limb = "l_leg"
			if ("Right Foot")
				limb = "r_foot"
				third_limb = "r_leg"
			if ("Left Hand")
				limb = "l_hand"
				third_limb = "l_arm"
			if ("Right Hand")
				limb = "r_hand"
				third_limb = "r_arm"

		var/new_state = input(user, "What state do you wish the limb to be in?") as null|anything in list("Normal","Amputated","Prosthesis")
		if (!new_state && !CanUseTopic(user)) return TOPIC_NOACTION

		switch(new_state)
			if ("Normal")
				pref.organ_data[limb] = null
				pref.rlimb_data[limb] = null
				if (third_limb)
					pref.organ_data[third_limb] = null
					pref.rlimb_data[third_limb] = null
			if ("Amputated")
				pref.organ_data[limb] = "amputated"
				pref.rlimb_data[limb] = null
				if (second_limb)
					pref.organ_data[second_limb] = "amputated"
					pref.rlimb_data[second_limb] = null

		return TOPIC_REFRESH

	else if (href_list["organs"])
		var/organ_name = input(user, "Which internal function do you want to change?") as null|anything in list("Heart", "Eyes")
		if (!organ_name) return

		var/organ = null
		switch(organ_name)
			if ("Heart")
				organ = "heart"
			if ("Eyes")
				organ = "eyes"

		var/new_state = input(user, "What state do you wish the organ to be in?") as null|anything in list("Normal","Assisted","Mechanical")
		if (!new_state) return

		switch(new_state)
			if ("Normal")
				pref.organ_data[organ] = null
		return TOPIC_REFRESH

	else if (href_list["disabilities"])
		var/disability_flag = text2num(href_list["disabilities"])
		pref.disabilities ^= disability_flag
		return TOPIC_REFRESH

	return ..()