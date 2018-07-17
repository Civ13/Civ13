#define GLOBAL_SLOT 99

var/list/forbidden_pref_save_varnames = list("client_ckey", "last_id")

/datum/preferences/proc/preferences_exist(var/slot = 1)
	slot = text2num(slot)
	var/list/table = database.execute("SELECT * FROM preferences WHERE ckey = '[client_ckey]' AND slot = '[slot]';")
	if (islist(table) && !isemptylist(table))
		return TRUE
	return FALSE

/datum/preferences/proc/get_DB_preference_value(name, slot = TRUE)
	if (!preferences_exist(slot))
		return ""
	var/table = database.execute("SELECT prefs FROM preferences WHERE ckey = '[client_ckey]' AND slot = '[slot]';")
	var/list/key_val_pairs = splittext(table["prefs"], "&")
	for (var/key_val_pair in key_val_pairs)
		var/keyval_list = splittext(key_val_pair, "=")
		var/key = keyval_list[1]
		var/val = keyval_list[2]
		if (key == name)
			return val

/datum/preferences/proc/load_preferences(var/slot = 1)

	if (text2num(slot) == 0)
		return FALSE

	slot = num2text(slot)
	if (!client_ckey)
		return FALSE

	var/list/table = database.execute("SELECT * FROM preferences WHERE ckey = '[client_ckey]' AND slot = '[slot]';")
	if (!islist(table) || isemptylist(table))
		return FALSE

	if (current_slot == slot)
		save_preferences(slot)

	if (internal_table.Find(slot))
		var/list/L = internal_table[slot]
		if (L)
			L.Cut()

	var/params = table["prefs"]
	var/list/key_val_pairs = splittext(params, "&")

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
	/*	else
			switch (key)
				if ("clientprefs_enabled")
					var/list/clientprefs_enabled = splittext(val, ";")
					if (clientprefs_enabled.len) // will return false if new char
						preferences_enabled.Cut()
						for (var/pref in clientprefs_enabled)
							preferences_enabled += pref
				if ("clientprefs_disabled")
					var/list/clientprefs_disabled = splittext(val, ";")
					if (clientprefs_disabled.len)
						preferences_disabled.Cut()
						for (var/pref in clientprefs_disabled)
							preferences_disabled += pref
*/

	for (var/varname in vars)
		if (key_val_pairs.Find(varname))
			if (isnum(vars[varname])) // if the initial var is a num
				vars[varname] = text2num(key_val_pairs[varname])
			else
				vars[varname] = key_val_pairs[varname]
		else // reset to default, getting rid of previous setting
			if (isnum(vars[varname]) || istext(vars[varname]) && !forbidden_pref_save_varnames.Find(varname))
				vars[varname] = initial(vars[varname])

	internal_table[slot] = key_val_pairs
	update_setup()

	return TRUE

/datum/preferences/proc/del_preferences(var/slot = TRUE)
	if (text2num(slot) == FALSE)
		return FALSE
	if (database.execute("DELETE FROM preferences WHERE ckey = '[client_ckey]' AND slot = '[slot]';"))
		if (internal_table.Find(slot))
			var/list/L = internal_table[slot]
			if (L)
				L.Cut()
		return TRUE
	return FALSE

/datum/preferences/proc/save_preferences(var/slot = 1, var/prevslot = -1)

	if (text2num(slot) == 0)
		return FALSE

	if (!client_ckey)
		return FALSE

	if (real_name == "PLACEHOLDER")
		real_name = "[capitalize(client.key)] #[slot]"

	var/name_to_remember = real_name
	for (var/num in 1 to internal_table.len)
		if (num != text2num(slot))
			var/list/table = internal_table["[num]"]
			if (table["real_name"] == real_name)
				name_to_remember = random_name(gender,species)

	slot = num2text(slot)

	if (prevslot == -1)
		if (!internal_table.Find(slot))
			internal_table[slot] = list()
		remember_preference("real_name", name_to_remember, FALSE) // don't save or inf. loop
	else
	//	world << "0: [prevslot]"
		var/internal_table_prev_slot = internal_table["[prevslot]"]
	//	world << "#1: [internal_table_prev_slot]["german_name"]"
		internal_table[slot] = copylist(internal_table_prev_slot)
		remember_preference("real_name", name_to_remember, FALSE)

	var/params = ""
	for (var/key in internal_table[slot])
		if (!vars.Find(key))
			continue
		if (internal_table[slot][key] == initial(vars[key]))
	//		world << "#2: [key]"
			continue
		if (params != "")
			params += "&"
		var/val = internal_table[slot][key]
		if (islist(val))
			params += "[key]={"
			for (var/x in val)
				params += "[x]"
				if (x != val[val:len])
					params += "|"
			params += "}"
		else
			params += "[key]=[val]"

/*	// client_preferences have to be saved separately
	if (preferences_enabled.len)
		if (params)
			params += "&"
		params += "clientprefs_enabled="
		for (var/pref in preferences_enabled)
			if (!pref) continue
			params += pref
			params += ";"*/

	if (dd_hassuffix(params, ";"))
		params = copytext(params, 1, lentext(params))
/*
	if (preferences_disabled.len)
		if (params)
			params += "&"
		params += "clientprefs_disabled="
		for (var/pref in preferences_disabled)
			if (!pref) continue
			params += pref
			params += ";"*/

	if (dd_hassuffix(params, ";"))
		params = copytext(params, 1, lentext(params))

	var/list/prefs_exist_check = database.execute("SELECT * FROM preferences WHERE ckey = '[client_ckey]' AND slot = '[slot]';")
	if (islist(prefs_exist_check) && !isemptylist(prefs_exist_check))
		database.execute("UPDATE preferences SET prefs = '[params]' WHERE ckey = '[client_ckey]' AND slot = '[slot]';")
	else
		database.execute("INSERT INTO preferences (ckey, slot, prefs) VALUES ('[client_ckey]', '[slot]', '[params]');")
	return TRUE

// slot preferences

/datum/preferences/proc/knows_preference(pref)
	var/slot = num2text(current_slot)
	if (!internal_table.Find(slot))
		return FALSE
	var/list/L = internal_table[slot]
	return L.Find(pref)

/datum/preferences/proc/remember_preference(pref, value, var/save = TRUE)
	if (!vars.Find(pref))
		return FALSE
	if (value == initial(vars[pref]))
		return FALSE
	if (forbidden_pref_save_varnames.Find(pref))
		return FALSE

	var/slot = num2text(current_slot)
	if (!internal_table.Find(slot))
		internal_table[slot] = list()
	internal_table[slot][pref] = value

	if (save)
		save_preferences(current_slot)

	return TRUE

/datum/preferences/proc/forget_preference(pref, var/save = TRUE, var/glob = FALSE)
	if (!vars.Find(pref))
		return FALSE
	if (forbidden_pref_save_varnames.Find(pref))
		return FALSE

	var/slot = num2text(current_slot)
	if (!internal_table.Find(slot))
		internal_table[slot] = list()
	internal_table[slot] -= pref

	if (save)
		save_preferences(current_slot)

	return TRUE

#undef GLOBAL_SLOT