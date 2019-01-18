/client/verb/clear_cache()
	set category = "OOC"
	set name = "Clear Cache"
	if (mob)
		nanomanager.close_uis(mob)
	cache.Cut()
	sending.Cut()
	src << "<span class = 'good'>Cache successfully cleared!</span>"

/client/verb/MOTD()
	set category = "OOC"
	set name = "See MOTD"
	if (mob) // sanity
		mob.see_personalized_MOTD()

/client/proc/hide_status_tabs()
	set category = "OOC"
	set name = "Hide Status Tabs"
	status_tabs = FALSE
	verbs -= /client/proc/hide_status_tabs
	verbs += /client/proc/show_status_tabs

/client/proc/show_status_tabs()
	set category = "OOC"
	set name = "Show Status Tabs"
	status_tabs = TRUE
	verbs -= /client/proc/show_status_tabs
	verbs += /client/proc/hide_status_tabs

/client/verb/who()
	set name = "Who"
	set category = "OOC"

	var/msg = "<b>Current Players:</b>\n"

	var/list/Lines = list()

	if (holder && (R_ADMIN & holder.rights || R_MOD & holder.rights))
		for (var/client/C in clients)
			var/entry = "\t[C.key]"
			if (C.holder && C.holder.fakekey)
				entry += " <i>(as [C.holder.fakekey])</i>"
			entry += " - Playing as [C.mob.real_name]"
			switch(C.mob.stat)
				if (UNCONSCIOUS)
					entry += " - <font color='red'><b>Unconscious</b></font>"
				if (DEAD)
					if (isghost(C.mob))
						var/mob/observer/ghost/O = C.mob
						if (O.started_as_observer)
							entry += " - <font color='gray'>Observing</font>"
						else
							entry += " - <font color='red'><b>DEAD</b></font>"
					else
						entry += " - <font color='gray'>In Lobby</font>"

			var/age
			if (isnum(C.player_age))
				if (player_age >= 864000)
					age = "[round(player_age/864000)] days"
				else
					age = "[round(player_age/360000)] hours"

				if (player_age <= (864000*2))
					age = "<font color='#ff0000'><b>[age]</b></font>"
				else
					age = "<font color='#ff8c00'><b>[age]</b></font>"
			else
				age = FALSE
//			entry += " - [age]"

			if (C.is_afk())
				entry += " (AFK - [C.inactivity2text()])"
			entry += " (<A HREF='?_src_=holder;adminmoreinfo=\ref[C.mob]'>?</A>)"
			Lines += entry
	else
		for (var/client/C in clients)
			var/entry = "Player <b>[C.key]</b> - Playing as <i>[C.mob.real_name]</i>"
			Lines += entry

	for (var/line in sortList(Lines))
		msg += "[line]\n"

	msg += "<b>Total Players: [length(Lines)]</b>"
	src << msg

/client/verb/adminwho()
	set category = "Help!"
	set name = "Staff Who"

	var/highstaff_message = ""
	var/adminmsg = ""
	var/modmsg = ""
	var/mentmsg = ""
//	var/devmsg = ""

	var/num_highstaff_online = 0
	var/num_mods_online = 0
	var/num_admins_online = 0
	var/num_mentors_online = 0
