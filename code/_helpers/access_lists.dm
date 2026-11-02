// Stage the entire independent file before publishing membership. IDs stay text.
/proc/parse_verified_access_text(access_text)
	if (!istext(access_text) || !length(access_text))
		return null
	if (access_text == "\n")
		return list()
	var/normalized_text = replacetext(access_text, "\r\n", "\n")
	if (normalized_text == "\n" || findtext(normalized_text, "\r"))
		return null
	if (copytext(normalized_text, length(normalized_text)) != "\n")
		return null
	var/list/access_rows = splittext(normalized_text, "\n")
	var/list/staged_keys = list()
	var/list/seen_ids = list()
	var/row_index = 0
	var/regex/row_format = regex("^[A-Za-z0-9_ \t]+=[ \t]*[1-9][0-9]{16,19}[ \t]*$")
	var/regex/key_format = regex("^[a-z0-9]{1,256}$")
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

/proc/reload_verified_access_list(access_kind)
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
	try
		staged_keys = parse_verified_access_text(file2text(access_filename))
	catch(var/exception/read_error)
		return FALSE
	if (isnull(staged_keys))
		return FALSE
	if (access_kind == "approved")
		approved_list = staged_keys
		approved_list_ready = TRUE
	else
		whitelist_list = staged_keys
		whitelist_list_ready = TRUE
	return TRUE

/proc/verified_access_member(access_kind, candidate_key)
	if (access_kind == "approved")
		return approved_list_ready && (candidate_key in approved_list)
	if (access_kind == "whitelist")
		return whitelist_list_ready && (candidate_key in whitelist_list)
	return FALSE
