var/list/admin_datums = list()

/datum/admins
	var/rank			= "Temporary Admin"
	var/client/owner	= null
	var/rights = FALSE
	var/fakekey			= null

	var/datum/weakref/marked_datum_weak

/datum/admins/proc/OOC_rank()
	switch (rank)
		if ("Admiral")
			return "Admiral"
		if ("Captain")
			return "Captain"
		if ("Sergeant")
			return "Sergeant"
		if ("HeadAdmin")
			return "Headmin"
		if ("DebugHost")
			return "Host"
	return rank

/datum/admins/proc/marked_datum()
	if (marked_datum_weak)
		return marked_datum_weak.resolve()

/datum/admins/New(initial_rank = "Temporary Admin", initial_rights = FALSE, ckey)

	if (!ckey)
		error("Admin datum created without a ckey argument. Datum has been deleted")
		qdel(src)
		return

	rank = initial_rank
	rights = initial_rights

	if (rights == FALSE)
		rights = admin_ranks[ckeyEx(rank)]

//	world << "rights #1: [rights]"

	if (istext(rights))
		rights = text2num(rights)
/*
	for (var/x in admin_ranks)
		world << "[x] = [admin_ranks[x]]"

	world << "rights for admin_rank [ckeyEx(rank)]/[initial_rank] = [rights]; initial_rights = [initial_rights]"
*/
	admin_datums[ckey] = src

/datum/admins/proc/associate(client/C)
	if (istype(C))
		owner = C
		owner.holder = src
		owner.add_admin_verbs()
		admins |= C

/datum/admins/proc/disassociate()
	if (owner)
		admins -= owner
		owner.remove_admin_verbs()
		owner.deadmin_holder = owner.holder
		owner.holder = null

/datum/admins/proc/reassociate()
	if (owner)
		admins |= owner
		owner.holder = src
		owner.deadmin_holder = null
		owner.add_admin_verbs()


/client/proc/deadmin()
	if (holder)
		holder.disassociate()
	return TRUE
