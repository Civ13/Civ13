// Native fixture for code/modules/admin/shared_player_records.dm. The
// production file is included unchanged; only what it calls is stubbed.
var/list/checks = list()
var/list/failed = list()

/proc/check(label, ok)
	checks += label
	if (!ok)
		failed += label

/datum/shard_group
	var/enabled = FALSE
	var/region = "gaia"
var/datum/shard_group/shard_group = new

/proc/shard_id_valid(value)
	return istext(value) && length(value)

/datum/transfer_bridge
	var/on = FALSE
	var/refuse = FALSE
	var/list/received = list()
/datum/transfer_bridge/proc/enabled()
	return on
/datum/transfer_bridge/proc/request(path, list/body)
	if (path != "/record")
		return null
	if (refuse)
		return list("ok" = FALSE, "error" = "bad record")
	for (var/list/R in body["records"])
		received += list(R)
	return list("ok" = TRUE)
var/datum/transfer_bridge/transfer_bridge = new

var/fake_now = "1800000000"
/proc/rustg_unix_timestamp()
	return "[fake_now].25"

// What player_notes.dm calls.
/datum/player_info
	var/author
	var/rank
	var/content
	var/timestamp
/proc/get_player_notes_file_dir()
	return "data/player_saves/"
/proc/message_admins(text)
	return
/proc/key_name_admin(whom)
	return "[whom]"
/proc/key_name(whom)
	return "[whom]"
/proc/ishost(whom)
	return FALSE
/datum/admins
	var/rank = "Admin"
/client
	var/datum/admins/holder

// Old savefile notes, as notes_add() wrote them before the shared records.
/proc/write_legacy_notes()
	var/savefile/index = new("data/player_notes.sav")
	index << list("oldtimer")
	var/savefile/info = new("data/player_saves/o/oldtimer/info.sav")
	var/datum/player_info/P = new
	P.author = "SomeAdmin"
	P.rank = "Moderator"
	P.content = "used slurs"
	P.timestamp = "Mon, March 3rd of 2025"
	var/datum/player_info/Q = new
	Q.author = "Adminbot"
	Q.rank = "Friendly Robot"
	Q.content = "auto note"
	info << list(P, Q)

/proc/log_admin(text)
	return

/proc/sortList(list/L)
	. = L.Copy()
	for (var/i = 1, i <= length(.), i++)
		for (var/j = i + 1, j <= length(.), j++)
			if (sorttext(.[i], .[j]) < 0)
				var/t = .[i]
				.[i] = .[j]
				.[j] = t

/proc/write_json(path, value)
	if (fexists(path))
		fdel(path)
	text2file(json_encode(value), path)

/world/New()
	..()
	fdel("data/")
	run_checks()
	fdel("result.json")
	text2file(json_encode(list("checks" = length(checks), "failed_labels" = failed)), "result.json")
	shutdown()

