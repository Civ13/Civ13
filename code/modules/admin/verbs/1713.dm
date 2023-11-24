
/client/proc/toggle_playing()
	set category = "Special"
	set name = "Toggle Playing"

	ticker.players_can_join = !ticker.players_can_join
	world << "<big><b>You [(ticker.players_can_join) ? "can" : "can't"] join the game [(ticker.players_can_join) ? "now" : "anymore"].</b></big>"
	message_admins("[key_name(src)] changed the playing setting.", key_name(src))

/client/proc/toggle_tts()
	set category = "Special"
	set name = "Toggle TTS"

	config.tts_on = !config.tts_on
	message_admins("[key_name(src)] changed turned the TTS setting [config.tts_on ? "on" : "off"].", key_name(src))

/client/proc/set_teams()
	set category = "Special"
	set name = "Set Teams"
	if (map && istype(map, /obj/map_metadata/football))
		var/obj/map_metadata/football/FM = map
		FM.assign_teams(triggerer = src)

/client/proc/end_all_grace_periods()
	set category = "Special"
	set name = "End All Grace Periods"
	var/conf = input(src, "Are you sure you want to end all grace periods?") in list("Yes", "No")
	if (conf == "Yes")
		map.admin_ended_all_grace_periods = TRUE
		message_admins("[key_name(src)] ended all grace periods!", key_name(src))
		log_admin("[key_name(src)] ended all grace periods.")

/client/proc/reset_all_grace_periods()
	set category = "Special"
	set name = "Reset All Grace Periods"
	var/conf = input(src, "Are you sure you want to reset all grace periods?") in list("Yes", "No")
	if (conf == "Yes")
		map.admin_ended_all_grace_periods = FALSE
		message_admins("[key_name(src)] reset all grace periods!", key_name(src))
		log_admin("[key_name(src)] reset all grace periods.")

/client/proc/faction_species()
	set category = "Special"
	set name = "Faction Species"

	if (!map)
		return

	var/list/choicelist = list("Cancel")
	for (var/i in map.faction_organization)
		choicelist += i

	var/conf = WWinput(src, "Which faction do you wish to change?","Species","Cancel",choicelist)
	if (conf == "Cancel")
		return
	var/choice = WWinput(src, "Which species to turn them into?","Species","Human", list("Human","Orc","Gorilla","Ant","Lizard","Wolfman","Crab"))
	if (choice == "Human")
		map.human += conf
		if (conf in map.orc)
			map.orc -= conf
		if (conf in map.gorilla)
			map.gorilla -= conf
		if (conf in map.ant)
			map.ant -= conf
		if (conf in map.lizard)
			map.lizard -= conf
		if (conf in map.crab)
			map.crab -= conf
		if (conf in map.wolfman)
			map.wolfman -= conf
	else if (choice == "Orc")
		map.orc += conf
		if (conf in map.human)
			map.human -= conf
		if (conf in map.gorilla)
			map.gorilla -= conf
		if (conf in map.ant)
			map.ant -= conf
		if (conf in map.lizard)
			map.lizard -= conf
		if (conf in map.crab)
			map.crab -= conf
		if (conf in map.wolfman)
			map.wolfman -= conf
	else if (choice == "Gorilla")
		map.gorilla += conf
		if (conf in map.orc)
			map.orc -= conf
		if (conf in map.human)
			map.human -= conf
		if (conf in map.ant)
			map.ant -= conf
		if (conf in map.lizard)
			map.lizard -= conf
		if (conf in map.crab)
			map.crab -= conf
		if (conf in map.wolfman)
			map.wolfman -= conf
	else if (choice == "Ant")
		map.ant += conf
		if (conf in map.orc)
			map.orc -= conf
		if (conf in map.human)
			map.human -= conf
		if (conf in map.gorilla)
			map.gorilla -= conf
		if (conf in map.lizard)
			map.lizard -= conf
		if (conf in map.crab)
			map.crab -= conf
		if (conf in map.wolfman)
			map.wolfman -= conf
	else if (choice == "Lizard")
		map.lizard += conf
		if (conf in map.orc)
			map.orc -= conf
		if (conf in map.human)
			map.human -= conf
		if (conf in map.gorilla)
			map.gorilla -= conf
		if (conf in map.ant)
			map.ant -= conf
		if (conf in map.crab)
			map.crab -= conf
		if (conf in map.wolfman)
			map.wolfman -= conf
	else if (choice == "Wolfman")
		map.wolfman += conf
		if (conf in map.orc)
			map.orc -= conf
		if (conf in map.human)
			map.human -= conf
		if (conf in map.gorilla)
			map.gorilla -= conf
		if (conf in map.ant)
			map.ant -= conf
		if (conf in map.lizard)
			map.lizard -= conf
		if (conf in map.crab)
			map.crab -= conf
		if (conf in map.wolfman)
			map.wolfman -= conf
	else if (choice == "Crab")
		map.crab += conf
		if (conf in map.orc)
			map.orc -= conf
		if (conf in map.human)
			map.human -= conf
		if (conf in map.gorilla)
			map.gorilla -= conf
		if (conf in map.ant)
			map.ant -= conf
		if (conf in map.lizard)
			map.lizard -= conf
		if (conf in map.wolfman)
			map.wolfman -= conf
	message_admins("[key_name(src)] changed the [conf] to [choice].", key_name(src))
	log_admin("[key_name(src)] changed the [conf] to [choice].")
	return

var/civilians_toggled = TRUE
var/british_toggled = TRUE
var/pirates_toggled = TRUE
var/indians_toggled = TRUE
var/french_toggled = TRUE
var/spanish_toggled = TRUE
var/portuguese_toggled = TRUE
var/dutch_toggled = TRUE
var/roman_toggled = TRUE
var/greek_toggled = TRUE
var/arab_toggled = TRUE
var/japanese_toggled = TRUE
var/russian_toggled = TRUE
var/chechen_toggled = TRUE
var/finnish_toggled = TRUE
var/norwegian_toggled = TRUE
var/swedish_toggled = TRUE
var/danish_toggled = TRUE
var/german_toggled = TRUE
var/american_toggled = TRUE
var/vietnamese_toggled = TRUE
var/chinese_toggled = TRUE
var/filipino_toggled = TRUE
var/polish_toggled = TRUE
var/italian_toggled = TRUE

