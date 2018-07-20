
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

	var/total_germans = alive_germans.len + dead_germans.len + heavily_injured_germans.len
	var/total_russians = alive_russians.len + dead_russians.len + heavily_injured_russians.len
	var/total_civilians = alive_civilians.len + dead_civilians.len + heavily_injured_civilians.len
	var/total_partisans = alive_partisans.len + dead_partisans.len + heavily_injured_partisans.len

	var/mortality_coefficient_german = 0
	var/mortality_coefficient_russian = 0
	var/mortality_coefficient_civilian = 0
	var/mortality_coefficient_partisan = 0

	if (dead_germans.len > 0)
		mortality_coefficient_german = dead_germans.len/total_germans

	if (dead_russians.len > 0)
		mortality_coefficient_russian = dead_russians.len/total_russians

	if (dead_civilians.len > 0)
		mortality_coefficient_civilian = dead_civilians.len/total_civilians

	if (dead_partisans.len > 0)
		mortality_coefficient_partisan = dead_partisans.len/total_partisans


	var/mortality_german = round(mortality_coefficient_german*100)
	var/mortality_russian = round(mortality_coefficient_russian*100)
	var/mortality_civilian = round(mortality_coefficient_civilian*100)
	var/mortality_partisan = round(mortality_coefficient_partisan*100)

	var/msg1 = "German Side: [alive_germans.len] alive, [heavily_injured_germans.len] heavily injured or unconscious, [dead_germans.len] deceased. Mortality rate: [mortality_german]%"
	var/msg2 = "Italian Side: [alive_italians.len] alive, [heavily_injured_italians.len] heavily injured or unconscious, [dead_italians.len] deceased. Mortality rate: [mortality_italian]%"
	var/msg3 = "Soviet Side: [alive_russians.len] alive, [heavily_injured_russians.len] heavily injured or unconscious, [dead_russians.len] deceased. Mortality rate: [mortality_russian]%"
	var/msg4 = "Civilians: [alive_civilians.len] alive, [heavily_injured_civilians.len] heavily injured or unconscious, [dead_civilians.len] deceased. Mortality rate: [mortality_civilian]%"
	var/msg5 = "Partisans: [alive_partisans.len] alive, [heavily_injured_partisans.len] heavily injured or unconscious, [dead_partisans.len] deceased. Mortality rate: [mortality_partisan]%"

	if (map && !map.faction_organization.Find(GERMAN))
		msg1 = null
	if (map && !map.faction_organization.Find(SOVIET))
		msg3 = null
	if (map && !map.faction_organization.Find(CIVILIAN))
		msg4 = null
	if (map && !map.faction_organization.Find(PARTISAN))
		msg5 = null

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
			if (msg3)
				world << "<font size=3>[msg3]</font>"
			if (msg4)
				world << "<font size=3>[msg4]</font>"
			if (msg5)
				world << "<font size=3>[msg5]</font>"

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

/client/proc/message_russians()
	set category = "Special"
	set name = "Message Russians"

	var/msg = input(usr, "Send what?", "Message Russians") as text

	if (!msg)
		return

	var/ick_ock = input(usr, "Make this an IC message?", "Message Russians") in list("Yes", "No")
	if (ick_ock == "Yes")
		ick_ock = TRUE
	else
		ick_ock = FALSE

	if (msg)
		if (!ick_ock || !radio2soviets(msg))
			for (var/mob/living/carbon/human/H in player_list)
				if (istype(H) && H.client)
					if (H.original_job && H.original_job.base_type_flag() == SOVIET)
						var/msg_start = ick_ock ? "<b>IMPORTANT MESSAGE FROM THE SOVIET HIGH COMMAND:</b>" : "<b>MESSAGE TO THE SOVIET TEAM FROM ADMINS:</b>"
						H << "[msg_start] <span class = 'notice'>[msg]</span>"

		src << "You sent '[msg]' to the Russian team."
		message_admins("[key_name(src)] sent '[msg]' to the Russian team. (IC = [ick_ock ? "yes" : "no"])")

/client/proc/message_germans()
	set category = "Special"
	set name = "Message Germans"

	var/msg = input(usr, "Send what?", "Message Germans") as text

	if (!msg)
		return

	var/ick_ock = input(usr, "Make this an IC message?", "Message Germans") in list("Yes", "No")

	if (ick_ock == "Yes")
		ick_ock = TRUE
	else
		ick_ock = FALSE

	if (msg)
		if (!ick_ock || !radio2germans(msg))
			for (var/mob/living/carbon/human/H in player_list)
				if (istype(H) && H.client)
					if (H.original_job && list(GERMAN, ITALIAN).Find(H.original_job.base_type_flag()))
						var/msg_start = ick_ock ? "<b>IMPORTANT MESSAGE FROM THE GERMAN HIGH COMMAND:</b>" : "<b>MESSAGE TO THE GERMAN TEAM FROM ADMINS:</b>"
						H << "[msg_start] <span class = 'notice'>[msg]</span>"

		src << "You sent '[msg]' to the German team."
		message_admins("[key_name(src)] sent '[msg]' to the German team. (IC = [ick_ock ? "yes" : "no"])")

