/obj/train_pseudoturf
	anchored = TRUE
	name = "train"
	layer = 2.5
	var/obj/train_car_center/master = null
	var/datum/train_controller/controller = null
	var/deadly = FALSE
	var/list/saved_contents = list()
	var/list/saved_mobs = list()
	var/based_on_type = null // debug variable
	var/copy_of_instance = null // debug variable

/obj/train_pseudoturf/New(_loc, var/turf/T, var/ignorecontents = FALSE)
	..()

	loc = _loc
	density = T.density
	opacity = T.opacity
	based_on_type = T.type
	copy_of_instance = T

	if (istype(T, /turf/wall))
		var/turf/wall/W = T
		icon = W.icon
		icon_state = W.ref_state
		overlays = W.overlays
		deadly = TRUE
	else
		icon = T.icon
		icon_state = T.icon_state
		for (var/atom/A in T.overlays)
			overlays += new A.type

	pixel_x = T.pixel_x
	pixel_y = T.pixel_y
	dir = T.dir
	anchored = TRUE

	uses_initial_density = TRUE
	initial_density = density

	uses_initial_opacity = TRUE
	initial_opacity = opacity

	for (var/atom_movable in loc)
		if (istype(atom_movable, /obj/structure/wild))
			qdel(atom_movable)

	if (!ignorecontents)
		for (var/atom_movable in T)

			var/atom/movable/AM = atom_movable

			if (istype(AM, /obj/train_decal))
				vis_contents |= AM
				continue

			if (check_object_invalid_for_moving(src, AM, TRUE))
				continue

			var/atom/movable/AM2 = new AM.type(loc)

			if (istype(AM2, /obj/structure/multiz/ladder/ww2))
				var/obj/structure/multiz/ladder/ww2/old_ladder = AM
				var/obj/structure/multiz/ladder/ww2/new_ladder = AM2
				new_ladder.area_id = old_ladder.area_id
				new_ladder.ladder_id = old_ladder.ladder_id
				new_ladder.target = new_ladder.find_target()
				new_ladder.target.target = new_ladder
				qdel (old_ladder) // delete the source so we don't make multiple identical
					// ladders between different cars!

			if (istype(AM2, /obj/train_lever))
				var/obj/train_lever/lever = AM2
				lever.real = TRUE // distinguish us from the example lever

			if (istype(AM2, /obj/structure/bed))
				var/obj/structure/bed/bed = AM2
				bed.can_buckle = FALSE // fixes the train buckling meme
/*
			if (istype(aa, /obj/machinery))
				aa.anchored = TRUE*/

			AM2.icon = AM.icon
			AM2.icon_state = AM.icon_state
			AM2.layer = AM.layer
			AM2.pixel_x = AM.pixel_x
			AM2.pixel_y = AM.pixel_y
			AM2.dir = AM.dir

			AM2.uses_initial_density = TRUE
			AM2.initial_density = AM2.density

			AM2.uses_initial_opacity = TRUE
			AM2.initial_opacity = AM2.opacity


	for (var/atom_movable in T)
		if (istype(atom_movable, /obj/structure))
			var/obj/structure/S = atom_movable
			if (S.density && !istype(S, /obj/structure/railing/train_railing))
				if (!istype(S, /obj/structure/simple_door))
					deadly = TRUE

/obj/train_pseudoturf/proc/save_contents_as_refs()
	for (var/atom_movable in get_turf(src))
		if (!check_object_invalid_for_moving(src, atom_movable))
			saved_contents += atom_movable
			if (isliving(atom_movable))
				saved_mobs += atom_movable

/obj/train_pseudoturf/proc/remove_contents_refs()
	saved_contents.Cut()
	saved_mobs.Cut()

/obj/train_pseudoturf/proc/reset_track_lights() // pre movement
	for (var/obj/train_track/tt in get_turf(src))
		tt.set_light(2, 3, "#a0a080") // reset the lights of tracks we left behind

/obj/train_pseudoturf/proc/unset_track_lights() // post movement
	for (var/obj/train_track/tt in get_turf(src))
		tt.set_light(0, FALSE) // unset the lights of tracks we're now on

