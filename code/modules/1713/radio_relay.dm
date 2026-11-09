// Independent Civ13 implementation. No upstream telecom source or assets copied.
//
// Cross-region radio (design: docs/cross-shard-radio.md). Radio inside one
// world is unchanged. A message crosses to another region of the shard group
// only through a long-range relay station here and one there that share a
// network key, both powered, with an antenna beside them and a condition above
// zero. Condition wears while the relay runs and in bad weather and is
// repaired with electronics or copper wire, so an untended relay goes silent.
//
// Transport is the region's transfer agent (tools/transfer_storage/radio.py):
// a /process posts outbound messages and polls arrivals once a second while
// a relay here is on the air, and nothing is ever saved or replayed.
#define CIV_RELAY_KEY_LIMIT 16
#define CIV_RELAY_MESSAGE_LIMIT 256
#define CIV_RELAY_GARBLE_BELOW 40
// Wear per ten running minutes with players present: fair, wet, extreme weather.
#define CIV_RELAY_WEAR_FAIR 1
#define CIV_RELAY_WEAR_WET 3
#define CIV_RELAY_WEAR_EXTREME 6
#define CIV_RELAY_WEAR_SECONDS 600
#define CIV_RELAY_REPAIR_ELECTRONICS 25
#define CIV_RELAY_REPAIR_COPPER 10
#define CIV_RELAY_RATE_LIMIT 10
#define CIV_RELAY_RATE_WINDOW 100
#define CIV_RELAY_HEARTBEAT 600
#define CIV_RELAY_LOG_LIMIT 200
#define CIV_RELAY_QUEUE_LIMIT 50

var/global/list/radio_relay_log = list()
var/global/civ_relay_wear_seconds = 0
// Last /radio/status answer: region id -> list(key -> list("condition", "age")).
var/global/list/civ_relay_peer_links = list()
// Envelopes waiting for the radio process to post them to the agent.
var/global/list/civ_relay_outbound_queue = list()

/proc/civ_relay_key_valid(value)
	return shard_id_valid(value) && length(value) <= CIV_RELAY_KEY_LIMIT

/obj/structure/telecom/relay
	name = "long-range radio relay"
	desc = "A powered relay desk. With an antenna beside it and a network key, it carries radio traffic to other lands whose relay shares the key, as long as both are kept in repair."
	icon_state = "radio_vintage"
	powerneeded = 40
	density = TRUE
	var/network_key = ""
	// 0 to 100, saved as a plain number; never a world.time stamp.
	var/condition = 100
	var/tmp/list/sent_times = list()

/obj/structure/telecom/relay/persistence_runtime_var(var_name)
	if (var_name == "sent_times")
		return TRUE
	return ..()

/obj/structure/telecom/relay/after_load()
	. = ..()
	if (!isnum(condition) || condition != condition)
		condition = 0
	condition = clamp(round(condition), 0, 100)
	if (!civ_relay_key_valid(network_key))
		network_key = ""

/obj/structure/telecom/relay/proc/has_antenna()
	// A comms satellite overhead stands in for the antenna (space/satellites.dm).
	if (satellite_comms_link(src))
		return TRUE
	for (var/obj/structure/telecom/antenna/A in range(1, src))
		if (!A.retired && (A in civ_telecom_devices) && A.anchored && isturf(A.loc) && A.z == z)
			return TRUE
	return FALSE

// Powered, switched on, with an antenna and some condition left: it wears.
/obj/structure/telecom/relay/proc/running()
	return operational() && has_antenna() && condition > 0

// On the air: running with a key set.
/obj/structure/telecom/relay/proc/on_air()
	return running() && civ_relay_key_valid(network_key)

/obj/structure/telecom/relay/proc/wear(amount)
	if (!running() || amount <= 0)
		return
	if (satellite_comms_link(src))
		amount /= 2
	condition = max(0, condition - amount)
	if (!condition)
		visible_message("<span class='warning'>[src] crackles and falls silent. It needs repair.</span>")

