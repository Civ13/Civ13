// Group-wide OOC chat for a region group (sharded servers). An OOC line said
// in one region shows in every other region of the group, tagged with the
// region it came from. IC speech and radio stay local; radio crosses regions
// only through relay stations (radio_relay.dm).
//
// The sending world applies its own mutes, bans, spam and advertising checks
// and posts the line to Discord (webhook and ooc.log) when its own webhook is
// on. CivilizationBot knows one game server per group, so usually only the
// mainland has a webhook: a line from a region without one ("posted" FALSE)
// is posted by the mainland instead, tagged with its region, and by no other
// world, so the bot sees each line once (Rail Yard, 2026-11-08). A receiving
// world shows it to its clients with OOC enabled, unless OOC is globally muted
// here or the speaker holds an OOC ban in this world's ban list too.
//
// Discord OOC: CivilizationBot writes Discord messages to SQL/discord2ooc.txt
// of one world only (the mainland). That world shows them and hands them on as
// "discord" envelopes, which every other region shows with the Discord tag and
// never posts back to Discord (Val, 2026-11-08).
//
// Transport is the region's transfer agent (tools/transfer_storage/radio.py,
// /ooc/send and /ooc/inbox). The radio process sends queued lines once a
// second and polls the inbox every few seconds, never while an earlier OOC
// call is still waiting on the agent. Off unless the world is in a region
// group and has a transfer agent.
#define REGION_OOC_QUEUE_LIMIT 50
#define REGION_OOC_SEND_LIMIT 10
#define REGION_OOC_RECEIVE_LIMIT 50
#define REGION_OOC_POLL_INTERVAL 30 // deciseconds between inbox polls

var/global/list/region_ooc_outbound_queue = list()
var/global/region_ooc_busy = FALSE
var/global/region_ooc_next_poll = 0

/proc/region_ooc_enabled()
	return shard_group && shard_group.enabled && transfer_bridge && transfer_bridge.enabled() && ticker && ticker.current_state == GAME_STATE_PLAYING

// Queues one OOC line said here for the other regions. msg is the sanitized
// text before mention highlighting; each region highlights its own clients.
/proc/region_ooc_outbound(client/speaker, msg, style)
	if (!speaker)
		return FALSE
	var/rank = ""
	var/fakekey = ""
	var/datum/admins/holder = speaker.holder
	if (holder && holder.rank != "HHost")
		if (holder.fakekey)
			fakekey = "[holder.fakekey]"
		else
			rank = "[holder.OOC_rank()]"
	return region_ooc_outbound_line(speaker.key, speaker.ckey, msg, style, rank, fakekey)

/proc/region_ooc_outbound_line(name, speaker_ckey, msg, style, rank = "", fakekey = "")
	if (!istext(name) || !length(name) || !istext(msg) || !length(msg) || !region_ooc_enabled())
		return FALSE
	region_ooc_outbound_queue += list(list("name" = name, "ckey" = speaker_ckey, "message" = msg, "style" = style, "rank" = rank, "fakekey" = fakekey, "posted" = webhook_enabled()))
	if (region_ooc_outbound_queue.len > REGION_OOC_QUEUE_LIMIT)
		region_ooc_outbound_queue.Cut(1, 2)
	return TRUE

// An OOC line from a server agent's character (agent control, scope ooc): shown
// here, posted to Discord like a player's line and sent to the other regions, so
// an agent can check the whole OOC path (Val, 2026-11-08). name is shown as is.
/proc/agent_ooc_say(name, speaker_ckey, msg)
	if (!config.ooc_allowed)
		return FALSE
	name = sanitize(copytext_char(name, 1, 46), 0)
	msg = sanitize(msg)
	if (!name || !msg)
		return FALSE
	log_ooc("[name] : [msg]")
	webhook_send_ooc(speaker_ckey, "__**\[[time_stamp()]] ([map.ID]) OOC:**__ **[name]:** [msg]")
	discord_log("[name]:", "[msg]")
	var/shown = ooc_ping_clients(msg)
	for (var/client/target in clients)
		if (target.is_preference_enabled(/datum/client_preference/show_ooc))
			to_chat(target, "<span class='ooc'><span class='everyone'>" + create_text_tag("ooc", "OOC:", target) + " <EM>[name]:</EM> <span class='message'>[shown]</span></span></span>")
	region_ooc_outbound_line(name, speaker_ckey, msg, "everyone")
	return TRUE

// Hands one Discord message, already sanitized, on to the other regions.
/proc/region_ooc_outbound_discord(sender, msg)
	if (!istext(sender) || !length(sender) || !istext(msg) || !length(msg) || !region_ooc_enabled())
		return FALSE
	region_ooc_outbound_queue += list(list("name" = sender, "ckey" = "discord", "message" = msg, "style" = "everyone", "discord" = TRUE, "posted" = TRUE))
	if (region_ooc_outbound_queue.len > REGION_OOC_QUEUE_LIMIT)
		region_ooc_outbound_queue.Cut(1, 2)
	return TRUE

// Shows one Discord message (sanitized sender and text) to this world's clients with OOC on.
/proc/discord_ooc_show(sender, msg)
	var/dmsg = "<IMG src='\ref[text_tag_icons]' class='text_tag' iconstate='discord' alt='Discord'><b><font color='#31A8DE'>[sender]: [msg]</font></b>"
	log_discord(dmsg)
	if (!config.ooc_allowed)
		return FALSE // OOC is globally muted
	for (var/client/C in clients)
		if (C.is_preference_enabled(/datum/client_preference/show_ooc))
			to_chat(C, dmsg)
	return TRUE