/client/proc/toggle_factions()
	set name = "Toggle Factions"
	set category = "Special"

	if (!check_rights(R_ADMIN))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return

	var/list/choices = list()

	choices += "CIVILIAN ([civilians_toggled ? "ENABLED" : "DISABLED"])"
	choices += "BRITISH ([british_toggled ? "ENABLED" : "DISABLED"])"
	choices += "PIRATES ([pirates_toggled ? "ENABLED" : "DISABLED"])"
	choices += "PORTUGUESE ([portuguese_toggled ? "ENABLED" : "DISABLED"])"
	choices += "FRENCH ([french_toggled ? "ENABLED" : "DISABLED"])"
	choices += "SPANISH ([spanish_toggled ? "ENABLED" : "DISABLED"])"
	choices += "DUTCH ([dutch_toggled ? "ENABLED" : "DISABLED"])"
	choices += "INDIANS ([indians_toggled ? "ENABLED" : "DISABLED"])"
	choices += "ROMAN ([roman_toggled ? "ENABLED" : "DISABLED"])"
	choices += "GREEK ([greek_toggled ? "ENABLED" : "DISABLED"])"
	choices += "ARAB ([arab_toggled ? "ENABLED" : "DISABLED"])"
	choices += "JAPANESE ([japanese_toggled ? "ENABLED" : "DISABLED"])"
	choices += "RUSSIAN ([russian_toggled ? "ENABLED" : "DISABLED"])"
	choices += "CHECHEN ([chechen_toggled ? "ENABLED" : "DISABLED"])"
	choices += "FINNISH ([finnish_toggled ? "ENABLED" : "DISABLED"])"
	choices += "NORWEGIAN ([norwegian_toggled ? "ENABLED" : "DISABLED"])"
	choices += "SWEDISH ([swedish_toggled ? "ENABLED" : "DISABLED"])"
	choices += "DANISH ([danish_toggled ? "ENABLED" : "DISABLED"])"
	choices += "GERMAN ([german_toggled ? "ENABLED" : "DISABLED"])"
	choices += "AMERICAN ([american_toggled ? "ENABLED" : "DISABLED"])"
	choices += "VIETNAMESE ([vietnamese_toggled ? "ENABLED" : "DISABLED"])"
	choices += "CHINESE ([chinese_toggled ? "ENABLED" : "DISABLED"])"
	choices += "FILIPINO ([filipino_toggled ? "ENABLED" : "DISABLED"])"
	choices += "POLISH ([polish_toggled ? "ENABLED" : "DISABLED"])"
	choices += "ITALIAN ([italian_toggled ? "ENABLED" : "DISABLED"])"
	choices += "CANCEL"

	var/choice = input("Enable/Disable what faction?") in choices

	if (choice == "CANCEL")
		return

	else if (findtext(choice, "CIVILIAN"))
		civilians_toggled = !civilians_toggled
		world << "<span class = 'warning'>The Civilian faction has been [civilians_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Civilian faction 'enabled' setting to [civilians_toggled].", key_name(src))
	else if (findtext(choice, "BRITISH"))
		british_toggled = !british_toggled
		world << "<span class = 'warning'>The British has been [british_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the British faction 'enabled' setting to [british_toggled].", key_name(src))
	else if (findtext(choice, "PIRATES"))
		pirates_toggled = !pirates_toggled
		world << "<span class = 'warning'>The Pirate faction has been [pirates_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Pirate faction 'enabled' setting to [pirates_toggled].", key_name(src))
	else if (findtext(choice, "INDIANS"))
		indians_toggled = !indians_toggled
		world << "<span class = 'warning'>The Native faction has been [indians_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Native faction 'enabled' setting to [indians_toggled].", key_name(src))
	else if (findtext(choice, "PORTUGUESE"))
		portuguese_toggled = !portuguese_toggled
		world << "<span class = 'warning'>The Portuguese faction has been [portuguese_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Portuguese faction 'enabled' setting to [portuguese_toggled].", key_name(src))
	else if (findtext(choice, "SPANISH"))
		spanish_toggled = !spanish_toggled
		world << "<span class = 'warning'>The Spanish faction has been [spanish_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Spanish faction 'enabled' setting to [spanish_toggled].", key_name(src))
	else if (findtext(choice, "FRENCH"))
		french_toggled = !french_toggled
		world << "<span class = 'warning'>The French faction has been [french_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the French faction 'enabled' setting to [french_toggled].", key_name(src))
	else if (findtext(choice, "DUTCH"))
		dutch_toggled = !dutch_toggled
		world << "<span class = 'warning'>The Dutch faction has been [dutch_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Dutch faction 'enabled' setting to [dutch_toggled].", key_name(src))
	else if (findtext(choice, "JAPANESE"))
		japanese_toggled = !japanese_toggled
		world << "<span class = 'warning'>The Japanese faction has been [japanese_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Japanese faction 'enabled' setting to [japanese_toggled].", key_name(src))
	else if (findtext(choice, "RUSSIAN"))
		russian_toggled = !russian_toggled
		world << "<span class = 'warning'>The Russian faction has been [russian_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Russian faction 'enabled' setting to [russian_toggled].", key_name(src))
	else if (findtext(choice, "CHECHEN"))
		chechen_toggled = !chechen_toggled
		world << "<span class = 'warning'>The Chechen faction has been [chechen_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Chechen faction 'enabled' setting to [chechen_toggled].", key_name(src))
	else if (findtext(choice, "FINNISH"))
		finnish_toggled = !finnish_toggled
		world << "<span class = 'warning'>The Finnish faction has been [finnish_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Finnish faction 'enabled' setting to [finnish_toggled].", key_name(src))
	else if (findtext(choice, "NORWEGIAN"))
		finnish_toggled = !finnish_toggled
		world << "<span class = 'warning'>The Norwegian faction has been [norwegian_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Norwegian faction 'enabled' setting to [norwegian_toggled].", key_name(src))
	else if (findtext(choice, "SWEDISH"))
		finnish_toggled = !finnish_toggled
		world << "<span class = 'warning'>The Swedish faction has been [swedish_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Swedish faction 'enabled' setting to [swedish_toggled].", key_name(src))
	else if (findtext(choice, "DANISH"))
		finnish_toggled = !finnish_toggled
		world << "<span class = 'warning'>The Danish faction has been [danish_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Finnish faction 'enabled' setting to [danish_toggled].", key_name(src))
	else if (findtext(choice, "ROMAN"))
		roman_toggled = !roman_toggled
		world << "<span class = 'warning'>The Roman faction has been [roman_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Roman faction 'enabled' setting to [roman_toggled].", key_name(src))
	else if (findtext(choice, "GREEK"))
		greek_toggled = !greek_toggled
		world << "<span class = 'warning'>The Greek faction has been [greek_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Greek faction 'enabled' setting to [greek_toggled].", key_name(src))
	else if (findtext(choice, "ARAB"))
		arab_toggled = !arab_toggled
		world << "<span class = 'warning'>The Arabic faction has been [arab_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Arabic faction 'enabled' setting to [arab_toggled].", key_name(src))
	else if (findtext(choice, "GERMAN"))
		german_toggled = !german_toggled
		world << "<span class = 'warning'>The German faction has been [german_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the German faction 'enabled' setting to [german_toggled].", key_name(src))
	else if (findtext(choice, "AMERICAN"))
		american_toggled = !american_toggled
		world << "<span class = 'warning'>The American faction has been [american_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the American faction 'enabled' setting to [american_toggled].", key_name(src))
	else if (findtext(choice, "VIETNAMESE"))
		vietnamese_toggled = !vietnamese_toggled
		world << "<span class = 'warning'>The Vietnamese faction has been [vietnamese_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Vietnamese faction 'enabled' setting to [vietnamese_toggled].", key_name(src))
	else if (findtext(choice, "CHINESE"))
		chinese_toggled = !chinese_toggled
		world << "<span class = 'warning'>The Chinese faction has been [chinese_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Chinese faction 'enabled' setting to [chinese_toggled].", key_name(src))
	else if (findtext(choice, "FILIPINO"))
		filipino_toggled = !filipino_toggled
		world << "<span class = 'warning'>The Filipino faction has been [filipino_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Filipino faction 'enabled' setting to [filipino_toggled].", key_name(src))
	else if (findtext(choice, "POLISH"))
		polish_toggled = !polish_toggled
		world << "<span class = 'warning'>The Polish faction has been [polish_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Polish faction 'enabled' setting to [polish_toggled].", key_name(src))
	else if (findtext(choice, "ITALIAN"))
		italian_toggled = !italian_toggled
		world << "<span class = 'warning'>The Italian faction has been [italian_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Italian faction 'enabled' setting to [italian_toggled].", key_name(src))

