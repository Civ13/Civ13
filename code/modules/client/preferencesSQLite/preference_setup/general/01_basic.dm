/datum/preferences
	var/identifying_gender = MALE

/datum/category_item/player_setup_item/general/basic
	name = "Basic"
	sort_order = 1
	var/list/valid_player_genders = list(MALE, FEMALE)
	var/list/valid_second_languages = list(GERMAN, RUSSIAN, ITALIAN, UKRAINIAN)

datum/preferences/proc/set_biological_gender(var/set_gender)
	gender = set_gender
	identifying_gender = set_gender

/datum/category_item/player_setup_item/general/basic/sanitize_character()

	var/datum/species/S = all_species[pref.species ? pref.species : "Human"]
	pref.age			= sanitize_integer(pref.age, S.min_age, S.max_age, initial(pref.age))
	pref.gender 		= sanitize_inlist(pref.gender, valid_player_genders, pick(valid_player_genders))
	pref.pirate_gender 		= sanitize_inlist(pref.pirate_gender, valid_player_genders, pick(valid_player_genders))
	pref.english_gender 		= sanitize_inlist(pref.english_gender, valid_player_genders, pick(valid_player_genders))
	pref.body_build 	= sanitize_inlist(pref.body_build, list("Slim", "Default", "Fat"), "Default")
	pref.identifying_gender = (pref.identifying_gender in all_genders_define_list) ? pref.identifying_gender : pref.gender
	pref.real_name		= sanitize_name(pref.real_name, pref.species)

	if (!pref.real_name)
		pref.real_name	= random_name(pref.gender, pref.species)

	/* start setting up german, russian names*/

	pref.pirate_name		= sanitize_name(pref.pirate_name, pref.species)
	if (!pref.pirate_name)
		pref.pirate_name	= random_pirate_name(pref.pirate_gender, pref.species)


	pref.english_name		= sanitize_name(pref.english_name, pref.species)
	if (!pref.english_name)
		pref.english_name	= random_english_name(pref.english_gender, pref.species)
	/*										*/

//	pref.spawnpoint		= sanitize_inlist(pref.spawnpoint, spawntypes, initial(pref.spawnpoint))
	pref.be_random_name	= sanitize_integer(pref.be_random_name, FALSE, TRUE, initial(pref.be_random_name))
	pref.be_random_name_pirate	= sanitize_integer(pref.be_random_name_pirate, FALSE, TRUE, initial(pref.be_random_name_pirate))
	pref.be_random_name_english	= sanitize_integer(pref.be_random_name_english, FALSE, TRUE, initial(pref.be_random_name_english))

/datum/category_item/player_setup_item/general/basic/content()
	// name
	. = "<b>Name:</b> "
	. += "<a href='?src=\ref[src];rename=1'><b>[pref.real_name]</b></a><br>"
	. += "(<a href='?src=\ref[src];random_name=1'>Random Name</A>) "
	. += "(<a href='?src=\ref[src];always_random_name=1'>Always Random Name: [pref.be_random_name ? "Yes" : "No"]</a>)"
	. += "<br><br>"
	// pirate name
	. += "<b>Pirate Name:</b> "
	. += "<a href='?src=\ref[src];rename_pirate=1'><b>[pref.pirate_name]</b></a><br>"
	. += "(<a href='?src=\ref[src];random_name_pirate=1'>Random Name</A>) "
	. += "(<a href='?src=\ref[src];always_random_name_pirate=1'>Always Random Name: [pref.be_random_name_pirate ? "Yes" : "No"]</a>)"
	. += "<br><br>"
	// british name
	. += "<b>British Name:</b> "
	. += "<a href='?src=\ref[src];rename_english=1'><b>[pref.english_name]</b></a><br>"
	. += "(<a href='?src=\ref[src];random_name_english=1'>Random Name</A>) "
	. += "(<a href='?src=\ref[src];always_random_name_english=1'>Always Random Name: [pref.be_random_name_english ? "Yes" : "No"]</a>)"
	. += "<br><br>"
	// gender
	. += "<b>Default Gender:</b> <a href='?src=\ref[src];gender=1'><b>[capitalize(lowertext(pref.gender))]</b></a><br>"
	. += "<br>"
	. += "<b>Pirate Gender:</b> <a href='?src=\ref[src];gender_pirate=1'><b>[capitalize(lowertext(pref.pirate_gender))]</b></a><br>"
	. += "<br>"
	. += "<b>British Gender:</b> <a href='?src=\ref[src];gender_english=1'><b>[capitalize(lowertext(pref.english_gender))]</b></a><br>"
	. += "<br>"
	. += "<br><br>"


