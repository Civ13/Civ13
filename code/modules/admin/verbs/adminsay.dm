// Admin chat (ASAY): every online staff member with an admin datum sees it.
// The line also goes to CivilizationBot's admin channel (admin.log and the
// asay webhook, like admin helps) and to the other regions of a sharded group
// (region_asay.dm). Discord admin-channel messages arrive through
// SQL/discord2admin.txt (start_messaging_loop in world.dm).
/client/proc/cmd_admin_say(msg as text)
	set category = "Admin"
	set name = "Asay"
	set desc = "Talk to the other online admins."
	if (!holder)
		to_chat(src, "Only administrators may use this command.")
		return
	if (prefs && (prefs.muted & MUTE_ADMINHELP))
		to_chat(src, "<span class='warning'>You cannot send ASAY messages (muted).</span>")
		return
	if (handle_spam_prevention(msg, MUTE_ADMINHELP))
		return
	msg = sanitize(msg)
	if (!msg)
		return
	var/rank = istext(holder.rank) ? holder.rank : ""
	log_admin("ASAY: [key_name(src)] : [msg]")
	admin_say_show(key, msg, html_encode(rank))
	discord_asay_log(key, msg)
	region_asay_outbound(key, ckey, msg, rank)

// Shows one admin chat line to every online admin. name, msg and rank are
// already sanitized or html-encoded; region is the source region's name for a
// line from another region, and discord is TRUE for a Discord message.
/proc/admin_say_show(name, msg, rank = "", region = "", discord = FALSE)
	if (!istext(name) || !length(name) || !istext(msg) || !length(msg))
		return 0
	var/prefix = length(region) ? "<small>\[[region]\]</small> " : ""
	var/suffix = discord ? " (Discord)" : ""
	var/rank_text = length(rank) ? "[rank] " : ""
	var/shown = 0
	for (var/client/C in admins)
		if (!C.holder)
			continue
		var/tag = discord ? "<IMG src='\ref[text_tag_icons]' class='text_tag' iconstate='a-discord' alt='ASAY-Discord'>" : create_text_tag("asay", "ASAY:", C)
		to_chat(C, CHAT_TYPED(CHAT_ADMIN, "<span class='admin_channel'>[tag] [prefix]<span class='name'>[rank_text][name][suffix]</span>: <span class='message'>[msg]</span></span>"))
		shown++
	return shown

// Posts one admin chat line to CivilizationBot's admin channel (admin.log and
// the asay webhook), in the format admin helps use. place is the map ID, or a
// region name for a line the mainland posts for another region.
/proc/discord_asay_log(name, text, place = null)
	if (!place)
		place = map ? map.ID : "NULL"
	var/line = "__**\[[time_stamp()]] ([place]) ASAY:**__ **[name]** [text]"
	var/admindiary = file("admin.log")
	admindiary << line
	webhook_send_asay(name, line, "asay", TRUE) // only staff (or an admin agent) can asay
	return TRUE
