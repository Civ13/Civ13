/* A simpler and more flexible code for banning, designed for SQLite. Its
 * not nearly as fancy as old banning, and it wasn't worth making an interface
 * for this rather small amount of code, so its all done via BYOND's input() */

// 7 ways to ban people (8 now - Taislin)
var/list/ban_types = list("Job Ban", "Faction Ban", "Officer Ban", "Server Ban", "Observe Ban", "Playing Ban", "Penal Ban")

/datum/quickBan_handler
/datum/quickBan_handler/Topic(href,href_list[])
	..()
	if (href_list["quickBan_removeBan"])
		var/client/caller = locate(href_list["caller"])
		var/UID = href_list["quickBan_removeBan_UID"]
		var/ckey = href_list["quickBan_removeBan_ckey"]
		var/cID = href_list["quickBan_removeBan_cID"]
		var/ip = href_list["quickBan_removeBan_ip"]
		database.execute("DELETE FROM quick_bans WHERE (UID = '[UID]' OR ckey = '[ckey]' OR cID = '[cID]' OR ip = '[ip]');")
		var/M = "[key_name(caller)] removed a ban for '[UID]/[ckey]/[cID]/[ip]'."
		log_admin(M)
		message_admins(M)

		for (var/client/C in clients)
			if (C.ckey == ckey)
				C << "<span class = 'good'>href_list["quickBan_unbanned_message"]</span>"


var/datum/quickBan_handler/quickBan_handler = null

/* admin procedures */
/client/proc/quickBan_search()
	set category = "Bans"

	if (!quickBan_handler)
		quickBan_handler = new

	var/option = input(src, "Search for a ban?") in list("Yes", "No")
	if (option == "No")
		return

	var/_ckey = ckey(input(src, "What ckey will you search for? (optional)") as null|text)
	var/cID = input(src, "What cID will you search for? (optional)") as null|text
	var/ip = input(src, "What address will you search for? (optional)") as null|text
	var/ban_type = input(src, "What type of ban do you want to search for?") in ban_types + "All"

	var/html = "<center><big>List of Quick Bans</big></center>"

	var/list/result = list()

	if (ban_type == "All")
		result = database.execute("SELECT * FROM quick_bans;", FALSE)
	else
		ban_type = replacetext(ban_type, " Ban", "")
		result = database.execute("SELECT * FROM quick_bans WHERE type = '[ban_type]';", FALSE)

	var/list/possibilities = list()

	if (islist(result) && !isemptylist(result))
		for (var/v in 1 to 100)
			if (_ckey && result.Find("ckey_[v]") && result["ckey_[v]"] != _ckey)
				continue
			if (cID && result.Find("cID_[v]") && result["cID_[v]"] != cID)
				continue
			if (ip && result.Find("ip_[v]") && result["ip_[v]"] != ip)
				continue
			if (text2num(result["expire_realtime_[v]"]) <= world.realtime)
				database.execute("DELETE * FROM quick_bans WHERE UID = '[result["UID_v"]]';")
				continue
			var/quickBan_unbanned_message = "Your ban [result["ban_type"]] ([result["type_specific_info"]]) has been lifted by an admin."
			possibilities += "<big><b>UID [result["UID_[v]"]]</b> (<a href='byond://?src=\ref[quickBan_handler];caller=\ref[src];quickBan_removeBan=1;quickBan_removeBan_UID=[result["UID_[v]"]];quickBan_removeBan_ckey=[result["ckey_[v]"]];quickBan_removeBan_cID=[result["cID_[v]"]];quickBan_removeBan_ip=[result["ip_[v]"]];quickBan_unbanned_message=[quickBan_unbanned_message]'>DELETE</a>)</big>: [result["ckey_[v]"]]/[result["cID_[v]"]]/[result["ip_[v]"]], type '[result["type_[v]"]]' ([result["type_specific_info_[v]"]]): banned for '[result["reason_[v]"]]' by [result["banned_by_[v]"]] on [result["ban_date_[v]"]]. <b>[result["expire_info_[v]"]]</b>. (After assigned date)"

	for (var/possibility in possibilities)
		html += "<br>"
		html += possibility

	src << browse(html, "window=quick_bans_search;")

