/obj/structure/turret
	not_movable = TRUE
	anchored = TRUE
	density = FALSE
	layer = MOB_LAYER + 1 //just above mobs
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "tank_cannon"

	var/turret_x = 0
	var/turret_y = 0

	var/turret_color = "#4a5243"
	var/turret_icon
	var/image/turret_image
	var/image/turret_roof_image

	var/mob/gunner = null
	var/mob/loader = null
	var/mob/commander = null

	var/obj/structure/bed/chair/gunner/gunner_seat = null
	var/obj/structure/bed/chair/loader/loader_seat = null
	var/obj/structure/bed/chair/loader/commander_seat = null

	var/gunner_x = 16
	var/gunner_y = -16

	var/loader_x = -16
	var/loader_y = 0

	var/commander_x = 10
	var/commander_y = 0

	var/azimuth = 0
	var/azimuth_to_target = 0
	var/distance = 5

	var/rotation_speed = 0.5 // seconds for 1 degree
	var/stopped_rotation_time = 1

	var/list/weapons = list()
	var/selected_weapon = 1
	var/is_firing = FALSE

	var/broken = FALSE

/obj/structure/turret/New()
	..()

	switch(dir)
		if(NORTH)
			azimuth = 0
		if(EAST)
			azimuth = 90
		if(SOUTH)
			azimuth = 180
		if(WEST)
			azimuth = 270

	update_icon()

/obj/structure/turret/proc/clear_aiming_line(var/mob/user)
	if(!user)
		return
	if(!user.client)
		return
	for (var/image/img in user.client.images)
		if (img.icon_state == "point")
			user.client.images.Remove(img)
		if (img.icon_state == "cannon_target")
			user.client.images.Remove(img)

/obj/structure/turret/proc/draw_aiming_line(var/mob/user)
	if(!user)
		return
	if(!user.client)
		return
	clear_aiming_line(user)
	var/image/aiming_line
	var/i = 0
	var/point_x
	var/point_y
	var/actual_azimuth = azimuth - 90
	for(i = 0, i < distance * 32, i+=32)
		point_x = ceil(i * cos(-actual_azimuth))
		point_y = ceil(i * sin(-actual_azimuth))
		if (point_x != 0 || point_y != 0)
			aiming_line = new('icons/effects/Targeted.dmi', loc = src, icon_state="point", pixel_x = point_x, pixel_y = point_y, layer = 14)
			aiming_line.alpha = 255 - (i / 4)
			user.client.images += aiming_line
	aiming_line = new('icons/effects/Targeted.dmi', loc = src, icon_state="cannon_target", pixel_x = point_x, pixel_y = point_y, layer = 14)
	user.client.images += aiming_line

/obj/structure/turret/update_icon()
	..()
	draw_aiming_line(gunner)
	update_dir()

	pixel_x = 0
	pixel_y = 0

	var/vehicle_dir = 0

	for (var/obj/structure/vehicleparts/frame/F in loc)
		vehicle_dir = F.dir
		if (F.axis && F.axis.color)
			turret_color = F.axis.color

	if(vehicle_dir != 0)
		switch(vehicle_dir)
			if(NORTH)
				pixel_x = -turret_x
				pixel_y = -turret_y
			if(WEST)
				pixel_x = turret_y
				pixel_y = -turret_x
			if(SOUTH)
				pixel_x = turret_x
				pixel_y = turret_y
			if(EAST)
				pixel_x = -turret_y
				pixel_y = turret_x

	update_seats()

	var/ic = 'icons/obj/vehicles/vehicles256x256.dmi'
	turret_image = image(icon=ic, loc=src, pixel_x = -112, pixel_y = -112, icon_state="[turret_icon][broken]", layer=12)
	turret_image.color = turret_color
	turret_roof_image = image(icon=ic, loc=src, pixel_x = -112, pixel_y = -112, icon_state="[turret_icon]_roof[broken]", layer=13)
	turret_roof_image.color = turret_color

