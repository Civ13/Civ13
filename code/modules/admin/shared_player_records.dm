// Shared player records: staff records about an account (admin notes,
// warnings, bans, watch flags, memos, and later karma and lifetime points),
// the same on every region of a shard group.
//
// A record made here gets its own id, goes into this region's journal
// (data/player_records.json) at once, and is sent to the region's transfer
// agent (/record). The coordinator stores it in the group table
// (tools/transfer_storage/records.py) and publishes read-only files beside
// the regions, which every world reads:
//
//   ../shared-records/index.json                 per-ckey summary (counts, watch, active bans, playtime)
//   ../shared-records/bans.json                  every active ban
//   ../shared-records/players/<k>/<ckey>.json    every record about one ckey
//
// Records are never edited in place: removing one appends a "revoke" record.
// While the agent or the coordinator is down this world keeps reading the last
// files and its own journal, so a record made here applies here at once and
// reaches the other regions when they are back. A server outside a shard group
// keeps every record in its journal (local mode).
//
// Entry points for other features:
//   shared_records.add(ckey, kind, body, author, rank)   -> the record, or null
//   shared_records.revoke(record, author, rank, reason)  -> the revoke record, or null
//   shared_records.summary(ckey)        -> list("notes", "warnings", "watch", "bans", "hours", "kinds")
//   shared_records.records_for(ckey)    -> every record about ckey, revoked ones marked "revoked"
//   shared_records.active_bans(ckey, scope) -> active bans of one scope ("game", "ooc", "job"; "any": every scope)
//   shared_records.playtime_hours(ckey) -> hours connected with the character alive and awake
//   shared_records.account_ckey(account) -> the ckey of a Discord account key (d:<id>), or null
#define SHARED_RECORDS_JOURNAL "data/player_records.json"
#define SHARED_RECORDS_READ_INTERVAL 100 // deciseconds between snapshot reads
#define SHARED_RECORDS_SEND_LIMIT 10 // records sent per tick
#define SHARED_RECORDS_MAX_BODY 16000 // characters of JSON in one record body
#define SHARED_RECORDS_UNIX_2000 946684800

var/global/datum/shared_records/shared_records = new

/datum/shared_records
	var/list/journal = null // record lists made here and not yet in the snapshot
	var/index_text = null
	var/list/index = list()
	var/bans_text = null
	var/list/bans = list()
	var/next_read = 0
	var/busy = FALSE
	var/serial = 0
	var/hold_save = FALSE // TRUE while many records are added at once; the caller saves
	var/migrated = FALSE

// The folder the coordinator writes, beside the region folders.
/datum/shared_records/proc/root()
	if (shard_group && shard_group.enabled)
		return "../shared-records/"
	return "data/shared-records/"

// This world's region name in records; "local" outside a shard group.
/datum/shared_records/proc/region()
	if (shard_group && shard_group.enabled && shard_id_valid(shard_group.region))
		return shard_group.region
	return "local"

// Whether records leave this world: a shard group with a transfer agent.
/datum/shared_records/proc/linked()
	return shard_group && shard_group.enabled && transfer_bridge && transfer_bridge.enabled()

// Unix times are digit strings here: a DM number is a 32-bit float, which
// near 1.8e9 only holds every 128th second, and json_encode would write it
// with six significant digits. The snapshot files use digit strings too.
/datum/shared_records/proc/now_unix()
	var/stamp = rustg_unix_timestamp()
	if (istext(stamp))
		var/dot = findtext(stamp, ".")
		if (dot)
			stamp = copytext(stamp, 1, dot)
		if (unix_valid(stamp))
			return stamp
	// Without rust_g: about two minutes coarse, which only delays dropping sent records.
	return num2text(round(world.realtime / 10) + SHARED_RECORDS_UNIX_2000, 12)

/datum/shared_records/proc/unix_valid(value)
	var/regex/shape = regex("^\[0-9]{1,12}$")
	return istext(value) && shape.Find(value)

// A time as a digit string: text stays, a number (an old or hand-written
// file) is converted, anything else is "0".
/datum/shared_records/proc/unix_value(value)
	if (unix_valid(value))
		return value
	if (isnum(value) && value >= 0)
		return num2text(round(value), 12)
	return "0"

// TRUE when time a is later than time b.
/datum/shared_records/proc/unix_after(a, b)
	a = unix_value(a)
	b = unix_value(b)
	while (length(a) > 1 && copytext(a, 1, 2) == "0")
		a = copytext(a, 2)
	while (length(b) > 1 && copytext(b, 1, 2) == "0")
		b = copytext(b, 2)
	if (length(a) != length(b))
		return length(a) > length(b)
	return sorttext(a, b) < 0

