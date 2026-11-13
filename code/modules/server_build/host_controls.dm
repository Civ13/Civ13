// Host Controls (Server tab): what the launcher's Host tab does for this world's own region,
// from inside the game (Val, 2026-11-13: in-game server management has parity with the
// launcher for the admin's own server).
//
// The world cannot run host actions itself, so a request is a small file in its data folder:
// data/host_request.json {"id", "action", "by"}. The host service (scripts/gaia-host, serve or
// watch) takes it on its next pass while the world is awake (about every 30 seconds), runs it
// for this world only, and answers in data/host_reply.json {"id", "ok", "result"}. It also keeps
// data/host_status.json current: busy action and phase, build, staged update, update when empty.
// The host only accepts the actions it lists in Host.WORLD_REQUESTS; everything a world does to
// itself (save and stop, save and restart, cancel a countdown) stays in the existing verbs, which
// this menu opens.

#define HOST_REQUEST_PATH "data/host_request.json"
#define HOST_REPLY_PATH "data/host_reply.json"
#define HOST_STATUS_PATH "data/host_status.json"
#define HOST_STATUS_STALE_MINUTES 5
#define HOST_REPLY_WAIT 1800 // deciseconds: a pass every ~30 s, so three minutes is generous

var/global/host_controls_waiting = null // the id of the request still waiting for its answer

/proc/host_controls_read(path)
	if(!fexists(path)) return null
	var/list/value = null
	try
		value = json_decode(file2text(path))
	catch
		return null
	return islist(value) ? value : null

// Minutes since the host last wrote its status, or null when it never did.
/proc/host_controls_status_age(list/status, now_realtime = world.realtime)
	if(!status || !isnum(status["at_minute"])) return null
	return max(0, round(now_realtime / 600) - status["at_minute"])

/proc/host_controls_short(text)
	return istext(text) ? html_encode(copytext(text, 1, 201)) : null

/proc/host_controls_status_html(list/status, now_realtime = world.realtime)
	var/list/lines = list("<b>Host controls</b>")
	var/age = host_controls_status_age(status, now_realtime)
	if(isnull(age))
		lines += "The host service has not reported for this world. Host actions need it running (launcher: Restart host service)."
		return jointext(lines, "<br>")
	if(age > HOST_STATUS_STALE_MINUTES)
		lines += "<font color='red'>The host service last reported [age] minutes ago; it may be stopped (launcher: Restart host service).</font>"
	var/region = host_controls_short(status["region"])
	var/group = host_controls_short(status["group"])
	if(region) lines += "Region: [region][group ? " of [group]" : ""]"
	var/list/operation = status["operation"]
	if(status["busy"] && islist(operation))
		lines += "Busy: [host_controls_short(operation["action"]) || "an action"] ([host_controls_short(operation["phase"]) || "under way"])"
	else if(islist(operation) && operation["phase"] == "failed" && operation["error"])
		lines += "Last action ([host_controls_short(operation["action"])]) failed: [host_controls_short(operation["error"])]"
	else
		lines += "Busy: no"
	var/built = status["built"]
	lines += "Build: [istext(built) ? copytext(built, 1, 8) : "unknown"] (Server Revision in the OOC tab has the details)"
	var/list/stage = status["stage"]
	if(status["update_pending"])
		lines += "Update: built and ready ([istext(status["staged"]) ? copytext(status["staged"], 1, 8) : "staged"])"
	else if(islist(stage) && stage["phase"] == "failed")
		lines += "Update: the last build failed: [host_controls_short(stage["error"]) || "no reason given"]"
	else if(islist(stage) && stage["phase"] && !(stage["phase"] in list("ready", "current")))
		lines += "Update: building ([host_controls_short(stage["phase"])])"
	else
		lines += "Update: none waiting"
	lines += "Update when empty: [status["update_when_empty"] ? "on" : "off"] (the whole group)"
	lines += "Sleep and wake: the world sleeps by itself once empty and saved, and a join wakes it."
	return jointext(lines, "<br>")

// Writes the request; the id, or null when the file could not be written.
/proc/host_controls_send(action, by)
	var/id = copytext(md5("[world.realtime]-[world.time]-[rand(1, 1000000)]-[action]"), 1, 17)
	fdel(HOST_REQUEST_PATH)
	if(!text2file(json_encode(list("id" = id, "action" = action, "by" = "[by]")), HOST_REQUEST_PATH) || !fexists(HOST_REQUEST_PATH))
		return null
	return id

/proc/host_controls_reply(id)
	var/list/reply = host_controls_read(HOST_REPLY_PATH)
	if(!reply || reply["id"] != id) return null
	return reply