/mob/var/obj/structure/turret/using_turret = null

/mob/proc/start_using_turret(o)
	stop_using_turret()
	if (o && istype(o, /obj/structure/turret))
		using_turret = o
		using_turret.do_html(src)

/mob/proc/stop_using_turret()
	if (using_turret)
		using_turret.clear_aiming_line(src)
		to_chat(src, SPAN_NOTICE("You have stopped using the [using_turret.name]."))
		src << browse(null, "window=artillery_window")
		using_turret = null

/obj/structure/turret/proc/place_user(var/mob/living/M)
	var/obj/structure/vehicleparts/axis/turret_vehicle = null
	var/obj/structure/vehicleparts/axis/mob_vehicle = null

	for (var/obj/structure/vehicleparts/frame/F in loc)
		turret_vehicle = F.axis

	for (var/obj/structure/vehicleparts/frame/F in M.loc)
		mob_vehicle = F.axis

	if(turret_vehicle != mob_vehicle)
		to_chat(M, SPAN_WARNING("You have to be in the same vehicle as the turret to get in it."))
		return

	if (M.buckled)
		return
	M.forceMove(loc)
	if(gunner_seat && !gunner_seat.buckled_mob)
		gunner_seat.buckle_mob(M)
		to_chat(M, SPAN_NOTICE("You climb into the gunner seat."))
	else if(loader_seat && !loader_seat.buckled_mob)
		loader_seat.buckle_mob(M)
		to_chat(M, SPAN_NOTICE("You climb into the loader seat."))
	else if(commander_seat && !commander_seat.buckled_mob)
		commander_seat.buckle_mob(M)
		to_chat(M, SPAN_NOTICE("You climb into the commander seat."))
	else
		to_chat(M, SPAN_NOTICE("There are no available seats in the turret."))
		return

/obj/structure/turret/attack_hand(var/mob/attacker)
	place_user(attacker)

/obj/structure/turret/proc/switch_weapon()
	selected_weapon += 1

	if(selected_weapon > weapons.len)
		selected_weapon = 1

/obj/structure/turret/proc/icrease_target_azimuth(var/value)
	azimuth_to_target += value
	if(stopped_rotation_time != 0 && world.time - stopped_rotation_time > 0.1)
		stopped_rotation_time = 0
		rotate_to_target()

/obj/structure/turret/proc/icrease_target_distance(var/value)
	distance += value
	if(distance < 5)
		distance = 5
	update_icon()

/obj/structure/turret/proc/update_dir()
	if(azimuth >= 45 && azimuth < 135)
		dir = EAST
	else if(azimuth >= 135 && azimuth < 225)
		dir = SOUTH
	else if(azimuth >= 225 && azimuth < 315)
		dir = WEST
	else
		dir = NORTH

/obj/structure/turret/proc/clamp_azimuth()
	if(azimuth >= 360)
		azimuth -= 360
	else if(azimuth < 0)
		azimuth += 360

/obj/structure/turret/proc/rotate_to_target()
	if(azimuth_to_target)
		var/delta_azimuth = ((azimuth_to_target) ? ((azimuth_to_target) < 0 ? -1 : 1) : 0)
		azimuth += delta_azimuth
		clamp_azimuth(azimuth)
		azimuth_to_target -= delta_azimuth

	update_icon()

	if(azimuth_to_target != 0)
		spawn(0.15)
			rotate_to_target()
	else
		stopped_rotation_time = world.time

/obj/structure/turret/proc/update_seats()
	if(gunner_seat)
		gunner_seat.update_icon()
	if(loader_seat)
		loader_seat.update_icon()
	if(commander_seat)
		commander_seat.update_icon()

/obj/structure/turret/proc/open_fire()
	if(!is_firing)
		is_firing = TRUE
		fire()

