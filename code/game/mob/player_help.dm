// Only local bounded files are read here. The optional bridge owns HTTP/model work.
var/global/datum/player_help_service/player_help_service = new

/client
	// Session-only state. Never attached to a mob or passed to native persistence.
	var/tmp/list/player_help_turns = list()
	var/tmp/mob/player_help_body
	var/tmp/list/player_help_injuries = list()
	var/tmp/player_help_generation = 0
	var/tmp/player_help_touched = 0
	var/tmp/player_help_action_token
	var/tmp/player_help_acknowledged = FALSE

/client/verb/ask_player_help()
	set name = "Ask for help"
	set category = "Help!"
	player_help_service.expire_conversations()
	player_help_service.bind_body(src, mob)
	var/generation = player_help_generation
	var/question = player_help_prompt()
	player_help_service.bind_body(src, mob)
	if (question && (src in clients) && generation == player_help_generation)
		player_help_service.submit(src, question)

/client/proc/player_help_prompt()
	return input(src, "Ask a gameplay question. Your question and gameplay condition (health, recent observed injuries, inventory, exposure and public server state) are sent to the server owner's AI service. Do not enter personal information.", "Ask for help") as text|null

/datum/player_help_service
	var/root = "SQL/player-help/"
	var/list/pending = list()
	var/sequence
	var/heartbeat_confirmed = FALSE
	var/heartbeat_time = -1000
	var/serial = 0
	var/request_timeout_seconds = 60
	var/account_salt
	var/list/accounts = list()
	var/list/global_times = list()
	var/conversation_supported = FALSE
	var/list/conversation_clients = list()
	var/list/limits = list("cooldown_seconds"=30, "burst_requests"=3, "burst_seconds"=120, "window_requests"=10, "window_seconds"=600, "global_requests"=30, "global_seconds"=60, "max_accounts"=2048, "queue_slots"=8)

/datum/player_help_service/persistence_runtime_var(key)
	return (key in list("pending", "accounts", "global_times", "conversation_clients", "account_salt", "sequence", "serial", "heartbeat_confirmed", "heartbeat_time", "conversation_supported")) || ..()

/datum/player_help_service/proc/reset_conversation(client/C)
	C.player_help_turns = list()
	C.player_help_injuries = list()
	C.player_help_generation++
	C.player_help_action_token = null
	C.player_help_acknowledged = FALSE
	conversation_clients -= C
	// A pending account reservation survives reset until response/timeout.

// Login calls this even when a client briefly visits another body and returns.
/datum/player_help_service/proc/bind_body(client/C, mob/body)
	if (!C || C.player_help_body == body)
		return
	reset_conversation(C)
	C.player_help_body = body

/datum/player_help_service/proc/expire_conversations()
	// At most 128 retained client sessions. Release disconnected client refs.
	for (var/client/C in conversation_clients.Copy())
		if (!(C in clients) || limit_time() - C.player_help_touched >= 9000)
			reset_conversation(C)
		else
			bind_body(C, C.mob)

/datum/player_help_service/proc/remember(client/C, question, answer)
	if (!(C in conversation_clients) && conversation_clients.len >= 128)
		reset_conversation(conversation_clients[1])
	// Trim on Unicode boundaries; length() is the native UTF-8 byte count.
	if (length(answer) > 3000)
		var/end = 1
		while (end <= length(answer))
			var/bytes = length(ascii2text(text2ascii(answer, end)))
			if (end + bytes - 1 > 3000)
				break
			end += bytes
		answer = copytext(answer, 1, end)
	C.player_help_turns += list(list("question" = question, "answer" = answer))
	var/size = 0
	for (var/list/pair in C.player_help_turns)
		size += length(pair["question"]) + length(pair["answer"])
	while (C.player_help_turns.len > 3 || size > 4096)
		var/list/oldest = C.player_help_turns[1]
		size -= length(oldest["question"]) + length(oldest["answer"])
		C.player_help_turns.Cut(1, 2)
	C.player_help_touched = limit_time()
	C.player_help_acknowledged = TRUE
	C.player_help_action_token = md5("[world.realtime]-[rand(1, 1000000000)]-[++serial]")
	conversation_clients |= C