/datum/admins/proc/host_controls()
	set category = "Server"
	set name = "Host Controls"
	set desc = "This server's host actions, as the launcher's Host tab: update, update without saving, build, update when empty, status."
	if(!check_rights(R_SERVER)) return
	var/mob/requester = usr
	var/list/status = host_controls_read(HOST_STATUS_PATH)
	to_chat(requester, "<span class='notice'>[host_controls_status_html(status)]</span>")
	var/list/choices = list(
		"Save, update and restart",
		"Update and restart without saving",
		"Build update",
		"Save and restart (same build)",
		"Save and stop",
		"Cancel planned restart",
		status && status["update_when_empty"] ? "Turn update when empty off" : "Turn update when empty on",
		"Refresh status",
		"Close")
	var/choice = WWinput(requester, "Choose a host action for this server. Actions marked as host actions need the host service running.", "Host Controls", "Close", choices)
	if(!choice || choice == "Close" || !check_rights(R_SERVER)) return
	switch(choice)
		if("Save and restart (same build)")
			save_restart_resume()
			return
		if("Save and stop")
			save_and_shut_down()
			return
		if("Cancel planned restart")
			cancel_planned_shutdown()
			return
	var/action = list(
		"Save, update and restart" = "update-handover",
		"Update and restart without saving" = "update-unsaved",
		"Build update" = "stage",
		"Turn update when empty off" = "update-when-empty-off",
		"Turn update when empty on" = "update-when-empty-on",
		"Refresh status" = "status")[choice]
	if(!action) return
	var/question = null
	switch(action)
		if("update-handover")
			question = "Build the latest master beside this world, then hand players over to it? Players keep playing while it builds and while the new build loads the save; they reconnect for a few seconds at the switch. A failed build or load leaves this world running."
		if("update-unsaved")
			question = "Update and restart WITHOUT SAVING? Anything done since the last completed save is lost. Nothing is wiped: the last completed save is backed up, the update is built first while the world keeps running, then the world is ended and starts on the new build from that save. Everyone is disconnected until it is back."
		if("stage")
			question = "Build the latest update beside this world while it keeps running? Nobody is kicked."
		if("update-when-empty-on", "update-when-empty-off")
			question = "[action == "update-when-empty-on" ? "Turn on" : "Turn off"] update when empty for every region of this group? With it on, a region that is empty and saved moves onto a newer build by itself."
	if(question && WWinput(requester, question, "Host Controls", "No", list("Yes", "No")) != "Yes") return
	if(action == "update-unsaved" && WWinput(requester, "Are you sure? Unsaved progress on this server will be lost.", "Update without saving", "No", list("Lose unsaved progress", "No")) != "Lose unsaved progress") return
	if(!check_rights(R_SERVER)) return
	if(host_controls_waiting)
		to_chat(requester, "Another host request is still waiting for the host service's answer; try again shortly.")
		return
	var/requester_ckey = requester && requester.client ? requester.client.ckey : null
	var/id = host_controls_send(action, requester_ckey)
	if(!id)
		to_chat(requester, "<span class='warning'>Could not write the host request.</span>")
		return
	host_controls_waiting = id
	log_admin("[key_name(requester)] asked the host for [action].")
	if(action != "status") message_admins("[key_name_admin(requester)] asked the host for: [choice].")
	to_chat(requester, "Sent to the host service; it answers within about 30 seconds.")
	host_controls_await(id, action, choice, requester) // returns at its first sleep

/proc/host_controls_await(id, action, choice, mob/requester)
	set waitfor = FALSE
	var/deadline = world.time + HOST_REPLY_WAIT
	var/list/reply = null
	while(world.time < deadline)
		sleep(50)
		reply = host_controls_reply(id)
		if(reply) break
	if(host_controls_waiting == id) host_controls_waiting = null
	if(!reply)
		fdel(HOST_REQUEST_PATH) // never run late
		var/late = "The host service did not answer [choice] within [round(HOST_REPLY_WAIT / 600)] minutes; the request was withdrawn. Is the host service running (launcher: Restart host service)?"
		message_admins(late)
		if(requester) to_chat(requester, "<span class='warning'>[late]</span>")
		return
	var/result = host_controls_short(reply["result"]) || "no details"
	if(reply["ok"])
		if(requester) to_chat(requester, "<span class='notice'>Host: [choice]: [result]</span>")
		if(action == "status")
			if(requester) to_chat(requester, "<span class='notice'>[host_controls_status_html(host_controls_read(HOST_STATUS_PATH))]</span>")
			return
		message_admins("Host accepted [choice]: [result]")
		if(action == "update-unsaved")
			to_chat(world, "<span class='danger'>The server will restart onto an update without saving once the update is built. Progress since the last save will be lost.</span>")
		else if(action == "update-handover")
			to_chat(world, "<span class='notice'>The server is building an update; you will be moved onto it with a short reconnect.</span>")
	else
		message_admins("Host refused [choice]: [result]")
		if(requester) to_chat(requester, "<span class='warning'>Host refused [choice]: [result]</span>")

#undef HOST_REQUEST_PATH
#undef HOST_REPLY_PATH
#undef HOST_STATUS_PATH
#undef HOST_STATUS_STALE_MINUTES
#undef HOST_REPLY_WAIT
