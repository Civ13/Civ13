// Launcher voice chat, game side (issue #5122 Phase 3, docs/launcher-voice-plan.md).
//
// The launcher joins with byond://host:port?civ13_voice=<key>. The key is a
// random per-connection secret that only that launcher and this world know.
// The game, not the player, decides who hears whom:
// - Voice identity is the BYOND key, so no Discord login is needed. Every
//   roster POST (voice_roster) lists ckey, voice key and team. CivilizationBot
//   gives each ckey a Discord provisional account (or the player's linked
//   account), hands the launcher its token over HTTPS when it shows the voice
//   key, and answers with the Discord user ID of every ckey.
// - The bot keeps one Discord voice lobby per region and one per team, with
//   members set from that roster. Nobody outside it can join either call.
// - In the region call, a player hears only voice players their character can
//   see, louder when closer. The launcher reads that list with the
//   civ13_voice_state topic and sets each participant's volume.
// - In the team call, everyone on the same faction in this region hears the
//   speaker's team-radio key.
// Volume is presentation, not confidentiality: a modified client can still
// play the whole region call. Players can always mute anyone themselves.

#define VOICE_KEY_MIN_LENGTH 32
#define VOICE_KEY_MAX_LENGTH 64
#define VOICE_RANGE 10
#define VOICE_STATE_CACHE (5) // deciseconds a computed answer is reused
#define VOICE_ADDRESS_INTERVAL (2) // deciseconds between topic calls per address
#define VOICE_ADDRESS_LIMIT 4096
#define VOICE_ROSTER_INTERVAL (5 SECONDS)
#define VOICE_ROSTER_KEEPALIVE (60 SECONDS)

/client/var/tmp/voice_key = null // the launcher's voice secret, never logged

// The voice key from a join link's topic, or null. Anything malformed is ignored.
/proc/voice_key_from_topic(topic)
	if(!istext(topic) || !length(topic) || length(topic) > 2048) return null
	var/list/params = params2list(topic)
	var/key = params["civ13_voice"]
	if(!istext(key) || length(key) < VOICE_KEY_MIN_LENGTH || length(key) > VOICE_KEY_MAX_LENGTH) return null
	var/static/regex/urlsafe = regex(@"^[A-Za-z0-9_-]+$")
	if(!urlsafe.Find(key)) return null
	return key

// What the launcher sends when it polls: sha1 of a label and its key, so the
// key itself never crosses the network after the join (the bot seals the
// launcher's Discord token with a key derived from it).
/proc/voice_poll_id(key)
	return sha1("civ13-voice-state:[key]")

// 0-100: how loud a speaker this many tiles away sounds.
/proc/voice_volume_at(distance)
	if(!isnum(distance) || distance < 0 || distance > VOICE_RANGE) return 0
	if(distance <= 2) return 100
	if(distance <= 5) return 75
	if(distance <= 8) return 50
	return 30

// A body that can talk: a living human whose player is conscious.
/proc/voice_can_speak(mob/M)
	return ishuman(M) && M.stat == CONSCIOUS

// A body that can hear: any living human, even knocked out (the SDK has no
// muffle, and waking up should not need a round trip).
/proc/voice_can_hear(mob/M)
	return ishuman(M) && M.stat != DEAD

// The faction a voice player's team call belongs to, or null.
/proc/voice_team(mob/M)
	if(!ishuman(M)) return null
	var/mob/living/human/H = M
	var/team = H.faction_text
	if(!istext(team) || !length(team) || length(team) > 64) return null
	return team

var/global/datum/voice_chat/voice_chat = new

/datum/voice_chat
	var/list/clients_by_key = list() // voice key -> client
	var/list/answers = list() // voice key -> list("at" = world.time, "body" = text)
	var/list/address_next = list() // address -> world.time of the next allowed call
	var/list/generations = list() // voice key -> list("gen", "mob", "alive")
	var/list/ids = list() // ckey -> Discord user ID, from the bot's roster answer
	var/list/poll_ids = list() // voice_poll_id(key) -> voice key
	var/last_roster = null // json of the last roster POSTed
	var/last_roster_at = -100000
	var/datum/http_request/roster_request = null
	var/roster_timer = null

