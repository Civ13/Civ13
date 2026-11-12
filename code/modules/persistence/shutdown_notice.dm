// Planned shutdown notices (Val, 2026-11-12): "Gaia should announce when it is planning to
// shut down." Every planned stop or restart counts down in chat and on the Status tab, and
// tells Discord (webhook method "shutdown_notice") when it is planned and if it is called off.
//
// kind says what happens at the end of the countdown:
//   "restart"     the world saves and restarts by itself (Save, Restart and Resume, the daily reboot)
//   "shutdown"    the world saves and stays down until it is started again (an admin's Save and Shut Down)
//   "maintenance" the host's Save and stop or Restart from the launcher, bot or host scripts
//   "update"      the host moves the world to an updated build (Save, update and restart)
//   "fresh"       a nonpersistent round saves for recovery and restarts fresh
//   "reboot"      an admin's or agent's plain restart, without a save first
//
// restart_transaction.dm resolves planned_shutdown_countdown with text2path, because its
// standalone fixture (tests/world_save) compiles without this file.

#define PLANNED_SHUTDOWN_MAX_SECONDS 3600

var/global/planned_shutdown_at = null // world.time the planned stop happens; null when none is planned
var/global/planned_shutdown_kind = null
var/global/planned_shutdown_cancellable = FALSE
var/global/planned_shutdown_serial = 0 // bumped by every new countdown and by a cancel

/proc/planned_shutdown_seconds(value, default_seconds = 60)
	if(istext(value)) value = text2num(value)
	if(!isnum(value)) value = default_seconds
	return clamp(round(value), 0, PLANNED_SHUTDOWN_MAX_SECONDS)

/proc/planned_shutdown_time_text(seconds)
	seconds = max(0, round(seconds))
	var/minutes = round(seconds / 60)
	var/rest = seconds % 60
	if(!minutes) return "[rest] second[rest == 1 ? "" : "s"]"
	var/text = "[minutes] minute[minutes == 1 ? "" : "s"]"
	if(rest) text += " [rest] second[rest == 1 ? "" : "s"]"
	return text

/proc/planned_shutdown_noun(kind)
	switch(kind)
		if("shutdown", "maintenance") return "shutdown"
		if("update") return "update"
	return "restart"

/proc/planned_shutdown_headline(kind)
	switch(kind)
		if("shutdown") return "The server will save the world and shut down"
		if("maintenance") return "The server will save the world and go down for maintenance"
		if("update") return "The server will move to an updated build"
		if("fresh") return "The server will save and restart"
		if("reboot") return "The world will restart"
	return "The server will save the world and restart"

/proc/planned_shutdown_detail(kind)
	switch(kind)
		if("shutdown") return "Your progress will be kept for when it comes back."
		if("maintenance") return "Your progress will be kept; reconnect when it is back."
		if("update") return "You will be moved over automatically. Each level is held still for a moment while it saves, and anything done after your level is saved will not carry over."
		if("fresh") return "This nonpersistent round will start fresh; the save will be retained for recovery."
		if("reboot") return "Reconnect in a minute or two."
	return "Your progress will be kept; reconnect in a few minutes to continue."

/proc/planned_shutdown_say(kind, seconds, first = FALSE)
	if(first)
		to_chat(world, "<font color='yellow' size=4><b>Attention - [planned_shutdown_headline(kind)] in [planned_shutdown_time_text(seconds)]. [planned_shutdown_detail(kind)]</b></font>")
	else
		to_chat(world, "<font color='yellow' size=4><b>Attention - Server [planned_shutdown_noun(kind)] in [planned_shutdown_time_text(seconds)].</b></font>")

// Discord: "scheduled" (with the warning's length) or "cancelled". Delivery is asynchronous
// and a missing or failing sink never delays the countdown.
/proc/planned_shutdown_webhook(event, kind, seconds = 0, reason = null)
	if(!webhook_enabled()) return
	var/list/query = list("event" = event, "kind" = kind, "seconds" = seconds, "round" = istext(game_id) ? game_id : "")
	if(istext(reason) && length(reason)) query["reason"] = copytext(reason, 1, 201)
	try
		webhook_send("shutdown_notice", query)
	catch
		world.log << "Shutdown notice could not be queued."

