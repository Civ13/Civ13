/* A simpler and more flexible code for banning, designed for SQLite. Its
 * not nearly as fancy as old banning, and it wasn't worth making an interface
 * for this rather small amount of code, so its all done via BYOND's input() */

// bantypes
var/list/ban_types = list("Faction Ban", "Job Ban", "Server Ban", "Playing Ban", "OOC Ban")

/datum/quickBan_handler
/datum/quickBan_handler/Topic(href,href_list[])
	..()
	if (href_list["quickBan_removeBan"])
		var/client/caller = locate(href_list["caller"])
		var/UID = href_list["quickBan_removeBan_UID"]
		var/ckey = href_list["quickBan_removeBan_ckey"]
		var/cID = href_list["quickBan_removeBan_cID"]
		var/ip = href_list["quickBan_removeBan_ip"]

		var/bans_file = null

		if (fexists("SQL/bans.txt"))
			bans_file = "SQL/bans.txt"

		if (bans_file)
			var/details = file2text(bans_file)
			var/list/details_lines = splittext(details, "|||\n")
			if (details_lines.len)
				for(var/i=1,i<=details_lines.len,i++)
					var/list/details2 = splittext(details_lines[i], ";")
					if (findtext(details_lines[i], ";"))
						if (details2[3] == UID)
							details_lines -= details_lines[i]
							fdel(bans_file)
							for(var/L in details_lines)
								text2file("[L]|||", bans_file)

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
	var/list/result = list()
	var/list/checkedUID = list() //to prevent same ban from showing multiple times
	var/option = input(src, "Search for a ban?") in list("Yes","Show All","Cancel")
	if (option == "No")
		return
	var/list/details_lines = splittext(file2text("SQL/bans.txt"), "|||\n")
	for(var/i=1,i<=details_lines.len,i++)
		if (findtext(details_lines[i], ";"))
			var/list/presult = splittext(details_lines[i], ";")
			var/found = FALSE
			if (presult && presult.len>=11)
				for(var/tuid in checkedUID)
					if (presult[3] == tuid)
						found = TRUE
				if (!found && presult.len>=11)
					checkedUID += presult[3]
					result += list(presult)
	if (option == "Yes")
		var/option2 = input(src, "What to search for?") in list("ckey","cID","ip","Cancel")
		var/list/result3 = list()
		if (option2 == "Cancel")
			return
		else if (option2 == "ckey")
			var/_ckey = ckey(input(src, "What ckey will you search for?") as null|text)
			for(var/result2 in result)
				if (result2[9]==_ckey)
					result3 += list(result2)
		else if (option2 == "cID")
			var/cID = input(src, "What cID will you search for?") as null|text
			for(var/result2 in result)
				if (result2[11]==cID)
					result3 += list(result2)
		else if (option2 == "ip")
			var/ip = input(src, "What address will you search for?") as null|text
			for(var/result2 in result)
				if (result2[10]==ip)
					result3 += list(result2)
		result = result3

	var/html = "<center><big>List of Quick Bans</big></center>"
	var/list/possibilities = list()
	if (islist(result) && !isemptylist(result))
		for (var/list/v in result)
			possibilities += "<big><b>UID [v[3]]</b> (<a href='byond://?src=\ref[quickBan_handler];caller=\ref[src];quickBan_removeBan=1;quickBan_removeBan_UID=[v[3]];quickBan_removeBan_ckey=[v[9]];quickBan_removeBan_cID=[v[10]];quickBan_removeBan_ip=[v[11]]'>DELETE</a>)</big>: [v[9]]/[v[10]]/[v[11]], type '[v[1]]' ([v[2]]): banned for '[v[4]]' by [v[5]] on [v[6]]. <b>[v[8]]</b>. (After assigned date)"
	for (var/possibility in possibilities)
		html += "<br>"
		html += possibility

	src << browse(html, "window=quick_bans_search;")
/proc/find_cID(var/current = "ckey", var/currentvar = null)
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

/proc/find_ip(var/current = "ckey", var/currentvar = null)
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