//	var/num_devs_online = FALSE

	if (holder)
		for (var/client/C in admins)
			if (!C.visible_in_who)
				continue

			if (R_PERMISSIONS & C.holder.rights)
				highstaff_message += "\t[C] is a [C.holder.rank]"

				if (isobserver(C.mob))
					highstaff_message += " - Observing"
				else if (istype(C.mob,/mob/new_player))
					highstaff_message += " - Lobby"
				else
					highstaff_message += " - Playing"

				if (C.is_afk())
					highstaff_message += " (AFK - [C.inactivity2text()])"
				highstaff_message += "\n"
				num_highstaff_online++

			else if (R_ADMIN & C.holder.rights || (!R_MOD & C.holder.rights && !R_MENTOR & C.holder.rights))	//Used to determine who shows up in admin rows

				if (C.holder.fakekey && (!R_ADMIN & holder.rights && !R_MOD & holder.rights))		//Mentors can't see stealthmins
					continue

				adminmsg += "\t[C] is a [C.holder.rank]"

				if (C.holder.fakekey)
					adminmsg += " <i>(as [C.holder.fakekey])</i>"

				if (isobserver(C.mob))
					adminmsg += " - Observing"
				else if (istype(C.mob,/mob/new_player))
					adminmsg += " - Lobby"
				else
					adminmsg += " - Playing"

				if (C.is_afk())
					adminmsg += " (AFK - [C.inactivity2text()])"
				adminmsg += "\n"

				num_admins_online++

			else if ((R_MOD & C.holder.rights)/* && C.holder.rank != "Developer"*/)				//Who shows up in mod/mentor rows.
				modmsg += "\t[C] is a [C.holder.rank]"

				if (isobserver(C.mob))
					modmsg += " - Observing"
				else if (istype(C.mob,/mob/new_player))
					modmsg += " - Lobby"
				else
					modmsg += " - Playing"

				if (C.is_afk())
					modmsg += " (AFK - [C.inactivity2text()])"
				modmsg += "\n"
				num_mods_online++


	/*		else if ((R_MOD & C.holder.rights) && C.holder.rank == "Developer")				//Who shows up in mod/mentor rows.
				devmsg += "\t[C] is a [C.holder.rank]"

				if (isobserver(C.mob))
					devmsg += " - Observing"
				else if (istype(C.mob,/mob/new_player))
					devmsg += " - Lobby"
				else
					devmsg += " - Playing"

				if (C.is_afk())
					devmsg += " (AFK - [C.inactivity2text()])"
				devmsg += "\n"
				num_devs_online++*/

			else if (R_MENTOR & C.holder.rights)
				mentmsg += "\t[C] is a [C.holder.rank]"
				if (isobserver(C.mob))
					mentmsg += " - Observing"
				else if (istype(C.mob,/mob/new_player))
					mentmsg += " - Lobby"
				else
					mentmsg += " - Playing"

				if (C.is_afk())
					mentmsg += " (AFK - [C.inactivity2text()])"
				mentmsg += "\n"
				num_mentors_online++

	else
		for (var/client/C in admins)
			if (R_ADMIN & C.holder.rights || (!R_MOD & C.holder.rights && !R_MENTOR & C.holder.rights))
				if (!C.holder.fakekey)
					adminmsg += "\t[C] is a [C.holder.rank]\n"
					num_admins_online++
			else if (R_MOD & C.holder.rights)
				modmsg += "\t[C] is a [C.holder.rank]\n"
				num_mods_online++
			else if (R_MENTOR & C.holder.rights)
				mentmsg += "\t[C] is a [C.holder.rank]\n"
				num_mentors_online++
/* todo: discord bot
	if (config.admin_irc)
		src << "<span class='info'>Adminhelps are also sent to IRC. If no admins are available in game try anyway and an admin on IRC may see it and respond.</span>"*/

	var/msg = "<b>Current High Staff ([num_highstaff_online]):</b>\n" + highstaff_message

	msg += "\n<b>Current Admins ([num_admins_online]):</b>\n" + adminmsg

	if (config.show_mods)
		msg += "\n<b> Current Moderators ([num_mods_online]):</b>\n" + modmsg

	if (config.show_mentors)
		msg += "\n<b> Current Mentors ([num_mentors_online]):</b>\n" + mentmsg

//	msg += "\n<b> Current Developers ([num_devs_online]):</b>\n" + devmsg

	src << msg

// OOC

