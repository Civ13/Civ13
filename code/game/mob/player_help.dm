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
	// What the help window shows besides the remembered turns.
	var/tmp/player_help_pending // the question waiting for its answer
	var/tmp/player_help_notice // one refusal or failure, shown once
	var/tmp/player_help_draft // a refused question, put back in the box once
	var/tmp/list/player_help_plain = list() // remembered turns whose answer is plain text
	var/tmp/list/player_help_standalone // one exchange from a worker without follow-up context: shown, never sent

// The window is the whole interface: the conversation, the question box and
// every refusal. Nothing is asked through a separate dialog or answered in chat.
/client/verb/ask_player_help()
	set name = "Ask for help"
	set category = "Help!"
	tutorial_event("help")
	player_help_service.open_window(src)

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
	var/list/limits = list("cooldown_seconds"=10, "burst_requests"=5, "burst_seconds"=120, "window_requests"=10, "window_seconds"=600, "global_requests"=30, "global_seconds"=60, "max_accounts"=2048, "queue_slots"=8)

/datum/player_help_service/persistence_runtime_var(key)
	return (key in list("pending", "accounts", "global_times", "conversation_clients", "account_salt", "sequence", "serial", "heartbeat_confirmed", "heartbeat_time", "conversation_supported")) || ..()

/datum/player_help_service/proc/reset_conversation(client/C)
	C.player_help_turns = list()
	C.player_help_injuries = list()
	C.player_help_generation++
	C.player_help_action_token = null
	C.player_help_acknowledged = FALSE
	C.player_help_pending = null
	C.player_help_notice = null
	C.player_help_draft = null
	C.player_help_plain = list()
	C.player_help_standalone = null
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

/datum/player_help_service/proc/new_token()
	return md5("[world.realtime]-[rand(1, 1000000000)]-[++serial]")

/datum/player_help_service/proc/open_window(client/C)
	if (!C || !(C in clients))
		return
	expire_conversations()
	bind_body(C, C.mob)
	show_window(C)

// Every change to the conversation redraws the window from the server's state.
/datum/player_help_service/proc/show_window(client/C)
	if (!C || !(C in clients))
		return
	if (!C.player_help_action_token)
		C.player_help_action_token = new_token()
	show_browse(C, render_window(C), "window=player_help;size=600x640")
	C.player_help_notice = null
	C.player_help_draft = null

// A refusal or failure goes into the window, with the question back in the box.
/datum/player_help_service/proc/refuse(client/C, notice, question = null)
	if (!C || !(C in clients))
		return
	C.player_help_notice = notice
	C.player_help_draft = istext(question) ? question : null
	show_window(C)

/datum/player_help_service/proc/remember(client/C, question, answer, plain = FALSE)
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
	var/list/newest = list("question" = question, "answer" = answer)
	C.player_help_turns += list(newest)
	if (plain)
		C.player_help_plain += list(newest)
	C.player_help_standalone = null
	var/size = 0
	for (var/list/pair in C.player_help_turns)
		size += length(pair["question"]) + length(pair["answer"])
	while (C.player_help_turns.len > 3 || size > 4096)
		var/list/oldest = C.player_help_turns[1]
		size -= length(oldest["question"]) + length(oldest["answer"])
		C.player_help_plain -= list(oldest)
		C.player_help_turns.Cut(1, 2)
	C.player_help_touched = limit_time()
	C.player_help_acknowledged = TRUE
	C.player_help_action_token = new_token()
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
	handle_action(usr ? usr.client : null, href_list)

