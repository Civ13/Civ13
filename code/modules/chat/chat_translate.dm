// Server-side chat translation (docs/chat-translation.md, Val 2026-11-21:
// "All chat should be automatically translated to the user's configured
// language, which defaults to English").
//
// Dream Seeker's WebView2 has the browser Translator API but no language
// models, so the chat window asks the server instead. The page sends the text
// of a new line it already received (the understood, chat-tr part only) with
// the reader's language; this world asks the host's Edge translator service
// (tools/edge-translator, Microsoft Edge's on-device Translator) and answers
// that one client. Nothing is stored on disk. Off unless CHAT_TRANSLATE_URL is
// set (Val, 2026-11-21: Edge, not Ollama).

#define CHAT_TRANSLATE_MAX_CHARS 500
#define CHAT_TRANSLATE_QUEUE_LIMIT 40 // distinct texts waiting for the translator
#define CHAT_TRANSLATE_CACHE_LIMIT 1000
#define CHAT_TRANSLATE_CLIENT_PER_MINUTE 40
#define CHAT_TRANSLATE_REQUEST_TICKS 200 // abandon a call after 20 seconds
#define CHAT_TRANSLATE_FAILURE_LIMIT 3
#define CHAT_TRANSLATE_PAUSE 3000 // five minutes off after repeated failures

var/global/datum/chat_translator/chat_translator = new

// The languages the chat window offers (TRANSLATE_LANGS in chat.html).
var/global/list/chat_translate_languages = list(
	"en" = "English", "es" = "Spanish", "pt" = "Portuguese", "fr" = "French", "de" = "German",
	"it" = "Italian", "nl" = "Dutch", "pl" = "Polish", "ru" = "Russian", "uk" = "Ukrainian",
	"tr" = "Turkish", "sv" = "Swedish", "fi" = "Finnish", "cs" = "Czech", "ro" = "Romanian",
	"el" = "Greek", "ar" = "Arabic", "hi" = "Hindi", "id" = "Indonesian", "vi" = "Vietnamese",
	"th" = "Thai", "zh" = "Chinese", "ja" = "Japanese", "ko" = "Korean")

// Common English chat words. A line in plain letters where a quarter of the
// words are on this list is English and never reaches the translator.
var/global/list/chat_translate_english_words = list(
	"the", "a", "an", "and", "or", "but", "is", "are", "was", "were", "be", "been", "am",
	"i", "you", "he", "she", "it", "we", "they", "me", "him", "her", "us", "them",
	"my", "your", "his", "its", "our", "their", "this", "that", "these", "those",
	"to", "of", "in", "on", "at", "for", "with", "from", "by", "up", "down", "out", "into",
	"what", "where", "when", "why", "how", "who", "which", "do", "does", "did", "dont",
	"have", "has", "had", "can", "cant", "will", "would", "should", "could", "not", "no",
	"yes", "yeah", "ok", "okay", "hi", "hey", "hello", "thanks", "thank", "please", "lol",
	"go", "come", "get", "got", "need", "want", "know", "just", "here", "there", "now",
	"im", "its", "whats", "lets", "some", "all", "any", "one", "if", "so", "too", "very")

/datum/chat_translator
	var/tmp/list/queue = list() // keys waiting for the translator, oldest first
	var/tmp/list/waiting = list() // key -> list of list(client, id)
	var/tmp/list/cache = list() // key -> list(source, translation); translation "" when none is needed
	var/tmp/running = FALSE
	var/tmp/failures = 0
	var/tmp/paused_until = 0
	var/tmp/no_rust_g = FALSE
	var/tmp/translated = 0
	var/tmp/dropped = 0
	var/tmp/list/rate = list() // "\ref[client]" -> requests in this minute
	var/tmp/rate_window = 0

/datum/chat_translator/proc/enabled()
	return config && istext(config.chat_translate_url) && length(config.chat_translate_url) && !no_rust_g

// Tells a chat window whether this world translates for it. Sent once the page
// is ready (/datum/chat/proc/on_ready).
/datum/chat_translator/proc/announce(client/C)
	if (C)
		C << output(enabled() ? "1" : "0", "browser_chat:setTranslateServer")

// The page's request: chat_translate=<id>&lang=<code>&text=<plain text>.
/datum/chat_translator/proc/handle_topic(client/C, list/href_list)
	if (!C)
		return
	var/id = text2num(href_list["chat_translate"])
	var/lang = href_list["lang"]
	var/text = href_list["text"]
	if (!isnum(id) || id < 1 || id > 1000000000 || round(id) != id)
		return
	if (!istext(lang) || !chat_translate_languages[lang] || !istext(text))
		return
	// From here every request is answered, with an empty translation when
	// there is none, so the page moves on to its next line at once.
	text = clean_text(text)
	if (!text || !enabled() || !allow(C) || world.time < paused_until)
		deliver_one(C, id, lang, "")
		return
	var/key = "[lang]\n[text]"
	var/list/hit = cache[key]
	if (hit)
		deliver_one(C, id, hit[1], hit[2])
		return
	if (lang == "en" && looks_english(text))
		remember(key, "en", "")
		deliver_one(C, id, "en", "")
		return
	if (waiting[key])
		var/list/W = waiting[key]
		W += list(list(C, id))
		return
	if (queue.len >= CHAT_TRANSLATE_QUEUE_LIMIT)
		// Under a burst, drop the oldest waiting text rather than fall behind.
		var/oldest = queue[1]
		queue.Cut(1, 2)
		answer_all(waiting[oldest], "", "")
		waiting -= oldest
		dropped++
	queue += key
	waiting[key] = list(list(C, id))
	if (!running)
		running = TRUE
		drain()

