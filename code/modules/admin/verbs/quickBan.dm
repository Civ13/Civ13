/* A simpler and more flexible code for banning, designed for SQLite. Its
 * not nearly as fancy as old banning, and it wasn't worth making an interface
 * for this rather small amount of code, so its all done via BYOND's input() */

// bantypes
var/list/ban_types = list("Faction Ban", "Job Ban", "Server Ban", "Playing Ban", "OOC Ban")

/datum/quickBan_handler
/datum/quickBan_handler/Topic(href,href_list[])
	..()
	if (href_list["quickBan_removeBan"])
		var/client/callers = locate(href_list["caller"])
		quickBan_remove_uid(href_list["quickBan_removeBan_UID"], callers ? callers.key : "Unknown", callers ? callers.mob : null)

var/datum/quickBan_handler/quickBan_handler = null

/* admin procedures */
// Alt lookups read every region's connections (shared_player_records.dm),
// then this region's own log for anything the snapshot does not have yet.
/proc/quickBan_find_local(current, currentvar, want)
	if (!fexists("SQL/playerlogs.txt"))
		return FALSE
	var/list/columns = list("ckey" = 1, "ip" = 2, "cID" = 3)
	var/full_logs = file2text("SQL/playerlogs.txt")
	var/list/full_logs_split = splittext(full_logs, "|\n")
	for(var/i=1;i<full_logs_split.len;i++)
		var/list/full_logs_split_two = splittext(full_logs_split[i], ";")
		if (full_logs_split_two.len >= 3 && full_logs_split_two[columns[current]] == currentvar)
			return full_logs_split_two[columns[want]]
	return FALSE

/proc/quickBan_find(current, currentvar, want)
	if (currentvar == null)
		return FALSE
	var/list/fields = list("ckey" = "ckey", "ip" = "ip", "cID" = "cid")
	var/found = shared_records.find_connection(fields[current], currentvar, fields[want])
	if (found)
		return found
	return quickBan_find_local(current, currentvar, want)

/proc/find_cID(var/current = "ckey", var/currentvar = null)
	return quickBan_find(current, currentvar, "cID")

/proc/find_ip(var/current = "ckey", var/currentvar = null)
	return quickBan_find(current, currentvar, "ip")

/proc/find_ckey(var/current = "ip", var/currentvar = null)
	return quickBan_find(current, currentvar, "ckey")

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
		fields["ip"] = C.public_address()
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
			var/faction = input("What faction?") in list(BRITISH, PIRATES, CIVILIAN, INDIANS, PORTUGUESE, SPANISH, FRENCH, DUTCH, ITALIAN, GREEK, ROMAN, ARAB, JAPANESE, RUSSIAN, GERMAN, AMERICAN, VIETNAMESE, FINNISH, NORWEGIAN, SWEDISH, DANISH, CHECHEN, FILIPINO, CHINESE, POLISH, BLUEFACTION, REDFACTION, CAFR, TSFSR)
			fields["type_specific_info"] = faction

	reenter_bantime:

	var/duration_in_x_units = input(src, "How long do you want the ban to last ('5 hours', '4 days': the default unit is days)") as text
	var/duration_in_days = text2num(ckey(splittext(duration_in_x_units, " ")[1]))
	duration_in_days = max(0,min(duration_in_days,10000))
	if (!isnum(duration_in_days))
		to_chat(src, "<span class = 'warning'>Invalid amount.</span>")
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
		to_chat(src, "<span class = 'warning'>Invalid unit.</span>")
		goto reenter_bantime

	fields["until"] = shared_records.unix_add(shared_records.now_unix(), round(duration_in_days * 86400))

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

	reenter_reason:
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
	if (!fields.Find("until"))
		fields["until"] = "0"
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

/* ban types and shared ban scopes */
// Bans are shared player records (shared_player_records.dm), so a ban made on
// one region holds on every region. scope groups the types: game is a server
// ban, play keeps someone out of play, ooc mutes OOC, and job covers the rest.
/proc/quickBan_scope(ban_type)
	switch (ban_type)
		if ("Server")
			return "game"
		if ("Playing", "Observe", "Penal")
			return "play"
		if ("OOC")
			return "ooc"
	return "job"

