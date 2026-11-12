/process/casings/fire()
	var/list/turf2casings = list()

	// get casings
	for (current in current_list)
		var/obj/item/ammo_casing/A = current
		if (!isDeleted(A))
			if (A.loc && isturf(A.loc)) // so we don't delete ammo casings in guns or mags or nullspace
				if (!turf2casings[A.loc])
					turf2casings[A.loc] = 0
				++turf2casings[A.loc]
		else
			catchBadType(A)
			bullet_casings -= A

		PROCESS_LIST_CHECK
		PROCESS_TICK_CHECK
