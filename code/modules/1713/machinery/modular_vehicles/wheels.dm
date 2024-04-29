//////////////DRIVING WHEELS///////////////////////

/obj/item/vehicleparts/wheel/modular
	name = "vehicle wheel"
	desc = "Used to steer a vehicle."
	icon_state = "wheel_b"
	item_state = "wheel_b"
	worn_state = "wheel_b"
	var/obj/structure/bed/chair/drivers/drivingchair = null
	var/obj/structure/vehicleparts/frame/control = null
	var/lastdirchange = 0

/obj/item/vehicleparts/wheel/modular/Destroy()
	drivingchair = null
	control = null
	..()

/obj/item/vehicleparts/wheel/modular/proc/turndir(var/mob/living/mob = null, var/newdir = "left")
	if (world.time <= lastdirchange)
		return FALSE
	lastdirchange = world.time+control.axis.turntimer
	if (control && control.axis && (control.axis.moving == FALSE || control.axis.currentspeed == 0))
		return FALSE
	if (!control || !control.axis)
		return
	for(var/obj/effect/pseudovehicle/O in control.axis.components)
		for(var/obj/structure/vehicleparts/frame/VP in O.loc)
			if (VP.axis != control.axis)
				if (mob)
					to_chat(mob, "<span class='warning'>You can't turn, something is in the way!</span>")
				return FALSE
		for(var/obj/effect/pseudovehicle/PV in O.loc)
			if (PV.link != control.axis)
				if (mob)
					to_chat(mob, "<span class='warning'>You can't turn, something is in the way!</span>")
				return FALSE
	if (newdir == "left")
		if (!control.axis.do_matrix(dir,TURN_LEFT(control.axis.dir), newdir))
			return FALSE
	else
		if (!control.axis.do_matrix(dir,TURN_RIGHT(control.axis.dir), newdir))
			return FALSE
	return TRUE

/obj/structure/bed/chair/drivers/ex_act(severity)
	switch(severity)
		if (1.0)
			if (prob(40))
				Destroy()
				return
		if (2.0)
			if (prob(10))
				Destroy()
				return
		if (3.0)
			return

/obj/structure/bed/chair/drivers/Destroy()
	if (wheel)
		wheel.control.axis.wheel = null
		wheel.Destroy()
		wheel = null
	visible_message("<span class='danger'>The [name] gets destroyed!</span>")
	..()

/obj/item/vehicleparts/wheel/modular/attack_self(mob/living/human/H)
	if(!control)
		return
	if(!control.axis)
		return
	if (!(control.loc in range(1,loc)))
		H.remove_from_mob(src)
		src.forceMove(drivingchair)
		return
	if (!control.axis.engine)
		return
	if (!control.axis.engine.fueltank)
		return
	if (!control.axis.engine.fueltank.reagents)
		to_chat(H, "There is not enough fuel!")
		return
	if (!control.axis.engine.on && control.axis.engine.fueltank.reagents.total_volume > 0)
		control.axis.currentspeed = 0
		control.axis.engine.turn_on(H)
		if (isemptylist(control.axis.corners))
			control.axis.check_corners()
		if (isemptylist(control.axis.matrix))
			control.axis.check_matrix()
		playsound(loc, control.axis.engine.starting_snd, 35, FALSE, 2)
		spawn(40)
			if (control.axis.engine && control.axis.engine.on)
				control.axis.engine.running_sound()
		return
	else if (control.axis.engine && control.axis.engine.fueltank)
		if (control.axis && control.axis.engine && control.axis.engine.fueltank && control.axis.engine.fueltank.reagents.total_volume <= 0)
			to_chat(H, "There is not enough fuel!")
			return
	if (control.axis.currentspeed < 0)
		control.axis.currentspeed = 0
	control.axis.currentspeed++
	if (control.axis.currentspeed>control.axis.speeds)
		control.axis.currentspeed = control.axis.speeds

	else
		var/spd = control.axis.get_speed()
		control.axis.vehicle_m_delay = spd
		if (control.axis.currentspeed == 1 && !control.axis.moving)
			control.axis.moving = TRUE
			to_chat(H, "You put the vehicle into first gear.")
			playsound(loc, 'sound/effects/lever.ogg',40, TRUE)
			control.axis.add_transporting()
			control.axis.startmovementloop()
		if (spd <= 0)
			return
		else
			control.axis.vehicle_m_delay = spd
			if (control.axis.currentspeed < control.axis.speedlist.len+1)
				to_chat(H, "You increase the speed.")
				playsound(loc, 'sound/effects/lever.ogg',40, TRUE)
			return


