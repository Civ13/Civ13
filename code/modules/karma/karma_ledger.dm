// Hidden karma: how players remember each other, and how staff rate them.
// Staff only: no player ever sees a karma value, a rating or who gave it.
//
// Karma is a set of record kinds in the shared player records store
// (code/modules/admin/shared_player_records.dm), tied to ckeys, so it is the
// same on every region and survives characters and deaths:
//
//   karma_rating    about the rated ckey; body giver, rating (kindly|poorly), note, faction, shared_cid.
//                   A giver's latest rating of a ckey replaces their earlier ones; revoking
//                   that latest one leaves the pair with none.
//   karma_standing  about a ckey; body value (-2..2), reason. Set by staff; the latest counts.
//   karma_bar       about a ckey; body reason. That ckey may not give karma until it is revoked.
//
// Removing a rating or a bar revokes its record. The weights match
// tools/transfer_storage/karma.py, which writes shared-records/karma/<ckey>.json
// for the giver lists and the Discord bot; the dossier here is computed live so
// it also covers records not yet synced and servers outside a shard group.
//
// Entry points:
//   karma_rate(giver, target, rating, note, faction, shared_cid) -> the record, or a refusal text
//   karma_set_standing(ckey, value, reason, author, rank)       -> the record, or null
//   karma_set_bar(ckey, barred, reason, author, rank)           -> TRUE when changed
//   karma_standing(ckey)   -> list(value, reason, author, at), or null
//   karma_barred(ckey)     -> TRUE when the ckey may not give karma
//   karma_received(ckey)   -> giver -> that giver's live rating record
//   karma_given(ckey)      -> target -> rating, from the coordinator's file and this world's journal
//   karma_dossier(ckey)    -> list(ckey, standing, barred, hours, summary, ratings) with weights and flags
#define KARMA_NOTE_LIMIT 1000
#define KARMA_FULL_WEIGHT_HOURS 100
#define KARMA_PLAYTIME_FLOOR 0.05
#define KARMA_AGE_SECONDS 7776000 // 90 days
#define KARMA_AGE_FACTOR 0.5
#define KARMA_LOW_WEIGHT 0.25
#define KARMA_BURST_SECONDS 3600
#define KARMA_BURST_COUNT 3
#define KARMA_DERIVED_MARGIN 3

/proc/karma_standing_factor(value)
	switch (value)
		if (2)
			return 1.5
		if (1)
			return 1.2
		if (-1)
			return 0.25
		if (-2)
			return 0
	return 1

/proc/karma_standing_name(value)
	switch (value)
		if (2)
			return "trusted"
		if (1)
			return "good"
		if (0)
			return "neutral"
		if (-1)
			return "poor"
		if (-2)
			return "bad"
	return "unknown"

/proc/karma_playtime_factor(hours)
	if (!isnum(hours))
		hours = 0
	return max(KARMA_PLAYTIME_FLOOR, min(1, hours / KARMA_FULL_WEIGHT_HOURS))

/proc/karma_age_factor(at, now)
	return (now - at) <= KARMA_AGE_SECONDS ? 1 : KARMA_AGE_FACTOR

/proc/karma_live_records(ckey, kind)
	. = list()
	for (var/list/record in shared_records.records_for(ckey))
		if (record["kind"] == kind && !record["revoked"] && islist(record["body"]))
			. += list(record)

// -- writing ------------------------------------------------------------------

// A giver remembers a target kindly or poorly. Returns the record, or a text
// saying why not (shown to the giver). The callers check sight and verification.
/proc/karma_rate(giver, target, rating, note = "", faction = "", shared_cid = FALSE)
	giver = ckey(giver)
	target = ckey(target)
	if (!length(giver) || !length(target))
		return "That player cannot be remembered."
	if (giver == target)
		return "You cannot remember yourself."
	if (!(rating in list("kindly", "poorly")))
		return "Choose kindly or poorly."
	if (karma_barred(giver))
		return "You cannot do that."
	var/list/body = list("giver" = giver, "rating" = rating)
	if (istext(note) && length(note))
		body["note"] = copytext(sanitize(note), 1, KARMA_NOTE_LIMIT + 1)
	if (istext(faction) && length(faction))
		body["faction"] = copytext(faction, 1, 65)
	if (shared_cid)
		body["shared_cid"] = TRUE
	var/list/record = shared_records.add(target, "karma_rating", body, giver, "Player")
	if (!islist(record))
		return "That could not be saved. Try again later."
	return record

