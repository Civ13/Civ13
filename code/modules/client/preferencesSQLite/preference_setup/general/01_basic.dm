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
	pref.body_build 	= sanitize_inlist(pref.body_build, list("Slim", "Default", "Fat"), "Default")
	pref.identifying_gender = (pref.identifying_gender in all_genders_define_list) ? pref.identifying_gender : pref.gender
	pref.real_name		= sanitize_name(pref.real_name, pref.species)

	if (!pref.real_name)
		pref.real_name	= random_name(pref.gender, pref.species)

	/* start setting up pirate, british names*/

	pref.english_name		= sanitize_name(pref.english_name, pref.species)
	if (!pref.english_name)
		pref.english_name	= random_english_name(pref.gender, pref.species)

	pref.spanish_name		= sanitize_name(pref.spanish_name, pref.species)
	if (!pref.spanish_name)
		pref.spanish_name	= random_spanish_name(pref.gender, pref.species)

	pref.portuguese_name		= sanitize_name(pref.portuguese_name, pref.species)
	if (!pref.portuguese_name)
		pref.portuguese_name	= random_portuguese_name(pref.gender, pref.species)

	pref.french_name		= sanitize_name(pref.french_name, pref.species)
	if (!pref.french_name)
		pref.french_name	= random_french_name(pref.gender, pref.species)

	pref.dutch_name		= sanitize_name(pref.dutch_name, pref.species)
	if (!pref.dutch_name)
		pref.dutch_name	= random_dutch_name(pref.gender, pref.species)

	pref.carib_name		= sanitize_name(pref.carib_name, pref.species)
	if (!pref.carib_name)
		pref.carib_name	= random_carib_name(pref.gender, pref.species)

	/*										*/

//	pref.spawnpoint		= sanitize_inlist(pref.spawnpoint, spawntypes, initial(pref.spawnpoint))
	pref.be_random_name	= sanitize_integer(pref.be_random_name, FALSE, TRUE, initial(pref.be_random_name))
	pref.be_random_name_english	= sanitize_integer(pref.be_random_name_english, FALSE, TRUE, initial(pref.be_random_name_english))
	pref.be_random_name_french	= sanitize_integer(pref.be_random_name_french, FALSE, TRUE, initial(pref.be_random_name_french))
	pref.be_random_name_spanish	= sanitize_integer(pref.be_random_name_spanish, FALSE, TRUE, initial(pref.be_random_name_spanish))
	pref.be_random_name_portuguese	= sanitize_integer(pref.be_random_name_portuguese, FALSE, TRUE, initial(pref.be_random_name_portuguese))
	pref.be_random_name_carib	= sanitize_integer(pref.be_random_name_carib, FALSE, TRUE, initial(pref.be_random_name_carib))
	pref.be_random_name_dutch	= sanitize_integer(pref.be_random_name_dutch, FALSE, TRUE, initial(pref.be_random_name_dutch))

