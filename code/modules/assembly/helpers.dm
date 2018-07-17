/proc/isassembly(O)
	if (istype(O, /obj/item/assembly))
		return TRUE
	return FALSE

/proc/isigniter(O)
	if (istype(O, /obj/item/assembly/igniter))
		return TRUE
	return FALSE

/proc/isinfared(O)
	if (istype(O, /obj/item/assembly/infra))
		return TRUE
	return FALSE
/*
/proc/isprox(O)
	if (istype(O, /obj/item/assembly/prox_sensor))
		return TRUE
	return FALSE
*/
/proc/istimer(O)
	if (istype(O, /obj/item/assembly/timer))
		return TRUE
	return FALSE

/*
Name:	IsSpecialAssembly
Desc:	If true is an object that can be attached to an assembly holder but is a special thing like a plasma can or door
*/

/obj/proc/IsSpecialAssembly()
	return FALSE

/*
Name:	IsAssemblyHolder
Desc:	If true is an object that can hold an assemblyholder object
*/
/obj/proc/IsAssemblyHolder()
	return FALSE