/client/verb/ooc(msg as text)
	set name = "OOC"
	set category = "OOC"

	if (say_disabled)	//This is here to try to identify lag problems
		usr << "<span class='warning'>Speech is currently admindisabled.</span>"
		return

	if (!mob)	return
	if (IsGuestKey(key))
		src << "Guests may not use OOC."
		return

	if (!is_preference_enabled(/datum/client_preference/show_ooc))
		src << "<span class='warning'>You have OOC muted.</span>"
		return

	if (quickBan_isbanned("OOC"))
		src << "<span class = 'danger'>You're banned from OOC.</span>"
		return

	var/msg_prefix = ""


	msg = sanitize(msg)
	msg = "[msg_prefix][msg]"
	if (!msg)	return

	/* mentioning clients with @key or @ckey */
	for (var/client/C in clients)
		if (C.pingability)
			var/imsg = msg
			msg = replacetext(msg, "@[C.key]", "<span class='ping'>@[capitalize(C.key)]</span>")
			msg = replacetext(msg, "@[C.ckey]", "<span class='ping'>@[capitalize(C.key)]</span>")
			if (msg != imsg)
				winset(C, "mainwindow", "flash=2;")
				C << sound('sound/machines/ping.ogg')

	/* mentioning @everyone: staff only */
	if (holder && holder.rights & R_ADMIN)
		var/imsg = msg
		msg = replacetext(msg, "@everyone", "<span class='ping'>@everyone</span>")
		if (msg != imsg)
			for (var/client/C in clients)
				winset(C, "mainwindow", "flash=2;")
				C << sound('sound/machines/ping.ogg')

	/* mentioning specific roles: */

	// @admins: ping secondary admins, primary admins, and the head admin.
	var/imsg = msg
	msg = replacetext(msg, "@admins", "<span class='ping'>@admins</span>")
	msg = replacetext(msg, "@Admins", "<span class='ping'>@admins</span>")
	if (msg != imsg)
		for (var/client/C in clients)
			if (C.holder && C.holder.rights & R_MOD && !(C.holder.rights & R_PERMISSIONS))
				winset(C, "mainwindow", "flash=2;")
				C << sound('sound/machines/ping.ogg')

	// @highstaff: ping managers, hosts, and senators
	imsg = msg
	msg = replacetext(msg, "@highstaff", "<span class='ping'>@highstaff</span>")
	msg = replacetext(msg, "@Highstaff", "<span class='ping'>@highstaff</span>")
	if (msg != imsg)
		for (var/client/C in clients)
			if (C.holder && C.holder.rights & R_PERMISSIONS)
				winset(C, "mainwindow", "flash=2;")
				C << sound('sound/machines/ping.ogg')

	if (!holder)
		if (!config.ooc_allowed)
			src << "<span class='danger'>OOC is globally muted.</span>"
			return
		if (!config.dooc_allowed && (mob.stat == DEAD))
			usr << "<span class='danger'>OOC for dead mobs has been turned off.</span>"
			return
		if (prefs.muted & MUTE_OOC)
			src << "<span class='danger'>You cannot use OOC (muted).</span>"
			return
		if (handle_spam_prevention(msg,MUTE_OOC))
			return
		if (findtext(msg, "byond://"))
			src << "<b>Advertising other servers is not allowed.</b>"
			log_admin("[key_name(src)] has attempted to advertise in OOC: [msg]")
			message_admins("[key_name_admin(src)] has attempted to advertise in OOC: [msg]")
			return

	log_ooc("[mob.name]/[key] : [msg]")

	var/ooc_style = "everyone"
	if (holder && !holder.fakekey)
		ooc_style = "elevated"
		if (holder.rights & R_MOD)
			ooc_style = "moderator"
		if (holder.rights & R_DEBUG)
			ooc_style = "developer"
		if (holder.rights & R_PERMISSIONS)
			ooc_style = "admin"

	for (var/client/target in clients)
		if (target.is_preference_enabled(/datum/client_preference/show_ooc))
			var/display_name = key
			if (holder)
				if (holder.fakekey)
					if (target.holder)
						display_name = "[holder.fakekey]/([key])"
					else
						display_name = holder.fakekey
				else
					display_name = "<span class = 'ping'>[holder.OOC_rank()]</span> [display_name]"

			// patrons get OOC colors too, now  kachnov

			var/admin_patron_check = FALSE
			if (holder && !holder.fakekey && (holder.rights & R_ADMIN))
				admin_patron_check = TRUE

			if (admin_patron_check && config.allow_admin_ooccolor && (prefs.ooccolor != initial(prefs.ooccolor))) // keeping this for the badmins
				target << "<font color='[prefs.ooccolor]'><span class='ooc'>" + create_text_tag("ooc", "OOC:", target) + " <EM>[display_name]:</EM> <span class='message'>[msg]</span></span></font>"
			else
				target << "<span class='ooc'><span class='[ooc_style]'>" + create_text_tag("ooc", "OOC:", target) + " <EM>[display_name]:</EM> <span class='message'>[msg]</span></span></span>"

