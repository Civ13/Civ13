///So in Civ13 theres two measures of radiation used: Sieverts (and mSv and uSv) for emitted radiation and Grays/rads (1 Gy = 100 rads) for absorbed radiation.
///GRAYS: basic unit used is rad. For an adult human, exposure to 2 Gy from an unfocused radiation source such as an excursion will cause radiation sickness but is not considered definitely lethal; 2.4-3.4 Gy is the median lethal dose; a dose of 5 Gy almost always kills.
///SIEVERTS: basic unit used is mSv. An exposure to 1 Sv for 1 hour gives a total exposure of 1 Gy (since 1 Sv is equal to 1 Gy for all except alpha radiation).
///The radiation var of humans is measured in rads, so 100 radiation means 1 Gy. 1 mSv = 0.1 rad

/// RAD_LEVEL_NORMAL 15 //0.15 Gy, equal to 1 year smoking 1 1/2 packs of cigarettes a day. Avg dose for Chernobyl recovery workers.
/// RAD_LEVEL_MODERATE 40 //Gives mild radiation poisoning symptoms (vomiting, erytrema)
/// RAD_LEVEL_HIGH 100 //Gives radiation poisoning (passing out, twitches, severe erytrema)
/// RAD_LEVEL_VERY_HIGH 200 //Severe radiation poisoning, sometimes fatal
/// RAD_LEVEL_CRITICAL 300 //LD50
/// RAD_LEVEL_DEADLY 500 //Always kills

//severity: mSv per second. duration: duration in seconds
/proc/radiation_pulse(turf/epicenter, range, severity, duration, log)
	duration = round(duration)
	var/last = world.time + duration
	if(!epicenter || !severity || duration < 1) return FALSE

	if(!istype(epicenter, /turf))
		epicenter = get_turf(epicenter.loc)

	for(var/atom/T in range(range, epicenter))
		var/cseverity=severity/100
		var/distance = get_dist(epicenter, T)
		if(distance < 0)
			distance = 0
		if (distance <= 1 && distance <= range)
			T.rad_act(cseverity)
		else if (distance > 1 && distance <= range)
			T.rad_act(cseverity*(1-(distance/range)))
	if (world.time <= last && duration > 0)
		spawn(10)
			radiation_pulse(epicenter, range, severity, duration-1, 0)
	if (log)
		log_game("Radiation emission at ([epicenter.x],[epicenter.y],[epicenter.z]) with size ([range]) and severity [severity] mSv in area [epicenter.loc.name] ")
	change_global_radiation((severity/100)/10000) //Very slow radiation of the entire world. Even slower now because ungas love leaving uranium around.

	return TRUE

/atom/proc/rad_act(var/severity)
	return 0

//Rad stuff for plants
/obj/structure/wild/rad_act(amount)
	if(amount <= 0)
		return
	radiation += amount
	if(radiation >= 15 && (icon_state != deadicon_state || icon != deadicon) && !findtext(name,"irradiated"))
		icon = deadicon
		icon_state = deadicon_state
		health = health/2
		maxhealth = maxhealth/2
		name = "irradiated " + name
		update_icon()

/turf/floor/rad_act(amount)
	if(amount <= 0)
		return
	radiation += amount
	update_icon()
	return
//Rad stuff for grass
/turf/floor/grass/rad_act(amount)
	if(amount <= 0)
		return
	radiation += amount
	update_icon()
	return

/turf/floor/beach/water/rad_act(amount)
	if(amount <= 0)
		return
	radiation += amount
	update_icon()
	return

/obj/structure/farming/plant/rad_act(amount)
	if(amount <= 0)
		return
	radiation += amount
	if(radiation >= 8)
		stage = 15
		icon_state = "[plant]-dead"
		desc = "A dead irradiated [plant] plant."
		name = "radiation-burned dead [plant]"
	update_icon()
	return

/obj/structure/sink/rad_act(amount)
	if(amount <= 0)
		return
	radiation += amount
	return

/mob/living/rad_act(amount)
	if(amount <= 0)
		return
	radiation += amount
	return

/mob/living/human/rad_act(amount)
	if(amount <= 0)
		return
	if (inducedSSD)
		return
	for (var/obj/item/organ/external/sorgan in organs)
		var/blocked = getarmor_rad(sorgan.name)
		var/new_amount = max(0, (amount/11)*(1 - blocked/100)) //we need to divide it by 11 because there are 11 external body parts. Otherwise the dose is 11 time greater than it is supposed to be.
		if (orc || ant)
			new_amount *= 0.5
		else if (crab)
			new_amount *= 0.33
		radiation += new_amount
	for(var/obj/I in src) //Radiation is also applied to items held by the mob, but with the unprotected values in the case of geiger counters
		if (istype(I, /obj/item/weapon/geiger_counter))
			I.rad_act(amount)
		else
			var/blocked = getarmor_rad("chest")
			var/new_amount = max(0, amount*(1 - blocked/100))
			I.rad_act(new_amount)