/proc/karma_set_standing(ckey, value, reason, author = "", rank = "")
	if (!isnum(value) || round(value) != value || value < -2 || value > 2)
		return null
	if (!istext(reason) || !length(reason))
		return null
	return shared_records.add(ckey, "karma_standing", list("value" = value, "reason" = copytext(reason, 1, 301)), author, rank)

// Bars or unbars a ckey from giving karma. An unbar revokes every live bar.
/proc/karma_set_bar(ckey, barred, reason = "", author = "", rank = "")
	if (barred)
		if (karma_barred(ckey))
			return FALSE
		return islist(shared_records.add(ckey, "karma_bar", list("reason" = copytext("[reason]", 1, 301)), author, rank))
	. = FALSE
	for (var/list/record in karma_live_records(ckey, "karma_bar"))
		if (shared_records.revoke(record, author, rank, reason))
			. = TRUE

// -- reading ------------------------------------------------------------------

/proc/karma_standing(ckey)
	var/list/latest = null
	for (var/list/record in karma_live_records(ckey, "karma_standing"))
		var/list/body = record["body"]
		if (!isnum(body["value"]))
			continue
		if (!latest || record["at"] >= latest["at"])
			latest = record
	if (!latest)
		return null
	var/list/body = latest["body"]
	return list("value" = body["value"], "reason" = body["reason"], "author" = latest["author"], "at" = latest["at"])

/proc/karma_barred(ckey)
	return length(karma_live_records(ckey, "karma_bar")) > 0

// A giver's latest rating counts; when staff revoked that one, the pair has
// none (an older rating never comes back).
/proc/karma_received(ckey)
	ckey = ckey(ckey)
	var/list/by_giver = list()
	for (var/list/record in shared_records.records_for(ckey))
		var/list/body = record["body"]
		if (record["kind"] != "karma_rating" || !islist(body))
			continue
		var/giver = body["giver"]
		if (!istext(giver) || giver == ckey || !(body["rating"] in list("kindly", "poorly")))
			continue
		var/list/known = by_giver[giver]
		if (!known || record["at"] >= known["at"])
			by_giver[giver] = record
	. = list()
	for (var/giver in by_giver)
		var/list/record = by_giver[giver]
		if (!record["revoked"])
			.[giver] = record

// What a ckey has given: target -> list(kind, at, note). The coordinator's
// karma file covers every region; this world's journal adds what is not synced.
/proc/karma_given(ckey)
	ckey = ckey(ckey)
	. = list()
	var/list/given = .
	var/text = shared_records.read_json("[shared_records.root()]karma/[ckey].json")
	if (istext(text))
		var/list/decoded = null
		try
			decoded = json_decode(text)
		catch
			decoded = null
		if (islist(decoded) && islist(decoded["given"]))
			for (var/list/row in decoded["given"])
				if (islist(row) && istext(row["target"]))
					given[row["target"]] = list("kind" = row["kind"], "at" = row["at"], "note" = row["note"])
	var/list/revoked = shared_records.pending_revokes()
	for (var/list/record in shared_records.load_journal())
		var/list/body = record["body"]
		if (record["kind"] != "karma_rating" || !islist(body) || body["giver"] != ckey || (record["id"] in revoked))
			continue
		given[record["ckey"]] = list("kind" = body["rating"], "at" = time2text((record["at"] - 946684800) * 10, "YYYY-MM-DD"), "note" = body["note"])

