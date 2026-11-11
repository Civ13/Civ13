// Group-wide admin chat (ASAY) for a region group (sharded servers). An admin
// chat line said in one region shows to the admins of every other region,
// tagged with the region it came from, like group-wide OOC (region_ooc.dm).
//
// It has its own ring on the transfer agent (/asay/send, /asay/inbox), never
// the OOC ring: an agent or world without admin chat support then drops the
// line instead of showing it to players as OOC.
//
// Discord: the sending world posts the line itself when its webhook is on;
// otherwise the mainland posts it, tagged with its region ("posted" FALSE), so
// CivilizationBot's admin channel sees each line once. Discord admin-channel
// messages reach the mainland only (SQL/discord2admin.txt); it shows them and
// hands them on as "discord" lines that no world posts back to Discord.
#define REGION_ASAY_QUEUE_LIMIT 50
#define REGION_ASAY_SEND_LIMIT 10
#define REGION_ASAY_RECEIVE_LIMIT 50
#define REGION_ASAY_POLL_INTERVAL 30 // deciseconds between inbox polls
#define REGION_ASAY_MAX_AGE 3000 // deciseconds a queued line may wait for the round to start

var/global/list/region_asay_outbound_queue = list()
var/global/region_asay_busy = FALSE
var/global/region_asay_next_poll = 0

// Queues one admin chat line said here (sanitized text, html-safe rank) for the other regions.
/proc/region_asay_outbound(name, speaker_ckey, msg, rank = "")
	if (!istext(name) || !length(name) || !istext(msg) || !length(msg) || !region_ooc_linked())
		return FALSE
	region_asay_outbound_queue += list(list("name" = name, "ckey" = speaker_ckey, "message" = msg, "rank" = rank, "posted" = webhook_enabled(), "queued" = world.time))
	if (region_asay_outbound_queue.len > REGION_ASAY_QUEUE_LIMIT)
		region_asay_outbound_queue.Cut(1, 2)
	return TRUE

// Hands one Discord admin-channel message, already sanitized, on to the other regions.
/proc/region_asay_outbound_discord(sender, msg)
	if (!istext(sender) || !length(sender) || !istext(msg) || !length(msg) || !region_ooc_linked())
		return FALSE
	region_asay_outbound_queue += list(list("name" = sender, "ckey" = "discord", "message" = msg, "rank" = "", "discord" = TRUE, "posted" = TRUE, "queued" = world.time))
	if (region_asay_outbound_queue.len > REGION_ASAY_QUEUE_LIMIT)
		region_asay_outbound_queue.Cut(1, 2)
	return TRUE

// Shows one admin chat line from another region to this world's admins.
// Returns how many admins saw it, or FALSE when it was refused.
/proc/region_asay_receive(list/envelope)
	if (!islist(envelope))
		return FALSE
	var/source = envelope["source"]
	var/name = envelope["name"]
	var/msg = envelope["message"]
	if (!shard_id_valid(source) || source == shard_group.region || !istext(name) || !length(name) || !istext(msg) || !length(msg))
		return FALSE
	// The sender sanitized the line; anything with raw markup did not come from it.
	if (findtext(msg, "<") || findtext(msg, ">"))
		return FALSE
	var/region_name = html_encode(region_ooc_region_name(source))
	name = html_encode(name)
	var/rank = istext(envelope["rank"]) ? html_encode(envelope["rank"]) : ""
	if (envelope["discord"])
		log_discord_asay("\[[region_name]\] [name]: [msg]")
		return admin_say_show(name, msg, "", region_name, TRUE)
	log_admin("ASAY: \[[region_name]\] [name] : [msg]")
	if (!envelope["posted"] && shard_group.region == shard_group.mainland)
		discord_asay_log(name, msg, region_name)
	return admin_say_show(name, msg, rank, region_name)

// Called by the radio process once a second: sends queued lines and shows
// lines from the other regions.
/proc/region_asay_tick()
	if (!region_ooc_linked())
		region_asay_outbound_queue.Cut()
		return
	if (!region_ooc_enabled())
		return // lines said while the world starts wait for the round
	if (region_asay_busy)
		return
	region_asay_busy = TRUE
	. = region_asay_exchange()
	region_asay_busy = FALSE

/proc/region_asay_exchange()
	var/sent = 0
	while (region_asay_outbound_queue.len && ++sent <= REGION_ASAY_SEND_LIMIT)
		var/list/envelope = region_asay_outbound_queue[1]
		region_asay_outbound_queue.Cut(1, 2)
		if (world.time - envelope["queued"] > REGION_ASAY_MAX_AGE)
			continue // waited too long for the round to start
		envelope = envelope.Copy()
		envelope -= "queued"
		if (!transfer_bridge.request("/asay/send", list("envelope" = envelope)))
			return // the agent is not answering; the rest waits for the next tick
	if (world.time < region_asay_next_poll)
		return
	region_asay_next_poll = world.time + REGION_ASAY_POLL_INTERVAL
	var/list/answer = transfer_bridge.request("/asay/inbox", list())
	if (!islist(answer) || !answer["ok"] || !islist(answer["result"]) || !islist(answer["result"]["envelopes"]))
		return
	var/count = 0
	for (var/list/envelope in answer["result"]["envelopes"])
		if (++count > REGION_ASAY_RECEIVE_LIMIT)
			break
		region_asay_receive(envelope)

#undef REGION_ASAY_QUEUE_LIMIT
#undef REGION_ASAY_SEND_LIMIT
#undef REGION_ASAY_RECEIVE_LIMIT
#undef REGION_ASAY_POLL_INTERVAL
#undef REGION_ASAY_MAX_AGE
