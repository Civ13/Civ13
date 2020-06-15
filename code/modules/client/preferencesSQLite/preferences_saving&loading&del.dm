var/list/forbidden_pref_save_varnames = list("client_ckey", "last_id")

/datum/preferences/proc/preferences_exist(var/list/l_charprefs = list())
	if (isemptylist(l_charprefs))
		return FALSE
	var/F = file("SQL/charprefs.txt")
	var/list/charprefs = splittext(file2text(F), "|||\n")
	for (var/i=1;i<charprefs.len;i++)
		var/list/charprefs2 = splittext(charprefs[i], ";")
		if (charprefs2[1] == client_ckey)
			return TRUE
	return FALSE

/datum/preferences/proc/load_preferences(var/list/charprefs = list())

	if (!client_ckey)
		return FALSE
	if (isemptylist(charprefs))
		charprefs = splittext(file2text("SQL/charprefs.txt"), "|||\n")

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
				var/list = replacetext(replacetext(val, "{", ""), "}", "")
				list = splittext(list, "|")
				for (var/something in list)
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

	for(var/prf in preferences_disabled)
		preferences_enabled -= prf

	update_setup()

	return TRUE

/datum/preferences/proc/save_preferences(var/list/charprefs = list())

	if (!client || !client_ckey || !client.key)
		return FALSE

	if (real_name == "PLACEHOLDER")
		real_name = "[capitalize(client.key)]"

	if (client && real_name == capitalize(client.key))
		real_name = random_name(gender,species)

	var/list/vars_to_save = list("preferences_disabled", "UI_style", "UI_file", "UI_useborder", "UI_style_color", "UI_style_alpha", "lobby_music_volume", "cursor", "real_name", "be_random_name", "be_random_body", "gender", "age", "b_type", "h_style", "hair_color", "facial_color", "eye_color", "r_hair", "g_hair", "b_hair", "f_style", "r_facial", "g_facial", "b_facial", "s_tone", "r_skin", "g_skin", "b_skin", "r_eyes", "g_eyes", "b_eyes", "traits")

	for (var/i in traits)
		if (!(i in trait_list))
			traits -= i

	var/params = ""
	for (var/key in vars_to_save)
		if (!vars.Find(key))
			continue
		var/val = vars[key]
		if (vars[key] == initial(vars[key]))
			continue
		if (params != "")
			params += "&"
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
		params = copytext(params, 1, length(params))


	if (dd_hassuffix(params, ";"))
		params = copytext(params, 1, length(params))
	var/F = file("SQL/charprefs.txt")
	var/done1 = FALSE
	if (isemptylist(charprefs))
		charprefs = splittext(file2text(F), "|||\n")
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