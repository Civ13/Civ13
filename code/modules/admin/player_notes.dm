// Player notes and warnings, shared by every region of a shard group through
// the shared player records (shared_player_records.dm). A note made on one
// region shows on all of them; removing it appends a revoke record, so two
// admins acting at once on two regions never overwrite each other.
//
// Notes made before the shared records (data/player_saves/<k>/<key>/info.sav,
// indexed by data/player_notes.sav) are copied in once per region by
// legacy_notes_migrate(). Each copy's id comes from its content, so the same
// note copied on several regions is stored once. The old files are kept.

#define PLAYER_NOTES_MIGRATED "data/player_notes.migrated"

/proc/notes_add(var/key, var/note, var/mob/user)
	key = ckey(key)
	if (!key || !note)
		return null
	var/list/record = shared_records.add(key, "note", list("text" = note), user ? user.ckey : "",
		(user && user.client && user.client.holder) ? user.client.holder.rank : "Friendly Robot")
	if (!record)
		return null
	message_admins("<span class = 'notice'>[key_name_admin(user)] has edited [key]'s notes.</span>", key_name_admin(user))
	log_admin("[key_name(user)] has edited [key]'s notes.")
	return record

// Removes one note or warning by its record id. Only its author, a note left
// by the server, or the host may remove it.
/proc/notes_del(var/key, var/id, var/mob/user = usr)
	key = ckey(key)
	for (var/list/record in shared_records.records_for(key))
		if (record["id"] != id || record["revoked"] || !(record["kind"] in list("note", "warning")))
			continue
		if (!notes_can_remove(record, user))
			return FALSE
		if (!shared_records.revoke(record, user ? user.ckey : "", (user && user.client && user.client.holder) ? user.client.holder.rank : ""))
			return FALSE
		message_admins("<span class = 'notice'>[key_name_admin(user)] deleted one of [key]'s notes.</span>", key_name_admin(user))
		log_admin("[key_name(user)] deleted one of [key]'s notes.")
		return TRUE
	return FALSE

/proc/notes_can_remove(list/record, mob/user)
	if (!user)
		return FALSE
	var/author = record["author"]
	return author == user.ckey || !length(author) || author == "adminbot" || ishost(user)

// Records a formal warning (Warn). The player sees the reason if online.
/proc/notes_warn(key, reason, mob/user)
	key = ckey(key)
	if (!key || !reason)
		return null
	return shared_records.add(key, "warning", list("text" = reason), user ? user.ckey : "",
		(user && user.client && user.client.holder) ? user.client.holder.rank : "")

// The notes and warnings about key, oldest first, without removed ones.
/proc/notes_for(key)
	. = list()
	for (var/list/record in shared_records.records_for(key))
		if (!record["revoked"] && (record["kind"] in list("note", "warning")))
			. += list(record)

// Copies this region's old savefile notes into the shared records, once.
/proc/legacy_notes_migrate()
	if (fexists(PLAYER_NOTES_MIGRATED) || !fexists("data/player_notes.sav"))
		return 0
	var/count = 0
	var/savefile/S = new("data/player_notes.sav")
	var/list/note_keys
	S >> note_keys
	shared_records.hold_save = TRUE
	for (var/key in note_keys)
		if (!istext(key))
			continue
		var/savefile/info = new("[get_player_notes_file_dir()][copytext(key, 1, 2)]/[key]/info.sav")
		var/list/infos
		info >> infos
		for (var/datum/player_info/I in infos)
			if (!istext(I.content) || !length(I.content))
				continue
			var/author = istext(I.author) ? ckey(I.author) : ""
			var/id = md5("civ13-legacy-note|[ckey(key)]|[author]|[I.content]|[I.timestamp]")
			var/list/body = list("text" = I.content, "legacy" = TRUE)
			if (istext(I.timestamp))
				body["legacy_date"] = I.timestamp
			if (shared_records.add(key, "note", body, author, istext(I.rank) ? I.rank : "", id))
				count++
	shared_records.hold_save = FALSE
	shared_records.save_journal()
	text2file("[count] notes copied to the shared player records.", PLAYER_NOTES_MIGRATED)
	if (count)
		log_admin("Shared player records: copied [count] old player notes from this region.")
	return count

#undef PLAYER_NOTES_MIGRATED