/obj/item/vehicleparts/wheel/modular/secondary_attack_self(mob/living/human/user)
	if (!control || !control.axis)
		return
	if (control && control.axis && control.axis.engine && control.axis.engine.fueltank && (control.axis.currentspeed <= 0 || control.axis.engine.fueltank.reagents.total_volume <= 0))
		if (control.axis.engine.on)
			to_chat(user, "You turn off the [control.axis.engine].")
			control.axis.engine.on = FALSE
			control.axis.moving = FALSE
			control.axis.currentspeed = 0
			control.axis.engine.update_icon()
			return

		return
	else
		var/spd = control.axis.get_speed()
		control.axis.currentspeed--
		spd = control.axis.get_speed()
		if (spd <= 0 || control.axis.currentspeed == 0)
			control.axis.moving = FALSE
			to_chat(user, "You stop the [control.axis].")
			for (var/obj/structure/vehicleparts/movement/W in control.axis.wheels)
				W.update_icon()
			return
		else
			control.axis.vehicle_m_delay = spd
			to_chat(user, "You reduce the speed.")
			playsound(loc, 'sound/effects/lever.ogg',40, TRUE)
			return

/obj/structure/bed/chair/drivers
	name = "driver's seat"
	desc = "Where you drive the vehicle."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "driver_car"
	anchored = FALSE
	var/obj/structure/vehicleparts/axis/axis = null
	var/obj/item/vehicleparts/wheel/modular/wheel = null
	New()
		..()
		wheel = new/obj/item/vehicleparts/wheel/modular(src)
		wheel.drivingchair = src

/obj/structure/bed/chair/drivers/tank
	name = "tank driver's seat"
	icon_state = "driver_tank"
	flammable = FALSE

/obj/structure/bed/chair/drivers/user_unbuckle_mob(mob/user)
	var/mob/living/M = unbuckle_mob()
	if (axis)
		axis.driver = null
	if (M)
		if (M != user)
			M.visible_message(\
				"<span class='notice'>[M.name] was unbuckled by [user.name]!</span>",\
				"<span class='notice'>You were unbuckled from [src] by [user.name].</span>",\
				"<span class='notice'>You hear metal clanking.</span>")
		else
			M.visible_message(\
				"<span class='notice'>[M.name] unbuckled themselves!</span>",\
				"<span class='notice'>You unbuckle yourself from [src].</span>",\
				"<span class='notice'>You hear metal clanking.</span>")
		add_fingerprint(user)
		for(var/obj/item/vehicleparts/wheel/modular/MW in M)
			M.remove_from_mob(MW)
			MW.forceMove(src)
			if (wheel && wheel.control && wheel.control.axis && wheel.control.axis.engine && wheel.control.axis.engine.on)
				wheel.control.axis.engine.on = FALSE
				wheel.control.axis.moving = FALSE
				wheel.control.axis.currentspeed = 0
				wheel.control.axis.engine.update_icon()
				to_chat(user, "You stop the [wheel.control.axis].")
				for (var/obj/structure/vehicleparts/movement/W in wheel.control.axis.wheels)
					W.update_icon()
	return M

/obj/structure/bed/chair/drivers/update_icon()
	return

/obj/structure/bed/chair/drivers/post_buckle_mob()
	if (axis)
		axis.driver = buckled_mob
	if (buckled_mob && istype(buckled_mob, /mob/living/human) && buckled_mob.put_in_active_hand(wheel) == FALSE)
		to_chat(buckled_mob, "Your hands are full!")
		return

