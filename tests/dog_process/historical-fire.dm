/process/dog/fire()
	try
		for (current in current_list)
			if (!isDeleted(current))
				var/mob/living/simple_animal/complex_animal/dog/dog = current
				if (dog.stat == CONSCIOUS && dog.walking_to && !ecology_animal_frozen(dog))
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
						for (var/obj/S in target)
							if (S.density)
								continue
						step(dog, get_dir(dog, dog.walking_to))
			else
				catchBadType(current)
				dog_mob_list -= current
			PROCESS_LIST_CHECK
			PROCESS_TICK_CHECK

	catch (var/exception/e)
		catchException(e)