var/civilians_forceEnabled = FALSE
var/british_forceEnabled = FALSE
var/pirates_forceEnabled = FALSE
var/portuguese_forceEnabled = FALSE
var/spanish_forceEnabled = FALSE
var/french_forceEnabled = FALSE
var/indians_forceEnabled = FALSE
var/dutch_forceEnabled = FALSE
var/roman_forceEnabled = FALSE
var/greek_forceEnabled = FALSE
var/arab_forceEnabled = FALSE
var/japanese_forceEnabled = FALSE
var/russian_forceEnabled = FALSE
var/chechen_forceEnabled = FALSE
var/finnish_forceEnabled = FALSE
var/norwegian_forceEnabled = FALSE
var/swedish_forceEnabled = FALSE
var/danish_forceEnabled = FALSE
var/german_forceEnabled = FALSE
var/american_forceEnabled = FALSE
var/vietnamese_forceEnabled = FALSE
var/chinese_forceEnabled = FALSE
var/filipino_forceEnabled = FALSE
var/polish_forceEnabled = FALSE
var/italian_forceEnabled = FALSE

/client/proc/forcibly_enable_faction()
	set name = "Forcibly Enable Faction"
	set category = "Special"

	if (!check_rights(R_ADMIN))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return

	var/list/choices = list()

	choices += "CIVILIAN ([civilians_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "BRITISH ([british_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "PIRATES ([pirates_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "FRENCH ([french_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "DUTCH ([dutch_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "ITALIAN ([italian_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "INDIANS ([indians_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "PORTUGUESE ([portuguese_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "SPANISH ([spanish_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "GREEK ([greek_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "ROMAN ([roman_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "ARAB ([arab_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "JAPANESE ([japanese_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "RUSSIAN ([russian_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "CHECHEN ([chechen_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "FINNISH ([finnish_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "NORWEGIAN ([norwegian_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "SWEDISH ([swedish_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "DANISH ([danish_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "GERMAN ([german_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "AMERICAN ([american_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "VIETNAMESE ([vietnamese_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "CHINESE ([chinese_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "FILIPINO ([filipino_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "POLISH ([polish_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "CANCEL"

	var/choice = input("Enable/Disable what faction?") in choices

	if (choice == "CANCEL")
		return

	else if (findtext(choice, "CIVILIAN"))
		civilians_forceEnabled = !civilians_forceEnabled
		world << "<span class = 'notice'>The Civilian faction [civilians_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Civilian faction 'forceEnabled' setting to [civilians_forceEnabled].", key_name(src))
	else if (findtext(choice, "BRITISH"))
		british_forceEnabled = !british_forceEnabled
		world << "<span class = 'notice'>The British faction [british_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the British faction 'forceEnabled' setting to [british_forceEnabled].", key_name(src))
	else if (findtext(choice, "PIRATES"))
		pirates_forceEnabled = !pirates_forceEnabled
		world << "<span class = 'notice'>The Pirate faction [pirates_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Pirate faction 'forceEnabled' setting to [pirates_forceEnabled].", key_name(src))

	else if (findtext(choice, "SPANISH"))
		spanish_forceEnabled = !spanish_forceEnabled
		world << "<span class = 'notice'>The Spanish faction [spanish_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Spanish faction 'forceEnabled' setting to [spanish_forceEnabled].", key_name(src))
	else if (findtext(choice, "PORTUGUESE"))
		portuguese_forceEnabled = !portuguese_forceEnabled
		world << "<span class = 'notice'>The Portuguese faction [portuguese_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Portuguese faction 'forceEnabled' setting to [portuguese_forceEnabled].", key_name(src))
	else if (findtext(choice, "FRENCH"))
		french_forceEnabled = !french_forceEnabled
		world << "<span class = 'notice'>The French faction [french_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the French faction 'forceEnabled' setting to [french_forceEnabled].", key_name(src))
	else if (findtext(choice, "DUTCH"))
		dutch_forceEnabled = !dutch_forceEnabled
		world << "<span class = 'notice'>The Dutch faction [dutch_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Dutch faction 'forceEnabled' setting to [dutch_forceEnabled].", key_name(src))
	else if (findtext(choice, "ITALIAN"))
		italian_forceEnabled = !italian_forceEnabled
		world << "<span class = 'notice'>The Italian faction [italian_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Italian faction 'forceEnabled' setting to [italian_forceEnabled].", key_name(src))
	else if (findtext(choice, "JAPANESE"))
		japanese_forceEnabled = !japanese_forceEnabled
		world << "<span class = 'notice'>The Japanese faction [japanese_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Japanese faction 'forceEnabled' setting to [japanese_forceEnabled].", key_name(src))
	else if (findtext(choice, "RUSSIAN"))
		russian_forceEnabled = !russian_forceEnabled
		world << "<span class = 'notice'>The Russian faction [russian_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Russian faction 'forceEnabled' setting to [russian_forceEnabled].", key_name(src))

	else if (findtext(choice, "CHECHEN"))
		chechen_forceEnabled = !chechen_forceEnabled
		world << "<span class = 'notice'>The Chechen faction [chechen_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Chechen faction 'forceEnabled' setting to [chechen_forceEnabled].", key_name(src))

	else if (findtext(choice, "FINNISH"))
		finnish_forceEnabled = !finnish_forceEnabled
		world << "<span class = 'notice'>The Finnish faction [finnish_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Finnish faction 'forceEnabled' setting to [finnish_forceEnabled].", key_name(src))

	else if (findtext(choice, "NORWEGIAN"))
		norwegian_forceEnabled = !norwegian_forceEnabled
		world << "<span class = 'notice'>The Norwegian faction [norwegian_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Norwegian faction 'forceEnabled' setting to [norwegian_forceEnabled].", key_name(src))

	else if (findtext(choice, "SWEDISH"))
		swedish_forceEnabled = !swedish_forceEnabled
		world << "<span class = 'notice'>The Swedish faction [swedish_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Swedish faction 'forceEnabled' setting to [swedish_forceEnabled].", key_name(src))

	else if (findtext(choice, "DANISH"))
		danish_forceEnabled = !danish_forceEnabled
		world << "<span class = 'notice'>The Danish faction [danish_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Danish faction 'forceEnabled' setting to [danish_forceEnabled].", key_name(src))

	else if (findtext(choice, "INDIANS"))
		indians_forceEnabled = !indians_forceEnabled
		world << "<span class = 'notice'>The Native faction [indians_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Native faction 'forceEnabled' setting to [indians_forceEnabled].", key_name(src))
	else if (findtext(choice, "ROMAN"))
		roman_forceEnabled = !roman_forceEnabled
		world << "<span class = 'notice'>The Roman faction [roman_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Roman faction 'forceEnabled' setting to [roman_forceEnabled].", key_name(src))
	else if (findtext(choice, "GREEK"))
		greek_forceEnabled = !greek_forceEnabled
		world << "<span class = 'notice'>The Greek faction [greek_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Greek faction 'forceEnabled' setting to [greek_forceEnabled].", key_name(src))
	else if (findtext(choice, "ARAB"))
		arab_forceEnabled = arab_forceEnabled
		world << "<span class = 'notice'>The Arabic faction [arab_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Arabic faction 'forceEnabled' setting to [arab_forceEnabled].", key_name(src))
	else if (findtext(choice, "GERMAN"))
		german_forceEnabled = german_forceEnabled
		world << "<span class = 'notice'>The German faction [german_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the German faction 'forceEnabled' setting to [german_forceEnabled].", key_name(src))
	else if (findtext(choice, "AMERICAN"))
		american_forceEnabled = american_forceEnabled
		world << "<span class = 'notice'>The American faction [american_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the American faction 'forceEnabled' setting to [american_forceEnabled].", key_name(src))
	else if (findtext(choice, "VIETNAMESE"))
		vietnamese_forceEnabled = vietnamese_forceEnabled
		world << "<span class = 'notice'>The Vietnamese faction [vietnamese_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Vietnamese faction 'forceEnabled' setting to [vietnamese_forceEnabled].", key_name(src))
	else if (findtext(choice, "CHINESE"))
		chinese_forceEnabled = !chinese_forceEnabled
		world << "<span class = 'notice'>The Chinese faction [chinese_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Chinese faction 'forceEnabled' setting to [chinese_forceEnabled].", key_name(src))
	else if (findtext(choice, "FILIPINO"))
		filipino_forceEnabled = !filipino_forceEnabled
		world << "<span class = 'notice'>The Filipino faction [filipino_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Filipino faction 'forceEnabled' setting to [filipino_forceEnabled].", key_name(src))
	else if (findtext(choice, "POLISH"))
		polish_forceEnabled = !polish_forceEnabled
		world << "<span class = 'notice'>The Polish faction [polish_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Polishfaction 'forceEnabled' setting to [polish_forceEnabled].", key_name(src))

