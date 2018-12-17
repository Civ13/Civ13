/process/dog

/process/dog/setup()
	name = "dog process"
	schedule_interval = 0.2 SECONDS // a bit slower than humans run (1.42 to 1.76 deciseconds)
	start_delay = 0.5 MINUTES
	fires_at_gamestates = list(GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_HIGH
	processes.dog = src

/process/dog/fire()
	try
		for (current in current_list)
			if (!isDeleted(current))
				var/mob/living/simple_animal/complex_animal/dog/dog = current
				if (dog.stat == CONSCIOUS && dog.walking_to)
					if (ismob(dog.walking_to))
						var/mob/M = dog.walking_to
						if (world.time - M.last_movement >= 10)
							continue
					var/dist_x = abs(dog.x - dog.walking_to.x)
					var/dist_y = abs(dog.y - dog.walking_to.y)
					if (dist_x > 1 || dist_y > 1 || dog.walking_to != dog.following)
						var/turf/target = get_step(dog.loc, get_dir(dog, dog.walking_to))
						if (target.density)
							continue
						if (locate(/obj/structure) in target)
							continue
						step(dog, get_dir(dog, dog.walking_to))
			else
				catchBadType(current)
				dog_mob_list -= current
			PROCESS_LIST_CHECK
			PROCESS_TICK_CHECK

	catch (var/exception/e)
		catchException(e)

/process/dog/reset_current_list()
	PROCESS_USE_FASTEST_LIST(dog_mob_list)

/process/dog/statProcess()
	..()
	stat(null, "[dog_mob_list.len] mobs")

/process/dog/htmlProcess()
	return ..() + "[dog_mob_list.len] mobs"