/obj/structure/telecom/relay/proc/garble(message)
	if (condition >= CIV_RELAY_GARBLE_BELOW || !prob(CIV_RELAY_GARBLE_BELOW - condition))
		return message
	return stars(message)

// At most CIV_RELAY_RATE_LIMIT outbound messages per CIV_RELAY_RATE_WINDOW deciseconds.
/obj/structure/telecom/relay/proc/allow_send()
	var/now = world.time
	var/list/kept = list()
	for (var/t in sent_times)
		if (now - t < CIV_RELAY_RATE_WINDOW)
			kept += t
	sent_times = kept
	if (sent_times.len >= CIV_RELAY_RATE_LIMIT)
		return FALSE
	sent_times += now
	return TRUE

/obj/structure/telecom/relay/ex_act(severity)
	switch (severity)
		if (1)
			condition = 0
		if (2)
			condition = max(0, condition - 60)
		else
			condition = max(0, condition - 25)

/obj/structure/telecom/relay/attack_hand(mob/living/human/H)
	if (!istype(H) || H.stat != CONSCIOUS || !H.can_use_hands() || get_dist(H, src) > 1)
		return
	var/choice = input(H, "Power it, set its network key, or repair it with electronics or copper wire. Drag an adjacent laid cable onto it to power it.", name) in list("Power", "Network key", "Cancel")
	if (!H || H.stat != CONSCIOUS || get_dist(H, src) > 1 || !H.can_use_hands())
		return
	if (choice == "Power")
		enabled = !enabled
		if (!enabled && powersource)
			powersource.update_power(-powerneeded, 1, src)
		to_chat(H, "You switch [src] [enabled ? "on" : "off"].")
	if (choice == "Network key")
		var/value = input(H, "Network key: 1 to [CIV_RELAY_KEY_LIMIT] lowercase letters, digits, - or _. Only relays with the same key exchange messages. Leave it empty to take the relay off the air.", name, network_key) as text|null
		if (isnull(value) || !H || get_dist(H, src) > 1 || H.stat != CONSCIOUS || !H.can_use_hands())
			return
		value = lowertext(trim(value))
		if (!length(value))
			network_key = ""
			to_chat(H, "[src] is off the air.")
		else if (civ_relay_key_valid(value))
			network_key = value
			to_chat(H, "[src] is keyed to <b>[network_key]</b>.")
		else
			to_chat(H, "<span class='warning'>A key is 1 to [CIV_RELAY_KEY_LIMIT] lowercase letters, digits, - or _.</span>")

/obj/structure/telecom/relay/attackby(obj/item/W, mob/living/human/H)
	var/restore = 0
	if (istype(W, /obj/item/stack/material/electronics))
		restore = CIV_RELAY_REPAIR_ELECTRONICS
	else if (istype(W, /obj/item/stack/material/copper))
		restore = CIV_RELAY_REPAIR_COPPER
	if (!restore)
		return ..()
	if (!istype(H) || H.stat != CONSCIOUS || !H.can_use_hands() || get_dist(H, src) > 1)
		return
	if (enabled)
		to_chat(H, "Switch [src] off before working on it.")
		return
	if (condition >= 100)
		to_chat(H, "[src] is in good repair.")
		return
	if (H.getStat("crafting") < 100)
		to_chat(H, "<span class='warning'>You do not know enough about radio equipment to repair this.</span>")
		return
	var/obj/item/stack/S = W
	if (S.amount < 1)
		return
	H.visible_message("[H] starts repairing [src].", "You start repairing [src].")
	if (!do_after(H, 50, src) || !S || S.amount < 1 || enabled || get_dist(H, src) > 1)
		return
	S.use(1)
	condition = min(100, condition + restore)
	to_chat(H, "You repair [src]. Condition [condition]%.")