/client/proc/quickBan_person()
	set category = "Bans"

	var/option = input(src, "Do you wish to ban by client or by manual input? (Necessary to ban an offline client)") in list("Client", "Manual Input", "Cancel")
	if (option == "Cancel")
		return

	var/list/fields = list() // as much storage as we need

	if (option == "Manual Input")
		fields["ckey"] = input(src, "What is the person's ckey? (optional)") as null|text
		fields["cID"] = input(src, "What is the person's cID? (optional)") as null|text
		fields["ip"] = input(src, "What is the person's IP? (optional)") as null|text
		fields["ckey"] = ckey(fields["ckey"])
		if (!fields["ckey"] && !fields["cID"] && !fields["ip"])
			return
		else
			// we have one or more field, use connection logs to find the others
			var/ckey = fields["ckey"]
			var/cID = fields["cID"]
			var/ip = fields["ip"]

			if (fields["ckey"])
				if (!fields["cID"])
					fields["cID"] = database.execute("SELECT computerid FROM connection_log WHERE ckey = '[ckey]';")["computerid"]
				if (!fields["ip"])
					fields["ip"] = database.execute("SELECT ip FROM connection_log WHERE ckey = '[ckey]';")["ip"]
			else if (fields["cID"])
				if (!fields["ckey"])
					fields["ckey"] = database.execute("SELECT ckey FROM connection_log WHERE computerid = '[cID]';")["ckey"]
				if (!fields["ip"])
					fields["ip"] = database.execute("SELECT ip FROM connection_log WHERE computerid = '[cID]';")["ip"]
			else if (fields["ip"])
				if (!fields["ckey"])
					fields["ckey"] = database.execute("SELECT ckey FROM connection_log WHERE ip = '[ip]';")["ckey"]
				if (!fields["cID"])
					fields["cID"] = database.execute("SELECT computerid FROM connection_log WHERE ip = '[ip]';")["computerid"]

			// as a fallback, search for mobs in the world and use their lastKnownX variables instead

			if (fields["ckey"])
				if (!fields["cID"])
					for (var/mob/M in mob_list)
						if (M.lastKnownCkey == fields["ckey"])
							if (M.lastKnownCID)
								fields["cID"] = M.lastKnownCID
				if (!fields["ip"])
					for (var/mob/M in mob_list)
						if (M.lastKnownCkey == fields["ckey"])
							if (M.lastKnownIP)
								fields["ip"] = M.lastKnownIP

			else if (fields["cID"])
				if (!fields["ckey"])
					for (var/mob/M in mob_list)
						if (M.lastKnownCID == fields["cID"])
							if (M.lastKnownCkey)
								fields["ckey"] = M.lastKnownCkey
				if (!fields["ip"])
					for (var/mob/M in mob_list)
						if (M.lastKnownCID == fields["cID"])
							if (M.lastKnownIP)
								fields["ip"] = M.lastKnownIP

			else if (fields["ip"])
				if (!fields["ckey"])
					for (var/mob/M in mob_list)
						if (M.lastKnownIP == fields["ip"])
							if (M.lastKnownCkey)
								fields["ckey"] = M.lastKnownCkey
				if (!fields["cID"])
					for (var/mob/M in mob_list)
						if (M.lastKnownIP == fields["ip"])
							if (M.lastKnownIP)
								fields["cID"] = M.lastKnownCID

	else if (option == "Client")
		var/client/C = input(src, "Which client?") in clients + "Cancel"
		if (C == "Cancel")
			return
		fields["ckey"] = C.ckey
		fields["cID"] = C.computer_id
		fields["ip"] = C.address
		fields["ckey"] = ckey(fields["ckey"])

	if (trying_to_quickBan_admin(fields["ckey"], fields["cID"], fields["ip"]))
		return

	fields["type"] = input(src, "What type of ban will this be?") in ban_types + "Cancel"
	if (fields["type"] == "Cancel")
		return

	fields["type"] = replacetext(fields["type"], " Ban", "")

	switch (fields["type"])
		if ("Job")
			var/list/possibilities = job_master.occupations
			var/datum/job/J = input("What job?") in possibilities
			fields["type_specific_info"] = J.title
		if ("Faction")
			var/faction = input("What faction?") in list(GERMAN, SOVIET, ITALIAN, UKRAINIAN, SCHUTZSTAFFEL, PARTISAN, CIVILIAN, USA, JAPAN, POLISH_INSURGENTS)
			fields["type_specific_info"] = faction

	reenter_bantime

	var/duration_in_x_units = input(src, "How long do you want the ban to last ('5 hours', '4 days': the default unit is days)") as text
	var/duration_in_days = text2num(ckey(splittext(duration_in_x_units, " ")[1]))

	if (!isnum(duration_in_days))
		src << "<span class = 'warning'>Invalid amount.</span>"
		goto reenter_bantime

	if (findtext(duration_in_x_units, "year"))
		duration_in_days *= 365
	else if (findtext(duration_in_x_units, "month"))
		duration_in_days *= 30
	else if (findtext(duration_in_x_units, "week"))
		duration_in_days *= 7
	else if (findtext(duration_in_x_units, "hour"))
		duration_in_days /= 24
	else if (findtext(duration_in_x_units, "minute"))
		duration_in_days /= 1440
	else if (findtext(duration_in_x_units, "second"))
		duration_in_days /= 86400
	else if (!findtext(duration_in_x_units, "day"))
		src << "<span class = 'warning'>Invalid unit.</span>"
		goto reenter_bantime

	var/duration_in_deciseconds = duration_in_days * 86400 * 10
	fields["expire_realtime"] = num2text(world.realtime + duration_in_deciseconds, 20)

	switch (duration_in_days)
		if (0 to 0.99) // count in hours
			fields["expire_info"] = "Expires in [duration_in_days*24] hour(s)"
		if (0.99 to 6.99) // count in days
			fields["expire_info"] = "Expires in [duration_in_days] day(s)"
		if (6.99 to 29.99) // count in weeks
			fields["expire_info"] = "Expires in [duration_in_days/7] week(s)"
		if (29.99 to 364.99) // count in months
			fields["expire_info"] = "Expires in [duration_in_days/30] month(s)"
		if (364.99 to INFINITY) // count in years
			fields["expire_info"] = "Expires in [duration_in_days/365] year(s)"

	fields["ban_date"] = replacetext(time2text(world.realtime, "DDD MMM DD hh:mm:ss YYYY"), ":", ".")

	reenter_reason
	fields["reason"] = input(src, "Provide a reason for the ban.") as text
	if (!fields["reason"])
		goto reenter_reason

	fields["banned_by"] = key

	quickBan_ban(fields, src)

