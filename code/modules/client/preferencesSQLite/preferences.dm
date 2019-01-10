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
	var/japanese_name = "Hideki Tojo"
	var/russian_name = "Victor Reznof"
	var/carib_name = "Mojowai"
	var/greek_name = "Philokrates"
	var/roman_name = "Decius Salvius Primulus"
	var/arab_name = "Ibrahim ibn Osama"
	var/be_random_name = FALSE				//whether we are a random name every round
	var/be_random_name_pirate = TRUE
	var/be_random_name_carib = TRUE
	var/be_random_name_spanish = TRUE
	var/be_random_name_french = TRUE
	var/be_random_name_portuguese = TRUE
	var/be_random_name_dutch = TRUE
	var/be_random_name_japanese = TRUE
	var/be_random_name_russian = TRUE
	var/be_random_name_english = TRUE
	var/be_random_name_roman = TRUE
	var/be_random_name_greek = TRUE
	var/be_random_name_arab = TRUE
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

	var/disabilities = 0

	var/client/client = null
	var/client_ckey = null
	var/client_isguest = FALSE

	var/list/internal_table = list()

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
			japanese_name = random_japanese_name(gender, species)
			russian_name = random_russian_name(gender, species)
			carib_name = random_carib_name(gender, species)
			roman_name = random_roman_name(gender, species)
			greek_name = random_greek_name(gender, species)
			arab_name = random_arab_name(gender, species)
			save_preferences(1)

		spawn (1)
			loadGlobalPreferences()
			loadGlobalSettings()
			ready = TRUE

/datum/preferences/Del()
	save_preferences(current_slot)
	..()

/datum/preferences/proc/update_setup()
	player_setup.update_setup()

/datum/preferences/proc/ShowChoices(mob/user)
	if (!user || !user.client)	return

	if (!get_mob_by_key(client_ckey))
		user << "<span class='danger'>No mob exists for the given client!</span>"
		return

	var/dat = {"
	<br>
	<html>
	<head>
	<style>
	[common_browser_style]
	</style>
	</head>
	<body><center><big><b>PREFERENCES<br><br>
	"}
	dat += player_setup.header()
	dat += "</big></b><br><HR></center>"
	dat += player_setup.content(user)

	var/datlist = splittext(dat, "<br>")
	var/datlist2 = list()
	for (var/line in datlist)
		datlist2 += "[line]<br>"
	dat = ""
	for (var/line in datlist2)
		dat += line

	dat += "</body></html>"
	user << browse(dat, "window=preferences;size=800x800")



/datum/preferences/proc/process_link(mob/user, list/href_list)
	if (!user)	return

	if (!istype(user, /mob/new_player))	return

	ShowChoices(usr)
	return TRUE

/datum/preferences/Topic(href, list/href_list)
	if (..())
		return TRUE

	// after global prefs are reloaded
	spawn (1.1)
		ShowChoices(usr)

	return TRUE

/datum/preferences/proc/copy_to(mob/living/carbon/human/character, safety = FALSE)
	// Sanitizing rather than saving as someone might still be editing when copy_to occurs.
	player_setup.sanitize_setup()
	if (be_random_name)
		real_name = random_name(gender,species)

	character.real_name = real_name

	if (character.dna)
		character.dna.real_name = character.real_name

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

	character.all_underwear.Cut()

	if (backbag > 4 || backbag < 1)
		backbag = TRUE //Same as above
	character.backbag = backbag

	//Debugging report to track down a bug, which randomly assigned the plural gender to people.
	if (character.gender in list(PLURAL, NEUTER))
		if (isliving(src)) //Ghosts get neuter by default
			message_admins("[character] ([character.ckey]) has spawned with their gender as plural or neuter. Please notify coders.")
			character.gender = MALE

/proc/globalprefsanitize(str)
	if (islist(str))
		return ""
	return str

// global preferences handling
/datum/preferences/proc/loadGlobalPreferences()
	var/F = file("SQL/globalpreferences.txt")
	var/list/globalprefs = splittext(file2text(F), "|||")
	var/list/tables = list()
	for (var/i;i<globalprefs.len;i++)
		var/list/globalprefs2 = list(splittext(globalprefs[i], ";"))
		if (globalprefs2[1] == client_ckey)
			tables = globalprefs2[2]
	if (!islist(tables) || isemptylist(tables))
		return
	var/list/keyvals_list = splittext(tables, "&")
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
	var/F = file("SQL/globalpreferences.txt")
	var/list/globalprefs = splittext(file2text(F), "|||")
	var/done1 = FALSE
	for (var/i;i<globalprefs.len;i++)
		var/list/globalprefs2 = list(splittext(globalprefs[i], ";"))
		if (globalprefs2[1] == client_ckey)
			globalprefs2[2] = prefstring
			done1 = TRUE
	if (!done1)
		text2file(F, "[client_ckey];[prefstring]|||")
// global settings handling
/datum/preferences/proc/loadGlobalSettings()
	if (!client)
		return

	var/F = file("SQL/globalsettings.txt")
	var/list/globalprefs = splittext(file2text(F), "|||")
	var/list/tables = list()
	var/list/tables2 = list()
	for (var/i;i<globalprefs.len;i++)
		var/list/globalprefs2 = list(splittext(globalprefs[i], ";"))
		if (globalprefs2[1] == client_ckey)
			tables = globalprefs2[2]
		if (islist(tables) && !isemptylist(tables))
			// enabled
			var/list/vals_list = splittext(tables, "&")
			for (var/val in vals_list)
				if (isnum(text2num(val)))
					val = text2num(val)
				client.set_preference(val, TRUE)

			// disabled
			tables2 = globalprefs2[3]
			var/list/vals_list2 = splittext(tables2, "&")
			for (var/val2 in vals_list2)
				if (isnum(text2num(val2)))
					val2 = text2num(val2)
				client.set_preference(val2, FALSE)


/datum/preferences/proc/saveGlobalSettings()
	var/prefstring = ""
	for (var/v in 1 to preferences_enabled.len)
		prefstring += preferences_enabled[v]
		if (v != preferences_enabled.len)
			prefstring += "&"
	var/prefstring2 = ""
	for (var/v in 1 to preferences_disabled.len)
		prefstring2 += preferences_disabled[v]
		if (v != preferences_disabled.len)
			prefstring2 += "&"
	var/F = file("SQL/globalsettings.txt")
	var/list/globalprefs = splittext(file2text(F), "|||")
	var/done1 = FALSE
	var/done2 = FALSE
	if (prefstring)
		for (var/i;i<globalprefs.len;i++)
			var/list/globalprefs2 = list(splittext(globalprefs[i], ";"))
			if (globalprefs2[1] == client_ckey)
				globalprefs2[2] = prefstring
				done1 = TRUE
	if (prefstring2)
		for (var/i;i<globalprefs.len;i++)
			var/list/globalprefs2 = list(splittext(globalprefs[i], ";"))
			if (globalprefs2[1] == client_ckey)
				globalprefs2[3] = prefstring2
				done2 = TRUE
		if (!done1 && !done2)
			text2file(F, "[client_ckey];[prefstring];[prefstring2]|||")


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