// Highlights @key and @ckey mentions of clients in this world and pings them.
/proc/ooc_ping_clients(msg)
	for (var/client/C in clients)
		if (C.pingability)
			var/imsg = msg
			msg = replacetext(msg, "@[C.key]", "<span class='ping'>@[capitalize(C.key)]</span>")
			msg = replacetext(msg, "@[C.ckey]", "<span class='ping'>@[capitalize(C.key)]</span>")
			if (msg != imsg)
				winset(C, "mainwindow", "flash=2;")
				C << sound('sound/machines/ping.ogg')
	return msg

// TRUE when this world's ban list holds an active ban of that type for the key.
/proc/region_ooc_ckey_banned(ckey, ban_type = "OOC")
	if (!istext(ckey) || !fexists("SQL/bans.txt"))
		return FALSE
	for (var/line in splittext(file2text("SQL/bans.txt"), "|||\n"))
		if (!findtext(line, ";"))
			continue
		var/list/fields = splittext(line, ";")
		if (fields.len >= 9 && fields[9] == ckey && fields[1] == ban_type && fields[2] == "nil" && text2num(fields[7]) > world.realtime)
			return TRUE
	return FALSE

/proc/region_ooc_region_name(id)
	var/list/peer = shard_group.peers[id]
	if (islist(peer) && istext(peer["name"]))
		return peer["name"]
	return id

// Shows one OOC line from another region. Returns TRUE when it was shown.
/proc/region_ooc_receive(list/envelope)
	if (!islist(envelope))
		return FALSE
	var/source = envelope["source"]
	var/speaker_ckey = envelope["ckey"]
	var/name = envelope["name"]
	var/msg = envelope["message"]
	var/style = envelope["style"]
	if (!shard_id_valid(source) || source == shard_group.region || !istext(speaker_ckey) || !istext(name) || !istext(msg) || !length(msg))
		return FALSE
	// The sender sanitized the line; anything with raw markup did not come from it.
	if (findtext(msg, "<") || findtext(msg, ">"))
		return FALSE
	if (!(style in list("everyone", "elevated", "mentor", "moderator", "developer", "admin", "highstaff")))
		style = "everyone"
	// From Discord through the mainland: already on Discord, and its sender is no ckey.
	if (envelope["discord"])
		if (findtext(name, "<") || findtext(name, ">"))
			return FALSE
		return discord_ooc_show(name, msg)
	if (region_ooc_ckey_banned(ckey(speaker_ckey)))
		return FALSE
	var/region_name = html_encode(region_ooc_region_name(source))
	name = html_encode(name)
	// Before the mute check: a mute here hides the line here, not on Discord.
	if (!envelope["posted"] && shard_group.region == shard_group.mainland)
		region_ooc_post_to_discord(region_name, name, msg)
	if (!config.ooc_allowed && style == "everyone")
		return FALSE
	var/rank = istext(envelope["rank"]) ? html_encode(envelope["rank"]) : ""
	var/fakekey = istext(envelope["fakekey"]) ? html_encode(envelope["fakekey"]) : ""
	log_ooc("\[[region_name]\] [name] : [msg]")
	msg = ooc_ping_clients(msg)
	for (var/client/target in clients)
		if (!target.is_preference_enabled(/datum/client_preference/show_ooc))
			continue
		var/display_name = name
		if (length(fakekey))
			display_name = target.holder ? "[fakekey]/([name])" : fakekey
		else if (length(rank))
			display_name = "<span class = 'ping'>[rank]</span> [name]"
		to_chat(target, "<span class='ooc'><span class='[style]'>" + create_text_tag("ooc", "OOC:", target) + " <small>\[[region_name]\]</small> <EM>[display_name]:</EM> <span class='message'>[msg]</span></span></span>")
	return TRUE

// The mainland posts a line from a region without its own webhook, in the
// format the OOC verb uses, with the region name where the map ID would be.
/proc/region_ooc_post_to_discord(region_name, name, msg)
	var/line = "__**\[[time_stamp()]] ([region_name]) OOC:**__ **[name]:** [msg]"
	webhook_send_ooc(name, line)
	var/oocdiary = file("ooc.log")
	oocdiary << line
	return TRUE

// Called by the radio process once a second: posts queued lines and shows
// lines from the other regions.
/proc/region_ooc_tick()
	if (!region_ooc_enabled())
		region_ooc_outbound_queue.Cut()
		return
	if (region_ooc_busy)
		return
	region_ooc_busy = TRUE
	. = region_ooc_exchange()
	region_ooc_busy = FALSE

/proc/region_ooc_exchange()
	var/sent = 0
	while (region_ooc_outbound_queue.len && ++sent <= REGION_OOC_SEND_LIMIT)
		var/list/envelope = region_ooc_outbound_queue[1]
		region_ooc_outbound_queue.Cut(1, 2)
		if (!transfer_bridge.request("/ooc/send", list("envelope" = envelope)))
			return // the agent is not answering; the rest waits for the next tick
	if (world.time < region_ooc_next_poll)
		return
	region_ooc_next_poll = world.time + REGION_OOC_POLL_INTERVAL
	var/list/answer = transfer_bridge.request("/ooc/inbox", list())
	if (!islist(answer) || !answer["ok"] || !islist(answer["result"]) || !islist(answer["result"]["envelopes"]))
		return
	var/count = 0
	for (var/list/envelope in answer["result"]["envelopes"])
		if (++count > REGION_OOC_RECEIVE_LIMIT)
			break
		region_ooc_receive(envelope)

#undef REGION_OOC_QUEUE_LIMIT
#undef REGION_OOC_SEND_LIMIT
#undef REGION_OOC_RECEIVE_LIMIT
#undef REGION_OOC_POLL_INTERVAL
