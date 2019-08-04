
/client/proc/toggle_playing()
	set category = "Special"
	set name = "Toggle Playing"

	ticker.players_can_join = !ticker.players_can_join
	world << "<big><b>You [(ticker.players_can_join) ? "can" : "can't"] join the game [(ticker.players_can_join) ? "now" : "anymore"].</b></big>"
	message_admins("[key_name(src)] changed the playing setting.")

// debugging
/client/proc/reset_roundstart_autobalance()
	set category = "Special"
	set name = "Reset Roundstart Autobalance"

	if (!check_rights(R_HOST) || (!check_rights(R_ADMIN)))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return

	var/_clients = input("How many clients?") as num

	job_master.admin_expected_clients = 0
	if (map.ID != MAP_TRIBES)
		map.availablefactions_run = TRUE
	job_master.toggle_roundstart_autobalance(_clients, announce = 2)
	job_master.admin_expected_clients = _clients

	message_admins("[key_name(src)] reset the roundstart autobalance for [_clients] players.")

/client/proc/end_all_grace_periods()
	set category = "Special"
	set name = "End All Grace Periods"
	var/conf = input(src, "Are you sure you want to end all grace periods?") in list("Yes", "No")
	if (conf == "Yes")
		map.admin_ended_all_grace_periods = TRUE
		message_admins("[key_name(src)] ended all grace periods!")
		log_admin("[key_name(src)] ended all grace periods.")