// One ckey's karma for staff, weighted like karma.py.
/proc/karma_dossier(ckey)
	ckey = ckey(ckey)
	var/now = shared_records.now_unix()
	var/list/received = karma_received(ckey)
	var/list/rows = list()
	for (var/giver in received)
		var/list/record = received[giver]
		var/list/body = record["body"]
		var/list/giver_standing = karma_standing(giver)
		var/standing_value = giver_standing ? giver_standing["value"] : null
		var/giver_hours = shared_records.playtime_hours(giver)
		var/list/factors = list("standing" = karma_standing_factor(standing_value),
			"playtime" = round(karma_playtime_factor(giver_hours), 0.001),
			"age" = karma_age_factor(record["at"], now))
		var/weight = factors["standing"] * factors["playtime"] * factors["age"]
		var/list/flags = list()
		var/list/bans = shared_records.active_bans(giver, "game")
		if (length(bans))
			flags += "giver_banned"
			weight = 0
		if (body["shared_cid"])
			flags += "shared_connection"
		if (body["rating"] == "poorly" && length(body["faction"]))
			var/peers = 0
			for (var/other in received)
				var/list/other_record = received[other]
				var/list/other_body = other_record["body"]
				if (other_body["rating"] == "poorly" && other_body["faction"] == body["faction"] && abs(other_record["at"] - record["at"]) <= KARMA_BURST_SECONDS)
					peers++
			if (peers >= KARMA_BURST_COUNT)
				flags += "burst"
		if (!length(bans) && weight < KARMA_LOW_WEIGHT)
			flags += "low_weight"
		var/giver_label = isnull(standing_value) ? karma_derived_label(giver) : karma_standing_name(standing_value)
		rows += list(list("giver" = giver, "kind" = body["rating"], "weight" = round(weight, 0.001), "factors" = factors,
			"giver_standing" = giver_label, "giver_hours" = giver_hours,
			"giver_notes" = shared_records.summary(giver)["notes"] > 0, "flags" = flags,
			"faction" = body["faction"], "at" = record["at"], "note" = body["note"], "record" = record))
	var/kindly = 0
	var/poorly = 0
	var/kindly_weighted = 0
	var/poorly_weighted = 0
	for (var/list/row in rows)
		var/list/flags = row["flags"]
		if ("giver_banned" in flags)
			continue
		if (row["kind"] == "kindly")
			kindly++
			kindly_weighted += row["weight"]
		else
			poorly++
			poorly_weighted += row["weight"]
	var/hours = shared_records.playtime_hours(ckey)
	var/list/summary = list("kindly" = kindly, "poorly" = poorly,
		"kindly_weighted" = round(kindly_weighted, 0.001), "poorly_weighted" = round(poorly_weighted, 0.001),
		"per10h" = round((kindly_weighted - poorly_weighted) / max(hours, 1) * 10, 0.01))
	return list("ckey" = ckey, "standing" = karma_standing(ckey), "barred" = karma_barred(ckey), "hours" = hours,
		"summary" = summary, "ratings" = rows)

// A label for a ckey with no admin standing, from the raw ratings it received.
/proc/karma_derived_label(ckey)
	var/list/received = karma_received(ckey)
	if (!length(received))
		return "unknown"
	var/net = 0
	for (var/giver in received)
		var/list/record = received[giver]
		var/list/body = record["body"]
		net += body["rating"] == "kindly" ? 1 : -1
	if (net >= KARMA_DERIVED_MARGIN)
		return "good"
	if (net <= -KARMA_DERIVED_MARGIN)
		return "poor"
	return "neutral"

#undef KARMA_NOTE_LIMIT
#undef KARMA_FULL_WEIGHT_HOURS
#undef KARMA_PLAYTIME_FLOOR
#undef KARMA_AGE_SECONDS
#undef KARMA_AGE_FACTOR
#undef KARMA_LOW_WEIGHT
#undef KARMA_BURST_SECONDS
#undef KARMA_BURST_COUNT
#undef KARMA_DERIVED_MARGIN