/obj/structure/turret/proc/fire()
	if(weapons.len < selected_weapon)
		return
	if(!gunner_seat || !gunner || gunner.stat != CONSCIOUS)
		is_firing = FALSE
		return

	var/next_shot_delay = 1
	var/actual_azimuth = azimuth - 90
	var/target_x = trunc(distance * cos(-actual_azimuth))
	var/target_y = trunc(distance * sin(-actual_azimuth))

	if(istype(weapons[selected_weapon], /obj/item/weapon/gun/projectile/automatic/stationary/autocannon))
		var/obj/item/weapon/gun/projectile/automatic/stationary/autocannon/A = weapons[selected_weapon]
		A.loc = loc
		A.dir = dir
		A.Fire(locate(x + target_x, y + target_y, z),gunner)
		A.forceMove(src)
		next_shot_delay = A.firemodes[A.sel_mode].burst_delay
	else if(istype(weapons[selected_weapon], /obj/item/weapon/gun/projectile))
		var/obj/item/weapon/gun/projectile/G = weapons[selected_weapon]
		G.recoil = 1
		G.dir = dir
		G.Fire(locate(x + target_x, y + target_y, z),gunner)
		next_shot_delay = G.firemodes[G.sel_mode].burst_delay
	else if(istype(weapons[selected_weapon], /obj/structure/cannon/modern/tank))
		var/obj/structure/cannon/modern/tank/C = weapons[selected_weapon]
		C.azimuth = azimuth
		C.distance = distance
		C.loc = loc
		C.do_tank_fire(gunner)
		C.forceMove(src)

	if(is_firing)
		spawn(next_shot_delay)
			fire()

/obj/structure/turret/attackby(obj/item/W as obj, mob/M as mob)
	if(weapons.len < selected_weapon)
		return

	if(istype(weapons[selected_weapon], /obj/item/weapon/gun/projectile/automatic))
		var/obj/item/weapon/gun/projectile/automatic/G = weapons[selected_weapon]
		to_chat(M, SPAN_NOTICE("You start loading the [G.name]."))
		G.attackby(W, M)
	else if(istype(weapons[selected_weapon], /obj/structure/cannon/modern/tank))
		var/obj/structure/cannon/modern/tank/C = weapons[selected_weapon]
		to_chat(M, SPAN_NOTICE("You start loading the [C.name]."))
		C.attackby(W, M)

	do_html(M)

/obj/structure/turret/Topic(href, href_list, hsrc)

	var/mob/user = usr

	if (href_list["switch"])
		switch_weapon()
	if (href_list["load"])
		if(weapons.len >= selected_weapon)
			if(istype(weapons[selected_weapon], /obj/item/weapon/gun/projectile/automatic))
				var/obj/item/weapon/gun/projectile/automatic/G = weapons[selected_weapon]
				G.unload_ammo(user)
			else if(istype(weapons[selected_weapon], /obj/structure/cannon/modern/tank))
				var/obj/structure/cannon/modern/tank/C = weapons[selected_weapon]
				if(C.loaded.len > 0)
					var/obj/item/cannon_ball/S = C.loaded[1]
					C.loaded -= S
					S.loc = get_turf(user)
					to_chat(user, SPAN_NOTICE("You unload \the [src]."))
				if(istype(weapons[selected_weapon], /obj/structure/cannon/modern/tank/autoloader))
					var/obj/structure/cannon/modern/tank/autoloader/A = weapons[selected_weapon]
					if (!A.is_loading)
						A.is_loading = TRUE
						var/list/loadable = list()
						for (var/obj/structure/shellrack/autoloader/AL in range(1,src))
							if (AL.storage.contents)
								for (var/obj/item/cannon_ball/shell/tank/TS in AL.storage.contents)
									if (istype(TS, A.ammotype))
										if (A.caliber != TS.caliber && A.caliber != null && A.caliber != 0)
											to_chat(user, SPAN_WARNING("\The [TS] is of the wrong caliber! You need [A.caliber] mm shells for this cannon."))
											continue
										loadable += TS

						playsound(loc, 'sound/machines/autoloader.ogg', 100, TRUE)
						var/obj/item/cannon_ball/shell/tank/chosen

						to_chat(user, SPAN_NOTICE("The autoloader begins loading a shell."))
						spawn (6 SECONDS)
							if (!loadable.len)
								to_chat(user, SPAN_WARNING("There are no shells to load."))
								return
							chosen = WWinput(usr, "Select a tank shell to load", "Load Tank Shell", loadable[1], WWinput_list_or_null(loadable))
							if (!chosen || chosen == "")
								return
							chosen.loc = src
							A.loaded += chosen
							to_chat(user, SPAN_NOTICE("The autoloader loads \the [src]."))
							A.is_loading = FALSE
							return
					else
						to_chat(user, SPAN_WARNING("The autoloader is currently in use."))
	do_html(user)