/obj/structure/telecom/relay/examine(mob/user)
	. = ..()
	to_chat(user, "Network key: [length(network_key) ? network_key : "none (off the air)"]. Condition: [condition]%[condition < CIV_RELAY_GARBLE_BELOW ? (condition ? ", garbling" : ", silent") : ""].")
	if (!transfer_bridge.enabled())
		to_chat(user, "This land is not linked to any other.")
		return
	if (!running())
		to_chat(user, "It is [enabled ? (has_antenna() ? (condition ? "unpowered" : "in need of repair") : "missing an antenna") : "switched off"].")
	for (var/id in shard_group.order)
		var/list/peer = shard_group.peers[id]
		var/list/links = civ_relay_peer_links[id]
		var/state = peer["state"]
		var/line
		if (state == "DOWN" || state == "MISMATCH")
			line = "down"
		else if (state == "ASLEEP")
			line = "asleep"
		else if (!length(network_key))
			line = "no key set here"
		else if (!islist(links) || !islist(links[network_key]))
			line = "no working relay on this key"
		else
			var/list/far = links[network_key]
			line = "linked, their relay at [far["condition"]]%"
		to_chat(user, "[peer["name"]]: [line].")

// -- wear ------------------------------------------------------------------

// Called once a second by the civ_telecom process. Wear only accrues while
// the world has players, so a sleeping or empty world never catches up.
/proc/civ_relay_tick()
	if (!length(clients))
		return
	if (++civ_relay_wear_seconds < CIV_RELAY_WEAR_SECONDS)
		return
	civ_relay_wear_seconds = 0
	var/amount = CIV_RELAY_WEAR_FAIR
	if (weather == WEATHER_WET)
		amount = CIV_RELAY_WEAR_WET
	else if (weather == WEATHER_EXTREME)
		amount = CIV_RELAY_WEAR_EXTREME
	for (var/obj/structure/telecom/relay/R in civ_telecom_devices)
		R.wear(amount)

/proc/civ_relay_on_air_list()
	. = list()
	for (var/obj/structure/telecom/relay/R in civ_telecom_devices)
		if (R.on_air())
			. += R

// -- sending ----------------------------------------------------------------

// Called by every radio broadcast(). One envelope per distinct key on the air.
/proc/civ_relay_outbound(freq, mob/living/human/speaker, message, verbage = "says")
	if (!transfer_bridge.enabled() || !istype(speaker) || !istext(message) || !length(message))
		return
	if (!isnum(freq) && !istext(freq))
		return
	if (speaker.client && (speaker.client.prefs.muted & MUTE_IC))
		return
	var/list/keys = list()
	for (var/obj/structure/telecom/relay/R in civ_relay_on_air_list())
		if (R.network_key in keys)
			continue
		if (!R.allow_send())
			continue
		keys[R.network_key] = R
	if (!keys.len)
		return
	var/clean = copytext(html_encode(message), 1, CIV_RELAY_MESSAGE_LIMIT + 1)
	var/language_name = speaker.default_language ? speaker.default_language.name : "-"
	var/name = copytext(speaker.real_name, 1, 65)
	var/ckey_text = speaker.ckey ? speaker.ckey : "-"
	for (var/key in keys)
		var/obj/structure/telecom/relay/R = keys[key]
		var/list/envelope = list(
			"key" = key,
			"frequency" = freq,
			"name" = name,
			"message" = R.garble(clean),
			"language" = language_name,
			"verb" = verbage,
			"relay" = copytext(R.name, 1, 33),
			"condition" = R.condition,
			"ckey" = ckey_text)
		civ_relay_log_line("OUT", "[key_name(speaker)] on [key] ([freq]) via [R.name]: \"[clean]\"")
		// The radio process posts it; a burst beyond the queue is dropped oldest first.
		civ_relay_outbound_queue += list(envelope)
		if (civ_relay_outbound_queue.len > CIV_RELAY_QUEUE_LIMIT)
			civ_relay_outbound_queue.Cut(1, 2)

