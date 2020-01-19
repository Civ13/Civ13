
/proc/earthquake(severity, duration, var/log=TRUE) //severity from 1 to 10. duration in ms
	duration = round(duration)
	if (severity>10)
		severity=10
	if(!severity || duration < 1) return FALSE
	world << "<big><b>An earthquake has started!</b></big>"
	spawn(duration)
		world << "<big><i>The earthquake subsides.</i></big>"
	spawn(1)
		for (var/mob/m in player_list)
			if (m.client)
				shake_camera(m, duration, severity)
	spawn(5)
		for(var/atom/T)
			if ((istype(T, /mob/living) || istype(T, /obj)))
				if (ishuman(T))
					var/mob/living/carbon/human/H = T
					H.Weaken(duration)
				else if (istype(T, /obj/structure/window))
					var/obj/structure/window/W = T
					W.shatter()
				else if (istype(T, /obj))
					if (prob(4*severity) && T.density)
						T.ex_act(1.0)

	if (log)
		log_game("<font color='red'>An earthquake has happened!</font>")

	return TRUE

///////////////////Vulcano//////////////////////

/turf/wall/rockwall/lavaspawner/proc/start_lava_flow()
	for(var/turf/T in range(1,src))
		if (istype(T.loc, /area/caribbean/nomads/forest/Jungle/lava_east) || istype(T.loc, /area/caribbean/nomads/forest/Jungle/lava_west) || istype(T.loc, /area/caribbean/nomads/forest/Jungle/lava_south))
			T.ChangeTurf(/turf/floor/lava)
	return