/proc/run_checks()
	var/datum/shared_records/S = shared_records

	write_legacy_notes()
	// Local mode: no shard group, the journal is the store.
	check("local root", S.root() == "data/shared-records/" && S.region() == "local")
	var/list/note = S.add("Bob Smith", "note", list("text" = "griefed"), "Val", "Host")
	check("note made", islist(note) && note["ckey"] == "bobsmith" && note["author"] == "val" && length(note["id"]) == 32)
	check("time from rust_g", note["at"] == "1800000000")
	check("journal written", fexists("data/player_records.json"))
	check("bad kind refused", isnull(S.add("bob", "Bad Kind!", list())))
	check("ban needs a scope", isnull(S.add("bob", "ban", list("until" = 0))))
	check("body size capped", isnull(S.add("bob", "note", list("text" = jointext(new /list(17000), "x")))))
	var/list/warning = S.add("bobsmith", "warning", list("text" = "spam"), "val", "Host")
	var/list/sum = S.summary("bobsmith")
	check("summary counts pending", sum["notes"] == 1 && sum["warnings"] == 1 && sum["kinds"]["note"] == 1)
	var/before = length(S.journal)
	check("same id stored once", S.add("bobsmith", "note", list("text" = "x"), "val", "", note["id"]) == note && length(S.journal) == before)
	S.revoke(warning, "val", "Host", "mistake")
	sum = S.summary("bobsmith")
	check("revoke lowers the count", sum["warnings"] == 0 && sum["notes"] == 1)
	var/list/found = S.records_for("bobsmith")
	var/revoked_seen = FALSE
	for (var/list/R in found)
		if (R["id"] == warning["id"])
			var/list/gone = R["revoked"]
			revoked_seen = islist(gone) && gone["reason"] == "mistake"
	check("revoked record marked", revoked_seen)

	check("exact time arithmetic", S.unix_add("1800099999", 2) == "1800100001" && S.unix_after("1800000001", "1800000000") \
		&& !S.unix_after("1800000000", "1800000000") && S.unix_after("10", "9") && !S.unix_after(0, "5") \
		&& S.unix_add("1800000000", 7776000) == "1807776000" && S.unix_add("5", 7) == "12" && S.unix_add("99999", 1) == "100000")
	S.add("eve", "ban", list("scope" = "game", "until" = S.unix_add(fake_now, 60)), "val", "Host")
	S.add("eve", "ban", list("scope" = "ooc"), "val", "Host")
	S.add("eve", "ban", list("scope" = "game", "until" = "1799999999"), "val", "Host")
	check("active game bans only", length(S.active_bans("eve")) == 1 && length(S.active_bans("eve", "any")) == 2)
	fake_now = "1800000061"
	check("temporary ban ends on its own", !length(S.active_bans("eve")) && length(S.active_bans("eve", "any")) == 1)
	check("ckeys with notes", jointext(S.ckeys_with(list("note", "warning")), ",") == "bobsmith,oldtimer")
	check("time text", S.time_text("1795176000", "YYYY-MM-DD") == "2026-11-20")
	var/list/old = notes_for("oldtimer")
	check("old notes copied", length(old) == 2 && old[1]["author"] == "someadmin" && old[1]["body"]["legacy_date"] == "Mon, March 3rd of 2025")
	check("old notes kept", fexists("data/player_saves/o/oldtimer/info.sav") && fexists("data/player_notes.migrated"))
	var/list/copy_ids = list(old[1]["id"], old[2]["id"])
	fdel("data/player_notes.migrated")
	legacy_notes_migrate()
	check("a second copy collapses", length(notes_for("oldtimer")) == 2 && notes_for("oldtimer")[1]["id"] == copy_ids[1])
	var/mob/admin = new
	check("only the author removes", !notes_del("oldtimer", copy_ids[1], admin))
	admin.ckey = "someadmin"
	check("author removes", notes_del("oldtimer", copy_ids[1], admin) && length(notes_for("oldtimer")) == 1)
	check("warning recorded", notes_warn("Rude Guy", "insults", admin) && S.summary("rudeguy")["warnings"] == 1)

	// The journal survives a restart.
	var/datum/shared_records/again = new
	check("journal reloads", length(again.load_journal()) == length(S.journal))

	// Linked mode: records go to the agent, then leave the journal once the
	// coordinator's pull time for this region is later than the send.
	shard_group.enabled = TRUE
	transfer_bridge.on = TRUE
	check("group root", S.root() == "../shared-records/" && S.region() == "gaia")
	S.tick()
	check("records sent", length(transfer_bridge.received) == length(S.journal) && !("sent" in transfer_bridge.received[1]))
	var/sent_at = S.journal[1]["sent"]
	check("send time rounded up", sent_at == "1800000062")
	fdel("../shared-records/")
	write_json("../shared-records/index.json", list("version" = 1, "pulled" = list("gaia" = sent_at),
		"accounts" = list("d:42" = "amy"), "players" = list("bobsmith" = list("notes" = 1, "warnings" = 0, "watch" = FALSE,
		"bans" = list(), "hours" = 12.5, "kinds" = list("note" = 1)))))
	write_json("../shared-records/bans.json", list("version" = 1, "bans" = list(list("id" = "ffffffffffffffffffffffffffffffff", "ckey" = "zed",
		"scope" = "game", "until" = "0"))))
	S.refresh(TRUE)
	check("not dropped at the same second", length(S.journal) && length(S.journal) == length(transfer_bridge.received))
	write_json("../shared-records/index.json", list("version" = 1, "pulled" = list("gaia" = "1800000063"),
		"accounts" = list("d:42" = "amy"), "players" = list("bobsmith" = list("notes" = 1, "warnings" = 0, "watch" = FALSE,
		"bans" = list(), "hours" = 12.5, "kinds" = list("note" = 1)))))
	S.refresh(TRUE)
	check("dropped once pulled", !length(S.journal))
	sum = S.summary("bobsmith")
	check("summary from snapshot", sum["notes"] == 1 && sum["hours"] == 12.5)
	check("playtime", S.playtime_hours("bobsmith") == 12.5 && S.playtime_hours("nobody") == 0)
	check("account map", S.account_ckey("d:42") == "amy" && isnull(S.account_ckey("d:1")))
	check("snapshot bans", length(S.active_bans("zed")) == 1)

	// A refused record is kept here and never treated as synced.
	transfer_bridge.refuse = TRUE
	S.add("amy", "note", list("text" = "x"), "val", "Host")
	S.tick()
	check("refused kept", length(S.journal) == 1 && S.journal[1]["sent"] == -1)
	write_json("../shared-records/index.json", list("version" = 1, "pulled" = list("gaia" = "1900000000"), "players" = list()))
	S.refresh(TRUE)
	check("refused never dropped", length(S.journal) == 1)
	fdel("../shared-records/")
