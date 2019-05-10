/* A simpler and more flexible code for banning, designed for SQLite. Its
 * not nearly as fancy as old banning, and it wasn't worth making an interface
 * for this rather small amount of code, so its all done via BYOND's input() */

// bantypes
var/list/ban_types = list("Faction Ban", "Job Ban", "Officer Ban", "Server Ban", "Playing Ban", "OOC Ban")

/datum/quickBan_handler
/datum/quickBan_handler/Topic(href,href_list[])
	..()
	if (href_list["quickBan_removeBan"])
		var/client/caller = locate(href_list["caller"])
		var/UID = href_list["quickBan_removeBan_UID"]
		var/ckey = href_list["quickBan_removeBan_ckey"]
		var/cID = href_list["quickBan_removeBan_cID"]
		var/ip = href_list["quickBan_removeBan_ip"]

		var/F = file("SQL/bans.txt")
		if (fexists(F))
			var/full_banlist = file2text(F)
			fcopy("SQL/bans.txt","SQL/bans_backup.txt")
			fdel(F)
			var/list/full_list_split = splittext(full_banlist, "|||\n")
			for(var/i=1;i<full_list_split.len;i++)
				var/list/full_list_split_two = splittext(full_list_split[i], ";")
				if (full_list_split_two[1] == "[ckey]" || full_list_split_two[2] == "[cID]" || full_list_split_two[3] == "[ip]")
					full_list_split_two[10] = 0
					if (text2num(full_list_split_two[10]) > text2num(num2text(world.realtime,20))) //if the ban expiration hasn't been reached yet
						text2file("[full_list_split[i]]|||","SQL/bans.txt")
					log_admin("[key_name(caller)] removed a ban for '[UID]/[ckey]/[cID]/[ip]'.")
					message_admins("[key_name(caller)] removed a ban for '[UID]/[ckey]/[cID]/[ip]'.")

				for (var/client/C in clients)
					if (C.ckey == ckey)
						C << "<span class = 'good'>href_list["Your ban has been lifted."]</span>"


var/datum/quickBan_handler/quickBan_handler = null

/* admin procedures */
/client/proc/quickBan_search()
	set category = "Bans"

	if (!quickBan_handler)
		quickBan_handler = new
	var/full_banlist = file2text("SQL/bans.txt")
	var/list/full_list_split = splittext(full_banlist, "|||\n")
	var/list/result = list()

	var/option = input(src, "Search for a ban?") in list("Yes","Show All","Cancel")
	if (option == "No")
		return
	else if (option == "Yes")
		var/option2 = input(src, "What to search for?") in list("ckey","cID","ip","Cancel")
		if (option2 == "Cancel")
			return
		else if (option2 == "ckey")
			var/_ckey = ckey(input(src, "What ckey will you search for?") as null|text)
			for(var/i=1;i<full_list_split.len;i++)
				var/list/full_list_split_two = splittext(full_list_split[i], ";")
				if (full_list_split_two[1] == _ckey)
					result += list(full_list_split_two)

		else if (option2 == "cID")
			var/cID = input(src, "What cID will you search for?") as null|text
			for(var/i=1;i<full_list_split.len;i++)
				var/list/full_list_split_two = splittext(full_list_split[i], ";")
				if (full_list_split_two[2] == cID)
					result += list(full_list_split_two)

		else if (option2 == "ip")
			var/ip = input(src, "What address will you search for?") as null|text
			for(var/i=1;i<full_list_split.len;i++)
				var/list/full_list_split_two = splittext(full_list_split[i], ";")
				if (full_list_split_two[3] == ip)
					result += list(full_list_split_two)

	else if (option == "Show All")
		for(var/i=1;i<full_list_split.len;i++)
			var/list/full_list_split_two = splittext(full_list_split[i], ";")
			result += list(full_list_split_two)
	var/html = "<center><big>List of Quick Bans</big></center>"
	var/list/possibilities = list()
	if (islist(result) && !isemptylist(result))
		for (var/v = 1; v<=result.len; v++)
			if (islist(result[v]))
				possibilities += "<big><b>UID [result[v][6]]</b> (<a href='byond://?src=\ref[quickBan_handler];caller=\ref[src];quickBan_removeBan=1;quickBan_removeBan_UID=[result[v][6]];quickBan_removeBan_ckey=[result[v][1]];quickBan_removeBan_cID=[result[v][2]];quickBan_removeBan_ip=[result[v][3]]'>DELETE</a>)</big>: [result[v][1]]/[result[v][2]]/[result[v][3]], type '[result[v][4]]' ([result[v][5]]): banned for '[result[v][7]]' by [result[v][8]] on [result[v][9]]. <b>[result[v][11]]</b>. (After assigned date)"

	for (var/possibility in possibilities)
		html += "<br>"
		html += possibility

	src << browse(html, "window=quick_bans_search;")
/client/proc/find_cID(var/current = "ckey", var/currentvar = null)
	if (currentvar == null)
		return FALSE
	var/full_logs = file2text("SQL/playerlogs.txt")
	var/list/full_logs_split = splittext(full_logs, "|\n")
	for(var/i=1;i<full_logs_split.len;i++)
		var/list/full_logs_split_two = splittext(full_logs_split[i], ";")
		if (current == "ckey")
			if (full_logs_split_two[1] == currentvar)
				return full_logs_split_two[3]
		else if (current == "ip")
			if (full_logs_split_two[2] == currentvar)
				return full_logs_split_two[3]
	return FALSE