// Every refusal tells the player why, inside the window; a click that does nothing reads as broken.
/datum/player_help_service/proc/handle_action(client/C, list/href_list)
	if (!C || !islist(href_list))
		return
	expire_conversations()
	var/question = href_list["question"]
	question = istext(question) ? trim(question) : null
	if (!valid_action(C, href_list["token"]))
		// The window on screen belongs to a conversation that is gone. Replace it
		// with the current one and keep what the player typed.
		refuse(C, "That window was out of date: its conversation was cleared after a reconnect, a change of body, a new conversation or 15 minutes without questions. Nothing was sent.", question)
		return
	if (href_list["action"] == "reset")
		reset_conversation(C)
		show_window(C)
	else if (href_list["action"] == "open")
		// Guide links open in the player's own browser, so the conversation stays on screen.
		var/url = href_list["url"]
		if (markdown_url(url) && length(url) <= 300 && findtext(url, "https://civ13.github.io/") == 1)
			C << link(url)
	else if (href_list["action"] == "ask")
		if (!length(question))
			refuse(C, "Type your question in the box first.")
			return
		var/list/pair
		var/raw_turn = href_list["turn"]
		if (!isnull(raw_turn))
			// One remembered exchange chosen as the only context for this question.
			var/turn = istext(raw_turn) ? text2num(raw_turn) : null
			if (!isnum(turn) || turn != round(turn) || turn < 1 || turn > C.player_help_turns.len || "[turn]" != raw_turn)
				refuse(C, "That exchange is no longer available. Ask about the whole conversation instead.", question)
				return
			pair = C.player_help_turns[turn]
		submit(C, question, pair)

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
		return "Sign in to a BYOND account to ask for help. Guests cannot use it."
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
			return "Your previous question is still pending. Wait for its answer, then ask again."
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
			return "You are asking faster than the helper allows. Wait [round(retry / 10) + 1] seconds, then press the button again."
	if (!slot || global_times.len >= limits["global_requests"] || (!history && accounts.len >= limits["max_accounts"]))
		return "The helper is busy with other questions. Wait a few seconds, then press the button again."
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
	return heartbeat_fresh()

// poll() calls available() every half second, so this is current without reading a file.
/datum/player_help_service/proc/heartbeat_fresh()
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
	var/list/slots = list("left hand" = H.l_hand, "right hand" = H.r_hand, "back" = H.back, "mask" = H.wear_mask, "suit" = H.wear_suit, "uniform" = H.w_uniform, "shoes" = H.shoes, "belt" = H.belt, "gloves" = H.gloves, "head" = H.head, "left ear" = H.l_ear, "right ear" = H.r_ear, "hip" = H.wear_id, "left pocket" = H.l_store, "right pocket" = H.r_store)
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
	retain_injury(C, H, list("kind" = kind, "time" = limit_time()))

// Called only after the animal attack confirms injury. Awareness is captured
// before damage: the same hit may knock the victim unconscious. Never retain
// attacker references, renamed labels, account names or raw admin attack logs.
/datum/player_help_service/proc/record_animal_injury(client/C, mob/living/human/H, mob/living/simple_animal/animal, limb, lost_limb)
	if (!C || !(C in clients) || !H || C.mob != H || H.client != C || !animal)
		return
	if ((lost_limb || !isnull(limb)) && !(limb in injury_body_parts()))
		return
	var/source = istype(animal, /mob/living/simple_animal/hostile/alligator) ? "alligator" : "animal"
	retain_injury(C, H, list("kind" = lost_limb ? "animal_limb_loss" : "animal_damage", "time" = limit_time(), "source" = source, "body_part" = limb))

/datum/player_help_service/proc/injury_body_parts()
	return list("chest", "groin", "head", "l_arm", "r_arm", "l_hand", "r_hand", "l_leg", "r_leg", "l_foot", "r_foot")

/datum/player_help_service/proc/retain_injury(client/C, mob/living/human/H, list/event)
	bind_body(C, H)
	if (!(C in conversation_clients))
		if (conversation_clients.len >= 128)
			reset_conversation(conversation_clients[1])
		// Track an injury-only session, without extending an existing conversation.
		C.player_help_touched = limit_time()
		conversation_clients |= C
	C.player_help_injuries += list(event)
	while (C.player_help_injuries.len > 6)
		C.player_help_injuries.Cut(1, 2)

/datum/player_help_service/proc/injury_context(client/C, mob/living/human/H)
	var/list/results = list()
	if (!C || !(C in clients) || !H || C.mob != H || H.client != C || C.player_help_body != H)
		return results
	var/now = limit_time()
	for (var/list/event in C.player_help_injuries)
		if (!(event["kind"] in list("self_weapon_hit", "reported_projectile_hit", "reported_shrapnel_hit", "reported_hot_ground", "reported_freezing_feet", "animal_damage", "animal_limb_loss")) || !isnum(event["time"]) || event["time"] > now || now - event["time"] >= 6000)
			continue
		var/list/row = list("kind" = event["kind"], "certainty" = "observed", "age_seconds" = round((now - event["time"]) / 10))
		if (event["kind"] in list("animal_damage", "animal_limb_loss"))
			if (!(event["source"] in list("alligator", "animal")) || ((event["kind"] == "animal_limb_loss" || !isnull(event["body_part"])) && !(event["body_part"] in injury_body_parts())))
				continue
			row["source"] = event["source"]
			if (!isnull(event["body_part"]))
				row["body_part"] = event["body_part"]
		results += list(row)
	return results

