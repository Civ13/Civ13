//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:33
#define GLOBAL_SLOT 99

var/list/preferences_datums = list()

/datum/preferences

	//non-preference stuff
	var/warns = FALSE
	var/muted = FALSE
	var/last_ip
	var/last_id

	//game-preferences
	var/ooccolor = "#010000"			//Whatever this is set to acts as 'reset' color and is thus unusable as an actual custom color
	var/list/be_special_role = list()		//Special role selection
	var/UI_style = "1713Style"
	var/UI_useborder = FALSE
	var/UI_style_color = "#FFFFFF"
	var/UI_style_alpha = 255
	var/lobby_music_volume = 30

	//character preferences
	var/real_name = "John Doe"						//our character's name
	var/english_name = "John Adams"
	var/spanish_name = "Juan Garcia"
	var/french_name = "Mathieu Bertrand"
	var/portuguese_name = "Pedro Alves"
	var/dutch_name = "Daan Visser"
	var/carib_name = "Mojowai"
	var/greek_name = "Philokrates"
	var/roman_name = "Decius Salvius Primulus"
	var/arab_name = "Ibrahim"
	var/japanese_name = "Toshizou Hijikata"
	var/russian_name = "Vladisov Sakhavisk"
	var/be_random_name = FALSE				//whether we are a random name every round
	var/be_random_name_pirate = FALSE
	var/be_random_name_carib = FALSE
	var/be_random_name_spanish = FALSE
	var/be_random_name_french = FALSE
	var/be_random_name_portuguese = FALSE
	var/be_random_name_dutch = FALSE
	var/be_random_name_english = FALSE
	var/be_random_name_japanese = FALSE
	var/be_random_name_roman = TRUE
	var/be_random_name_greek = TRUE
	var/be_random_name_arab = TRUE
	var/be_random_name_russian = FALSE
	var/gender = MALE					//gender of character (well duh)
	var/civ_ethnicity = ENGLISH

	var/body_build = "Default"			//character body build name
	var/age = 25						//age of character

	var/b_type = "A+"					//blood type (not-chooseable)
	var/backbag = 2						//backpack type
	var/h_style = "Bald"				//Hair type
	var/r_hair = FALSE						//Hair color
	var/g_hair = FALSE						//Hair color
	var/b_hair = FALSE						//Hair color
	var/f_style = "Chinstrap"				//Face hair type
	var/r_facial = FALSE					//Face hair color
	var/g_facial = FALSE					//Face hair color
	var/b_facial = FALSE					//Face hair color
	var/s_tone = FALSE						//Skin tone

	var/r_skin = FALSE						//Skin color
	var/g_skin = FALSE						//Skin color
	var/b_skin = FALSE						//Skin color

	var/r_eyes = FALSE						//Eye color
	var/g_eyes = FALSE						//Eye color
	var/b_eyes = FALSE						//Eye color
	var/species = "Human"               //Species datum to use.
	var/species_preview                 //Used for the species selection window.
	var/list/alternate_languages = list() //Secondary language(s)
	var/list/language_prefixes = list() //Kanguage prefix keys

	//Mob preview
	var/list/preview_icons = list()
	var/list/preview_icons_front = list()
	var/list/preview_icons_back = list()
	var/list/preview_icons_east = list()
	var/list/preview_icons_west = list()

	//Keeps track of preferrence for not getting any wanted jobs
	var/alternate_option = FALSE

	// maps each organ to either null(intact) or "amputated"
	// will probably not be able to do this for head and torso ;)
	var/list/organ_data = list()
	var/list/rlimb_data = list()
	var/list/player_alt_titles = new()		// the default name of a job like "Medical Doctor"

	var/disabilities = 0

	var/list/pockets = list("Knife", "Food")

	var/client/client = null
	var/client_ckey = null
	var/client_isguest = FALSE

	var/list/internal_table = list()

	var/list/saved_lists = list("pockets")

	var/datum/category_collection/player_setup_collection/player_setup

	var/current_character_type = "N/A"

	var/current_slot = 1

	var/list/preferences_enabled = list("SOUND_MIDI", "SOUND_LOBBY", "SOUND_AMBIENCE",
		"CHAT_GHOSTEARS", "CHAT_GHOSTSIGHT", "CHAT_GHOSTRADIO", "CHAT_SHOWICONS",
		"SHOW_TYPING", "CHAT_OOC", "CHAT_LOOC", "CHAT_DEAD", "SHOW_PROGRESS",
		"CHAT_ATTACKLOGS", "CHAT_DEBUGLOGS", "CHAT_PRAYER", "SOUND_ADMINHELP")

	var/list/preferences_disabled = list()

	var/ready = FALSE