// Posts several queued envelopes in one request to the agent's
// /radio/send_batch. Returns how many the agent accepted (0 when it cannot be
// reached). Not used by the radio process yet, which sends one per request;
// switch to it when relay traffic makes the per-message round trips matter.
/proc/civ_relay_send_batch(list/envelopes)
	if (!transfer_bridge.enabled() || !length(envelopes))
		return 0
	var/list/answer = transfer_bridge.request("/radio/send_batch", list("envelopes" = envelopes))
	if (!islist(answer) || !answer["ok"] || !islist(answer["result"]))
		return 0
	var/accepted = 0
	for (var/id in answer["result"]["ids"])
		if (istext(id))
			accepted++
	return accepted

// -- receiving --------------------------------------------------------------

// A speaker from another land, for the hearer code: it needs a name, a real
// name and a language, and nothing else of a mob.
/datum/remote_speaker
	var/name = "someone"
	var/real_name = "someone"
	var/region = ""
	var/relay = ""
	var/datum/language/language = null

/proc/civ_relay_language(language_name)
	if (!istext(language_name) || language_name == "-")
		return null
	for (var/key in all_languages)
		var/datum/language/L = all_languages[key]
		if (L.name == language_name)
			return L
	return null

/proc/civ_relay_frequency_matches(obj/radio, freq)
	var/radio_freq
	var/list/multi
	if (istype(radio, /obj/item/weapon/radio))
		var/obj/item/weapon/radio/R = radio
		radio_freq = R.freq
		multi = R.multifreq ? R.multifreqlist : null
	else if (istype(radio, /obj/structure/radio))
		var/obj/structure/radio/SR = radio
		radio_freq = SR.freq
		multi = SR.multifreq ? SR.multifreqlist : null
	else
		return FALSE
	if (multi)
		return (freq in multi)
	return radio_freq == freq

// Every conscious human with a receiver on the frequency hears the relayed
// line through it; the same scan as global_broadcast(), one hearing per hearer.
/proc/civ_relay_rebroadcast(freq, datum/remote_speaker/speaker, message, verbage, obj/structure/telecom/relay/origin)
	var/list/tried = list()
	for (var/mob/living/human/hearer in human_mob_list)
		if ((hearer in tried) || hearer.stat != CONSCIOUS)
			continue
		tried += hearer
		var/obj/heard_on = null
		for (var/obj/structure/radio/radio in view(7, hearer))
			if (radio.receiver_on && civ_relay_frequency_matches(radio, freq) && (radio.check_power() || radio.powerneeded == 0))
				heard_on = radio
				break
		if (!heard_on)
			for (var/obj/item/weapon/radio/radio in range(1, get_turf(hearer)))
				if (radio.receiver_on && civ_relay_frequency_matches(radio, freq))
					heard_on = radio
					break
		if (!heard_on)
			for (var/obj/item/weapon/radio/radio in hearer.contents)
				if (radio.receiver_on && civ_relay_frequency_matches(radio, freq))
					heard_on = radio
					break
		if (heard_on)
			hearer.hear_relayed_radio(message, verbage, speaker, heard_on)
	// Powered broadcast receivers also carry regional traffic, bounded per arrival.
	var/list/station_audience = list()
	for (var/obj/structure/telecom/R in civ_telecom_devices)
		if (R.type != /obj/structure/telecom || R.frequency != freq || R.z != origin.z || get_dist(R, origin) > 60 || !R.operational())
			continue
		for (var/mob/living/human/H in view(3, R))
			if (station_audience.len >= 32)
				break
			if ((H in station_audience) || !H.broadcast_online() || H.stat != CONSCIOUS || H.sleeping || (H.sdisabilities & DEAF) || H.ear_deaf || H.find_trait("Deaf"))
				continue
			station_audience |= H
			var/heard = speaker.language && !H.say_understands(null, speaker.language) ? speaker.language.scramble(message, H) : message
			H.hear_station_line("[speaker.real_name] (via [speaker.relay], [speaker.region]): [heard]")
	for (var/mob/observer/O in mob_list)
		O.hear_relayed_radio(message, verbage, speaker, null)

