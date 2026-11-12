// Standalone harness for code/modules/persistence/shutdown_notice.dm: stubs the chat,
// webhook and admin helpers it calls, runs countdowns at a fast tick and writes result.json.
var/game_id = "probe"
var/list/sent = list()
var/list/said = list()
var/list/failures = list()
/proc/webhook_enabled() return TRUE
/proc/webhook_send(method, list/query) sent += "[method]:[query["event"]]:[query["kind"]]:[query["seconds"]]"
/proc/to_chat(target, message) said += message
/proc/check_rights() return TRUE
/proc/WWinput() return "Yes"
/proc/log_admin()
/proc/message_admins()
/proc/key_name()
/proc/key_name_admin()
/datum/admins/var/fakekey
/client/var/datum/admins/holder

/proc/expect(condition, message)
	if(!condition) failures += message

/world/New()
	..()
	spawn(0) probe_run()

/proc/probe_run()
	expect(planned_shutdown_time_text(1) == "1 second", "one second")
	expect(planned_shutdown_time_text(90) == "1 minute 30 seconds", "minute and seconds")
	expect(planned_shutdown_time_text(300) == "5 minutes", "whole minutes")
	expect(planned_shutdown_seconds("99999") == 3600 && planned_shutdown_seconds(-5) == 0 && planned_shutdown_seconds(null, 60) == 60, "clamping")
	// Nobody online: Discord hears of it and the stop goes ahead at once, not cancellable.
	expect(planned_shutdown_countdown("restart", 0) && !planned_shutdown_cancellable && !planned_shutdown_cancel(), "zero-second countdown")
	expect(!said.len, "a zero-second countdown says nothing in chat")
	// 12 s: the opening line, then the 10 second mark.
	var/started = world.time
	expect(planned_shutdown_countdown("maintenance", 12), "a countdown that runs out returns TRUE")
	expect(world.time - started == 120, "it lasts its seconds ([world.time - started])")
	expect(said.len == 2 && findtext(said[1], "go down for maintenance in 12 seconds") && findtext(said[2], "shutdown in 10 seconds"), "milestones: [json_encode(said)]")
	expect(planned_shutdown_status_text() == "now" && !planned_shutdown_cancellable, "after the countdown the stop is under way")
	// Called off part way.
	var/list/result = list()
	spawn(0) result += planned_shutdown_countdown("update", 600)
	sleep(20)
	expect(planned_shutdown_status_text() == "9:58" && planned_shutdown_remaining() == 598, "Status tab line ([planned_shutdown_status_text()])")
	expect(planned_shutdown_cancel("probe"), "an admin can call it off")
	sleep(20)
	expect(result.len == 1 && result[1] == FALSE, "the called-off countdown returns FALSE")
	expect(isnull(planned_shutdown_status_text()) && !planned_shutdown_cancel(), "nothing left to cancel")
	expect(json_encode(sent) == json_encode(list("shutdown_notice:scheduled:restart:0", "shutdown_notice:scheduled:maintenance:12", "shutdown_notice:scheduled:update:600", "shutdown_notice:cancelled:update:0")), "Discord notices: [json_encode(sent)]")
	text2file(json_encode(list("failures" = failures.len, "messages" = failures)), "result.json")
	del(world)