//	var/client/client = pref.client

	//. += "<b>Body Shape:</b> <a href='?src=\ref[src];body_build=1'><b>[pref.body_build]</b></a><br>" No. No no no no no no.
	. += "<b>Age:</b> <a href='?src=\ref[src];age=1'>[pref.age]</a><br>"

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


	//pirate names
	if (href_list["rename_pirate"])
		var/raw_name = input(user, "Choose your character's pirate name:", "Character Name")  as text|null
		if (!isnull(raw_name) && CanUseTopic(user))
			var/new_name = sanitize_name(raw_name, pref.species)
			if (new_name)
				pref.pirate_name = new_name
				return TOPIC_REFRESH
			else
				user << "<span class='warning'>Invalid name. Your name should be at least 2 and at most [MAX_NAME_LEN] characters long. It may only contain the characters A-Z, a-z, -, ' and .</span>"
				return TOPIC_NOACTION

	else if (href_list["random_name_pirate"])
		pref.pirate_name = random_pirate_name(pref.pirate_gender, pref.species)
		return TOPIC_REFRESH

	else if (href_list["always_random_name_pirate"])
		pref.be_random_name_pirate = !pref.be_random_name_pirate
		return TOPIC_REFRESH

	//english names
	if (href_list["rename_english"])
		var/raw_name = input(user, "Choose your character's English name:", "Character Name")  as text|null
		if (!isnull(raw_name) && CanUseTopic(user))
			var/new_name = sanitize_name(raw_name, pref.species)
			if (new_name)
				pref.english_name = new_name
				return TOPIC_REFRESH
			else
				user << "<span class='warning'>Invalid name. Your name should be at least 2 and at most [MAX_NAME_LEN] characters long. It may only contain the characters A-Z, a-z, -, ' and .</span>"
				return TOPIC_NOACTION

	else if (href_list["random_name_english"])
		pref.english_name = random_english_name(pref.english_gender, pref.species)
		return TOPIC_REFRESH

	else if (href_list["always_random_name_english"])
		pref.be_random_name_english = !pref.be_random_name_english
		return TOPIC_REFRESH

	else if (href_list["gender"])
		pref.gender = next_in_list(pref.gender, valid_player_genders)
		return TOPIC_REFRESH


	else if (href_list["gender_pirate"])
		pref.pirate_gender = next_in_list(pref.pirate_gender, valid_player_genders)
		if ((input(user, "Choose new Pirate name that corresponds with this gender?") in list("Yes", "No")) == "Yes")
			pref.pirate_name = random_pirate_name(pref.pirate_gender, pref.species)
		return TOPIC_REFRESH

	else if (href_list["gender_english"])
		pref.english_gender = next_in_list(pref.english_gender, valid_player_genders)
		if ((input(user, "Choose new English name that corresponds with this gender?") in list("Yes", "No")) == "Yes")
			pref.english_name = random_english_name(pref.english_gender, pref.species)
		return TOPIC_REFRESH


	else if (href_list["body_build"])
		pref.body_build = input("Body Shape", "Body") in list("Default", "Slim", "Fat")
		return TOPIC_REFRESH

	else if (href_list["age"])
		var/datum/species/S = all_species[pref.species]
		var/new_age = input(user, "Choose your character's age:\n([S.min_age]-[S.max_age])", "Character Preference", pref.age) as num|null
		if (new_age && CanUseTopic(user))
			pref.age = max(min(round(text2num(new_age)), S.max_age), S.min_age)
			return TOPIC_REFRESH

	return ..()
