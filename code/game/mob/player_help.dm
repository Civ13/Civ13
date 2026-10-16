// Only local bounded files are read here. The optional bridge owns HTTP/model work.
var/global/datum/player_help_service/player_help_service = new

/client/verb/ask_player_help()
	set name = "Ask for help"
	set category = "Help!"
	var/question = player_help_prompt()
	if (question && (src in clients))
		player_help_service.submit(src, question)

/client/proc/player_help_prompt()
	return input(src, "Ask a gameplay question. Your question and gameplay condition (health, inventory, exposure and public server state) are sent to the server owner's AI service. Do not enter personal information.", "Ask for help") as text|null

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
	var/list/limits = list("cooldown_seconds"=30, "burst_requests"=3, "burst_seconds"=120, "window_requests"=10, "window_seconds"=600, "global_requests"=30, "global_seconds"=60, "max_accounts"=2048, "queue_slots"=8)

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
	var/list/health = read_json("[root]health.json", 256)
	if (!islist(health) || health["enabled"] != TRUE || !istext(health["sequence"]))
		return FALSE
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
	if (!available())
		return "AI gameplay help is unavailable. Please use the Crafting Atlas or try again later."
	if (!istext(question) || !length(question) || length(question) > 500)
		return "Please keep your question to 1 through 500 characters."
	var/slot = reserve(account)
	if (!isnum(slot))
		return slot
	serial++
	var/id = "[world.realtime]-[rand(1, 999999)]-[serial]"
	var/list/request = list("id" = id, "account" = account, "question" = question, "game_context" = game_context(C ? C.mob : null))
	fdel("[root][slot].ready")
	fdel("[root][slot].request.json")
	fdel("[root][slot].response.json")
	if (!write_request(slot, request))
		clear_slot(slot)
		return "AI gameplay help could not send your question. Please try again later."
	pending["[slot]"] = list("id" = id, "account" = account, "client" = C, "deadline" = world.time + request_timeout_seconds * 10)
	return TRUE

/datum/player_help_service/proc/write_request(slot, list/request)
	return text2file(json_encode(request), "[root][slot].request.json") && text2file(request["id"], "[root][slot].ready")

/datum/player_help_service/proc/poll()
	available()
	for (var/i = 1, i <= 8, i++)
		var/list/entry = pending["[i]"]
		if (!islist(entry))
			continue
		var/client/C = entry["client"]
		// Disconnect does not cancel work or release the account's pending lock.
		if (C && !(C in clients))
			C = null
		var/list/response = matching_response(i, entry["id"])
		if (islist(response))
			if (C && response["status"] == "ok" && istext(response["answer"]) && length(response["answer"]) <= 4000)
				C << browse(render_answer(response["answer"]), "window=player_help;size=600x500")
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

/datum/player_help_service/proc/render_answer(answer)
	return "<html><body><h2>AI gameplay help</h2><p>AI answers can be mistaken. Verify recipes in the Crafting Atlas.</p><pre style='white-space:pre-wrap'>[html_encode(answer)]</pre><p><a href='https://civ13.github.io/civ13-wiki/'>Player wiki</a> | <a href='https://civ13.github.io/Civ13/crafting/'>Crafting Atlas</a></p></body></html>"

/process/player_help/setup()
	processes.player_help = src
	name = "Player help"
	schedule_interval = 2 SECONDS
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_LOW

/process/player_help/fire()
	player_help_service.poll()