/mob/proc/hear_relayed_radio(message, verbage, datum/remote_speaker/speaker, obj/destination)
	if (!client || !message || !speaker)
		return
	message = capitalize(message)
	if (sleeping || stat == UNCONSCIOUS)
		hear_sleep(message)
		return
	if (speaker.language && !(speaker.language.flags & INNATE) && !say_understands(null, speaker.language))
		message = speaker.language.scramble(message, src)
	if ((sdisabilities & DEAF) || ear_deaf || find_trait("Deaf"))
		if (prob(20))
			to_chat(src, "<span class='warning'>You feel the radio vibrate but can hear nothing from it!</span>")
		return
	var/lang_name = speaker.language ? "<span class = 'small_message'>([speaker.language.name])</span> " : ""
	var/khz = ""
	if (destination)
		var/freq_text = istype(destination, /obj/item/weapon/radio) ? (destination:freq) : (destination:freq)
		khz = isnum(freq_text) ? "([freq_text] kHz)" : "([freq_text])"
	var/head = destination ? "[destination.name], <i>[khz]</i>" : "Radio"
	var/full_message = "<font size = 2 color=#FFAE19><b>[head]:</font></b><font size = 2> <b>[speaker.real_name]</b> <span class = 'small_message'>(via [speaker.relay], [speaker.region])</span> [lang_name]\"[message]\"</font>"
	on_hear_radio(destination, full_message)

// One arrival from the agent's inbox: checked field by field, then heard
// through every relay here that shares its key.
/proc/civ_relay_receive(list/envelope)
	if (!islist(envelope))
		return FALSE
	var/key = envelope["key"]
	var/message = envelope["message"]
	var/freq = envelope["frequency"]
	var/source = envelope["source"]
	if (!civ_relay_key_valid(key) || !istext(message) || !length(message) || length(message) > CIV_RELAY_MESSAGE_LIMIT)
		return FALSE
	if (!shard_id_valid(source) || !(source in shard_group.peers))
		return FALSE
	if (isnum(freq))
		if (freq != round(freq) || freq < 150 || freq > 300)
			return FALSE
	else if (!istext(freq) || !length(freq) || length(freq) > 32)
		return FALSE
	var/list/here = list()
	for (var/obj/structure/telecom/relay/R in civ_relay_on_air_list())
		if (R.network_key == key)
			here += R
	if (!here.len)
		return FALSE
	var/obj/structure/telecom/relay/best = here[1]
	for (var/obj/structure/telecom/relay/R in here)
		if (R.condition > best.condition)
			best = R
	var/datum/remote_speaker/S = new
	S.real_name = html_encode(copytext("[envelope["name"]]", 1, 65))
	S.name = S.real_name
	var/list/peer = shard_group.peers[source]
	S.region = html_encode(copytext("[peer["name"]]", 1, 65))
	S.relay = html_encode(copytext("[envelope["relay"]]", 1, 33))
	S.language = civ_relay_language(envelope["language"])
	var/verbage = istext(envelope["verb"]) && length(envelope["verb"]) <= 32 ? html_encode(envelope["verb"]) : "says"
	var/clean = best.garble(html_encode(copytext(message, 1, CIV_RELAY_MESSAGE_LIMIT + 1)))
	civ_relay_log_line("IN", "[envelope["ckey"]] ([S.real_name], [source]) on [key] ([freq]) via [best.name]: \"[clean]\"")
	civ_relay_rebroadcast(freq, S, clean, verbage, best)
	return TRUE