/datum/voice_chat/proc/attach(client/C, key)
	if(!C || !key) return
	if(clients_by_key[key] && clients_by_key[key] != C)
		return // a duplicate key keeps its first owner; the second launcher gets nothing
	C.voice_key = key
	clients_by_key[key] = C
	poll_ids[voice_poll_id(key)] = key
	if(!roster_timer)
		roster_timer = addtimer(CALLBACK(src, PROC_REF(roster_tick)), VOICE_ROSTER_INTERVAL, TIMER_LOOP | TIMER_STOPPABLE)

/datum/voice_chat/proc/detach(client/C)
	if(!C || !C.voice_key) return
	if(clients_by_key[C.voice_key] == C)
		clients_by_key -= C.voice_key
		poll_ids -= voice_poll_id(C.voice_key)
	answers -= C.voice_key
	generations -= C.voice_key
	C.voice_key = null

// A client that may use voice: it joined with a voice key and has a stable
// BYOND key (guest keys change every connect).
/datum/voice_chat/proc/eligible(client/C)
	return C && C.voice_key && clients_by_key[C.voice_key] == C && !IsGuestKey(C.key)

// The Discord user ID a voice client is heard as, or null until the bot
// has answered with one.
/datum/voice_chat/proc/voice_id(client/C)
	if(!eligible(C)) return null
	var/id = ids[C.ckey]
	return is_discord_id(id) ? id : null

// The Discord user ID a body is heard as: its player's, when that player uses voice.
/datum/voice_chat/proc/speaker_id(mob/M)
	return M && M.client ? voice_id(M.client) : null

// Reads the bot's roster answer: {"ids": {ckey: Discord user ID}}. Anything
// malformed leaves the known IDs alone.
/datum/voice_chat/proc/take_ids(body)
	if(!istext(body) || length(body) > 262144) return FALSE
	var/list/answer
	try
		answer = json_decode(body)
	catch(var/exception/e)
		if(e) return FALSE
	if(!islist(answer) || !islist(answer["ids"])) return FALSE
	var/list/fresh = list()
	var/list/given = answer["ids"]
	for(var/ckey_value in given)
		var/id = given[ckey_value]
		if(istext(ckey_value) && ckey(ckey_value) == ckey_value && is_discord_id(id))
			fresh[ckey_value] = id
	ids = fresh
	answers.Cut()
	return TRUE

// Bumps a client's generation whenever its body changes or dies, so the
// launcher drops volumes that belonged to the old body at once.
/datum/voice_chat/proc/generation(client/C)
	var/list/entry = generations[C.voice_key]
	var/mob/M = C.mob
	var/alive = voice_can_hear(M)
	if(!entry)
		entry = list("gen" = 1, "mob" = M, "alive" = alive)
		generations[C.voice_key] = entry
	else if(entry["mob"] != M || entry["alive"] != alive)
		entry["gen"] = entry["gen"] + 1
		entry["mob"] = M
		entry["alive"] = alive
	return entry["gen"]

// Discord ID -> volume for every voice player this client's body can see.
// Dead, observing and lobby players hear nobody in the region call.
/datum/voice_chat/proc/audible(mob/listener)
	. = list()
	if(!voice_can_hear(listener) || !isturf(listener.loc)) return
	for(var/mob/living/human/H in hearers(VOICE_RANGE, listener))
		if(H == listener || !voice_can_speak(H)) continue
		var/id = speaker_id(H)
		if(!id) continue
		var/volume = voice_volume_at(get_dist(listener, H))
		if(volume > .[id]) .[id] = volume

// The answer for one voice key, as JSON text. Unknown keys get an empty answer
// that looks like a player with nobody in sight.
/datum/voice_chat/proc/state(key)
	var/client/C = clients_by_key[key]
	var/id = voice_id(C)
	if(!id)
		return json_encode(list("v" = 1, "gen" = 0, "ready" = eligible(C) ? 0 : -1))
	var/list/cached = answers[key]
	if(cached && world.time >= cached["at"] && world.time < cached["at"] + VOICE_STATE_CACHE)
		return cached["body"]
	var/list/answer = list("v" = 1, "gen" = generation(C), "me" = id, "hear" = audible(C.mob))
	var/team = voice_team(C.mob)
	if(team && voice_can_hear(C.mob)) answer["team"] = team
	var/body = json_encode(answer)
	answers[key] = list("at" = world.time, "body" = body)
	return body