/obj/train_pseudoturf/proc/_Move()

	for (var/atom_movable in saved_contents)
		var/atom/movable/AM = atom_movable
		if (AM)
			if (saved_mobs.Find(AM))
				var/mob/M = AM
				M.original_pulling = M.pulling
				if (!M.buckled)
					switch (controller.orientation)
						if (VERTICAL)
							M.train_move(locate(M.x, M.y+controller.getMoveInc(), M.z))
						if (HORIZONTAL)
							M.train_move(locate(M.x+controller.getMoveInc(), M.y, M.z))
			else
				switch (controller.orientation)
					if (VERTICAL)
						AM.train_move(locate(AM.x, AM.y+controller.getMoveInc(), AM.z))
					if (HORIZONTAL)
						AM.train_move(locate(AM.x+controller.getMoveInc(), AM.y, AM.z))

				if (istype(AM, /obj/structure/bed))
					var/obj/structure/bed/bed = AM
					var/mob/M = bed.buckled_mob
					if (M)
						switch (controller.orientation)
							if (VERTICAL)
								M.train_move(locate(M.x, M.y+controller.getMoveInc(), M.z))
							if (HORIZONTAL)
								M.train_move(locate(M.x+controller.getMoveInc(), M.y, M.z))

	for (var/mob in saved_mobs)
		var/mob/M = mob
		if (M)
			if (M.original_pulling)
				M.start_pulling(M.original_pulling)
				M.original_pulling = null

	switch (controller.orientation)
		if (VERTICAL)
			y+=controller.getMoveInc()
		if (HORIZONTAL)
			x+=controller.getMoveInc()

/obj/train_pseudoturf/proc/move_mobs()
	for (var/mob in saved_mobs)
		if (mob)
			var/mob/M = mob
			spawn (0.1)
				if (!isnull(M.next_train_movement))

					var/atom/movable/p = M.pulling

					if (M.next_train_movement)
						M.dir = M.next_train_movement
						if (p) p.dir = M.next_train_movement

					switch (M.next_train_movement)
						if (NORTH)
							var/moved = M.train_move(locate(M.x, M.y+1, M.z))
							if (p && moved) p.train_move(M.behind())
						if (SOUTH)
							var/moved = M.train_move(locate(M.x, M.y-1, M.z))
							if (p && moved) p.train_move(M.behind())
						if (EAST)
							var/moved = M.train_move(locate(M.x+1, M.y, M.z))
							if (p && moved) p.train_move(M.behind())
						if (WEST)
							var/moved = M.train_move(locate(M.x-1, M.y, M.z))
							if (p && moved) p.train_move(M.behind())

					if (p && get_dist(M, p) <= 1)
						M.start_pulling(p) // start_pulling checks for p on its own

					M.next_train_movement = null
					M.train_gib_immunity = FALSE
					M.last_moved_on_train = world.time

/obj/train_pseudoturf/proc/src_dir()
	switch (controller.direction)
		if ("FORWARDS")
			return SOUTH
		if ("BACKWARDS")
			return NORTH

/obj/train_pseudoturf/proc/destroy_objects()
	for (var/atom_movable in get_step(src, src_dir()))
		var/atom/movable/AM = atom_movable
		if (AM.pulledby && AM.pulledby.is_on_train())
			continue
		// this is now a feature - Kachnov
		if (istype(AM, /obj/tank))
			var/obj/tank/T = AM
			T.tank_message("<span class = 'danger'><big>[AM] explodes.</big></span>")
			for (var/mob/M in T)
				M.crush()
			explosion(get_turf(T), 1, 3, 5, 6)
			spawn (20)
				qdel(T)
				T.loc = null
		if (check_object_invalid_for_moving(src, AM) && check_object_valid_for_destruction(AM))
			if (AM.density)
				visible_message("<span class = 'danger'>The train crushes [AM]!</span>")
				if (istype(AM, /obj/structure))
					gibs(get_turf(AM), gibber_type = /obj/effect/gibspawner/robot)
				qdel(AM)
			else if (!AM.density)
				visible_message("<span class = 'warning'>The train crushes [AM].</span>")
				qdel(AM)

/obj/train_pseudoturf/proc/gib_idiots()
	for (var/mob/living/L in get_step(src, src_dir()))

		if (L.is_on_train() && L.get_train() == controller)
			continue

		if (L.train_gib_immunity)
			continue

		if (deadly && istype(L))
			visible_message("<span class = 'danger'>The train crushes [L]!</span>")
			L.crush()

/obj/train_connector/ex_act(severity)
	if (prob(round(70 * (1/severity))))
		qdel(src)
	else
		return

/obj/train_pseudoturf/Destroy()
	if (master)
		master.forwards_pseudoturfs -= src
		master.backwards_pseudoturfs -= src
	..()