/obj/structure/bed/chair/drivers/attackby(var/obj/item/I, var/mob/living/human/H)
	if (buckled_mob && H == buckled_mob && istype(I, /obj/item/vehicleparts/wheel/modular))
		H.remove_from_mob(I)
		I.forceMove(src)
		user_unbuckle_mob(H)
		return
	else
		..()
/obj/structure/bed/chair/drivers/attack_hand( var/mob/living/human/H)
	if (wheel && buckled_mob && H == buckled_mob && wheel.loc != H)
		if (buckled_mob.put_in_active_hand(wheel))
			to_chat(H, "You grab the wheel.")
			if (map.ID == MAP_THE_ART_OF_THE_DEAL)
				if (H.stat != DEAD && H.civilization != "Sheriff Office" && H.civilization != "Paramedics" && H.civilization != "Government")
					for(var/list/L in map.vehicle_registrations)
						if (L[1]==wheel.control.axis.reg_number && L[2] != H.civilization)
							if (!(H.real_name in map.warrants))
								var/reason = "Grand Theft Auto"
								if (L[2] == "Sheriff Office")
									reason = "Theft of a Law Enforcement Vehicle"
								if (L[2] == "Paramedics")
									reason = "Theft of an Ambulance"
								if (L[2] == "Government")
									reason = "Theft of a Government Vehicle"
								map.warrants += H.real_name
								H.gun_permit = 0
								H.bail_price += 500
								var/obj/item/weapon/paper_bin/police/PAR = null
								for(var/obj/item/weapon/paper_bin/police/PAR2 in world)
									PAR = PAR2
									break
								if (PAR)
									var/obj/item/weapon/paper/police/warrant/SW = new /obj/item/weapon/paper/police/warrant(PAR.loc)
									SW.tgt_mob = H
									SW.tgt = H.real_name
									SW.tgtcmp = H.civilization
									SW.reason = reason
									PAR.add(SW)
									SW.spawntimer = 12000
								var/obj/item/weapon/paper/police/warrant/SW2 = new /obj/item/weapon/paper/police/warrant(null)
								SW2.tgt_mob = H
								SW2.tgt = H.real_name
								SW2.tgtcmp = H.civilization
								SW2.reason = reason
								map.pending_warrants += SW2
								SW2.forceMove(null)
								global_broadcast(FREQP,"<big>Attention, a stolen vehicle has been reported: <b>[L[1]]</b> - <b>[L[4]] [L[3]]</b> - registered to <b>[L[2]]</b><br>. A warrant has been issued for [SW2.tgt], please intervene immediately and detain the suspect.</big>")
								break
			return
	else
		..()

/obj/structure/bed/chair/mgunner
	name = "machinegunner's seat"
	desc = "a seat with a course machinegun."
	icon_state = "officechair_white"
	anchored = FALSE
	flammable = FALSE
	var/obj/item/weapon/gun/projectile/automatic/mg = null
	New()
		..()
		if(mg)
			mg.mount = src
			mg.nothrow = TRUE
			mg.nodrop = TRUE
			mg.recoil = 1
/obj/structure/bed/chair/mgunner/rotate_right()
	return

/obj/structure/bed/chair/mgunner/rotate_left()
	return

/obj/structure/bed/chair/mgunner/update_icon()
	return

/obj/structure/bed/chair/mgunner/post_buckle_mob()
	if (buckled_mob && istype(buckled_mob, /mob/living/human) && mg)
		if(buckled_mob.put_in_active_hand(mg) == FALSE)
			buckled_mob << "Your hands are full!"
			return

/obj/structure/bed/chair/mgunner/dt28/New()
		mg = new/obj/item/weapon/gun/projectile/automatic/dp28/dt28(src)
		..()

/obj/structure/bed/chair/mgunner/dtm28/New()
		mg = new/obj/item/weapon/gun/projectile/automatic/dp28/dt28/dtm28(src)
		..()

/obj/structure/bed/chair/mgunner/mg34/New()
		mg = new/obj/item/weapon/gun/projectile/automatic/manual/mg34(src)
		..()

/obj/structure/bed/chair/mgunner/browning_lmg/New()
		mg = new/obj/item/weapon/gun/projectile/automatic/browning_lmg(src)
		..()