// Fixed external body parts only, not a vars walk or internal organ diagnosis.
/datum/player_help_service/proc/body_damage_context(mob/living/human/H)
	var/list/results = list()
	for (var/part in injury_body_parts())
		var/obj/item/organ/external/O = H.get_organ(part)
		var/present = O && O.owner == H
		var/list/row = list("body_part" = part, "missing" = present ? FALSE : TRUE, "brute" = present ? round(max(0, min(1000, O.brute_dam))) : 0, "burn" = present ? round(max(0, min(1000, O.burn_dam))) : 0)
		if (present)
			// Limb states the character already sees when examining themselves;
			// they let Help give tourniquet, splint and bandage steps directly.
			var/bleeding = FALSE
			for (var/datum/wound/W in O.wounds)
				if (!W.internal && W.bleeding())
					bleeding = TRUE
					break
			row["bleeding"] = bleeding
			row["artery_cut"] = (O.status & ORGAN_ARTERY_CUT) ? TRUE : FALSE
			row["tourniquet"] = O.tourniquet ? TRUE : FALSE
			row["broken"] = (O.status & ORGAN_BROKEN) ? TRUE : FALSE
			row["splinted"] = (O.status & ORGAN_SPLINTED) ? TRUE : FALSE
		results += list(row)
	return results

// Match the categories shown to the character by print_mood(), not raw mood.
/datum/player_help_service/proc/mood_category(value)
	return isnum(value) ? capitalize(mood_tier_name(value)) : null

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
		condition["mood_category"] = mood_category(H.mood)
		// Job title the player already sees; lets Help tailor advice to their role.
		if (H.original_job && istext(H.original_job_title) && length(H.original_job_title))
			condition["role"] = copytext(H.original_job_title, 1, 81)
		var/list/events = list()
		if (H.on_fire)
			events += "On fire"
		if (H.stunned || H.weakened)
			events += "Incapacitated"
		var/area/A = get_area(H)
		if (A)
			condition["outdoors"] = A.location == AREA_OUTSIDE ? TRUE : FALSE
			var/local_weather = weather_at(H)
			condition["local_weather"] = local_weather == WEATHER_WET ? "Wet weather" : (local_weather == WEATHER_EXTREME ? "Extreme weather" : (local_weather == WEATHER_SMOG ? "Smog" : "No weather"))
			if (A.location == AREA_OUTSIDE && local_weather != WEATHER_NONE)
				events += "Exposed to local weather"
		condition["active_effects"] = events
		condition["inventory"] = inventory_context(H)
		condition["recent_injuries"] = injury_context(H.client, H)
		condition["body_damage"] = body_damage_context(H)
		context["player"] = condition
	return context

/datum/player_help_service/proc/submit(client/C, question, list/target_pair = null)
	if (!C || !istext(question) || !length(question))
		return FALSE
	var/result = enqueue(account_key(C), question, C, target_pair)
	if (istext(result))
		refuse(C, result, question)
		return FALSE
	// The window shows the question and a waiting line until poll() brings the answer.
	C.player_help_pending = question
	player_activity.feature_used(C, "player_help")
	show_window(C)
	return TRUE

