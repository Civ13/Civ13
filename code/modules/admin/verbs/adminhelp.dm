/client/var/showed_adminhelp_popup = FALSE

/client/verb/adminhelp()
	set category = "Help!"
	set name = "Adminhelp"

	if (say_disabled)	//This is here to try to identify lag problems
		usr << "<span class = 'red'>Speech is currently admin-disabled.</span>"
		return

	//handle muting and automuting
	if (prefs.muted & MUTE_ADMINHELP)
		src << "<span class = 'red'>Error: Admin-PM: You cannot send adminhelps (Muted).</span>"
		return

	if (!showed_adminhelp_popup)
		alert(src, "If you are experiencing a bug, please try: a) relogging b) following the instructions in the MOTD and c) using the 'Clear Cache' verb in the OOC tab, before asking admins. If you are reporting a bug, please use the 'Report Bug' button at the top right of your screen. Gameplay questions go in mentorhelp, not adminhelp.")
		showed_adminhelp_popup = TRUE

	adminhelped = TRUE //Determines if they get the message to reply by clicking the name.

	var/msg = input(src, "What do you need help with? Type nothing to cancel.") as text

	if (handle_spam_prevention(msg,MUTE_ADMINHELP))
		return

	//clean the input msg
	if (!msg)
		return

	msg = sanitize(msg)
	if (!msg)
		return

	if (!mob) //this doesn't happen
		return

	//show it to the person adminhelping too
	src << "<span class = 'notice'>PM to-<b>Admins </b>: [msg]</span>"
	if (config.discordurl)
		src << "<i>If no admins are online, please ping @Sergeant <a href = '[config.discordurl]'>in the discord</a>.</i>"
	log_admin("HELP: [key_name(src)]: [msg]")
	discord_ahelp_log(key_name(src),msg)
	msg = "<span class = 'notice'><b><font color=red>Request for Help: </span>[get_options_bar(mob, 2, TRUE, TRUE)]:</b> [msg]</span>"
	var/mentormsg = "<span class = 'notice'><b><font color=red>Request for Help:</b> [msg]</span>"

	for (var/client/X in admins)
		if ((R_ADMIN|R_MOD) & X.holder.rights)

			if (X.is_preference_enabled(/datum/client_preference/holder/play_adminhelp_ping))
				X << 'sound/effects/adminhelp.ogg'
			X << msg
		else if (R_MENTOR & X.holder.rights)
			if (X.is_preference_enabled(/datum/client_preference/holder/play_adminhelp_ping))
				X << 'sound/effects/adminhelp.ogg'
			X << mentormsg