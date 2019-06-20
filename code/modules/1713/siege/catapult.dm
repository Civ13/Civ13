/obj/structure/catapult
	name = "Catapult"
	icon = 'icons/obj/catapult.dmi'
	layer = MOB_LAYER + 1 //just above mobs
	density = TRUE
	icon_state = "catapult0"
	var/angle = 20
	var/travelled = 0
	var/max_distance = 0
	var/high_distance = 0
	var/high = TRUE
	var/mob/user = null
	var/obj/item/catapult_ball/loaded = null
	bound_height = 64
	bound_width = 32
	anchored = TRUE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE

/obj/structure/catapult/New()
	..()
	catapult_piece_list += src


/obj/structure/catapult/Destroy()
	catapult_piece_list -= src
	..()

/obj/structure/catapult/ex_act(severity)
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


/obj/structure/catapult/attack_hand(var/mob/attacker)
	interact(attacker)

// todo: loading artillery. This will regenerate the shrapnel and affect our explosion
/obj/structure/catapult/attackby(obj/item/W as obj, mob/M as mob)
	if (istype(W, /obj/item/catapult_ball))
		if (loaded)
			M << "<span class = 'warning'>There's already a projectile loaded.</span>"
			return
		// load first and only slot
		M.remove_from_mob(W)
		W.loc = src
		loaded = W
		icon_state = "catapult1"
		update_icon()
		if (M == user)
			do_html(M)
	else if (istype(W,/obj/item/weapon/hammer))
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		user << (anchored ? "<span class='notice'>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored
	else
		..()


/obj/structure/catapult/interact(var/mob/m)
	if (user)
		if (get_dist(src, user) > 1)
			user = null
	restart
	if (!anchored)
		user << "<span class = 'danger'>You need to fix it to the floor before firing.</span>"
		user = null
	if (user && user != m)
		if (user.client)
			return
		else
			user = null
			goto restart
	else
		user = m
		do_html(user)

/obj/structure/catapult/Topic(href, href_list, hsrc)

	var/mob/user = usr

	if (!user || user.lying)
		return

	user.face_atom(src)

	var/mob/living/carbon/human/H = user
	if (istype(H) && H.faction_text == "INDIANS")
		user << "<span class = 'danger'>You have no idea how this thing works.</span>"
		return FALSE

	if (!locate(src) in get_step(user, user.dir))
		user << "<span class = 'danger'>Get behind the catapult to use it.</span>"
		return FALSE

	if (!user.can_use_hands())
		user << "<span class = 'danger'>You have no hands to use this with.</span>"
		return FALSE

	if (!anchored)
		user << "<span class = 'danger'>You need to fix it to the floor before firing.</span>"
		return FALSE

	if (href_list["load"])
		var/obj/item/catapult_ball/M = user.get_active_hand()
		if (M && istype(M) && do_after(user, 10, src))
			user.remove_from_mob(M)
			M.loc = src
			loaded = M

	if (href_list["set_angle"])
		angle = input(user, "Set the target distance to what? (From 5 to 80 meters)") as num
		angle = Clamp(angle, 5, 80)

	if (href_list["fire"])

		if (map)
			if (!map.faction1_can_cross_blocks() && !map.faction2_can_cross_blocks())
				user << "<span class = 'danger'>You can't fire yet.</span>"
				return

		if (!loaded)
			user << "<span class = 'danger'>There's nothing in the catapult.</span>"
			return


		if (do_after(user, 20, src))

			// firing code

			// screen shake
			for (var/mob/m in player_list)
				if (m.client)
					var/abs_dist = abs(m.x - x) + abs(m.y - y)
					if (abs_dist <= 37)
						shake_camera(m, 3, (5 - (abs_dist/10)))

			// sound
			spawn (rand(1,2))
				var/turf/t1 = get_turf(src)
				playsound(t1, 'sound/effects/catapult.ogg', 100, TRUE)
				playsound(t1, "artillery_out_distant", 100, TRUE)

			// actual hit somewhere (or not)
			var/turf/target = get_turf(src)
			var/odir = dir

			max_distance = angle + rand(2,7)

			switch (dir)
				if (WEST)
					max_distance = min(max_distance, x - 5)
				if (EAST)
					max_distance = min(max_distance, world.maxx - x - 5)
				if (NORTH)
					max_distance = min(max_distance, world.maxy - y - 5)
				if (SOUTH)
					max_distance = min(max_distance, y - 5)

			high_distance = max_distance * 0.80


			travelled = 0
			high = TRUE
			qdel(loaded)
			loaded = null
			icon_state = "catapult_fire"
			update_icon()
			spawn(10)
				icon_state = "catapult0"
				update_icon()
			var/list/old_valid_targets = list()

			spawn (0)
				for (var/v in 1 to max_distance)

					if (v > high_distance)
						high = FALSE

					var/hit = FALSE

					if (target)
						old_valid_targets.Insert(old_valid_targets.len+1, target)

					var/skew = v >= 10

					switch (odir)
						if (EAST)
							target = locate(target.x+1, target.y + (prob(20) && skew ? pick(1,-1) : 0), z)
						if (WEST)
							target = locate(target.x-1, target.y + (prob(20) && skew ? pick(1,-1) : 0), z)
						if (NORTH)
							target = locate(target.x + (prob(20) && skew ? pick(1,-1) : 0), target.y+1, z)
						if (SOUTH)
							target = locate(target.x + (prob(20) && skew ? pick(1,-1) : 0), target.y-1, z)

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
					else if (!target)
						if (!old_valid_targets.len)
							break
						else
							target = old_valid_targets[old_valid_targets.len]
							hit = TRUE

					if (hit)
						playsound(target, "artillery_in", 70, TRUE)
						spawn (10)
							var/target_area_original_integrity = target_area.artillery_integrity
							if (target_area.location == AREA_INSIDE && !target_area.arty_act(25))
								for (var/mob/living/L in view(20, target))
									shake_camera(L, 5, 5)
									L << "<span class = 'danger'>You hear something violently smash into the ceiling!</span>"
								message_admins("Catapult projectile hit the ceiling at [target.x], [target.y], [target.z].")
								log_admin("Catapult projectile hit the ceiling at [target.x], [target.y], [target.z].")
								return
							else if (target_area_original_integrity)
								target.visible_message("<span class = 'danger'>The ceiling collapses!</span>")
							message_admins("Catapult projectile hit at [target.x], [target.y], [target.z].")
							log_admin("Catapult projectile hit at [target.x], [target.y], [target.z].")
							explosion(target, 1, 2, 2, 0)
						break

					sleep(0.5)

	do_html(user)

/obj/structure/catapult/proc/do_html(var/mob/m)

	if (m)

		max_distance = angle

		m << browse({"

		<br>
		<html>

		<head>
		<style>
		[common_browser_style]
		</style>
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
		Shell: <a href='?src=\ref[src];load=1'>[loaded ? loaded.name : "No projectile loaded"]</a><br><br>
		Distance: <a href='?src=\ref[src];set_angle=1'>[angle] meters</a><br><br>
		<br>
		<center>
		<a href='?src=\ref[src];fire=1'><b><big>FIRE!</big></b></a>
		</center>

		</body>
		</html>
		<br>
		"},  "window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=500x500")
	//		<A href = '?src=\ref[src];topic_type=[topic_custom_input];continue_num=1'>

/obj/structure/catapult/verb/rotate_left()
	set category = null
	set name = "Rotate left"
	set src in range(2, usr)
	if (anchored)
		user << "<span class='notice'>You need to unsecure the catapult first!</span>"
	else
		switch(dir)
			if (EAST)
				dir = SOUTH

			if (WEST)
				dir = NORTH

			if (NORTH)
				dir = EAST

			if (SOUTH)
				dir = WEST

	return

/obj/structure/catapult/verb/rotate_right()
	set category = null
	set name = "Rotate right"
	set src in range(2, usr)
	if (anchored)
		user << "<span class='notice'>You need to unsecure the catapult first!</span>"
	else
		switch(dir)
			if (EAST)
				dir = SOUTH
			if (WEST)
				dir = NORTH
			if (NORTH)
				dir = EAST
			if (SOUTH)
				dir = WEST

	return

/obj/structure/catapult/Bump(var/atom/A, yes)

	if (throwing)
		throw_impact(A)
		throwing = FALSE

	spawn(0)
		if (A && yes)
			A.last_bumped = world.time
			A.Bumped(src)
		return

	..()
	return


/obj/item/catapult_ball
	icon = 'icons/obj/cannon_ball.dmi'
	name = "catapult projectile"
	icon_state = "catapult"
	w_class = 4.0
	value = 15