/proc/find_ckey(var/current = "ip", var/currentvar = null)
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
			var/faction = input("What faction?") in list(BRITISH, PIRATES, CIVILIAN, INDIANS, PORTUGUESE, SPANISH, FRENCH, DUTCH, GREEK, ROMAN, ARAB, JAPANESE, RUSSIAN, GERMAN, AMERICAN, VIETNAMESE, FINNISH, NORWEGIAN, SWEDISH, DANISH, CHECHEN, FILIPINO, CHINESE, POLISH)
			fields["type_specific_info"] = faction

	reenter_bantime

	var/duration_in_x_units = input(src, "How long do you want the ban to last ('5 hours', '4 days': the default unit is days)") as text
	var/duration_in_days = text2num(ckey(splittext(duration_in_x_units, " ")[1]))
	duration_in_days = max(0,min(duration_in_days,10000))
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
	text2file("[fields["type"]];[fields["type_specific_info"]];[fields["UID"]];[fields["reason"]];[fields["banned_by"]];[fields["ban_date"]];[fields["expire_realtime"]];[fields["expire_info"]];[banckey];[bancID];[banip];|||","SQL/bans.txt")

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
	if (fexists("SQL/bans.txt"))
		var/details = file2text("SQL/bans.txt")
		var/list/details_lines = splittext(details, "|||\n")
		if (details_lines.len)
			for(var/i=1,i<=details_lines.len,i++)
				if (findtext(details_lines[i], ";"))
					var/list/details2 = splittext(details_lines[i], ";")
					if ((ckey == details2[9] || computer_id == details2[11] || address == details2[10]) && details2[1] == ban_type && details2[2] == type_specific_info && text2num(details2[7])>world.realtime)
						return TRUE
	return FALSE
/* check if we're banned and tell us why we're banned */
/client/proc/quickBan_rejected(var/bantype = "Server")

	var/list/fields = list()

	if (fexists("SQL/bans.txt"))
		var/details = file2text("SQL/bans.txt")
		var/list/details_lines = splittext(details, "|||\n")
		for(var/i=1,i<=details_lines.len,i++)
			if (findtext(details_lines[i], ";"))
				var/list/details2 = splittext(details_lines[i], ";")
				if ((ckey == details2[9] || computer_id == details2[11] || address == details2[10]) && details2[1] == bantype && text2num(details2[7])>world.realtime)
					fields = details2
	if (isemptylist(fields))
		return FALSE

	var/reason = fields[4]
	var/date = fields[6]
	var/expire_info = fields[8]

	if (reason)
		if (bantype == "Server")
			src << "<span class = 'userdanger'>You're banned. Reason: '[reason]'. This ban was assigned on [date] and [expire_info] (after assigned date)</span>"
			return TRUE
		else
			src << "<span class = 'userdanger'>You're [lowertext(bantype)]-banned. Reason: '[reason]'. This ban was assigned on [date] and [expire_info] (after assigned date)</span>"
	return FALSE

/* kick us if we just got banned */
/client/proc/quickBan_kicked(var/bantype, var/reason, var/expire_info)
	src << "<span class = 'userdanger'>You have been given a [lowertext(bantype)]-ban. Reason: '[reason]'. [expire_info].</span>"
	del src

/* check if we're an admin trying to quickBan another admin */
/client/proc/trying_to_quickBan_admin(_ckey, cID, ip)
	// check to see if we're trying to ban an admin by ckey
	var/F = "SQL/admins.txt"
	if (fexists(F))
		var/list/admincheck = splittext(file2text(F),"|||\n")
		if (islist(admincheck) && !isemptylist(admincheck))
			for(var/i in admincheck)
				var/list/admincheck_two = splittext(i, ";")
				if (admincheck_two.len && admincheck_two[1] == "[_ckey]")
					src << "<span class = 'danger'>You can't ban admins!</span>"
					return TRUE
	return FALSE



/proc/quickBan_discord(var/gckey = null, var/duration = 0, var/ban_reason = "No reason provided. Appeal in the Discord.", var/banner = "Unknown")
	if (!gckey)
		return "no ckey provided"
	if (!duration)
		return "no duration provided"
	var/list/fields = list() // as much storage as we need
	fields["ckey"] = gckey
	if (!fields["ckey"])
		return "no ckey found"
	else
		// we have one or more field, use connection logs to find the others
		if (fields["ckey"])
			if (!fields["cID"])
				fields["cID"] = find_cID("ckey", fields["ckey"])
			if (!fields["ip"])
				fields["ip"] = find_ip("ckey", fields["ckey"])

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

	fields["type"] = replacetext("Server Ban", " Ban", "")

	var/duration_in_x_units = duration
	var/duration_in_days = text2num(ckey(splittext(duration_in_x_units, " ")[1]))
	duration_in_days = max(0,min(duration_in_days,10000))
	if (!isnum(duration_in_days))
		return "duration not a number"
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
		return "wrong duration variable"

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

	fields["reason"] = ban_reason

	fields["banned_by"] = banner

	quickBan_ban(fields, src)

	return "successful."