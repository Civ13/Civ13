var/list/forbidden_pref_save_varnames = list("client_ckey", "last_id")

/datum/preferences/proc/preferences_exist()
	var/F = file("SQL/charprefs.txt")
	var/fulltext = file2text(F)
	var/list/charprefs = splittext(fulltext, "|||\n")
	var/done1 = FALSE
	for (var/i=1;i<charprefs.len;i++)
		var/list/charprefs2 = splittext(charprefs[i], ";")
		if (charprefs2[1] == client_ckey)
			done1 = TRUE
	if (!done1)
		return FALSE
	else
		return TRUE

/datum/preferences/proc/load_preferences()

	if (!client_ckey)
		return FALSE

	var/F = file("SQL/charprefs.txt")
	var/fulltext = file2text(F)
	var/list/charprefs = splittext(fulltext, "|||\n")
	var/done1 = FALSE
	var/table = 0
	for (var/i=1;i<charprefs.len;i++)
		var/list/charprefs2 = splittext(charprefs[i], ";")
		if (charprefs2[1] == client_ckey)
			done1 = TRUE
			table = charprefs2[2]

	if (!done1)
		return FALSE

	var/list/key_val_pairs = splittext(table, "&")

	for (var/key_val_pair in key_val_pairs)
		var/keyval_list = splittext(key_val_pair, "=")
		var/key = keyval_list[1]
		var/val = keyval_list[2]
		if (key != "clientprefs_enabled" && key != "clientprefs_disabled")
			key_val_pairs -= key_val_pair
			if (findtext(val, "{"))
				key_val_pairs[key] = list()
			//	log_debug("[key] = [val]")
				var/list = replacetext(replacetext(val, "{", ""), "}", "")
				list = splittext(list, "|")
				for (var/something in list)
			//		log_debug("item: [something]")
					key_val_pairs[key] += something
			else
				key_val_pairs[key] = val


	for (var/varname in vars)
		if (key_val_pairs.Find(varname))
			if (isnum(vars[varname])) // if the initial var is a num
				vars[varname] = text2num(key_val_pairs[varname])
			else
				vars[varname] = key_val_pairs[varname]
		else // reset to default, getting rid of previous setting
			if (isnum(vars[varname]) || istext(vars[varname]) && !forbidden_pref_save_varnames.Find(varname))
				vars[varname] = initial(vars[varname])

	internal_table = list(key_val_pairs)
	update_setup()

	return TRUE

/datum/preferences/proc/save_preferences()

	if (!client_ckey)
		return FALSE

	if (real_name == "PLACEHOLDER")
		real_name = "[capitalize(client.key)]"

	var/name_to_remember = real_name
	var/list/table = list(internal_table)
	if (table["real_name"] == real_name)
		name_to_remember = random_name(gender,species)

	if (isemptylist(internal_table))
		internal_table = list()
	remember_preference("real_name", name_to_remember) // don't save or inf. loop

	var/params = ""
	for (var/key in internal_table)
		if (!vars.Find(key))
			continue
		if (internal_table[key] == initial(vars[key]))
			continue
		if (params != "")
			params += "&"
		var/val = internal_table[key]
		if (islist(val))
			params += "[key]={"
			for (var/x in val)
				params += "[x]"
				if (x != val[val:len])
					params += "|"
			params += "}"
		else
			params += "[key]=[val]"

	if (dd_hassuffix(params, ";"))
		params = copytext(params, 1, lentext(params))


	if (dd_hassuffix(params, ";"))
		params = copytext(params, 1, lentext(params))


	var/F = file("SQL/charprefs.txt")
	var/list/charprefs = splittext(file2text(F), "|||\n")
	var/done1 = FALSE
	for (var/i=1;i<charprefs.len;i++)
		var/list/charprefs2 = splittext(charprefs[i], ";")
		if (charprefs2[1] == client_ckey)
			charprefs[i] = "[client_ckey];[params]"
			done1 = TRUE
	if (!done1)
		text2file("[client_ckey];[params]|||",F)
	else
		fdel(F)
		for (var/i=1;i<charprefs.len;i++)
			text2file("[charprefs[i]]|||", F)
	return
/datum/preferences/proc/remember_preference(pref, value)
	if (!vars.Find(pref))
		return FALSE
	if (value == initial(vars[pref]))
		return FALSE
	if (forbidden_pref_save_varnames.Find(pref))
		return FALSE

	if (isemptylist(internal_table))
		internal_table = list()
	internal_table[pref] = value

	return TRUE

/datum/preferences/proc/forget_preference(pref, var/glob = FALSE)
	if (!vars.Find(pref))
		return FALSE
	if (forbidden_pref_save_varnames.Find(pref))
		return FALSE

	if (isemptylist(internal_table))
		internal_table = list()
	internal_table -= pref

	return TRUE
