
/proc/explosion(turf/epicenter, devastation_range, heavy_impact_range, light_impact_range, flash_range, adminlog = TRUE, z_transfer = UP|DOWN, is_rec = config.use_recursive_explosions, sound = "explosion", shaped = FALSE, do_effects = TRUE)
/*
	// TODO: splits explosions bigger than 5x5 into sub-explosions
	var/num_explosions = devastation_range/5
	var/explosion_epicenters_locations = list()

	for (var/v in 1 to num_explosions)
		// do data for first explosion
		// epicenter = locate(epicenter.x+devestation_range)

*/	
	var/multi_z_scalar = 0.35
	src = null	//so we don't abort once src is deleted

	spawn(0)
		epicenter = get_turf(epicenter)
		if(!epicenter) return

		// Handles recursive propagation of explosions.
		if(z_transfer)
			var/adj_dev   = max(0, (multi_z_scalar * devastation_range) - (shaped ? 2 : 0) )
			var/adj_heavy = max(0, (multi_z_scalar * heavy_impact_range) - (shaped ? 2 : 0) )
			var/adj_light = max(0, (multi_z_scalar * light_impact_range) - (shaped ? 2 : 0) )
			var/adj_flash = max(0, (multi_z_scalar * flash_range) - (shaped ? 2 : 0) )


			if(adj_dev > 0 || adj_heavy > 0)
				if(HasAbove(epicenter.z) && z_transfer & UP)
					explosion(GetAbove(epicenter), round(adj_dev), round(adj_heavy), round(adj_light), round(adj_flash), 0, UP, shaped)
				if(HasBelow(epicenter.z) && z_transfer & DOWN)
					explosion(GetBelow(epicenter), round(adj_dev), round(adj_heavy), round(adj_light), round(adj_flash), 0, DOWN, shaped)

		var/max_range = max(devastation_range, heavy_impact_range, light_impact_range, flash_range)


//Play sounds; we want sounds to be different depending on distance so we will manually do it ourselves.
//Stereo users will also hear the direction of the explosion!
//Calculate far explosion sound range. Only allow the sound effect for heavy/devastating explosions.
//3/7/14 will calculate to 80 + 35
		var/far_dist = (light_impact_range * 240)
		var/frequency = get_rand_frequency()
		for (var/mob/M in player_list)
			if(M && M.client) // double check for the client
				var/turf/M_turf = get_turf(M)
				if(M_turf && M_turf.z == epicenter.z)
					var/dist = get_dist(M_turf, epicenter)
					//If inside the blast radius + world.view - 2
					if(dist <= round(max_range + world.view - 2, 1))
						if(devastation_range > 0)
							M.playsound_local(epicenter, get_sfx("explosion"), 100, 1, frequency, falloff = 5) // get_sfx() is so that everyone gets the same sound
							shake_camera(M, Clamp(devastation_range, 3, 10), 2)
						else
							M.playsound_local(epicenter, get_sfx("explosion_small"), 100, 1, frequency, falloff = 5)
							shake_camera(M, 4, 1)

						//You hear a far explosion if you're outside the blast radius. Small bombs shouldn't be heard all over the map.

					else if(dist <= far_dist)
						var/far_volume = Clamp(far_dist*3, 30, 50) // Volume is based on explosion size and dist
						far_volume += (dist <= far_dist * 0.5 ? 50 : 0) // add 50 volume if the mob is pretty close to the explosion
						if(devastation_range > 0)
							M.playsound_local(epicenter, 'sound/effects/explosionfarnew.ogg', far_volume * 2, 1, frequency, falloff = 5)
							shake_camera(M, 5, 1) // shakes no matter how far [40m artillery and you still get shaken, tweak if necessary]
						else
							M.playsound_local(epicenter, 'sound/effects/explosionsmallfarnew.ogg', far_volume * 2, 1, frequency, falloff = 5)

		if(heavy_impact_range > 1)

			if(do_effects)
				var/datum/effect/system/explosion/E = new/datum/effect/system/explosion()
				E.set_up(epicenter)
				E.start()
			if(istype(epicenter, /turf/floor/dirt) || istype(epicenter, /turf/floor/plating/road) || istype(epicenter, /turf/floor/wood) || !istype(epicenter, /turf/floor/beach))
				new/obj/effect/crater64(epicenter)
		else
			if(do_effects)
				var/datum/effect/system/explosion_small/E = new/datum/effect/system/explosion_small()
				E.set_up(epicenter)
				E.start()

		var/x0 = epicenter.x
		var/y0 = epicenter.y
		var/z0 = epicenter.z
		if(config.use_recursive_explosions)
			var/power = devastation_range * 2 + heavy_impact_range + light_impact_range //The ranges add up, ie light 14 includes both heavy 7 and devestation 3. So this calculation means devestation counts for 4, heavy for 2 and light for 1 power, giving us a cap of 27 power.
			explosion_rec(epicenter, power, shaped)
		else
			for(var/turf/T in trange(max_range, epicenter))
				var/dist = sqrt((T.x - x0)**2 + (T.y - y0)**2)

				if(dist < devastation_range)		dist = 1
				else if(dist < heavy_impact_range)	dist = 2
				else if(dist < light_impact_range)	dist = 3
				else								continue

				T.ex_act(dist)
				if(!T)
					T = locate(x0,y0,z0)
				for(var/atom_movable in T.contents)	//bypass type checking since only atom/movable can be contained by turfs anyway
					var/atom/movable/AM = atom_movable
					if(AM && AM.simulated)
						AM.ex_act(dist)
	var/datum/explosiondata/data = new // handles the data for rpgs and sounds for dynamite and missiles, etc.
	data.epicenter = epicenter
	data.devastation_range = devastation_range
	data.heavy_impact_range = heavy_impact_range
	data.light_impact_range = light_impact_range
	data.flash_range = flash_range
	data.adminlog = adminlog
	data.z_transfer = z_transfer
	data.is_rec = is_rec
	data.rec_pow = max(0,devastation_range) * 2 + max(0,heavy_impact_range) + max(0,light_impact_range)
	if (sound)
		data.sound = sound
	// queue work
	processes.callproc.queue(processes.explosion, /process/explosion/proc/queue, list(data), 1)

	return data


