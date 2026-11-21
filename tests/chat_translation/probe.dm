// Native probe of server-side chat translation (code/modules/chat/chat_translate.dm),
// included by tests/ecology_spawning/run_linux.py, never by the game DME. The
// model and the chat window are stood in for: ask_model returns canned answers
// and deliver_one records what each window would receive.
/world
	hub = ""
	hub_password = ""
	maxx = 5
	maxy = 5
	maxz = 1
	turf = /turf/floor/plating
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/client/New()
	del(src)
	return

/datum/tr_window
/datum/chat_translator/tr_probe
	var/list/answers = list() // key -> list(source, translation) or null for a failure
	var/list/asked = list()
	var/list/received = list() // "window id" -> list(source, translation)
	var/model_ticks = 2
/datum/chat_translator/tr_probe/ask_model(key)
	asked += key
	sleep(model_ticks)
	return answers[key]
/datum/chat_translator/tr_probe/deliver_one(C, id, source, translation)
	received["\ref[C] [id]"] = list(source, translation)

var/tr_failures = 0
var/tr_runtime_error = FALSE
/proc/tr_check(condition, label)
	if (!condition)
		tr_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	tr_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/tr_ask(datum/chat_translator/tr_probe/T, W, id, lang, text)
	T.handle_topic(W, list("chat_translate" = "[id]", "lang" = lang, "text" = text))

/proc/tr_got(datum/chat_translator/tr_probe/T, W, id)
	return T.received["\ref[W] [id]"]

/proc/tr_checks()
	config = new
	var/datum/chat_translator/tr_probe/T = new
	var/datum/tr_window/A = new
	var/datum/tr_window/B = new

	// Off without both settings: still answers, never asks the model.
	tr_ask(T, A, 1, "en", "hola amigo")
	tr_check(!T.asked.len && islist(tr_got(T, A, 1)) && tr_got(T, A, 1)[2] == "", "off: answered empty, model not asked")
	config.chat_translate_url = "http://127.0.0.1:11434/"
	config.chat_translate_model = "qwen3:8b"
	tr_check(T.enabled(), "on with an address and a model")

	// Bad requests are ignored.
	tr_ask(T, A, 0, "en", "hola")
	tr_ask(T, A, 2, "xx", "hola")
	tr_ask(T, A, "2.5", "en", "hola")
	tr_check(T.received.len == 1, "bad id or language gets no answer")

	// English for an English reader never reaches the model.
	tr_ask(T, A, 3, "en", "the storm is coming, get inside")
	tr_check(!T.asked.len && tr_got(T, A, 3)[2] == "", "English line skipped for English readers")
	tr_ask(T, A, 4, "en", "!!! 123")
	tr_check(!T.asked.len && tr_got(T, A, 4)[2] == "", "no letters: skipped")

	// A Spanish line: one model call shared by two readers, cached after.
	T.answers["en\nhola amigo"] = list("es", "hello friend")
	tr_ask(T, A, 5, "en", "hola amigo")
	tr_ask(T, B, 1, "en", "hola amigo")
	sleep(10)
	tr_check(T.asked.len == 1, "two readers, one model call")
	tr_check(tr_got(T, A, 5)[1] == "es" && tr_got(T, A, 5)[2] == "hello friend", "first reader gets the translation")
	tr_check(tr_got(T, B, 1)[2] == "hello friend", "second reader gets it too")
	tr_ask(T, B, 2, "en", "hola amigo")
	tr_check(T.asked.len == 1 && tr_got(T, B, 2)[2] == "hello friend", "repeat answered from the cache")

	// Accented text is never taken for English; English for a German reader goes to the model.
	T.answers["en\ncafé por favor"] = list("es", "coffee please")
	T.answers["de\nthe storm is coming"] = list("en", "der Sturm kommt")
	tr_ask(T, A, 6, "en", "café por favor")
	tr_ask(T, A, 7, "de", "the storm is coming")
	sleep(10)
	tr_check(tr_got(T, A, 6)[2] == "coffee please", "accented line translated")
	tr_check(tr_got(T, A, 7)[2] == "der Sturm kommt", "English translated for a German reader")

	// A failed call answers empty; three in a row pause translation.
	tr_ask(T, A, 8, "en", "bonjour un")
	tr_ask(T, A, 9, "en", "bonjour deux")
	tr_ask(T, A, 10, "en", "bonjour trois")
	sleep(20)
	tr_check(tr_got(T, A, 8)[2] == "" && tr_got(T, A, 10)[2] == "", "failures answered empty")
	tr_check(world.time < T.paused_until, "three failures pause translation")
	var/before = T.asked.len
	tr_ask(T, A, 11, "en", "bonjour quatre")
	tr_check(T.asked.len == before && tr_got(T, A, 11)[2] == "", "paused: answered empty, model not asked")
	T.paused_until = 0

	// Per-window limit.
	T.rate_window = world.time
	T.rate.Cut()
	for (var/i in 1 to 45)
		tr_ask(T, B, 100 + i, "en", "the line [i] is english")
	tr_check(tr_got(T, B, 145) && tr_got(T, B, 145)[2] == "" && T.rate["\ref[B]"] == 40, "a window is limited to 40 a minute")

	// Queue limit: the oldest waiting text is dropped and answered empty.
	T.model_ticks = 50
	T.rate.Cut()
	var/list/readers = list()
	for (var/i in 1 to 45)
		var/datum/tr_window/R = new
		readers += R
		tr_ask(T, R, 1, "fr", "ligne numero [i]")
	tr_check(T.queue.len == 40 && T.dropped == 4, "queue bounded ([T.queue.len] waiting, [T.dropped] dropped)")
	tr_check(islist(tr_got(T, readers[2], 1)) && !tr_got(T, readers[45], 1), "dropped line answered, newest still waiting")
	T.model_ticks = 0
	T.queue.Cut()
	T.waiting.Cut()

	// Request body and reply parsing.
	var/body = T.request_body("de", "hola")
	tr_check(findtext(body, "\"stream\":false") && findtext(body, "\"think\":false") && !findtext(body, "@false@"), "booleans are real JSON booleans")
	var/list/decoded = json_decode(body)
	tr_check(decoded["model"] == "qwen3:8b" && decoded["messages"][2]["content"] == "hola", "model and text sent")
	var/list/r = T.parse_reply(json_encode(list("message" = list("content" = "{\"source\":\"ES\",\"translation\":\" hallo \"}"))), "de", "hola")
	tr_check(r && r[1] == "es" && r[2] == "hallo", "reply parsed")
	r = T.parse_reply(json_encode(list("message" = list("content" = "{\"source\":\"de\",\"translation\":\"hola\"}"))), "de", "hola")
	tr_check(r && r[2] == "", "same language gives no translation")
	tr_check(isnull(T.parse_reply("not json", "de", "x")), "bad reply is a failure")
	tr_check(isnull(T.parse_reply(json_encode(list("message" = list("content" = "nope"))), "de", "x")), "bad content is a failure")

/world/New()
	OpenPort("none")
	try
		tr_checks()
	catch(var/exception/e)
		tr_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = tr_failures, "runtime_error" = tr_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