/datum/category_item/player_setup_item/general/basic/content()
	// name
	. = "<b>Name:</b> "
	. += "<a href='?src=\ref[src];rename=1'><b>[pref.real_name]</b></a><br>"
	. += "(<a href='?src=\ref[src];random_name=1'>Random Name</A>) "
	. += "(<a href='?src=\ref[src];always_random_name=1'>Always Random Name: [pref.be_random_name ? "Yes" : "No"]</a>)"
	. += "<br><br>"
	// british name
	. += "<b>English Name:</b> "
	. += "<a href='?src=\ref[src];rename_english=1'><b>[pref.english_name]</b></a><br>"
	. += "(<a href='?src=\ref[src];random_name_english=1'>Random Name</A>) "
	. += "(<a href='?src=\ref[src];always_random_name_english=1'>Always Random Name: [pref.be_random_name_english ? "Yes" : "No"]</a>)"
	. += "<br><br>"
	. += "<b>Spanish Name:</b> "
	. += "<a href='?src=\ref[src];rename_spanish=1'><b>[pref.spanish_name]</b></a><br>"
	. += "(<a href='?src=\ref[src];random_name_spanish=1'>Random Name</A>) "
	. += "(<a href='?src=\ref[src];always_random_name_spanish=1'>Always Random Name: [pref.be_random_name_spanish ? "Yes" : "No"]</a>)"
	. += "<br><br>"
	. += "<b>Portuguese Name:</b> "
	. += "<a href='?src=\ref[src];rename_portuguese=1'><b>[pref.portuguese_name]</b></a><br>"
	. += "(<a href='?src=\ref[src];random_name_portuguese=1'>Random Name</A>) "
	. += "(<a href='?src=\ref[src];always_random_name_portuguese=1'>Always Random Name: [pref.be_random_name_portuguese ? "Yes" : "No"]</a>)"
	. += "<br><br>"
	. += "<b>French Name:</b> "
	. += "<a href='?src=\ref[src];rename_french=1'><b>[pref.french_name]</b></a><br>"
	. += "(<a href='?src=\ref[src];random_name_french=1'>Random Name</A>) "
	. += "(<a href='?src=\ref[src];always_random_name_french=1'>Always Random Name: [pref.be_random_name_french ? "Yes" : "No"]</a>)"
	. += "<br><br>"
	. += "<b>Dutch Name:</b> "
	. += "<a href='?src=\ref[src];rename_dutch=1'><b>[pref.dutch_name]</b></a><br>"
	. += "(<a href='?src=\ref[src];random_name_dutch=1'>Random Name</A>) "
	. += "(<a href='?src=\ref[src];always_random_name_dutch=1'>Always Random Name: [pref.be_random_name_dutch ? "Yes" : "No"]</a>)"
	. += "<br><br>"
	. += "<b>Carib Name:</b> "
	. += "<a href='?src=\ref[src];rename_carib=1'><b>[pref.carib_name]</b></a><br>"
	. += "(<a href='?src=\ref[src];random_name_carib=1'>Random Name</A>) "
	. += "(<a href='?src=\ref[src];always_random_name_carib=1'>Always Random Name: [pref.be_random_name_carib ? "Yes" : "No"]</a>)"
	. += "<br><br>"
	// gender
	. += "<b>Default Gender:</b> <a href='?src=\ref[src];gender=1'><b>[capitalize(lowertext(pref.gender))]</b></a><br>"
	. += "<br>"
	. += "<br><br>"
	. += "<b>Pirate Ethnicity:</b> <a href='?src=\ref[src];ethnicity_pirate=1'><b>[capitalize(lowertext(pref.pirate_ethnicity))]</b></a><br>"
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
		pref.english_name = random_english_name(pref.gender, pref.species)
		return TOPIC_REFRESH

	else if (href_list["always_random_name_english"])
		pref.be_random_name_english = !pref.be_random_name_english
		return TOPIC_REFRESH

	//spanish names
	if (href_list["rename_spanish"])
		var/raw_name = input(user, "Choose your character's Spanish name:", "Character Name")  as text|null
		if (!isnull(raw_name) && CanUseTopic(user))
			var/new_name = sanitize_name(raw_name, pref.species)
			if (new_name)
				pref.spanish_name = new_name
				return TOPIC_REFRESH
			else
				user << "<span class='warning'>Invalid name. Your name should be at least 2 and at most [MAX_NAME_LEN] characters long. It may only contain the characters A-Z, a-z, -, ' and .</span>"
				return TOPIC_NOACTION

	else if (href_list["random_name_spanish"])
		pref.spanish_name = random_spanish_name(pref.gender, pref.species)
		return TOPIC_REFRESH

	else if (href_list["always_random_name_spanish"])
		pref.be_random_name_spanish = !pref.be_random_name_spanish
		return TOPIC_REFRESH

	//portuguese names
	if (href_list["rename_portuguese"])
		var/raw_name = input(user, "Choose your character's Portuguese name:", "Character Name")  as text|null
		if (!isnull(raw_name) && CanUseTopic(user))
			var/new_name = sanitize_name(raw_name, pref.species)
			if (new_name)
				pref.portuguese_name = new_name
				return TOPIC_REFRESH
			else
				user << "<span class='warning'>Invalid name. Your name should be at least 2 and at most [MAX_NAME_LEN] characters long. It may only contain the characters A-Z, a-z, -, ' and .</span>"
				return TOPIC_NOACTION

	else if (href_list["random_name_portuguese"])
		pref.portuguese_name = random_portuguese_name(pref.gender, pref.species)
		return TOPIC_REFRESH

	else if (href_list["always_random_name_portuguese"])
		pref.be_random_name_portuguese = !pref.be_random_name_portuguese
		return TOPIC_REFRESH

	//dutch names
	if (href_list["rename_dutch"])
		var/raw_name = input(user, "Choose your character's Dutch name:", "Character Name")  as text|null
		if (!isnull(raw_name) && CanUseTopic(user))
			var/new_name = sanitize_name(raw_name, pref.species)
			if (new_name)
				pref.dutch_name = new_name
				return TOPIC_REFRESH
			else
				user << "<span class='warning'>Invalid name. Your name should be at least 2 and at most [MAX_NAME_LEN] characters long. It may only contain the characters A-Z, a-z, -, ' and .</span>"
				return TOPIC_NOACTION

	else if (href_list["random_name_dutch"])
		pref.dutch_name = random_dutch_name(pref.gender, pref.species)
		return TOPIC_REFRESH

	else if (href_list["always_random_name_dutch"])
		pref.be_random_name_dutch = !pref.be_random_name_dutch
		return TOPIC_REFRESH

	//french names
	if (href_list["rename_french"])
		var/raw_name = input(user, "Choose your character's French name:", "Character Name")  as text|null
		if (!isnull(raw_name) && CanUseTopic(user))
			var/new_name = sanitize_name(raw_name, pref.species)
			if (new_name)
				pref.french_name = new_name
				return TOPIC_REFRESH
			else
				user << "<span class='warning'>Invalid name. Your name should be at least 2 and at most [MAX_NAME_LEN] characters long. It may only contain the characters A-Z, a-z, -, ' and .</span>"
				return TOPIC_NOACTION

	else if (href_list["random_name_french"])
		pref.french_name = random_french_name(pref.gender, pref.species)
		return TOPIC_REFRESH

	else if (href_list["always_random_name_french"])
		pref.be_random_name_french = !pref.be_random_name_french
		return TOPIC_REFRESH

	//carib names
	if (href_list["rename_carib"])
		var/raw_name = input(user, "Choose your character's Carib name:", "Character Name")  as text|null
		if (!isnull(raw_name) && CanUseTopic(user))
			var/new_name = sanitize_name(raw_name, pref.species)
			if (new_name)
				pref.carib_name = new_name
				return TOPIC_REFRESH
			else
				user << "<span class='warning'>Invalid name. Your name should be at least 2 and at most [MAX_NAME_LEN] characters long. It may only contain the characters A-Z, a-z, -, ' and .</span>"
				return TOPIC_NOACTION

	else if (href_list["random_name_carib"])
		pref.carib_name = random_carib_name(pref.gender, pref.species)
		return TOPIC_REFRESH

	else if (href_list["always_random_name_carib"])
		pref.be_random_name_carib = !pref.be_random_name_carib
		return TOPIC_REFRESH

	else if (href_list["gender"])
		pref.gender = next_in_list(pref.gender, valid_player_genders)
		return TOPIC_REFRESH

	else if (href_list["ethnicity_pirate"])
		pref.pirate_ethnicity = next_in_list(pref.pirate_ethnicity, list(ENGLISH, SPANISH, PORTUGUESE, FRENCH, DUTCH))
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
