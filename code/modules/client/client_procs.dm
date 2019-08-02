	////////////
	//SECURITY//
	////////////
#define UPLOAD_LIMIT		10485760	//Restricts client uploads to the server to 10MB //Boosted this thing. What's the worst that can happen?
#define ABSOLUTE_MIN_CLIENT_VERSION 511
#define REAL_MIN_CLIENT_VERSION 512
#define PLAYERCAP 200
	/*
	When somebody clicks a link in game, this Topic is called first.
	It does the stuff in this proc and  then is redirected to the Topic() proc for the src=[0xWhatever]
	(if specified in the link). ie locate(hsrc).Topic()

	Such links can be spoofed.

	Because of this certain things MUST be considered whenever adding a Topic() for something:
		- Can it be fed harmful values which could cause runtimes?
		- Is the Topic call an admin-only thing?
		- If so, does it have checks to see if the person who called it (usr.client) is an admin?
		- Are the processes being called by Topic() particularly laggy?
		- If so, is there any protection against somebody spam-clicking a link?
	If you have any  questions about this stuff feel free to ask. ~Carn
	*/
/client/Topic(href, href_list, hsrc)
	if (!usr || usr != mob)	//stops us calling Topic for somebody else's client. Also helps prevent usr=null
		return

	//search the href for script injection
	if ( findtext(href,"<script",1,0) )
		world.log << "Attempted use of scripts within a topic call, by [src]"
		message_admins("Attempted use of scripts within a topic call, by [src]")
		//del(usr)
		return

	//Admin PM
	if (href_list["priv_msg"])
		var/client/C = locate(href_list["priv_msg"])
		if (ismob(C)) 		//Old stuff can feed-in mobs instead of clients
			var/mob/M = C
			C = M.client
		cmd_admin_pm(C,null)
		return

	if (href_list["irc_msg"])
		if (!holder && received_irc_pm < world.time - 6000) //Worse they can do is spam IRC for 10 minutes
			usr << "<span class='warning'>You are no longer able to use this, it's been more then 10 minutes since an admin on IRC has responded to you</span>"
			return
		if (mute_irc)
			usr << "<span class='warning'You cannot use this as your client has been muted from sending messages to the admins on IRC</span>"
			return
		cmd_admin_irc_pm(href_list["irc_msg"])
		return

	// see quickBan.dm
	if (href_list["quickBan_removeBan"])
		var/UID = href_list["quickBan_removeBan_UID"]
		if (UID)
			var/confirm = input("Are you sure you want to remove the ban with the UID '[UID]' ?") in list("Yes", "No")
			if (confirm == "Yes")
				var/F = file("SQL/bans.txt")
				if (fexists(F))
					fcopy("SQL/bans.txt","SQL/bans_backup.txt")
					fdel(F)
				var/M = "[key_name(usr)] removed quickBan '<b>[UID]</b>' from the ban list. It belonged to [href_list["ckey"]]/[href_list["cID"]]/[href_list["ip"]]"
				spawn(1)
					var/full_banlist = null
					full_banlist = file2text("SQL/bans.txt")
					var/list/full_list_split = splittext(full_banlist, "|||\n")
					for(var/i=1;i<full_list_split.len;i++)
						var/list/full_list_split_two = splittext(full_list_split[i], ";")
						if (text2num(full_list_split_two[10]) <= text2num(num2text(world.realtime,20))) //if the ban expiration has been reached
							full_list_split[i] = "|||\n"
					spawn(1)
						for(var/i=1;i<full_list_split.len;i++)
							var/list/full_list_split_two = splittext(full_list_split[i], ";")
							if (text2num(full_list_split_two[10]) > text2num(num2text(world.realtime,20))) //if the ban expiration hasnt been reached
								if (!(full_list_split[i] = "|||\n"))
									text2file("[full_list_split[i]]|||","SQL/bans.txt")
							return
					log_admin(M)
					message_admins(M)

	//Logs all hrefs
	if (config && config.log_hrefs && href_logfile)
		href_logfile << "<small>[time2text(world.timeofday,"hh:mm")] [src] (usr:[usr])</small> || [hsrc ? "[hsrc] " : ""][href]<br>"

	switch(href_list["_src_"])
		if ("holder")	hsrc = holder
		if ("usr")		hsrc = mob
		if ("prefs")		return prefs.process_link(usr,href_list)
		if ("vars")		return view_var_Topic(href,href_list,hsrc)

	..()	//redirect to hTopic()

/client/proc/handle_spam_prevention(var/message, var/mute_type)
	if (config.automute_on && !holder && last_message == message)
		last_message_count++
		if (last_message_count >= SPAM_TRIGGER_AUTOMUTE)
			src << "<span class = 'red'>You have exceeded the spam filter limit for identical messages. An auto-mute was applied.</span>"
			cmd_admin_mute(mob, mute_type, TRUE)
			return TRUE
		if (last_message_count >= SPAM_TRIGGER_WARNING)
			src << "<span class = 'red'>You are nearing the spam filter limit for identical messages.</span>"
			return FALSE
	else
		last_message = message
		last_message_count = FALSE
		return FALSE