// Time a plus seconds (whole, 0 or more), exactly.
/datum/shared_records/proc/unix_add(a, seconds)
	a = unix_value(a)
	seconds = max(0, round(seconds))
	while (length(a) < 6)
		a = "0[a]"
	var/high = text2num(copytext(a, 1, length(a) - 4)) + round(seconds / 100000)
	var/low = text2num(copytext(a, length(a) - 4)) + seconds % 100000
	if (low >= 100000)
		high += round(low / 100000)
		low = low % 100000
	var/low_text = num2text(low, 6)
	while (length(low_text) < 5)
		low_text = "0[low_text]"
	if (!high)
		return num2text(low, 6)
	return "[num2text(high, 12)][low_text]"

/datum/shared_records/proc/new_id(ckey, kind)
	return md5("[region()]-[ckey]-[kind]-[world.realtime]-[world.timeofday]-[rand(1, 1000000000)]-[++serial]")

/datum/shared_records/proc/kind_valid(kind)
	var/regex/shape = regex("^\[a-z]\[a-z0-9_]{0,31}$")
	return istext(kind) && shape.Find(kind)

/datum/shared_records/proc/id_valid(id)
	var/regex/shape = regex("^\[0-9a-f]{32}$")
	return istext(id) && shape.Find(id)

// -- journal ------------------------------------------------------------------

/datum/shared_records/proc/load_journal()
	if (islist(journal))
		return journal
	journal = list()
	if (fexists(SHARED_RECORDS_JOURNAL))
		var/list/saved = null
		try
			saved = json_decode(file2text(SHARED_RECORDS_JOURNAL))
		catch
			saved = null
		if (islist(saved))
			for (var/list/record in saved)
				if (islist(record) && id_valid(record["id"]))
					journal += list(record)
	return journal

// Written whole: a temporary file first, then copied over the journal.
/datum/shared_records/proc/save_journal()
	var/temp = "[SHARED_RECORDS_JOURNAL].tmp"
	if (fexists(temp))
		fdel(temp)
	text2file(json_encode(load_journal()), temp)
	if (fcopy(temp, SHARED_RECORDS_JOURNAL))
		fdel(temp)
	else
		log_admin("Shared player records: could not write [SHARED_RECORDS_JOURNAL].")

// -- writing ------------------------------------------------------------------

// Makes one record about ckey. author is the staff member's ckey ("" for the
// server), rank their rank. id is only for records copied from old files, so a
// copy made on several regions is stored once. Returns the record, or null.
/datum/shared_records/proc/add(ckey, kind, list/body, author = "", rank = "", id = null)
	ckey = ckey(ckey)
	if (!length(ckey) || length(ckey) > 32 || !kind_valid(kind))
		return null
	if (!islist(body))
		body = list()
	var/body_text = json_encode(body)
	if (length(body_text) > SHARED_RECORDS_MAX_BODY)
		return null
	if (kind == "ban")
		if (!(body["scope"] in list("game", "ooc", "job")))
			return null
		body["until"] = unix_value(body["until"]) // "0": never ends
	if (kind == "revoke" && !id_valid(body["target"]))
		return null
	if (isnull(id))
		id = new_id(ckey, kind)
	if (!id_valid(id))
		return null
	author = istext(author) ? ckey(author) : ""
	rank = istext(rank) ? copytext(rank, 1, 65) : ""
	for (var/list/existing in load_journal())
		if (existing["id"] == id)
			return existing
	var/list/record = list("id" = id, "ckey" = ckey, "kind" = kind, "author" = author, "rank" = rank,
		"region" = region(), "at" = now_unix(), "body" = body, "sent" = 0)
	journal += list(record)
	if (!hold_save)
		save_journal()
	return record

// Revokes a record (from records_for() or add()). Returns the revoke record.
/datum/shared_records/proc/revoke(list/target, author = "", rank = "", reason = "")
	if (!islist(target) || !id_valid(target["id"]) || target["kind"] == "revoke")
		return null
	var/list/body = list("target" = target["id"], "target_kind" = target["kind"])
	if (istext(reason) && length(reason))
		body["reason"] = copytext(reason, 1, 1025)
	return add(target["ckey"], "revoke", body, author, rank)

// -- reading ------------------------------------------------------------------