/datum/player_help_service/proc/request_size(list/request)
	// Bound the ASCII JSON representation even when native JSON emits UTF-8.
	var/encoded = json_encode(request)
	var/size = 0
	var/i = 1
	while (i <= length(encoded))
		var/codepoint = text2ascii(encoded, i)
		size += codepoint > 65535 ? 12 : (codepoint > 127 ? 6 : 1)
		i += length(ascii2text(codepoint))
	return size

/datum/player_help_service/Topic(href, list/href_list)
	// The global service ref is public. The actor always comes from usr.client;
	// a copied URL cannot select another account, client or conversation.
	var/client/C = usr ? usr.client : null
	expire_conversations()
	if (!valid_action(C, href_list["token"]))
		return
	if (href_list["action"] == "reset")
		reset_conversation(C)
		C << browse(null, "window=player_help")
		C << "AI gameplay help conversation cleared. Ask for help to start a new conversation."
	else if (href_list["action"] == "followup")
		if (!available() || !conversation_supported || !C.player_help_acknowledged || !C.player_help_turns.len)
			C << "Follow-up context is unavailable. Start a new conversation or try again later."
			return
		C.ask_player_help()

/datum/player_help_service/proc/valid_action(client/C, token)
	if (C && (C in clients))
		bind_body(C, C.mob)
	return C && (C in clients) && C.player_help_action_token && token == C.player_help_action_token

// Account identity comes only from the authenticated client, never player input.
// A per-server salt keeps account names out of the bridge and model payload.
/datum/player_help_service/proc/account_key(client/C)
	if (!C || !C.ckey || IsGuestKey(C.ckey))
		return null
	if (!account_salt)
		account_salt = "[world.realtime]-[rand(1, 1000000000)]"
	return md5("[account_salt]:[C.ckey]")

/datum/player_help_service/proc/refresh_limits()
	var/list/settings = read_json("[root]limits.json", 1024)
	if (!islist(settings))
		return
	for (var/key in limits)
		var/value = settings[key]
		var/ceiling = findtext(key, "seconds") ? 86400 : 4096
		if (key == "queue_slots")
			ceiling = 8
		if (isnum(value) && value == round(value) && value >= 1 && value <= ceiling)
			limits[key] = value

// No sleeps or external calls between admission and reservation.
// Return a slot number or private rejection text. Reconnects share account state.
/datum/player_help_service/proc/reserve(account)
	if (!istext(account) || length(account) != 32)
		return "Please sign in to a BYOND account to ask for AI gameplay help."
	var/now = limit_time()
	var/retention = max(limits["cooldown_seconds"], limits["burst_seconds"], limits["window_seconds"]) * 10
	for (var/key in accounts.Copy())
		var/list/times = accounts[key]
		while (times.len && now - times[1] >= retention)
			times.Cut(1, 2)
		if (!times.len)
			accounts -= key
	while (global_times.len && now - global_times[1] >= limits["global_seconds"] * 10)
		global_times.Cut(1, 2)
	var/slot = 0
	for (var/i = 1, i <= 8, i++)
		var/list/entry = pending["[i]"]
		if (entry && entry["account"] == account)
			return "Your previous question is still pending."
		if (!entry && !slot && i <= limits["queue_slots"])
			slot = i
	var/list/history = accounts[account]
	if (history)
		var/retry = 0
		var/list/caps = list(1, limits["burst_requests"], limits["window_requests"])
		var/list/spans = list(limits["cooldown_seconds"], limits["burst_seconds"], limits["window_seconds"])
		for (var/index = 1, index <= 3, index++)
			var/count = 0
			var/first = 0
			for (var/timestamp in history)
				if (now - timestamp < spans[index] * 10)
					if (!count)
						first = timestamp
					count++
			if (count >= caps[index])
				retry = max(retry, spans[index] * 10 - (now - first))
		if (retry)
			return "Please wait [round(retry / 10) + 1] seconds before asking another gameplay question."
	if (!slot || global_times.len >= limits["global_requests"] || (!history && accounts.len >= limits["max_accounts"]))
		return "AI gameplay help is busy. Please wait at least 5 seconds before trying again."
	if (!history)
		history = list()
		accounts[account] = history
	history += now
	global_times += now
	pending["[slot]"] = list("account"=account, "deadline"=now + request_timeout_seconds * 10)
	return slot

