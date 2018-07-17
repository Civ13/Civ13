/datum/train_controller
	var/faction = null
	var/list/train_car_centers = list()
	var/list/reverse_train_car_centers = list()
	var/list/train_connectors = list()
	var/list/train_railings = list()
	var/list/reverse_train_connectors = list()
	var/list/reverse_train_railings = list()
	var/officer_cars = TRUE
	var/storage_cars = TRUE
	var/soldier_cars = TRUE
	var/conductor_cars = TRUE
	var/total_cars = FALSE
	var/total_height = FALSE
	var/total_width = FALSE

	var/obj/effect/landmark/train/starting_point = null
	var/obj/effect/landmark/train/limit_point = null

	var/orientation = VERTICAL
	var/direction = "FORWARDS" // right now, trains only move north to south (forwards) and south to north (backwards)
	// They don't reverse yet, because that's fucking annoying to do.
	var/moving = FALSE // are we moving?
	var/halting = FALSE // did the conductor stop us?
//	var/finishing_halting = FALSE // did we halt recently? don't play movement sounds
	var/velocity = 2.50 // previously 3.0
	var/started_moving = FALSE  // calls train_start hook when set to TRUE for the first time
	var/list/last_played[2] // movement, halting sounds
	var/playing = "" // ditto
	var/obj/train_car_center/last_car = null // the car closest to the front of the train
	var/obj/train_car_center/first_car = null // the car closest to the back of the train
	var/inc[2] // FORWARDS = -1, BACKWARDS = +1
	var/my_tcc_type = null

	var/halting_sound_delay = 100
	var/movement_sound_delay = 50

	var/invisible = FALSE // disappear into the void

/datum/train_controller/proc/get_lever()
	for (var/obj/train_lever/lever in lever_list)
		if (lever.loc && lever.faction == faction && lever.real)
			return lever
	return null

/datum/train_controller/german/get_lever()
	for (var/obj/train_lever/lever in lever_list)
		if (lever.loc && istype(lever, /obj/train_lever/german) && lever.real)
			return lever
	return null

/datum/train_controller/german_supply_controller/get_lever()
	return null

/datum/train_controller/russian/get_lever()
	for (var/obj/train_lever/lever in lever_list)
		if (lever.loc && istype(lever, /obj/train_lever/russian) && lever.real)
			return lever
	return null
/*
/datum/train_controller/proc/get_next_mob_move(var/mob/m, var/dir)

	switch (dir)
		if (NORTH)
			return list("x" = FALSE, "y" = TRUE)
		if (SOUTH)
			return list("x" = FALSE, "y" = -1)
		if (EAST)
			return list("x" = TRUE, "y" = FALSE)
		if (WEST)
			return list("x" = -1, "y" = FALSE)*/