/obj/structure/turret/proc/do_html(var/mob/m)
	if (!m)
		return

	if(m != gunner)
		return

	var/weapon_name = "Any weapon selected"
	var/loaded = "Nothing loaded"

	if(weapons.len >= selected_weapon)
		if(istype(weapons[selected_weapon], /obj/item/weapon/gun/projectile/automatic))
			var/obj/item/weapon/gun/projectile/automatic/G = weapons[selected_weapon]
			weapon_name = G.name
			if(G.ammo_magazine)
				loaded = G.ammo_magazine.name
		else if(istype(weapons[selected_weapon], /obj/structure/cannon/modern/tank))
			var/obj/structure/cannon/modern/tank/C = weapons[selected_weapon]
			weapon_name = C.name
			if(C.loaded.len >= 1)
				loaded = C.loaded[1].name
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
	<big><b>[name]</b></big><br>
	</center>
	<big>Switch weapon:</big><br>
	<big><a href='?src=\ref[src];switch=1'>[weapon_name]</a>|<a href='?src=\ref[src];load=1'>[loaded]</a></big><br>
	</body>
	</html>
	<br>
	"},  "window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=400x400")

/obj/structure/turret/bt7
	turret_color = "#5c784f"
	turret_icon = "bt7_turret"
	name = "BT-7"

	turret_x = -16
	turret_y = 0

	gunner_x = 9
	gunner_y = -2

	loader_x = -9
	loader_y = -2

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		loader_seat = new /obj/structure/bed/chair/loader(src.loc)
		loader_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/russian76(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/dp28/dt28(src))
		..()

/obj/structure/turret/t34
	turret_color = "#3d5931"
	turret_icon = "t34_turret"
	name = "T-34"

	gunner_x = 9
	gunner_y = -2

	loader_x = -9
	loader_y = -2

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		loader_seat = new /obj/structure/bed/chair/loader(src.loc)
		loader_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/russian76(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/dp28/dt28(src))
		..()

/obj/structure/turret/kv1
	turret_color = "#3d5931"
	turret_icon = "kv1_turret"
	name = "KV-1"

	gunner_x = 9
	gunner_y = -2

	commander_x = 0
	commander_y = 11

	loader_x = -9
	loader_y = -2

	commander_x = 0
	commander_y = 11

	rotation_speed = 1

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		loader_seat = new /obj/structure/bed/chair/loader(src.loc)
		loader_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/russian76(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/dp28/dt28(src))
		..()

/obj/structure/turret/t3485
	turret_color = "#4a5243"
	turret_icon = "t3485_turret"
	name = "T-34-85"

	gunner_x = 11
	gunner_y = -12

	loader_x = -11
	loader_y = -2

	commander_x = 11
	commander_y = 0

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		loader_seat = new /obj/structure/bed/chair/loader(src.loc)
		loader_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/russian85(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/dp28/dt28(src))
		..()

/obj/structure/turret/is1
	turret_color = "#4a5243"
	turret_icon = "is1_turret"
	name = "IS-1"

	gunner_x = 14
	gunner_y = -8

	loader_x = -11
	loader_y = 8

	commander_x = 14
	commander_y = 12

	rotation_speed = 0.9

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		loader_seat = new /obj/structure/bed/chair/loader(src.loc)
		loader_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/russian85(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/dp28/dt28(src))
		..()