/client/proc/find_ip(var/current = "ckey", var/currentvar = null)
	if (currentvar == null)
		return FALSE
	var/full_logs = file2text("SQL/playerlogs.txt")
	var/list/full_logs_split = splittext(full_logs, "|\n")
	for(var/i=1;i<full_logs_split.len;i++)
		var/list/full_logs_split_two = splittext(full_logs_split[i], ";")
		if (current == "ckey")
			if (full_logs_split_two[1] == currentvar)
				return full_logs_split_two[2]
		else if (current == "cID")
			if (full_logs_split_two[3] == currentvar)
				return full_logs_split_two[2]
	return FALSE

/client/proc/find_ckey(var/current = "ip", var/currentvar = null)
	if (currentvar == null)
		return FALSE
	var/full_logs = file2text("SQL/playerlogs.txt")
	var/list/full_logs_split = splittext(full_logs, "|\n")
	for(var/i=1;i<full_logs_split.len;i++)
		var/list/full_logs_split_two = splittext(full_logs_split[i], ";")
		if (current == "ip")
			if (full_logs_split_two[2] == currentvar)
				return full_logs_split_two[1]
		else if (current == "cID")
			if (full_logs_split_two[3] == currentvar)
				return full_logs_split_two[1]
	return FALSE

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
			if (fields["ckey"])
				if (!fields["cID"])
					fields["cID"] = find_cID("ckey", fields["ckey"])
				if (!fields["ip"])
					fields["ip"] = find_ip("ckey", fields["ckey"])
			else if (fields["cID"])
				if (!fields["ckey"])
					fields["ckey"] = find_ckey("cID", fields["cID"])
				if (!fields["ip"])
					fields["ip"] = find_ip("cID", fields["cID"])
			else if (fields["ip"])
				if (!fields["ckey"])
					fields["ckey"] = find_ckey("ip", fields["ip"])
				if (!fields["cID"])
					fields["cID"] = find_cID("ip", fields["ip"])

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
			var/faction = input("What faction?") in list(BRITISH, PIRATES, CIVILIAN, INDIANS, PORTUGUESE, SPANISH, FRENCH, DUTCH, GREEK, ROMAN, ARAB, JAPANESE, RUSSIAN, GERMAN, AMERICAN, VIETNAMESE)
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
		fields["UID"] = num2text(rand(1, 1000*1000*1000), 20)
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
	var/banckey = fields["ckey"]
	var/bancID = fields["cID"]
	var/banip = fields["ip"]
	var/expire_info = fields["expire_info"]

	//txt database
	text2file("[fields["ckey"]];[fields["cID"]];[fields["ip"]];[fields["type"]];[fields["type_specific_info"]];[fields["UID"]];[fields["reason"]];[fields["banned_by"]];[fields["ban_date"]];[fields["expire_realtime"]];[fields["expire_info"]]|||","SQL/bans.txt")
	if (banner)
		banner << "<span class = 'notice'>You have successfully banned [banckey]/[bancID]/[banip]. This ban [lowertext(expire_info)]."
	var/M = "[key_name(banner)] banned [banckey]/[bancID]/[banip] (bantype = [fields["type"]] ([fields["type_specific_info"]])) for reason '[fields["reason"]]'. This ban [lowertext(expire_info)]."
	log_admin(M)
	message_admins(M)
	// kick whoever got banned if they're on
	if (lowertext(fields["type"]) == "server")
		for (var/client/C in clients)
			if (C.ckey == banckey)
				C.quickBan_kicked(fields["type"], fields["reason"], fields["expire_info"])
				break
	else
		if (fields["type_specific_info"])
			for (var/client/C in clients)
				if (C.ckey == banckey)
					C << "<span class = 'userdanger'>You have been [lowertext(fields["type"])]-banned ([fields["type_specific_info"]]). Reason: '[fields["reason"]]'. This ban [lowertext(expire_info)]."
					break
		else
			for (var/client/C in clients)
				if (C.ckey == banckey)
					C << "<span class = 'userdanger'>You have been [fields["type"]]-banned. Reason: '[fields["reason"]]'. This ban [lowertext(expire_info)]."
					break

/* checking if we're banned */
/client/proc/quickBan_isbanned(var/ban_type = "Server", var/type_specific_info = "nil")
	var/list/bans = list()
	var/full_banlist = file2text("SQL/bans.txt")
	var/list/full_list_split = splittext(full_banlist, "|||\n")
	for(var/i=1;i<full_list_split.len;i++)
		var/list/full_list_split_two = splittext(full_list_split[i], ";")
		if (text2num(full_list_split_two[10]) < text2num(num2text(world.realtime,20))) // ban expired?
			full_list_split_two[10] = 0
		if (full_list_split_two[1] == "[ckey]" || full_list_split_two[2] == "[computer_id]" || full_list_split_two[3] == "[address]")
			if (!(text2num(full_list_split_two[10]) < text2num(num2text(world.realtime,20)))) // not expired?
				bans += list(full_list_split_two)
	if (islist(bans) && !isemptylist(bans))
		for (var/x=1;x<=bans.len;x++)
			return list("reason" = bans[x][7],"ban_date" = bans[x][9], "expire_info" = bans[x][11])
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
	var/F = file("SQL/admins.txt")
	if (fexists(F))
		var/list/admincheck = splittext(file2text("SQL/admins.txt"),"|||\n")
		if (islist(admincheck) && !isemptylist(admincheck))
			for(var/i=1;i<admincheck.len;i++)
				var/list/admincheck_two = splittext(admincheck[i], ";")
				if (admincheck_two[1] == "[_ckey]" || admincheck_two[2] == "[cID]" || admincheck_two[3] == "[ip]")
					src << "<span class = 'danger'>You can't ban admins!</span>"
					return TRUE
	return FALSE