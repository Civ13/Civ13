//print an error message to world.log

//wrapper macros for easier grepping
#define DIRECT_INPUT(A, B) A >> B
#define SEND_IMAGE(target, image) DIRECT_OUTPUT(target, image)
#define SEND_SOUND(target, sound) DIRECT_OUTPUT(target, sound)
#define WRITE_FILE(file, text) DIRECT_OUTPUT(file, text)
#define READ_FILE(file, text) DIRECT_INPUT(file, text)
//This is an external call, "true" and "false" are how rust parses out booleans
#define WRITE_LOG(log, text) rustg_log_write(log, text, "true")
#define WRITE_LOG_NO_FORMAT(log, text) rustg_log_write(log, text, "false")


// On Linux/Unix systems the line endings are LF, on windows it's CRLF, admins that don't use notepad++
// will get logs that are one big line if the system is Linux and they are using notepad.  This solves it by adding CR to every line ending
// in the logs.  ascii character 13 = CR

/var/global/log_end= world.system_type == UNIX ? ascii2text(13) : ""


/proc/error(msg)
	webhook_send_runtime("## ERROR: [msg][log_end]")
	world.log << "## ERROR: [msg][log_end]"


#define WARNING(MSG) warning("[MSG] in [__FILE__] at line [__LINE__] src: [src] usr: [usr].")
//print a warning message to world.log
/proc/warning(msg)
	webhook_send_runtime("## WARNING: [msg][log_end]")
	world.log << "## WARNING: [msg][log_end]"

//print a testing-mode debug message to world.log
/proc/testing(msg)
	webhook_send_runtime("## TESTING: [msg][log_end]")
	world.log << "## TESTING: [msg][log_end]"

/proc/game_log(category, text)
	diary << "\[[time_stamp()]] [game_id] [category]: [text][log_end]"

//sends OOC to a file readable by a bot, who then sends it to the Discord
/proc/discord_log(name,text)
	var/oocdiary = file("ooc.log")
	if (map)
		oocdiary << "__**\[[time_stamp()]] ([map.ID]) OOC:**__ **[name]** [text]"

/proc/discord_admin_log(name,text)
	var/admindiary = file("admin.log")
	if (map)
		admindiary << "__**\[[time_stamp()]] ([map.ID]) ASAY:**__ **[name]** [text]"

/proc/discord_ahelp_log(name,text)
	var/admindiary = file("admin.log")
	if (map)
		admindiary << "__**\[[time_stamp()]] ([map.ID]) AHELP:**__ **[name]** [text]"

/proc/discord_mentorhelp_log(name,text)
	var/admindiary = file("admin.log")
	if (map)
		admindiary << "__**\[[time_stamp()]] ([map.ID]) MENTORHELP:**__ **[name]** [text]"

/proc/discord_adminpm_log(name,text,aname)
	var/admindiary = file("admin.log")
	if (map)
		admindiary << "__**\[[time_stamp()]] ([map.ID]) ADMINPM TO **[aname]**:**__ **[name]** [text]"
		webhook_send_asay(name, "__**\[[time_stamp()]] ([map.ID]) ADMINPM TO **[aname]**:**__ **[name]** [text]")
	else webhook_send_asay(name, "__**\[[time_stamp()]] (NULL) ADMINPM TO **[aname]**:**__ **[name]** [text]")

/proc/discord_admin_ban(banner,banned,duration,reason)
	var/admindiary = file("admin.log")
	if (map)
		admindiary << "__**\[[time_stamp()]] ([map.ID])** [banner] **HAS BANNED** [banned] for [duration], with the reason \"[reason]\""

/proc/discord_admin_unban(banner,banned)
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
					if (details2[9] == banned)
						details_lines -= details_lines[i]
						fdel(bans_file)
						for(var/L in details_lines)
							text2file("[L]|||", bans_file)

		log_admin("[banner] unbanned '[banned]' using the Discord.")
		message_admins("[banner] unbanned '[banned]' using the Discord.")
		for (var/client/C in clients)
			if (C.ckey == banned)
				C << "<span class = 'good'>href_list["Your ban has been lifted."]</span>"
/proc/attack_log(category, text)
	attack_log << "\[[time_stamp()]] [game_id] [category]: [text][log_end]"

/proc/log_admin(text)
	admin_log.Add(text)
	if (config.log_admin)
		game_log("ADMIN", text)