/*
	var/dir2x[0]
	var/dir2y[0]

	// use dir2text because maps don't support numerical keys

	dir2x[dir2text(EAST)] = TRUE
	dir2x[dir2text(WEST)] = -1
	dir2x[dir2text(NORTH)] = FALSE
	dir2x[dir2text(SOUTH)] = FALSE

	dir2y[dir2text(EAST)] = FALSE
	dir2y[dir2text(WEST)] = FALSE
	dir2y[dir2text(NORTH)] = TRUE
	dir2y[dir2text(SOUTH)] = -1

	if (moving)
		switch (direction)
			if ("FORWARDS")
				return locate(m.x+dir2x[dir2text(dir)], m.y-1+dir2y[dir2text(dir)], m.z)
			if ("BACKWARDS")
				return locate(m.x+dir2x[dir2text(dir)], m.y+1+dir2y[dir2text(dir)], m.z)
	else
		return null
*/
/datum/train_controller/New(_faction)

	faction = _faction

	inc["FORWARDS"] = -1
	inc["BACKWARDS"] = TRUE

	last_played["movement"] = -1
	last_played["halting"] = -1

	switch (faction)
		if (GERMAN)
			my_tcc_type = /obj/train_car_center/german
			officer_cars = config.german_train_cars_officer
			storage_cars = config.german_train_cars_storage
			soldier_cars = config.german_train_cars_soldier
			conductor_cars = config.german_train_cars_conductor
			total_cars = officer_cars + storage_cars + soldier_cars + conductor_cars

			starting_point = locate_type(landmarks_list, /obj/effect/landmark/train/german_train_start)
			limit_point = locate_type(landmarks_list, /obj/effect/landmark/train/german_train_limit)

			if (!starting_point || !limit_point || !istype(starting_point) || !istype(limit_point))
				return // nope

			var/starting_y = starting_point.y
			var/starting_x = starting_point.x
			var/starting_z = starting_point.z

			var/off_di = getAreaDimensions(src, "officer")
			var/st_di = getAreaDimensions(src, "storage")
			var/so_di = getAreaDimensions(src, "soldier")
			var/con_di = getAreaDimensions(src, "conductor")

		//	var/cars_width = (off_di["width"] + st_di["width"] + so_di["width"] + con_di["width"])
			var/cars_height = (off_di["height"] + st_di["height"] + so_di["height"] + con_di["height"])

			var/num_spaces = total_cars - 1 // 2 cars = TRUE space, etc
			var/extra_height = SPACES_BETWEEN_CARS * num_spaces

			total_height = cars_height + extra_height

			var/max_dist = abs(starting_point.y - limit_point.y) + 1

			if (total_height > max_dist)
				return // we fucked up. This is a huge train, or there isn't much space between the starting and limit
						// points.

			//	otherwise, continue

			var/y_inc = FALSE
			var/found_first_car = FALSE

			for (var/v in 1 to officer_cars)
				var/obj/train_car_center/tcc = new/obj/train_car_center/german/officer(locate(starting_x, starting_y + y_inc, starting_z), src)
				y_inc -= off_di["height"]
				y_inc -= SPACES_BETWEEN_CARS
				train_car_centers += tcc
				last_car = tcc

				if (!found_first_car)
					first_car = tcc
					found_first_car = TRUE

			for (var/v in 1 to soldier_cars)
				var/obj/train_car_center/tcc = new/obj/train_car_center/german/soldier(locate(starting_x, starting_y + y_inc, starting_z), src)
				y_inc -= so_di["height"]
				y_inc -= SPACES_BETWEEN_CARS
				train_car_centers += tcc
				last_car = tcc

				if (!found_first_car)
					first_car = tcc
					found_first_car = TRUE

			for (var/v in 1 to storage_cars) // this makes unboarding way easier
				var/obj/train_car_center/tcc = new/obj/train_car_center/german/storage(locate(starting_x, starting_y + y_inc, starting_z), src)
				y_inc -= st_di["height"]
				y_inc -= SPACES_BETWEEN_CARS
				train_car_centers += tcc
				last_car = tcc

				if (!found_first_car)
					first_car = tcc
					found_first_car = TRUE

			for (var/v in 1 to conductor_cars)
				var/obj/train_car_center/tcc = new/obj/train_car_center/german/conductor(locate(starting_x, starting_y + y_inc, starting_z), src)
				y_inc -= con_di["height"]
				y_inc -= SPACES_BETWEEN_CARS
				train_car_centers += tcc
				last_car = tcc

				if (!found_first_car)
					first_car = tcc
					found_first_car = TRUE

			generate_connectors()
			reverse_train_car_centers = reverselist(train_car_centers)

			// and we're done

		if (SOVIET)
			return // not implemented lmao

		if ("GERMAN-SUPPLY")

			// reverse our movement because BYOND uses a meme y axis
			inc["FORWARDS"] = TRUE
			inc["BACKWARDS"] = -1

			orientation = HORIZONTAL

			my_tcc_type = /obj/train_car_center/germansupply
			storage_cars = config.german_train_cars_supply
			total_cars = storage_cars

			starting_point = locate_type(landmarks_list, /obj/effect/landmark/train/german_supplytrain_start)
			limit_point = locate_type(landmarks_list, /obj/effect/landmark/train/german_supplytrain_limit) in world

			if (!starting_point || !limit_point || !istype(starting_point) || !istype(limit_point))
				return // nope

			var/starting_y = starting_point.y
			var/starting_x = starting_point.x
			var/starting_z = starting_point.z

			var/st_di = getAreaDimensions(src, "supply")

			var/cars_width = st_di["width"]

			var/num_spaces = total_cars - 1 // 2 cars = TRUE space, etc
			var/extra_width = SPACES_BETWEEN_CARS * num_spaces

			total_width = cars_width + extra_width

			var/max_dist = abs(limit_point.x - starting_point.x) + 1

			if (total_width > max_dist)
				return // we fucked up. This is a huge train, or there isn't much space between the starting and limit
						// points.

			//	otherwise, continue

			var/x_inc = FALSE
			var/found_first_car = FALSE

			for (var/v in 1 to storage_cars) // this makes unboarding way easier
				var/obj/train_car_center/tcc = new/obj/train_car_center/germansupply(locate(starting_x+x_inc, starting_y, starting_z), src)
				x_inc += st_di["width"]
				x_inc += SPACES_BETWEEN_CARS
				train_car_centers += tcc
				last_car = tcc

				if (!found_first_car)
					first_car = tcc
					found_first_car = TRUE

			generate_connectors()
			reverse_train_car_centers = reverselist(train_car_centers)

			spawn (0)
				var/datum/train_controller/german_supplytrain_controller/train = src
				for (var/obj/item/weapon/paper/supply_train_requisitions_sheet/paper in paper_list)
					paper.memo = "<br><i>As of the time this was printed, you have [train.supply_points] Supply Requisition Points remaining.</i>"
					paper.regenerate_info()
					break

