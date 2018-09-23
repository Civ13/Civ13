/obj/effect/spawner
	name = "object spawner"

/obj/effect/spawner/mobspawner
	name = "mob spawner"
	invisibility = 101
	icon = 'icons/mob/screen/1713Style.dmi'
	icon_state = "x2"
	var/activated = 1
	var/current_number = 0
	var/max_number = 25
	var/max_range = 10
	var/create_path = /mob/living/simple_animal/hostile/skeleton
	var/timer = 200

/obj/effect/spawner/mobspawner/New()
	..()
	spawnerproc()

/obj/effect/spawner/mobspawner/proc/spawnerproc()
	if (activated)
		if (current_number < max_number)
			spawn(rand(timer,timer + (timer/2)))
				var/mob/living/simple_animal/newmob = new create_path(src.loc)
				newmob.origin = src
				newmob.x=src.x+(rand(-max_range,max_range))
				newmob.y=src.y+(rand(-max_range,max_range))
				while (get_turf(newmob).opacity == TRUE)
					newmob.x=src.x+(rand(-max_range,max_range))
					newmob.y=src.y+(rand(-max_range,max_range))
				current_number += 1
				spawnerproc()


/obj/effect/spawner/mobspawner/turkeys
	name = "turkey spawner"
	max_number = 5
	max_range = 13
	create_path = /mob/living/simple_animal/turkey_m
	timer = 900