/datum/shared_records/proc/read_json(path)
	if (!fexists(path))
		return null
	try
		return file2text(path)
	catch
		return null

// Re-reads the snapshot files when they changed, and drops journal records the
// snapshot now holds: those sent before the coordinator last emptied this
// region's queue.
/datum/shared_records/proc/refresh(force = FALSE)
	if (!force && world.time < next_read)
		return
	next_read = world.time + SHARED_RECORDS_READ_INTERVAL
	if (!migrated)
		migrated = TRUE
		legacy_notes_migrate()
	var/text = read_json("[root()]index.json")
	if (istext(text) && text != index_text)
		var/list/decoded = null
		try
			decoded = json_decode(text)
		catch
			decoded = null
		if (islist(decoded) && islist(decoded["players"]))
			index_text = text
			index = decoded
	text = read_json("[root()]bans.json")
	if (istext(text) && text != bans_text)
		var/list/decoded = null
		try
			decoded = json_decode(text)
		catch
			decoded = null
		if (islist(decoded) && islist(decoded["bans"]))
			bans_text = text
			bans = decoded["bans"]
	var/list/pulled = islist(index["pulled"]) ? index["pulled"] : list()
	var/pull = pulled[region()]
	if (!unix_valid(pull) || !length(load_journal()))
		return
	var/changed = FALSE
	for (var/list/record in journal.Copy())
		if (unix_valid(record["sent"]) && unix_after(pull, record["sent"]))
			journal -= list(record)
			changed = TRUE
	if (changed)
		save_journal()

// Called once a second by the cross-region radio process: sends journal
// records the agent does not have yet, and re-reads the snapshot files.
/datum/shared_records/proc/tick()
	refresh()
	if (busy || !linked())
		return
	busy = TRUE
	. = send()
	busy = FALSE

/datum/shared_records/proc/send()
	var/sent = 0
	var/changed = FALSE
	for (var/list/record in load_journal())
		if (record["sent"])
			continue
		if (++sent > SHARED_RECORDS_SEND_LIMIT)
			break
		var/list/outgoing = record.Copy()
		outgoing -= "sent"
		var/list/answer = transfer_bridge.request("/record", list("records" = list(outgoing)))
		if (!islist(answer))
			break // the agent is not answering; try again next tick
		if (!answer["ok"])
			// Refused (a malformed record): it would block every later one.
			log_admin("Shared player records: the agent refused record [record["id"]] ([answer["error"]]); kept here only.")
			record["sent"] = -1
			changed = TRUE
			continue
		// Stamped after the agent has it, rounded up, so a coordinator pull
		// later than this second has certainly collected it.
		record["sent"] = unix_add(now_unix(), 1)
		changed = TRUE
	if (changed)
		save_journal()
	return sent

// Journal records about ckey (not yet in the snapshot), oldest first.
/datum/shared_records/proc/pending_for(ckey)
	. = list()
	for (var/list/record in load_journal())
		if (record["ckey"] == ckey)
			. += list(record)

// The ids revoked by journal records.
/datum/shared_records/proc/pending_revokes()
	. = list()
	for (var/list/record in load_journal())
		var/list/body = record["body"]
		if (record["kind"] == "revoke" && islist(body))
			.[body["target"]] = record

/datum/shared_records/proc/summary(ckey)
	ckey = ckey(ckey)
	refresh()
	var/list/players = islist(index["players"]) ? index["players"] : list()
	var/list/known = islist(players[ckey]) ? players[ckey] : list()
	var/list/known_kinds = known["kinds"]
	var/list/kinds = islist(known_kinds) ? known_kinds.Copy() : list()
	var/list/result = list("notes" = isnum(known["notes"]) ? known["notes"] : 0,
		"warnings" = isnum(known["warnings"]) ? known["warnings"] : 0,
		"watch" = known["watch"] ? TRUE : FALSE,
		"bans" = active_bans(ckey),
		"hours" = isnum(known["hours"]) ? known["hours"] : 0,
		"kinds" = kinds)
	var/list/revoked = pending_revokes()
	for (var/list/record in pending_for(ckey))
		var/kind = record["kind"]
		var/delta = 1
		if (kind == "revoke")
			var/list/revoke_body = record["body"]
			kind = revoke_body["target_kind"]
			delta = -1
		else if (record["id"] in revoked)
			continue // made and revoked before the snapshot caught up
		if (!istext(kind))
			continue
		kinds[kind] = max(0, (isnum(kinds[kind]) ? kinds[kind] : 0) + delta)
		switch (kind)
			if ("note")
				result["notes"] = max(0, result["notes"] + delta)
			if ("warning")
				result["warnings"] = max(0, result["warnings"] + delta)
			if ("watch")
				result["watch"] = delta > 0
			if ("unwatch")
				if (delta > 0)
					result["watch"] = FALSE
	return result

