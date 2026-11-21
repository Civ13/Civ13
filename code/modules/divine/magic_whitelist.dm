// ============================================================
// Magic whitelist (Val, 2026-11-15). Hidden mechanic: keep it out of changelog
// lines, the wiki and anything a player sees.
// ------------------------------------------------------------
// Like the TDM job whitelist (SQL/whitelist.txt, verified_access_member), staff
// choose who may take part: on persistent worlds only a whitelisted player can
// follow a god, use Beseech, read sealed advancement notes or gain the magic
// skill. Players who are not on it keep whatever is saved on their character;
// it is suspended, not deleted, and comes back as soon as staff add them.
//
// The list is one player key per line ("#" starts a comment) and is shared by
// every region of a shard group: like admins.txt (admin_ranks.dm), a region
// reads the gate region's SQL/magic_whitelist.txt. A lone server keeps its own.
// Staff edit it with the Magic Whitelist admin verb, the launcher's Magic
// whitelist dialog, or scripts/shard-group/shard_group.py magic-whitelist.
// Worlds reread it at most every MAGIC_WHITELIST_REFRESH, and at once after an
// edit made in that world.
// ============================================================

#define MAGIC_WHITELIST_NAME "magic_whitelist.txt"
#define MAGIC_WHITELIST_REFRESH 300 // deciseconds between rereads of the shared file
#define MAGIC_WHITELIST_HEADER "# Magic whitelist: one player key per line. Shared by every region of the group.\n"

var/global/list/magic_whitelist = list()
var/global/magic_whitelist_text = null
var/global/magic_whitelist_read_at = -1
var/global/magic_whitelist_path = null

/proc/magic_whitelist_file()
	if (magic_whitelist_path)
		return magic_whitelist_path
	magic_whitelist_path = "SQL/[MAGIC_WHITELIST_NAME]"
	if (fexists("config/shard_region.json"))
		var/list/settings = null
		try
			settings = json_decode(file2text("config/shard_region.json"))
		catch
			settings = null
		if (islist(settings))
			// The same source admins_file() reads: the gate, else the mainland.
			var/source = istext(settings["gate"]) ? settings["gate"] : settings["mainland"]
			var/region = settings["region"]
			// The group's own folder once it has one (found by its admins file, like admins_file()).
			if (shard_id_valid(region) && fexists("../front-door/SQL/admins.txt"))
				magic_whitelist_path = "../front-door/SQL/[MAGIC_WHITELIST_NAME]"
			else if (shard_id_valid(source) && shard_id_valid(region) && source != region && fexists("../[source]/config/shard_region.json"))
				magic_whitelist_path = "../[source]/SQL/[MAGIC_WHITELIST_NAME]"
	return magic_whitelist_path

/proc/magic_whitelist_parse(text)
	var/list/keys = list()
	if (!istext(text))
		return keys
	for (var/line in splittext(replacetext(text, ascii2text(13), ""), "\n"))
		var/hash = findtext(line, "#")
		if (hash)
			line = copytext(line, 1, hash)
		var/key = ckey(line)
		if (length(key) && length(key) <= 32 && !(key in keys))
			keys += key
	return keys

/proc/magic_whitelist_refresh(force = FALSE)
	if (!force && magic_whitelist_read_at >= 0 && world.time < magic_whitelist_read_at + MAGIC_WHITELIST_REFRESH)
		return
	magic_whitelist_read_at = world.time
	var/F = magic_whitelist_file()
	var/text = ""
	if (fexists(F))
		try
			text = file2text(F)
		catch
			// Keep the last list we read rather than suspending everyone over one bad read.
			return
	if (!istext(text))
		text = ""
	if (text == magic_whitelist_text)
		return
	magic_whitelist_text = text
	magic_whitelist = magic_whitelist_parse(text)

/proc/magic_whitelisted(key)
	key = ckey(key)
	if (!length(key))
		return FALSE
	magic_whitelist_refresh()
	return (key in magic_whitelist)

// Only persistent worlds are gated; TDM maps keep their own wizard jobs.
/proc/magic_whitelist_applies()
	return map && map.persistence

// Add (or remove) one key and write the shared file. FALSE if nothing changed.
/proc/magic_whitelist_set(key, add)
	key = ckey(key)
	if (!length(key) || length(key) > 32)
		return FALSE
	magic_whitelist_refresh(TRUE)
	var/list/keys = magic_whitelist.Copy()
	if (add == (key in keys))
		return FALSE
	if (add)
		keys += key
	else
		keys -= key
	var/text = MAGIC_WHITELIST_HEADER
	for (var/entry in sortList(keys))
		text += "[entry]\n"
	var/F = magic_whitelist_file()
	if (fexists(F))
		fdel(F)
	text2file(text, F)
	magic_whitelist_refresh(TRUE)
	return (key in magic_whitelist) == !!add

// The player key a character belongs to, played or not.
/mob/living/human/proc/magic_key()
	if (client)
		return client.ckey
	if (istext(persistence_owner_ckey) && length(persistence_owner_ckey))
		return ckey(persistence_owner_ckey)
	return ckey

/mob/living/human/proc/magic_allowed()
	if (!magic_whitelist_applies())
		return TRUE
	if (divine_is_own_god()) // repository_nations.dm: a god playing their own follower
		return TRUE
	return magic_whitelisted(magic_key())

// Whatever a character can still do once their player leaves the list: a
// pending prayer ends and Beseech goes away. Saved patron and prayers stay.
/mob/living/human/proc/magic_whitelist_revoked()
	if (divine_covenant || divine_request)
		divine_break_covenant()
	if (divine_vigil_member)
		divine_leave_vigil()
	divine_refresh_verbs()

#undef MAGIC_WHITELIST_HEADER
