// Verified ckey -> Discord ID (text), from the approved list. Accounts use it
// (code/modules/accounts/discord_accounts.dm); empty until approved.txt loads.
var/global/list/approved_discord_ids = list()

// Stage the entire independent file before publishing membership. IDs stay text.
/proc/parse_verified_access_text(access_text)
	if (!istext(access_text) || !length(access_text))
		return null
	if (access_text == "\n")
		return list()
	var/normalized_text = replacetext(access_text, ascii2text(13) + "\n", "\n")
	if (normalized_text == "\n" || findtext(normalized_text, ascii2text(13)))
		return null
	if (copytext(normalized_text, length(normalized_text)) != "\n")
		return null
	var/list/access_rows = splittext(normalized_text, "\n")
	var/list/staged_keys = list()
	var/list/seen_ids = list()
	var/row_index = 0
	var/regex/row_format = regex(@"^[A-Za-z0-9_ \t]+=[ \t]*[1-9][0-9]{16,19}[ \t]*$")
	var/regex/key_format = regex(@"^[a-z0-9]{1,256}$")
	for (var/access_row in access_rows)
		row_index++
		if (row_index == access_rows.len && access_row == "")
			continue
		if (!row_format.Find(access_row))
			return null
		var/list/access_fields = splittext(access_row, "=")
		var/canonical_key = ckey(access_fields[1])
		var/discord_id = trim(access_fields[2])
		if (!key_format.Find(canonical_key))
			return null
		if ((canonical_key in staged_keys) || (discord_id in seen_ids))
			return null
		staged_keys += canonical_key
		seen_ids += discord_id
	return staged_keys

// The mode is set by the host-generated shard directory, not by the
// authority bundle. An unreadable access bundle cannot turn the mode off.
/proc/gateway_access_enabled()
	return shard_group && shard_group.enabled && shard_group.gateway_verified_access

// The host's protected gateway directory is the trust boundary. Publishing an
// atomic bundle is also a reload notice: worlds poll only this one authority,
// not one another. There is no Topic endpoint, credential, or public output.
/proc/reload_gateway_verified_access(force = FALSE)
	var/static/next_read = 0
	var/static/loaded_revision = 0
	var/static/loaded_text = null
	if (!force && world.time < next_read)
		return approved_list_ready && whitelist_list_ready
	next_read = world.time + 5 SECONDS
	var/path = "../front-door/SQL/verified-access.json"
	var/access_text = null
	try
		access_text = file2text(path)
	catch
		return gateway_access_unavailable()
	if (access_text == loaded_text && loaded_revision && approved_list_ready && whitelist_list_ready)
		return TRUE
	if (!istext(access_text) || !length(access_text) || length(access_text) > 8388608)
		return gateway_access_unavailable()
	var/list/staged = stage_gateway_verified_access(access_text, shard_group.group, loaded_revision, loaded_text)
	if (!islist(staged))
		return gateway_access_unavailable()
	approved_list = staged["approved"]
	approved_discord_ids = staged["ids"]
	whitelist_list = staged["whitelist"]
	loaded_revision = staged["revision"]
	loaded_text = access_text
	approved_list_ready = TRUE
	whitelist_list_ready = TRUE
	return TRUE

// Parse both halves before the caller publishes any membership or grant.
/proc/stage_gateway_verified_access(access_text, group, loaded_revision, loaded_text)
	var/list/bundle = null
	try
		bundle = json_decode(access_text)
	catch
		return null
	if (!islist(bundle) || bundle.len != 5 || bundle["schema"] != 1 || bundle["group"] != group)
		return null
	var/revision = bundle["revision"]
	if (!isnum(revision) || round(revision) != revision || revision < 1 || revision > 8000000 || revision < loaded_revision)
		return null
	if (revision == loaded_revision && access_text != loaded_text)
		return null
	var/list/staged_approved = parse_verified_access_text(bundle["approved"])
	var/list/staged_whitelist = parse_verified_access_text(bundle["whitelist"])
	if (isnull(staged_approved) || isnull(staged_whitelist))
		return null
	var/list/staged_ids = verified_access_discord_ids(bundle["approved"], staged_approved)
	if (staged_ids.len != staged_approved.len)
		return null
	return list("revision" = revision, "approved" = staged_approved, "ids" = staged_ids, "whitelist" = staged_whitelist)