/datum/player_help_service/proc/limit_time()
	return world.time

/datum/player_help_service/proc/read_json(path, limit)
	var/raw = file2text(path)
	if (!istext(raw) || length(raw) > limit)
		return null
	try
		return json_decode(raw)
	catch
		return null

/datum/player_help_service/proc/available()
	refresh_limits()
	conversation_supported = FALSE
	var/list/health = read_json("[root]health.json", 256)
	if (!islist(health) || health["enabled"] != TRUE || !istext(health["sequence"]))
		return FALSE
	conversation_supported = health["conversation_protocol"] == 1
	if (isnum(health["request_timeout_seconds"]))
		request_timeout_seconds = max(60, min(600, health["request_timeout_seconds"]))
	if (sequence != health["sequence"])
		if (sequence)
			heartbeat_confirmed = TRUE
		sequence = health["sequence"]
		heartbeat_time = world.time
	return heartbeat_confirmed && world.time - heartbeat_time < 100

/datum/player_help_service/proc/clear_slot(slot)
	fdel("[root][slot].ready")
	fdel("[root][slot].request.json")
	fdel("[root][slot].response.json")
	pending -= "[slot]"

/datum/player_help_service/proc/matching_response(slot, id)
	var/list/response = read_json("[root][slot].response.json", 24000)
	if (islist(response) && response["id"] == id)
		return response
	return null

// Traverse only carried equipment and storage, never implants or other mobs.
// At most 24 items, 64 inspected entries and two container levels per question.
/datum/player_help_service/proc/inventory_context(mob/living/human/H)
	var/list/slots = list("left hand" = H.l_hand, "right hand" = H.r_hand, "back" = H.back, "mask" = H.wear_mask, "suit" = H.wear_suit, "uniform" = H.w_uniform, "shoes" = H.shoes, "belt" = H.belt, "gloves" = H.gloves, "head" = H.head, "left ear" = H.l_ear, "right ear" = H.r_ear, "ID slot" = H.wear_id, "left pocket" = H.l_store, "right pocket" = H.r_store)
	var/list/queue = list()
	for (var/slot in slots)
		var/obj/item/I = slots[slot]
		if (I && I.loc == H)
			queue += list(list("item" = I, "place" = slot, "depth" = 0))
	var/list/items = list()
	var/list/seen = list()
	var/inspected = 0
	var/children_inspected = 0
	var/truncated = FALSE
	for (var/index = 1, index <= queue.len, index++)
		if (items.len >= 24 || inspected + children_inspected >= 64)
			truncated = TRUE
			break
		var/list/entry = queue[index]
		var/obj/item/I = entry["item"]
		inspected++
		if (!I || (I in seen))
			continue
		seen += I
		var/quantity = 1
		if (istype(I, /obj/item/stack))
			var/obj/item/stack/S = I
			quantity = max(0, min(100000, S.amount))
		items += list(list("name" = copytext(html_decode("[I.name]"), 1, 81), "quantity" = quantity, "place" = copytext(entry["place"], 1, 81)))
		if (istype(I, /obj/item/weapon/storage))
			if (entry["depth"] >= 2)
				if (I.contents.len)
					truncated = TRUE
			else
				for (var/atom/child in I.contents)
					if (queue.len >= 64 || inspected + children_inspected >= 64)
						truncated = TRUE
						break
					children_inspected++
					if (istype(child, /obj/item))
						queue += list(list("item" = child, "place" = copytext(html_decode("[I.name]"), 1, 81), "depth" = entry["depth"] + 1))
	return list("items" = items, "truncated" = truncated)