//This stops files larger than UPLOAD_LIMIT being sent from client to server via input(), client.Import() etc.
/client/AllowUpload(filename, filelength)
	if (filelength > UPLOAD_LIMIT)
		src << "<font color='red'>Error: AllowUpload(): File Upload too large. Upload Limit: [UPLOAD_LIMIT/1024]KiB.</font>"
		return FALSE
/*	//Don't need this at the moment. But it's here if it's needed later.
	//Helps prevent multiple files being uploaded at once. Or right after eachother.
	var/time_to_wait = fileaccess_timer - world.time
	if (time_to_wait > 0)
		src << "<font color='red'>Error: AllowUpload(): Spam prevention. Please wait [round(time_to_wait/10)] seconds.</font>"
		return FALSE
	fileaccess_timer = world.time + FTPDELAY	*/
	return TRUE

	///////////
	//CONNECT//
	///////////
/client/New(TopicData)

	dir = NORTH
	TopicData = null							//Prevent calls to client.Topic from connect

	if (!(connection in list("seeker", "web")))					//Invalid connection type.
		return null

	if (byond_version < ABSOLUTE_MIN_CLIENT_VERSION)		// seriously out of date client.
		return null

	if (key != world.host)
		if (!config.guests_allowed && IsGuestKey(key))
			WWalert(src, "This server doesn't allow guest accounts to play. Please go to http://www.byond.com/ and register for a key.", "Guest Account Detected")
			del(src)
			return

	// Change the way they should download resources.
	if (config.resource_urls)
		preload_rsc = pick(config.resource_urls)
	else preload_rsc = TRUE // If config.resource_urls is not set, preload like normal.

	clients += src
	directory[ckey] = src

	if (processes.client && processes.client.logged_next_normal_respawns[ckey])
		next_normal_respawn = processes.client.logged_next_normal_respawns[ckey]

	//preferences datum - also holds some persistant data for the client (because we may as well keep these datums to a minimum)
	prefs = preferences_datums[ckey]

	if (!prefs)
		prefs = new /datum/preferences(src)
		preferences_datums[ckey] = prefs

	prefs.last_ip = address				//these are gonna be used for banning
	prefs.last_id = computer_id			//these are gonna be used for banning

	. = ..()	//calls mob.Login()


	if (quickBan_rejected("Server"))
		del(src)
		return FALSE

	if (byond_version < REAL_MIN_CLIENT_VERSION)		//Out of date client.
		src << "<span class = 'danger'><font size = 4>Please upgrade to BYOND [REAL_MIN_CLIENT_VERSION] to play.</font></span>"
		del(src)
		return FALSE

	/*Admin Authorisation: */

	load_admins()

	holder = admin_datums[ckey]

	// this is here because mob/Login() is called whenever a mob spawns in
	if (holder)
		if (ticker && ticker.current_state == GAME_STATE_PLAYING) //Only report this stuff if we are currently playing.
			message_admins("Staff login: [key_name(src)]")

	if (holder)
		holder.associate(src)
		admins |= src
		holder.owner = src

	sleep(1)

	/* we're the key in host.txt.
	 * if there are no admins, and we aren't admin, give us admin
	 * then delete host.txt?
	 */

	if (clients.len >= PLAYERCAP)
		if (!holder)
			src << "<span class = 'danger'><font size = 4>The server is full right now, sorry.</font></span>"
			del(src)
			return

	var/host_file_text = file2text("config/host.txt")
	if (ckey(host_file_text) == ckey && !holder)
		holder = new("Host", FALSE, ckey)
		var/datum/admins/A = new/datum/admins(holder.rank, holder.rights, ckey)
		if (directory[ckey])
			A.associate(directory[ckey])

	/* let us profile if we're hosting on our computer OR if we have host perms */
	if (world.host == key || (holder && (holder.rights & R_HOST)))
		control_freak = 0

	if (!holder)

		if (!world_is_open)
			src << "<span class = 'userdanger'>The server is currently closed to non-admins.</span>"
			message_admins("[src] tried to log in, but was rejected, the server is closed to non-admins.")
			del(src)
			return

	if (custom_event_msg && custom_event_msg != "")
		src << "<h1 class='alert'>Custom Event</h1>"
		src << "<h2 class='alert'>A custom event is taking place. OOC Info:</h2>"
		src << "<span class='alert'>[custom_event_msg]</span>"
		src << "<br>"

	if (holder)
		add_admin_verbs()
		admin_memo_show()

	verbs += /client/proc/hide_status_tabs

	// Forcibly enable hardware-accelerated graphics, as we need them for the lighting overlays.
	// (but turn them off first, since sometimes BYOND doesn't turn them on properly otherwise)
	spawn(5) // And wait a half-second, since it sounds like you can do this too fast.
		if (src)
			winset(src, null, "command=\".configure graphics-hwmode off\"")
			sleep(2) // wait a bit more, possibly fixes hardware mode not re-activating right
			winset(src, null, "command=\".configure graphics-hwmode on\"")
	if (src)
		send_resources()

	fix_nanoUI()

	spawn (1)
		log_to_db()

	spawn (2)
		if (!istype(mob, /mob/new_player))
			src << browse(null, "window=playersetup;")

		if (istype(mob, /mob/living/carbon/human))
			human_clients_mob_list |= mob

		else if (istype(mob, /mob/observer))
			observer_mob_list |= mob


	// Ensure we aren't in movementMachine_clients, then add us to it.
	for (var/v in 1 to 20)
		movementMachine_clients -= src
		sleep(1)

	movementMachine_clients += src

	//////////////
	//DISCONNECT//
	//////////////