/proc/gateway_access_unavailable()
	// Some existing loadout readers inspect the lists directly; clear all three
	// rather than let a stale list grant admission while readiness is false.
	approved_list_ready = FALSE
	whitelist_list_ready = FALSE
	approved_list = list()
	whitelist_list = list()
	approved_discord_ids = list()
	return FALSE

/proc/reload_verified_access_list(access_kind)
	if (access_kind != "approved" && access_kind != "whitelist")
		return FALSE
	if (gateway_access_enabled())
		return reload_gateway_verified_access(TRUE)
	var/access_filename = null
	if (access_kind == "approved")
		access_filename = "SQL/approved.txt"
	else if (access_kind == "whitelist")
		access_filename = "SQL/whitelist.txt"
	else
		return FALSE
	if (!fexists(access_filename))
		return FALSE
	var/list/staged_keys = null
	var/access_text = null
	try
		access_text = file2text(access_filename)
		staged_keys = parse_verified_access_text(access_text)
	catch
		return FALSE
	if (isnull(staged_keys))
		return FALSE
	if (access_kind == "approved")
		approved_list = staged_keys
		approved_list_ready = TRUE
		approved_discord_ids = verified_access_discord_ids(access_text, staged_keys)
	else
		whitelist_list = staged_keys
		whitelist_list_ready = TRUE
	return TRUE

/proc/verified_access_member(access_kind, candidate_key)
	if (gateway_access_enabled() && !reload_gateway_verified_access())
		return FALSE
	if (access_kind == "approved")
		return approved_list_ready && (candidate_key in approved_list)
	if (access_kind == "whitelist")
		return whitelist_list_ready && (candidate_key in whitelist_list)
	return FALSE

// The verified soft whitelist (Val, 2026-11-19): TRUE when the account has
// linked a Discord account (the approved list the Verify Discord verb fills).
// Fails closed while the list has not been read.
/proc/account_verified(account)
	return istext(account) && verified_access_member("approved", ckey(account))

// The Discord IDs of a file that parse_verified_access_text() already accepted
// as staged_keys. A file that changed in between (different keys) yields none.
/proc/verified_access_discord_ids(access_text, list/staged_keys)
	var/list/ids = list()
	if (!istext(access_text) || !islist(staged_keys))
		return ids
	for (var/access_row in splittext(replacetext(access_text, ascii2text(13) + "\n", "\n"), "\n"))
		var/separator = findtext(access_row, "=")
		if (!separator)
			continue
		var/canonical_key = ckey(copytext(access_row, 1, separator))
		if (canonical_key in staged_keys)
			ids[canonical_key] = trim(copytext(access_row, separator + 1))
	if (ids.len != staged_keys.len)
		return list()
	return ids

/proc/verified_discord_id(candidate_key)
	if (gateway_access_enabled() && !reload_gateway_verified_access())
		return null
	if (!approved_list_ready || !istext(candidate_key))
		return null
	var/id = approved_discord_ids[candidate_key]
	if (!istext(id))
		return null
	return id

// The bot rewrites SQL/approved.txt and SQL/whitelist.txt as players verify in
// Discord. Startup and Reload Lists read them once; this watch re-reads a file
// whenever its text changes, so a new verification reaches a running world
// within a few minutes. A file that fails validation keeps the prior list and is
// retried on the next pass.
/proc/watch_verified_access_lists()
	set waitfor = FALSE
	var/static/watching = FALSE
	if (watching)
		return
	watching = TRUE
	if (gateway_access_enabled())
		while (TRUE)
			reload_gateway_verified_access()
			sleep(5 SECONDS)
	var/list/loaded_text = list()
	for (var/access_kind in list("approved", "whitelist"))
		loaded_text[access_kind] = verified_access_file_text(access_kind)
	while (TRUE)
		sleep(2 MINUTES)
		for (var/access_kind in list("approved", "whitelist"))
			var/access_text = verified_access_file_text(access_kind)
			if (!istext(access_text) || access_text == loaded_text[access_kind])
				continue
			if (reload_verified_access_list(access_kind))
				loaded_text[access_kind] = access_text

// The current text of an access file, or null when it is missing or unreadable.
/proc/verified_access_file_text(access_kind)
	var/access_filename = access_kind == "approved" ? "SQL/approved.txt" : (access_kind == "whitelist" ? "SQL/whitelist.txt" : null)
	if (!access_filename || !fexists(access_filename))
		return null
	var/access_text = null
	try
		access_text = file2text(access_filename)
	catch
		return null
	return access_text