/proc/log_discord(text)
	if (config.log_admin)
		game_log("DISCORD", text)

/proc/log_discord_asay(text)
	if (config.log_admin)
		game_log("DISCORD-ASAY", text)

/proc/log_debug(text)
	if (config.log_debug)
		game_log("DEBUG", text)

	for (var/client/C in admins)
		if (C.is_preference_enabled(/datum/client_preference/admin/show_debug_logs))
			C << "<span class=\"log_message\">DEBUG: [text]</span>"

/proc/log_game(text)
	if (config.log_game)
		game_log("GAME", text)

/proc/log_vote(text)
	if (config.log_vote)
		game_log("VOTE", text)

/proc/log_access(text)
	if (config.log_access)
		game_log("ACCESS", text)

/proc/log_say(text)
	if (config.log_say)
		game_log("SAY", text)

/proc/log_ooc(text)
	if (config.log_ooc)
		game_log("OOC", text)

/proc/log_whisper(text)
	if (config.log_whisper)
		game_log("WHISPER", text)

/proc/log_emote(text)
	if (config.log_emote)
		game_log("EMOTE", text)

/proc/log_attack(text)
	if (config.log_attack)
		attack_log("ATTACK", text)

/proc/log_adminwarn(text)
	if (config.log_adminwarn)
		game_log("ADMINWARN", text)

/proc/log_to_dd(text)
	world.log << text //this comes before the config check because it can't possibly runtime
	if (config.log_world_output)
		game_log("DD_OUTPUT", text)

/proc/log_misc(text)
	game_log("MISC", text)

/proc/log_unit_test(text)
	world.log << "## UNIT_TEST ##: [text]"
	log_debug(text)

//pretty print a direction bitflag, can be useful for debugging.
/proc/print_dir(var/dir)
	var/list/comps = list()
	if (dir & NORTH) comps += "NORTH"
	if (dir & SOUTH) comps += "SOUTH"
	if (dir & EAST) comps += "EAST"
	if (dir & WEST) comps += "WEST"
	if (dir & UP) comps += "UP"
	if (dir & DOWN) comps += "DOWN"

	return english_list(comps, nothing_text="0", and_text="|", comma_text="|")

//more or less a logging utility
/proc/key_name(var/whom, var/include_link = null, var/include_name = TRUE, var/highlight_special_characters = TRUE)
	var/mob/M
	var/client/C
	var/key

	if (!whom)	return "*null*"
	if (istype(whom, /client))
		C = whom
		M = C.mob
		key = C.key
	else if (ismob(whom))
		M = whom
		C = M.client
		key = M.key
	else if (istype(whom, /datum/mind))
		var/datum/mind/D = whom
		key = D.key
		M = D.current
		if (D.current)
			C = D.current.client
	else if (istype(whom, /datum))
		var/datum/D = whom
		return "*invalid:[D.type]*"
	else
		return "*invalid*"

	. = ""

	if (key)
		if (include_link && C)
			. += "<a href='?priv_msg=\ref[C]'>"

		if (C && C.holder && C.holder.fakekey && !include_name)
			. += "Administrator"
		else
			. += key

		if (include_link)
			if (C)	. += "</a>"
			else	. += " (DC)"
	else
		. += "*no key*"

	if (include_name && M)
		var/name

		if (M.real_name)
			name = M.real_name
		else if (M.name)
			name = M.name


		if (include_link && is_special_character(M) && highlight_special_characters)
			. += "/(<font color='#FFA500'>[name]</font>)" //Orange
		else
			. += "/([name])"

	return .

/proc/key_name_admin(var/whom, var/include_name = TRUE)
	return key_name(whom, TRUE, include_name)


// Helper procs for building detailed log lines
/datum/proc/log_info_line()
	return "[src] ([type])"

/atom/log_info_line()
	var/turf/t = get_turf(src)
	return "[src] ([t ? t : "NULL"]) ([t ? t.x : 0],[t ? t.y : 0],[t ? t.z : 0]) ([t ? t.type : "NULL"])"

/mob/log_info_line()
	return "[..()] ([ckey])"

/turf/log_info_line()
	return "[src] ([loc]) ([x],[y],[z]) ([loc.type])"

/proc/log_info_line(var/datum/d)
	if(!istype(d))
		return
	return d.log_info_line()