/obj/structure/bed/chair/mgunner/pkm/New()
		mg = new/obj/item/weapon/gun/projectile/automatic/pkm(src)
		..()

/obj/structure/bed/chair/mgunner/type99/New()
		mg = new/obj/item/weapon/gun/projectile/automatic/type99(src)
		..()

/obj/structure/bed/chair/mgunner/user_unbuckle_mob(mob/user)
	var/mob/living/M = unbuckle_mob()
	if (M)
		if (M != user)
			M.visible_message(\
				"<span class='notice'>[M.name] was unbuckled by [user.name]!</span>",\
				"<span class='notice'>You were unbuckled from [src] by [user.name].</span>",\
				"<span class='notice'>You hear metal clanking.</span>")
		else
			M.visible_message(\
				"<span class='notice'>[M.name] unbuckled themselves!</span>",\
				"<span class='notice'>You unbuckle yourself from [src].</span>",\
				"<span class='notice'>You hear metal clanking.</span>")
		add_fingerprint(user)
		if(mg)
			M.remove_from_mob(mg)
			mg.forceMove(src)
	return M

////////GUNNER///////////
/obj/structure/bed/chair/gunner
	name = "gunner's seat"
	desc = "a seat next to the gun trigger."
	icon_state = "officechair_white"
	anchored = FALSE
	flammable = FALSE
	var/obj/structure/turret/turret = null
	var/obj/item/turret_controls/controls = null
	New()
		..()
		controls = new/obj/item/turret_controls(src)

/obj/structure/bed/chair/gunner/proc/setup(var/obj/structure/turret/origin_turret)
	turret = origin_turret
	controls.turret = origin_turret
	update_icon()

/obj/structure/bed/chair/gunner/update_icon()
	if(!turret)
		return
	dir = turret.dir
	switch(turret.dir)
		if(EAST)
			pixel_x = -turret.gunner_y - 8
			pixel_y = turret.gunner_x - 8
		if(NORTH)
			pixel_x = -turret.gunner_x
			pixel_y = -turret.gunner_y - 16
		if(WEST)
			pixel_x = turret.gunner_y + 8
			pixel_y = -turret.gunner_x - 7
		if(SOUTH)
			pixel_x = turret.gunner_x
			pixel_y = turret.gunner_y

	pixel_x += turret.pixel_x
	pixel_y += turret.pixel_y

	if(buckled_mob)
		buckled_mob.dir = dir
		buckled_mob.pixel_x = pixel_x
		buckled_mob.pixel_y = pixel_y

/obj/structure/bed/chair/gunner/post_buckle_mob()
	..()
	update_icon()
	if(buckled_mob)
		buckled_mob.pixel_x = pixel_x
		buckled_mob.pixel_y = pixel_y
		if(turret)
			turret.draw_aiming_line(buckled_mob)
			turret.gunner = buckled_mob
		if (istype(buckled_mob, /mob/living/human))
			if(buckled_mob.put_in_active_hand(controls) == FALSE)
				buckled_mob << "Your hands are full!"
				return
			else
				controls.azoom.Grant(buckled_mob)

/obj/structure/bed/chair/gunner/attackby(var/obj/item/I, var/mob/living/human/H)
	if (buckled_mob && H == buckled_mob && istype(I, /obj/item/turret_controls))
		H.remove_from_mob(I)
		I.forceMove(src)
		user_unbuckle_mob(H)
		return
	else
		..()

/obj/structure/bed/chair/gunner/user_unbuckle_mob(mob/user)
	var/mob/living/M = unbuckle_mob()
	if (M)
		if (M != user)
			M.visible_message(\
				"<span class='notice'>[M.name] was unbuckled by [user.name]!</span>",\
				"<span class='notice'>You were unbuckled from [src] by [user.name].</span>",\
				"<span class='notice'>You hear metal clanking.</span>")
		else
			M.visible_message(\
				"<span class='notice'>[M.name] unbuckled themselves!</span>",\
				"<span class='notice'>You unbuckle yourself from [src].</span>",\
				"<span class='notice'>You hear metal clanking.</span>")
		add_fingerprint(user)
		for(var/obj/item/turret_controls/C in M)
			M.remove_from_mob(C)
			C.forceMove(src)
		if(turret)
			M.stop_using_turret()
			turret.gunner = null
	return M