/mob/living/human/proc/getarmor_rad(organ)
	return getarmor_organ(get_organ(organ), "rad")

/obj/item/weapon/geiger_counter //DISCLAIMER: I know nothing about how real-life Geiger counters work. This will not be realistic. ~Xhuis
	name = "geiger counter"
	desc = "A device used to detect radiation."
	w_class = ITEM_SIZE_SMALL
	slot_flags = SLOT_BELT|SLOT_ID|SLOT_POCKET
	icon = 'icons/obj/device.dmi'
	icon_state = "geiger_off"
	item_state = "multitool"
	flammable = TRUE
	var/scanning = 0
	var/radiation_count = 0
	var/checked = FALSE

/obj/item/weapon/geiger_counter/examine(mob/user)
	..()
	if(!scanning)
		return
	else
		check_radiation(user)

/obj/item/weapon/geiger_counter/update_icon()
	if(!scanning)
		icon_state = "geiger_off"
		return
	switch(radiation_count)
		if(-INFINITY to RAD_LEVEL_NORMAL)
			icon_state = "geiger_on_1"
		if(RAD_LEVEL_NORMAL + 1 to RAD_LEVEL_MODERATE)
			icon_state = "geiger_on_2"
		if(RAD_LEVEL_MODERATE + 1 to RAD_LEVEL_HIGH)
			icon_state = "geiger_on_3"
		if(RAD_LEVEL_HIGH + 1 to RAD_LEVEL_VERY_HIGH)
			icon_state = "geiger_on_4"
		if(RAD_LEVEL_VERY_HIGH + 1 to RAD_LEVEL_CRITICAL)
			icon_state = "geiger_on_4"
		if(RAD_LEVEL_CRITICAL + 1 to INFINITY)
			icon_state = "geiger_on_5"
	..()

/obj/item/weapon/geiger_counter/rad_act(var/severity)
	radiation_count = severity*100 //to convert to mSv
	var/backgroundrad = 0
	if (global_radiation > 0 && loc.z == world.maxz)
		backgroundrad = global_radiation/1000
	radiation_count = (radiation_count+backgroundrad)
	update_icon()

/obj/item/weapon/geiger_counter/proc/check_radiation(mob/user)
	if(!scanning || !checked)
		radiation_count = 0
		return
	if (radiation_count >= 1000)
		user << "<font size=2>\icon[getFlatIcon(src)] Reading: <b>[radiation_count/1000] Sv/s</b></span>"
	else if (radiation_count <= 0.001)
		user << "<font size=2>\icon[getFlatIcon(src)] Reading: <b>0 uSv/s</b></span>"
	else if (radiation_count <= 0.1)
		user << "<font size=2>\icon[getFlatIcon(src)] Reading: <b>[radiation_count*1000] uSv/s</b></span>"
	else
		user << "<font size=2>\icon[getFlatIcon(src)] Reading: <b>[radiation_count] mSv/s</b></span>"
	radiation_count = 0
	checked = FALSE
	return

/obj/item/weapon/geiger_counter/attack_self(mob/user)
	if (scanning)
		check_radiation(user)
		return

/obj/item/weapon/geiger_counter/attack(atom/M, mob/user)
	if(user.a_intent == I_HELP)
		user.visible_message("<span class='notice'>[user] scans [M] with [src].</span>", "<span class='notice'>You scan [M]'s radiation levels with [src]...</span>")
		user << "<font size=2>\icon[getFlatIcon(src)] Reading: <b>[M.radiation/100] Gy</b></span>"
		return
	..()

/obj/item/weapon/geiger_counter/verb/turn_on()
	set category = null
	set name = "Turn On/Off"
	set src in range(1, usr)

	scanning = !scanning
	update_icon()
	usr << "<span class='notice'>You switch [scanning ? "on" : "off"] \the [src].</span>"
	if (!scanning)
		radiation_count = 0
	if (scanning)
		processing()