/* helpers */
/proc/quickBan_sanitize_fields(var/list/fields)

	if (!fields.Find("ckey") || fields["ckey"] == "")
		fields["ckey"] = "nil"
	if (!fields.Find("cID") || fields["cID"] == "")
		fields["cID"] = "nil"
	if (!fields.Find("ip") || fields["ip"] == "" || fields["ip"] == null) // host
		fields["ip"] = "nil"
	if (!fields.Find("type"))
		fields["type"] = "nil"
	if (!fields.Find("type_specific_info"))
		fields["type_specific_info"] = "nil"
	if (!fields.Find("UID"))
		fields["UID"] = database.newUID()
	if (!fields.Find("reason"))
		fields["reason"] = "nil"
	if (!fields.Find("banned_by"))
		fields["banned_by"] = "nil"
	if (!fields.Find("ban_date"))
		fields["ban_date"] = "nil"
	if (!fields.Find("expire_realtime"))
		fields["expire_realtime"] = "nil"
	if (!fields.Find("expire_info"))
		fields["expire_info"] = "nil"

	// sanitize user input
	for (var/x in fields)
		if (!istext(fields[x]))
			if (!isnum(fields[x]))
				fields[x] = "[fields[x]]"
			else
				fields[x] = num2text(fields[x], 20)
		if (x == "ckey" || x == "cID" || x == "ip")
			fields[x] = copytext(fields[x], 1, 51)
		else if (x == "reason")
			fields[x] = copytext(fields[x], 1, 151)
		fields[x] = sanitizeSQL(fields[x], 200)

	fields["test"] = "test"

