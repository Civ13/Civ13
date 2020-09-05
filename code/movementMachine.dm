#define SECONDS *10
var/movementMachine/movementMachine = null

/movementMachine
	var/interval = 0.01 SECONDS // 100 FPS
	var/ticks = 0
	var/last_run = -1

	var/list/last_twenty_tick_usage_times = list()

	var/last_tick_usage = 0
	var/last_cpu = 0

	var/average_tick_usage = 0
	var/average_cpu = 0

/movementMachine/New()
	..()
	if (movementMachine && movementMachine != src)
		del(src)
		return FALSE
	return TRUE

/movementMachine/proc/start()
	spawn (0)
		process()

/movementMachine/proc/process()

	while (TRUE)

		var/initial_tick_usage = world.tick_usage

		for (var/client in movementMachine_clients)

			// this try-catch block is here now because apparently client can be something that isn't a client, causing the game to crash
			try

				if (client && client:type == /client && !client:movement_busy && !isDeleted(client))

					var/mob/M = client:mob

					if (!isDeleted(M))
						if ((M.movement_eastwest || M.movement_northsouth) && M.client.canmove && !M.client.moving && world.time >= M.client.move_delay)
							var/diag = FALSE
							var/movedir = M.movement_northsouth ? M.movement_northsouth : M.movement_eastwest
							if ((M.movement_eastwest && M.movement_northsouth))
								if (M.movement_northsouth == NORTH && M.movement_eastwest == WEST)
									movedir = NORTHWEST
									diag = TRUE
								else if (M.movement_northsouth == NORTH && M.movement_eastwest == EAST)
									movedir = NORTHEAST
									diag = TRUE
								else if (M.movement_northsouth == SOUTH && M.movement_eastwest == WEST)
									movedir = SOUTHWEST
									diag = TRUE
								else if (M.movement_northsouth == SOUTH && M.movement_eastwest == EAST)
									movedir = SOUTHEAST
									diag = TRUE
							// hack to let other clients Move() earlier
							do_movement(M, movedir, diag)
							if (ishuman(M))
								var/mob/living/human/H = M
								if (H.football && H.football.owner == H)
									H.football.update_movement()	
					else
						mob_list -= M
				else
					movementMachine_clients -= client

			catch(var/exception/e)
				world.Error(e)

		++ticks
		last_run = world.time
		var/final_tick_usage = world.tick_usage

		// get average/last tick usage: cpu stats are based on this, since cpu doesn't update in real time it's the best we can do - Kachnov
		last_twenty_tick_usage_times += ((final_tick_usage-initial_tick_usage) * (world.tick_lag/interval))
		if (last_twenty_tick_usage_times.len >= 20)
			var/list/old = last_twenty_tick_usage_times.Copy()
			last_twenty_tick_usage_times.Cut()
			last_twenty_tick_usage_times.len = 10
			for (var/v in 11 to 20)
				last_twenty_tick_usage_times[v-10] = old[v]

		average_tick_usage = average_tick_usage()
		last_tick_usage = last_twenty_tick_usage_times[last_twenty_tick_usage_times.len]

		// I'm not confident that this is the best way to "calculate" average/last cpu, but oh well - Kachnov
		average_cpu = (average_tick_usage/100) * world.cpu
		last_cpu = (last_tick_usage/100) * world.cpu

		sleep(interval)
#undef SECONDS


/movementMachine/proc/do_movement(var/mob/M, movedir, diag)
	set waitfor = FALSE
	if (M && M.client)
		M.client.movement_busy = TRUE
		M.client.Move(get_step(M, movedir), movedir, diag)
		// remove this client from movementMachine_clients until it needs to be in it again. This makes the amount of loops to be done the absolute minimum
		movementMachine_clients -= M.client
		do_movement_continued(M)

/movementMachine/proc/do_movement_continued(var/mob/M)
	set waitfor = FALSE
	var/movtoset = 0
	if (M && M.client)
		if (M.client.move_delay)
			movtoset = M.client.move_delay
			sleep(movtoset - world.time)
		else
			sleep(3)
	if (M && M.client)
		M.client.movement_busy = FALSE
		movementMachine_clients += M.client

/movementMachine/proc/average_tick_usage()
	if (!last_twenty_tick_usage_times.len)
		return 0
	. = 0
	for (var/n in last_twenty_tick_usage_times)
		. += n
	. /= last_twenty_tick_usage_times.len