// Server-owned queue boundary; no client/Topic-supplied account identifiers.
/datum/player_help_service/proc/enqueue(account, question, client/C, list/target_pair = null)
	expire_conversations()
	if (C)
		bind_body(C, C.mob)
	if (!available())
		return "The helper is unavailable right now. Try again later, or use the player wiki and the Crafting Atlas."
	if (!istext(question) || !length(question) || length(question) > 500)
		return "Please keep your question to 1 through 500 characters."
	if (C && C.player_help_turns.len && !conversation_supported)
		return "This helper cannot carry follow-up context. Press New conversation, then ask again."
	if (target_pair && (!C || !conversation_supported || !C.player_help_acknowledged || !C.player_help_turns.Find(target_pair)))
		return "That exchange is no longer available. Ask about the whole conversation instead."
	var/slot = reserve(account)
	if (!isnum(slot))
		return slot
	serial++
	var/id = "[world.realtime]-[rand(1, 999999)]-[serial]"
	var/list/request = list("id" = id, "account" = account, "question" = question, "game_context" = game_context(C ? C.mob : null))
	request["render_contract"] = list("version" = 1, "capabilities" = list("markdown-basic-v1"))
	if (C && conversation_supported)
		var/list/turns = target_pair ? list(target_pair) : C.player_help_turns.Copy()
		request["conversation"] = list("version" = 1, "turns" = turns)
	// Includes escaping, IDs, context and metadata, not just dialogue bytes.
	// A targeted reply must never silently lose the exchange it refers to.
	if (target_pair && request_size(request) > 16384)
		clear_slot(slot)
		return "The selected exchange and your character's details are too large to send together. Try a shorter question or start a new conversation."
	// Retain complete newest pairs when the existing spool envelope is tight.
	while (request_size(request) > 16384 && request["conversation"])
		var/list/conversation = request["conversation"]
		var/list/turns = conversation["turns"]
		if (!turns.len)
			break
		turns.Cut(1, 2)
	if (request_size(request) > 16384)
		clear_slot(slot)
		return "That question and your character's details are too long to send together. Try a shorter question."
	fdel("[root][slot].ready")
	fdel("[root][slot].request.json")
	fdel("[root][slot].response.json")
	if (!write_request(slot, request))
		clear_slot(slot)
		return "The helper could not send your question. Try again in a moment."
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
		var/asked = entry["question"]
		if (islist(response))
			var/answer_format = response_format(response)
			if (C)
				C.player_help_pending = null
			if (C && response["status"] == "ok" && entry["had_history"] && response["conversation_protocol"] != 1)
				reset_conversation(C)
				refuse(C, "The helper did not accept the earlier conversation, so it was cleared. Ask your question again.", asked)
			else if (C && answer_format && response["status"] == "ok" && istext(response["answer"]) && length(response["answer"]) && length(response["answer"]) <= 4000)
				if (entry["conversation"] && response["conversation_protocol"] == 1)
					remember(C, asked, response["answer"], answer_format == "plain-v1")
				else
					// A worker without follow-up context: show this one exchange and send nothing later.
					reset_conversation(C)
					var/list/standalone = list("question" = asked, "answer" = response["answer"])
					C.player_help_standalone = list(standalone)
					if (answer_format == "plain-v1")
						C.player_help_plain = list(standalone)
				show_window(C)
				player_activity.help_outcome(C, "ok")
			else if (C && response["status"] == "rate_limited")
				player_activity.help_outcome(C, "rate_limited")
				refuse(C, "You are asking faster than the helper allows. Wait [max(1, min(86400, text2num("[response["retry_seconds"]]")))] seconds, then press the button again.", asked)
			else if (C && (response["status"] == "busy" || response["status"] == "pending"))
				player_activity.help_outcome(C, "busy")
				refuse(C, "The helper is busy with other questions. Wait [max(1, min(86400, text2num("[response["retry_seconds"]]")))] seconds, then press the button again.", asked)
			else if (C)
				player_activity.help_outcome(C, "failed")
				refuse(C, "The helper could not answer that. Try again in a moment, or use the player wiki and the Crafting Atlas.", asked)
			clear_slot(i)
		else if (world.time >= entry["deadline"])
			if (C)
				C.player_help_pending = null
				player_activity.help_outcome(C, "timeout")
				refuse(C, "The helper took too long to answer. Try again in a moment, or use the player wiki and the Crafting Atlas.", asked)
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

// Answer text as display markup. This is the only place model output becomes
// HTML: plain answers are escaped whole, Markdown goes through markdown_answer().
/datum/player_help_service/proc/answer_markup(answer, answer_format = "markdown-basic-v1")
	if (!istext(answer) || length(answer) > 4000)
		return "<p>AI gameplay help did not receive a usable response.</p>"
	if (answer_format == "plain-v1")
		return "<pre>[html_encode(answer)]</pre>"
	if (answer_format == "markdown-basic-v1")
		return markdown_answer(answer)
	return null

