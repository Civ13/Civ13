//type definitions

/obj/train_car_center // this is an object and not a datum because we use locations and it's probably a pain to recode that
	var/list/forwards_pseudoturfs = list() // for when we're going forwards - start from bottom down
	var/list/backwards_pseudoturfs = list() // for when we're going backwards - start from top up
	var/datum/train_controller/master = null
	var/turf/connector_turfs = list() // these are references to turfs and need to be regenerated every time we move.
	name = ""

	// debugging

	var/last_x_offset = -1
	var/last_y_offset = -1

/obj/train_car_center/proc/regenerate_connector_turfs()

	switch (master.orientation)

		if (VERTICAL)

			connector_turfs = list()

			var/middleX = FALSE
			var/minX = 1000000
			var/minY = 1000000

			for (var/object in forwards_pseudoturfs)
				var/obj/train_pseudoturf/tpt = object
				minX = min(minX, tpt.x)
				minY = min(minY, tpt.y)

			middleX = minX + 3 // todo : make this a constant based on train width

			//get pseudoturf TRUE - middle x, lowest y - 1
			var/turf/t1 = locate(middleX, minY-1, z)

			connector_turfs["turf"] = t1
			connector_turfs["dir"] = SOUTH // dir we're adding the connectors in is always SOUTH for vertical trains

		if (HORIZONTAL)

			connector_turfs = list()

			var/minY = 1000000
			var/middleY = FALSE
			var/maxX = FALSE

			for (var/object in forwards_pseudoturfs)
				var/obj/train_pseudoturf/tpt = object
				maxX = max(maxX, tpt.x)
				minY = min(minY, tpt.y)

			middleY = minY + 2 // todo : make this a constant based on train width

			//get pseudoturf TRUE - middle y, highest x + 1
			var/turf/t1 = locate(maxX+1, middleY, z)

			connector_turfs["turf"] = t1
			connector_turfs["dir"] = EAST // dir we're adding the connectors in is always EAST for horizontal trains

/obj/train_car_center/proc/print_loc(var/atom/a)
	return "[a.x],[a.y],[a.z]"

/obj/train_car_center/proc/connect_to(var/obj/train_car_center/other)
	if (other)
		regenerate_connector_turfs()
		var/turf/t1 = connector_turfs["turf"]
		if (t1)
			var/turf/t2 = null
			var/turf/t3 = null
			switch (master.orientation)
				if (VERTICAL)
					t2 = locate(t1.x+1, t1.y, t1.z)
					t3 = locate(t1.x-1, t1.y, t1.z)
				if (HORIZONTAL)
					t2 = locate(t1.x, t1.y+1, t1.z)
					t3 = locate(t1.x, t1.y-1, t1.z)

			var/dir = connector_turfs["dir"]

			var/railing_one_dir = WEST  // WEST so it's squeezing the connector
			var/railing_two_dir = EAST  // EAST so ditto

			if (master.orientation == HORIZONTAL)
				railing_one_dir = SOUTH
				railing_two_dir = NORTH

			for (var/v in 1 to 3)

				if (t1)
					master.add_connector(t1)
					t1 = get_step(t1, dir)

				if (t2)
					master.add_railing(t2, railing_one_dir)
					t2 = get_step(t2, dir)

				if (t3)
					master.add_railing(t3, railing_two_dir)
					t3 = get_step(t3, dir)


/obj/train_car_center/german

/obj/train_car_center/german/officer

/obj/train_car_center/german/storage

/obj/train_car_center/german/soldier

/obj/train_car_center/german/conductor

/obj/train_car_center/germansupply

/obj/train_car_center/russian

/obj/train_car_center/russian/officer

/obj/train_car_center/russian/storage

/obj/train_car_center/russian/soldier

/obj/train_car_center/russian/conductor

//_Move proc
/obj/train_car_center/proc/_Move(direction)

	var/list/pseudoturfs = forwards_pseudoturfs
	if (direction == "BACKWARDS")
		pseudoturfs = backwards_pseudoturfs //shoddy attempt to fix backwards moving.

	for (var/object in pseudoturfs)
		if (!object)
			pseudoturfs -= object
			continue
		var/obj/train_pseudoturf/tpt = object
		tpt.save_contents_as_refs()

		// the new behavior for destroying objects requires that we do it
		// prior to moving. We don't have to do so for gibbing, but I do it anyway
		// so gibs don't get all over train walls anymore - Kachnov

		processes.callproc.queue(tpt, /obj/train_pseudoturf/proc/gib_idiots, null, 0.3)
		processes.callproc.queue(tpt, /obj/train_pseudoturf/proc/destroy_objects, null, 0.6)
		#ifdef USE_TRAIN_LIGHTS
		processes.callproc.queue(tpt, /obj/train_pseudoturf/proc/reset_track_lights, null, 0.6)
		#endif
		processes.callproc.queue(tpt, /obj/train_pseudoturf/proc/_Move, null, 0.9)
		#ifdef USE_TRAIN_LIGHTS
		processes.callproc.queue(tpt, /obj/train_pseudoturf/proc/unset_track_lights, null, 0.9)
		#endif
		processes.callproc.queue(tpt, /obj/train_pseudoturf/proc/move_mobs, null, 1.2)
		processes.callproc.queue(tpt, /obj/train_pseudoturf/proc/remove_contents_refs, null, 1.5)