// Fixed server-controlled categories only; reported categories are invoked at
// the corresponding direct victim message, never at a generic damage hook.
/datum/player_help_service/proc/record_observed_injury(client/C, mob/living/human/H, kind)
	if (!C || !(C in clients) || !H || C.mob != H || H.client != C || H.stat != CONSCIOUS || H.sleeping > 0)
		return
	if (!(kind in list("self_weapon_hit", "reported_projectile_hit", "reported_shrapnel_hit", "reported_hot_ground", "reported_freezing_feet")))
		return
	// Queued chat can be dropped before it becomes visible; do not record it.
	if (kind != "self_weapon_hit" && (!C.chat || !C.chat.is_ready || C.chat.client != C))
		return
	bind_body(C, H)
	if (!(C in conversation_clients))
		if (conversation_clients.len >= 128)
			reset_conversation(conversation_clients[1])
		// Track an injury-only session, without extending an existing conversation.
		C.player_help_touched = limit_time()
		conversation_clients |= C
	C.player_help_injuries += list(list("kind" = kind, "time" = limit_time()))
	while (C.player_help_injuries.len > 6)
		C.player_help_injuries.Cut(1, 2)

/datum/player_help_service/proc/injury_context(client/C, mob/living/human/H)
	var/list/results = list()
	if (!C || !(C in clients) || !H || C.mob != H || H.client != C || C.player_help_body != H)
		return results
	var/now = limit_time()
	for (var/list/event in C.player_help_injuries)
		if (!(event["kind"] in list("self_weapon_hit", "reported_projectile_hit", "reported_shrapnel_hit", "reported_hot_ground", "reported_freezing_feet")) || !isnum(event["time"]) || event["time"] > now || now - event["time"] >= 6000)
			continue
		results += list(list("kind" = event["kind"], "certainty" = "observed", "age_seconds" = round((now - event["time"]) / 10)))
	return results

// Read public map metadata directly; never accept player text as server state.
/datum/player_help_service/proc/game_context(mob/asking_player)
	var/list/context = list("map" = "Unknown", "gamemode" = "Unknown")
	if (map)
		context = list("map" = copytext("[map.title]", 1, 121), "map_id" = copytext("[map.ID]", 1, 121), "gamemode" = copytext("[map.gamemode]", 1, 121), "era" = copytext("[map.age]", 1, 121), "era_ordinal" = map.ordinal_age, "civilizations" = map.civilizations ? TRUE : FALSE)
	context["season"] = copytext("[global.season]", 1, 121)
	context["time_of_day"] = copytext("[time_of_day]", 1, 121)
	if (istype(asking_player, /mob/living/human))
		var/mob/living/human/H = asking_player
		var/list/condition = list("health_percent" = round(100 * H.health / max(1, H.maxHealth)), "nutrition_percent" = round(100 * H.nutrition / max(1, H.max_nutrition)), "hydration_percent" = round(100 * H.water / max(1, H.max_water)), "body_temperature_kelvin" = round(H.bodytemperature), "wetness_percent" = round(100 * H.cold_wetness))
		var/list/events = list()
		if (H.on_fire)
			events += "On fire"
		if (H.stunned || H.weakened)
			events += "Incapacitated"
		var/area/A = get_area(H)
		if (A)
			condition["outdoors"] = A.location == AREA_OUTSIDE ? TRUE : FALSE
			condition["local_weather"] = A.weather == WEATHER_WET ? "Wet weather" : (A.weather == WEATHER_EXTREME ? "Extreme weather" : (A.weather == WEATHER_SMOG ? "Smog" : "No weather"))
			if (A.location == AREA_OUTSIDE && A.weather != WEATHER_NONE)
				events += "Exposed to local weather"
		condition["active_effects"] = events
		condition["inventory"] = inventory_context(H)
		condition["recent_injuries"] = injury_context(H.client, H)
		context["player"] = condition
	return context

