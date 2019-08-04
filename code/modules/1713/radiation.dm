///So in Civ13 theres two measures of radiation used: Sieverts (and mSv and uSv) for emitted radiation and Grays/rads (1 Gy = 100 rads) for absorbed radiation.
///GRAYS: basic unit used is rad. For an adult human, exposure to 2 Gy from an unfocused radiation source such as an excursion will cause radiation sickness but is not considered definitely lethal; 2.4-3.4 Gy is the median lethal dose; a dose of 5 Gy almost always kills.
///SIEVERTS: basic unit used is mSv. An exposure to 1 Sv for 1 hour gives a total exposure of 1 Gy (since 1 Sv is equal to 1 Gy for all except alpha radiation).
///The radiation var of humans is measured in rads, so 100 radiation means 1 Gy. 1 mSv = 0.1 rad

#define RAD_LEVEL_NORMAL 15 //0.15 Gy, equal to 1 year smoking 1 1/2 packs of cigarettes a day. Avg dose for Chernobyl recovery workers.
#define RAD_LEVEL_MODERATE 40 //Gives mild radiation poisoning symptoms (vomiting, erytrema)
#define RAD_LEVEL_HIGH 100 //Gives radiation poisoning (passing out, twitches, severe erytrema)
#define RAD_LEVEL_VERY_HIGH 200 //Severe radiation poisoning, sometimes fatal
#define RAD_LEVEL_CRITICAL 300 //LD50
#define RAD_LEVEL_DEADLY 500 //Always kills

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
		log_game("Radiation emission with size ([range]) and severity [severity] mSv in area [epicenter.loc.name] ")
	return TRUE

/atom/proc/rad_act(var/severity)
	return 0

/mob/living/carbon/human/rad_act(amount)
	if(amount <= 0)
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

/mob/living/carbon/human/proc/getarmor_rad(organ)
	return getarmor_organ(get_organ(organ), "rad")

/obj/item/weapon/geiger_counter //DISCLAIMER: I know nothing about how real-life Geiger counters work. This will not be realistic. ~Xhuis
	name = "geiger counter"
	desc = "A device used to detect radiation."
	w_class = 2.0
	slot_flags = SLOT_BELT|SLOT_ID|SLOT_POCKET
	icon = 'icons/obj/device.dmi'
	icon_state = "geiger_off"
	item_state = "multitool"
	flammable = TRUE
	var/scanning = 0
	var/radiation_count = 0

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
	update_icon()

/obj/item/weapon/geiger_counter/proc/check_radiation(mob/user)
	if(!scanning)
		return
	if (radiation_count >= 1000)
		user << "<font size=2>\icon[getFlatIcon(src)] Reading: <b>[radiation_count/1000] Sv/s</b></span>"
	else if (radiation_count <= 0.001)
		user << "<font size=2>\icon[getFlatIcon(src)] Reading: <b>0 uSv/s</b></span>"
	else if (radiation_count <= 0.1)
		user << "<font size=2>\icon[getFlatIcon(src)] Reading: <b>[radiation_count*1000] uSv/s</b></span>"
	else
		user << "<font size=2>\icon[getFlatIcon(src)] Reading: <b>[radiation_count] mSv/s</b></span>"
	return

/obj/item/weapon/geiger_counter/attack_self(mob/user)
	if (scanning)
		check_radiation(user)
		return

/obj/item/weapon/geiger_counter/attack(mob/living/M, mob/user)
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
	if (scanning)
		processing()


/obj/item/weapon/geiger_counter/proc/processing()
	if (scanning)
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
		spawn(10)
			processing()
	else
		return