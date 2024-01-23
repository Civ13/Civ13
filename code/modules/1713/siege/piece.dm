/obj/structure/cannon
	name = "cannon"
	icon = 'icons/obj/cannon.dmi'
	pixel_x = -16
	pixel_y = 0
	layer = MOB_LAYER + 1 //just above mobs
	density = TRUE
	icon_state = "cannon"
	var/travelled = 0
	var/max_distance = 0
	var/high_distance = 0
	var/high = TRUE
	var/mob/user = null
	var/list/obj/item/cannon_ball/loaded = new/list()
	var/max_loaded = 1
	bound_height = 64
	bound_width = 32
	anchored = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/ammotype = /obj/item/cannon_ball
	var/spritemod = TRUE //if true, uses 32x64
	var/explosion = TRUE
	var/incendiary = FALSE
	var/nuclear = FALSE
	var/reagent_payload = "none"
	var/maxrange = 50

	var/firedelay = 20
	var/caliber = 75
	var/broken = FALSE
	var/can_assemble = FALSE
	var/assembled = TRUE
	var/obj/structure/bed/chair/loader/loader_chair = null
	var/obj/structure/bed/chair/gunner/gunner_chair = null
	var/see_amount_loaded = FALSE
	var/autoloader = FALSE

	var/degree = 270
	var/distance = 5
	var/has_scope = TRUE
	var/scope_mod = "Disabled"
	var/target_x = 0
	var/target_y = -5

	var/course = FALSE

	var/is_naval = FALSE
	var/naval_position = "middle"

/obj/structure/cannon/verb/assemble()
	set category = null
	set name = "Assemble"
	set src in range(2, usr)

	if (!istype(usr, /mob/living))
		return

	if (!can_assemble)
		return

	if (assembled)
		visible_message("[usr] starts disassembling \the [src]...")
		if (do_after(usr, 70, src, can_move = FALSE))
			visible_message("[usr] finishes disassembling \the [src].")
			assembled = FALSE
			anchored = FALSE
			if (loader_chair && (loader_chair in range(3,src)))
				if (loader_chair.buckled_mob)
					loader_chair.unbuckle_mob(buckled_mob)
				loader_chair.forceMove(src)
			if (gunner_chair && (gunner_chair in range(3,src)))
				if (gunner_chair.buckled_mob)
					gunner_chair.unbuckle_mob(buckled_mob)
				gunner_chair.forceMove(src)
			icon_state = "feldkanone18"
			update_icon()
	else
		visible_message("[usr] starts assembling \the [src]...")
		if (do_after(usr, 70, src, can_move = FALSE))
			visible_message("[usr] finishes assembling \the [src].")
			assembled = TRUE
			anchored = TRUE
			if (loader_chair)
				switch (dir)
					if (NORTH)
						loader_chair.forceMove(locate(x,y-1,z))
					if (SOUTH)
						loader_chair.forceMove(locate(x,y+1,z))
					if (EAST)
						loader_chair.forceMove(locate(x-1,y,z))
					if (WEST)
						loader_chair.forceMove(locate(x+1,y,z))
				loader_chair.dir = dir
				loader_chair.anchored = TRUE
			if (gunner_chair)
				switch (dir)
					if (NORTH)
						gunner_chair.forceMove(locate(x+1,y,z))
					if (SOUTH)
						gunner_chair.forceMove(locate(x-1,y,z))
					if (EAST)
						gunner_chair.forceMove(locate(x,y-1,z))
					if (WEST)
						gunner_chair.forceMove(locate(x,y+1,z))
				gunner_chair.dir = dir
				gunner_chair.anchored = TRUE
			icon_state = "feldkanone18_assembled"
			update_icon()
			return

/obj/structure/cannon/bullet_act(var/obj/item/projectile/proj)
	if (istype(proj, /obj/item/projectile/shell))
		var/obj/item/projectile/shell/S = proj
		if (S.atype == "HE")
			if (prob(90))
				visible_message("<span class = 'warning'>\The [src] blows up!</span>")
				qdel(src)
		else
			if (prob(25))
				visible_message("<span class = 'warning'>\The [src] blows up!</span>")
				qdel(src)