/* the actual banning procedure */
/proc/quickBan_ban(var/list/fields, var/client/banner = null)

	if (!fields)
		fields = list()
	quickBan_sanitize_fields(fields)
	var/banckey = fields["ckey"]
	var/bancID = fields["cID"]
	var/banip = fields["ip"]
	var/expire_info = fields["expire_info"]

	var/list/body = list("scope" = quickBan_scope(fields["type"]), "type" = fields["type"], "info" = fields["type_specific_info"],
		"uid" = fields["UID"], "cid" = bancID, "ip" = banip, "reason" = fields["reason"], "banned_by" = fields["banned_by"],
		"ban_date" = fields["ban_date"], "expire_info" = expire_info, "until" = fields["until"])
	// A ban by computer id or IP alone has no ckey; it is kept under "@nockey".
	var/record_ckey = (banckey && banckey != "nil") ? banckey : "@nockey"
	var/list/record = shared_records.add(record_ckey, "ban", body, banner ? banner.ckey : ckey(fields["banned_by"]),
		(banner && banner.holder) ? banner.holder.rank : "Discord")
	if (!record)
		if (banner)
			to_chat(banner, "<span class = 'warning'>The ban could not be recorded.</span>")
		log_admin("quickBan: the ban of [banckey]/[bancID]/[banip] could not be recorded.")
		return FALSE
	var/M = ""
	if (banner)
		to_chat(banner, "<span class = 'notice'>You have successfully banned [banckey]/[bancID]/[banip] on every region. This ban [lowertext(expire_info)].")
		M = "[key_name(banner)] banned [banckey]/[bancID]/[banip] (bantype = [fields["type"]] ([fields["type_specific_info"]])) for reason '[fields["reason"]]'. This ban [lowertext(expire_info)]."
		message_admins(M, key_name(banner))
	else
		M = "An admin on Discord banned [banckey]/[bancID]/[banip] (bantype = [fields["type"]] ([fields["type_specific_info"]])) for reason '[fields["reason"]]'. This ban [lowertext(expire_info)]."
		message_admins(M, "Admin on Discord")
	log_admin(M)
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
					to_chat(C, "<span class = 'userdanger'>You have been [lowertext(fields["type"])]-banned ([fields["type_specific_info"]]). Reason: '[fields["reason"]]'. This ban [lowertext(expire_info)].")
					break
		else
			for (var/client/C in clients)
				if (C.ckey == banckey)
					to_chat(C, "<span class = 'userdanger'>You have been [fields["type"]]-banned. Reason: '[fields["reason"]]'. This ban [lowertext(expire_info)].")
					break
	return TRUE

// The first active ban of ban_type (with type_specific_info, unless any_info)
// on this ckey, computer id or IP, from any region. Null when none.
/proc/quickBan_find_ban(ckey, cid, ip, ban_type, type_specific_info = "nil", any_info = FALSE)
	for (var/list/ban in shared_records.active_bans_matching(null, quickBan_scope(ban_type)))
		if (ban["type"] != ban_type)
			continue
		if (!any_info && ban["info"] != type_specific_info)
			continue
		if ((ckey && ban["ckey"] == ckey) || (cid && cid != "nil" && ban["cid"] == cid) || (ip && ip != "nil" && ban["ip"] == ip))
			return ban
	return null

/* checking if we're banned */
/client/proc/quickBan_isbanned(var/ban_type = "Server", var/type_specific_info = "nil")
	return quickBan_find_ban(ckey, computer_id, public_address(), ban_type, type_specific_info) ? TRUE : FALSE

/* check if we're banned and tell us why we're banned */
/client/proc/quickBan_rejected(var/bantype = "Server")
	var/list/ban = quickBan_find_ban(ckey, computer_id, public_address(), bantype, any_info = TRUE)
	if (!ban)
		return FALSE

	var/reason = ban["reason"]
	var/date = ban["ban_date"]
	var/expire_info = ban["expire_info"]

	if (reason)
		if (bantype == "Server")
			to_chat(src, "<span class = 'userdanger'>You're banned. Reason: '[reason]'. This ban was assigned on [date] and [expire_info] (after assigned date)</span>")
			return TRUE
		else
			to_chat(src, "<span class = 'userdanger'>You're [lowertext(bantype)]-banned. Reason: '[reason]'. This ban was assigned on [date] and [expire_info] (after assigned date)</span>")
	return FALSE

/* lifting bans */
// Lifts one ban (from active_bans_matching()) on every region.
/proc/quickBan_lift(list/ban, unbanner, mob/user = null)
	if (!islist(ban))
		return FALSE
	var/list/target = list("id" = ban["id"], "kind" = "ban", "ckey" = ban["ckey"])
	if (!shared_records.revoke(target, user ? user.ckey : ckey(unbanner), (user && user.client && user.client.holder) ? user.client.holder.rank : "Discord", "lifted by [unbanner]"))
		return FALSE
	log_admin("[unbanner] removed a ban for '[ban["uid"]]/[ban["ckey"]]/[ban["cid"]]/[ban["ip"]]'.")
	message_admins("[unbanner] removed a ban for '[ban["uid"]]/[ban["ckey"]]/[ban["cid"]]/[ban["ip"]]'.", unbanner)
	for (var/client/C in clients)
		if (C.ckey == ban["ckey"])
			to_chat(C, "<span class = 'good'>Your ban has been lifted.</span>")
	return TRUE

/proc/quickBan_remove_uid(UID, unbanner, mob/user = null)
	if (!UID)
		return FALSE
	for (var/list/ban in shared_records.active_bans_matching(null, "any"))
		if (ban["uid"] == UID)
			return quickBan_lift(ban, unbanner, user)
	return FALSE