/datum/train_controller/proc/start_moving(var/_direction) // when the conductor decides to move

	direction = _direction
	moving = TRUE

	var/obj/train_lever/lever = get_lever()

	if (lever)

		switch (direction)
			if ("FORWARDS")
				lever.icon_state = lever.pushed_state
			if ("BACKWARDS")
				lever.icon_state = lever.pulled_state

		lever.direction = direction

/datum/train_controller/proc/stop_moving()

	moving = FALSE
	halting = FALSE

	var/obj/train_lever/lever = get_lever()
	if (lever)
		lever.icon_state = lever.none_state
		lever.direction = "NONE"

	for (var/railing in train_railings)
		if (!railing)
			train_railings -= railing
			continue
		var/atom/R = railing
		R.pixel_y = 0

/datum/train_controller/german_supplytrain_controller/proc/update_invisibility(var/on = FALSE)

	invisible = on

	if (on) // make us invisible
		spawn (20)
			for (var/a in train_car_centers)
				if (!a)
					train_car_centers -= a
					continue
				var/obj/train_car_center/tcc = a
				for (var/b in tcc.forwards_pseudoturfs)
					if (!b)
						tcc.forwards_pseudoturfs -= b
						continue
					var/obj/train_pseudoturf/tpt = b
					if (!tpt.loc)
						continue
					tpt.invisibility = 100
					tpt.density = FALSE
					tpt.opacity = FALSE
					for (var/atom_movable in tpt.loc.contents|tpt.vis_contents)
						if (!istype(atom_movable, /obj/effect) && !istype(atom_movable, /obj/train_track) && !istype(atom_movable, /obj/structure/closet))
							var/atom/movable/AM = atom_movable
							AM.invisibility = 100
							AM.density = FALSE
							AM.opacity = FALSE
						if (istype(atom_movable, /obj/structure/light))
							var/obj/structure/light/L = atom_movable
							L.on = FALSE
							L.update(0, TRUE, TRUE)

			for (var/connector in train_connectors)
				if (!connector)
					train_connectors -= connector
					continue
				var/atom/A = connector
				A.invisibility = 100
				A.density = FALSE
				A.opacity = FALSE

			for (var/railing in train_railings)
				if (!railing)
					train_railings -= railing
					continue
				var/atom/A = railing
				A.invisibility = 100
				A.density = FALSE
				A.opacity = FALSE
	else
		for (var/a in train_car_centers)
			if (!a)
				train_car_centers -= a
				continue
			var/obj/train_car_center/tcc = a
			for (var/b in tcc.forwards_pseudoturfs)
				if (!b)
					tcc.forwards_pseudoturfs -= b
					continue
				var/obj/train_pseudoturf/tpt = b
				if (!tpt.loc)
					continue
				tpt.invisibility = FALSE
				tpt.density = tpt.initial_density
				tpt.opacity = tpt.initial_opacity
				for (var/atom_movable in tpt.loc.contents|tpt.vis_contents)
					if (!istype(atom_movable, /obj/effect) && !istype(atom_movable, /obj/train_track) && !istype(atom_movable, /obj/structure/closet))
						var/atom/movable/AM = atom_movable
						AM.invisibility = 0
						AM.density = AM.initial_density
						AM.opacity = AM.initial_opacity
					if (istype(atom_movable, /obj/structure/light))
						var/obj/structure/light/L = atom_movable
						L.on = TRUE
						L.update(0, TRUE, TRUE)
					else if (istype(atom_movable, /obj/structure/simple_door/key_door/anyone/train))
						var/obj/structure/simple_door/key_door/anyone/train/door = atom_movable
						door.density = TRUE
						door.opacity = TRUE
						door.state = FALSE
						door.icon_state = door.material.name

		for (var/connector in train_connectors)
			if (!connector)
				train_connectors -= connector
				continue
			var/atom/A = connector
			A.invisibility = 0
			A.density = A.initial_density
			A.opacity = A.initial_opacity

		for (var/railing in train_railings)
			if (!railing)
				train_railings -= railing
				continue
			var/atom/A = railing
			A.invisibility = 0
			A.density = A.initial_density
			A.opacity = A.initial_opacity