/proc/ignite_turf(turf/target, duration, damage)
	for (var/mob/living/HM in target)
		HM.adjustBurnLoss(damage)
		HM.fire_stacks += rand(1,3)
		HM.IgniteMob()
	var/obj/effect/fire/F = new /obj/effect/fire(target)
	F.timer = duration * 10 // So it's in seconds
	return

/proc/ignite_turf_lowchance(turf/target, duration, damage)
	for (var/mob/living/HM in target)
		HM.adjustBurnLoss(damage)
		if (prob(30))
			HM.fire_stacks += rand(1)
		HM.IgniteMob()
	if (prob(30))
		var/obj/effect/fire/F = new /obj/effect/fire(target)
		F.timer = duration * 10 // So it's in seconds
	return

/turf
	var/explosion_resistance

/turf/floor
	explosion_resistance = TRUE

/turf/wall
	explosion_resistance = 10

/turf/floor/plating/road
	explosion_resistance = 4


var/list/explosion_turfs = list()

var/explosion_in_progress = 0

proc/explosion_rec(turf/epicenter, power, shaped)
	var/loopbreak = 0
	while(explosion_in_progress)
		if(loopbreak >= 15) return
		sleep(10)
		loopbreak++

	if(power <= 0) return
	epicenter = get_turf(epicenter)
	if(!epicenter) return

	explosion_in_progress = 1
	explosion_turfs = list()

	explosion_turfs[epicenter] = power

	//This steap handles the gathering of turfs which will be ex_act() -ed in the next step. It also ensures each turf gets the maximum possible amount of power dealt to it.
	for(var/direction in cardinal)
		var/turf/T = get_step(epicenter, direction)
		var/adj_power = power - epicenter.get_explosion_resistance()
		if(shaped)
			if (shaped == direction)
				adj_power *= 3
			else if (shaped == reverse_direction(direction))
				adj_power *= 0.10
			else
				adj_power *= 0.45

		T.explosion_spread(adj_power, direction)

	//This step applies the ex_act effects for the explosion, as planned in the previous step.
	for(var/spot in explosion_turfs)
		var/turf/T = spot
		if(explosion_turfs[T] <= 0) continue
		if(!T) continue

		//Wow severity looks confusing to calculate... Fret not, I didn't leave you with any additional instructions or help. (just kidding, see the line under the calculation)
		var/severity = 4 - round(max(min( 3, ((explosion_turfs[T] - T.get_explosion_resistance()) / (max(3,(power/3)))) ) ,1), 1)								//sanity			effective power on tile				divided by either 3 or one third the total explosion power
								//															One third because there are three power levels and I
								//															want each one to take up a third of the crater
		var/x = T.x
		var/y = T.y
		var/z = T.z
		T.ex_act(severity)
		if(!T)
			T = locate(x,y,z)

		var/throw_target = get_edge_target_turf(T, get_dir(epicenter,T))
		for(var/atom_movable in T.contents)
			var/atom/movable/AM = atom_movable
			if(AM && AM.simulated)
				AM.ex_act(severity)
				if(!AM.anchored)
					AM.throw_at(throw_target, 9/severity, 9/severity)


	explosion_turfs.Cut()
	explosion_in_progress = 0


//Code-wise, a safe value for power is something up to ~25 or ~30.. This does quite a bit of damage.
//direction is the direction that the spread took to come to this tile. So it is pointing in the main blast direction - meaning where this tile should spread most of it's force.
/turf/proc/explosion_spread(power, direction)
	if(power <= 0)
		return

	if(explosion_turfs[src] >= power)
		return //The turf already sustained and spread a power greated than what we are dealing with. No point spreading again.
	explosion_turfs[src] = power

/*	sleep(2)
	var/obj/effect/debugging/M = locate() in src
	if (!M)
		M = new(src, power, direction)
	M.maptext = "[power]"
	if(power > 10)
		M.color = "#cccc00"
	if(power > 20)
		M.color = "#ffcc00"
*/
	var/spread_power = power - src.get_explosion_resistance() //This is the amount of power that will be spread to the tile in the direction of the blast

	var/turf/T = get_step(src, direction)
	if(T)
		T.explosion_spread(spread_power, direction)
	T = get_step(src, turn(direction,90))
	if(T)
		T.explosion_spread(spread_power, turn(direction,90))
	T = get_step(src, turn(direction,-90))
	if(T)
		T.explosion_spread(spread_power, turn(direction,90))

/turf/unsimulated/explosion_spread(power)
	return //So it doesn't get to the parent proc, which simulates explosions

/atom/var/explosion_resistance
/atom/proc/get_explosion_resistance()
	if(simulated)
		return explosion_resistance

/turf/get_explosion_resistance()
	. = ..()
	for(var/obj/O in src)
		. += O.get_explosion_resistance()


/turf/simulated/floor/get_explosion_resistance()
	. = ..()