// The whole window, drawn from the server's state for this client: the
// conversation in order, the question still waiting, one notice and the question
// box. Questions, notices and drafts are escaped; answers come from answer_markup().
/datum/player_help_service/proc/render_window(client/C)
	var/token = C.player_help_action_token
	var/base = "?src=\ref[src];token=[token]"
	var/list/pairs = C.player_help_turns.len ? C.player_help_turns : C.player_help_standalone
	var/waiting = istext(C.player_help_pending) && length(C.player_help_pending)
	// Choosing one earlier answer to ask about only matters when there are several.
	var/can_target = C.player_help_turns.len > 1 && C.player_help_acknowledged && conversation_supported && !waiting
	var/list/thread = list()
	var/turn = 0
	if (islist(pairs))
		for (var/list/pair in pairs)
			turn++
			if (!istext(pair["question"]) || !istext(pair["answer"]) || length(pair["question"]) > 500 || length(pair["answer"]) > 4000)
				continue
			var/markup = answer_markup(pair["answer"], (pair in C.player_help_plain) ? "plain-v1" : "markdown-basic-v1")
			var/reply = can_target ? "<a class='reply' href='#' data-turn='[turn]'>Ask about this answer</a>" : ""
			thread += "<div class='msg you'><div class='who'>You</div><div class='bubble'>[html_encode(pair["question"])]</div></div>"
			thread += "<div class='msg helper'><div class='who'>Helper</div><div class='bubble answer'>[markup]</div>[reply]</div>"
	if (waiting)
		thread += "<div class='msg you'><div class='who'>You</div><div class='bubble'>[html_encode(C.player_help_pending)]</div></div>"
		thread += "<div class='msg helper'><div class='who'>Helper</div><div class='bubble pending'><span class='dots'><i></i><i></i><i></i></span><span id='pendingText'>Looking through the guides</span></div></div>"
	var/started = thread.len
	if (!started)
		var/list/chips = list()
		for (var/example in list("What should I do first?", "How do I make a fire?", "How do I stop bleeding?", "How do I stay warm in winter?"))
			chips += "<a class='chip' href='[base];action=ask;question=[url_encode(example)]'>[example]</a>"
		thread += "<div class='empty'><h2>What do you need help with?</h2><p>Ask about crafting, survival, farming, medicine, travel or anything else in the game. The helper answers from the player wiki and the game's recipes. It remembers the conversation, so you can ask follow-up questions.</p><div class='chips'>[jointext(chips, "")]</div></div>"
	if (istext(C.player_help_notice) && length(C.player_help_notice))
		thread += "<div class='notice' role='alert'>[html_encode(C.player_help_notice)]</div>"
	else if (!waiting && !heartbeat_fresh())
		thread += "<div class='notice' role='alert'>The helper is not answering right now. You can still try, or use the player wiki and the Crafting Atlas.</div>"
	var/draft = istext(C.player_help_draft) ? html_encode(copytext(C.player_help_draft, 1, 2001)) : ""
	var/followup = C.player_help_turns.len > 0
	var/locked = waiting ? " disabled" : ""
	var/reset = started ? "<a class='button quiet' href='[base];action=reset'>New conversation</a>" : ""
	return {"<!DOCTYPE html><html><head><meta charset='utf-8'><meta http-equiv='X-UA-Compatible' content='IE=edge'><title>Ask for Help</title><style>
@font-face{font-family:'Civ13Custom';src:url('Alegreya-Regular.ttf') format('truetype');font-weight:normal;font-style:normal}
@font-face{font-family:'Civ13Custom';src:url('Alegreya-Bold.ttf') format('truetype');font-weight:bold;font-style:normal}
@font-face{font-family:'Civ13Custom';src:url('Alegreya-Italic.ttf') format('truetype');font-weight:normal;font-style:italic}
*{box-sizing:border-box}
html,body{height:100%}
body{margin:0;display:flex;flex-direction:column;overflow:hidden;background:#392611;color:#ece6d6;font-family:'Civ13Custom','Book Antiqua','Palatino Linotype',Georgia,serif;font-size:16px;line-height:1.45}
a{color:#ffb27d}
a:hover{color:#ffd0ae}
.bar{flex:none;display:flex;align-items:center;gap:12px;padding:10px 14px;background:#271a0c;border-bottom:2px solid #1a1108}
.bar h1{margin:0;font-size:21px;line-height:1.2;color:#ff8040;font-weight:bold}
.bar p{margin:2px 0 0;font-size:13px;line-height:1.3;color:#b8ab92}
.bar .title{flex:1;min-width:0}
.button{flex:none;display:inline-block;padding:6px 12px;border:1px solid #1a1108;border-radius:4px;background:#ff8040;color:#1a1108;font:inherit;font-size:15px;font-weight:bold;line-height:1.2;text-decoration:none;cursor:pointer}
.button:hover{background:#ff9a66;color:#1a1108}
.button.quiet{background:#3f2a13;border-color:#6b5230;color:#ece6d6;font-weight:normal;font-size:14px}
.button.quiet:hover{border-color:#ff8040;color:#fff}
.button:disabled{background:#4a3520;border-color:#4a3520;color:#9a8a70;cursor:default}
#thread{flex:1;min-height:0;overflow-y:auto;padding:14px 14px 6px}
#thread::-webkit-scrollbar{width:10px}
#thread::-webkit-scrollbar-thumb{background:#6b5230;border-radius:5px}
#thread::-webkit-scrollbar-track{background:#2e1e0d}
.msg{display:flex;flex-direction:column;margin:0 0 12px}
.who{font-size:12px;line-height:1.2;letter-spacing:.06em;text-transform:uppercase;color:#b8ab92;margin:0 4px 3px}
.bubble{padding:8px 12px;border-radius:8px;overflow-wrap:anywhere;word-wrap:break-word}
.you{align-items:flex-end}
.you .bubble{max-width:82%;background:#5c3f1d;border:1px solid #7a5628;border-bottom-right-radius:2px;color:#f6f0e1;white-space:pre-wrap}
.helper{align-items:flex-start}
.helper .bubble{max-width:94%;background:#2b1c0d;border:1px solid #1a1108;border-left:3px solid #c8763a;border-bottom-left-radius:2px}
.answer p{margin:0 0 7px}
.answer p:last-child,.answer pre:last-child{margin-bottom:0}
.answer h1,.answer h2,.answer h3,.answer h4,.answer h5,.answer h6{margin:8px 0 4px;font-size:16px;line-height:1.3;color:#ffb27d}
.answer h1:first-child,.answer h2:first-child,.answer h3:first-child,.answer h4:first-child{margin-top:0}
.answer b{color:#fff6e4}
.answer code,.answer pre{font-family:Consolas,'Courier New',monospace;font-size:14px;background:#1a1108;border-radius:3px}
.answer code{padding:1px 4px}
.answer pre{margin:0 0 7px;padding:6px 8px;white-space:pre-wrap;overflow-wrap:anywhere}
.reply{display:none;margin:3px 4px 0;font-size:13px;color:#b8ab92}
.js .reply{display:inline-block}
.pending{color:#b8ab92;font-style:italic}
.dots{display:inline-block;margin-right:8px}
.dots i{display:inline-block;width:6px;height:6px;margin-right:3px;border-radius:50%;background:#ff8040;animation:wait 1.2s infinite ease-in-out}
.dots i:nth-child(2){animation-delay:.2s}
.dots i:nth-child(3){animation-delay:.4s}
@keyframes wait{0%,80%,100%{opacity:.25;transform:translateY(0)}40%{opacity:1;transform:translateY(-3px)}}
.empty{max-width:460px;margin:26px auto 14px;text-align:center}
.empty h2{margin:0 0 6px;font-size:22px;color:#f6f0e1}
.empty p{margin:0 0 14px;color:#cfc6b1}
.chips{display:flex;flex-wrap:wrap;justify-content:center;gap:8px}
.chip{padding:5px 12px;border:1px solid #6b5230;border-radius:14px;background:#271a0c;color:#ece6d6;font-size:15px;text-decoration:none}
.chip:hover{border-color:#ff8040;color:#fff}
.notice{margin:0 0 12px;padding:8px 12px;border:1px solid #ff8040;border-radius:6px;background:#4b2a12;color:#ffe0cc}
.ask{flex:none;margin:0;padding:10px 14px 8px;background:#271a0c;border-top:2px solid #1a1108}
.target{display:none;align-items:center;gap:8px;margin:0 0 6px;font-size:13px;color:#b8ab92}
.target b{flex:1;min-width:0;overflow:hidden;white-space:nowrap;text-overflow:ellipsis;color:#ece6d6;font-weight:normal;font-style:italic}
.target a{flex:none;text-decoration:none;font-size:18px;line-height:1;color:#b8ab92}
.row{display:flex;gap:8px}
#q{flex:1;min-width:0;padding:7px 10px;border:1px solid #6b5230;border-radius:4px;background:#1f1408;color:#f6f0e1;font:inherit}
#q:focus{outline:none;border-color:#ff8040}
#q:disabled{color:#9a8a70}
#q::placeholder{color:#8c7d64}
.fine{margin:7px 0 0;font-size:12px;line-height:1.35;color:#9c8f77}
.fine a{color:#c9b792}
</style></head><body>
<div class='bar'><div class='title'><h1>Ask for Help</h1><p>AI answers can be wrong. Check recipes in the Crafting Atlas.</p></div>[reset]</div>
<div id='thread'>[jointext(thread, "")]</div>
<form class='ask' id='ask' action='byond://?' method='get'><input type='hidden' name='src' value='\ref[src]'><input type='hidden' name='action' value='ask'><input type='hidden' name='token' value='[token]'><input type='hidden' name='turn' id='turn' value='' disabled>
<div class='target' id='target'><span>Asking only about:</span><b id='targetq'></b><a href='#' id='untarget' title='Ask about the whole conversation'>&times;</a></div>
<div class='row'><input id='q' name='question' maxlength='500' autocomplete='off' aria-label='Your question' placeholder="[followup ? "Ask a follow-up question" : "Type your question"]" value="[draft]"[locked]><button class='button' id='send' type='submit'[locked]>[waiting ? "Waiting" : (followup ? "Follow up" : "Ask")]</button></div>
<p class='fine'>Your question and your character's condition (health, mood, recent injuries, inventory, exposure and public server state) are sent to the server owner's AI service. Do not enter personal information. <a href='https://civ13.github.io/civ13-wiki/'>Player wiki</a> &middot; <a href='https://civ13.github.io/Civ13/crafting/'>Crafting Atlas</a></p></form>
<script>
(function(){
var send='byond://[base];action=';
var thread=document.getElementById('thread'),form=document.getElementById('ask'),q=document.getElementById('q'),button=document.getElementById('send'),turn=document.getElementById('turn'),target=document.getElementById('target');
document.body.className='js';
var asked=document.querySelectorAll('.you');
if(!asked.length||document.querySelector('.notice,.pending')){thread.scrollTop=thread.scrollHeight;}
else{thread.scrollTop=Math.max(0,asked.item(asked.length-1).offsetTop-thread.offsetTop-8);}
function ready(){button.disabled=q.disabled||!q.value.trim().length;}
q.addEventListener('input',ready);ready();
if(!q.disabled){q.focus();q.setSelectionRange(q.value.length,q.value.length);}
form.addEventListener('submit',function(e){
e.preventDefault();
var text=q.value.trim();
if(!text||q.disabled){return;}
var url=send+'ask'+(turn.value?';turn='+turn.value:'')+';question='+encodeURIComponent(text);
q.disabled=true;button.disabled=true;button.textContent='Sending';
setTimeout(function(){q.disabled=false;button.textContent='Try again';ready();},8000);
window.location.href=url;
});
document.querySelectorAll('.reply').forEach(function(a){a.addEventListener('click',function(e){
e.preventDefault();
turn.value=a.getAttribute('data-turn');
document.getElementById('targetq').textContent=a.parentNode.previousElementSibling.querySelector('.bubble').textContent;
target.style.display='flex';q.placeholder='Ask about that answer';q.focus();
});});
document.getElementById('untarget').addEventListener('click',function(e){e.preventDefault();turn.value='';target.style.display='none';q.placeholder='Ask a follow-up question';q.focus();});
document.addEventListener('click',function(e){
var a=e.target.closest?e.target.closest('a'):null;
if(a&&a.href&&a.href.indexOf('https://civ13.github.io/')===0){e.preventDefault();window.location.href=send+'open;url='+encodeURIComponent(a.href);}
});
var slow=document.getElementById('pendingText');
if(slow){setTimeout(function(){slow.textContent='Still working. A long answer can take a minute';},20000);}
})();
</script></body></html>"}

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
	// Half a second: poll() reads one small health file and only the pending slots' responses,
	// and a finished answer should reach the player without waiting on a slow timer.
	schedule_interval = 5
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_LOW

/process/player_help/fire()
	player_help_service.poll()
