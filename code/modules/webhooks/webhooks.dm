/proc/webhook_send_runtime(message, ckey = "", ckey2 = "") //when server logging gets fucked up, discord bot saves the day
	var/list/query = list("message" = message, "ckey" = ckey, "ckey2" = ckey2)
	webhook_send("runtimemessage", query)

/proc/webhook_send_attacklog(message, ckey = "", ckey2 = "")
	var/list/query = list("message" = message, "ckey" = ckey, "ckey2" = ckey2)
	webhook_send("attacklogmessage", query)

/proc/webhook_send_alog(ckey = "", message)
	var/list/query = list("ckey" = ckey, "message" = message)
	webhook_send("alogmessage", query)

/proc/webhook_send_asay(ckey, message)
	var/list/query = list("ckey" = ckey, "message" = message)
	webhook_send("asaymessage", query)

/proc/webhook_send_ooc(ckey, message)
	var/list/query = list("ckey" = ckey, "message" = message)
	webhook_send("oocmessage", query)

/proc/webhook_send_ic(ckey, message)
    var/list/query = list("ckey" = ckey, "message" = message)
    webhook_send("icmessage", query)

/proc/webhook_send_garbage(ckey, message)
	var/list/query = list("ckey" = ckey, "message" = message)
	webhook_send("garbage", query)

/proc/webhook_send_round_start(round = "")
    var/list/query = list("round" = round)
    webhook_send("round_start", query)

// One announcement per process, only after startup has chosen its identity.
var/global/round_start_announced = FALSE
/proc/announce_round_start_once()
	if(round_start_announced || !istext(game_id) || !length(game_id)) return FALSE
	round_start_announced = TRUE // Reserve before the asynchronous webhook dispatch.
	var/oocdiary = file("ooc.log")
	oocdiary << "> \[[time_stamp()]] New round [game_id] starting!"
	webhook_send_round_start(game_id)
	return TRUE

/proc/announce_restored_round_once()
	// Legacy saves have no historical identity. Never present a generated ID as
	// the restored one, or announce a generation that no longer matches.
	try
		var/list/state = map_storage.read_round_state()
		if(!state.len || state["game_id"] != game_id)
			world.log << "Round-start announcement suppressed: saved identity is unavailable or differs."
			return FALSE
	catch
		world.log << "Round-start announcement suppressed: saved identity could not be validated."
		return FALSE
	return announce_round_start_once()

/proc/webhook_send_login(ckey, ip = "", cid = "")
    var/list/query = list("ckey" = ckey, "ip" = ip, "cid" = cid)
    webhook_send("login", query)

/proc/webhook_send_logout(ckey)
    var/list/query = list("ckey" = ckey)
    webhook_send("logout", query)

/proc/webhook_send(method, data)
	if (!config || !config.webhook_can_fire)
		return
	if (!config.webhook_address || !config.webhook_key)
		return

	var/query = "[config.webhook_address]?key=[config.webhook_key]&method=[method]&data=[url_encode(json_encode(data))]"
	spawn(-1)
		world.Export(query)
