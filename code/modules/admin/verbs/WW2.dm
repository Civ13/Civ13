
/client/proc/toggle_playing()
	set category = "Special"
	set name = "Toggle Playing"

	ticker.players_can_join = !ticker.players_can_join
	world << "<big><b>You [(ticker.players_can_join) ? "can" : "can't"] join the game [(ticker.players_can_join) ? "now" : "anymore"].</b></big>"
	message_admins("[key_name(src)] changed the playing setting.")

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
		reinforcements_master.locked[GERMAN] = !reinforcements_master.locked[GERMAN]
		world << "<font color=red>Reinforcements [(!reinforcements_master.locked[GERMAN]) ? "can" : "can't"] join the Germans [(!reinforcements_master.locked[GERMAN]) ? "now" : "anymore"].</font>"
		message_admins("[key_name(src)] changed the geforce reinforcements setting.")
	else
		src << "<span class = danger>WARNING: No reinforcements master found.</span>"

/client/proc/allow_rjoin_ruforce()
	set category = "Special"
	set name = "Toggle reinforcements (Russian)"

	if (reinforcements_master)
		reinforcements_master.locked[SOVIET] = !reinforcements_master.locked[SOVIET]
		world << "<font color=red>Reinforcements [(!reinforcements_master.locked[SOVIET]) ? "can" : "can't"] join the Russians [(!reinforcements_master.locked[SOVIET]) ? "now" : "anymore"].</font>"
		message_admins("[key_name(src)] changed the ruforce reinforcements setting.")
	else
		src << "<span class = danger>WARNING: No reinforcements master found.</span>"


/client/proc/force_reinforcements_geforce()
	set category = "Special"
	set name = "Quickspawn reinforcements (German)"

	var/list/l = reinforcements_master.reinforcement_pool[GERMAN]

	if (reinforcements_master)
		if (l.len)
			reinforcements_master.allow_quickspawn[GERMAN] = TRUE
			reinforcements_master.german_countdown = 0
		else
			src << "<span class = danger>Nobody is in the German reinforcement pool.</span>"
	else
		src << "<span class = danger>WARNING: No reinforcements master found.</span>"

	message_admins("[key_name(src)] tried to send reinforcements for the Germans.")

	reinforcements_master.lock_check()

/client/proc/force_reinforcements_ruforce()
	set category = "Special"
	set name = "Quickspawn reinforcements (Russian)"

	var/list/l = reinforcements_master.reinforcement_pool[SOVIET]

	if (reinforcements_master)
		if (l.len)
			reinforcements_master.allow_quickspawn[SOVIET] = TRUE
			reinforcements_master.soviet_countdown = 0
		else
			src << "<span class = danger>Nobody is in the Russian reinforcement pool.</span>"
	else
		src << "<span class = danger>WARNING: No reinforcements master found.</span>"

	message_admins("[key_name(src)] tried to send reinforcements for the Russians.")

	reinforcements_master.lock_check()

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

var/german_civilian_mode = FALSE
var/soviet_civilian_mode = FALSE

/client/proc/toggle_german_civilian_mode()
	set category = "Special"
	set name = "Toggle German Civilian Mode"
	german_civilian_mode = !german_civilian_mode
	var/M = "[key_name(src)] [german_civilian_mode ? "enabled" : "disabled"] German Civilian Mode - Civilians will [german_civilian_mode ? "now" : "no longer"] count towards the amount of Germans."
	message_admins(M)
	log_admin(M)

/client/proc/toggle_soviet_civilian_mode()
	set category = "Special"
	set name = "Toggle Soviet Civilian Mode"
	soviet_civilian_mode = !soviet_civilian_mode
	var/M = "[key_name(src)] [soviet_civilian_mode ? "enabled" : "disabled"] Soviet Civilian Mode - Civilians will [soviet_civilian_mode ? "now" : "no longer"] count towards the amount of Soviets."
	message_admins(M)
	log_admin(M)

var/partisans_toggled = TRUE
var/civilians_toggled = TRUE
var/SS_toggled = TRUE
var/paratroopers_toggled = TRUE
var/germans_toggled = TRUE
var/soviets_toggled = TRUE
var/polish_toggled = TRUE
var/usa_toggled = TRUE
var/japanese_toggled = TRUE