// -- bridge loop ------------------------------------------------------------

// The radio process: once a second it posts queued outbound envelopes, polls
// the agent's inbox while a relay here is on the air, sends the heartbeat
// every minute and refreshes the peer link view. Each request is one
// loopback POST with a five-second deadline. Without a configured transfer
// agent nothing is sent and relays only show "not linked".
/process/civ_radio_relay/setup()
	name = "cross-region radio relay"
	schedule_interval = 1 SECOND
	start_delay = 2 SECONDS
	priority = PROCESS_PRIORITY_LOW
	fires_at_gamestates = list(GAME_STATE_PLAYING)
	processes.civ_radio_relay = src

/process/civ_radio_relay/var/since_heartbeat = CIV_RELAY_HEARTBEAT

/process/civ_radio_relay/fire()
	if (!transfer_bridge.enabled())
		civ_relay_outbound_queue.Cut()
		return
	var/sent = 0
	while (civ_relay_outbound_queue.len && ++sent <= CIV_RELAY_RATE_LIMIT)
		var/list/envelope = civ_relay_outbound_queue[1]
		civ_relay_outbound_queue.Cut(1, 2)
		transfer_bridge.request("/radio/send", list("envelope" = envelope))
	// Group-wide OOC rides the same agent and needs no relay station.
	region_ooc_tick()
	// Orbital strikes aimed at this world (orbit_artillery.dm).
	orbit_artillery_tick()
	var/list/on_air = civ_relay_on_air_list()
	since_heartbeat += 10
	if (since_heartbeat >= CIV_RELAY_HEARTBEAT)
		since_heartbeat = 0
		var/list/relays = list()
		for (var/obj/structure/telecom/relay/R in on_air)
			relays += list(list("key" = R.network_key, "condition" = R.condition))
		transfer_bridge.request("/radio/heartbeat", list("relays" = relays))
		var/list/answer = transfer_bridge.request("/radio/status", list())
		if (islist(answer) && answer["ok"] && islist(answer["result"]) && islist(answer["result"]["peers"]))
			civ_relay_peer_links = answer["result"]["peers"]
	if (!on_air.len)
		return
	var/list/answer = transfer_bridge.request("/radio/inbox", list())
	if (!islist(answer) || !answer["ok"] || !islist(answer["result"]))
		return
	var/list/envelopes = answer["result"]["envelopes"]
	if (!islist(envelopes))
		return
	var/count = 0
	for (var/list/envelope in envelopes)
		if (++count > 50)
			break
		civ_relay_receive(envelope)

/process/civ_radio_relay/reset_current_list()
	return

// -- logs -------------------------------------------------------------------

// Game log (RADIO) and a bounded ring that admins read with view variables
// and agents read with the logs action (kind "radio").
/proc/civ_relay_log_line(direction, text)
	var/line = "[direction] [text]"
	game_log("RADIO", line)
	radio_relay_log += "\[[time_stamp()]\] [line]"
	if (radio_relay_log.len > CIV_RELAY_LOG_LIMIT)
		radio_relay_log.Cut(1, radio_relay_log.len - CIV_RELAY_LOG_LIMIT + 1)

#undef CIV_RELAY_KEY_LIMIT
#undef CIV_RELAY_MESSAGE_LIMIT
#undef CIV_RELAY_GARBLE_BELOW
#undef CIV_RELAY_WEAR_FAIR
#undef CIV_RELAY_WEAR_WET
#undef CIV_RELAY_WEAR_EXTREME
#undef CIV_RELAY_WEAR_SECONDS
#undef CIV_RELAY_REPAIR_ELECTRONICS
#undef CIV_RELAY_REPAIR_COPPER
#undef CIV_RELAY_RATE_LIMIT
#undef CIV_RELAY_RATE_WINDOW
#undef CIV_RELAY_HEARTBEAT
#undef CIV_RELAY_LOG_LIMIT