/client/proc/toggle_respawn_delays()
	set category = "Special"
	set name = "Toggle Respawn Delays"
	config.no_respawn_delays = !config.no_respawn_delays
	var/M = "[key_name(src)] [config.no_respawn_delays ? "disabled" : "enabled"] respawn delays."
	message_admins(M, key_name(src))
	log_admin(M)
	world << "<font size = 3><span class = 'notice'>Respawn delays are now <b>[config.no_respawn_delays ? "disabled" : "enabled"]</b>.</span></font>"



/client/proc/show_battle_report()
	set category = "Special"
	set name = "Show Battle Report"

	if (!processes.battle_report || !processes.battle_report.fires_at_gamestates.Find(ticker.current_state))
		src << "<span class = 'warning'>You can't send a battle report right now.</span>"
		return

	// to prevent showing multiple battle reports - Kachnov
	if (processes.battle_report)
		message_admins("[key_name(src)] showed everyone the battle report.", key_name(src))
		processes.battle_report.BR_ticks = processes.battle_report.max_BR_ticks
	else
		show_global_battle_report(src)

/client/proc/see_battle_report()
	set category = "Special"
	set name = "See Battle Report"
	if (!processes.battle_report || !processes.battle_report.fires_at_gamestates.Find(ticker.current_state))
		src << "<span class = 'warning'>You can't see the battle report right now.</span>"
		return
	show_global_battle_report(src, TRUE)