// Rate limit per client so one window cannot flood the translator.
/datum/chat_translator/proc/allow(C)
	if (world.time >= rate_window + 600)
		rate_window = world.time
		rate.Cut()
	var/ref = "\ref[C]"
	if (rate[ref] >= CHAT_TRANSLATE_CLIENT_PER_MINUTE)
		return FALSE
	rate[ref] = rate[ref] + 1
	return TRUE

/datum/chat_translator/proc/clean_text(text)
	text = copytext_char(text, 1, CHAT_TRANSLATE_MAX_CHARS + 1)
	for (var/control in list("\n", ascii2text(13), "\t"))
		text = replacetext(text, control, " ")
	text = trim(text)
	// Something to translate: a Latin letter or any non-ASCII character.
	if (!length(text) || (!findtext(text, regex(@"[A-Za-z]")) && length(text) == length_char(text)))
		return null
	return text

/datum/chat_translator/proc/looks_english(text)
	if (length(text) != length_char(text)) // accented or non-Latin letters
		return FALSE
	var/regex/word = regex(@"[A-Za-z']+", "g")
	var/total = 0
	var/common = 0
	var/position = 1
	while (word.Find(text, position))
		position = word.next
		total++
		if (lowertext(replacetext(word.match, "'", "")) in chat_translate_english_words)
			common++
	return total > 0 && common * 4 >= total

/datum/chat_translator/proc/remember(key, source, translation)
	if (cache.len >= CHAT_TRANSLATE_CACHE_LIMIT)
		cache.Cut(1, CHAT_TRANSLATE_CACHE_LIMIT / 5 + 1)
	cache[key] = list(source, translation)

/datum/chat_translator/proc/deliver_one(client/C, id, source, translation)
	if (!istype(C, /client))
		return
	C << output(list2params(list("[id]", source, translation)), "browser_chat:receiveTranslation")

/datum/chat_translator/proc/answer_all(list/W, source, translation)
	for (var/list/entry in W)
		deliver_one(entry[1], entry[2], source, translation)

/datum/chat_translator/proc/drain()
	set waitfor = FALSE
	while (queue.len && enabled() && world.time >= paused_until)
		var/key = queue[1]
		queue.Cut(1, 2)
		var/list/result = ask_translator(key)
		var/list/W = waiting[key]
		waiting -= key
		if (!result)
			answer_all(W, "", "")
			failures++
			if (failures >= CHAT_TRANSLATE_FAILURE_LIMIT)
				paused_until = world.time + CHAT_TRANSLATE_PAUSE
				failures = 0
				log_game("Chat translation: the translator did not answer [CHAT_TRANSLATE_FAILURE_LIMIT] times in a row; paused for five minutes.")
			continue
		failures = 0
		// A cold Edge language pack can return a successful but empty reply.
		// Only cache empties confirmed to already be in the target language.
		if (result[2] || findtext(key, "[result[1]]\n") == 1)
			remember(key, result[1], result[2])
		if (result[2])
			translated++
		answer_all(W, result[1], result[2])
	// Paused or switched off: answer everything still waiting.
	for (var/left in queue)
		answer_all(waiting[left], "", "")
	queue.Cut()
	waiting.Cut()
	running = FALSE

// The translator service's body for one line.
/datum/chat_translator/proc/request_body(lang, text)
	return json_encode(list("text" = text, "target" = lang))

// list(source, translation) from the service, translation "" when the line is
// already in the reader's language; null when the service did not answer.
/datum/chat_translator/proc/ask_translator(key)
	var/split = findtext(key, "\n")
	var/lang = copytext(key, 1, split)
	var/text = copytext(key, split + 1)
	var/url = config.chat_translate_url
	if (copytext(url, -1) == "/")
		url = copytext(url, 1, -1)
	var/datum/http_request/R = new
	R.prepare(RUSTG_HTTP_METHOD_POST, "[url]/translate", request_body(lang, text), list("Content-Type" = "application/json"))
	try
		R.begin_async()
	catch
		no_rust_g = TRUE
		log_game("Chat translation: rust_g is unavailable, so the server cannot translate chat.")
		return null
	for (var/i in 1 to CHAT_TRANSLATE_REQUEST_TICKS)
		if (R.is_complete())
			break
		sleep(1)
	if (!R.is_complete())
		return null
	var/datum/http_response/response = R.into_response()
	if (response.error || response.status_code != 200)
		return null
	return parse_reply(response.body, lang, text)

/datum/chat_translator/proc/parse_reply(body, lang, text)
	if (!istext(body))
		return null
	var/list/answer
	try
		answer = json_decode(body)
	catch
		return null
	if (!islist(answer))
		return null
	var/source = lowertext(copytext("[answer["source"]]", 1, 3))
	var/translation = trim(copytext_char("[answer["translation"]]", 1, CHAT_TRANSLATE_MAX_CHARS * 2))
	if (!findtext(source, regex(@"^[a-z]{2}$")))
		source = "und"
	if (source == lang || !length(translation) || translation == text)
		translation = ""
	return list(source, translation)

// One line for the Debug Controller.
/datum/chat_translator/proc/summary()
	return "[enabled() ? "on" : "off"], queued [queue.len], cached [cache.len], translated [translated], dropped [dropped][world.time < paused_until ? ", paused" : ""]"

#undef CHAT_TRANSLATE_MAX_CHARS
#undef CHAT_TRANSLATE_QUEUE_LIMIT
#undef CHAT_TRANSLATE_CACHE_LIMIT
#undef CHAT_TRANSLATE_CLIENT_PER_MINUTE
#undef CHAT_TRANSLATE_REQUEST_TICKS
#undef CHAT_TRANSLATE_FAILURE_LIMIT
#undef CHAT_TRANSLATE_PAUSE
