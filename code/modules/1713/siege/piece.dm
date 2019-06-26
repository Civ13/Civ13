/obj/structure/cannon
	name = "cannon"
	icon = 'icons/obj/cannon_v.dmi'
	layer = MOB_LAYER + 1 //just above mobs
	density = TRUE
	icon_state = "cannon"
	var/angle = 20
	var/travelled = 0
	var/max_distance = 0
	var/high_distance = 0
	var/high = TRUE
	var/mob/user = null
	var/obj/item/cannon_ball/loaded = null
	bound_height = 64
	bound_width = 32
	anchored = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/ammotype = /obj/item/cannon_ball
	var/spritemod = TRUE //if true, uses 32x64
	var/explosion = TRUE
	var/reagent_payload = "none"
	var/maxrange = 50
	var/maxsway = 3
	var/sway = 0
	var/firedelay = 20
/obj/structure/cannon/modern
	name = "field cannon"
	icon = 'icons/obj/cannon.dmi'
	icon_state = "modern_cannon"
	ammotype = /obj/item/cannon_ball/shell
	spritemod = FALSE
	maxsway = 10
	firedelay = 30
	maxrange = 80
/obj/structure/cannon/mortar
	name = "mortar"
	icon = 'icons/obj/cannon_ball.dmi'
	layer = MOB_LAYER + 1 //just above mobs
	density = TRUE
	icon_state = "mortar"
	bound_height = 32
	bound_width = 32
	anchored = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	ammotype = /obj/item/cannon_ball/mortar_shell
	spritemod = FALSE //if true, uses 32x64
	explosion = TRUE
	reagent_payload = "none"
	maxrange = 23
	maxsway = 7
	firedelay = 12
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
	interact(attacker)