/obj/item/turret_controls
	icon = 'icons/obj/device.dmi'
	icon_state = "turret_control"
	item_state = "turret_control"
	worn_state = "turret_control"
	nothrow = TRUE
	nodrop = TRUE
	var/datum/action/toggle_scope/azoom
	var/obj/item/weapon/attachment/scope/adjustable/binoculars/periscope/optics
	var/obj/structure/turret/turret = null
	var/is_rotating = FALSE
	var/rotating_dir = 0
	New()
		..()
		optics = new/obj/item/weapon/attachment/scope/adjustable/binoculars/periscope()
		build_zooming()

/obj/item/turret_controls/proc/get_zoom_amt()
	if(!optics)
		return ZOOM_CONSTANT
	return optics.zoom_amt

/obj/item/turret_controls/proc/build_zooming()
	azoom = new()
	azoom.scope = optics
	actions += azoom

/obj/item/turret_controls/scope/on_changed_slot()
	..()

	if (azoom)
		if (istype(loc, /obj/item))
			var/mob/M = loc.loc
			if (M && istype(M))
				azoom.Remove(M)
				if(loc == M.r_hand || loc == M.l_hand)
					azoom.Grant(M)

		else if (istype(loc, /mob))
			var/mob/M = loc
			if (istype(M))
				azoom.Remove(M)
				if (src == M.r_hand || src == M.l_hand)
					azoom.Grant(M)

/obj/item/turret_controls/dropped(mob/user)
	..()
	if (azoom)
		azoom.Remove(user)

/obj/item/turret_controls/proc/stop_rotation()
	rotating_dir = 0
	is_rotating = FALSE

/obj/item/turret_controls/proc/start_rotation(var/direction)
	rotating_dir = direction
	if(!is_rotating)
		is_rotating = TRUE
		rotate()

/obj/structure/bed/chair/gunner/mtlb/update_icon()
	if(!turret)
		return
	dir = turret.dir
	switch(turret.dir)
		if(EAST)
			pixel_x = -turret.gunner_y
			pixel_y = turret.gunner_x
		if(NORTH)
			pixel_x = -turret.gunner_x
			pixel_y = -turret.gunner_y
		if(WEST)
			pixel_x = turret.gunner_y
			pixel_y = -turret.gunner_x
		if(SOUTH)
			pixel_x = turret.gunner_x
			pixel_y = turret.gunner_y

	pixel_x += turret.pixel_x
	pixel_y += turret.pixel_y

	if(buckled_mob)
		buckled_mob.dir = dir
		buckled_mob.pixel_x = pixel_x
		buckled_mob.pixel_y = pixel_y

/obj/item/turret_controls/proc/rotate()
	if(!turret)
		return
	if(!is_rotating)
		rotating_dir = 0
		return
	if (rotating_dir > 0)
		turret.icrease_target_azimuth(1)
	else if (rotating_dir < 0)
		turret.icrease_target_azimuth(-1)

	spawn(0.1)
		rotate()

/obj/item/turret_controls/proc/increase_distance(var/distance)
	if(!turret)
		return
	if(distance > 0)
		turret.icrease_target_distance(1)
	else
		turret.icrease_target_distance(-1)

/obj/item/turret_controls/attack_self(mob/living/human/user)
	if(!turret)
		return
	turret.open_fire()

/obj/item/turret_controls/proc/stop_firing()
	if(!turret)
		return
	turret.is_firing = FALSE

/obj/item/turret_controls/secondary_attack_self(mob/living/human/user)
	if(!turret)
		return
	turret.switch_weapon(user)

////////LOADER CHAIR////////
/obj/structure/bed/chair/loader
	name = "loader's seat"
	desc = "A seat at the gun loader's position."
	icon_state = "officechair_white"
	anchored = FALSE
	flammable = FALSE
	var/obj/structure/turret/turret = null

/obj/structure/bed/chair/loader/proc/setup(var/obj/structure/turret/origin_turret)
	turret = origin_turret
	update_icon()