/proc/show_global_battle_report(var/shower, var/private = FALSE)

	var/total_pirates = alive_pirates.len + dead_pirates.len + heavily_injured_pirates.len
	var/total_british = alive_british.len + dead_british.len + heavily_injured_british.len
	var/total_civilians = alive_civilians.len + dead_civilians.len + heavily_injured_civilians.len
	var/total_spanish = alive_spanish.len + dead_spanish.len + heavily_injured_spanish.len
	var/total_indians = alive_indians.len + dead_indians.len + heavily_injured_indians.len
	var/total_french = alive_french.len + dead_french.len + heavily_injured_french.len
	var/total_portuguese = alive_portuguese.len + dead_portuguese.len + heavily_injured_portuguese.len
	var/total_dutch = alive_dutch.len + dead_dutch.len + heavily_injured_dutch.len
	var/total_roman = alive_roman.len + dead_roman.len + heavily_injured_roman.len
	var/total_greek = alive_greek.len + dead_greek.len + heavily_injured_greek.len
	var/total_arab = alive_arab.len + dead_arab.len + heavily_injured_arab.len
	var/total_japanese = alive_japanese.len + dead_japanese.len + heavily_injured_japanese.len
	var/total_russian = alive_russian.len + dead_russian.len + heavily_injured_russian.len
	var/total_chechen = alive_chechen.len + dead_chechen.len + heavily_injured_chechen.len
	var/total_finnish = alive_finnish.len + dead_finnish.len + heavily_injured_finnish.len
	var/total_norwegian = alive_norwegian.len + dead_norwegian.len + heavily_injured_norwegian.len
	var/total_swedish = alive_swedish.len + dead_swedish.len + heavily_injured_swedish.len
	var/total_danish = alive_danish.len + dead_danish.len + heavily_injured_danish.len
	var/total_german = alive_german.len + dead_german.len + heavily_injured_german.len
	var/total_american = alive_american.len + dead_american.len + heavily_injured_american.len
	var/total_vietnamese = alive_vietnamese.len + dead_vietnamese.len + heavily_injured_vietnamese.len
	var/total_chinese = alive_chinese.len + dead_chinese.len + heavily_injured_chinese.len
	var/total_filipino = alive_filipino.len + dead_filipino.len + heavily_injured_filipino.len
	var/total_polish = alive_polish.len + dead_polish.len + heavily_injured_polish.len
	var/total_italian = alive_italian.len + dead_italian.len + heavily_injured_italian.len

	var/mortality_coefficient_pirates = 0
	var/mortality_coefficient_british = 0
	var/mortality_coefficient_spanish = 0
	var/mortality_coefficient_portuguese = 0
	var/mortality_coefficient_french = 0
	var/mortality_coefficient_indians = 0
	var/mortality_coefficient_civilian = 0
	var/mortality_coefficient_greek = 0
	var/mortality_coefficient_dutch = 0
	var/mortality_coefficient_roman = 0
	var/mortality_coefficient_arab = 0
	var/mortality_coefficient_japanese = 0
	var/mortality_coefficient_russian = 0
	var/mortality_coefficient_chechen = 0
	var/mortality_coefficient_finnish = 0
	var/mortality_coefficient_norwegian = 0
	var/mortality_coefficient_swedish = 0
	var/mortality_coefficient_danish = 0
	var/mortality_coefficient_german = 0
	var/mortality_coefficient_american = 0
	var/mortality_coefficient_vietnamese = 0
	var/mortality_coefficient_chinese = 0
	var/mortality_coefficient_filipino = 0
	var/mortality_coefficient_polish = 0
	var/mortality_coefficient_italian = 0

	if (dead_british.len > 0)
		mortality_coefficient_british = dead_british.len/total_british

	if (dead_pirates.len > 0)
		mortality_coefficient_pirates = dead_pirates.len/total_pirates

	if (dead_indians.len > 0)
		mortality_coefficient_indians = dead_indians.len/total_indians

	if (dead_spanish.len > 0)
		mortality_coefficient_spanish = dead_spanish.len/total_spanish

	if (dead_portuguese.len > 0)
		mortality_coefficient_portuguese = dead_portuguese.len/total_portuguese

	if (dead_french.len > 0)
		mortality_coefficient_french = dead_french.len/total_french

	if (dead_civilians.len > 0)
		mortality_coefficient_civilian = dead_civilians.len/total_civilians

	if (dead_dutch.len > 0)
		mortality_coefficient_dutch = dead_dutch.len/total_dutch

	if (dead_greek.len > 0)
		mortality_coefficient_greek = dead_greek.len/total_greek

	if (dead_roman.len > 0)
		mortality_coefficient_roman = dead_roman.len/total_roman

	if (dead_arab.len > 0)
		mortality_coefficient_arab = dead_arab.len/total_arab

	if (dead_japanese.len > 0)
		mortality_coefficient_japanese = dead_japanese.len/total_japanese

	if (dead_russian.len > 0)
		mortality_coefficient_russian = dead_russian.len/total_russian

	if (dead_chechen.len > 0)
		mortality_coefficient_chechen = dead_chechen.len/total_chechen

	if (dead_finnish.len > 0)
		mortality_coefficient_finnish = dead_finnish.len/total_finnish

	if (dead_norwegian.len > 0)
		mortality_coefficient_norwegian = dead_norwegian.len/total_norwegian

	if (dead_swedish.len > 0)
		mortality_coefficient_swedish = dead_swedish.len/total_swedish

	if (dead_danish.len > 0)
		mortality_coefficient_danish = dead_danish.len/total_danish

	if (dead_german.len > 0)
		mortality_coefficient_german = dead_german.len/total_german

	if (dead_american.len > 0)
		mortality_coefficient_american = dead_american.len/total_american

	if (dead_vietnamese.len > 0)
		mortality_coefficient_vietnamese = dead_vietnamese.len/total_vietnamese

	if (dead_chinese.len > 0)
		mortality_coefficient_chinese = dead_chinese.len/total_chinese

	if (dead_filipino.len > 0)
		mortality_coefficient_filipino = dead_filipino.len/total_filipino

	if (dead_polish.len > 0)
		mortality_coefficient_polish = dead_polish.len/total_polish
	
	if (dead_italian.len > 0)
		mortality_coefficient_italian = dead_italian.len/total_italian

	var/mortality_british = round(mortality_coefficient_british*100)
	var/mortality_pirates = round(mortality_coefficient_pirates*100)
	var/mortality_civilian = round(mortality_coefficient_civilian*100)
	var/mortality_french = round(mortality_coefficient_french*100)
	var/mortality_spanish = round(mortality_coefficient_spanish*100)
	var/mortality_portuguese = round(mortality_coefficient_portuguese*100)
	var/mortality_indians = round(mortality_coefficient_indians*100)
	var/mortality_dutch = round(mortality_coefficient_dutch*100)
	var/mortality_roman = round(mortality_coefficient_roman*100)
	var/mortality_greek = round(mortality_coefficient_greek*100)
	var/mortality_arab = round(mortality_coefficient_arab*100)
	var/mortality_japanese = round(mortality_coefficient_japanese*100)
	var/mortality_russian = round(mortality_coefficient_russian*100)
	var/mortality_chechen = round(mortality_coefficient_chechen*100)
	var/mortality_finnish = round(mortality_coefficient_finnish*100)
	var/mortality_norwegian = round(mortality_coefficient_norwegian*100)
	var/mortality_swedish = round(mortality_coefficient_swedish*100)
	var/mortality_danish = round(mortality_coefficient_danish*100)
	var/mortality_german = round(mortality_coefficient_german*100)
	var/mortality_american = round(mortality_coefficient_american*100)
	var/mortality_vietnamese = round(mortality_coefficient_vietnamese*100)
	var/mortality_chinese = round(mortality_coefficient_chinese*100)
	var/mortality_filipino = round(mortality_coefficient_filipino*100)
	var/mortality_polish = round(mortality_coefficient_polish*100)
	var/mortality_italian = round(mortality_coefficient_italian*100)

	var/fact1 = "British"
	var/fact2 = "Pirates"
	var/fact3 = "Civilians"
	var/fact4 = "Spanish"
	var/fact5 = "Portuguese"
	var/fact6 = "French"
	var/fact7 = "Natives"
	var/fact8 = "Dutch"
	var/fact9 = "Romans"
	var/fact10 = "Greeks"
	var/fact11 = "Arabs"
	var/fact12 = "Japanese"
	var/fact13 = "Russians"
	var/fact14 = "Germans"
	var/fact15 = "Americans"
	var/fact16 = "Vietnamese"
	var/fact17 = "Chinese"
	var/fact18 = "Filipino"
	var/fact19 = "Chechen"
	var/fact20 = "Finnish"
	var/fact21 = "Norwegian"
	var/fact22 = "Swedish"
	var/fact23 = "Danish"
	var/fact24 = "Polish"
	var/fact25 = "Italian"

	if (map.ID == MAP_CAMPAIGN)
		fact2 = "Redmenia"
		fact3 = "Blugoslavia"
	else if (map.ID == MAP_ROTSTADT)
		fact2 = "Rotstadt People's Republic"
		fact3 = "Blugoslavian Armed Forces"
	else if (map.ID == MAP_WHITERUN)
		fact3 = "Stormcloaks"
		fact9 = "Imperials"
	else if (map.ID == MAP_CLASH)
		fact21 = "Bear Clan"
		fact23 = "Raven Clan"
	else if (map.ID == MAP_MISSIONARY_RIDGE)
		fact3 = "Confederate Army"
		fact15 = "Union Army"
	else if (map.ID == MAP_RUHR_UPRISING)
		fact3 = "Ruhr Red Army"
	else if (map.ID == MAP_SIBERSYN || map.ID == MAP_TSARITSYN)
		fact3 = "Red Army"
		fact13 = "White Army"
	else if (map.ID == MAP_KANDAHAR || map.ID == MAP_MAGISTRAL || map.ID == MAP_HILL_3234)
		fact3 = "DRA and Civilians"
		fact11 = "Mujahideen"
	else if (map.ID == MAP_HOSTAGES || map.ID == MAP_ARAB_TOWN_2)
		fact11 = "Insurgents"
	else if (map.ID == MAP_ARAB_TOWN)
		fact11 = "Hezbollah"
		fact15 = "IDF"
	else if (map.ID == MAP_CAPITOL_HILL)
		fact3 = "Militia"
		fact15 = "Government"
	else if (map.ID == MAP_GROZNY)
		fact13 = "Russian Federal Forces"
	else if (map.ID == MAP_YELTSIN)
		fact3 = "Militia"
		fact13 = "Russian Army"
	else if (map.ID == MAP_WACO)
		fact3 = "Davidians"
		fact15 = "ATF"
	else if (map.ID == MAP_BANK_ROBBERY)
		fact3 = "Police"
		fact13 = "Robbers"
	else if (map.ID == MAP_DRUG_BUST)
		fact3 = "Police"
		fact13 = "Rednikov"
	else if (map.ID == MAP_TANTIVEIV)
		fact3 = "Rebels"
		fact15 = "Empire"
	else if (map.ID == MAP_TADOJSVILLE)
		fact3 = "UN Soldiers"
		fact7 = "Mercenaries"
	else if (map.ID == MAP_EFT_FACTORY)
		fact3 = "Scavs"
		fact13 = "BEAR"
		fact15 = "USEC"
	else if (map.ID == MAP_SYRIA)
		fact11 = "Syrian Arab Republic"
		fact15 = "Free Syrian Army"
	else if (map.ID == MAP_EAST_LOS_SANTOS)
		fact7 = "Ballas"
		fact17 = "Grove Street"
	else if (map.ordinal_age >= 6 && map.ordinal_age < 8)
		fact13 = "Soviets"

	var/msg1 = "[fact1]: [alive_british.len] alive, [heavily_injured_british.len] heavily injured or unconscious, [dead_british.len] deceased. Mortality rate: [mortality_british]%"
	var/msg2 = "[fact2]: [alive_pirates.len] alive, [heavily_injured_pirates.len] heavily injured or unconscious, [dead_pirates.len] deceased. Mortality rate: [mortality_pirates]%"
	var/msg3 = "[fact3]: [alive_civilians.len] alive, [heavily_injured_civilians.len] heavily injured or unconscious, [dead_civilians.len] deceased. Mortality rate: [mortality_civilian]%"
	var/msg4 = "[fact4]: [alive_spanish.len] alive, [heavily_injured_spanish.len] heavily injured or unconscious, [dead_spanish.len] deceased. Mortality rate: [mortality_spanish]%"
	var/msg5 = "[fact5]: [alive_portuguese.len] alive, [heavily_injured_portuguese.len] heavily injured or unconscious, [dead_portuguese.len] deceased. Mortality rate: [mortality_portuguese]%"
	var/msg6 = "[fact6]: [alive_french.len] alive, [heavily_injured_french.len] heavily injured or unconscious, [dead_french.len] deceased. Mortality rate: [mortality_french]%"
	var/msg8 = "[fact8]: [alive_dutch.len] alive, [heavily_injured_dutch.len] heavily injured or unconscious, [dead_dutch.len] deceased. Mortality rate: [mortality_dutch]%"
	var/msg7 = "[fact7]: [alive_indians.len] alive, [heavily_injured_indians.len] heavily injured or unconscious, [dead_indians.len] deceased. Mortality rate: [mortality_indians]%"
	var/msg9 = "[fact9]: [alive_roman.len] alive, [heavily_injured_roman.len] heavily injured or unconscious, [dead_roman.len] deceased. Mortality rate: [mortality_roman]%"
	var/msg10 = "[fact10]: [alive_greek.len] alive, [heavily_injured_greek.len] heavily injured or unconscious, [dead_greek.len] deceased. Mortality rate: [mortality_greek]%"
	var/msg11 = "[fact11]: [alive_arab.len] alive, [heavily_injured_arab.len] heavily injured or unconscious, [dead_arab.len] deceased. Mortality rate: [mortality_arab]%"
	var/msg12 = "[fact12]: [alive_japanese.len] alive, [heavily_injured_japanese.len] heavily injured or unconscious, [dead_japanese.len] deceased. Mortality rate: [mortality_japanese]%"
	var/msg13 = "[fact13]: [alive_russian.len] alive, [heavily_injured_russian.len] heavily injured or unconscious, [dead_russian.len] deceased. Mortality rate: [mortality_russian]%"
	var/msg14 = "[fact14]: [alive_german.len] alive, [heavily_injured_german.len] heavily injured or unconscious, [dead_german.len] deceased. Mortality rate: [mortality_german]%"
	var/msg15 = "[fact15]: [alive_american.len] alive, [heavily_injured_american.len] heavily injured or unconscious, [dead_american.len] deceased. Mortality rate: [mortality_american]%"
	var/msg16 = "[fact16]: [alive_vietnamese.len] alive, [heavily_injured_vietnamese.len] heavily injured or unconscious, [dead_vietnamese.len] deceased. Mortality rate: [mortality_vietnamese]%"
	var/msg17 = "[fact17]: [alive_chinese.len] alive, [heavily_injured_chinese.len] heavily injured or unconscious, [dead_chinese.len] deceased. Mortality rate: [mortality_chinese]%"
	var/msg18 = "[fact18]: [alive_filipino.len] alive, [heavily_injured_filipino.len] heavily injured or unconscious, [dead_filipino.len] deceased. Mortality rate: [mortality_filipino]%"
	var/msg19 = "[fact19]: [alive_chechen.len] alive, [heavily_injured_chechen.len] heavily injured or unconscious, [dead_chechen.len] deceased. Mortality rate: [mortality_chechen]%"
	var/msg20 = "[fact20]: [alive_finnish.len] alive, [heavily_injured_finnish.len] heavily injured or unconscious, [dead_finnish.len] deceased. Mortality rate: [mortality_finnish]%"
	var/msg21 = "[fact21]: [alive_norwegian.len] alive, [heavily_injured_norwegian.len] heavily injured or unconscious, [dead_norwegian.len] deceased. Mortality rate: [mortality_norwegian]%"
	var/msg22 = "[fact22]: [alive_swedish.len] alive, [heavily_injured_swedish.len] heavily injured or unconscious, [dead_swedish.len] deceased. Mortality rate: [mortality_swedish]%"
	var/msg23 = "[fact23]: [alive_danish.len] alive, [heavily_injured_danish.len] heavily injured or unconscious, [dead_danish.len] deceased. Mortality rate: [mortality_danish]%"
	var/msg24 = "[fact24]: [alive_polish.len] alive, [heavily_injured_polish.len] heavily injured or unconscious, [dead_polish.len] deceased. Mortality rate: [mortality_polish]%"
	var/msg25 = "[fact25]: [alive_italian.len] alive, [heavily_injured_italian.len] heavily injured or unconscious, [dead_italian.len] deceased. Mortality rate: [mortality_italian]%"

	var/msg_npcs = "NPCs: [faction1_npcs] americans alive, [faction2_npcs] japanese alive."

	var/msg_companies= ""
	var/relpc = ""
	var/relpc_am = 0
	if (map && map.civilizations)
		for (var/rel in map.custom_company_value)
			if (map.custom_company_value[rel] > relpc_am)
				relpc = rel
				relpc_am = map.custom_company_value[rel]
	if (relpc_am > 0 && relpc != "")
		msg_companies = "<b>Richest Company:</b> [relpc]"


	var/msg_religions = ""
	var/relp = ""
	var/relp_am = 0
	if (map && map.civilizations)
		for (var/rel in map.custom_religions)
			if (map.custom_religions[rel][3] > relp_am)
				relp = rel
				relp_am = map.custom_religions[rel][3]
	if (relp_am > 0 && relp != "")
		msg_religions = "<b>Most Powerful Religion:</b> [relp]"

	var/msg_factions = ""
	var/relpf = ""
	var/relpf_max = 0
	if (map && map.civilizations && map.ID != MAP_NATIONSRP && map.ID != MAP_NATIONSRP_TRIPLE && map.ID != MAP_NATIONSRPMED && map.ID != MAP_NATIONSRP_WW2 && map.ID != MAP_NATIONSRP_COLDWAR && map.ID != MAP_NATIONSRP_COLDWAR_CAMPAIGN && map.ID != MAP_NOMADS_PERSISTENCE_BETA)
		map.facl = list()
		for (var/i=1,i<=map.custom_faction_nr.len,i++)
			var/nu = 0
			map.facl += list(map.custom_faction_nr[i] = nu)

		for (var/relf in map.facl)
			var/curr = ""
			map.facl[relf] = 0
			for (var/mob/living/human/H in world)
				if (relf == H.civilization)
					map.facl[relf] += 1
					curr = "[H.civilization]"
			if (map.facl[relf] > relpf_max)
				relpf = "[curr]"
				relpf_max = map.facl[relf]

		if (relpf_max > 0 && relpf != "")
			msg_factions = "<b>Largest Faction:</b> [relpf]"

	if (map && !map.faction_organization.Find(BRITISH))
		msg1 = null
	if (map && !map.faction_organization.Find(PIRATES))
		msg2 = null
	if (map && !map.faction_organization.Find(CIVILIAN))
		msg3 = null
	if (map && !map.faction_organization.Find(SPANISH))
		msg4 = null
	if (map && !map.faction_organization.Find(PORTUGUESE))
		msg5 = null
	if (map && !map.faction_organization.Find(FRENCH))
		msg6 = null
	if (map && !map.faction_organization.Find(INDIANS))
		msg7 = null
	if (map && !map.faction_organization.Find(DUTCH))
		msg8 = null
	if (map && !map.faction_organization.Find(ROMAN))
		msg9 = null
	if (map && !map.faction_organization.Find(GREEK))
		msg10 = null
	if (map && !map.faction_organization.Find(ARAB))
		msg11 = null
	if (map && !map.faction_organization.Find(JAPANESE))
		msg12 = null
	if (map && !map.faction_organization.Find(RUSSIAN))
		msg13 = null
	if (map && !map.faction_organization.Find(GERMAN))
		msg14 = null
	if (map && !map.faction_organization.Find(AMERICAN))
		msg15 = null
	if (map && !map.faction_organization.Find(VIETNAMESE))
		msg16 = null
	if (map && !map.faction_organization.Find(CHINESE))
		msg17 = null
	if (map && !map.faction_organization.Find(FILIPINO))
		msg18 = null
	if (map && !map.faction_organization.Find(CHECHEN))
		msg19 = null
	if (map && !map.faction_organization.Find(FINNISH))
		msg20 = null
	if (map && !map.faction_organization.Find(NORWEGIAN))
		msg21 = null
	if (map && !map.faction_organization.Find(SWEDISH))
		msg22 = null
	if (map && !map.faction_organization.Find(DANISH))
		msg23 = null
	if (map && !map.faction_organization.Find(POLISH))
		msg24 = null
	if (map && !map.faction_organization.Find(ITALIAN))
		msg25 = null

	var/public = "Yes"

	if (shower && !private)
		public = WWinput(shower, "Show the report to the entire server?", "Battle Report", "Yes", list("Yes", "No"))
	else if (private)
		public = "No"

	if (public == "Yes")
		if (!shower || (input(shower, "Are you sure you want to show the battle report? Unless the Battle Controller Process died, it will happen automatically!", "Battle Report") in list ("Yes", "No")) == "Yes")
			world << "<font size=4>Status Report:</font>"

			if (msg1)
				world << "<font size=3>[msg1]</font>"
			if (msg2)
				world << "<font size=3>[msg2]</font>"
			if (msg3)
				world << "<font size=3>[msg3]</font>"
			if (msg4)
				world << "<font size=3>[msg4]</font>"
			if (msg5)
				world << "<font size=3>[msg5]</font>"
			if (msg6)
				world << "<font size=3>[msg6]</font>"
			if (msg7)
				world << "<font size=3>[msg7]</font>"
			if (msg8)
				world << "<font size=3>[msg8]</font>"
			if (msg9)
				world << "<font size=3>[msg9]</font>"
			if (msg10)
				world << "<font size=3>[msg10]</font>"
			if (msg11)
				world << "<font size=3>[msg11]</font>"
			if (msg12)
				world << "<font size=3>[msg12]</font>"
			if (msg13)
				world << "<font size=3>[msg13]</font>"
			if (msg14)
				world << "<font size=3>[msg14]</font>"
			if (msg15)
				world << "<font size=3>[msg15]</font>"
			if (msg16)
				world << "<font size=3>[msg16]</font>"
			if (msg17)
				world << "<font size=3>[msg17]</font>"
			if (msg18)
				world << "<font size=3>[msg18]</font>"
			if (msg19)
				world << "<font size=3>[msg19]</font>"
			if (msg20)
				world << "<font size=3>[msg20]</font>"
			if (msg21)
				world << "<font size=3>[msg21]</font>"
			if (msg22)
				world << "<font size=3>[msg22]</font>"
			if (msg23)
				world << "<font size=3>[msg23]</font>"
			if (msg24)
				world << "<font size=3>[msg24]</font>"
			if (msg25)
				world << "<font size=3>[msg25]</font>"
			if (map.civilizations && msg_religions != "")
				world << "<font size=3>[msg_religions]</font>"
			if (map.civilizations && msg_factions != "")
				world << "<font size=3>[msg_factions]</font>"
			if (map.civilizations && msg_companies != "")
				world << "<font size=3>[msg_companies]</font>"
			if (map.ID == MAP_IWO_JIMA)
				world << "<font size=3>[msg_npcs]</font>"
			if (shower)
				message_admins("[key_name(shower)] showed everyone the battle report.", key_name(shower))
			else
				message_admins("the <b>Battle Controller Process</b> showed everyone the battle report.")
	else
		if (msg1)
			shower << msg1
		if (msg2)
			shower << msg2
		if (msg3)
			shower << msg3
		if (msg4)
			shower << msg4
		if (msg5)
			shower << msg5
		if (msg6)
			shower << msg6
		if (msg7)
			shower << msg7
		if (msg8)
			shower << msg8
		if (msg9)
			shower << msg9
		if (msg10)
			shower << msg10
		if (msg11)
			shower << msg11
		if (msg12)
			shower << msg12
		if (msg13)
			shower << msg13
		if (msg14)
			shower << msg14
		if (msg15)
			shower << msg15
		if (msg16)
			shower << msg16
		if (msg17)
			shower << msg17
		if (msg18)
			shower << msg18
		if (msg19)
			shower << msg19
		if (msg20)
			shower << msg20
		if (msg21)
			shower << msg21
		if (msg22)
			shower << msg22
		if (msg23)
			shower << msg23
		if (msg24)
			shower << msg24
		if (msg25)
			shower << msg25