/datum/player_help_service/proc/submit(client/C, question)
	if (!C || !istext(question) || !length(question))
		return FALSE
	var/result = enqueue(account_key(C), question, C)
	if (istext(result))
		C << result
		return FALSE
	C << "Asking the AI gameplay helper. Answers can be mistaken; check the Crafting Atlas and player wiki."
	return TRUE

// Server-owned queue boundary; no client/Topic-supplied account identifiers.
/datum/player_help_service/proc/enqueue(account, question, client/C)
	expire_conversations()
	if (C)
		bind_body(C, C.mob)
	if (!available())
		return "AI gameplay help is unavailable. Please use the Crafting Atlas or try again later."
	if (!istext(question) || !length(question) || length(question) > 500)
		return "Please keep your question to 1 through 500 characters."
	if (C && C.player_help_turns.len && !conversation_supported)
		return "This helper cannot carry follow-up context. Use New conversation to ask a standalone question."
	var/slot = reserve(account)
	if (!isnum(slot))
		return slot
	serial++
	var/id = "[world.realtime]-[rand(1, 999999)]-[serial]"
	var/list/request = list("id" = id, "account" = account, "question" = question, "game_context" = game_context(C ? C.mob : null))
	request["render_contract"] = list("version" = 1, "capabilities" = list("markdown-basic-v1"))
	if (C && conversation_supported)
		request["conversation"] = list("version" = 1, "turns" = C.player_help_turns.Copy())
	// Includes escaping, IDs, context and metadata, not just dialogue bytes.
	// Retain complete newest pairs when the existing spool envelope is tight.
	while (request_size(request) > 16384 && request["conversation"])
		var/list/conversation = request["conversation"]
		var/list/turns = conversation["turns"]
		if (!turns.len)
			break
		turns.Cut(1, 2)
	if (request_size(request) > 16384)
		clear_slot(slot)
		return "AI gameplay help could not fit this question and context. Please try a shorter question."
	fdel("[root][slot].ready")
	fdel("[root][slot].request.json")
	fdel("[root][slot].response.json")
	if (!write_request(slot, request))
		clear_slot(slot)
		return "AI gameplay help could not send your question. Please try again later."
	var/list/sent_conversation = request["conversation"]
	var/list/sent_turns = sent_conversation ? sent_conversation["turns"] : null
	pending["[slot]"] = list("id" = id, "account" = account, "client" = C, "generation" = C ? C.player_help_generation : null, "body" = C ? C.mob : null, "question" = question, "conversation" = !!sent_conversation, "had_history" = sent_turns && sent_turns.len, "deadline" = world.time + request_timeout_seconds * 10)
	return TRUE

/datum/player_help_service/proc/write_request(slot, list/request)
	return text2file(json_encode(request), "[root][slot].request.json") && text2file(request["id"], "[root][slot].ready")

