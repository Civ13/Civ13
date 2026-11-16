var/list/admin_ranks = list()								//list of all ranks with associated rights

//load our rank - > rights associations
/proc/load_admin_ranks()
	admin_ranks.Cut()

	var/previous_rights = FALSE

	//load text from file
	var/list/Lines = file2list("config/admin_ranks.txt")

	//process each line separately
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
// The admins file text the current admin list was built from; a login rebuilds the
// list when the file has changed since (the Discord bot rewrites it on role changes).
var/loaded_admins_text = null
var/admins_file_path = null

/hook/startup/proc/loadAdmins()
	load_admins()
	return TRUE

// Every region of a shard group reads the admins file of the world CivilizationBot
// watches (the relay's gate, else the mainland), which the bot keeps in step with
// staff roles. Region worktrees are siblings under the group root
// (scripts/shard-group/shard_group.py region_dir), so that file is
// ../<gate>/SQL/admins.txt. A lone server, and that world itself, use their own.
// The gate stays put when the host moves the mainland (Gaia, 2026-11-15).
/proc/admins_file()
	if (admins_file_path)
		return admins_file_path
	admins_file_path = "SQL/admins.txt"
	if (fexists("config/shard_region.json"))
		var/list/settings = null
		try
			settings = json_decode(file2text("config/shard_region.json"))
		catch
			settings = null
		if (islist(settings))
			var/source = istext(settings["gate"]) ? settings["gate"] : settings["mainland"]
			var/region = settings["region"]
			var/shared = "../[source]/SQL/admins.txt"
			// A group that has moved its front door keeps one copy beside the regions
			// (shard_group.py adopt_front_door), so no later move has to carry it.
			if (shard_id_valid(region) && fexists("../front-door/SQL/admins.txt"))
				admins_file_path = "../front-door/SQL/admins.txt"
			else if (shard_id_valid(source) && shard_id_valid(region) && source != region && fexists(shared))
				admins_file_path = shared
	return admins_file_path

/proc/admins_file_text()
	var/F = admins_file()
	if (!fexists(F))
		return ""
	var/text = file2text(F)
	if (!istext(text))
		return ""
	// The loader splits on "|||\n"; a file saved with Windows line endings must too.
	return replacetext(text, ascii2text(13), "")

/proc/load_admins(var/force = FALSE)
	if (loaded_admins && !force)
		if (admins_file_text() == loaded_admins_text)
			return
		log_admin("Admins file [admins_file()] changed; rebuilding the admin list.")
	//clear the datums references
	admin_datums.Cut()
	for (var/client/C in admins)
		C.remove_admin_verbs()
		C.holder = null

	admins.Cut()

	load_admin_ranks()

	var/F = admins_file()
	var/admin_text = admins_file_text()

	var/list/admincheck = splittext(admin_text,"|||\n")
	if (islist(admincheck) && !isemptylist(admincheck))
		for(var/i in admincheck)
			var/list/admincheck_two = splittext(i, ";")
			if (admincheck_two.len >= 3 && admincheck_two[2] != "NONE")
				var/ckey = lowertext(admincheck_two[1])
				var/rank = admincheck_two[2]
				if (rank == "Removed")	//This person was de-adminned. They are only in the admin list for archive purposes.
					continue
				var/rights = admincheck_two[3]
				if (istext(rights))
					rights = text2num(rights)
				// make our admins datum and put us in admin_datums[]
				var/datum/admins/A = new/datum/admins(rank, rights, ckey)
				if (directory[ckey])
					A.associate(directory[ckey])
					/* moved association code to client/New(), so it works for clients
					   created at the same time as the world */

	// Only the file's owner tidies it: a region reading the mainland's shared file
	// must not rewrite it under the mainland (or the other regions) reading it.
	if (F == "SQL/admins.txt" && fexists(F))
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
	loaded_admins_text = admins_file_text()

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