/obj/structure/bed/chair/loader/update_icon()
	if(!turret)
		return
	dir = turret.dir
	switch(dir)
		if(EAST)
			pixel_x = -turret.loader_y - 8
			pixel_y = turret.loader_x - 8
		if(NORTH)
			pixel_x = -turret.loader_x
			pixel_y = -turret.loader_y - 16
		if(WEST)
			pixel_x = turret.loader_y + 8
			pixel_y = -turret.loader_x - 7
		if(SOUTH)
			pixel_x = turret.loader_x
			pixel_y = turret.loader_y

	pixel_x += turret.pixel_x
	pixel_y += turret.pixel_y

	if(buckled_mob)
		buckled_mob.dir = dir
		buckled_mob.pixel_x = pixel_x
		buckled_mob.pixel_y = pixel_y

/obj/structure/bed/chair/loader/post_buckle_mob()
	update_icon()
	if(buckled_mob)
		buckled_mob.pixel_x = pixel_x
		buckled_mob.pixel_y = pixel_y
		if(turret)
			turret.loader = buckled_mob

/obj/structure/bed/chair/loader/user_unbuckle_mob(mob/user)
	var/mob/living/M = unbuckle_mob()
	if (M)
		if (M != user)
			M.visible_message(\
				"<span class='notice'>[M.name] was unbuckled by [user.name]!</span>",\
				"<span class='notice'>You were unbuckled from [src] by [user.name].</span>",\
				"<span class='notice'>You hear metal clanking.</span>")
		else
			M.visible_message(\
				"<span class='notice'>[M.name] unbuckled themselves!</span>",\
				"<span class='notice'>You unbuckle yourself from [src].</span>",\
				"<span class='notice'>You hear metal clanking.</span>")
		add_fingerprint(user)
		if(turret)
			M.stop_using_turret()
			turret.loader = null
	return M

//////////COMMANDER CHAIR/////////////
/obj/structure/bed/chair/commander
	name = "commander's seat"
	desc = "The vehicle commander's seat, with a perisope."
	anchored = FALSE
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "commanders_seat"
	flammable = FALSE
	var/obj/structure/turret/turret = null
	var/obj/item/weapon/attachment/scope/adjustable/binoculars/periscope/periscope = null
	New()
		..()
		periscope = new/obj/item/weapon/attachment/scope/adjustable/binoculars/periscope(src)
		periscope.commanderchair = src

/obj/structure/bed/chair/commander/proc/setup(var/obj/structure/turret/origin_turret)
	turret = origin_turret
	update_icon()

/obj/structure/bed/chair/commander/user_unbuckle_mob(mob/user)
	var/mob/living/M = unbuckle_mob()
	if (M)
		if (M != user)
			M.visible_message(\
				"<span class='notice'>[M.name] was unbuckled by [user.name]!</span>",\
				"<span class='notice'>You were unbuckled from [src] by [user.name].</span>",\
				"<span class='notice'>You hear metal clanking.</span>")
		else
			M.visible_message(\
				"<span class='notice'>[M.name] unbuckled themselves!</span>",\
				"<span class='notice'>You unbuckle yourself from [src].</span>",\
				"<span class='notice'>You hear metal clanking.</span>")
		add_fingerprint(user)
		for(var/obj/item/weapon/attachment/scope/adjustable/binoculars/periscope/PS in M)
			M.remove_from_mob(PS)
			PS.forceMove(src)
		if(turret)
			M.stop_using_turret()
			turret.commander = null
	return M

/obj/structure/bed/chair/commander/update_icon()
	if(!turret)
		return
	dir = turret.dir
	switch(turret.dir)
		if(EAST)
			pixel_x = -turret.commander_y - 8
			pixel_y = turret.commander_x - 8
		if(NORTH)
			pixel_x = -turret.commander_x
			pixel_y = -turret.commander_y - 16
		if(WEST)
			pixel_x = turret.commander_y + 10
			pixel_y = -turret.commander_x - 7
		if(SOUTH)
			pixel_x = turret.commander_x
			pixel_y = turret.commander_y

	pixel_x += turret.pixel_x
	pixel_y += turret.pixel_y

	if(buckled_mob)
		buckled_mob.dir = dir
		buckled_mob.pixel_x = pixel_x
		buckled_mob.pixel_y = pixel_y