/obj/structure/turret/course
	turret_color = "#4a5243"
	turret_icon = "su100_turret"
	name = "Course cannon"

	gunner_x = 12
	gunner_y = 8

	loader_x = -6
	loader_y = 18

/obj/structure/turret/course/proc/turn_to_dir(var/tdir)
	if(tdir == "left")
		azimuth -= 90
	else if(tdir == "right")
		azimuth += 90
	clamp_azimuth()
	update_icon()

/obj/structure/turret/course/rotate_to_target()
	if(azimuth_to_target)
		var/delta_azimuth = ((azimuth_to_target) ? ((azimuth_to_target) < 0 ? -1 : 1) : 0)
		azimuth += delta_azimuth
		clamp_azimuth(azimuth)
		azimuth_to_target -= delta_azimuth

	var/continue_rotation = TRUE

	switch(dir)
		if(EAST)
			if(azimuth >= 135)
				azimuth = 134
				continue_rotation= FALSE
			else if(azimuth < 45)
				azimuth = 45
				continue_rotation = FALSE
		if(SOUTH)
			if(azimuth >= 225)
				azimuth = 224
				continue_rotation = FALSE
			else if(azimuth < 135)
				azimuth = 135
				continue_rotation = FALSE
		if(WEST)
			if(azimuth >= 315)
				azimuth = 314
				continue_rotation = FALSE
			else if(azimuth < 225)
				azimuth = 225
				continue_rotation = FALSE
		if(NORTH)
			if(azimuth >= 45 && azimuth <= 180)
				azimuth = 44
				continue_rotation = FALSE
			else if(azimuth <= 315 && azimuth > 180)
				azimuth = 316
				continue_rotation = FALSE

	update_icon()

	if(azimuth_to_target != 0 && continue_rotation)
		spawn(0.15)
			rotate_to_target()
	else
		stopped_rotation_time = world.time

/obj/structure/turret/course/su85m
	turret_color = "#4a5243"
	turret_icon = "su100_turret"
	name = "SU-85M"

	gunner_x = 12
	gunner_y = 8

	loader_x = -6
	loader_y = 18

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		loader_seat = new /obj/structure/bed/chair/loader(src.loc)
		loader_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/russian85(src))
		..()

/obj/structure/turret/course/su100
	turret_color = "#4a5243"
	turret_icon = "su100_turret"
	name = "SU-100"

	gunner_x = 12
	gunner_y = 8

	loader_x = -6
	loader_y = 18

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		loader_seat = new /obj/structure/bed/chair/loader(src.loc)
		loader_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/russian100(src))
		..()

/obj/structure/turret/is2
	turret_color = "#4a5243"
	turret_icon = "is2_turret"
	name = "IS-2"

	gunner_x = 14
	gunner_y = -8

	loader_x = -11
	loader_y = 8

	commander_x = 14
	commander_y = 13

	rotation_speed = 1.1

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		loader_seat = new /obj/structure/bed/chair/loader(src.loc)
		loader_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/russian122(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/dp28/dt28(src))
		..()

/obj/structure/turret/is3
	turret_color = "#4a5243"
	turret_icon = "is3_turret"
	name = "IS-3"

	turret_x = 0
	turret_y = 16

	gunner_x = 14
	gunner_y = -12

	loader_x = -14
	loader_y = 3

	commander_x = 14
	commander_y = 3

	rotation_speed = 1.3

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		loader_seat = new /obj/structure/bed/chair/loader(src.loc)
		loader_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/russian122(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/dp28/dt28(src))
		..()

/obj/structure/turret/t55
	turret_color = "#5c5c4c"
	turret_icon = "t55_turret"
	name = "T-55"

	turret_x = 0
	turret_y = 16

	gunner_x = 11
	gunner_y = -17

	loader_x = -13
	loader_y = 3

	commander_x = 16
	commander_y = 2

	rotation_speed = 1.1

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		loader_seat = new /obj/structure/bed/chair/loader(src.loc)
		loader_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/russian100(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/stationary/dshk(src))
		..()