// todo: loading artillery. This will regenerate the shrapnel and affect our explosion
/obj/structure/cannon/attackby(obj/item/W as obj, mob/M as mob)
	if (istype(W, ammotype))
		if (loaded)
			M << "<span class = 'warning'>There's already a [loaded] loaded.</span>"
			return
		// load first and only slot
		M.remove_from_mob(W)
		W.loc = src
		loaded = W
		if (M == user)
			do_html(M)
	else if (istype(W,/obj/item/weapon/wrench))
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		user << (anchored ? "<span class='notice'>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored


/obj/structure/cannon/interact(var/mob/m)
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

/obj/structure/cannon/Topic(href, href_list, hsrc)

	var/mob/user = usr

	if (!user || user.lying)
		return

	user.face_atom(src)

	var/mob/living/carbon/human/H = user
	if (istype(H) && H.faction_text == "INDIANS")
		user << "<span class = 'danger'>You have no idea how this thing works.</span>"
		return FALSE

	if (!locate(user) in range(1,src))
		user << "<span class = 'danger'>Get behind the cannon to use it.</span>"
		return FALSE

	if (!user.can_use_hands())
		user << "<span class = 'danger'>You have no hands to use this with.</span>"
		return FALSE

	if (!anchored)
		user << "<span class = 'danger'>You need to fix it to the floor before firing.</span>"
		return FALSE

	if (href_list["load"])
		var/obj/item/cannon_ball/M = user.get_active_hand()
		if (M && istype(M) && do_after(user, 10, src))
			user.remove_from_mob(M)
			M.loc = src
			loaded = M

	if (href_list["set_angle"])
		angle = input(user, "Set the target distance to what? (From 5 to [maxrange] meters)") as num
		angle = Clamp(angle, 5, maxrange)

	if (href_list["set_sway"])
		sway = input(user, "Set the Left-Right sway to what? (From -[maxsway] to [maxsway] meters - negatives are left, positives are right)") as num
		sway = Clamp(sway, -maxsway, maxsway)

	if (href_list["fire"])

		if (!map.faction1_can_cross_blocks() && !map.faction2_can_cross_blocks())
			user << "<span class = 'danger'>You can't fire yet.</span>"
			return

		if (!loaded)
			user << "<span class = 'danger'>There's nothing in \the [src].</span>"
			return


		if (do_after(user, firedelay, src))

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
			var/turf/target = get_turf(src)
			var/odir = dir

			max_distance = rand(max_distance - round(max_distance/10), max_distance + round(max_distance/10))

			high_distance = max_distance * 0.80

			travelled = 0
			high = TRUE
			if (!istype(loaded, /obj/item/cannon_ball/shell/gas))
				explosion = TRUE
			else
				explosion = FALSE
				reagent_payload = loaded.reagent_payload
			qdel(loaded)
			loaded = null

			spawn (0)
				var/v = max_distance

				if (v > high_distance)
					high = FALSE

				var/hit = FALSE

				var/tx = 0
				var/ty = 0

				switch (odir)
					if (EAST)
						tx = x+1+max_distance
						ty = y + sway + pick(0,pick(1,-1))
					if (WEST)
						tx = x-1-max_distance
						ty = y + sway + pick(0,pick(1,-1))
					if (NORTH)
						tx = x + sway + pick(0,pick(1,-1))
						ty = y+1+max_distance
					if (SOUTH)
						tx = x + sway + pick(0,pick(1,-1))
						ty = y-1-max_distance
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
							if (istype(src,/obj/structure/cannon/mortar))
								explosion(target, 1, 2, 2, 3)
							else
								explosion(target, 1, 2, 3, 4)
							var/target_area_original_integrity = target_area.artillery_integrity
							if (target_area.location == AREA_INSIDE && !target_area.arty_act(25))
								for (var/mob/living/L in view(20, target))
									shake_camera(L, 5, 5)
									L << "<span class = 'danger'>You hear something violently smash into the ceiling!</span>"
								message_admins("Cannonball hit the ceiling at [target.x], [target.y], [target.z].")
								log_admin("Cannonball hit the ceiling at [target.x], [target.y], [target.z].")
								return
							else if (target_area_original_integrity)
								target.visible_message("<span class = 'danger'>The ceiling collapses!</span>")
							message_admins("Cannonball hit at [target.x], [target.y], [target.z].")
							log_admin("Cannonball hit at [target.x], [target.y], [target.z].")
						else
							message_admins("Gas artillery shell ([reagent_payload]) hit at [target.x], [target.y], [target.z].")
							log_admin("Gas artillery shell ([reagent_payload]) hit at [target.x], [target.y], [target.z].")
							var/how_many = 24 // half of 49, the radius we spread over (7x7)
							for (var/k in 1 to how_many)
								switch (reagent_payload)
									if ("chlorine_gas")
										new/obj/effect/effect/smoke/chem/payload/chlorine_gas(target)
									if ("mustard_gas")
										new/obj/effect/effect/smoke/chem/payload/mustard_gas(target)
									if ("white_phosphorus_gas")
										new/obj/effect/effect/smoke/chem/payload/white_phosphorus_gas(target)
									if ("xylyl_bromide")
										new/obj/effect/effect/smoke/chem/payload/xylyl_bromide(target)
									if ("phosgene_gas")
										new/obj/effect/effect/smoke/chem/payload/phosgene(target)
				sleep(0.5)

	do_html(user)

/obj/structure/cannon/proc/do_html(var/mob/m)

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
		Shell: <a href='?src=\ref[src];load=1'>[loaded ? loaded.name : "No shell loaded"]</a><br><br>
		Distance: <a href='?src=\ref[src];set_angle=1'>[angle] meters</a><br><br>
		Left-Right sway: <a href='?src=\ref[src];set_sway=1'>[sway] meters</a><br><br>
		<br>
		<center>
		<a href='?src=\ref[src];fire=1'><b><big>FIRE!</big></b></a>
		</center>

		</body>
		</html>
		<br>
		"},  "window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=500x500")
	//		<A href = '?src=\ref[src];topic_type=[topic_custom_input];continue_num=1'>

/obj/structure/cannon/verb/rotate_left()
	set category = null
	set name = "Rotate left"
	set src in range(2, usr)
	if (anchored)
		user << "<span class='notice'>You need to unsecure \the [src] first!</span>"
	else
		switch(dir)
			if (EAST)
				dir = SOUTH
				if (spritemod)
					bound_height = 64
					bound_width = 32
					icon = 'icons/obj/cannon_v.dmi'
					icon_state = "cannon"
			if (WEST)
				dir = NORTH
				if (spritemod)
					bound_height = 64
					bound_width = 32
					icon = 'icons/obj/cannon_v.dmi'
					icon_state = "cannon"
			if (NORTH)
				dir = EAST
				if (spritemod)
					bound_height = 32
					bound_width = 64
					icon = 'icons/obj/cannon_h.dmi'
					icon_state = "cannon"
			if (SOUTH)
				dir = WEST
				if (spritemod)
					bound_height = 32
					bound_width = 64
					icon = 'icons/obj/cannon_h.dmi'
					icon_state = "cannon"
	return

/obj/structure/cannon/verb/rotate_right()
	set category = null
	set name = "Rotate right"
	set src in range(2, usr)
	if (anchored)
		user << "<span class='notice'>You need to unsecure \the [src] first!</span>"
	else
		switch(dir)
			if (EAST)
				dir = SOUTH
				if (spritemod)
					bound_height = 64
					bound_width = 32
					icon = 'icons/obj/cannon_v.dmi'
					icon_state = "cannon"
			if (WEST)
				dir = NORTH
				if (spritemod)
					bound_height = 64
					bound_width = 32
					icon = 'icons/obj/cannon_v.dmi'
					icon_state = "cannon"
			if (NORTH)
				dir = EAST
				if (spritemod)
					bound_height = 32
					bound_width = 64
					icon = 'icons/obj/cannon_h.dmi'
					icon_state = "cannon"
			if (SOUTH)
				dir = WEST
				if (spritemod)
					bound_height = 32
					bound_width = 64
					icon = 'icons/obj/cannon_h.dmi'
					icon_state = "cannon"
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
		if (dir==SOUTH)
			bound_height = 64
			bound_width = 32
			icon = 'icons/obj/cannon_v.dmi'
			icon_state = "cannon"
		if (dir==NORTH)
			bound_height = 64
			bound_width = 32
			icon = 'icons/obj/cannon_v.dmi'
			icon_state = "cannon"
		if (dir==EAST)
			bound_height = 32
			bound_width = 64
			icon = 'icons/obj/cannon_h.dmi'
			icon_state = "cannon"
		if (dir==WEST)
			bound_height = 32
			bound_width = 64
			icon = 'icons/obj/cannon_h.dmi'
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
		if (dir==SOUTH)
			bound_height = 64
			bound_width = 32
			icon = 'icons/obj/cannon_v.dmi'
			icon_state = "cannon"
		if (dir==NORTH)
			bound_height = 64
			bound_width = 32
			icon = 'icons/obj/cannon_v.dmi'
			icon_state = "cannon"
		if (dir==EAST)
			bound_height = 32
			bound_width = 64
			icon = 'icons/obj/cannon_h.dmi'
			icon_state = "cannon"
		if (dir==WEST)
			bound_height = 32
			bound_width = 64
			icon = 'icons/obj/cannon_h.dmi'
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
				icon = 'icons/obj/cannon_v.dmi'
				icon_state = "cannon"
			if (NORTH)
				bound_height = 64
				bound_width = 32
				icon = 'icons/obj/cannon_v.dmi'
				icon_state = "cannon"
			if (EAST)
				bound_height = 32
				bound_width = 64
				icon = 'icons/obj/cannon_h.dmi'
				icon_state = "cannon"
			if (WEST)
				bound_height = 32
				bound_width = 64
				icon = 'icons/obj/cannon_h.dmi'
				icon_state = "cannon"
/*
/obj/structure/cannon/verb/fix()
	set category = null
	set name = "Lock in place"
	set src in range(1, usr)
	if (anchored)
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		user << "<span class='notice'>Now unsecuring the cannon...</span>"
		if (do_after(user, 20, src))
			if (!src) return
			user << "<span class='notice'>You unsecured the cannon.</span>"
			anchored = FALSE
	else if (!anchored)
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		user << "<span class='notice'>Now securing the cannon...</span>"
		if (do_after(user, 20, src))
			if (!src) return
			user << "<span class='notice'>You secured the cannon.</span>"
			anchored = TRUE
	return
*/