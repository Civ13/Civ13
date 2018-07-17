/client/proc/highest_patreon_level()
	if (isPatron("$3+"))
		if (isPatron("$5+"))
			if (isPatron("$10+"))
				if (isPatron("$15+"))
					if (isPatron("$20+"))
						return "$20+"
					return "$15+"
				return "$10+"
			return "$5+"
		return "$3+"
	return null

/client/proc/isPatron(pledge = "$3+")
	var/number = text2num(replacetext(replacetext(pledge, "$", ""), "+", ""))
	if (serverswap && serverswap.Find("masterdir"))
		var/list/patron2pledge = file2list("[serverswap["masterdir"]]patrons.txt")
		for (var/string in patron2pledge)
			var/list/splitString = splittext(string, "=")
			if (splitString.len)
				var/patron = ckey(splitString[1])
				// ignore second field, discord id
				var/pledge2 = text2num(splitString[3])
				if (patron == ckey && pledge2 >= number)
					return TRUE
	return FALSE

/client/proc/enable_disable_dabs()
	set category = "Patron"
	set name = "Enable/Disable Dabbing"
	config.allow_dabbing = !config.allow_dabbing
	if (config.allow_dabbing)
		world << "<big>[key] has enabled *dab.</big>"
	else
		world << "<big>[key] has disabled *dab.</big>"