/obj/structure/bed/chair/commander/post_buckle_mob()
	if(buckled_mob)
		buckled_mob.pixel_x = pixel_x
		buckled_mob.pixel_y = pixel_y
		if(turret)
			turret.commander = buckled_mob
		if (istype(buckled_mob, /mob/living/human) && buckled_mob.put_in_active_hand(periscope) == FALSE)
			buckled_mob << "Your hands are full!"
			return

/obj/structure/bed/chair/commander/attackby(var/obj/item/I, var/mob/living/human/H)
	if (buckled_mob && H == buckled_mob && istype(I, /obj/item/weapon/attachment/scope/adjustable/binoculars/periscope))
		H.remove_from_mob(I)
		I.forceMove(src)
		user_unbuckle_mob(H)
		return
	else
		..()

/obj/structure/bed/chair/commander/attack_hand( var/mob/living/human/H)
	if (buckled_mob && H == buckled_mob && periscope.loc != H)
		if (buckled_mob.put_in_active_hand(periscope))
			H << "You look through the periscope."
			return
	else
		..()

///////COMMANDER NAVAL////////

/obj/structure/bed/chair/commander/naval
	name = "spotter's seat"
	desc = "A spotter's seat with a long-range periscope."
	anchored = TRUE
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "commanders_seat"
	New()
		..()
		periscope = new/obj/item/weapon/attachment/scope/adjustable/binoculars/periscope/naval(src)
		periscope.commanderchair = src

///////COMMANDER NVG////////

/obj/structure/bed/chair/commander/nvg
	name = "commander's seat with night vision"
	desc = "The vehicle commander's seat, with a perisope and night vision."
	anchored = FALSE
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "commanders_seat"
	flammable = FALSE
	var/overtype = "nvg"
	New()
		..()
		periscope = new/obj/item/weapon/attachment/scope/adjustable/binoculars/periscope(src)
		periscope.commanderchair = src

/obj/structure/bed/chair/commander/nvg/post_buckle_mob()
	if (buckled_mob && istype(buckled_mob, /mob/living/human) && buckled_mob.put_in_active_hand(periscope) == FALSE)
		buckled_mob << "Your hands are full!"
		return
	if(buckled_mob)
		buckled_mob << "You activate the optics on the [src]."
		if (overtype == "nvg")
			buckled_mob.nvg = TRUE
			buckled_mob.handle_vision()
		else if (overtype == "thermal")
			buckled_mob.thermal = TRUE
			buckled_mob.handle_vision()
		buckled_mob.update_action_buttons()

/obj/structure/bed/chair/commander/nvg/user_unbuckle_mob(mob/user)
	if(buckled_mob)
		buckled_mob << "You deactivate the optics on the [src]."
		if (overtype == "nvg")
			buckled_mob.nvg = FALSE
			buckled_mob.handle_vision()
		else if (overtype == "thermal")
			buckled_mob.thermal = FALSE
			buckled_mob.handle_vision()

	var/mob/living/M = unbuckle_mob()
	if (M)
		if (M != user)
			M.visible_message(\
				"<span class='notice'>[M.name] was unbuckled by [user.name]!</span>",\
				"<span class='notice'>You were unbuckled from [src] by [user.name].</span>",\
				"<span class='notice'>You hear metal clanking.</span>")
		else
			M.visible_message(\
				"<span class='notice'>[M.name] unbuckled themselves!</span>",\
				"<span class='notice'>You unbuckle yourself from [src].</span>",\
				"<span class='notice'>You hear metal clanking.</span>")
		add_fingerprint(user)
		for(var/obj/item/weapon/attachment/scope/adjustable/binoculars/periscope/PS in M)
			M.remove_from_mob(PS)
			PS.forceMove(src)
	return M

///////COMMANDER THERMAL////////

/obj/structure/bed/chair/commander/nvg/thermal
	name = "commander's seat with thermal imaging"
	desc = "The vehicle commander's seat, with a perisope and thermal imaging."
	overtype = "thermal"

