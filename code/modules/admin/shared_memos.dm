// Admin memos (shown to staff at login) and server memos (shown to every
// player with the MOTD), shared by every region of a shard group through the
// shared player records (shared_player_records.dm). Each author has at most one
// memo of each kind: writing a new one revokes the old one.
//
// Memos made before the shared records (data/memo.sav, data/memo2.sav) are
// copied in once per region by memo_migrate_legacy(). The old files are kept.

/proc/memo_label(kind)
	return kind == "admin_memo" ? "Admin Memo" : "Server Memo"

// The active memos of kind ("admin_memo" or "server_memo"), newest per author.
/proc/memos_active(kind)
	memo_migrate_legacy()
	. = list()
	for (var/author in shared_records.ckeys_with(list(kind)))
		var/list/newest = null
		for (var/list/record in shared_records.records_for(author))
			if (record["kind"] != kind || record["revoked"])
				continue
			if (!newest || !shared_records.unix_after(newest["at"], record["at"]))
				newest = record
		if (newest)
			. += list(newest)

/proc/memo_html(list/record)
	var/list/body = record["body"]
	if (!islist(body))
		return ""
	if (body["legacy"] && istext(body["html"]))
		return body["html"] // written by staff on the old memo files, shown as it was
	var/name = istext(body["name"]) ? body["name"] : record["ckey"]
	return "[memo_label(record["kind"])] from <b>[html_encode(name)]</b> on [shared_records.time_text(record["at"], "(DDD) DD MMM hh:mm")]<br><i>[body["text"]]</i>"

/proc/memo_show(kind, client/C)
	if (!C)
		return
	for (var/list/record in memos_active(kind))
		to_chat(C, "<center><span class='motd'>[memo_html(record)]</span></center>")

// Revokes every active memo of kind by author. Returns how many.
/proc/memo_remove(kind, author, client/remover)
	author = ckey(author)
	. = 0
	for (var/list/record in shared_records.records_for(author))
		if (record["kind"] == kind && !record["revoked"])
			if (shared_records.revoke(record, remover ? remover.ckey : "", (remover && remover.holder) ? remover.holder.rank : ""))
				.++

/proc/memo_write(kind, client/C)
	if (!C || !C.holder)
		return
	var/memo = input(C, "Type your memo\n(Leaving it blank will delete your current memo):", "Write Memo", null) as null|message
	if (isnull(memo))
		return
	if (memo == "")
		memo_remove(kind, C.ckey, C)
		to_chat(C, "<b>Memo removed</b>")
		return
	if (findtext(memo, "<script", 1, 0))
		return
	var/text = replacetext(html_encode(copytext(memo, 1, MAX_MESSAGE_LEN)), "\n", "<br>")
	memo_remove(kind, C.ckey, C)
	if (!shared_records.add(C.ckey, kind, list("text" = text, "name" = C.key), C.ckey, C.holder.rank))
		to_chat(C, "<span class='warning'>The memo could not be saved.</span>")
		return
	message_admins("[C.key] has set [kind == "admin_memo" ? "an admin" : "a server"] memo on every region:<br>[text]", C.key)

// Removes your own memo, or anyone's with +SERVER.
/proc/memo_delete(kind, client/C)
	if (!C || !C.holder)
		return
	var/author = C.ckey
	if (check_rights(R_SERVER, 0, C))
		var/list/authors = list()
		for (var/list/record in memos_active(kind))
			authors += record["ckey"]
		if (!authors.len)
			to_chat(C, "<b>There are no memos.</b>")
			return
		author = input(C, "Whose memo shall we remove?", "Remove [memo_label(kind)]") as null|anything in authors
	if (!author)
		return
	if (memo_remove(kind, author, C))
		to_chat(C, "<b>Removed the memo created by [author] on every region.</b>")
	else
		to_chat(C, "<b>[author] has no memo.</b>")

var/memos_migrated = FALSE

// Copies this region's old memo files into the shared records, once.
/proc/memo_migrate_legacy()
	if (memos_migrated)
		return 0
	memos_migrated = TRUE
	if (fexists("data/memos.migrated"))
		return 0
	var/count = 0
	shared_records.hold_save = TRUE
	for (var/kind in list("admin_memo", "server_memo"))
		var/path = kind == "admin_memo" ? "data/memo.sav" : "data/memo2.sav"
		if (!fexists(path))
			continue
		var/savefile/F = new(path)
		for (var/author in F.dir)
			var/html
			F[author] >> html
			if (!istext(html) || !length(html) || !length(ckey(author)))
				continue
			if (shared_records.add(author, kind, list("html" = html, "legacy" = TRUE), ckey(author), "",
				md5("civ13-legacy-memo|[kind]|[ckey(author)]|[html]")))
				count++
	shared_records.hold_save = FALSE
	shared_records.save_journal()
	text2file("[count] memos copied to the shared player records.", "data/memos.migrated")
	if (count)
		log_admin("Shared player records: copied [count] old memos from this region.")
	return count
