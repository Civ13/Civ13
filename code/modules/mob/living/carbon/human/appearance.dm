/mob/living/human/proc/change_appearance(var/flags = APPEARANCE_ALL_HAIR, var/location = src, var/mob/user = src, var/check_species_whitelist = TRUE, var/list/species_whitelist = list(), var/list/species_blacklist = list(), var/datum/topic_state/_state = default_state)
	var/datum/nano_module/appearance_changer/AC = new(location, src, check_species_whitelist, species_whitelist, species_blacklist)
	AC.flags = flags
	AC.ui_interact(user, state = _state)

/mob/living/human/proc/change_species(var/new_species)
	if (!new_species)
		return

	if (species == new_species)
		return

	if (!(new_species in all_species))
		return

	set_species(new_species)
	reset_hair()
	return TRUE

/mob/living/human/proc/change_gender(var/_gender)
	if (gender == _gender)
		return

	gender = _gender
	reset_hair()
	update_body()
	update_dna()
	return TRUE

/mob/living/human/proc/change_hair(var/hair_style)
	if (!hair_style)
		return

	if (h_style == hair_style)
		return

	if (!(hair_style in hair_styles_list))
		return

	h_style = hair_style

	update_hair()
	return TRUE

/mob/living/human/proc/change_facial_hair(var/facial_hair_style)
	if (body_build.nofacialhair) return

	if (!facial_hair_style)
		return

	if (f_style == facial_hair_style)
		return

	if (!(facial_hair_style in facial_hair_styles_list))
		return

	f_style = facial_hair_style

	update_hair()
	return TRUE

/mob/living/human/proc/reset_hair()
	var/list/valid_hairstyles = generate_valid_hairstyles()
	var/list/valid_facial_hairstyles = generate_valid_facial_hairstyles()

	if (valid_hairstyles.len && !find_trait("Baldness"))
		h_style = pick(valid_hairstyles)
	else
		//this shouldn't happen
		h_style = "Bald"

	if (valid_facial_hairstyles.len)
		f_style = pick(valid_facial_hairstyles)
	else
		//this shouldn't happen
		f_style = "Shaved"

	update_hair()

/mob/living/human/proc/change_eye_color(var/red, var/green, var/blue)
	if (red == r_eyes && green == g_eyes && blue == b_eyes)
		return

	r_eyes = red
	g_eyes = green
	b_eyes = blue

	update_eyes()
	update_body()
	return TRUE

/mob/living/human/proc/change_hair_color(var/red, var/green, var/blue)
	if (red == r_hair && green == g_hair && blue == b_hair)
		return

	r_hair = red
	g_hair = green
	b_hair = blue

	force_update_limbs()
	update_body()
	update_hair()
	return TRUE

/mob/living/human/proc/change_facial_hair_color(var/red, var/green, var/blue)
	if (red == r_facial && green == g_facial && blue == b_facial)
		return

	r_facial = red
	g_facial = green
	b_facial = blue

	update_hair()
	return TRUE

/mob/living/human/proc/change_skin_color(var/red, var/green, var/blue)
	if (red == r_skin && green == g_skin && blue == b_skin || !(species.appearance_flags & HAS_SKIN_COLOR))
		return

	r_skin = red
	g_skin = green
	b_skin = blue

	force_update_limbs()
	update_body()
	return TRUE

/mob/living/human/proc/change_skin_tone(var/tone)
	if (s_tone == tone || !(species.appearance_flags & HAS_SKIN_TONE))
		return

	s_tone = tone

	force_update_limbs()
	update_body()
	return TRUE

/mob/living/human/proc/update_dna()
	check_dna()
	dna.ready_dna(src)

/mob/living/human/proc/generate_valid_species(var/check_whitelist = TRUE, var/list/whitelist = list(), var/list/blacklist = list())
	var/list/valid_species = new()
	for (var/current_species_name in all_species)
		var/datum/species/current_species = all_species[current_species_name]

		if (check_whitelist && !check_rights(R_ADMIN, FALSE, src)) //If we're using the whitelist, make sure to check it!
			if (!(current_species.spawn_flags & CAN_JOIN))
				continue
			if (whitelist.len && !(current_species_name in whitelist))
				continue
			if (blacklist.len && (current_species_name in blacklist))
				continue

		valid_species += current_species_name

	return valid_species

/mob/living/human/proc/generate_valid_hairstyles(var/check_gender = TRUE, var/growth = FALSE)
	var/list/valid_hairstyles = new()
	for (var/hairstyle in hair_styles_list)
		var/datum/sprite_accessory/S = hair_styles_list[hairstyle]

		if (check_gender && gender == MALE && S.gender == FEMALE)
			continue
		if (check_gender && gender == FEMALE && S.gender == MALE)
			continue
		if (growth && h_growth < S.growth)
			continue
		if (!(species.get_bodytype() in S.species_allowed))
			continue
		valid_hairstyles += hairstyle

	return valid_hairstyles

/mob/living/human/proc/generate_valid_facial_hairstyles(var/growth = FALSE)
	var/list/valid_facial_hairstyles = new()
	for (var/facialhairstyle in facial_hair_styles_list)
		var/datum/sprite_accessory/S = facial_hair_styles_list[facialhairstyle]

		if (gender == MALE && S.gender == FEMALE)
			continue
		if (gender == FEMALE && S.gender == MALE)
			continue
		if (growth && f_growth < S.growth)
			continue
		if (!(species.get_bodytype() in S.species_allowed))
			continue

		valid_facial_hairstyles += facialhairstyle

	return valid_facial_hairstyles

/mob/living/human/proc/force_update_limbs()
	for (var/obj/item/organ/external/O in organs)
		O.sync_colour_to_human(src)
		O.update_icon()
	update_body(0)