/datum/train_controller/proc/stop_moving_slow() // when the conductor decides to stop
	velocity = 1.0
	halting = TRUE

	spawn (50)
		moving = FALSE
		halting = FALSE
		velocity = initial(velocity)
		var/obj/train_lever/lever = get_lever()
		lever.icon_state = lever.none_state
		lever.direction = "NONE"

		for (var/railing in train_railings)
			if (!railing)
				train_railings -= railing
				continue
			var/atom/R = railing
			R.pixel_y = 0

/datum/train_controller/proc/started_moving()
	if (!started_moving)
		started_moving = TRUE
		if (faction != "GERMAN-SUPPLY")
			callHook("train_move")

/datum/train_controller/proc/getMoveInc()
	return inc[direction] * TRUE

/datum/train_controller/german_supplytrain_controller/Process()
	..()

	if (direction == "BACKWARDS" && !moving)
		for (var/a in train_car_centers)
			if (!a)
				train_car_centers -= a
				continue
			var/obj/train_car_center/tcc = a
			for (var/b in tcc.forwards_pseudoturfs)
				if (!b)
					tcc.forwards_pseudoturfs -= b
					continue
				var/obj/train_pseudoturf/tpt = b
				if (tpt.loc)
					for (var/obj/item/weapon/paper/supply_train_requisitions_sheet/paper in tpt.loc.contents)
						paper.supplytrain_process(src)

/datum/train_controller/proc/Process()
	if (moving)
		if (can_move_check())
			spawn (10)
				started_moving() // regardless of what triggers us to move, make it start the round.

			if (direction == "FORWARDS")
				for (var/object in train_car_centers)
					if (!object)
						train_car_centers -= object
						continue
					var/obj/train_car_center/tcc = object
					tcc._Move(direction)
				// this way if connectors runtime, it won't stop the main train from moving
				move_connectors(0)
			else if (direction == "BACKWARDS")
				for (var/object in reverse_train_car_centers)
					if (!object)
						reverse_train_car_centers -= object
						continue
					var/obj/train_car_center/tcc = object
					tcc._Move(direction)
				// this way if connectors runtime, it won't stop the main train from moving
				move_connectors(1)
		else
			moving = FALSE
			var/obj/train_lever/lever = get_lever()
			if (lever)
				lever.icon_state = lever.none_state
				lever.direction = "NONE"
			for (var/railing in train_railings)
				if (!railing)
					train_railings -= railing
					continue
				var/atom/R = railing
				R.pixel_y = 0

