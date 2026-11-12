// Frozen source from Civ13 master 6f8adb761, used only by the offline parity fixture.
/obj/structure/vehicleparts/axis/aircraft/proc/aircraft_shift(target_z, dx = 0, dy = 0)
	if (!target_z || transforming_vehicle)
		return FALSE
	add_transporting(FALSE)
	var/list/movers = list()
	var/list/destinations = list()
	var/list/tiles = list()
	for (var/atom/movable/M in (transporting | components))
		if (QDELETED(M) || !isturf(M.loc))
			continue
		var/turf/D = locate(M.x + dx, M.y + dy, target_z)
		if (!D)
			return FALSE
		movers += M
		destinations[M] = D
		tiles |= M.loc
		tiles |= D
	transforming_vehicle = TRUE
	transform_tiles = tiles
	for (var/turf/T in tiles)
		T.vehicle_transforming = src
	try
		// Frames first, so whatever stands on them arrives on a floor.
		for (var/obj/structure/vehicleparts/frame/F in movers)
			F.forceMove(destinations[F])
		for (var/atom/movable/M in movers)
			if (istype(M, /obj/structure/vehicleparts/frame) || QDELETED(M))
				continue
			M.forceMove(destinations[M])
	catch (var/exception/e)
		release_transform_tiles(tiles)
		throw e
	release_transform_tiles(tiles)
	for (var/obj/O in movers)
		O.update_icon()
	refresh_passenger_vision()
	return TRUE

/obj/structure/vehicleparts/axis/ship/submarine/proc/shift_level(target_z)
	if (!target_z || transforming_vehicle)
		return FALSE
	add_transporting(FALSE)
	var/list/movers = list()
	var/list/destinations = list()
	var/list/tiles = list()
	for (var/atom/movable/M in (transporting | components))
		if (QDELETED(M) || !isturf(M.loc))
			continue
		var/turf/D = locate(M.x, M.y, target_z)
		if (!D)
			return FALSE
		movers += M
		destinations[M] = D
		tiles |= M.loc
		tiles |= D
	transforming_vehicle = TRUE
	transform_tiles = tiles
	for (var/turf/T in tiles)
		T.vehicle_transforming = src
	try
		// Frames first, so whatever stands on them arrives on a deck.
		for (var/obj/structure/vehicleparts/frame/F in movers)
			F.forceMove(destinations[F])
		for (var/atom/movable/M in movers)
			if (istype(M, /obj/structure/vehicleparts/frame) || QDELETED(M))
				continue
			M.forceMove(destinations[M])
	catch (var/exception/e)
		release_transform_tiles(tiles)
		throw e
	release_transform_tiles(tiles)
	for (var/obj/O in movers)
		O.update_icon()
	refresh_passenger_vision()
	return TRUE
