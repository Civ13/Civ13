
/client/proc/toggle_playing()
	set category = "Special"
	set name = "Toggle Playing"

	ticker.players_can_join = !ticker.players_can_join
	world << "<big><b>You [(ticker.players_can_join) ? "can" : "can't"] join the game [(ticker.players_can_join) ? "now" : "anymore"].</b></big>"
	message_admins("[key_name(src)] changed the playing setting.")
/*
/client/proc/allow_join_geforce()
	set category = "Special"
	set name = "Toggle joining (German)"

	ticker.can_latejoin_geforce = !ticker.can_latejoin_geforce
	world << "<font color=red>You [(ticker.can_latejoin_geforce) ? "can" : "can't"] join the Germans [(ticker.can_latejoin_geforce) ? "now" : "anymore"].</font>"
	message_admins("[key_name(src)] changed the geforce latejoin setting.")

/client/proc/allow_join_ruforce()
	set category = "Special"
	set name = "Toggle joining (Russian)"

	ticker.can_latejoin_ruforce = !ticker.can_latejoin_ruforce
	world << "<font color=red>You [(ticker.can_latejoin_ruforce) ? "can" : "can't"] join the Russians [(ticker.can_latejoin_ruforce) ? "now" : "anymore"].</font>"
	message_admins("[key_name(src)] changed the ruforce latejoin setting.")

/client/proc/allow_rjoin_geforce()
	set category = "Special"
	set name = "Toggle reinforcements (German)"

	if (reinforcements_master)
		reinforcements_master.locked[BRITISH] = !reinforcements_master.locked[BRITISH]
		world << "<font color=red>Reinforcements [(!reinforcements_master.locked[BRITISH]) ? "can" : "can't"] join the Germans [(!reinforcements_master.locked[BRITISH]) ? "now" : "anymore"].</font>"
		message_admins("[key_name(src)] changed the geforce reinforcements setting.")
	else
		src << "<span class = danger>WARNING: No reinforcements master found.</span>"

/client/proc/allow_rjoin_ruforce()
	set category = "Special"
	set name = "Toggle reinforcements (Russian)"

	if (reinforcements_master)
		reinforcements_master.locked[PIRATES] = !reinforcements_master.locked[PIRATES]
		world << "<font color=red>Reinforcements [(!reinforcements_master.locked[PIRATES]) ? "can" : "can't"] join the Russians [(!reinforcements_master.locked[PIRATES]) ? "now" : "anymore"].</font>"
		message_admins("[key_name(src)] changed the ruforce reinforcements setting.")
	else
		src << "<span class = danger>WARNING: No reinforcements master found.</span>"


/client/proc/force_reinforcements_geforce()
	set category = "Special"
	set name = "Quickspawn reinforcements (German)"

	var/list/l = reinforcements_master.reinforcement_pool[BRITISH]

	if (reinforcements_master)
		if (l.len)
			reinforcements_master.allow_quickspawn[BRITISH] = TRUE
			reinforcements_master.british_countdown = 0
		else
			src << "<span class = danger>Nobody is in the German reinforcement pool.</span>"
	else
		src << "<span class = danger>WARNING: No reinforcements master found.</span>"

	message_admins("[key_name(src)] tried to send reinforcements for the Germans.")

	reinforcements_master.lock_check()

/client/proc/force_reinforcements_ruforce()
	set category = "Special"
	set name = "Quickspawn reinforcements (Russian)"

	var/list/l = reinforcements_master.reinforcement_pool[PIRATES]

	if (reinforcements_master)
		if (l.len)
			reinforcements_master.allow_quickspawn[PIRATES] = TRUE
			reinforcements_master.pirates_countdown = 0
		else
			src << "<span class = danger>Nobody is in the Russian reinforcement pool.</span>"
	else
		src << "<span class = danger>WARNING: No reinforcements master found.</span>"

	message_admins("[key_name(src)] tried to send reinforcements for the Russians.")

	reinforcements_master.lock_check()
*/
// debugging
/client/proc/reset_roundstart_autobalance()
	set category = "Special"
	set name = "Reset Roundstart Autobalance"

	if (!check_rights(R_HOST))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return

	var/_clients = input("How many clients?") as num

	job_master.admin_expected_clients = 0
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

var/civilians_toggled = TRUE
var/british_toggled = TRUE
var/pirates_toggled = TRUE