/obj/structure/turret/t62
	turret_color = "#5c5c4c"
	turret_icon = "t62a_turret"
	name = "T-62"

	turret_x = 0
	turret_y = 8

	gunner_x = 12
	gunner_y = -16

	loader_x = -18
	loader_y = -2

	commander_x = 16
	commander_y = 5

	rotation_speed = 1

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		loader_seat = new /obj/structure/bed/chair/loader(src.loc)
		loader_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/russian115(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/pkm(src))
		..()

/obj/structure/turret/t62/t62m
	turret_color = "#5c5c4c"
	turret_icon = "t62m_turret"
	name = "T-62M"

/obj/structure/turret/t62/t62mv
	turret_color = "#5c5c4c"
	turret_icon = "t62mv_turret"
	name = "T-62MV"

/obj/structure/turret/t64bm
	turret_color = "#5c5c4c"
	turret_icon = "t64bm_turret"
	name = "T-64BM"

	turret_x = 0
	turret_y = 16

	gunner_x = 16
	gunner_y = 5

	commander_x = -16
	commander_y = 6

	rotation_speed = 0.7

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/autoloader/t90a(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/pkm(src))
		..()

/obj/structure/turret/t72
	turret_color = "#5c5c4c"
	turret_icon = "t72_turret"
	name = "T-72"

	turret_x = 0
	turret_y = 16

	gunner_x = 14
	gunner_y = 3

	commander_x = -14
	commander_y = 7

	rotation_speed = 0.8

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/autoloader/t90a(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/pkm(src))
		..()

/obj/structure/turret/t72/t72m1
	turret_icon = "t72m1_turret"
	name = "T-72M1"
	rotation_speed = 0.6

/obj/structure/turret/t72/t72b3
	turret_icon = "t72b3_turret"
	name = "T-72B3"
	rotation_speed = 0.3

/obj/structure/turret/t80u
	turret_color = "#5c5c4c"
	turret_icon = "t80u_turret"
	name = "T-80U"

	turret_x = 0
	turret_y = 16

	gunner_x = 16
	gunner_y = 5

	commander_x = -14
	commander_y = 5

	rotation_speed = 0.6

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/autoloader/t90a(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/pkm(src))
		..()

/obj/structure/turret/t80u/t80uk
	turret_icon = "t80uk_turret"
	name = "T-80UK"

/obj/structure/turret/t90a
	turret_icon = "t90a_turret"
	name = "T-90A"

	turret_x = 0
	turret_y = 16

	gunner_x = 16
	gunner_y = 8

	commander_x = -14
	commander_y = 6

	rotation_speed = 0.6

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/autoloader/t90a(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/pkm(src))
		..()

/obj/structure/turret/bmd2
	turret_color = "#787859"
	turret_icon = "bmd2_turret"
	name = "BMD-2"

	icon = 'icons/obj/guns/mgs.dmi'
	icon_state = "autocannon"

	turret_x = 16
	turret_y = -16

	gunner_x = 4
	gunner_y = 0

	commander_x = -4
	commander_y = 0

	rotation_speed = 0.3

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/stationary/autocannon/shipunov2a42(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/pkm(src))
		..()

/obj/structure/turret/btr80
	turret_color = "#4a5243"
	turret_icon = "btr80_turret"
	name = "BTR-80"

	icon = 'icons/obj/guns/mgs.dmi'
	icon_state = "autocannon"

	turret_x = 16
	turret_y = 0

	gunner_x = 0
	gunner_y = 4

	rotation_speed = 0.4

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/stationary/autocannon/shipunov2a72(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/pkm(src))
		..()

