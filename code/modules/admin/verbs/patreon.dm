/client/proc/give_patreon_rewards()
	set category = "Test"
	set name = "Give Patreon Rewards"
	if(!check_rights(R_HOST)) return
	var/_ckey = input(src, "What ckey?") as text
	if (!_ckey)
		return
	_ckey = ckey(_ckey)
	var/extra = ""
	var/cpledge = ""
	for (var/client/C in clients)
		if (C.ckey == _ckey)
			if (C.highest_patreon_level())
				cpledge = C.highest_patreon_level()
				extra = " They are a [cpledge] patron."
	if (!extra)
		var/list/table = database.execute("SELECT * FROM patreon WHERE user = '[_ckey]';")
		if (islist(table) && !isemptylist(table))
			cpledge = table["pledge"]
			extra = " They are a [cpledge] patron."

	var/pledge = input(src, "What pledge amount?[extra]") in list("$3+", "$5+", "$10+", "$15+", "$20+")
	if (pledge == cpledge)
		src << "<span class = 'bad'>This is their current patron level.</span>"
		return
	_ckey = sanitizeSQL(_ckey, 50)
	if (database.execute("INSERT INTO patreon (user, pledge) VALUES ('[_ckey]', '[pledge]');"))
		src << "<span class = 'good'>Successfully added '[_ckey]' as a [pledge] patron."
		var/M = "[key_name(src)] added '[_ckey]' as a [pledge] patron."
		log_admin(M)
		message_admins(M)
	else
		src << "<span class = 'danger'>A database error occured.</span>"
	spawn (5)
		remove_patreon_table_extras(_ckey)

/* keeps the patreon table small by removing any unecessary data. A person
 * who donated $10 gets $5 and $3 benefits too, so we don't need to store those,
 * and likewise, a person who donated $5 gets $3 benefits which are superfluous */

/proc/remove_patreon_table_extras(var/ckey)

	// we have $10, meaning we don't need $5 and $3
	var/list/_10check = database.execute("SELECT * FROM patreon WHERE user = '[ckey]' AND pledge = '$10+';")
	if (islist(_10check) && !isemptylist(_10check))
		database.execute("DELETE FROM patreon WHERE user = '[ckey]' AND pledge = '$5+';")
		database.execute("DELETE FROM patreon WHERE user = '[ckey]' AND pledge = '$3+';")

	// we have $5, meaning we don't need $3
	var/list/_5check = database.execute("SELECT * FROM patreon WHERE user = '[ckey]' AND pledge = '$5+';")
	if (islist(_5check) && !isemptylist(_5check))
		database.execute("DELETE FROM patreon WHERE user = '[ckey]' AND pledge = '$3+';")

/* to remove rewards */

/client/proc/remove_patreon_rewards()
	set category = "Test"
	set name = "Remove Patreon Rewards"
	if(!check_rights(R_HOST)) return
	var/_ckey = input(src, "What ckey?") as text
	if (!_ckey)
		return
	_ckey = ckey(_ckey)

	var/patreon_level = null

	for (var/client/C in clients)
		if (C.ckey == _ckey)
			patreon_level = C.highest_patreon_level()
			break

	if (!patreon_level)
		var/list/table = database.execute("SELECT * FROM patreon WHERE user = '[_ckey]';")
		if (islist(table) && !isemptylist(table))
			patreon_level = table["pledge"]

	if (!patreon_level)
		src << "<span class = 'danger'>This person isn't a patron, or the database failed to find them.</span>"
		return

	var/cont = input(src, "This person is a [patreon_level] patron. Continue?") in list ("Yes", "No")
	if (cont == "No")
		return

	_ckey = sanitizeSQL(_ckey, 50)
	if (database.execute("DELETE FROM patreon WHERE user = '[_ckey]';"))
		// there are no separate patreon lists but this is the easiest way to phrase it - kachnov
		src << "<span class = 'good'>Successfully REMOVED '[_ckey]' from the [patreon_level] patron list."
		var/M = "[key_name(src)] REMOVED '[_ckey]' from the [patreon_level] patron list."
		log_admin(M)
		message_admins(M)
	else
		src << "<span class = 'danger'>A database error occured.</span>"