/obj/item/weapon/geiger_counter/proc/processing()
	if (scanning)
		var/backgroundrad = 0
		if (global_radiation > 0 && loc.z == world.maxz)
			backgroundrad = global_radiation/1000
		if (backgroundrad > radiation_count)
			radiation_count = (radiation_count+backgroundrad)
		var/rad_min = radiation_count*60 //we check the effects over 1 min
		switch(rad_min)
			if(RAD_LEVEL_NORMAL to RAD_LEVEL_MODERATE)
				playsound(get_turf(src), pick('sound/machines/geiger/low1.ogg','sound/machines/geiger/low2.ogg','sound/machines/geiger/low3.ogg','sound/machines/geiger/low4.ogg'),75)
			if(RAD_LEVEL_MODERATE + 1 to RAD_LEVEL_HIGH)
				playsound(get_turf(src), pick('sound/machines/geiger/med1.ogg','sound/machines/geiger/med2.ogg','sound/machines/geiger/med3.ogg','sound/machines/geiger/med4.ogg'),75)
			if(RAD_LEVEL_HIGH + 1 to RAD_LEVEL_VERY_HIGH)
				playsound(get_turf(src), pick('sound/machines/geiger/med1.ogg','sound/machines/geiger/med2.ogg','sound/machines/geiger/med3.ogg','sound/machines/geiger/med4.ogg'),75)
			if(RAD_LEVEL_VERY_HIGH + 1 to RAD_LEVEL_CRITICAL)
				playsound(get_turf(src), pick('sound/machines/geiger/high1.ogg','sound/machines/geiger/high2.ogg','sound/machines/geiger/high3.ogg','sound/machines/geiger/high4.ogg'),75)
			if(RAD_LEVEL_CRITICAL + 1 to INFINITY)
				playsound(get_turf(src), pick('sound/machines/geiger/ext1.ogg','sound/machines/geiger/ext2.ogg','sound/machines/geiger/ext3.ogg','sound/machines/geiger/ext4.ogg'),75)
		update_icon()
		checked = TRUE
		spawn(10)
			processing()
	else
		radiation_count = 0
		return


/proc/nuke_map(turf/epicenter, severity, duration, log)
	duration = round(duration)
	var/last = world.time + duration
	if(!epicenter || !severity || duration < 1) return FALSE
	if(!istype(epicenter, /turf))
		epicenter = get_turf(epicenter.loc)
	explosion(epicenter, 10, 18, 23, 200)
	spawn(9)
		for (var/turf/floor/TF in range(25,epicenter))
			if (istype(TF, /turf/floor/dirt) || istype(TF, /turf/floor/grass) || istype(TF, /turf/floor/plating) || istype(TF, /turf/floor/beach/sand))
				if (prob(100*(1-(get_dist(TF,epicenter)/25))))
					TF.ChangeTurf(/turf/floor/dirt/burned)
				else
					if (prob(50))
						new/obj/effect/fire(TF)
			TF.radiation = 20
	spawn(14)
		for (var/mob/m in player_list)
			if (m.client)
				shake_camera(m, 3, (5 - (0.5)))
	spawn (20)
		for (var/turf/floor/grass/G in grass_turf_list)
			G.rad_act(severity /3)
	spawn (23)
		for (var/turf/floor/beach/water/G in water_turf_list)
			G.rad_act(severity /3)
	spawn(26)
		for(var/atom/T)
			if (T.z == epicenter.z && (istype(T, /mob/living) || istype(T, /obj)))
				var/cseverity=severity/3
				if (ismob(T))
					if (get_area(T).location == 0)
						cseverity = severity/100
					else
						cseverity = severity/30
					T.rad_act(cseverity)
					if (ishuman(T))
						var/mob/living/human/H = T
						H.Weaken(3)
						if (H.HUDtech.Find("flash"))
							flick("e_flash", H.HUDtech["flash"])
			if (istype(T, /obj/structure/window))
				var/obj/structure/window/W = T
				W.shatter()
			else if (istype(T, /obj))
				if (prob(20) && T.density && T.z == epicenter.z)
					T.ex_act(1.0)
		if (world.time <= last && duration > 0)
			spawn(10)
				radiation_pulse(epicenter, 100, severity, duration-1, 0)
	spawn(15)
		global_colour_matrix = list(0.8, 0.1, 0.1,\
						0.1, 0.8, 0.1,\
						0.1, 0.1, 0.8)
	spawn(50)
		for (var/obj/structure/wild/W)
			W.rad_act(22)
	spawn(65)
		for (var/obj/structure/farming/F)
			F.rad_act(22)

	if (log)
		log_game("<font color='red'>Nuke detonated in the map!</font>")

	change_global_radiation(310)
	return TRUE