/client/proc/toggle_factions()
	set name = "Toggle Factions"
	set category = "Special"

	if (!check_rights(R_ADMIN))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return

	var/list/choices = list()

	choices += "CIVILIANS ([civilians_toggled ? "ENABLED" : "DISABLED"])"
	choices += "BRITISH ([british_toggled ? "ENABLED" : "DISABLED"])"
	choices += "PIRATES ([pirates_toggled ? "ENABLED" : "DISABLED"])"
	choices += "CANCEL"

	var/choice = input("Enable/Disable what faction?") in choices

	if (choice == "CANCEL")
		return

	else if (findtext(choice, "CIVILIANS"))
		civilians_toggled = !civilians_toggled
		world << "<span class = 'warning'>The Civilian faction has been [civilians_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Civilian faction 'enabled' setting to [civilians_toggled].")
	else if (findtext(choice, "BRITISH"))
		british_toggled = !british_toggled
		world << "<span class = 'warning'>The German faction (not SS) has been [british_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the German faction 'enabled' setting to [british_toggled].")
	else if (findtext(choice, "PIRATES"))
		pirates_toggled = !pirates_toggled
		world << "<span class = 'warning'>The Soviet faction has been [pirates_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Soviet faction 'enabled' setting to [pirates_toggled].")

var/civilians_forceEnabled = FALSE
var/british_forceEnabled = FALSE
var/pirates_forceEnabled = FALSE
var/portuguese_forceEnabled = FALSE
var/spanish_forceEnabled = FALSE
var/french_forceEnabled = FALSE
var/indians_forceEnabled = FALSE

/client/proc/forcibly_enable_faction()
	set name = "Forcibly Enable Faction"
	set category = "Special"

	if (!check_rights(R_ADMIN))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return

	var/list/choices = list()

	choices += "CIVILIANS ([civilians_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "BRITISH ([british_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "PIRATES ([pirates_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "CANCEL"

	var/choice = input("Enable/Disable what faction?") in choices

	if (choice == "CANCEL")
		return

	else if (findtext(choice, "CIVILIANS"))
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

	var/mortality_coefficient_pirates = 0
	var/mortality_coefficient_british = 0
	var/mortality_coefficient_spanish = 0
	var/mortality_coefficient_portuguese = 0
	var/mortality_coefficient_french = 0
	var/mortality_coefficient_indians = 0
	var/mortality_coefficient_civilian = 0

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

	var/mortality_british = round(mortality_coefficient_british*100)
	var/mortality_pirates = round(mortality_coefficient_pirates*100)
	var/mortality_civilian = round(mortality_coefficient_civilian*100)
	var/mortality_french = round(mortality_coefficient_french*100)
	var/mortality_spanish = round(mortality_coefficient_spanish*100)
	var/mortality_portuguese = round(mortality_coefficient_portuguese*100)
	var/mortality_indians = round(mortality_coefficient_indians*100)

	var/msg1 = "British Side: [alive_british.len] alive, [heavily_injured_british.len] heavily injured or unconscious, [dead_british.len] deceased. Mortality rate: [mortality_british]%"
	var/msg2 = "Pirate Side: [alive_pirates.len] alive, [heavily_injured_pirates.len] heavily injured or unconscious, [dead_pirates.len] deceased. Mortality rate: [mortality_pirates]%"
	var/msg3 = "Civilians: [alive_civilians.len] alive, [heavily_injured_civilians.len] heavily injured or unconscious, [dead_civilians.len] deceased. Mortality rate: [mortality_civilian]%"
	var/msg4 = "Spanish: [alive_spanish.len] alive, [heavily_injured_spanish.len] heavily injured or unconscious, [dead_spanish.len] deceased. Mortality rate: [mortality_spanish]%"
	var/msg5 = "Portuguese: [alive_portuguese.len] alive, [heavily_injured_portuguese.len] heavily injured or unconscious, [dead_portuguese.len] deceased. Mortality rate: [mortality_portuguese]%"
	var/msg6 = "French: [alive_french.len] alive, [heavily_injured_french.len] heavily injured or unconscious, [dead_french.len] deceased. Mortality rate: [mortality_french]%"
	var/msg7 = "Natives: [alive_indians.len] alive, [heavily_injured_indians.len] heavily injured or unconscious, [dead_indians.len] deceased. Mortality rate: [mortality_indians]%"



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

	var/public = "Yes"

	if (shower && !private)
		public = WWinput(shower, "Show the report to the entire server?", "Battle Report", "Yes", list("Yes", "No"))
	else if (private)
		public = "No"

	if (public == "Yes")
		if (!shower || (input(shower, "Are you sure you want to show the battle report? Unless the Battle Controller Process died, it will happen automatically!", "Battle Report") in list ("Yes", "No")) == "Yes")
			world << "<font size=4>Battle status report:</font>"

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