/* the actual banning procedure */
/proc/quickBan_ban(var/list/fields, var/client/banner)

	if (!fields)
		fields = list()

	quickBan_sanitize_fields(fields)

	var/ckey = fields["ckey"]
	var/cID = fields["cID"]
	var/ip = fields["ip"]
	var/expire_info = fields["expire_info"]
/*
	for (var/x in fields)
	//	world << "[x] = [fields[x]]"
		if (!istext(fields[x]))
	//		world << "ERROR! [x] is not a text field!!!!"

	if (database.execute("INSERT INTO qbans (ckey, cID, ip, type, UID, reason, banned_by, ban_date, expire_realtime) VALUES ('[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]');"))
	//	world << "Test #0 succeeded"

	if (database.execute("INSERT INTO qbans (ckey, cID, ip, type, UID, reason, banned_by, ban_date, expire_realtime) VALUES ('[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]');"))
	//	world << "Test #1 succeeded"

	if (database.execute("INSERT INTO quick_bans (ckey, cID, ip, type, UID, reason, banned_by, ban_date, expire_realtime) VALUES ('[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]', '[fields["test"]]');"))
	//	world << "Test #2 succeeded"
		*/
	if (database.execute("INSERT INTO quick_bans (ckey, cID, ip, type, type_specific_info, UID, reason, banned_by, ban_date, expire_realtime, expire_info) VALUES ('[fields["ckey"]]', '[fields["cID"]]', '[fields["ip"]]', '[fields["type"]]', '[fields["type_specific_info"]]', '[fields["UID"]]', '[fields["reason"]]', '[fields["banned_by"]]', '[fields["ban_date"]]', '[fields["expire_realtime"]]', '[fields["expire_info"]]');"))
		if (banner)
			banner << "<span class = 'notice'>You have successfully banned [ckey]/[cID]/[ip]. This ban [lowertext(expire_info)]."
		var/M = "[key_name(banner)] banned [ckey]/[cID]/[ip] (bantype = [fields["type"]] ([fields["type_specific_info"]])) for reason '[fields["reason"]]'. This ban [lowertext(expire_info)]."
		log_admin(M)
		message_admins(M)
		// kick whoever got banned if they're on
		if (lowertext(fields["type"]) == "server")
			for (var/client/C in clients)
				if (C.ckey == ckey)
					C.quickBan_kicked(fields["type"], fields["reason"], fields["expire_info"])
					break
		else
			if (fields["type_specific_info"])
				for (var/client/C in clients)
					if (C.ckey == ckey)
						C << "<span class = 'userdanger'>You have been [lowertext(fields["type"])]-banned ([fields["type_specific_info"]]). Reason: '[fields["reason"]]'. This ban [lowertext(expire_info)]."
						break
			else
				for (var/client/C in clients)
					if (C.ckey == ckey)
						C << "<span class = 'userdanger'>You have been [fields["type"]]-banned. Reason: '[fields["reason"]]'. This ban [lowertext(expire_info)]."
						break
	else
		if (banner)
			banner << "<span class = 'warning'>FAILED to ban [ckey]/[cID]/[ip]! A database error occured.</span>"

