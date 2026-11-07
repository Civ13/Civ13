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

// resumed tells the bot this round was loaded from a save, not freshly started.
/proc/webhook_send_round_start(round = "", resumed = FALSE)
    var/list/query = list("round" = round, "resumed" = resumed ? TRUE : FALSE)
    webhook_send("round_start", query)

// One announcement per process, only after startup has chosen its identity.
var/global/round_start_announced = FALSE
/proc/announce_round_start_once(resumed = FALSE)
	if(round_start_announced || !istext(game_id) || !length(game_id)) return FALSE
	round_start_announced = TRUE // Reserve before the asynchronous webhook dispatch.
	var/oocdiary = file("ooc.log")
	oocdiary << "> \[[time_stamp()]] [resumed ? "Resumed round [game_id] from save" : "New round [game_id] starting"]!"
	webhook_send_round_start(game_id, resumed)
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
	return announce_round_start_once(TRUE)

/proc/webhook_send_login(ckey, ip = "", cid = "")
    var/list/query = list("ckey" = ckey, "ip" = ip, "cid" = cid)
    webhook_send("login", query)

/proc/webhook_send_logout(ckey)
    var/list/query = list("ckey" = ckey)
    webhook_send("logout", query)

// Webhooks leave the game loop (2026-11-07). world.Export blocks the whole
// server until the bot answers, spawn() or not, and one IC say line is one
// Export, so a busy table stalled every tick on the bot's round trip. Requests
// queue here and go out through rust_g's asynchronous HTTP, one at a time in
// order, checked once a tick. The game never waits on the bot again.
#define WEBHOOK_QUEUE_LIMIT 500
#define WEBHOOK_REQUEST_TICKS 100 // ticks one request may take before it is abandoned

var/global/datum/webhook_dispatcher/webhook_dispatcher = new

/datum/webhook_dispatcher
	var/list/queue = list()
	var/running = FALSE
	var/sent = 0
	var/failed = 0
	var/dropped = 0 // oldest requests discarded because the bot fell too far behind
	var/blocking = FALSE // rust_g refused: fall back to world.Export, as before 2026-11-07

/datum/webhook_dispatcher/proc/enqueue(query)
	if (!istext(query) || !length(query))
		return FALSE
	if (queue.len >= WEBHOOK_QUEUE_LIMIT)
		queue.Cut(1, 2)
		dropped++
		if (dropped == 1 || !(dropped % 100))
			world.log << "Webhooks: the bot is not keeping up; [dropped] requests dropped so far."
	queue += query
	if (!running)
		running = TRUE
		drain()
	return TRUE

/datum/webhook_dispatcher/proc/drain()
	set waitfor = FALSE
	while (queue.len)
		var/query = queue[1]
		queue.Cut(1, 2)
		if (deliver(query))
			sent++
		else
			failed++
	running = FALSE

// TRUE when the bot answered. Only the request in flight is checked, once a
// tick; a request the bot has not answered after WEBHOOK_REQUEST_TICKS is
// abandoned so one hung bot cannot hold the queue.
/datum/webhook_dispatcher/proc/deliver(query)
	if (blocking)
		return islist(world.Export(query))
	var/datum/http_request/R = new
	R.prepare(RUSTG_HTTP_METHOD_GET, query, "", list())
	try
		R.begin_async()
	catch
		// No rust_g at all: deliver the way webhooks always were, and say so once.
		blocking = TRUE
		world.log << "Webhooks: rust_g is unavailable; webhooks block the server again."
		return islist(world.Export(query))
	for (var/i in 1 to WEBHOOK_REQUEST_TICKS)
		if (R.is_complete())
			break
		sleep(1)
	if (!R.is_complete())
		return FALSE
	var/datum/http_response/response = R.into_response()
	return !response.error

// One line for the Debug Controller and the status probe.
/datum/webhook_dispatcher/proc/summary()
	return "queued [queue.len], sent [sent], failed [failed], dropped [dropped][blocking ? ", blocking fallback" : ""]"

#undef WEBHOOK_QUEUE_LIMIT
#undef WEBHOOK_REQUEST_TICKS

/proc/webhook_send(method, data)
	if (!config || !config.webhook_can_fire)
		return
	if (!config.webhook_address || !config.webhook_key)
		return

	var/query = "[config.webhook_address]?key=[config.webhook_key]&method=[method]&data=[url_encode(json_encode(data))]"
	webhook_dispatcher.enqueue(query)
