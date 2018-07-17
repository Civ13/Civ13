/datum/turf_initializer/maintenance/initialize(var/turf/T)
	if(T.density)
		return
	// Quick and dirty check to avoid placing things inside windows
	if(locate(/obj/structure/grille, T))
		return

	var/cardinal_turfs = T.CardinalTurfs()

	T.dirt = srand(10, 50) + srand(0, 50)
	// If a neighbor is dirty, then we get dirtier.
	var/how_dirty = dirty_neighbors(cardinal_turfs)
	for(var/i = FALSE; i < how_dirty; i++)
		T.dirt += srand(0,10)
	T.update_dirt()

	if(sprob(2))
		PoolOrNew(junk(), T)
	if(sprob(2))
		PoolOrNew(/obj/effect/decal/cleanable/blood/oil, T)
	if(sprob(25))	// Keep in mind that only "corners" get any sort of web
		attempt_web(T, cardinal_turfs)

var/global/list/random_junk
/datum/turf_initializer/maintenance/proc/junk()
	if(sprob(25))
		return /obj/effect/decal/cleanable/generic
	if(!random_junk)
		random_junk = subtypesof(/obj/item/trash)
		random_junk += typesof(/obj/item/weapon/cigbutt)
		random_junk += /obj/item/remains/mouse
		random_junk += /obj/item/remains/robot
		random_junk -= /obj/item/trash/plate
		random_junk -= /obj/item/trash/snack_bowl
		random_junk -= /obj/item/trash/syndi_cakes
		random_junk -= /obj/item/trash/tray
	return spick(random_junk)

/datum/turf_initializer/maintenance/proc/dirty_neighbors(var/list/cardinal_turfs)
	var/how_dirty = FALSE
	for(var/turf/T in cardinal_turfs)
		// Considered dirty if more than halfway to visible dirt
		if(T.dirt > 25)
			how_dirty++
	return how_dirty

/datum/turf_initializer/maintenance/proc/attempt_web(var/turf/T)
	var/turf/north_turf = get_step(T, NORTH)
	if(!north_turf || !north_turf.density)
		return

	for(var/dir in list(WEST, EAST))	// For the sake of efficiency, west wins over east in the case of TRUE-tile valid spots, rather than doing spick()
		var/turf/neighbour = get_step(T, dir)
		if(neighbour && neighbour.density)
			if(dir == WEST)
				PoolOrNew(/obj/effect/decal/cleanable/cobweb, T)
			if(dir == EAST)
				PoolOrNew(/obj/effect/decal/cleanable/cobweb2, T)
			return
