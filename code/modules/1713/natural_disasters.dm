
/obj/map_metadata/proc/earthquake(severity, duration, var/log=TRUE) //severity from 1 to 10. duration in ms
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
					var/mob/living/human/H = T
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

/turf/floor/lava
	name = "lava"
	icon = 'icons/turf/floors.dmi'
	icon_state = "lava0"
	interior = FALSE
	var/stage = 0
	var/dries = TRUE
	var/spreads = TRUE
	light_power = 2
	light_color = "#FFA500"
	New()
		..()
		if (dries)
			dryproc()
		spawn(5)
			for (var/atom/movable/M in src)
				Entered(M)
		if (spreads)
			spawn(20)
				var/area/A = get_area(src)
				for(var/turf/T in range(1,src))
					var/area/B = get_area(T)
					if (istype(B, A.type) && !istype(T,/turf/floor/lava))
						T.ChangeTurf(/turf/floor/lava)
			new/obj/effect/fire(src)
/turf/floor/lava/permanent
	dries = FALSE
	spreads = FALSE
/turf/floor/lava/proc/dryproc()
	if (stage>=2)
		src.ChangeTurf(/turf/floor/dirt/dry_lava)
		return
	else
		stage++
		if (stage>2)
			stage = 2
		else if (stage<0)
			stage = 0
		spawn(6000)
			icon_state = "lava[stage]"
			dryproc()

/turf/floor/lava/Entered(atom/movable/O)
	..()
	if (istype(O, /mob/living))
		var/mob/living/L = O
		visible_message("<span class='danger'>\The [O] is burned by the lava!</span>")
		if (ishuman(L))
			var/mob/living/human/H = L
			var/dam_zone = pick("l_foot", "r_foot", "l_leg", "r_leg")
			var/obj/item/organ/external/affecting = H.get_organ(dam_zone)
			switch(stage)
				if (0)
					affecting.droplimb(FALSE, DROPLIMB_BURN)
					qdel(affecting)
					H.apply_damage(100, BURN, affecting, FALSE, sharp=0, edge=0)
				if (1)
					if (prob(40))
						affecting.droplimb(FALSE, DROPLIMB_BURN)
						qdel(affecting)
					H.apply_damage(100, BURN, affecting, FALSE, sharp=0, edge=0)
				if (2)
					H.apply_damage(75, BURN, affecting, FALSE, sharp=0, edge=0)
			spawn(15)
				if (istype(H.loc, /turf/floor/lava))
					var/obj/structure/religious/remains/HR = new/obj/structure/religious/remains(src)
					HR.name = "[H]'s remains"
					HR.icon = 'icons/obj/flora/rocks.dmi'
					HR.icon_state = "remains"
					qdel(H)
					return
		else
			switch(stage)
				if (0)
					L.maim()
					L.maim()
					L.adjustFireLoss(100)
					spawn(20)
						qdel(L)
						new/obj/effect/decal/cleanable/ash(src)
					return
				if (1)
					if (prob(50))
						L.maim()
					L.adjustFireLoss(80)
					spawn(20)
						qdel(L)
						new/obj/effect/decal/cleanable/ash(src)
					return
				if (2)
					L.adjustFireLoss(55)
					spawn(20)
						qdel(L)
						new/obj/effect/decal/cleanable/ash(src)
					return
	else if (istype(O, /obj/item) || istype(O, /obj/structure) || istype(O, /obj/roof) || istype(O, /obj/covers))
		switch(stage)
			if (0)
				visible_message("<span class='danger'>\The [O] is melted by the lava!</span>")
				new/obj/effect/decal/cleanable/ash(src)
				qdel(O)
				if (prob(3))
					new/obj/effect/effect/smoke(loc)
				return
			if (1)
				visible_message("<span class='danger'>\The [O] is melted by the lava!</span>")
				new/obj/effect/decal/cleanable/ash(src)
				qdel(O)
				if (prob(3))
					new/obj/effect/effect/smoke(loc)
				return
			if (2)
				var/obj/OO = O
				if (OO.flammable)
					visible_message("<span class = 'warning'>\The [OO] is burned away.</span>")
					if (prob(33))
						new/obj/effect/effect/smoke(loc)
					qdel(O)
	return
/turf/wall/rockwall/lavaspawner/proc/start_lava_flow()

	for(var/turf/T in range(1,src))
		if (istype(T.loc, /area/caribbean/nomads/forest/Jungle/lava_east) || istype(T.loc, /area/caribbean/nomads/forest/Jungle/lava_west) || istype(T.loc, /area/caribbean/nomads/forest/Jungle/lava_south))
			T.ChangeTurf(/turf/floor/lava)
	return

/obj/map_metadata/proc/volcano_eruption()
	var/list/lavalist = list()
	for(var/turf/wall/rockwall/lavaspawner/L in world)
		lavalist += L
	if (!isemptylist(lavalist))
		var/turf/wall/rockwall/lavaspawner/T = pick(lavalist)
		T.start_lava_flow()
		world << "<font color='red'><big><b>The volcano erupts, with lava flowing down the mountain!</b></big></font>"
		return TRUE