/obj/structure/turret/mtlb
	turret_color = "#4a5243"
	turret_icon = "mtlb_turret"
	name = "MTLB"

	icon = 'icons/obj/guns/mgs.dmi'
	icon_state = "pkm"

	turret_x = 3
	turret_y = 12

	gunner_x = 0
	gunner_y = 0

	rotation_speed = 0.9

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner/mtlb(src.loc)
		gunner_seat.setup(src)
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/pkm(src))
		..()

/obj/structure/turret/pziv
	turret_color = "#585A5C"
	turret_icon = "pziv_turret"
	name = "PZ-IV"

	turret_x = 0
	turret_y = 16

	gunner_x = 11
	gunner_y = -2

	loader_x = -11
	loader_y = -2

	commander_x = 0
	commander_y = 11

	rotation_speed = 1.1

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		loader_seat = new /obj/structure/bed/chair/loader(src.loc)
		loader_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/german75(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/stationary/mg34(src))
		..()

/obj/structure/turret/pzvi
	turret_color = "#585A5C"
	turret_icon = "pziv_turret"
	name = "PZ-VI"

	turret_x = 0
	turret_y = 16

	gunner_x = 11
	gunner_y = -2

	loader_x = -11
	loader_y = -2

	commander_x = 0
	commander_y = 11

	rotation_speed = 1.3

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		loader_seat = new /obj/structure/bed/chair/loader(src.loc)
		loader_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/german88(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/stationary/mg34(src))
		..()

/obj/structure/turret/leo2a6
	turret_color = "#4a5243"
	turret_icon = "2a6_turret"
	name = "2A6"

	turret_x = 0
	turret_y = 16

	gunner_x = 16
	gunner_y = -16

	loader_x = 16
	loader_y = 16

	commander_x = -16
	commander_y = 16

	rotation_speed = 0.3

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		loader_seat = new /obj/structure/bed/chair/loader(src.loc)
		loader_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/leopard(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/stationary/mg3(src))
		..()

/obj/structure/turret/sherman
	turret_color = "#635931"
	turret_icon = "m4_turret"
	name = "M-4 Sherman"

	turret_x = 0
	turret_y = 8

	gunner_x = 9
	gunner_y = -8

	loader_x = 9
	loader_y = 8

	commander_x = -13
	commander_y = 6

	rotation_speed = 0.8

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		loader_seat = new /obj/structure/bed/chair/loader(src.loc)
		loader_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/american75(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/browning_lmg(src))
		..()

/obj/structure/turret/m41
	turret_color = "#635931"
	turret_icon = "m41_turret"
	name = "M-41 Walker Bulldog"

	turret_x = -16
	turret_y = 0

	gunner_x = 9
	gunner_y = -8

	loader_x = 9
	loader_y = 8

	commander_x = -8
	commander_y = 1

	rotation_speed = 0.7

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		loader_seat = new /obj/structure/bed/chair/loader(src.loc)
		loader_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/american76(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/browning_lmg(src))
		..()

/obj/structure/turret/m48
	turret_color = "#635931"
	turret_icon = "m48_turret"
	name = "M-48 Patton"

	gunner_x = 9
	gunner_y = -8

	loader_x = 9
	loader_y = 8

	commander_x = -12
	commander_y = 10

	rotation_speed = 0.7

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		loader_seat = new /obj/structure/bed/chair/loader(src.loc)
		loader_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/american90(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/browning_lmg(src))
		..()

/obj/structure/turret/bradley
	turret_icon = "bradley_turret"
	name = "Bradley"

	icon = 'icons/obj/guns/mgs.dmi'
	icon_state = "autocannon"

	turret_x = 9
	turret_y = -1

	gunner_x = -8
	gunner_y = 0

	commander_x = 8
	commander_y = 0

	rotation_speed = 0.3

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/stationary/autocannon/bushmaster/bradley(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/manual/m249(src))
		..()