//Graft proc
/obj/train_car_center/proc/Graft(what)
	backwards_pseudoturfs = forwards_pseudoturfs

/obj/train_car_center/germansupply/Graft(what)
	switch (what)
		if ("horizontal-storage")
			var/area/a = locate(/area/prishtina/train/german/cabin/storage_horizontal)
			var/min_x = min_area_x(a)
			var/max_y = max_area_y(a) // start at the minimum x and maximum y, ie top left corner
			for (var/turf/T in a.contents)
				var/x_offset = T.x - min_x
				var/y_offset = max_y - T.y
				var/z = 1
				var/obj/train_pseudoturf/tpt = new/obj/train_pseudoturf(locate(x + x_offset,y - y_offset,z), T)
				tpt.master = src
				tpt.controller = master
				forwards_pseudoturfs += tpt
	..()


/obj/train_car_center/german/Graft(what)

	switch (what)
		if ("officer")
			var/area/a = locate(/area/prishtina/train/german/cabin/officer)
			var/min_x = min_area_x(a)
			var/max_y = max_area_y(a) // start at the minimum x and maximum y, ie top left corner
			for (var/turf/T in a.contents)
				var/x_offset = T.x - min_x
				var/y_offset = max_y - T.y
				var/z = 1
				var/obj/train_pseudoturf/tpt = new/obj/train_pseudoturf(locate(x + x_offset,y - y_offset,z), T)
				tpt.master = src
				tpt.controller = master
				forwards_pseudoturfs += tpt
		if ("storage")
			var/area/a = locate(/area/prishtina/train/german/cabin/storage)
			var/min_x = min_area_x(a)
			var/max_y = max_area_y(a) // start at the minimum x and maximum y, ie top left corner
			for (var/turf/T in a.contents)
				var/x_offset = T.x - min_x
				var/y_offset = max_y - T.y
				var/z = 1
				var/obj/train_pseudoturf/tpt = new/obj/train_pseudoturf(locate(x + x_offset,y - y_offset,z), T)
				tpt.master = src
				tpt.controller = master
				forwards_pseudoturfs += tpt
		if ("soldier")
			var/area/a = locate(/area/prishtina/train/german/cabin/soldier)
			var/min_x = min_area_x(a)
			var/max_y = max_area_y(a) // start at the minimum x and maximum y, ie top left corner
			for (var/turf/T in a.contents)
				var/x_offset = T.x - min_x
				var/y_offset = max_y - T.y
				var/z = 1
				var/obj/train_pseudoturf/tpt = new/obj/train_pseudoturf(locate(x + x_offset,y - y_offset,z), T)
				tpt.master = src
				tpt.controller = master
				forwards_pseudoturfs += tpt
		if ("conductor")
			var/area/a = locate(/area/prishtina/train/german/cabin/conductor)
			var/min_x = min_area_x(a)
			var/max_y = max_area_y(a) // start at the minimum x and maximum y, ie bottom left corner
			for (var/turf/T in a.contents)
				var/x_offset = T.x - min_x
				var/y_offset = max_y - T.y
				var/z = TRUE
				var/obj/train_pseudoturf/tpt = new/obj/train_pseudoturf(locate(x + x_offset,y - y_offset,z), T)
				tpt.master = src
				tpt.controller = master
				forwards_pseudoturfs += tpt
				last_x_offset = x_offset
				last_y_offset = y_offset

	..()


/obj/train_car_center/russian/Graft(what)
	return

// and no graft procs for specific cars/cabins

//New() procs

/obj/train_car_center/New(_loc, _master)
	..()

	loc = _loc
	master = _master

	train_car_centers += src

/obj/train_car_center/german/New(_loc, _master)
	..(_loc, _master)

	german_main_train_car_centers += src

/obj/train_car_center/germansupply/New(_loc, _master)
	..(_loc, _master)
	Graft("horizontal-storage")

	german_supply_train_car_centers += src

/obj/train_car_center/german/officer/New(_loc, _master)
	..(_loc, _master)
	Graft("officer")

/obj/train_car_center/german/storage/New(_loc, _master)
	..(_loc, _master)
	Graft("storage")

/obj/train_car_center/german/soldier/New(_loc, _master)
	..(_loc, _master)
	Graft("soldier")

/obj/train_car_center/german/conductor/New(_loc, _master)
	..(_loc, _master)
	Graft("conductor")

/obj/train_car_center/russian/New(_loc, _master)
	..(_loc, _master)

/obj/train_car_center/russian/officer/New(_loc, _master)
	return

/obj/train_car_center/russian/storage/New(_loc, _master)
	return

/obj/train_car_center/russian/soldier/New(_loc, _master)
	return

/obj/train_car_center/russian/conductor/New(_loc, _master)
	return