/obj/structure/cannon/modern/tank/attackby(obj/item/W as obj, mob/M as mob)
	if (broken && istype(W, /obj/item/weapon/weldingtool))
		visible_message("[M] starts repairing the [src]...")
		if (do_after(M, 200, src))
			visible_message("[M] sucessfully repairs the [src].")
			broken = FALSE
			return
	if (istype(W, ammotype))
		var/obj/item/cannon_ball/TS = W
		if (caliber != TS.caliber && caliber != null && caliber != 0)
			M << "<span class = 'warning'>\The [TS] is of the wrong caliber! You need [caliber] mm shells for this cannon.</span>"
			return
		if (loaded.len >= max_loaded)
			M << "<span class = 'warning'>There's already a [loaded[1]] loaded.</span>"
			return
		// load first and only slot
		var/found_loader = FALSE
		for (var/obj/structure/bed/chair/loader/L in M.loc)
			found_loader = TRUE
		if (!found_loader && istype(src, /obj/structure/cannon/modern/tank) && !istype(src, /obj/structure/cannon/modern/tank/voyage))
			M << "<span class = 'warning'>You need to be at the loader's position to load \the [src].</span>"
			return FALSE

		var/loadtime = caliber*0.5
		if (istype(src,/obj/structure/cannon/modern/naval))
			loadtime = caliber*0.25

		if (do_after(M, loadtime, M, can_move = TRUE))
			if (M && (locate(M) in range(1,src)))
				found_loader = FALSE
				for (var/obj/structure/bed/chair/loader/L in M.loc)
					found_loader = TRUE
				if (!found_loader && istype(src, /obj/structure/cannon/modern/tank) && !istype(src, /obj/structure/cannon/modern/tank/voyage))
					M << "<span class = 'warning'>You need to be at the loader's position to load \the [src].</span>"
					return FALSE
				M.remove_from_mob(W)
				W.loc = src
				loaded += W
				M << SPAN_NOTICE("You load \the [src].")
				playsound(loc, 'sound/effects/lever.ogg', 100, TRUE)
				return
	else if (istype(W,/obj/item/weapon/wrench) && !can_assemble)
		M << (anchored ? "<span class='notice'>You start unfastening \the [src] from the floor.</span>" : "<span class='notice'>You start securing \the [src] to the floor.</span>")
		if (do_after(M, 3 SECONDS, src))
			playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
			M << (anchored ? "<span class='notice'>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
			anchored = !anchored
	else if (can_assemble && assembled)
		if (!gunner_chair && istype(W, /obj/structure/bed/chair/gunner))
			M.remove_from_mob(W)
			gunner_chair = W
			W.anchored = TRUE
		else if (!loader_chair && istype(W, /obj/structure/bed/chair/loader))
			M.remove_from_mob(W)
			loader_chair = W
			W.anchored = TRUE

/obj/structure/cannon/New()
	..()
	cannon_piece_list += src


/obj/structure/cannon/Destroy()
	cannon_piece_list -= src
	..()

/obj/structure/cannon/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			if (prob(10))
				qdel(src)
				return
		if (3.0)
			return

/obj/structure/cannon/attack_hand(var/mob/attacker)
	if (can_assemble && !assembled)
		attacker << "<span class = 'warning'>Assemble the cannon first.</span>"
		return
	else
		interact(attacker)

/obj/structure/cannon/attackby(obj/item/W as obj, mob/M as mob)
	if (istype(W, ammotype))
		/*
		var/obj/item/cannon_ball/TS = W
		if (caliber != TS.caliber && caliber != null && caliber != 0)
			M << "<span class = 'warning'>\The [TS] is of the wrong caliber! You need [caliber] mm shells for this cannon.</span>"
			return
		*/
		if (loaded.len >= max_loaded)
			M << "<span class = 'warning'>There's already a [loaded[1]] loaded.</span>"
			return
		// load first and only slot
		var/loadtime = caliber/2
		if (istype(src,/obj/structure/cannon/modern/naval))
			loadtime = caliber
		if (do_after(M, loadtime, src, can_move = TRUE))
			if (M && (locate(M) in range(1,src)))
				M.remove_from_mob(W)
				W.loc = src
				loaded += W
				user << SPAN_NOTICE("You load \the [src].")
				if (M == user)
					do_html(M)
	else if (istype(W,/obj/item/weapon/wrench))
		M << (anchored ? "<span class='notice'>You start unfastening \the [src] from the floor.</span>" : "<span class='notice'>You start securing \the [src] to the floor.</span>")
		if (do_after(M, 3 SECONDS, src))
			playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
			M << (anchored ? "<span class='notice'>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
			anchored = !anchored

/obj/structure/cannon/interact(var/mob/m)
	if (user)
		if (get_dist(src, user) > 1)
			user = null
	restart
	var/found_gunner = FALSE
	for (var/obj/structure/bed/chair/gunner/G in m.loc)
		found_gunner = TRUE
	if (!found_gunner && istype(src, /obj/structure/cannon/modern/tank) && !istype(src, /obj/structure/cannon/modern/tank/voyage))
		m << "<span class = 'warning'>You need to be at the gunner's position to operate \the [src].</span>"
		user = null
		return
	if (!anchored)
		m << "<span class = 'danger'>You need to fix \the [src] to the floor to operate it.</span>"
		user = null
		return
	if (user && user != m)
		if (user.client)
			return
		else
			user = null
			goto restart
	else
		user = m
		do_html(user)

/obj/structure/cannon/Topic(href, href_list, hsrc)

	var/mob/user = usr

	if (!user || user.lying)
		return

	user.face_atom(src)
	var/istank = FALSE
	if (istype(src, /obj/structure/cannon/modern/tank))
		istank = TRUE
	var/mob/living/human/H = user
	if (istype(H) && H.faction_text == INDIANS)
		user << "<span class = 'danger'>You have no idea how this thing works.</span>"
		return FALSE

	if (!locate(user) in range(1,src))
		if (dir != EAST && dir != WEST)
			user << "<span class = 'danger'>Get behind \the [src] to use it.</span>"
			return FALSE
		else
			if (dir == SOUTH)
				var/turf/T = get_step(src,NORTH)
				if (!locate(user) in range(1,T))
					user << "<span class = 'danger'>Get behind \the [src] to use it.</span>"
					return FALSE

	if (!user.can_use_hands())
		user << "<span class = 'danger'>You have no hands to use this with.</span>"
		return FALSE

	if (istype(src, /obj/structure/cannon/modern/tank) && !istype(src, /obj/structure/cannon/modern/tank/voyage))
		var/found_gunner = FALSE
		for (var/obj/structure/bed/chair/gunner/G in user.loc)
			found_gunner = TRUE
		if (!found_gunner)
			user << "<span class = 'warning'>You need to be at the gunner's position to operate \the [src].</span>"
			return FALSE

	if (!anchored)
		user << "<span class = 'danger'>You need to fix \the [src] to the floor to operate it.</span>"
		return FALSE

	if (href_list["load"])
		if (!loaded.len)
			if (!autoloader)
				var/obj/item/cannon_ball/TS = user.get_active_hand()
				if (istype(TS, ammotype))
					if (caliber != TS.caliber && caliber != null && caliber != 0)
						user << SPAN_WARNING("\The [TS] is of the wrong caliber! You need [caliber] mm shells for this cannon.")
						return
					// load first and only slot
					var/found_loader = FALSE
					for (var/obj/structure/bed/chair/loader/L in user.loc)
						found_loader = TRUE
					if (!found_loader && istype(src, /obj/structure/cannon/modern/tank) && !istype(src, /obj/structure/cannon/modern/tank/voyage))
						user << SPAN_WARNING("You need to be at the loader's position to load \the [src].")
						return FALSE
					var/loadtime = caliber/2
					if (istype(src,/obj/structure/cannon/modern/naval))
						loadtime = caliber
					if (do_after(user, loadtime, user, can_move = TRUE))
						if (user && (locate(user) in range(1,src)))
							found_loader = FALSE
							for (var/obj/structure/bed/chair/loader/L in user.loc)
								found_loader = TRUE
							if (!found_loader && istype(src, /obj/structure/cannon/modern/tank) && !istype(src, /obj/structure/cannon/modern/tank/voyage))
								user << SPAN_WARNING("You need to be at the loader's position to load \the [src].")
								return FALSE
							user.remove_from_mob(TS)
							TS.loc = src
							loaded += TS
							user << SPAN_NOTICE("You load \the [src].")
							if (istype(src, /obj/structure/cannon/modern/tank))
								playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
							return
			else
				var/list/loadable = list()
				for (var/obj/structure/shellrack/autoloader/AL in range(1,src))
					if (AL.storage.contents)
						for (var/obj/item/cannon_ball/TS in AL.storage.contents)
							if (istype(TS, ammotype))
								if (caliber != TS.caliber && caliber != null && caliber != 0)
									user << SPAN_WARNING("\The [TS] is of the wrong caliber! You need [caliber] mm shells for this cannon.")
									continue
								loadable += TS
				/* if (!(/obj/structure/shellrack/autoloader in range(1,src)))
					user << SPAN_WARNING("There are no shell racks to load from nearby.")
					return */

				playsound(loc, 'sound/machines/autoloader.ogg', 100, TRUE)
				var/obj/item/cannon_ball/chosen

				user << SPAN_NOTICE("The autoloader begins loading a shell.")
				spawn (6 SECONDS)
					if (!loadable.len)
						user << SPAN_WARNING("There are no shells to load.")
						return
					chosen = WWinput(usr, "Select a tank shell to load", "Load Tank Shell", loadable[1], WWinput_list_or_null(loadable))
					if (!chosen || chosen == "")
						return
					chosen.loc = src
					loaded += chosen
					user << SPAN_NOTICE("The autoloader loads \the [src].")
					return

		else if (istype(src, /obj/structure/cannon/modern) || istype(src, /obj/structure/cannon/mortar))
			var/obj/item/cannon_ball/M = loaded[1]
			var/unloadtime = caliber/8
			if (do_after(user, unloadtime, user, can_move = TRUE))
				if (user && (locate(user) in range(1,src)))
					loaded -= M
					M.loc = get_turf(user)
					user.put_in_active_hand(M)
					user << SPAN_NOTICE("You unload \the [src].")
					if (istype(src, /obj/structure/cannon/modern/tank))
						playsound(loc, 'sound/effects/lever.ogg',100, TRUE)
					return

	if (href_list["set_distance"])
		distance = input(user, "Set Distance? (From [5] to [maxrange] meters)") as num
		distance = clamp(distance, 5, max_distance)

	if (href_list["distance_1minus"])
		distance = distance - 1
		distance = clamp(distance, 5, max_distance)
	if (href_list["distance_10minus"])
		distance = distance - 10
		distance = clamp(distance, 5, max_distance)

	if (href_list["distance_1plus"])
		distance = distance + 1
		distance = clamp(distance, 5, max_distance)
	if (href_list["distance_10plus"])
		distance = distance + 10
		distance = clamp(distance, 5, max_distance)

	if (href_list["set_degree"])
		var/azimuth = input(user, "Set the Azimuth to what? (From [0] to [359] degrees - N = 0, W = 90, S = 180, E = 270)") as num
		degree = azimuth + 90
		if (degree < 0)
			degree += 360
		if (degree >= 360)
			degree -= 360

	if (href_list["degree_1minus"])
		degree = degree - 1
		if (degree < 0)
			degree += 360
	if (href_list["degree_10minus"])
		degree = degree - 10
		if (degree < 0)
			degree += 360

	if (href_list["degree_10plus"])
		degree = degree + 10
		if (degree >= 360)
			degree -= 360
	if (href_list["degree_1plus"])
		degree = degree + 1
		if (degree >= 360)
			degree -= 360

	// 0 north
	// 90 west
	// 180 south
	// 270 east

	if (course)
		if (dir == NORTH)
			degree = clamp(degree, 45, 134)
		else if (dir == WEST)
			degree = clamp(degree, 135, 224)
		else if (dir == SOUTH)
			degree = clamp(degree, 225, 315)
		else
			if (degree >= 45)
				degree = 44
			if (degree < 315)
				degree = 315

	target_coords()
	update_scope()

	if (degree >= 45 && degree < 135)
		dir = NORTH
	else if (degree >= 135 && degree < 225)
		dir = WEST
	else if (degree >= 225 && degree < 315)
		dir = SOUTH
	else
		dir = EAST

	if (href_list["toggle_scope"])
		if (scope_mod == "Enabled")
			scope_mod = "Disabled"
			delete_scope_image()
			to_chat(user, SPAN_NOTICE("Scope disabled."))
		else
			scope_mod = "Enabled"
			to_chat(user,  SPAN_NOTICE("Scope enabled."))
			update_scope()

	if (href_list["fire"])

		if (!map.faction1_can_cross_blocks() && !map.faction2_can_cross_blocks())
			user << "<span class = 'danger'>You can't fire yet.</span>"
			return

		if (!loaded.len)
			user << "<span class = 'danger'>There's nothing in \the [src].</span>"
			return

		if (istype(map, /obj/map_metadata/voyage))
			var/turf/onestep = get_step(loc, src.dir)
			var/turf/twostep = get_step(onestep, src.dir)
			for (var/obj/structure/barricade/ship/BS in onestep)
				if (BS.opacity)
					user << "You have no opening to fire through!"
					return
			for (var/obj/structure/barricade/ship/BS1 in twostep)
				if (BS1.opacity)
					user << "You have no opening to fire through!"
					return

		if (istype(src, /obj/structure/cannon/rocket))
			for (var/obj/item/cannon_ball/rocket/fired_shell in loaded)
				if (do_after(user, firedelay, src, can_move = FALSE))
					// firing code

					// screen shake
					for (var/mob/m in player_list)
						if (m.client)
							var/abs_dist = abs(m.x - x) + abs(m.y - y)
							if (abs_dist <= 37)
								shake_camera(m, 3, (5 - (abs_dist/10)))

					// smoke
					spawn (rand(3,4))
						new/obj/effect/effect/smoke/chem(get_step(src, dir))
					spawn (rand(5,6))
						new/obj/effect/effect/smoke/chem(get_step(src, dir))

					// sound
					spawn (rand(1,2))
						var/turf/t1 = get_turf(src)
						playsound(t1, 'sound/weapons/guns/fire/rpg7.ogg', 100, TRUE)
						playsound(t1, pick('sound/effects/aircraft/effects/missile1.ogg','sound/effects/aircraft/effects/missile2.ogg'), 40, TRUE)

					// actual hit somewhere (or not)
					var/turf/target = get_turf(src)

					max_distance = rand(max_distance - round(max_distance/10), max_distance + round(max_distance/10))

					high_distance = max_distance * 0.80

					travelled = 0
					high = TRUE

					if (fired_shell.atype == "INCENDIARY")
						explosion = FALSE
						incendiary = TRUE

					loaded -= fired_shell
					qdel(fired_shell)

					spawn (0)
						var/v = max_distance

						if (v > max_distance * 0.80)
							high = FALSE

						var/hit = FALSE

						var/tx = x + target_x + rand(-2,2)
						var/ty = y + target_y + rand(-2,2)
						if (tx < 1)
							tx = 1
						if (tx > world.maxx)
							tx = world.maxx
						if (ty < 1)
							ty = 1
						if (ty > world.maxy)
							ty = world.maxy
						target = locate(tx, ty, z)
						var/highcheck = high
						var/area/target_area = get_area(target)
						if (target_area.location == AREA_INSIDE)
							highcheck = FALSE

						if (v >= max_distance)
							hit = TRUE
						else if (target.density && !highcheck)
							hit = TRUE
						else if (target && !(target in range(1, get_turf(src))))
							if (!highcheck)
								for (var/atom/movable/AM in target)
									// go over sandbags
									if (AM.density && !(AM.flags & ON_BORDER))
										var/obj/structure/S = AM
										// go over some structures
										if (istype(S) && S.low)
											continue
										hit = TRUE
										break

						if (hit)
							playsound(target, pick('sound/effects/aircraft/effects/missile1.ogg','sound/effects/aircraft/effects/missile2.ogg'), 60, TRUE)
							spawn(10)
								playsound(target, "artillery_in", 60, TRUE)
							spawn (10)
								if (explosion)
									explosion(target, 1, 2, 3, 4)
									if (locate(/obj/structure/vehicleparts/frame) in target)
										for (var/obj/structure/vehicleparts/frame/F in range(1,target))
											if (F.axis)
												for (var/mob/M in F.axis.transporting)
													shake_camera(M, 3, 3)
											playsound(target, pick('sound/machines/tank/tank_ricochet1.ogg','sound/machines/tank/tank_ricochet2.ogg','sound/machines/tank/tank_ricochet3.ogg'),100, TRUE)
											target.visible_message(SPAN_DANGER("<big>The hull gets hit by a rocket!</big>"))
											F.w_front[5] -= rand(8,16)
											F.w_back[5] -= rand(8,16)
											F.w_left[5] -= rand(8,16)
											F.w_right[5] -= rand(8,16)

											F.try_destroy()
								if (incendiary)
									explosion(target, 0, 1, 3, 4)
									for (var/turf/floor/T in circlerangeturfs(3,target))
										if (!locate(/obj/structure/vehicleparts/frame) in T)
											ignite_turf(T, 12, 70)
								else
									message_admins("Gas rocket shell ([reagent_payload]) hit at ([target.x],[target.y],[target.z]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[target.x];Y=[target.y];Z=[target.z]'>JMP</a>).")
									log_admin("Gas rocket shell ([reagent_payload]) hit at ([target.x],[target.y],[target.z]).")
									var/how_many = 24 // half of 49, the radius we spread over (7x7)
									for (var/k in 1 to how_many)
										switch (reagent_payload)
											if ("chlorine")
												new/obj/effect/effect/smoke/chem/payload/chlorine_gas(target)
											if ("mustard_gas")
												new/obj/effect/effect/smoke/chem/payload/mustard_gas(target)
											if ("white_phosphorus_gas")
												new/obj/effect/effect/smoke/chem/payload/white_phosphorus_gas(target)
											if ("xylyl_bromide")
												new/obj/effect/effect/smoke/chem/payload/xylyl_bromide(target)
											if ("phosgene_gas")
												new/obj/effect/effect/smoke/chem/payload/phosgene(target)
											if ("smokescreen")
												new/obj/effect/effect/smoke/bad(target)
						sleep(0.5)
				else
					return
		else
			if (do_after(user, firedelay, src, can_move = istank))
				if (loaded.len)
					// firing code

					// screen shake
					for (var/mob/m in player_list)
						if (m.client)
							var/abs_dist = abs(m.x - x) + abs(m.y - y)
							if (abs_dist <= 37)
								shake_camera(m, 3, (5 - (abs_dist/10)))

					// smoke
					spawn (rand(3,4))
						new/obj/effect/effect/smoke/chem(get_step(src, dir))
					spawn (rand(5,6))
						new/obj/effect/effect/smoke/chem(get_step(src, dir))

					// sound
					spawn (rand(1,2))
						var/turf/t1 = get_turf(src)
						playsound(t1, "artillery_out", 100, TRUE)
						playsound(t1, "artillery_out_distant", 100, TRUE)

					// actual hit somewhere (or not)
					if (istype(src, /obj/structure/cannon/modern/tank))
						var/obj/structure/cannon/modern/tank/T = src
						T.do_tank_fire(user)
					else
						var/turf/target = get_turf(src)

						max_distance = rand(max_distance - round(max_distance/10), max_distance + round(max_distance/10))

						high_distance = max_distance * 0.80

						travelled = 0
						high = TRUE
						var/obj/item/cannon_ball/fired_shell = loaded[1]

						if (istype(fired_shell, /obj/item/cannon_ball/shell/gas))
							explosion = FALSE
							reagent_payload = fired_shell.reagent_payload
						if (istype(fired_shell, /obj/item/cannon_ball/mortar_shell/smoke))
							explosion = FALSE
							reagent_payload = fired_shell.reagent_payload

						if (fired_shell.atype == "INCENDIARY")
							explosion = FALSE
							incendiary = TRUE

						if (istype(fired_shell, /obj/item/cannon_ball/shell/nuclear))
							nuclear = TRUE

						loaded -= fired_shell
						qdel(fired_shell)

						spawn (0)
							var/v = max_distance

							if (v > high_distance)
								high = FALSE

							var/hit = FALSE
							
							var/tx = x + target_x + rand(-1,1)
							var/ty = y + target_y + rand(-1,1)

							if (istype(src, /obj/structure/cannon/modern/naval))
								tx += rand(-4,4)
								ty += rand(-4,4)
							else
								tx += rand(-1,1)
								ty += rand(-1,1)

							if (tx < 1)
								tx = 1
							if (tx > world.maxx)
								tx = world.maxx
							if (ty < 1)
								ty = 1
							if (ty > world.maxy)
								ty = world.maxy
							target = locate(tx, ty, z)
							var/highcheck = high
							var/area/target_area = get_area(target)
							if (target_area.location == AREA_INSIDE)
								highcheck = FALSE

							if (v >= max_distance)
								hit = TRUE
							else if (target.density && !highcheck)
								hit = TRUE
							else if (target && !(target in range(1, get_turf(src))))
								if (!highcheck)
									for (var/atom/movable/AM in target)
										// go over sandbags
										if (AM.density && !(AM.flags & ON_BORDER))
											var/obj/structure/S = AM
											// go over some structures
											if (istype(S) && S.low)
												continue
											hit = TRUE
											break

							if (hit)
								playsound(target, "artillery_in", 70, TRUE)
								spawn (10)
									if (explosion)
										if (istype(fired_shell, /obj/item/cannon_ball/mortar_shell))
											if (locate(/obj/structure/vehicleparts/frame) in target)
												for (var/obj/structure/vehicleparts/frame/F in range(1,target))
													if (F.axis)
														for (var/mob/M in F.axis.transporting)
															shake_camera(M, 3, 3)
													playsound(target, pick('sound/machines/tank/tank_ricochet1.ogg','sound/machines/tank/tank_ricochet2.ogg','sound/machines/tank/tank_ricochet3.ogg'),100, TRUE)
													target.visible_message(SPAN_DANGER("<big>The hull gets hit by a mortar shell!</big>"))
													F.w_front[5] -= rand(1,7)
													F.w_back[5] -= rand(1,7)
													F.w_left[5] -= rand(1,7)
													F.w_right[5] -= rand(1,7)

													F.try_destroy()
											else
												explosion(target, 1, 2, 2, 3)
												var/list/fragment_types = list(/obj/item/projectile/bullet/pellet/fragment/short_range = 1)
												fragmentate(target, 12, 7, fragment_types)

										else if (istype(fired_shell, /obj/item/cannon_ball/shell/naval/HE380))
											explosion(target, 2, 3, 3, 4)
											if (target.z > 1)
												var/turf/tgtbelow = locate(target.x,target.y,target.z-1)
												if (tgtbelow)
													explosion(tgtbelow, 2, 2, 2, 3)
										else if (istype(fired_shell, /obj/item/cannon_ball/shell/naval/HE150))
											explosion(target, 2, 2, 2, 3)
											if (target.z > 1)
												var/turf/tgtbelow = locate(target.x,target.y,target.z-1)
												if (tgtbelow)
													explosion(tgtbelow, 1, 2, 2, 3)

										else
											explosion(target, 2, 3, 4, 6)
											if (locate(/obj/structure/vehicleparts/frame) in target)
												for (var/obj/structure/vehicleparts/frame/F in range(1,target))
													if (F.axis)
														for (var/mob/M in F.axis.transporting)
															shake_camera(M, 3, 3)
													playsound(target, pick('sound/machines/tank/tank_ricochet1.ogg','sound/machines/tank/tank_ricochet2.ogg','sound/machines/tank/tank_ricochet3.ogg'),100, TRUE)
													target.visible_message(SPAN_DANGER("<big>The hull gets hit by an artillery shell!</big>"))
													F.w_front[5] -= rand(8,16)
													F.w_back[5] -= rand(8,16)
													F.w_left[5] -= rand(8,16)
													F.w_right[5] -= rand(8,16)

													F.try_destroy()

									if (incendiary)
										if (istype(src, /obj/structure/cannon/mortar))
											if (locate(/obj/structure/vehicleparts/frame) in target)
												for (var/obj/structure/vehicleparts/frame/F in range(1,target))
													if (F.axis)
														for (var/mob/M in F.axis.transporting)
															shake_camera(M, 3, 3)
													playsound(target, pick('sound/machines/tank/tank_ricochet1.ogg','sound/machines/tank/tank_ricochet2.ogg','sound/machines/tank/tank_ricochet3.ogg'),100, TRUE)
													target.visible_message(SPAN_DANGER("<big>The hull gets hit by an incendiary mortar shell!</big>"))
													F.w_front[5] -= rand(5,20)
													F.w_back[5] -= rand(5,20)
													F.w_left[5] -= rand(5,20)
													F.w_right[5] -= rand(5,20)

													F.try_destroy()
											else
												explosion(target, 0, 1, 2, 3)
											for (var/turf/floor/T in circlerangeturfs(2,target))
												if (!locate(/obj/structure/vehicleparts/frame) in T)
													ignite_turf(T, 12, 70)
										else
											explosion(target, 0, 1, 3, 4)
											if (locate(/obj/structure/vehicleparts/frame) in target)
												target.visible_message(SPAN_DANGER("<big>The hull gets hit by an incendiary artillery shell!</big>"))
											for (var/turf/floor/T in circlerangeturfs(3,target))
												if (!locate(/obj/structure/vehicleparts/frame) in T)
													ignite_turf(T, 12, 70)

									if (nuclear)
										if (istype(fired_shell, /obj/item/cannon_ball/shell/nuclear/W9))
											radiation_pulse(target, 10, 60, 1400, TRUE)
											explosion(target, 2, 2, 2, 100)
											change_global_pollution(150)
											change_global_radiation(10)
										else if (istype(fired_shell, /obj/item/cannon_ball/shell/nuclear/W19))
											radiation_pulse(target, 8, 70, 1400, TRUE)
											explosion(target, 2, 2, 2, 100)
											change_global_pollution(150)
											change_global_radiation(10)
										else if (istype(fired_shell, /obj/item/cannon_ball/shell/nuclear/W33))
											radiation_pulse(target, 10, 45, 1000, TRUE)
											explosion(target, 2, 2, 2, 100)
											change_global_pollution(150)
											change_global_radiation(10)
										else if (istype(fired_shell, /obj/item/cannon_ball/shell/nuclear/W33Boosted))
											radiation_pulse(target, 10, 50, 1400, TRUE)
											explosion(target, 2, 2, 2, 100)
											change_global_pollution(150)
											change_global_radiation(10)
										else if (istype(fired_shell, /obj/item/cannon_ball/shell/nuclear/nomads))
											radiation_pulse(target, 18, 150, 1000, TRUE)
											explosion(target, 5, 8, 20, 80)
											for (var/turf/floor/T in circlerangeturfs(4, target))
												ignite_turf(T, 8, 70)
											change_global_pollution(200)
											change_global_radiation(18)
										else if (istype(fired_shell,/obj/item/cannon_ball/rocket/nuclear))
											radiation_pulse(target, 12, 80, 1400, TRUE)
											explosion(target, 2, 2, 2, 30)
											change_global_pollution(150)
											change_global_radiation(10)
										else
											radiation_pulse(target, 4, 50, 800, TRUE)
											explosion(target, 2, 2, 2, 100)
											change_global_pollution(150)
											change_global_radiation(10)

										world << SPAN_DANGER("<big>A nuclear explosion has happened!</big>")
										for(var/mob/living/human/L in circlerangeturfs(30, target))
											L.Weaken(3)
											if (L.HUDtech.Find("flash"))
												flick("e_flash", L.HUDtech["flash"])

									else
										message_admins("Gas artillery shell ([reagent_payload]) hit at ([target.x],[target.y],[target.z]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[target.x];Y=[target.y];Z=[target.z]'>JMP</a>)..")
										log_admin("Gas artillery shell ([reagent_payload]) hit at ([target.x],[target.y],[target.z]).")
										var/how_many = 24 // half of 49, the radius we spread over (7x7)
										for (var/k in 1 to how_many)
											switch (reagent_payload)
												if ("chlorine")
													new/obj/effect/effect/smoke/chem/payload/chlorine_gas(target)
												if ("mustard_gas")
													new/obj/effect/effect/smoke/chem/payload/mustard_gas(target)
												if ("white_phosphorus_gas")
													new/obj/effect/effect/smoke/chem/payload/white_phosphorus_gas(target)
												if ("xylyl_bromide")
													new/obj/effect/effect/smoke/chem/payload/xylyl_bromide(target)
												if ("phosgene_gas")
													new/obj/effect/effect/smoke/chem/payload/phosgene(target)
												if ("smokescreen")
													new/obj/effect/effect/smoke/bad(target)
									/*
									var/target_area_original_integrity = target_area.artillery_integrity
									if (target_area.location == AREA_INSIDE && !target_area.arty_act(25))
										for (var/mob/living/L in view(20, target))
											shake_camera(L, 5, 5)
											L << "<span class = 'danger'>You hear something violently smash into the ceiling!</span>"
									else if (target_area_original_integrity)
										target.visible_message("<span class = 'danger'>The ceiling collapses!</span>")
									*/
							sleep(0.5)

	do_html(user)

/obj/structure/cannon/proc/do_html(var/mob/m)

	if (m)
		var/azimuth = degree - 90
		if (azimuth < 0)
			azimuth += 360
		if (azimuth >= 360)
			azimuth -= 360
		max_distance = maxrange

		m << browse({"

		<br>
		<html>

		<head>
		[common_browser_style]
		</head>

		<body>

		<script language="javascript">

		function set(input) {
		  window.location="byond://?src=\ref[src];action="+input.name+"&value="+input.value;
		}

		</script>

		<center>
		<big><b>[name]</b></big><br><br>
		</center>
		Shell: <a href='?src=\ref[src];load=1'>[loaded.len ? loaded[1].name : (autoloader ? "Click here to load shell" : "No shell loaded")]</a>[see_amount_loaded ? (loaded.len ? " <b>There are [loaded.len] [loaded[1].name]s loaded.</b>" : " <b>There is nothing loaded.</b>") : ""]<br><br>
		Increase/Decrease <b>distance</b>: <a href='?src=\ref[src];distance_1minus=1'>-1</a> | <a href='?src=\ref[src];set_distance=1'>[distance] meters</a> | <a href='?src=\ref[src];distance_1plus=1'>+1</a><br><br>
		Increase/Decrease <b>azimuth</b>: <a href='?src=\ref[src];degree_10plus=10'>+10</a> | <a href='?src=\ref[src];degree_1plus=1'>+1</a> | <a href='?src=\ref[src];set_degree=1'>[azimuth] degrees</a> | <a href='?src=\ref[src];degree_1minus=1'>-1</a> | <a href='?src=\ref[src];degree_10minus=1'>-10</a><br><br>
		Scope: [has_scope ? ("<a href='?src=\ref[src];toggle_scope=1'>[scope_mod]</a>") : "This weapon has no scope" ] <br><br>
		<br>
		<center>
		<a href='?src=\ref[src];fire=1'><b><big>FIRE!</big></b></a>
		</center>

		</body>
		</html>
		<br>
		"},  "window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=500x500")
	//		<A href = '?src=\ref[src];topic_type=[topic_custom_input];continue_num=1'>

/obj/structure/cannon/proc/target_coords()
	target_x = round(abs(distance * cos(degree))) * sign(cos(degree))
	target_y = round(abs(distance * sin(degree))) * sign(sin(degree))

/obj/structure/cannon/proc/sway()
	if (degree > 315 || degree < 45)
		return target_x
	else if (degree >= 45 && degree < 135)
		return target_y
	else if (degree >= 135 && degree < 225)
		return (-1 * target_x)
	else
		return (-1 * target_y)

/obj/structure/cannon/proc/rotate_to(var/new_dir)
	if (new_dir == NORTH)
		degree = 0
	else if (new_dir == WEST)
		degree = 90
	else if (new_dir == SOUTH)
		degree = 180
	else
		degree = 270
	dir = new_dir
	target_coords()
	update_scope()

/obj/structure/cannon/proc/delete_scope_image()
	for (var/image/img in usr.client.images)
		if (img.icon_state == "point")
			user.client.images.Remove(img)
		if (img.icon_state == "cannon_target")
			user.client.images.Remove(img)

/obj/structure/cannon/proc/update_scope()
	if (scope_mod == "Enabled")
		delete_scope_image()
		var/image/targeted_image
		target_coords()
		var/i
		for(i = 1, i <= distance, i++)
			var/point_x = round(abs(i * cos(degree))) * sign(cos(degree))
			var/point_y = round(abs(i * sin(degree))) * sign(sin(degree))
			if (point_x != 0 || point_y != 0)
				targeted_image = new/image('icons/effects/Targeted.dmi', src, icon_state = "point", pixel_x = point_x * 32, pixel_y = point_y * 32, layer = 12)
				usr.client.images += targeted_image
		targeted_image = new/image('icons/effects/Targeted.dmi', src, icon_state = "cannon_target", pixel_x = target_x * 32, pixel_y = target_y * 32, layer = 12)
		usr.client.images += targeted_image

/obj/structure/cannon/verb/rotate_left()
	set category = null
	set name = "Rotate Left"
	set src in range(2, usr)

	if (!istype(usr, /mob/living))
		return

	if (!is_naval)
		if (course)
			to_chat(user, SPAN_DANGER("You can't turn \the [src]."))
			return
		switch(dir)
			if (EAST)
				dir = NORTH
				degree = 0
				if (spritemod)
					bound_height = 64
					bound_width = 32
					icon = 'icons/obj/cannon.dmi'
					icon_state = "cannon"
			if (WEST)
				dir = SOUTH
				degree = 180
				if (spritemod)
					bound_height = 64
					bound_width = 32
					icon = 'icons/obj/cannon.dmi'
					icon_state = "cannon"
			if (NORTH)
				dir = WEST
				degree = 270
				if (spritemod)
					bound_height = 32
					bound_width = 64
					icon = 'icons/obj/cannon.dmi'
					icon_state = "cannon"
			if (SOUTH)
				dir = EAST
				degree = 90
				if (spritemod)
					bound_height = 32
					bound_width = 64
					icon = 'icons/obj/cannon.dmi'
					icon_state = "cannon"
	else
		var/turf/behind
		switch (dir)
			if (NORTH)
				behind = locate(src.x, src.y-1, src.z)
			if (SOUTH)
				behind = locate(src.x, src.y+1, src.z)
			if (EAST)
				behind = locate(src.x-1, src.y, src.z)
			if (WEST)
				behind = locate(src.x+1, src.y, src.z)
		var/obj/structure/bed/chair/chair_found
		for (var/obj/structure/bed/chair/chair in behind)
			chair_found = chair

		switch (dir)
			if (EAST)
				dir = NORTH
				degree = 0
				pixel_y = 0
				switch (naval_position)
					if ("middle")
						pixel_x = -32
						src.x -= 2
						src.y += 2
					if ("left")
						pixel_x = -20
						src.x -= 3
						src.y += 1
					if ("right")
						pixel_x = -44
						src.x -= 1
						src.y += 3
			if (WEST)
				dir = SOUTH
				degree = 180
				pixel_y = -64
				switch (naval_position)
					if ("middle")
						pixel_x = -32
						src.x += 2
						src.y -= 2
					if ("left")
						pixel_x = -44
						src.x += 3
						src.y -= 1
					if ("right")
						pixel_x = -20
						src.x += 1
						src.y -= 3
			if (NORTH)
				dir = WEST
				degree = 270
				pixel_x = -64
				switch (naval_position)
					if ("middle")
						pixel_y = -32
						src.x -= 2
						src.y -= 2
					if ("left")
						pixel_y = -20
						src.x -= 1
						src.y -= 3
					if ("right")
						pixel_y = -44
						src.x -= 3
						src.y -= 1
			if (SOUTH)
				dir = EAST
				degree = 90
				pixel_x = 0
				switch (naval_position)
					if ("middle")
						pixel_y = -32
						src.x += 2
						src.y += 2
					if ("left")
						pixel_y = -44
						src.x += 3
						src.y += 1
					if ("right")
						pixel_y = -20
						src.x += 1
						src.y += 3
		var/turf/new_behind
		switch (dir)
			if (NORTH)
				new_behind = locate(src.x, src.y-1, src.z)
			if (SOUTH)
				new_behind = locate(src.x, src.y+1, src.z)
			if (EAST)
				new_behind = locate(src.x-1, src.y, src.z)
			if (WEST)
				new_behind = locate(src.x+1, src.y, src.z)
		if (chair_found)
			chair_found.loc = new_behind
			chair_found.dir = src.dir
			if (chair_found.buckled_mob)
				chair_found.buckled_mob.loc = new_behind

	target_coords()
	update_scope()
	return

/obj/structure/cannon/verb/rotate_right()
	set category = null
	set name = "Rotate Right"
	set src in range(2, usr)

	if (!istype(usr, /mob/living))
		return

	if (!is_naval)
		if (course)
			to_chat(user, SPAN_DANGER("You can't turn \the [src]."))
			return
		switch(dir)
			if (EAST)
				dir = SOUTH
				degree = 180
				if (spritemod)
					bound_height = 64
					bound_width = 32
					icon = 'icons/obj/cannon.dmi'
					icon_state = "cannon"
			if (WEST)
				dir = NORTH
				degree = 0
				if (spritemod)
					bound_height = 64
					bound_width = 32
					icon = 'icons/obj/cannon.dmi'
					icon_state = "cannon"
			if (NORTH)
				dir = EAST
				degree = 90
				if (spritemod)
					bound_height = 32
					bound_width = 64
					icon = 'icons/obj/cannon.dmi'
					icon_state = "cannon"
			if (SOUTH)
				dir = WEST
				degree = 270
				if (spritemod)
					bound_height = 32
					bound_width = 64
					icon = 'icons/obj/cannon.dmi'
					icon_state = "cannon"
	else
		var/turf/behind
		switch (dir)
			if (NORTH)
				behind = locate(src.x, src.y-1, src.z)
			if (SOUTH)
				behind = locate(src.x, src.y+1, src.z)
			if (EAST)
				behind = locate(src.x-1, src.y, src.z)
			if (WEST)
				behind = locate(src.x+1, src.y, src.z)
		var/obj/structure/bed/chair/chair_found
		for (var/obj/structure/bed/chair/chair in behind)
			chair_found = chair

		switch (dir)
			if (EAST)
				dir = SOUTH
				degree = 180
				pixel_y = -64
				switch (naval_position)
					if ("middle")
						pixel_x = -32
						src.x -= 2
						src.y -= 2
					if ("left")
						pixel_x = -44
						src.x -= 1
						src.y -= 3
					if ("right")
						pixel_x = -20
						src.x -= 3
						src.y -= 1
			if (WEST)
				dir = NORTH
				degree = 0
				pixel_y = 0
				switch (naval_position)
					if ("middle")
						pixel_x = -32
						src.x += 2
						src.y += 2
					if ("left")
						pixel_x = -20
						src.x += 1
						src.y += 3
					if ("right")
						pixel_x = -44
						src.x += 3
						src.y += 1
			if (NORTH)
				dir = EAST
				degree = 90
				pixel_x = 0
				switch (naval_position)
					if ("middle")
						pixel_y = -32
						src.x += 2
						src.y -= 2
					if ("left")
						pixel_y = -44
						src.x += 3
						src.y -= 1
					if ("right")
						pixel_y = -20
						src.x += 1
						src.y -= 3
			if (SOUTH)
				dir = WEST
				degree = 270
				pixel_x = -64
				switch (naval_position)
					if ("middle")
						pixel_y = -32
						src.x -= 2
						src.y += 2
					if ("left")
						pixel_y = -20
						src.x -= 1
						src.y += 3
					if ("right")
						pixel_y = -44
						src.x -= 3
						src.y += 1
		var/turf/new_behind
		switch (dir)
			if (NORTH)
				new_behind = locate(src.x, src.y-1, src.z)
			if (SOUTH)
				new_behind = locate(src.x, src.y+1, src.z)
			if (EAST)
				new_behind = locate(src.x-1, src.y, src.z)
			if (WEST)
				new_behind = locate(src.x+1, src.y, src.z)
		if (chair_found)
			chair_found.loc = new_behind
			chair_found.dir = src.dir
			if (chair_found.buckled_mob)
				chair_found.buckled_mob.loc = new_behind

	target_coords()
	update_scope()
	return
/obj/structure/cannon/relaymove(var/mob/mob, direction)
	if (direction)
		// prevents going over the invisible wall
		var/list/dirs = list()

		switch (direction)
			if (NORTHEAST)
				dirs += NORTH
				dirs += EAST
			if (NORTHWEST)
				dirs += NORTH
				dirs += WEST
			if (SOUTHEAST)
				dirs += SOUTH
				dirs += EAST
			if (SOUTHWEST)
				dirs += SOUTH
				dirs += WEST
			else
				dirs += direction

		for (var/refdir in dirs)
			var/turf/ref = get_step(mob, refdir)

			if (ref && map.check_caribbean_block(mob, ref))
				mob.dir = direction
				return FALSE

	// bug abusers btfo
	if (map.check_caribbean_block(mob, get_turf(mob)))
		return FALSE
	if (spritemod)
		switch (dir)
			if (SOUTH)
				bound_height = 64
				bound_width = 32
				pixel_x = -16
				pixel_y = 0
				icon = 'icons/obj/cannon.dmi'
				icon_state = "cannon"
			if (NORTH)
				bound_height = 64
				bound_width = 32
				pixel_x = -16
				pixel_y = 0
				icon = 'icons/obj/cannon.dmi'
				icon_state = "cannon"
			if (EAST)
				bound_height = 32
				bound_width = 64
				pixel_x = 0
				pixel_y = -16
				icon = 'icons/obj/cannon.dmi'
				icon_state = "cannon"
			if (WEST)
				bound_height = 32
				bound_width = 64
				pixel_x = 0
				pixel_y = -16
				icon = 'icons/obj/cannon.dmi'
				icon_state = "cannon"
	return TRUE

/obj/structure/cannon/Bump(var/atom/A, yes)

	if (throwing)
		throw_impact(A)
		throwing = FALSE

	spawn(0)
		if (A && yes)
			A.last_bumped = world.time
			A.Bumped(src)
		return
	if (spritemod)
		switch (dir)
			if (SOUTH)
				bound_height = 64
				bound_width = 32
				pixel_x = -16
				pixel_y = 0
				icon = 'icons/obj/cannon.dmi'
				icon_state = "cannon"
			if (NORTH)
				bound_height = 64
				bound_width = 32
				pixel_x = -16
				pixel_y = 0
				icon = 'icons/obj/cannon.dmi'
				icon_state = "cannon"
			if (EAST)
				bound_height = 32
				bound_width = 64
				pixel_x = 0
				pixel_y = -16
				icon = 'icons/obj/cannon.dmi'
				icon_state = "cannon"
			if (WEST)
				bound_height = 32
				bound_width = 64
				pixel_x = 0
				pixel_y = -16
				icon = 'icons/obj/cannon.dmi'
				icon_state = "cannon"
	..()
	return

/obj/structure/cannon/Move(var/turf/NewLoc, var/newdir)
	..()
	if (spritemod)
		switch(newdir)
			if (SOUTH)
				bound_height = 64
				bound_width = 32
				pixel_x = -16
				pixel_y = 0
				icon = 'icons/obj/cannon.dmi'
				icon_state = "cannon"
			if (NORTH)
				bound_height = 64
				bound_width = 32
				pixel_x = -16
				pixel_y = 0
				icon = 'icons/obj/cannon.dmi'
				icon_state = "cannon"
			if (EAST)
				bound_height = 32
				bound_width = 64
				pixel_x = 0
				pixel_y = -16
				icon = 'icons/obj/cannon.dmi'
				icon_state = "cannon"
			if (WEST)
				bound_height = 32
				bound_width = 64
				pixel_x = 0
				pixel_y = -16
				icon = 'icons/obj/cannon.dmi'
				icon_state = "cannon"

/obj/structure/cannon/modern/tank/proc/do_tank_fire(var/mob/user)
	if (!loaded.len)
		return FALSE
	var/turf/TF
	target_coords()
	TF = locate(src.x + target_x,src.y + target_y,z)
	if (!TF)
		return FALSE
	var/sub = loaded[1].subtype
	var/obj/item/projectile/shell/S = new sub(loc)
	S.damage = loaded[1].damage
	S.atype = loaded[1].atype
	S.caliber = loaded[1].caliber
	S.heavy_armor_penetration = loaded[1].heavy_armor_penetration
	S.name = loaded[1].name
	S.starting = get_turf(src)

	loaded -= loaded[1]
	if (S.atype == "grapeshot")
		var/tot = pick(3,4)
		for(var/i = 1, i<= tot,i++)
			var/obj/item/projectile/shell/S1 = new S.type(loc)
			S1.damage = S.damage
			S1.atype = S.atype
			S1.caliber = S.caliber
			S1.heavy_armor_penetration = S.heavy_armor_penetration
			S1.name = S.name
			S1.starting = get_turf(src)
			S1.launch(TF, user, src, rand(-2,2), 0)
	else
		S.launch(TF, user, src, 0, 0)
	return TRUE