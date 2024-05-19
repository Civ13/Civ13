/mob/var/lastgib = -1

//This is the proc for gibbing a mob. Cannot gib ghosts.
//added different sort of gibs and animations. N
/mob/proc/gib(anim="gibbed-m",do_gibs)
	// should prevent spam-gibbing that causes immense lag - Kachnov
	if (lastgib == -1 || world.time - lastgib > 10)

		if (ishuman(src))
			emote("painscream")

		lastgib = world.time
		death(1)
		transforming = TRUE
		canmove = FALSE
		icon = null
		invisibility = 101
		update_canmove()
		dead_mob_list -= src

		var/atom/movable/overlay/animation = null
		animation = new(loc)
		animation.icon_state = "blank"
		animation.icon = 'icons/mob/mob.dmi'
		animation.master = src

		flick(anim, animation)
		if (do_gibs) gibs(loc)

		spawn(15)
			if (animation)
				qdel(animation)
			if (client)
				client.movement_busy = FALSE
				if (map.ID == MAP_CAMPAIGN || map.ID == MAP_NATIONSRP_COLDWAR_CMP)
					src << browse(null, "window=memory")
					stop_ambience(src)
					client.screen.Cut()
					var/mob/new_player/M = new /mob/new_player()
					M.key = key
					spawn(5)
						M << "<font size=6>You have died!</font>"
					if (M.mind)
						M.mind.reset()
				else
					ghostize()
			if (src)
				qdel(src)

// gibbing, but without organ or item dropping
/mob/proc/crush(anim="gibbed-m",do_gibs)
	if (lastgib == -1 || world.time - lastgib > 10)

		if (ishuman(src))
			emote("painscream")
		if (client)
			client.movement_busy = FALSE
		lastgib = world.time
		death(1)
		transforming = TRUE
		canmove = FALSE
		icon = null
		invisibility = 101
		update_canmove()
		dead_mob_list -= src

		var/atom/movable/overlay/animation = null
		animation = new(loc)
		animation.icon_state = "blank"
		animation.icon = 'icons/mob/mob.dmi'
		animation.master = src

		flick(anim, animation)
		if (do_gibs) gibs(loc)

		// I couldn't find the gib sound, so I'm using this instead
		// - Kachnov
		playsound(loc, 'sound/effects/splat.ogg', 100)

		spawn(15)
			if (animation)	qdel(animation)
			if (src)
				qdel(src)
			if (client)
				client.movement_busy = FALSE
				if (map.ID == MAP_CAMPAIGN || map.ID == MAP_NATIONSRP_COLDWAR_CMP)
					src << browse(null, "window=memory")
					stop_ambience(src)
					client.screen.Cut()
					var/mob/new_player/M = new /mob/new_player()
					M.key = key
					spawn(5)
						M << "<font size=6>You have died!</font>"
					if (M.mind)
						M.mind.reset()
				else
					ghostize()
			if (src)
				qdel(src)
/mob/proc/maim()
	crush()

/mob/proc/death(gibbed, deathmessage="seizes up and falls limp...")

	if (stat == DEAD)
		return FALSE

	facing_dir = null

	stat = DEAD

	update_canmove()

	dizziness = FALSE
	jitteriness = FALSE

	layer = MOB_LAYER

	sight |= SEE_TURFS|SEE_MOBS|SEE_OBJS
	see_in_dark = 8
	see_invisible = SEE_INVISIBLE_LEVEL_TWO

	drop_r_hand()
	drop_l_hand()

	if (istype(src,/mob/living))
		var/mob/living/L = src
		if (L.HUDneed.Find("health"))
			var/obj/screen/health/H = L.HUDneed["health"]
			H.icon_state = "healthdoll_BASE_DEAD"
		if(istype(src,/mob/living/human))
			var/mob/living/human/H = src
			H.look_into_distance(src,FALSE)

	timeofdeath = world.time
	if (mind) mind.store_memory("Time of death: [stationtime2text()]", FALSE)
	living_mob_list -= src
	dead_mob_list |= src

	updateicon()
/*
	if (ticker && ticker.mode)
		ticker.mode.check_win()*/

	if (client)
		client.movement_busy = FALSE
		if (map.ID == MAP_CAMPAIGN || map.ID == MAP_NATIONSRP_COLDWAR_CMP)
			src << browse(null, "window=memory")
			stop_ambience(src)
			client.screen.Cut()
			var/mob/new_player/M = new /mob/new_player()
			M.key = key
			spawn(5)
				M << "<font size=6>You have died!</font>"
			if (M.mind)
				M.mind.reset()
		else
			ghostize()
	announce_ghost_joinleave(client, FALSE)

	return TRUE