// Topic entry point, called before the generic once-per-two-minutes topic
// cooldown: a launcher asks about twice a second. Calls faster than that from
// one address get nothing back, and never a ban.
/datum/voice_chat/proc/handle_topic(list/input, addr)
	var/poll_id = input["civ13_voice_state"]
	var/static/regex/hex40 = regex(@"^[0-9a-f]{40}$")
	if(!istext(poll_id) || !hex40.Find(poll_id))
		return ""
	var/host = "?"
	if(istext(addr))
		var/list/parts = splittext(addr, ":")
		host = parts[1]
	var/next = address_next[host]
	if(isnum(next) && world.time < next && world.time >= next - VOICE_ADDRESS_INTERVAL)
		return ""
	if(address_next.len >= VOICE_ADDRESS_LIMIT)
		address_next.Cut()
	address_next[host] = world.time + VOICE_ADDRESS_INTERVAL
	return state(poll_ids[poll_id])

// One entry per eligible voice player in this world: ckey, the launcher's
// voice key (so the bot can hand that launcher its token) and team ("" for none).
/datum/voice_chat/proc/roster()
	var/list/members = list()
	for(var/key in clients_by_key)
		var/client/C = clients_by_key[key]
		if(!eligible(C)) continue
		var/team = voice_can_hear(C.mob) ? voice_team(C.mob) : null
		members += list(list("ckey" = C.ckey, "key" = key, "team" = team ? team : ""))
	return members

// Where to POST the roster: WEBHOOK_ADDRESS + "/voice_roster", only when that
// address is loopback or https (it carries the webhook key). Null otherwise.
/proc/voice_roster_endpoint(address)
	var/verify = discord_verify_endpoint(address)
	if(!verify) return null
	return copytext(verify, 1, length(verify) - length("/discord_verify") + 1) + "/voice_roster"

// Sends the roster when it changed, and once a minute regardless, so the bot
// can drop members of a world that stopped talking to it. One request at a time.
/datum/voice_chat/proc/roster_tick()
	for(var/key in clients_by_key.Copy())
		var/client/C = clients_by_key[key]
		if(!C || C.voice_key != key)
			clients_by_key -= key
			poll_ids -= voice_poll_id(key)
			answers -= key
			generations -= key
	if(roster_request)
		if(!roster_request.is_complete()) return
		var/datum/http_response/response = roster_request.into_response()
		roster_request = null
		if(!response || response.error || response.status_code != 200 || !take_ids(response.body))
			last_roster = null // try again on the next tick
	if(!webhook_enabled()) return
	var/url = voice_roster_endpoint(config.webhook_address)
	if(!url) return
	var/body = json_encode(list("v" = 1, "members" = roster()))
	if(body == last_roster && world.time < last_roster_at + VOICE_ROSTER_KEEPALIVE && world.time >= last_roster_at) return
	var/datum/http_request/request = new
	request.prepare(RUSTG_HTTP_METHOD_POST, url, body, list("Content-Type" = "application/json", "X-Webhook-Key" = config.webhook_key))
	request.begin_async()
	roster_request = request
	last_roster = body
	last_roster_at = world.time
	if(!length(clients_by_key) && roster_timer)
		// The empty roster just went out; wake again when someone attaches.
		deltimer(roster_timer)
		roster_timer = null

#undef VOICE_KEY_MIN_LENGTH
#undef VOICE_KEY_MAX_LENGTH
#undef VOICE_STATE_CACHE
#undef VOICE_ADDRESS_INTERVAL
#undef VOICE_ADDRESS_LIMIT
#undef VOICE_ROSTER_INTERVAL
#undef VOICE_ROSTER_KEEPALIVE
