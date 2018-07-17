/client/var/showed_mentorhelp_popup = FALSE

/client/verb/mentorhelp()
	set category = "Help!"
	set name = "Mentorhelp"

	if (say_disabled)	//This is here to try to identify lag problems
		usr << "<span class = 'red'>Speech is currently admin-disabled.</span>"
		return

	//handle muting and automuting
	if (prefs.muted & MUTE_MENTORHELP) // todo: add this
		src << "<font color='red'>Error: Mentor-PM: You cannot send mentorhelps (Muted).</font>"
		return

	if (!showed_mentorhelp_popup)
		WWalert(src, "Before asking for help, please click each of the buttons at the top right of your screen.", "Mentorhelp")
		showed_mentorhelp_popup = TRUE

	mentorhelped = TRUE //Determines if they get the message to reply by clicking the name.

	var/msg = input(src, "What do you need help with? Type nothing to cancel.") as text

	if (handle_spam_prevention(msg,MUTE_MENTORHELP))
		return

	//clean the input msg
	if (!msg)
		return
	msg = sanitize(msg)
	if (!msg)
		return

	if (!mob) //this doesn't happen
		return

	src << "<font color=green>PM to-<b>Mentors </b>: [msg]</font>"
	if (config.discordurl)
		src << "<i>If no mentors are online, please ping @Mentor Team <a href = '[config.discordurl]'>in the discord</a>.</i>"

	var/mentormsg = "<b><font color=green>Request for Help:</font>[get_options_bar(mob, 4, FALSE, TRUE, FALSE)]:</b> [msg]</font>"
	var/adminmsg = "(MENTORHELP) [mentormsg]"

	for (var/client/X in admins)
		if ((R_MENTOR & X.holder.rights) && !((R_ADMIN|R_MOD) & X.holder.rights))
			if (X.is_preference_enabled(/datum/client_preference/holder/play_adminhelp_ping))
				X << 'sound/effects/adminhelp.ogg'
			X << mentormsg

		else if ((R_ADMIN|R_MOD) & X.holder.rights)
			X << adminmsg

	return