/* checking if we're banned */
/client/proc/quickBan_isbanned(var/ban_type = "Server", var/type_specific_info = "nil")
	var/list/bans = database.execute("SELECT * FROM quick_bans WHERE (ckey = '[ckey]' OR cID = '[computer_id]' OR ip = '[address]') AND type = '[ban_type]' AND type_specific_info = '[type_specific_info]';", FALSE)
	if (islist(bans) && !isemptylist(bans))
		for (var/x in bans)
		//	world << "[x] = [bans[x]]"
			if (x == "expire_realtime" && text2num(bans[x]) <= world.realtime)
				if (bans.Find("UID"))
					database.execute("DELETE FROM quick_bans WHERE UID = '[bans["UID"]]';")
				continue
			else if (x == "reason")
				if (bans.Find("expire_realtime") && text2num(bans["expire_realtime"]) <= world.realtime)
					database.execute("DELETE FROM quick_bans WHERE UID = '[bans["UID"]]';")
					continue
				if (bans.Find("type_specific_info"))
				//	log_debug(bans["type_specific_info"])
				//	log_debug(type_specific_info)
					if (bans["type_specific_info"] != "nil")
						if (bans["type_specific_info"] == type_specific_info)
							return list("reason" = bans["reason"],
								"ban_date" = bans["ban_date"],
								"expire_info" = bans["expire_info"])
					else
						return list("reason" = bans["reason"],
							"ban_date" = bans["ban_date"],
							"expire_info" = bans["expire_info"])
				else
					return list("reason" = bans["reason"],
						"ban_date" = bans["ban_date"],
						"expire_info" = bans["expire_info"])
	return FALSE

/* check if we're banned and tell us why we're banned */
/client/proc/quickBan_rejected(var/bantype = "Server")

	var/list/fields = quickBan_isbanned(bantype)

	if (fields == FALSE)
		fields = list()

	if (!fields.Find("reason"))
		return FALSE

	var/reason = fields["reason"]
	var/date = fields["ban_date"]
	var/expire_info = fields["expire_info"]

	if (reason)
		if (bantype == "Server")
			src << "<span class = 'userdanger'>You're banned. Reason: '[reason]'. This ban was assigned on [date] and [expire_info] (after assigned date)</span>"
		else
			src << "<span class = 'userdanger'>You're [lowertext(bantype)]-banned. Reason: '[reason]'. This ban was assigned on [date] and [expire_info] (after assigned date)</span>"
		return TRUE
	return FALSE

/* kick us if we just got banned */
/client/proc/quickBan_kicked(var/bantype, var/reason, var/expire_info)
	src << "<span class = 'userdanger'>You have been given a [lowertext(bantype)]-ban. Reason: '[reason]'. [expire_info].</span>"
	del src

/* check if we're an admin trying to quickBan another admin */
/client/proc/trying_to_quickBan_admin(_ckey, cID, ip)
	// check to see if we're trying to ban an admin by ckey
	var/list/admincheck = database.execute("SELECT * FROM admin WHERE ckey = '[_ckey]';")
	if (islist(admincheck) && !isemptylist(admincheck))
		src << "<span class = 'danger'>You can't ban admins!</span>"
		return TRUE

	var/list/playercheck = database.execute("SELECT * FROM connection_log WHERE ckey = '[_ckey]' OR ip = '[ip]' OR computerid = '[cID]';")
	if (islist(playercheck) && !isemptylist(playercheck))
		if (playercheck.Find("ckey"))
			var/player_ckey = playercheck["ckey"]
			if (player_ckey)
				admincheck = database.execute("SELECT * FROM admin WHERE ckey = '[player_ckey]';")
				if (islist(admincheck) && !isemptylist(admincheck))
					src << "<span class = 'danger'>You can't ban admins!</span>"
					return TRUE
	return FALSE