/client/proc/reset_all_grace_periods()
	set category = "Special"
	set name = "Reset All Grace Periods"
	var/conf = input(src, "Are you sure you want to reset all grace periods?") in list("Yes", "No")
	if (conf == "Yes")
		map.admin_ended_all_grace_periods = FALSE
		message_admins("[key_name(src)] reset all grace periods!")
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
	message_admins("[key_name(src)] changed the [conf] to [choice].")
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
var/german_toggled = TRUE
var/american_toggled = TRUE
var/vietnamese_toggled = TRUE
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
	choices += "GERMAN ([german_toggled ? "ENABLED" : "DISABLED"])"
	choices += "AMERICAN ([american_toggled ? "ENABLED" : "DISABLED"])"
	choices += "VIETNAMESE ([vietnamese_toggled ? "ENABLED" : "DISABLED"])"
	choices += "CANCEL"

	var/choice = input("Enable/Disable what faction?") in choices

	if (choice == "CANCEL")
		return

	else if (findtext(choice, "CIVILIAN"))
		civilians_toggled = !civilians_toggled
		world << "<span class = 'warning'>The Civilian faction has been [civilians_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Civilian faction 'enabled' setting to [civilians_toggled].")
	else if (findtext(choice, "BRITISH"))
		british_toggled = !british_toggled
		world << "<span class = 'warning'>The British has been [british_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the British faction 'enabled' setting to [british_toggled].")
	else if (findtext(choice, "PIRATES"))
		pirates_toggled = !pirates_toggled
		world << "<span class = 'warning'>The Pirate faction has been [pirates_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Pirate faction 'enabled' setting to [pirates_toggled].")
	else if (findtext(choice, "INDIANS"))
		indians_toggled = !indians_toggled
		world << "<span class = 'warning'>The Native faction has been [indians_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Native faction 'enabled' setting to [indians_toggled].")
	else if (findtext(choice, "PORTUGUESE"))
		portuguese_toggled = !portuguese_toggled
		world << "<span class = 'warning'>The Portuguese faction has been [portuguese_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Portuguese faction 'enabled' setting to [portuguese_toggled].")
	else if (findtext(choice, "SPANISH"))
		spanish_toggled = !spanish_toggled
		world << "<span class = 'warning'>The Spanish faction has been [spanish_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Spanish faction 'enabled' setting to [spanish_toggled].")
	else if (findtext(choice, "FRENCH"))
		french_toggled = !french_toggled
		world << "<span class = 'warning'>The French faction has been [french_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the French faction 'enabled' setting to [french_toggled].")
	else if (findtext(choice, "DUTCH"))
		dutch_toggled = !dutch_toggled
		world << "<span class = 'warning'>The Dutch faction has been [dutch_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Dutch faction 'enabled' setting to [dutch_toggled].")
	else if (findtext(choice, "JAPANESE"))
		dutch_toggled = !japanese_toggled
		world << "<span class = 'warning'>The Japanese faction has been [japanese_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Japanese faction 'enabled' setting to [japanese_toggled].")
	else if (findtext(choice, "RUSSIAN"))
		dutch_toggled = !russian_toggled
		world << "<span class = 'warning'>The Russian faction has been [russian_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Russian faction 'enabled' setting to [russian_toggled].")
	else if (findtext(choice, "ROMAN"))
		roman_toggled = !roman_toggled
		world << "<span class = 'warning'>The Roman faction has been [roman_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Roman faction 'enabled' setting to [roman_toggled].")
	else if (findtext(choice, "GREEK"))
		greek_toggled = !greek_toggled
		world << "<span class = 'warning'>The Greek faction has been [greek_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Greek faction 'enabled' setting to [greek_toggled].")
	else if (findtext(choice, "ARAB"))
		arab_toggled = !arab_toggled
		world << "<span class = 'warning'>The Arabic faction has been [arab_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Arabic faction 'enabled' setting to [arab_toggled].")
	else if (findtext(choice, "GERMAN"))
		german_toggled = !german_toggled
		world << "<span class = 'warning'>The German faction has been [german_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the German faction 'enabled' setting to [german_toggled].")
	else if (findtext(choice, "AMERICAN"))
		american_toggled = !american_toggled
		world << "<span class = 'warning'>The American faction has been [american_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the American faction 'enabled' setting to [american_toggled].")
	else if (findtext(choice, "VIETNAMESE"))
		vietnamese_toggled = !vietnamese_toggled
		world << "<span class = 'warning'>The Vietnamese faction has been [vietnamese_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Vietnamese faction 'enabled' setting to [vietnamese_toggled].")
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
var/german_forceEnabled = FALSE
var/american_forceEnabled = FALSE
var/vietnamese_forceEnabled = FALSE
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
	choices += "INDIANS ([indians_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "PORTUGUESE ([portuguese_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "SPANISH ([spanish_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "GREEK ([greek_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "ROMAN ([roman_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "ARAB ([arab_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "JAPANESE ([japanese_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "RUSSIAN ([russian_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "GERMAN ([german_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "AMERICAN ([american_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "VIETNAMESE ([vietnamese_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "CANCEL"

	var/choice = input("Enable/Disable what faction?") in choices

	if (choice == "CANCEL")
		return

	else if (findtext(choice, "CIVILIAN"))
		civilians_forceEnabled = !civilians_forceEnabled
		world << "<span class = 'notice'>The Civilian faction [civilians_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Civilian faction 'forceEnabled' setting to [civilians_forceEnabled].")
	else if (findtext(choice, "BRITISH"))
		british_forceEnabled = !british_forceEnabled
		world << "<span class = 'notice'>The British faction [british_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the British faction 'forceEnabled' setting to [british_forceEnabled].")
	else if (findtext(choice, "PIRATES"))
		pirates_forceEnabled = !pirates_forceEnabled
		world << "<span class = 'notice'>The Pirate faction [pirates_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Pirate faction 'forceEnabled' setting to [pirates_forceEnabled].")

	else if (findtext(choice, "SPANISH"))
		spanish_forceEnabled = !spanish_forceEnabled
		world << "<span class = 'notice'>The Spanish faction [spanish_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Spanish faction 'forceEnabled' setting to [spanish_forceEnabled].")
	else if (findtext(choice, "PORTUGUESE"))
		portuguese_forceEnabled = !portuguese_forceEnabled
		world << "<span class = 'notice'>The Portuguese faction [portuguese_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Portuguese faction 'forceEnabled' setting to [portuguese_forceEnabled].")
	else if (findtext(choice, "FRENCH"))
		french_forceEnabled = !french_forceEnabled
		world << "<span class = 'notice'>The French faction [french_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the French faction 'forceEnabled' setting to [french_forceEnabled].")
	else if (findtext(choice, "DUTCH"))
		dutch_forceEnabled = !dutch_forceEnabled
		world << "<span class = 'notice'>The Dutch faction [dutch_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Dutch faction 'forceEnabled' setting to [dutch_forceEnabled].")
	else if (findtext(choice, "JAPANESE"))
		japanese_forceEnabled = !japanese_forceEnabled
		world << "<span class = 'notice'>The Japanese faction [japanese_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Japanese faction 'forceEnabled' setting to [japanese_forceEnabled].")
	else if (findtext(choice, "RUSSIAN"))
		dutch_forceEnabled = !dutch_forceEnabled
		world << "<span class = 'notice'>The Russian faction [russian_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Russian faction 'forceEnabled' setting to [russian_forceEnabled].")
	else if (findtext(choice, "INDIANS"))
		indians_forceEnabled = !indians_forceEnabled
		world << "<span class = 'notice'>The Native faction [indians_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Native faction 'forceEnabled' setting to [indians_forceEnabled].")
	else if (findtext(choice, "ROMAN"))
		roman_forceEnabled = !roman_forceEnabled
		world << "<span class = 'notice'>The Roman faction [roman_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Roman faction 'forceEnabled' setting to [roman_forceEnabled].")
	else if (findtext(choice, "GREEK"))
		greek_forceEnabled = !greek_forceEnabled
		world << "<span class = 'notice'>The Greek faction [greek_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Greek faction 'forceEnabled' setting to [greek_forceEnabled].")
	else if (findtext(choice, "ARAB"))
		arab_forceEnabled = arab_forceEnabled
		world << "<span class = 'notice'>The Arabic faction [arab_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Arabic faction 'forceEnabled' setting to [arab_forceEnabled].")
	else if (findtext(choice, "GERMAN"))
		german_forceEnabled = german_forceEnabled
		world << "<span class = 'notice'>The German faction [german_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the German faction 'forceEnabled' setting to [german_forceEnabled].")
	else if (findtext(choice, "AMERICAN"))
		american_forceEnabled = american_forceEnabled
		world << "<span class = 'notice'>The American faction [american_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the American faction 'forceEnabled' setting to [american_forceEnabled].")
	else if (findtext(choice, "VIETNAMESE"))
		vietnamese_forceEnabled = vietnamese_forceEnabled
		world << "<span class = 'notice'>The Vietnamese faction [vietnamese_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Vietnamese faction 'forceEnabled' setting to [vietnamese_forceEnabled].")