/client/verb/looc(msg as text)
	set name = "LOOC"
	set desc = "Local OOC, seen only by those in view."
	set category = "OOC"

	if (say_disabled)	//This is here to try to identify lag problems
		usr << "<span class='danger'>Speech is currently admindisabled.</span>"
		return

	if (!mob)
		return

	if (IsGuestKey(key))
		src << "Guests may not use OOC."
		return

	msg = sanitize(msg)
	if (!msg)
		return

	if (!is_preference_enabled(/datum/client_preference/show_looc))
		src << "<span class='danger'>You have LOOC muted.</span>"
		return

	if (quickBan_isbanned("OOC"))
		src << "<span class = 'danger'>You're banned from OOC.</span>"
		return

	if (!holder)
		if (!config.looc_allowed)
			src << "<span class='danger'>LOOC is globally muted.</span>"
			return
		if (!config.dooc_allowed && (mob.stat == DEAD))
			usr << "<span class='danger'>OOC for dead mobs has been turned off.</span>"
			return
		if (prefs.muted & MUTE_OOC)
			src << "<span class='danger'>You cannot use OOC (muted).</span>"
			return
		if (handle_spam_prevention(msg, MUTE_OOC))
			return
		if (findtext(msg, "byond://"))
			src << "<b>Advertising other servers is not allowed.</b>"
			log_admin("[key_name(src)] has attempted to advertise in OOC: [msg]")
			message_admins("[key_name_admin(src)] has attempted to advertise in OOC: [msg]")
			return

	log_ooc("(LOCAL) [mob.name]/[key] : [msg]")

	var/mob/source = mob.get_looc_source()

	var/display_name = key
	if (holder && holder.fakekey)
		display_name = holder.fakekey
	if (mob.stat != DEAD)
		display_name = mob.name

	var/turf/T = get_turf(source)
	var/list/listening = list()
	listening |= src	// We can always hear ourselves.
	var/list/listening_obj = list()

		// This is essentially a copy/paste from living/say() the purpose is to get mobs inside of objects without recursing through
		// the contents of every mob and object in get_mobs_or_objects_in_view() looking for PAI's inside of the contents of a bag inside the
		// contents of a mob inside the contents of a welded shut locker we essentially get a list of turfs and see if the mob is on one of them.

	if (T)
		var/list/hear = hear(7,T)
		var/list/hearturfs = list()

		for (var/I in hear)
			if (ismob(I))
				var/mob/M = I
				listening |= M.client
				hearturfs += M.locs[1]
			else if (isobj(I))
				var/obj/O = I
				hearturfs |= O.locs[1]
				listening_obj |= O

		for (var/mob/M in player_list)
			if (!M.is_preference_enabled(/datum/client_preference/show_looc))
				continue
		/*	if (isAI(M))
				var/mob/living/silicon/ai/A = M
				if (A.eyeobj && (A.eyeobj.locs[1] in hearturfs))
					eye_heard |= M.client
					listening |= M.client
					continue*/

			if (M.loc && M.locs[1] in hearturfs)
				listening |= M.client


	for (var/client/t in listening)
		var/admin_stuff = ""
		var/prefix = ""
		if (t in admins)
			admin_stuff += "/([key])"
			if (t != src)
				admin_stuff += "([admin_jump_link(mob, t.holder)])"
		t << "<span class='ooc'><span class='looc'>" + create_text_tag("looc", "LOOC:", t) + " <span class='prefix'>[prefix]</span><EM>[display_name][admin_stuff]:</EM> <span class='message'>[msg]</span></span></span>"


	for (var/client/adm in admins)	//Now send to all admins that weren't in range.
		if (!(adm in listening))
			var/admin_stuff = "/([key])([admin_jump_link(mob, adm.holder)])"
			var/prefix = "(R)"

			adm << "<span class='ooc'><span class='looc'>" + create_text_tag("looc", "LOOC:", adm) + " <span class='prefix'>[prefix]</span><EM>[display_name][admin_stuff]:</EM> <span class='message'>[msg]</span></span></span>"

/mob/proc/get_looc_source()
	return src