/datum/train_controller/proc/move_connectors(var/reverse = FALSE)

	if (!moving)
		return

	var/list/tcs = train_connectors
	var/list/trs = train_railings

	if (reverse)
		tcs = reverse_train_connectors
		trs = reverse_train_railings

	for (var/object in tcs)
		if (!object)
			tcs -= object
			continue

		var/obj/train_connector/tc = object
		tc.save_contents_as_refs()

		processes.callproc.queue(tc, /obj/train_connector/proc/_Move, null, 0.3)
		processes.callproc.queue(tc, /obj/train_connector/proc/move_mobs, null, 0.6)
		processes.callproc.queue(tc, /obj/train_connector/proc/remove_contents_refs, null, 0.9)

	for (var/object in trs)
		if (!object)
			trs -= object
			continue
		var/obj/structure/railing/train_railing/tr = object
		tr._Move()

/datum/train_controller/proc/generate_connectors()

	unoccupy_connectors()
	unoccupy_railings()

	for (var/v in 1 to train_car_centers.len-1)
		var/obj/train_car_center/current = train_car_centers[v]
		var/obj/train_car_center/next = train_car_centers[v+1]
		current.connect_to(next)

	reverse_train_connectors = reverselist(train_connectors)
	reverse_train_railings = reverselist(train_railings)

/datum/train_controller/proc/unoccupy_connectors()
	for (var/object in train_connectors)
		if (!object)
			train_connectors -= object
			continue
		var/obj/train_connector/tc = object
		tc.occupied = FALSE
		tc.loc = null

/datum/train_controller/proc/unoccupy_railings()
	for (var/object in train_railings)
		if (!object)
			train_railings -= object
			continue
		var/obj/structure/railing/train_railing/tr = object
		tr.occupied = FALSE
		tr.loc = null

/datum/train_controller/proc/add_connector(var/turf/t)

	var/obj/train_connector/using = null

	for (var/object in train_connectors)
		var/obj/train_connector/tc = object
		if (!tc.occupied)
			using = tc
			break

	if (!using)
		var/obj/train_connector/newc = new/obj/train_connector() // experimental location unique to this map
		using = newc
		train_connectors += newc

	using.master = src
	using.occupied = TRUE
	using.loc = t

/datum/train_controller/proc/add_railing(var/turf/t, var/_dir)

	var/obj/train_connector/using = null

	for (var/object in train_railings)
		var/obj/structure/railing/train_railing/tr = object
		if (!tr.occupied)
			using = tr
			break

	if (!using)
		var/obj/structure/railing/train_railing/tr = new/obj/structure/railing/train_railing() // experimental location unique to this map
		using = tr
		train_railings += tr

	using.master = src
	using.occupied = TRUE
	using.loc = t
	using.dir = _dir

/datum/train_controller/proc/can_move_check()

	switch (direction)

		if ("FORWARDS")
			for (var/a in train_car_centers)
				if (!a)
					train_car_centers -= a
					continue
				var/obj/train_car_center/tcc = a
				if (!last_car || last_car == tcc)
					for (var/b in tcc.forwards_pseudoturfs)
						if (!b)
							tcc.forwards_pseudoturfs -= b
							continue
						var/obj/train_pseudoturf/tpt = b
						switch (orientation)
							if (VERTICAL)
								if (tpt.y + getMoveInc() < limit_point.y) // since y decreases as we go down
									if (istype(src, /datum/train_controller/german_train_controller))
										spawn (3000)
											mapcheck_train_arrived = TRUE
									return FALSE // + getMoveInc() because getMoveInc() handles signs
							if (HORIZONTAL)
								if (tpt.x + getMoveInc() > limit_point.x)
									return FALSE // + getMoveInc() because getMoveInc() handles signs

		if ("BACKWARDS")
			for (var/a in reverse_train_car_centers)
				if (!a)
					reverse_train_car_centers -= a
					continue
				var/obj/train_car_center/tcc = a
				if (!first_car || first_car == tcc)
					for (var/b in tcc.backwards_pseudoturfs)
						if (!b)
							tcc.backwards_pseudoturfs -= b
							continue
						var/obj/train_pseudoturf/tpt = b
						switch (orientation)
							if (VERTICAL)
								if (tpt.y + getMoveInc() > starting_point.y)
									return FALSE
							if (HORIZONTAL)
								if (tpt.x + getMoveInc() < starting_point.x)
									return FALSE
	return TRUE