/datum/preferences/New(client/C)

	player_setup = new(src)

    /* don't change any of our preferences from the default anymore:
     * its counter-intuitive to how the new saving system works: the
     * preference saving thing assumes that the only things that change
     * are those which are changed by the user, so if we randomize these
     * values we will end up loading the default anyway */
	/*

	gender = pick(MALE, FEMALE)
	german_gender = pick(MALE, FEMALE)
	pirate_gender = pick(MALE, FEMALE)
	ukrainian_gender = pick(MALE, FEMALE)
	real_name = random_name(gender,species)

	/* changing names from the default is neccessary, however, and it occurs
	 * below. */


	b_type = pick(4;"O-", 36;"O+", 3;"A-", 28;"A+", TRUE;"B-", 20;"B+", TRUE;"AB-", 5;"AB+")
   */

	if (istype(C))
		client = C
		client_ckey = C.ckey
		if (IsGuestKey(client_ckey))
			client_isguest = TRUE

		// load our first slot, if we have one
		if (preferences_exist(1))
			load_preferences(1)
		else
			real_name = random_name(gender, species)
			english_name = random_english_name(gender, species)
			french_name = random_french_name(gender, species)
			portuguese_name = random_portuguese_name(gender, species)
			spanish_name = random_spanish_name(gender, species)
			dutch_name = random_dutch_name(gender, species)
			carib_name = random_carib_name(gender, species)
			roman_name = random_roman_name(gender, species)
			greek_name = random_greek_name(gender, species)
			arab_name = random_arab_name(gender, species)
			japanese_name = random_japanese_name(gender, species)
			russian_name = random_russian_name(gender, species)
			remember_preference("real_name", real_name)
			remember_preference("english_name", english_name)
			remember_preference("french_name", french_name)
			remember_preference("spanish_name", spanish_name)
			remember_preference("portuguese_name", portuguese_name)
			remember_preference("carib_name", carib_name)
			remember_preference("dutch_name", dutch_name)
			remember_preference("greek_name", greek_name)
			remember_preference("arab_name", arab_name)
			remember_preference("roman_name", roman_name)
			remember_preference("japanese_name", japanese_name)
			remember_preference("russian_name", russian_name)
			save_preferences(1)

		spawn (1)
			loadGlobalPreferences()
			loadGlobalSettings()
			ready = TRUE

		// otherwise, keep using our default values

	for (var/i in 1 to 8)
		internal_table[num2text(i)] = list()

/datum/preferences/Del()
	save_preferences(current_slot)
	..()

/datum/preferences/proc/update_setup()
	player_setup.update_setup()

