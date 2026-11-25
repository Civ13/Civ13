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
	var/tmp/projectile_slot_revision = 0
	bound_height = 64
	bound_width = 32
	anchored = TRUE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	// Range the crew can set, in tiles, and the blast where the stone lands.
	var/min_range = 5
	var/max_range = 80
	var/list/blast = list(1, 2, 2)
	// Icon states are [state_prefix]0, [state_prefix]1 and [state_prefix]_fire.
	var/state_prefix = "catapult"
	// Deciseconds to wind it up and loose it.
	var/loose_time = 20

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
			to_chat(M, "<span class = 'warning'>There's already a projectile loaded.</span>")
			return
		if (load_projectile(W, M) && M == user)
			do_html(M)
	else if (is_tool(W, TOOL_HAMMER))
		toggle_anchor(user)
	else
		..()


/obj/structure/catapult/proc/load_projectile(obj/item/catapult_ball/ball, mob/living/loader)
	if (QDELETED(src) || loaded || !istype(ball) || !istype(loader))
		return FALSE
	if (!loader.transfer_held_item_to(ball, src) || QDELETED(src))
		return FALSE
	loaded = ball
	projectile_slot_revision++
	icon_state = "[state_prefix]1"
	update_icon()
	return TRUE

/obj/structure/catapult/proc/unload_projectile(mob/actor)
	var/obj/item/catapult_ball/ball = loaded
	if (QDELETED(actor) || QDELETED(ball) || ball.loc != src)
		return FALSE
	// With no usable hand, put_in_hands can still drop the projectile at the operator's feet.
	actor.put_in_hands(ball)
	if (!QDELETED(ball) && ball.loc == src)
		return FALSE
	loaded = null
	projectile_slot_revision++
	icon_state = "[state_prefix]0"
	update_icon()
	return TRUE

/obj/structure/catapult/interact(var/mob/m)
	if (user)
		if (get_dist(src, user) > 1)
			user = null
	restart:
	if (!anchored)
		to_chat(user, "<span class = 'danger'>You need to fix it to the floor before firing.</span>")
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

	var/mob/living/human/H = user
	if (istype(H) && H.faction_text == INDIANS)
		to_chat(user, "<span class = 'danger'>You have no idea how this thing works.</span>")
		return FALSE

	if (!locate(src) in get_step(user, user.dir))
		to_chat(user, "<span class = 'danger'>Get behind the catapult to use it.</span>")
		return FALSE

	if (!user.can_use_hands())
		to_chat(user, "<span class = 'danger'>You have no hands to use this with.</span>")
		return FALSE

	if (!anchored)
		to_chat(user, "<span class = 'danger'>You need to fix it to the floor before firing.</span>")
		return FALSE

	if (href_list["load"])
		if (loaded)
			to_chat(user, SPAN_WARNING("There's already a projectile loaded."))
		else
			var/obj/item/catapult_ball/ball = user.get_active_hand()
			if (istype(ball) && do_after(user, 10, src) && anchored && user.get_active_hand() == ball)
				load_projectile(ball, user)
	else if (href_list["unload"])
		unload_projectile(user)

	if (href_list["set_angle"])
		angle = player_input(user, "Set the target distance to what? (From [min_range] to [max_range] meters)", null, null, "num", null, FALSE)
		angle = Clamp(angle, min_range, max_range)

	if (href_list["fire"])

		if (map)
			if (!map.faction1_can_cross_blocks() && !map.faction2_can_cross_blocks())
				to_chat(user, "<span class = 'danger'>You can't fire yet.</span>")
				return

		var/obj/item/catapult_ball/firing_ball = loaded
		if (QDELETED(firing_ball) || firing_ball.loc != src)
			to_chat(user, "<span class = 'danger'>There's nothing in the catapult.</span>")
			return

		var/firing_revision = projectile_slot_revision
		if (do_after(user, loose_time, src))
			// Unloading (even if the same projectile is put back) cancels this wind-up.
			if (QDELETED(src) || !anchored || loaded != firing_ball || projectile_slot_revision != firing_revision || QDELETED(firing_ball) || firing_ball.loc != src)
				return

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
				playsound(t1, "artillery_out_distance", 100, TRUE)

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
			qdel(firing_ball)
			loaded = null
			projectile_slot_revision++
			icon_state = "[state_prefix]_fire"
			update_icon()
			spawn(10)
				icon_state = "[state_prefix][loaded ? 1 : 0]"
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
					if (target && target_area && target_area.location == AREA_INSIDE)
						highcheck = FALSE

					if (v >= max_distance)
						hit = TRUE
					else if (target && target.density && !highcheck)
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
						playsound(target, "artillery_in", 100, FALSE)
						spawn (10)
							var/target_area_original_integrity = target_area.artillery_integrity
							if (target_area.location == AREA_INSIDE && !target_area.arty_act(25))
								for (var/mob/living/L in view(20, target))
									shake_camera(L, 5, 5)
									to_chat(L, "<span class = 'danger'>You hear something violently smash into the ceiling!</span>")
								message_admins("Catapult projectile hit the ceiling at [target.x], [target.y], [target.z].")
								log_admin("Catapult projectile hit the ceiling at [target.x], [target.y], [target.z].")
								return
							else if (target_area_original_integrity)
								target.visible_message("<span class = 'danger'>The ceiling collapses!</span>")
							message_admins("Catapult projectile hit at [target.x], [target.y], [target.z].")
							log_admin("Catapult projectile hit at [target.x], [target.y], [target.z].")
							explosion(target, blast[1], blast[2], blast[3], 0)
						break

					sleep(0.5)

	do_html(user)

/obj/structure/catapult/proc/do_html(var/mob/m)
	if (m)
		max_distance = angle
		ui_interact(m)

/obj/structure/catapult/ui_actions(ui_key)
	return list("load", "unload", "set_angle", "fire")

/obj/structure/catapult/ui_interact(mob/viewer, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE)
	var/list/rows = list(
		panel_row("Projectile", loaded ? loaded.name : "No projectile loaded", loaded ? null : "muted", list(panel_button(loaded ? "Unload" : "Load", loaded ? "unload" : "load"))),
		panel_row("Distance", "[angle] meters", buttons = list(panel_button("Set", "set_angle"))))
	open_panel(viewer, name, 420, 280, list(panel_section("Laying", rows = rows, buttons = list(panel_button("FIRE!", "fire")))), ui = ui, force_open = force_open)
	//		<A href = '?src=\ref[src];topic_type=[topic_custom_input];continue_num=1'>

/obj/structure/catapult/verb/rotate_left()
	set category = null
	set name = "Rotate Left"
	set src in range(2)
	if (anchored)
		to_chat(user, "<span class='notice'>You need to unsecure the catapult first!</span>")
	else
		set_dir(turn(dir, 90))
	return

/obj/structure/catapult/verb/rotate_right()
	set category = null
	set name = "Rotate Right"
	set src in range(2)
	if (anchored)
		to_chat(user, "<span class='notice'>You need to unsecure the catapult first!</span>")
	else
		set_dir(turn(dir, -90))

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
	w_class = ITEM_SIZE_LARGE
	value = 15