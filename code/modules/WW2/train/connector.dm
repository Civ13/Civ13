s//based off of /obj/structure/lattice, but way simpler

/obj/train_connector
	name = "train"
	icon = 'icons/obj/structures.dmi'
	icon_state = "latticefull"
	density = FALSE
	anchored = 1.0
	w_class = 3
	layer = 2.3 //under pipes
	//	flags = CONDUCT
	var/occupied = FALSE
	var/last_loc = null
	var/datum/train_controller/master = null
	var/list/saved_contents = list()
	var/list/saved_mobs = list()
	uses_initial_density = TRUE
	initial_density = FALSE

	uses_initial_opacity = TRUE
	initial_opacity = FALSE

// #define TCDEBUG

/obj/train_connector/proc/save_contents_as_refs()
	for (var/atom_movable in get_turf(src))
		if (!check_object_invalid_for_moving(src, atom_movable))
			saved_contents += atom_movable
			if (isliving(atom_movable))
				saved_mobs += atom_movable

/obj/train_connector/proc/remove_contents_refs()
	saved_contents.Cut()
	saved_mobs.Cut()

// copied from /obj/train_pseudoturf/_Move()
/obj/train_connector/proc/_Move()

	for (var/atom_movable in saved_contents)
		var/atom/movable/AM = atom_movable
		if (AM)
			if (saved_mobs.Find(AM))
				var/mob/M = AM
				M.original_pulling = M.pulling
				if (!M.buckled)
					switch (master.orientation)
						if (VERTICAL)
							M.train_move(locate(M.x, M.y+master.getMoveInc(), M.z))
						if (HORIZONTAL)
							M.train_move(locate(M.x+master.getMoveInc(), M.y, M.z))
			else
				switch (master.orientation)
					if (VERTICAL)
						AM.train_move(locate(AM.x, AM.y+master.getMoveInc(), AM.z))
					if (HORIZONTAL)
						AM.train_move(locate(AM.x+master.getMoveInc(), AM.y, AM.z))

				if (istype(AM, /obj/structure/bed))
					var/obj/structure/bed/bed = AM
					var/mob/M = bed.buckled_mob
					if (M)
						switch (master.orientation)
							if (VERTICAL)
								M.train_move(locate(M.x, M.y+master.getMoveInc(), M.z))
							if (HORIZONTAL)
								M.train_move(locate(M.x+master.getMoveInc(), M.y, M.z))

	for (var/mob in saved_mobs)
		var/mob/M = mob
		if (M)
			if (M.original_pulling)
				M.start_pulling(M.original_pulling)
				M.original_pulling = null

	switch (master.orientation)
		if (VERTICAL)
			y+=master.getMoveInc()
		if (HORIZONTAL)
			x+=master.getMoveInc()

// copied from /obj/train_pseudoturf/move_mobs()
/obj/train_connector/proc/move_mobs()
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

/obj/train_connector/ex_act(severity)
	if (prob(round(90 * (1/severity))))
		qdel(src)
	else
		return

/obj/train_connector/Destroy()
	if (master)
		master.train_connectors -= src
		master.reverse_train_connectors -= src
	..()