/datum/preferences/proc/ShowChoices(mob/user)
	if (!user || !user.client)	return

	if (!get_mob_by_key(client_ckey))
		user << "<span class='danger'>No mob exists for the given client!</span>"
		close_load_dialog(user)
		return

	if (pockets.len != 2)
		qdel_list(pockets)
		pockets = list("Knife", "Food")

	var/dat = {"
	<br>
	<html>
	<head>
	<style>
	[common_browser_style]
	</style>
	</head>
	<body><center>
	"}

	if (!IsGuestKey(user.key))
		dat += "<big><b>"
		dat += "<a href='?src=\ref[src];load=1'>Load Slot</a> - "
		dat += "<a href='?src=\ref[src];save=1'>Save to Slot</a> - "
		dat += "<a href='?src=\ref[src];del=1'>Delete Slot</a>"
		dat += "</big></b>"
	else
		dat += "Please create an account to save your preferences."

	dat += "<br><br>"
	dat += player_setup.header()
	dat += "<br><HR></center>"
	dat += player_setup.content(user)

	var/datlist = splittext(dat, "<br>")
	var/datlist2 = list()
	for (var/line in datlist)
		datlist2 += "<small>[line]</small><br>"
	dat = ""
	for (var/line in datlist2)
		dat += line

	dat += "</body></html>"
	user << browse(dat, "window=preferences;size=980x800")



/datum/preferences/proc/process_link(mob/user, list/href_list)
	if (!user)	return

	if (!istype(user, /mob/new_player))	return

	if (href_list["preference"] == "open_whitelist_forum")
		if (config.forumurl)
			user << link(config.forumurl)
		else
			user << "<span class='danger'>The forum URL is not set in the server configuration.</span>"
			return

	ShowChoices(usr)
	return TRUE

/datum/preferences/Topic(href, list/href_list)
	if (..())
		return TRUE

	if (href_list["save"])
		open_save_dialog(usr)

	else if (href_list["savetoslot"])
		var/previous_slot = text2num(current_slot)
		current_slot = text2num(href_list["savetoslot"])

		if (current_slot == 0)
			current_slot = 1 // if we delete all our slots, still let us save

		if (current_slot != 0 && save_preferences(current_slot, previous_slot))
			if (internal_table.len > 1 && current_slot != previous_slot)
				usr << "<span class = 'good'>Successfully saved current preferences to slot #[current_slot] (With a new name).</span>"
			else
				usr << "<span class = 'good'>Successfully saved current preferences to slot #[current_slot].</span>"
		else
			usr << "<span class = 'bad'>FAILED to save current preferences to slot #[current_slot].</span>"
		close_save_dialog(usr)

	else if (href_list["load"])
		if (!IsGuestKey(usr.key))
			open_load_dialog(usr)
			return TRUE

	else if (href_list["loadfromslot"])
		var/slot = text2num(href_list["loadfromslot"])
		if (slot == 0)
			slot = 1
		if (slot != 0)
			if (load_preferences(slot))
				current_slot = slot
				usr << "<span class = 'good'>Successfully loaded preferences (slot #[current_slot]).</span>"
				spawn (1)
					loadGlobalPreferences()
					loadGlobalSettings()
			else
				usr << "<span class = 'bad'>FAILED to load preferences (slot #[current_slot]).</span>"
		close_load_dialog(usr)

	else if (href_list["del"])
		open_del_dialog(usr)

	else if (href_list["delslot"])
		current_slot = text2num(href_list["delslot"])
		if (current_slot != FALSE)
			if (del_preferences(current_slot))
				usr << "<span class = 'good'>Successfully DELETED preferences (slot #[current_slot]).</span>"
			else
				usr << "<span class = 'good'>failed to DELETE preferences (slot #[current_slot]).</span>"
		close_del_dialog(usr)
	else
		return FALSE

	// after global prefs are reloaded
	spawn (1.1)
		ShowChoices(usr)

	return TRUE

/datum/preferences/proc/copy_to(mob/living/carbon/human/character, safety = FALSE)
	// Sanitizing rather than saving as someone might still be editing when copy_to occurs.
	player_setup.sanitize_setup()
	if (be_random_name)
		real_name = random_name(gender,species)

	if (config.humans_need_surnames)
		var/firstspace = findtext(real_name, " ")
		var/name_length = length(real_name)
		if (!firstspace)	//we need a surname
			real_name += " [pick(last_names)]"
		else if (firstspace == name_length)
			real_name += "[pick(last_names)]"

	character.real_name = real_name

	if (character.dna)
		character.dna.real_name = character.real_name

	character.body_build = get_body_build(gender, body_build)

	character.gender = gender
	character.age = age
	character.b_type = b_type

	character.r_eyes = r_eyes
	character.g_eyes = g_eyes
	character.b_eyes = b_eyes

	character.r_hair = r_hair
	character.g_hair = g_hair
	character.b_hair = b_hair

	character.r_facial = r_facial
	character.g_facial = g_facial
	character.b_facial = b_facial

	character.r_skin = r_skin
	character.g_skin = g_skin
	character.b_skin = b_skin

	character.s_tone = s_tone

	character.h_style = h_style
	character.f_style = f_style

	for (var/name in organ_data)

		var/status = organ_data[name]
		var/obj/item/organ/external/O = character.organs_by_name[name]
		if (O)
			O.status = FALSE
			if (status == "amputated")
				character.organs_by_name[O.limb_name] = null
				character.organs -= O
				if (O.children) // This might need to become recursive.
					for (var/obj/item/organ/external/child in O.children)
						character.organs_by_name[child.limb_name] = null
						character.organs -= child

	character.all_underwear.Cut()

	if (backbag > 4 || backbag < 1)
		backbag = TRUE //Same as above
	character.backbag = backbag

	//Debugging report to track down a bug, which randomly assigned the plural gender to people.
	if (character.gender in list(PLURAL, NEUTER))
		if (isliving(src)) //Ghosts get neuter by default
			message_admins("[character] ([character.ckey]) has spawned with their gender as plural or neuter. Please notify coders.")
			character.gender = MALE

/datum/preferences/proc/open_load_dialog(mob/user)
	var/dat = "<body>"
	dat += "<tt><center>"

	dat += "<b>Select a character slot to load from</b><hr>"
	for (var/i in 1 to config.character_slots)
		if (preferences_exist(i))
			dat += "<a href='?src=\ref[src];loadfromslot=[i]'>[i]. [get_DB_preference_value("real_name", i)]</a><br>"
		else
			dat += "[i]. Empty Slot<br>"

	dat += "<hr>"
	dat += "</center></tt>"
	user << browse(dat, "window=load_dialog;size=300x390")

/datum/preferences/proc/close_load_dialog(mob/user)
	user << browse(null, "window=load_dialog")

// save

/datum/preferences/proc/open_save_dialog(mob/user)
	var/dat = "<body>"
	dat += "<tt><center>"

	dat += "<b>Select a character slot to save to</b><hr>"
	for (var/i in 1 to config.character_slots)
		if (preferences_exist(i))
			dat += "<a href='?src=\ref[src];savetoslot=[i]'>[i]. [get_DB_preference_value("real_name", i)]</a><br>"
		else
			dat += "<a href='?src=\ref[src];savetoslot=[i]'>[i]. Empty Slot</a><br>"

	dat += "<hr>"
	dat += "</center></tt>"
	user << browse(dat, "window=save_dialog;size=300x390")

/datum/preferences/proc/close_save_dialog(mob/user)
	user << browse(null, "window=save_dialog")

// del

/datum/preferences/proc/open_del_dialog(mob/user)
	var/dat = "<body>"
	dat += "<tt><center>"

	dat += "<b>Select a character save to delete</b><hr>"
	for (var/i in 1 to config.character_slots)
		if (preferences_exist(i))
			dat += "<a href='?src=\ref[src];delslot=[i]'>[i]. [get_DB_preference_value("real_name", i)]</a><br>"
		else
			dat += "<i>[i]. Empty Slot</i><br>"

	dat += "<hr>"
	dat += "</center></tt>"
	user << browse(dat, "window=del_dialog;size=300x390")

/datum/preferences/proc/close_del_dialog(mob/user)
	user << browse(null, "window=del_dialog")


/proc/globalprefsanitize(str)
	if (islist(str))
		return ""
	return str

// global preferences handling
/datum/preferences/proc/loadGlobalPreferences()
	var/list/tables = database.execute("SELECT prefs FROM preferences WHERE ckey = '[client_ckey]' AND slot = 'glob1';")
	if (!islist(tables) || isemptylist(tables))
		return
	var/prefstring = tables["prefs"]
//	log_debug(prefstring)
	if (length(prefstring))
		var/list/keyvals_list = splittext(prefstring, "&")
		for (var/keyval in keyvals_list)
			var/keyval_pair = splittext(keyval, "=")
			var/key = keyval_pair[1]
			var/val = keyval_pair[2]
			if (isnum(text2num(val)))
				val = text2num(val)
			if (val != vars[key])
				if (vars[key])
					vars[key] = val

/datum/preferences/proc/saveGlobalPreferences()
	var/prefstring = ""

	prefstring += "ooccolor=[globalprefsanitize(ooccolor)]&"
	prefstring += "be_special_role=[globalprefsanitize(be_special_role)]&"
	prefstring += "UI_style=[globalprefsanitize(UI_style)]&"
	prefstring += "UI_useborder=[globalprefsanitize(UI_useborder)]&"
	prefstring += "UI_style_color=[globalprefsanitize(UI_style_color)]&"
	prefstring += "UI_style_alpha=[globalprefsanitize(UI_style_alpha)]&"
	prefstring += "lobby_music_volume=[globalprefsanitize(lobby_music_volume)]"

	var/list/prefs_exist_check = database.execute("SELECT * FROM preferences WHERE ckey = '[client_ckey]' AND slot = 'glob1';")
	if (islist(prefs_exist_check) && !isemptylist(prefs_exist_check))
		database.execute("UPDATE preferences SET prefs = '[prefstring]' WHERE ckey = '[client_ckey]' AND slot = 'glob1';")
	else
		database.execute("INSERT INTO preferences (ckey, slot, prefs) VALUES ('[client_ckey]', 'glob1', '[prefstring]');")

// global settings handling
#define ONLY_LOAD_DISABLED_SETTINGS
/datum/preferences/proc/loadGlobalSettings()
	if (!client)
		return
	// enabled
	var/list/tables = database.execute("SELECT prefs FROM preferences WHERE ckey = '[client_ckey]' AND slot = 'glob2_enabled';")

	#ifndef ONLY_LOAD_DISABLED_SETTINGS
	if (islist(tables) && !isemptylist(tables))
		var/prefstring = tables["prefs"]
		if (length(prefstring))
			var/list/vals_list = splittext(prefstring, "&")
			for (var/val in vals_list)
				if (isnum(text2num(val)))
					val = text2num(val)
				client.set_preference(val, TRUE)
	#else
	for (var/pref in preferences_enabled)
		client.set_preference(pref, TRUE)
	#endif
	// disabled
	tables = database.execute("SELECT prefs FROM preferences WHERE ckey = '[client_ckey]' AND slot = 'glob2_disabled';")
	if (islist(tables) && !isemptylist(tables))
		var/prefstring = tables["prefs"]
		if (length(prefstring))
			var/list/vals_list = splittext(prefstring, "&")
			for (var/val in vals_list)
				if (isnum(text2num(val)))
					val = text2num(val)
				client.set_preference(val, FALSE)
/*
	for (var/mob/M in player_list)
		if (M.client && M.client.ckey == client_ckey)
			ShowChoices(M)*/

/datum/preferences/proc/saveGlobalSettings()
	var/prefstring = ""
	for (var/v in 1 to preferences_enabled.len)
		prefstring += preferences_enabled[v]
		if (v != preferences_enabled.len)
			prefstring += "&"
	if (prefstring)
		var/list/prefs_exist_check = database.execute("SELECT * FROM preferences WHERE ckey = '[client_ckey]' AND slot = 'glob2_enabled';")
		if (islist(prefs_exist_check) && !isemptylist(prefs_exist_check))
			database.execute("UPDATE preferences SET prefs = '[prefstring]' WHERE ckey = '[client_ckey]' AND slot = 'glob2_enabled';")
		else
			database.execute("INSERT INTO preferences (ckey, slot, prefs) VALUES ('[client_ckey]', 'glob2_enabled', '[prefstring]');")

	prefstring = ""
	for (var/v in 1 to preferences_disabled.len)
		prefstring += preferences_disabled[v]
		if (v != preferences_disabled.len)
			prefstring += "&"
	if (prefstring)
		var/list/prefs_exist_check = database.execute("SELECT * FROM preferences WHERE ckey = '[client_ckey]' AND slot = 'glob2_disabled';")
		if (islist(prefs_exist_check) && !isemptylist(prefs_exist_check))
			database.execute("UPDATE preferences SET prefs = '[prefstring]' WHERE ckey = '[client_ckey]' AND slot = 'glob2_disabled';")
		else
			database.execute("INSERT INTO preferences (ckey, slot, prefs) VALUES ('[client_ckey]', 'glob2_disabled', '[prefstring]');")
#undef ONLY_LOAD_DISABLED_SETTINGS

/client/proc/is_preference_enabled(var/preference)

	if (ispath(preference))
		var/datum/client_preference/cp = get_client_preference_by_type(preference)
		preference = cp.key

	return (preference in prefs.preferences_enabled)

/client/proc/set_preference(var/preference, var/set_preference)
	var/datum/client_preference/cp
	if (ispath(preference))
		cp = get_client_preference_by_type(preference)
	else
		cp = get_client_preference_by_key(preference)

	if (!cp)
		return FALSE

	var/enabled
	if (set_preference && !(preference in prefs.preferences_enabled))
		prefs.preferences_enabled  += preference
		prefs.preferences_disabled -= preference
		enabled = TRUE
		. = TRUE
	else if (!set_preference && (preference in prefs.preferences_enabled))
		prefs.preferences_enabled  -= preference
		prefs.preferences_disabled |= preference
		enabled = FALSE
		. = TRUE
	if (.)
		cp.toggled(mob, enabled)

	for (var/client/C in clients)
		if (C.ckey == prefs.client_ckey)
			C.onload_preferences(preference)

	prefs.saveGlobalSettings()

/mob/proc/is_preference_enabled(var/preference)
	if (!client)
		return FALSE
	return client.is_preference_enabled(preference)

/mob/proc/set_preference(var/preference, var/set_preference)
	if (!client)
		return FALSE
	if (!client.prefs)
		log_debug("Client prefs found to be null for mob [src] and client [ckey], this should be investigated.")
		return FALSE

	return client.set_preference(preference, set_preference)

/client/var/initially_loaded_preferences = FALSE
/client/proc/onload_preferences(var/preference)
	if (initially_loaded_preferences)
		if (preference == "SOUND_LOBBY")
			var/datum/client_preference/cp = get_client_preference_by_type(/datum/client_preference/play_lobby_music)
			if (isnewplayer(mob))
				if (is_preference_enabled(cp.key))
					playtitlemusic()
				else
					stoptitlemusic()
	else
		initially_loaded_preferences = TRUE