/datum/train_controller/proc/coming_to_halt()
	if (moving && can_move_check())

		if (halting)
			return TRUE

		switch (direction)

			if ("FORWARDS")
				for (var/a in train_car_centers)
					if (!a)
						train_car_centers -= a
						continue
					var/obj/train_car_center/tcc = a
					for (var/b in tcc.forwards_pseudoturfs)
						if (!b)
							tcc.forwards_pseudoturfs -= b
							continue
						var/obj/train_pseudoturf/tpt = b
						switch (orientation)
							if (VERTICAL)
								if (abs(tpt.y - limit_point.y) < 20) // since y decreases as we go down
									return TRUE
							if (HORIZONTAL)
								if (abs(tpt.x - limit_point.x) < 20) // since y decreases as we go down
									return TRUE
			if ("BACKWARDS")
				for (var/a in train_car_centers)
					if (!a)
						train_car_centers -= a
						continue
					var/obj/train_car_center/tcc = a
					for (var/b in tcc.backwards_pseudoturfs)
						if (!b)
							tcc.backwards_pseudoturfs -= b
							continue
						var/obj/train_pseudoturf/tpt = b
						switch (orientation)
							if (VERTICAL)
								if (abs(tpt.y - starting_point.y) < 20) // since y decreases as we go down
									return TRUE
							if (HORIZONTAL)
								if (abs(tpt.x - starting_point.x) < 20) // since y decreases as we go down
									return TRUE
	return FALSE


/datum/train_controller/proc/sound_loop()

	//prioritize haltings
	if (last_played["halting"] == -1 || world.time - last_played["halting"] >= halting_sound_delay)
		if (coming_to_halt() && playing == "")
			last_played["halting"] = world.time
			play_halting_sound()
			playing = "halting"
			spawn (halting_sound_delay)
				playing = ""

	if (last_played["movement"] == -1 || world.time - last_played["movement"] >= movement_sound_delay)
		if (moving && can_move_check() && playing == "")
			last_played["movement"] = world.time
			play_movement_sound()
			playing = "movement"
			spawn (movement_sound_delay)
				playing = ""

/datum/train_controller/proc/play_movement_sound()
	play_train_sound("train_movement")

/datum/train_controller/proc/play_halting_sound()
	play_train_sound("train_halting")

/datum/train_controller/proc/play_train_sound(var/sound)

	var/soundin = get_sfx(sound)
	var/sound/S = sound(soundin)
	S.repeat = FALSE
	S.wait = FALSE
	S.volume = 50
	S.channel = 1

	var/list_type = german_main_train_car_centers
	if (istype(src, /datum/train_controller/german_supplytrain_controller))
		list_type = german_supply_train_car_centers

	for (var/tcc in list_type)

		if (!tcc)
			list_type -= tcc
			continue
		// range(20, tcc) = checks ~500 objects (400 turfs)
		// player_list will rarely be above 100 objects
		// so this should be more efficient - Kachnov
		for (var/M in player_list)
			if (M && M:loc) // make sure we aren't in the lobby
				var/dist = abs_dist(M, tcc)
				if (dist <= 20)
					var/volume = 100
					if (!locate(/obj/train_connector) in get_turf(M))
						volume -= (dist*3)
					S.volume = volume
					M << S

/datum/train_controller/proc/check_can_move_mob(var/mob/m)
	return TRUE

/datum/train_controller/proc/opposing_directions_check(var/mob/m)
	if (direction == "FORWARDS" && m.dir == NORTH)
		return TRUE
	else if (direction == "BACKWARDS" && m.dir == SOUTH)
		return TRUE
	return FALSE