/client/proc/toggle_respawn_delays()
	set category = "Special"
	set name = "Toggle Respawn Delays"
	config.no_respawn_delays = !config.no_respawn_delays
	var/M = "[key_name(src)] [config.no_respawn_delays ? "disabled" : "enabled"] respawn delays."
	message_admins(M)
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
		message_admins("[key_name(src)] showed everyone the battle report.")
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
	var/total_german = alive_german.len + dead_german.len + heavily_injured_german.len
	var/total_american = alive_american.len + dead_american.len + heavily_injured_american.len
	var/total_vietnamese = alive_vietnamese.len + dead_vietnamese.len + heavily_injured_vietnamese.len

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
	var/mortality_coefficient_german = 0
	var/mortality_coefficient_american = 0
	var/mortality_coefficient_vietnamese = 0

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

	if (dead_german.len > 0)
		mortality_coefficient_german = dead_german.len/total_german

	if (dead_american.len > 0)
		mortality_coefficient_american = dead_american.len/total_american

	if (dead_vietnamese.len > 0)
		mortality_coefficient_vietnamese = dead_vietnamese.len/total_vietnamese

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
	var/mortality_german = round(mortality_coefficient_german*100)
	var/mortality_american = round(mortality_coefficient_american*100)
	var/mortality_vietnamese = round(mortality_coefficient_vietnamese*100)

	var/msg1 = "British: [alive_british.len] alive, [heavily_injured_british.len] heavily injured or unconscious, [dead_british.len] deceased. Mortality rate: [mortality_british]%"
	var/msg2 = "Pirates: [alive_pirates.len] alive, [heavily_injured_pirates.len] heavily injured or unconscious, [dead_pirates.len] deceased. Mortality rate: [mortality_pirates]%"
	var/msg3 = "Civilians: [alive_civilians.len] alive, [heavily_injured_civilians.len] heavily injured or unconscious, [dead_civilians.len] deceased. Mortality rate: [mortality_civilian]%"
	var/msg4 = "Spanish: [alive_spanish.len] alive, [heavily_injured_spanish.len] heavily injured or unconscious, [dead_spanish.len] deceased. Mortality rate: [mortality_spanish]%"
	var/msg5 = "Portuguese: [alive_portuguese.len] alive, [heavily_injured_portuguese.len] heavily injured or unconscious, [dead_portuguese.len] deceased. Mortality rate: [mortality_portuguese]%"
	var/msg6 = "French: [alive_french.len] alive, [heavily_injured_french.len] heavily injured or unconscious, [dead_french.len] deceased. Mortality rate: [mortality_french]%"
	var/msg8 = "Dutch: [alive_dutch.len] alive, [heavily_injured_dutch.len] heavily injured or unconscious, [dead_dutch.len] deceased. Mortality rate: [mortality_dutch]%"
	var/msg7 = "Natives: [alive_indians.len] alive, [heavily_injured_indians.len] heavily injured or unconscious, [dead_indians.len] deceased. Mortality rate: [mortality_indians]%"
	var/msg9 = "Romans: [alive_roman.len] alive, [heavily_injured_roman.len] heavily injured or unconscious, [dead_roman.len] deceased. Mortality rate: [mortality_roman]%"
	var/msg10 = "Greeks: [alive_greek.len] alive, [heavily_injured_greek.len] heavily injured or unconscious, [dead_greek.len] deceased. Mortality rate: [mortality_greek]%"
	var/msg11 = "Arabs: [alive_arab.len] alive, [heavily_injured_arab.len] heavily injured or unconscious, [dead_arab.len] deceased. Mortality rate: [mortality_arab]%"
	var/msg12 = "Japanese: [alive_japanese.len] alive, [heavily_injured_japanese.len] heavily injured or unconscious, [dead_japanese.len] deceased. Mortality rate: [mortality_japanese]%"
	var/msg13 = "Russian: [alive_russian.len] alive, [heavily_injured_russian.len] heavily injured or unconscious, [dead_russian.len] deceased. Mortality rate: [mortality_russian]%"
	var/msg14 = "German: [alive_german.len] alive, [heavily_injured_german.len] heavily injured or unconscious, [dead_german.len] deceased. Mortality rate: [mortality_german]%"
	var/msg15 = "American: [alive_american.len] alive, [heavily_injured_american.len] heavily injured or unconscious, [dead_american.len] deceased. Mortality rate: [mortality_american]%"
	var/msg16 = "Vietnamese: [alive_vietnamese.len] alive, [heavily_injured_vietnamese.len] heavily injured or unconscious, [dead_vietnamese.len] deceased. Mortality rate: [mortality_vietnamese]%"

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
	if (map && map.civilizations)
		map.facl = list()
		for (var/i=1,i<=map.custom_faction_nr.len,i++)
			var/nu = 0
			map.facl += list(map.custom_faction_nr[i] = nu)

		for (var/relf in map.facl)
			var/curr = ""
			map.facl[relf] = 0
			for (var/mob/living/carbon/human/H in world)
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
			if (map.civilizations && msg_religions != "")
				world << "<font size=3>[msg_religions]</font>"
			if (map.civilizations && msg_factions != "")
				world << "<font size=3>[msg_factions]</font>"
			if (shower)
				message_admins("[key_name(shower)] showed everyone the battle report.")
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