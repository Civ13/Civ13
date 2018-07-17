#ifndef OVERRIDE_BAN_SYSTEM
//Blocks an attempt to connect before even creating our client datum thing.
world/IsBanned(key,address,computer_id)

	if(ckey(key) in admin_datums)
		return ..()

	//Guest Checking
	if(!config.guests_allowed && IsGuestKey(key))
		log_access("Failed Login: [key] - Guests not allowed")
		message_admins("\blue Failed Login: [key] - Guests not allowed")
		return list("reason"="guest", "desc"="\nReason: Guests not allowed. Please sign in with a byond account.")

	//check if the IP address is a known TOR node
	if(config && config.ToRban && ToRban_isbanned(address))
		log_access("Failed Login: [src] - Banned: ToR")
		message_admins("\blue Failed Login: [src] - Banned: ToR")
		//ban their computer_id and ckey for posterity
		AddBan(ckey(key), computer_id, "Use of ToR", "Automated Ban", 0, 0)
		return list("reason"="Using ToR", "desc"="\nReason: The network you are using to connect has been banned.\nIf you believe this is a mistake, please request help at [config.banappeals]")

/*
	if(config.ban_legacy_system)

		//Ban Checking
		. = CheckBan( ckey(key), computer_id, address )
		if(.)
			log_access("Failed Login: [key] [computer_id] [address] - Banned [.["reason"]]")
			message_admins("\blue Failed Login: [key] id:[computer_id] ip:[address] - Banned [.["reason"]]")
			return .

		return ..()	//default pager ban stuff

	else*/

	var/ckeytext = ckey(key)

	if(!establish_db_connection())
		error("Ban database connection failure. Key [ckeytext] not checked")
		log_misc("Ban database connection failure. Key [ckeytext] not checked")
		return

	var/failedcid = 1
	var/failedip = 1

	if(address)
		failedip = 0

	if(computer_id)
		failedcid = 0

//	#define IsBannedDebug

	#ifdef IsBannedDebug
	world << "ckey: [ckeytext]"
	world << "address: [address]"
	world << "CID: [computer_id]"
	#endif

	#ifdef IsBannedDebug
	world << "in procedure IsBanned(), ckey = [ckeytext], ip = [address], computerid = [computer_id];"
	#endif

	//var/list/rowdata = database.execute("SELECT ckey, ip, computerid, a_ckey, reason, expiration_time, duration, bantime, bantype FROM ban WHERE (ckey = '[ckeytext]' [ipquery] [cidquery]) AND (bantype = 'PERMABAN' OR (bantype = 'TEMPBAN' AND expiration_time > [database.Now(1)])) AND unbanned = NULL;")
//x = OR (bantype = 'TEMPBAN' AND expiration_time > [database.Now(1)])
//y =  AND (bantype = 'PERMABAN' x) AND unbanned = NULL)


	var/list/rowdata = database.execute("SELECT ckey, ip, computerid, a_ckey, reason, expiration_time, duration, bantime, bantype, unbanned FROM ban WHERE ((ckey = '[ckeytext]' OR ip = '[address ? address : "NOTHING"]' OR computerid = '[computer_id ? computer_id : "NOTHING"]') AND (bantype = 'PERMABAN' OR bantype = 'TEMPBAN'));")

	#ifdef IsBannedDebug
	world << "we managed to get past the ban SELECT query"
	#endif

	#ifdef IsBannedDebug
	if (!islist(rowdata) || isemptylist(rowdata))
		world << "no rowdata from the query"
	#endif

	if (islist(rowdata) && !isemptylist(rowdata))
		#ifdef IsBannedDebug
		world << "we have a 'rowdata' list."
		#endif
		var/pckey = rowdata["ckey"]
		//var/pip = rowdata[2]
		//var/pcid = rowdata[3]
		var/ackey = rowdata["a_ckey"]
		var/reason = rowdata["reason"]
		var/expiration = rowdata["expiration_time"]
		var/duration = rowdata["duration"]
		var/bantime = rowdata["bantime"]
		var/bantype = rowdata["bantype"]
		var/unbanned = rowdata["unbanned"]

		// if this is a tempban, check expiration_time

		if (istext(expiration))
			expiration = text2num(expiration)

		if (bantype == "TEMPBAN" && expiration < database.Now())
			#ifdef IsBannedDebug
			world << "skipping temp ban"
			#endif
			goto skipban

		if (unbanned != null)
			#ifdef IsBannedDebug
			world << "skipping removed ban"
			#endif
			goto skipban

		var/expires = ""
		if(text2num(duration) > 0)
			expires = " The ban is for [duration] minutes and expires on [expiration] (server time)."

		var/days_ago = smart_round(abs(world.realtime - bantime)/864000)
		var/days_left = (duration == -1 ? "" : smart_round((expiration-bantime)/864000))
		var/minutes_left = ((expiration-bantime)/600)

		var/desc = "<font size = 3>You are banned.</font><br>"
		desc += "<i>You, or another user of this computer or connection ([pckey]) is banned from playing here. The ban reason is:\n[reason]\n[duration != -1 ? "This ban was applied by [capitalize(ackey)] [days_ago] days ago." : ""]</i>"
		desc += "<br>"

		if (!expires)
			desc += "<b>This is a permanent ban.</b>"
		else
			desc += "<b>This ban is for [duration] minutes. Your ban expires in [days_left] days ([minutes_left] minutes).</b>"

		return list("reason"="[bantype]", "desc"="[desc]")

	skipban

	if (failedcid)
		message_admins("[key] has logged in with a blank computer id in the ban check.")
	if (failedip)
		message_admins("[key] has logged in with a blank ip in the ban check.")
	return ..()	//default pager ban stuff

#endif
#undef OVERRIDE_BAN_SYSTEM