/datum/player_help_service/proc/poll()
	available()
	expire_conversations()
	for (var/i = 1, i <= 8, i++)
		var/list/entry = pending["[i]"]
		if (!islist(entry))
			continue
		var/client/C = entry["client"]
		// Disconnect does not cancel work or release the account's pending lock.
		if (C && (C in clients))
			bind_body(C, C.mob)
		if (C && (!(C in clients) || C.player_help_generation != entry["generation"] || C.mob != entry["body"]))
			C = null
		var/list/response = matching_response(i, entry["id"])
		if (islist(response))
			var/answer_format = response_format(response)
			if (C && response["status"] == "ok" && entry["had_history"] && response["conversation_protocol"] != 1)
				C << "The helper did not accept follow-up context. Your conversation was cleared; please start a new conversation."
				reset_conversation(C)
			else if (C && answer_format && response["status"] == "ok" && istext(response["answer"]) && length(response["answer"]) && length(response["answer"]) <= 4000)
				// Snapshot only this session's completed questions before appending the current pair.
				var/list/previous_questions = list()
				for (var/list/pair in C.player_help_turns)
					previous_questions += pair["question"]
				if (entry["conversation"] && response["conversation_protocol"] == 1)
					remember(C, entry["question"], response["answer"])
				else
					reset_conversation(C)
					C.player_help_action_token = md5("[entry["id"]]-[rand(1, 1000000000)]")
				C << browse(render_answer(response["answer"], answer_format, C, entry["question"], previous_questions), "window=player_help;size=600x500")
			else if (C && response["status"] == "rate_limited")
				C << "AI gameplay help rate limit reached. Please wait [max(1, min(86400, text2num("[response["retry_seconds"]]")))] seconds and try again."
			else if (C && (response["status"] == "busy" || response["status"] == "pending"))
				C << "AI gameplay help is busy or your previous question is pending. Please wait [max(1, min(86400, text2num("[response["retry_seconds"]]")))] seconds before trying again."
			else if (C)
				C << "AI gameplay help did not receive a usable response. Please try again later or use the Crafting Atlas."
			clear_slot(i)
		else if (world.time >= entry["deadline"])
			if (C)
				C << "AI gameplay help timed out without a response. Please try again later or use the Crafting Atlas."
			clear_slot(i)

/datum/player_help_service/proc/response_format(list/response)
	// Missing both keys is the old worker protocol. Partial/null metadata fails closed.
	if (!("render_protocol" in response) && !("answer_format" in response))
		return "markdown-basic-v1"
	if (response["render_protocol"] != 1)
		return null
	if (response["answer_format"] == "plain-v1" || response["answer_format"] == "markdown-basic-v1")
		return response["answer_format"]
	return null

/datum/player_help_service/proc/render_answer(answer, answer_format = "markdown-basic-v1", client/C = null, question = null, list/previous_questions = null)
	if (!istext(answer) || length(answer) > 4000)
		answer = "AI gameplay help did not receive a usable response."
	var/body
	if (answer_format == "plain-v1")
		body = "<pre style='white-space:pre-wrap'>[html_encode(answer)]</pre>"
	else if (answer_format == "markdown-basic-v1")
		body = markdown_answer(answer)
	else
		return null
	var/current_question = ""
	if (istext(question) && length(question) <= 500)
		current_question = "<p><b>Question:</b> [html_encode(question)]</p>"
	var/history = ""
	if (islist(previous_questions) && previous_questions.len)
		history = "<h3>Previous questions</h3>"
		for (var/previous_question in previous_questions)
			if (istext(previous_question) && length(previous_question) <= 500)
				history += "<p>[html_encode(previous_question)]</p>"
	if (C && C.player_help_action_token)
		var/actions = "<a href='?src=\ref[src];action=reset;token=[C.player_help_action_token]'>New conversation</a>"
		if (C.player_help_acknowledged && C.player_help_turns.len)
			actions = "<a href='?src=\ref[src];action=followup;token=[C.player_help_action_token]'>Follow up</a> | [actions]"
		body += "<p>[actions]</p>"
	return "<html><body><h2>AI gameplay help</h2><p>AI answers can be mistaken. Verify recipes in the Crafting Atlas.</p>[current_question][body]<p><a href='https://civ13.github.io/civ13-wiki/'>Player wiki</a> | <a href='https://civ13.github.io/Civ13/crafting/'>Crafting Atlas</a></p>[history]</body></html>"

// Bounded display subset of CommonMark 0.31.2, not an HTML trust boundary
// delegated to the model. Only these routines generate answer markup.
/datum/player_help_service/proc/markdown_text(value)
	return html_encode(value)