/client/proc/toggle_factions()
	set name = "Toggle Factions"
	set category = "Special"

	if (!check_rights(R_ADMIN))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return

	var/list/choices = list()

	choices += "PARTISANS ([partisans_toggled ? "ENABLED" : "DISABLED"])"
	choices += "CIVILIANS ([civilians_toggled ? "ENABLED" : "DISABLED"])"
	choices += "GERMANS ([germans_toggled ? "ENABLED" : "DISABLED"])"
	choices += "SOVIET ([soviets_toggled ? "ENABLED" : "DISABLED"])"
	choices += "CANCEL"

	var/choice = input("Enable/Disable what faction?") in choices

	if (choice == "CANCEL")
		return

	if (findtext(choice, "PARTISANS"))
		partisans_toggled = !partisans_toggled
		world << "<span class = 'warning'>The Partisan faction has been [partisans_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Partisan faction 'enabled' setting to [partisans_toggled].")
	else if (findtext(choice, "CIVILIANS"))
		civilians_toggled = !civilians_toggled
		world << "<span class = 'warning'>The Civilian faction has been [civilians_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Civilian faction 'enabled' setting to [civilians_toggled].")
	else if (findtext(choice, "GERMAN"))
		germans_toggled = !germans_toggled
		world << "<span class = 'warning'>The German faction (not SS) has been [germans_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the German faction 'enabled' setting to [germans_toggled].")
	else if (findtext(choice, "SOVIET"))
		soviets_toggled = !soviets_toggled
		world << "<span class = 'warning'>The Soviet faction has been [soviets_toggled ? "<b><i>ENABLED</i></b>" : "<b><i>DISABLED</i></b>"].</span>"
		message_admins("[key_name(src)] changed the Soviet faction 'enabled' setting to [soviets_toggled].")

var/partisans_forceEnabled = FALSE
var/civilians_forceEnabled = FALSE
var/germans_forceEnabled = FALSE
var/soviets_forceEnabled = FALSE
var/SS_forceEnabled = FALSE
var/paratroopers_forceEnabled = FALSE
var/usa_forceEnabled = FALSE
var/japanese_forceEnabled = FALSE
var/polish_forceEnabled = FALSE

/client/proc/forcibly_enable_faction()
	set name = "Forcibly Enable Faction"
	set category = "Special"

	if (!check_rights(R_ADMIN))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return

	var/list/choices = list()

	choices += "PARTISANS ([partisans_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "CIVILIANS ([civilians_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "GERMANS ([germans_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "SOVIET ([soviets_forceEnabled ? "FORCIBLY ENABLED" : "NOT FORCIBLY ENABLED"])"
	choices += "CANCEL"

	var/choice = input("Enable/Disable what faction?") in choices

	if (choice == "CANCEL")
		return

	if (findtext(choice, "PARTISANS"))
		partisans_forceEnabled = !partisans_forceEnabled
		world << "<span class = 'notice'>The Partisan faction [partisans_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Partisan faction 'forceEnabled' setting to [partisans_forceEnabled].")
	else if (findtext(choice, "CIVILIANS"))
		civilians_forceEnabled = !civilians_forceEnabled
		world << "<span class = 'notice'>The Civilian faction [civilians_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Civilian faction 'forceEnabled' setting to [civilians_forceEnabled].")
	else if (findtext(choice, "GERMAN"))
		germans_forceEnabled = !germans_forceEnabled
		world << "<span class = 'notice'>The German faction [germans_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the German faction 'forceEnabled' setting to [germans_forceEnabled].")
	else if (findtext(choice, "SOVIET"))
		soviets_forceEnabled = !soviets_forceEnabled
		world << "<span class = 'notice'>The Soviet faction [soviets_forceEnabled ? "has been forcibly <b>enabled</b>" : "<b>is no longer forcibly enabled</b>"].</span>"
		message_admins("[key_name(src)] changed the Soviet faction 'forceEnabled' setting to [soviets_forceEnabled].")

/client/proc/toggle_respawn_delays()
	set category = "Special"
	set name = "Toggle Respawn Delays"
	config.no_respawn_delays = !config.no_respawn_delays
	var/M = "[key_name(src)] [config.no_respawn_delays ? "disabled" : "enabled"] respawn delays."
	message_admins(M)
	log_admin(M)
	world << "<font size = 3><span class = 'notice'>Respawn delays are now <b>[config.no_respawn_delays ? "disabled" : "enabled"]</b>.</span></font>"

/client/proc/open_armory_doors()
	set name = "Open Armory Doors"
	set category = "Special"
	var/side = input("Which side?") in list("Soviet", "German", "Cancel")
	if (side == "Soviet")
		for (var/obj/structure/simple_door/key_door/soviet/QM/D in door_list)
			D.Open()
		var/M = "[key_name(src)] opened Soviet Armory doors."
		message_admins(M)
		log_admin(M)
	else if (side == "German")
		for (var/obj/structure/simple_door/key_door/german/QM/D in door_list)
			D.Open()
		var/M = "[key_name(src)] opened German Armory doors."
		message_admins(M)
		log_admin(M)

/client/proc/close_armory_doors()
	set name = "Close Armory Doors"
	set category = "Special"
	var/side = input("Which side?") in list("Soviet", "German", "Cancel")
	if (side == "Soviet")
		for (var/obj/structure/simple_door/key_door/soviet/QM/D in door_list)
			D.Close()
			D.keyslot.locked = TRUE
	else if (side == "German")
		for (var/obj/structure/simple_door/key_door/german/QM/D in door_list)
			D.Close()
			D.keyslot.locked = TRUE