/client/Del()

	if (processes.client)
		processes.client.logged_next_normal_respawns[ckey] = next_normal_respawn

	if (holder)
		holder.owner = null
		admins -= src
	directory -= ckey
	clients -= src
	movementMachine_clients -= src // if we're currently in movementMachine_clients, this removes us. If not, it doesn't matter, since we won't be automatically re-added anymore
	observer_mob_list -= mob
	human_clients_mob_list -= mob
	if (processes.ping_track && processes.ping_track.client_ckey_check[ckey])
		processes.ping_track.client_ckey_check -= ckey

	return ..()

/client/proc/getSQL_id()
	return md5(ckey)

/client/proc/log_to_db()

	if (IsGuestKey(ckey))
		return

	var/sql_ip = sql_sanitize_text(address)

	if (sql_ip == null)
		sql_ip = "HOST"
	var/F = file("SQL/playerlogs.txt")
	var/full_logs = file2text(F)
	var/list/full_logs_split = splittext(full_logs, "|\n")
	var/currentage = -1
	for(var/i=1;i<full_logs_split.len;i++)
		var/list/full_logs_split_two = splittext(full_logs_split[i], ";")
		if ("[full_logs_split_two[1]]" == ckey)
			currentage = text2num(full_logs_split_two[4])
	//Logging player access
	if (currentage == -1)
		//adding to player logs (ckey;ip;computerid;datetime;realtime|)
		text2file("[ckey];[sql_ip];[computer_id];[num2text(world.realtime, 20)];[time2text(world.realtime,"YYYY/MMM/DD-hh:mm:ss")]|","SQL/playerlogs.txt")
		player_age = 0
	else
		player_age = (text2num(num2text(world.realtime,20)) - currentage)


#undef TOPIC_SPAM_DELAY
#undef UPLOAD_LIMIT
#undef MIN_CLIENT_VERSION

//checks if a client is afk
//3000 frames = 5 minutes
/client/proc/is_afk(duration=3000)
	if (inactivity > duration)	return inactivity
	return FALSE

//Checks if the client game window is minimized
/client/proc/is_minimized()
	return (winget(src, "mainwindow", "is-minimized") == "true")

/client/proc/inactivity2text()
	var/seconds = inactivity/10
	return "[round(seconds / 60)] minute\s, [seconds % 60] second\s"

//send resources to the client. It's here in its own proc so we can move it around easiliy if need be
/client/proc/send_resources()

	getFiles(
		'UI/templates/appearance_changer_WW13.tmpl',
		'UI/templates/chem_disp_WW13.tmpl',
		'UI/templates/freezer_WW13.tmpl',
		'UI/templates/layout_basic_WW13.tmpl',
		'UI/templates/layout_default_WW13.tmpl',
		'UI/templates/nav_WW13.tmpl',
		'UI/templates/news_browser_WW13.tmpl',
		'UI/templates/radio_WW13.tmpl',
		'UI/templates/smartfridge_WW13.tmpl',
		'UI/templates/vending_machine_WW13.tmpl'
		)

	spawn (10) //removing this spawn causes all clients to not get verbs.
		//Precache the client with all other assets slowly, so as to not block other browse() calls
		getFilesSlow(src, asset_cache.cache, register_asset = FALSE)

/mob/proc/MayRespawn()
	return FALSE

/client/proc/MayRespawn()
	if (mob)
		return mob.MayRespawn()

	// Something went wrong, client is usually kicked or transfered to a new mob at this point
	return FALSE

/client/verb/character_setup()
	set name = "Character & Preferences Setup"
	set category = "OOC"
	if (prefs)
		prefs.ShowChoices(usr)

// for testing
/client/proc/_winset(arg1, arg2)
	winset(src, arg1, arg2)

/client/proc/_winget(arg1, arg2)
	return winget(src, arg1, arg2)

// testing
/client/proc/delme()
	del src

/client/proc/calculate_is_active_non_observer()
	is_active_non_observer = (src && mob && !istype(mob, /mob/observer) && !is_minimized())
	next_calculate_is_active_non_observer = world.time + 600
	return is_active_non_observer

/client/Stat()
	..()
	sleep(10)

