/proc/webhook_send_roundstatus(status, extraData)
	var/list/query = list("status" = status)

	if(extraData)
		query.Add(extraData)

	webhook_send("roundstatus", query)

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

/proc/webhook_send_lobby(ckey, message)
	var/list/query = list("ckey" = ckey, "message" = message)
	webhook_send("lobbymessage", query)

/proc/webhook_send_me(ckey, message)
	var/list/query = list("ckey" = ckey, "message" = message)
	webhook_send("memessage", query)

/proc/webhook_send_ahelp(ckey, message)
	var/list/query = list("ckey" = ckey, "message" = message)
	webhook_send("ahelpmessage", query)

/proc/webhook_send_garbage(ckey, message)
	var/list/query = list("ckey" = ckey, "message" = message)
	webhook_send("garbage", query)

/proc/webhook_send_token(ckey, token)
	var/list/query = list("ckey" = ckey, "token" = token)
	webhook_send("token", query)

/proc/webhook_send_respawn_notice(ckey, message)
    var/list/query = list("ckey" = ckey, "message" = message)
    webhook_send("respawn_notice", query)

/proc/webhook_send_login(ckey, ip = "", cid = "")
    var/list/query = list("ckey" = ckey, "ip" = ip, "cid" = cid)
    webhook_send("login", query)

/proc/webhook_send_logout(ckey)
    var/list/query = list("ckey" = ckey)
    webhook_send("logout", query)

/proc/webhook_send_status_update(event, data)
	var/list/query = list("event" = event, "data" = data)
	webhook_send("status_update", query)

/proc/webhook_send(method, data)
	if (!config.webhook_can_fire)
		return
	if (!config.webhook_address || !config.webhook_key)
		return

	var/query = "[config.webhook_address]?key=[config.webhook_key]&method=[method]&data=[url_encode(json_encode(data))]"
	spawn(-1)
		world.Export(query)
