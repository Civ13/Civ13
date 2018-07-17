/turf/sky
	icon = 'icons/turf/sky.dmi'
	icon_state = ""
	name = "the sky"

var/list/sky_drop_map = list()

// this is probably laggy as hell but oh well - Kachnov
/turf/sky/Entered(var/atom/movable/mover)
	if (locate_dense_type(contents, /obj/structure) || locate_type(contents, /obj/structure/window/classic)) // plane windows
		return ..(mover)
	else
		..(mover)
		if (locate(/obj/structure/plating) in contents)
			return
		var/area/prishtina/void/sky/A = get_area(src)
		if (!istype(A))
			return
		if (!A.corresponding_area_type)
			return
		if (!istype(mover, /mob/observer))
			if (sky_drop_map.len)
				for (var/locstr in sky_drop_map)
					for (var/turf/T in range(5, sky_drop_map[locstr]))
						if (locate(/mob/living) in T)
							continue
						mover.forceMove(T)
			else
				if (A.corresponding_area_allow_subtypes )
					for (var/area/AA in area_list)
						if (istype(AA, A.corresponding_area_type))
							mover.forceMove(pick(AA.contents))
							mover.loc = get_turf(mover.loc)
							sky_drop_map["[mover.x],[mover.y],[mover.z]"] = mover.loc
							break
				else
					var/area/AA = locate(A.corresponding_area_type)
					mover.forceMove(pick(AA.contents))
					mover.loc = get_turf(mover.loc)
					sky_drop_map["[mover.x],[mover.y],[mover.z]"] = mover.loc

		if (isliving(mover))
			var/mob/living/L = mover
			if (!ishuman(mover))
				if (processes.paratrooper_plane.isLethalToJump())
					L << "<span class = 'userdanger'>You land hard on the ground.</span>"
					L.adjustBruteLoss(150)
				else
					L << "<span class = 'good'>You land softly on the ground.</span>"
			else
				var/mob/living/carbon/human/H = mover
				if (processes.paratrooper_plane.isLethalToJump() || !H.back || !istype(H.back, /obj/item/weapon/storage/backpack/german/paratrooper))
					H << "<span class = 'userdanger'>You land hard on the ground.</span>"
					H.adjustBruteLossByPart(75, "l_leg")
					H.adjustBruteLossByPart(75, "r_leg")
				else
					#define FALL_STEPS 12
					try
						H.client.canmove = FALSE
						var/image/I = image('icons/WW2/parachute.dmi', H, layer = MOB_LAYER + 1.0)
						I.pixel_x = -16
						I.pixel_y = 32

						// hack to stop overlays from resetting when you shoot and stuff (wtf)
						// this gets called world.fps times a second but it's usually just searching a list, no big deal
						spawn (0)
							while (H && !isDeleted(I))
								if (!H.overlays.Find(I))
									H.overlays += I
								sleep(world.tick_lag)

						H.overlays += I
						H.pixel_y += FALL_STEPS*10

						for (var/v in 1 to FALL_STEPS)
							spawn (v*5)
								H.pixel_y -= 10

						// animation is over now: it's supposed to be 7.8 seconds but this works better
						spawn (60)
							H.overlays -= I
							qdel(I)

						spawn ((FALL_STEPS+0.5)*5)
							playsound(get_turf(H), 'sound/effects/bamf.ogg', 20)
							shake_camera(H, 2)
							H.client.canmove = TRUE

					catch (var/exception/E)
						pass(E)
						H.client.canmove = TRUE
					#undef FALL_STEPS

		// make sure we have the right ambience for our new location
		spawn (1)
			if (ishuman(mover))
				var/area/H_area = get_area(mover)
				H_area.play_ambience(mover)