/client/proc/message_SS()
	set category = "Special"
	set name = "Message the SS"

	var/msg = input(usr, "Send what?", "Message the SS") as text

	if (!msg)
		return

	var/ick_ock = input(usr, "Make this an IC message?", "Message the SS") in list("Yes", "No")

	if (ick_ock == "Yes")
		ick_ock = TRUE
	else
		ick_ock = FALSE

	if (msg)
		if (!ick_ock || !radio2SS(msg))
			for (var/mob/living/carbon/human/H in player_list)
				if (istype(H) && H.client)
					if (H.original_job && H.original_job.base_type_flag() == GERMAN && H.original_job.is_SS)
						var/msg_start = ick_ock ? "<b>IMPORTANT MESSAGE FROM THE GERMAN HIGH COMMAND TO THE SS:</b>" : "<b>MESSAGE TO THE SS FROM ADMINS:</b>"
						H << "[msg_start] <span class = 'notice'>[msg]</span>"

		src << "You sent '[msg]' to the SS."
		message_admins("[key_name(src)] sent '[msg]' to the SS")


/client/proc/message_paratroopers()
	set category = "Special"
	set name = "Messages Paratroopers"

	var/msg = input(usr, "Send what?", "Message Paratroopers") as text

	if (!msg)
		return

	var/ick_ock = input(usr, "Make this an IC message?", "Message Paratroopers") in list("Yes", "No")

	if (ick_ock == "Yes")
		ick_ock = TRUE
	else
		ick_ock = FALSE

	if (msg)
		for (var/mob/living/carbon/human/H in player_list)
			if (istype(H) && H.client)
				if (H.original_job && H.original_job.base_type_flag() == GERMAN && istype(H.original_job, /datum/job/german/paratrooper))
					var/msg_start = ick_ock ? "<b>IMPORTANT MESSAGE FROM THE GERMAN HIGH COMMAND TO THE PARATROOPER SQUAD:</b>" : "<b>MESSAGE TO THE PARATROOPER SQUAD FROM ADMINS:</b>"
					H << "[msg_start] <span class = 'notice'>[msg]</span>"

		src << "You sent '[msg]' to the paratroopers."
		message_admins("[key_name(src)] sent '[msg]' to the paratroopers")

/client/proc/message_civilians()
	set category = "Special"
	set name = "Message Civilians"

	var/msg = input(usr, "Send what? Note that this messages Partisans too!", "Message Civilians") as text

	if (!msg)
		return

	var/ick_ock = input(usr, "Make this an IC message?", "Message Civilians") in list("Yes", "No")

	if (ick_ock == "Yes")
		ick_ock = TRUE
	else
		ick_ock = FALSE

	if (msg)
		for (var/mob/living/carbon/human/H in player_list)
			if (istype(H) && H.client)
				if (H.original_job && (H.original_job.base_type_flag() == CIVILIAN || H.original_job.base_type_flag() == PARTISAN))
					var/msg_start = ick_ock ? "<b>IMPORTANT MESSAGE FROM ???? to Civilians:</b>" : "<b>MESSAGE TO THE CIVILIANS FROM ADMINS:</b>"
					H << "[msg_start] <span class = 'notice'>[msg]</span>"

		src << "You sent '[msg]' to all Civilians."
		message_admins("[key_name(src)] sent '[msg]' to all Civilians")

/client/proc/message_partisans()
	set category = "Special"
	set name = "Message Partisans"

	var/msg = input(usr, "Send what?", "Message Partisans") as text

	if (!msg)
		return

	var/ick_ock = input(usr, "Make this an IC message?", "Message Partisans") in list("Yes", "No")

	if (ick_ock == "Yes")
		ick_ock = TRUE
	else
		ick_ock = FALSE

	if (msg)
		for (var/mob/living/carbon/human/H in player_list)
			if (istype(H) && H.client)
				if (H.original_job || H.original_job.base_type_flag() == PARTISAN)
					var/msg_start = ick_ock ? "<b>IMPORTANT MESSAGE FROM THE UKRAINIAN PARTISAN COMMAND TO PARTISANS:</b>" : "<b>MESSAGE TO PARTISANS FROM ADMINS:</b>"
					H << "[msg_start] <span class = 'notice'>[msg]</span>"

		src << "You sent '[msg]' to all Partisans."
		message_admins("[key_name(src)] sent '[msg]' to all Partisans")

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