// Counts down seconds and returns TRUE when the time is up, FALSE when it was called off
// (planned_shutdown_cancel) or replaced by a newer countdown. With nobody online the
// caller passes 0: Discord still hears of it and the stop goes ahead at once.
// warn_players FALSE leaves the chat to the caller (the maintenance request has its own).
/proc/planned_shutdown_countdown(kind, seconds, reason = null, warn_players = TRUE, cancellable = TRUE)
	seconds = planned_shutdown_seconds(seconds, 0)
	var/serial = ++planned_shutdown_serial
	var/at = world.time + seconds * 10
	planned_shutdown_at = at
	planned_shutdown_kind = kind
	planned_shutdown_cancellable = cancellable
	world.log << "Planned [planned_shutdown_noun(kind)] ([kind]) in [seconds] s[istext(reason) ? ": [reason]" : ""]."
	planned_shutdown_webhook("scheduled", kind, seconds, reason)
	if(!seconds)
		planned_shutdown_cancellable = FALSE
		return TRUE
	if(warn_players) planned_shutdown_say(kind, seconds, TRUE)
	for(var/mark in list(1800, 900, 600, 300, 120, 60, 30, 10, 0))
		if(mark >= seconds) continue
		// Wake every second, so a called-off countdown hands back at once.
		while(world.time < at - mark * 10)
			sleep(min(10, at - mark * 10 - world.time))
			if(planned_shutdown_serial != serial) return FALSE
		if(planned_shutdown_serial != serial) return FALSE
		if(warn_players && mark) planned_shutdown_say(kind, mark)
	planned_shutdown_cancellable = FALSE // the stop is under way now
	return TRUE

// An admin calls off the countdown. A stop already under way (the save started) cannot be.
/proc/planned_shutdown_cancel(by = null)
	if(isnull(planned_shutdown_at) || !planned_shutdown_cancellable) return FALSE
	var/kind = planned_shutdown_kind
	planned_shutdown_clear()
	to_chat(world, "<font color='yellow' size=4><b>The planned server [planned_shutdown_noun(kind)] was called off. Play on.</b></font>")
	planned_shutdown_webhook("cancelled", kind, 0, istext(by) ? "called off by [by]" : null)
	return TRUE

// Clears the Status tab line once a stop failed or was called off; the world keeps running.
/proc/planned_shutdown_clear()
	planned_shutdown_serial++
	planned_shutdown_at = null
	planned_shutdown_kind = null
	planned_shutdown_cancellable = FALSE

// Seconds left, or null when nothing is planned; the lifecycle status reports it to the host.
/proc/planned_shutdown_remaining()
	if(isnull(planned_shutdown_at)) return null
	return max(0, round((planned_shutdown_at - world.time) / 10))

/proc/planned_shutdown_status_text()
	var/left = planned_shutdown_remaining()
	if(isnull(left)) return null
	if(!left) return "now"
	return "[round(left / 60)]:[left % 60 < 10 ? "0" : ""][left % 60]"

/datum/admins/proc/cancel_planned_shutdown()
	set category = "Server"
	set name = "Cancel Planned Restart"
	set desc = "Calls off a restart or shutdown that is still counting down"
	if(!check_rights(R_SERVER)) return
	if(isnull(planned_shutdown_at))
		to_chat(usr, "No restart or shutdown is counting down.")
		return
	if(!planned_shutdown_cancellable)
		to_chat(usr, "This [planned_shutdown_noun(planned_shutdown_kind)] is already under way and cannot be called off.")
		return
	if(WWinput(usr, "Call off the planned server [planned_shutdown_noun(planned_shutdown_kind)]?", "Cancel Planned Restart", "No", list("Yes", "No")) != "Yes") return
	if(!check_rights(R_SERVER)) return
	var/who = usr.client.holder.fakekey ? "an admin" : usr.key
	var/noun = planned_shutdown_noun(planned_shutdown_kind)
	if(planned_shutdown_cancel(who))
		log_admin("[key_name(usr)] called off the planned server [noun].")
		message_admins("[key_name_admin(usr)] called off the planned server restart or shutdown.")
	else
		to_chat(usr, "The countdown already finished or was called off.")

#undef PLANNED_SHUTDOWN_MAX_SECONDS