// Lifts every active ban on ckey (Discord unban).
/proc/quickBan_lift_ckey(ckey, unbanner)
	. = 0
	for (var/list/ban in shared_records.active_bans(ckey, "any"))
		if (quickBan_lift(ban, unbanner))
			.++

/client/proc/quickBan_unban()
	set category = "Bans"
	set name = "Unban"
	if (!holder)
		return
	var/wanted = ckey(input(src, "Whose bans? (ckey; leave blank for every active ban)") as null|text)
	var/list/choices = list()
	for (var/list/ban in (wanted ? shared_records.active_bans(wanted, "any") : shared_records.active_bans_matching(null, "any")))
		var/until = ban["until"] == "0" ? "never ends" : "ends [shared_records.time_text(ban["until"])]"
		choices["[ban["ckey"]] - [ban["type"]][ban["info"] != "nil" ? " ([ban["info"]])" : ""] - [ban["reason"]] - [until] - #[ban["uid"]]"] = ban
	if (!choices.len)
		to_chat(src, "<span class = 'notice'>No active bans found.</span>")
		return
	var/choice = input(src, "Which ban do you want to lift on every region?") as null|anything in choices
	if (!choice || alert(src, "Lift this ban on every region?\n[choice]", "Unban", "Yes", "No") != "Yes")
		return
	quickBan_lift(choices[choice], key, mob)

/* old ban lists */
// Copies this region's SQL/bans.txt (still active bans) and SQL/playerlogs.txt
// into the shared records once. Ids come from their content, so the same ban
// or connection copied on several regions is stored once. The files are kept.
/proc/quickBan_migrate_legacy()
	if (fexists("SQL/bans.migrated"))
		return 0
	var/bans = 0
	var/seen = 0
	var/now = shared_records.now_unix()
	shared_records.hold_save = TRUE
	if (fexists("SQL/bans.txt"))
		for (var/line in splittext(file2text("SQL/bans.txt"), "|||\n"))
			var/list/f = splittext(line, ";")
			if (f.len < 11)
				continue
			// expire_realtime: deciseconds since 2000 as a digit string.
			var/expire = f[7]
			if (!shared_records.unix_valid(expire) || length(expire) < 2)
				continue
			var/until = shared_records.unix_add(copytext(expire, 1, length(expire)), 946684800)
			if (!shared_records.unix_after(until, now))
				continue
			var/ban_ckey = ckey(f[9])
			var/list/body = list("scope" = quickBan_scope(f[1]), "type" = f[1], "info" = f[2], "uid" = f[3], "reason" = f[4],
				"banned_by" = f[5], "ban_date" = f[6], "expire_info" = f[8], "cid" = f[10], "ip" = f[11], "until" = until, "legacy" = TRUE)
			if (shared_records.add((ban_ckey && ban_ckey != "nil") ? ban_ckey : "@nockey", "ban", body, ckey(f[5]), "",
				md5("civ13-legacy-ban|[f[3]]|[ban_ckey]|[f[1]]|[f[2]]")))
				bans++
	if (fexists("SQL/playerlogs.txt"))
		for (var/line in splittext(file2text("SQL/playerlogs.txt"), "|\n"))
			var/list/f = splittext(line, ";")
			if (f.len < 3 || !length(ckey(f[1])))
				continue
			var/known = ckey(f[1])
			if (shared_records.add(known, "connection", list("ip" = f[2], "cid" = f[3]), "", "", md5("civ13-connection|[known]|[f[2]]|[f[3]]")))
				seen++
	shared_records.hold_save = FALSE
	shared_records.save_journal()
	text2file("[bans] bans and [seen] connections copied to the shared player records.", "SQL/bans.migrated")
	log_admin("Shared player records: copied [bans] active bans and [seen] connections from this region.")
	return bans

/* kick us if we just got banned */
/client/proc/quickBan_kicked(var/bantype, var/reason, var/expire_info)
	to_chat(src, "<span class = 'userdanger'>You have been given a [lowertext(bantype)]-ban. Reason: '[reason]'. [expire_info].</span>")
	del src

/* check if we're an admin trying to quickBan another admin */
/client/proc/trying_to_quickBan_admin(_ckey, cID, ip)
	// check to see if we're trying to ban an admin by ckey
	var/F = admins_file()
	if (fexists(F))
		var/list/admincheck = splittext(file2text(F),"|||\n")
		if (islist(admincheck) && !isemptylist(admincheck))
			for(var/i in admincheck)
				var/list/admincheck_two = splittext(i, ";")
				if (admincheck_two.len && admincheck_two[1] == "[_ckey]")
					to_chat(src, "<span class = 'danger'>You can't ban admins!</span>")
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

	fields["until"] = shared_records.unix_add(shared_records.now_unix(), round(duration_in_days * 86400))

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

	quickBan_ban(fields, null)

	return "successful."