/datum/player_help_service/proc/markdown_blank(value)
	for (var/i = 1, i <= length(value), i++)
		var/c = text2ascii(value, i)
		if (c != 9 && c != 32)
			return FALSE
	return TRUE

/datum/player_help_service/proc/markdown_url(value)
	// Do not decode entities/percent escapes into a different scheme. Reject
	// controls, whitespace, quotes and backslashes before producing an attribute.
	if (!istext(value) || !(findtext(value, "https://") == 1 || findtext(value, "http://") == 1))
		return FALSE
	var/start = findtext(value, "://") + 3
	if (start > length(value))
		return FALSE
	for (var/i = 1, i <= length(value), i++)
		var/c = text2ascii(value, i)
		if (c <= 32 || c == 127 || c == 34 || c == 39 || c == 60 || c == 62 || c == 92)
			return FALSE
	return TRUE

/datum/player_help_service/proc/markdown_inline(value, depth = 0, links = TRUE)
	if (depth >= 8)
		return markdown_text(value)
	var/result = ""
	var/plain = ""
	var/n = length(value)
	for (var/i = 1, i <= n, i++)
		var/c = text2ascii(value, i)
		// Backslash escapes ASCII punctuation; never turn escaped text into tags.
		if (c == 92 && i < n)
			var/next = text2ascii(value, i + 1)
			if ((next >= 33 && next <= 47) || (next >= 58 && next <= 64) || (next >= 91 && next <= 96) || (next >= 123 && next <= 126))
				plain += copytext(value, i + 1, i + 2)
				i++
				continue
		if (c == 96)
			var/run = 1
			while (i + run <= n && text2ascii(value, i + run) == 96)
				run++
			var/end = i + run
			while (end <= n)
				if (text2ascii(value, end) != 96)
					end++
					continue
				var/closing = 1
				while (end + closing <= n && text2ascii(value, end + closing) == 96)
					closing++
				if (closing == run)
					break
				end += closing
			if (end <= n)
				var/code = replacetext(copytext(value, i + run, end), "\n", " ")
				if (length(code) >= 2 && copytext(code, 1, 2) == " " && copytext(code, length(code)) == " " && !markdown_blank(code))
					code = copytext(code, 2, length(code))
				result += "[markdown_text(plain)]<code>[markdown_text(code)]</code>"
				plain = ""
				i = end + run - 1
				continue
			plain += copytext(value, i, i + run)
			i += run - 1
			continue
		// Balanced inline links. Images are kept as text, with no remote fetch.
		if (c == 91 && links && !(i > 1 && text2ascii(value, i - 1) == 33))
			var/end = i + 1
			var/brackets = 1
			while (end <= n && brackets)
				var/b = text2ascii(value, end)
				if (b == 92)
					end += 2
					continue
				if (b == 91)
					brackets++
				if (b == 93)
					brackets--
				end++
			if (!brackets && end <= n && text2ascii(value, end) == 40)
				var/close = end + 1
				var/parens = 1
				while (close <= n && parens)
					var/b = text2ascii(value, close)
					if (b == 40)
						parens++
					if (b == 41)
						parens--
					close++
				if (!parens)
					var/url = copytext(value, end + 1, close - 1)
					if (markdown_url(url))
						result += "[markdown_text(plain)]<a href=\"[html_encode(url)]\">[markdown_inline(copytext(value, i + 1, end - 1), depth + 1, FALSE)]</a>"
						plain = ""
						i = close - 1
						continue
		if (c == 42 || c == 95)
			// Underscores inside names such as crude_twine remain literal.
			var/previous = i > 1 ? text2ascii(value, i - 1) : 32
			var/run = 1
			while (i + run <= n && text2ascii(value, i + run) == c)
				run++
			if (run <= 3 && i + run <= n && text2ascii(value, i + run) > 32 && (c != 95 || previous <= 32 || previous == 40))
				var/mark = copytext(value, i, i + run)
				var/end = findtext(value, mark, i + run)
				while (end && (text2ascii(value, end - 1) <= 32 || text2ascii(value, end - 1) == 92))
					end = findtext(value, mark, end + run)
				if (end > i + run)
					var/open = run == 1 ? "<i>" : (run == 2 ? "<b>" : "<b><i>")
					var/shut = run == 1 ? "</i>" : (run == 2 ? "</b>" : "</i></b>")
					result += "[markdown_text(plain)][open][markdown_inline(copytext(value, i + run, end), depth + 1, links)][shut]"
					plain = ""
					i = end + run - 1
					continue
		plain += copytext(value, i, i + 1)
	return result + markdown_text(plain)

