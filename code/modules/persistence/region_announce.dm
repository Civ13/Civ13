// Group-wide admin announcements for a region group (sharded servers).
// "Announce (All Regions)" shows the announcement here, exactly like Announce,
// and hands it to every other region of the group, whose players see the same
// announcement. Announce itself stays local to this world.
//
// It has its own ring on the transfer agent (/announce/send, /announce/inbox),
// like admin chat (region_asay.dm). Delivery is ephemeral: a region whose world
// is down, asleep or still loading when the line arrives does not get it (the
// agent keeps it for about 30 seconds). An announcement made before this
// world's round is playing waits here until it is, up to REGION_ANNOUNCE_MAX_AGE.
#define REGION_ANNOUNCE_QUEUE_LIMIT 20
#define REGION_ANNOUNCE_SEND_LIMIT 5
#define REGION_ANNOUNCE_RECEIVE_LIMIT 20
#define REGION_ANNOUNCE_POLL_INTERVAL 30 // deciseconds between inbox polls
#define REGION_ANNOUNCE_MAX_AGE 3000 // deciseconds a queued announcement may wait for the round to start

var/global/list/region_announce_outbound_queue = list()
var/global/region_announce_busy = FALSE
var/global/region_announce_next_poll = 0

// Shows one admin announcement to every player here, in the Announce style.
// name and msg are already html-safe; newlines in msg become line breaks.
/proc/admin_announce_show(name, msg)
	if (!istext(name) || !length(name) || !istext(msg) || !length(msg))
		return FALSE
	msg = replacetext(msg, "\n", "<br>") // required since we're putting it in a <p> tag
	to_chat(world, "<big><span class=notice><b>[name] Announces:</b></big><p style='text-indent: 50px'>[msg]</p></span>")
	return TRUE

// Queues one announcement made here (sanitized text) for the other regions.
/proc/region_announce_outbound(name, speaker_ckey, msg)
	if (!istext(name) || !length(name) || !istext(msg) || !length(msg) || !region_ooc_linked())
		return FALSE
	region_announce_outbound_queue += list(list("name" = name, "ckey" = speaker_ckey, "message" = msg, "queued" = world.time))
	if (region_announce_outbound_queue.len > REGION_ANNOUNCE_QUEUE_LIMIT)
		region_announce_outbound_queue.Cut(1, 2)
	return TRUE

// Shows one announcement from another region to every player here.
/proc/region_announce_receive(list/envelope)
	if (!islist(envelope))
		return FALSE
	var/source = envelope["source"]
	var/name = envelope["name"]
	var/msg = envelope["message"]
	if (!shard_id_valid(source) || source == shard_group.region || !istext(name) || !length(name) || !istext(msg) || !length(msg))
		return FALSE
	// The sender sanitized the text; anything with raw markup did not come from it.
	if (findtext(msg, "<") || findtext(msg, ">"))
		return FALSE
	var/region_name = region_ooc_region_name(source)
	log_admin("Announce (All Regions): \[[region_name]\] [envelope["ckey"]] as [name] : [msg]")
	return admin_announce_show(html_encode(name), msg)

// Called by the radio process once a second: sends queued announcements and
// shows those from the other regions.
/proc/region_announce_tick()
	if (!region_ooc_linked())
		region_announce_outbound_queue.Cut()
		return
	if (!region_ooc_enabled())
		return // announcements made while the world starts wait for the round
	if (region_announce_busy)
		return
	region_announce_busy = TRUE
	. = region_announce_exchange()
	region_announce_busy = FALSE

/proc/region_announce_exchange()
	var/sent = 0
	while (region_announce_outbound_queue.len && ++sent <= REGION_ANNOUNCE_SEND_LIMIT)
		var/list/queued = region_announce_outbound_queue[1]
		if (world.time - queued["queued"] > REGION_ANNOUNCE_MAX_AGE)
			region_announce_outbound_queue.Cut(1, 2)
			continue // waited too long (round start or a silent agent)
		var/list/envelope = queued.Copy()
		envelope -= "queued"
		if (!transfer_bridge.request("/announce/send", list("envelope" = envelope)))
			return // the agent is not answering; it stays queued for the next tick
		region_announce_outbound_queue.Cut(1, 2)
	if (world.time < region_announce_next_poll)
		return
	region_announce_next_poll = world.time + REGION_ANNOUNCE_POLL_INTERVAL
	var/list/answer = transfer_bridge.request("/announce/inbox", list())
	if (!islist(answer) || !answer["ok"] || !islist(answer["result"]) || !islist(answer["result"]["envelopes"]))
		return
	var/count = 0
	for (var/list/envelope in answer["result"]["envelopes"])
		if (++count > REGION_ANNOUNCE_RECEIVE_LIMIT)
			break
		region_announce_receive(envelope)

#undef REGION_ANNOUNCE_QUEUE_LIMIT
#undef REGION_ANNOUNCE_SEND_LIMIT
#undef REGION_ANNOUNCE_RECEIVE_LIMIT
#undef REGION_ANNOUNCE_POLL_INTERVAL
#undef REGION_ANNOUNCE_MAX_AGE