/obj/structure/turret/cv90
	turret_icon = "cv90_turret"
	name = "CV90"

	icon = 'icons/obj/guns/mgs.dmi'
	icon_state = "autocannon"

	turret_x = 0
	turret_y = 12

	gunner_x = -8
	gunner_y = 0

	commander_x = 8
	commander_y = 0

	rotation_speed = 0.3

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/stationary/autocannon/bushmaster(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/manual/m249(src))
		..()

/obj/structure/turret/technical_dshk
	turret_icon = ""
	name = "DSHK"

	icon = 'icons/obj/guns/mgs.dmi'
	icon_state = "dshk"

	turret_x = 16
	turret_y = 7

	gunner_x = 0
	gunner_y = 4

	rotation_speed = 0.2

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/stationary/dshk(src))
		..()

/*
/obj/structure/turret/technical_atgm
	turret_icon = ""
	name = "ATGM"

	icon = 'icons/obj/guns/mgs.dmi'
	icon_state = "atgm"

	turret_x = 9
	turret_y = -1

	gunner_x = -8
	gunner_y = 0

	rotation_speed = 0.2

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/stationary/atgm(src))
		..()
*/

/obj/structure/turret/m1abrams
	turret_icon = "m1a1_turret"
	name = "M1A1_turret"

	turret_x = 0
	turret_y = 16

	gunner_x = 16
	gunner_y = -16

	loader_x = 16
	loader_y = 10

	commander_x = -10
	commander_y = 16

	rotation_speed = 0.4

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		loader_seat = new /obj/structure/bed/chair/loader(src.loc)
		loader_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/m1a1_abrams(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/manual/m249(src))
		..()

/obj/structure/turret/challenger2
	turret_icon = "challenger2_turret"
	name = "Challenger-2"

	turret_x = 0
	turret_y = 16

	gunner_x = -16
	gunner_y = -16

	loader_x = 16
	loader_y = 16

	commander_x = -16
	commander_y = 16

	rotation_speed = 0.4

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		loader_seat = new /obj/structure/bed/chair/loader(src.loc)
		loader_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/leopard(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/stationary/mg3(src))
		..()

/obj/structure/turret/chiha
	turret_color = "#6a5a3d"
	turret_icon = "jap_turret"
	name = "Type 97 Chi-Ha"

	turret_x = 0
	turret_y = -8

	gunner_x = 4
	gunner_y = 0

	commander_x = -4
	commander_y = 0

	rotation_speed = 1

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		commander_seat = new /obj/structure/bed/chair/commander(src.loc)
		commander_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/japanese57(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/type99/type97tank(src))
		..()

/obj/structure/turret/hago
	turret_color = "#6a5a3d"
	turret_icon = "type95_turret"
	name = "Type 95 Ha-Go"

	turret_x = -12
	turret_y = 0

	gunner_x = 0
	gunner_y = 0

	commander_x = 0
	commander_y = 0

	rotation_speed = 2

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner/mtlb(src.loc)
		gunner_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/japanese37(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/type99/type97tank(src))
		..()


/obj/structure/turret/bmv1
	turret_color = "#3d5931"
	turret_icon = "char1_turret"
	name = "BMV-1 mk. I"

	gunner_x = 9
	gunner_y = -2

	loader_x = -9
	loader_y = -2

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		loader_seat = new /obj/structure/bed/chair/loader(src.loc)
		loader_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/bmv75(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/dp28/dt28(src))
		..()


/obj/structure/turret/smf1
	turret_color = "#555346"
	turret_icon = "t34_turret"
	name = "SMF I mod. A"

	gunner_x = 9
	gunner_y = -2

	loader_x = -9
	loader_y = -2

	New()
		gunner_seat = new /obj/structure/bed/chair/gunner(src.loc)
		gunner_seat.setup(src)
		loader_seat = new /obj/structure/bed/chair/loader(src.loc)
		loader_seat.setup(src)
		weapons.Add(new/obj/structure/cannon/modern/tank/smf75(src))
		weapons.Add(new/obj/item/weapon/gun/projectile/automatic/dp28/dt28(src))
		..()