/datum/player_help_service/proc/markdown_answer(answer)
	if (!istext(answer) || length(answer) > 4000)
		return "<p>AI gameplay help did not receive a usable response.</p>"
	var/carriage_return = ascii2text(13)
	answer = replacetext(replacetext(answer, "[carriage_return]\n", "\n"), carriage_return, "\n")
	var/list/lines = splittext(answer, "\n")
	var/result = ""
	var/paragraph = FALSE
	var/fence = ""
	var/fence_length = 0
	var/code = ""
	var/regex/fences = regex("^ {0,3}(`{3,}|~{3,})(.*)$")
	var/regex/headings = regex("^ {0,3}(#{1,6})( +|$)(.*)$")
	var/regex/bullets = regex("^( *)(- |\\* |\\+ )(.+)$")
	var/regex/numbers = regex("^( *)(\[0-9]{1,9})(\\.|\\)) +(.+)$")
	var/line_number = 0
	for (var/line in lines)
		line_number++
		var/has_fence = fences.Find(line)
		if (length(fence))
			if (has_fence && copytext(fences.group[1], 1, 2) == fence && length(fences.group[1]) >= fence_length && markdown_blank(fences.group[2]))
				result += "<pre>[markdown_text(code)]</pre>"
				fence = ""
				code = ""
			else
				code += "[line]\n"
			continue
		if (has_fence && !(copytext(fences.group[1], 1, 2) == "`" && findtext(fences.group[2], "`")))
			if (paragraph)
				result += "</p>"
				paragraph = FALSE
			fence = copytext(fences.group[1], 1, 2)
			fence_length = length(fences.group[1])
			continue
		if (markdown_blank(line))
			if (paragraph)
				result += "</p>"
				paragraph = FALSE
			continue
		if (headings.Find(line))
			if (paragraph)
				result += "</p>"
				paragraph = FALSE
			var/level = length(headings.group[1])
			result += "<h[level]>[markdown_inline(headings.group[3])]</h[level]>"
			continue
		var/prefix = ""
		var/content = line
		if (bullets.Find(line))
			prefix = "[replacetext(bullets.group[1], " ", "&nbsp;")]&bull; "
			content = bullets.group[3]
		else if (numbers.Find(line))
			prefix = "[replacetext(numbers.group[1], " ", "&nbsp;")][numbers.group[2]]. "
			content = numbers.group[4]
		if (length(prefix))
			if (paragraph)
				result += "</p>"
			paragraph = FALSE
			result += "<p>[prefix][markdown_inline(content)]</p>"
			continue
		if (!paragraph)
			result += "<p>"
			paragraph = TRUE
		else
			result += "<br>"
		// Keep explicit line breaks readable, including CommonMark hard breaks.
		if (line_number < lines.len)
			var/slashes = 0
			for (var/i = length(content), i >= 1 && text2ascii(content, i) == 92, i--)
				slashes++
			if (slashes % 2)
				content = copytext(content, 1, length(content))
		result += markdown_inline(content)
	if (paragraph)
		result += "</p>"
	if (length(fence))
		result += "<pre>[markdown_text(code)]</pre>"
	return result

/process/player_help/setup()
	processes.player_help = src
	name = "Player help"
	schedule_interval = 2 SECONDS
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_LOW

/process/player_help/fire()
	player_help_service.poll()
