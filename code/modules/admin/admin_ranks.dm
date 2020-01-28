var/list/admin_ranks = list()								//list of all ranks with associated rights

//load our rank - > rights associations
/proc/load_admin_ranks()
	admin_ranks.Cut()

	var/previous_rights = FALSE

	//load text from file
	var/list/Lines = file2list("config/admin_ranks.txt")

	//process each line seperately
	for (var/line in Lines)

		if (!length(line))				continue
		if (copytext(line,1,2) == "#")	continue

		var/list/List = splittext(line,"+")
		if (!List.len)					continue

		var/rank = ckeyEx(List[1])
		switch(rank)
			if (null,"")		continue
			if ("Removed")	continue				//Reserved

		var/rights = FALSE
		for (var/i=2, i<=List.len, i++)
			switch(ckey(List[i]))
				if ("@","prev")					rights |= previous_rights
				if ("buildmode","build")			rights |= R_BUILDMODE
				if ("admin")						rights |= R_ADMIN
				if ("trialadmin")				rights |= R_TRIALADMIN
				if ("fun")						rights |= R_FUN
				if ("server")					rights |= R_SERVER
				if ("debug")						rights |= R_DEBUG
				if ("permissions","rights")		rights |= R_PERMISSIONS
				if ("possess")					rights |= R_POSSESS
				if ("stealth")					rights |= R_STEALTH
				if ("rejuv","rejuvinate")		rights |= R_REJUVINATE
				if ("varedit")					rights |= R_VAREDIT
				if ("everything","host","all")	rights |= (R_HOST | R_BUILDMODE | R_ADMIN | R_TRIALADMIN | R_FUN | R_SERVER | R_DEBUG | R_PERMISSIONS | R_POSSESS | R_STEALTH | R_REJUVINATE | R_VAREDIT | R_SOUNDS | R_SPAWN | R_MOD| R_MENTOR)
				if ("sound","sounds")			rights |= R_SOUNDS
				if ("spawn","create")			rights |= R_SPAWN
				if ("mod")						rights |= R_MOD
				if ("mentor")					rights |= R_MENTOR

		admin_ranks[rank] = rights
		previous_rights = rights

	#ifdef TESTING
	var/msg = "Permission Sets Built:\n"
	for (var/rank in admin_ranks)
		msg += "\t[rank] - [admin_ranks[rank]]\n"
	testing(msg)
	#endif

var/loaded_admins = FALSE

/hook/startup/proc/loadAdmins()
	load_admins()
	return TRUE

/proc/load_admins(var/force = FALSE)
	if (loaded_admins && !force)
		return
	//clear the datums references
	admin_datums.Cut()
	for (var/client/C in admins)
		C.remove_admin_verbs()
		C.holder = null

	admins.Cut()

	load_admin_ranks()

	var/F = "SQL/admins.txt"
	if (!F)
		loaded_admins = TRUE
		return

	var/list/admincheck = splittext(file2text(F),"|||\n")
	if (islist(admincheck) && !isemptylist(admincheck))
		for(var/i in admincheck)
			var/list/admincheck_two = splittext(i, ";")
			if (admincheck_two.len >= 3 && admincheck_two[2] != "NONE")
				var/ckey = lowertext(admincheck_two[1])
				var/rank = admincheck_two[2]
				if (rank == "Removed") goto deadminned	//This person was de-adminned. They are only in the admin list for archive purposes.
				var/rights = admincheck_two[3]
				if (istext(rights))
					rights = text2num(rights)
				// make our admins datum and put us in admin_datums[]
				var/datum/admins/A = new/datum/admins(rank, rights, ckey)
				if (directory[ckey])
					A.associate(directory[ckey])
					/* moved association code to client/New(), so it works for clients
					   created at the same time as the world */

	//clean the list. Start from the end and skip repeated entries.
	var/list/admincheck2 = list()
	var/list/ckeyschecked = list()
	for(var/i=admincheck.len, i>=1, i--)
		var/list/admincheck_two = splittext(admincheck[i], ";")
		if (admincheck_two.len==3 && !(admincheck_two[1] in ckeyschecked))
			ckeyschecked += list(admincheck_two[1])
			admincheck2 += list(admincheck_two)
	fdel(F)
	for(var/list/nc in admincheck2)
		text2file("[nc[1]];[nc[2]];[nc[3]]|||",F)


	deadminned
	if (!admin_datums)
		loaded_admins = TRUE
		return

	#ifdef TESTING
	var/msg = "Admins Built:\n"
	for (var/ckey in admin_datums)
		var/rank
		var/datum/admins/D = admin_datums[ckey]
		if (D)	rank = D.rank
		msg += "\t[ckey] - [rank]\n"
	testing(msg)
	#endif

	loaded_admins = TRUE

#ifdef TESTING
/client/verb/changerank(newrank in admin_ranks)
	if (holder)
		holder.rank = newrank
		holder.rights = admin_ranks[newrank]
	else
		holder = new /datum/admins(newrank,admin_ranks[newrank],ckey)
	remove_admin_verbs()
	holder.associate(src)

/client/verb/changerights(newrights as num)
	if (holder)
		holder.rights = newrights
	else
		holder = new /datum/admins("testing",newrights,ckey)
	remove_admin_verbs()
	holder.associate(src)

#endif