/datum/shared_records/proc/records_for(ckey)
	ckey = ckey(ckey)
	. = list()
	var/text = read_json("[root()]players/[copytext(ckey, 1, 2)]/[ckey].json")
	if (istext(text))
		var/list/decoded = null
		try
			decoded = json_decode(text)
		catch
			decoded = null
		if (islist(decoded) && islist(decoded["records"]))
			for (var/list/record in decoded["records"])
				if (islist(record))
					. += list(record)
	var/list/seen = list()
	for (var/list/record in .)
		seen[record["id"]] = record
	for (var/list/record in pending_for(ckey))
		if (!seen[record["id"]])
			. += list(record)
			seen[record["id"]] = record
	var/list/revokes = pending_revokes()
	for (var/target in revokes)
		var/list/record = seen[target]
		if (islist(record) && !record["revoked"])
			var/list/revoke = revokes[target]
			var/list/revoke_body = revoke["body"]
			record["revoked"] = list("id" = revoke["id"], "by" = revoke["author"], "at" = revoke["at"],
				"region" = revoke["region"], "reason" = revoke_body["reason"])

/datum/shared_records/proc/active_bans(ckey, scope = "game")
	ckey = ckey(ckey)
	refresh()
	. = list()
	var/now = now_unix()
	var/list/revoked = pending_revokes()
	var/list/candidates = list()
	for (var/list/ban in bans)
		if (islist(ban) && ban["ckey"] == ckey)
			candidates += list(ban)
	for (var/list/record in pending_for(ckey))
		var/list/ban_body = record["body"]
		if (record["kind"] == "ban" && islist(ban_body))
			var/list/ban = ban_body.Copy()
			ban["id"] = record["id"]
			ban["ckey"] = record["ckey"]
			ban["author"] = record["author"]
			ban["region"] = record["region"]
			ban["at"] = record["at"]
			candidates += list(ban)
	for (var/list/ban in candidates)
		if (ban["id"] in revoked)
			continue
		if (scope != "any" && ban["scope"] != scope)
			continue
		var/until = unix_value(ban["until"])
		if (until != "0" && !unix_after(until, now))
			continue // a temporary ban ends on its own
		. += list(ban)

// Every ckey with at least one active record of the given kinds, sorted.
/datum/shared_records/proc/ckeys_with(list/kinds)
	refresh()
	var/list/found = list()
	var/list/players = islist(index["players"]) ? index["players"] : list()
	for (var/ckey in players)
		var/list/known = players[ckey]
		var/list/counts = islist(known) ? known["kinds"] : null
		if (!islist(counts))
			continue
		for (var/kind in kinds)
			if (counts[kind] > 0)
				found[ckey] = TRUE
				break
	for (var/list/record in load_journal())
		if (record["kind"] in kinds)
			found[record["ckey"]] = TRUE
	. = list()
	for (var/ckey in found)
		. += ckey
	return sortList(.)

// A record's time as text, in the host's time zone.
/datum/shared_records/proc/time_text(at, format = "YYYY-MM-DD hh:mm")
	var/seconds = text2num(unix_value(at)) - SHARED_RECORDS_UNIX_2000
	if (seconds <= 0)
		return "unknown"
	return time2text(seconds * 10, format)

/datum/shared_records/proc/watched(ckey)
	return summary(ckey)["watch"]

/datum/shared_records/proc/playtime_hours(ckey)
	ckey = ckey(ckey)
	refresh()
	var/list/players = islist(index["players"]) ? index["players"] : list()
	var/list/known = players[ckey]
	return islist(known) && isnum(known["hours"]) ? known["hours"] : 0

/datum/shared_records/proc/account_ckey(account)
	if (!istext(account))
		return null
	refresh()
	var/list/accounts = islist(index["accounts"]) ? index["accounts"] : list()
	var/found = accounts[account]
	return istext(found) ? found : null

#undef SHARED_RECORDS_JOURNAL
#undef SHARED_RECORDS_READ_INTERVAL
#undef SHARED_RECORDS_SEND_LIMIT
#undef SHARED_RECORDS_MAX_BODY
#undef SHARED_RECORDS_UNIX_2000
