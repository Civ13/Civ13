/obj/map_metadata/siberiad
	ID = MAP_SIBERIAD
	title = "Operation Siberiad"
	lobby_icon = 'icons/lobby/siberiad.png'
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,/area/caribbean/no_mans_land/invisible_wall/one,/area/caribbean/no_mans_land/invisible_wall/two)
	respawn_delay = 600
	no_hardcore = FALSE
	ambience = list('sound/ambience/winter.ogg')
	can_spawn_on_base_capture = TRUE

	faction_organization = list(
		AMERICAN,
		RUSSIAN)

	roundend_condition_sides = list(
		list(AMERICAN) = /area/caribbean/no_mans_land/capturable/one,
		list(RUSSIAN) = /area/caribbean/no_mans_land/capturable/one,
		)
	age = "1992"
	faction_distribution_coeffs = list(AMERICAN = 0.5, RUSSIAN = 0.5)
	battle_name = "Siberian Conflict"
	mission_start_message = "<font size=4>The remnants of the <font color = red>Soviet Union</font color> are fighting the <font color = 'blue'>Coalition</font color> in a devastated Siberian town, home to a military research facility in the <b>MIDDLE</b>.<br>A helicopter transporting a high ranking officer has crashed in the <b>SOUTH-WEST</b> of the map.<br>Better retrieve the highly confidential documents in time before the enemy does...<br>The battle will start in roughly <b>5 minutes</b>.</font>"
	faction1 = AMERICAN
	faction2 = RUSSIAN
	ordinal_age = 7
	songs = list(
		"Audio - Emissions:1" = 'sound/music/emissions.ogg')
	gamemode = "Extraction"
	var/activation_code = 0

/obj/map_metadata/siberiad/New()
	..()
	activation_code = rand(1000,9999) // Lazy way for now.

/obj/map_metadata/siberiad/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3600 || admin_ended_all_grace_periods)

/obj/map_metadata/siberiad/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3600 || admin_ended_all_grace_periods)

/obj/map_metadata/siberiad/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/american))
		if (J.is_siberiad)
			. = TRUE
		else
			. = FALSE
	else if (istype(J, /datum/job/russian))
		if (J.is_siberiad)
			. = TRUE
		else
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/siberiad/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 1200 // 2 minutes

/obj/map_metadata/siberiad/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/siberiad/roundend_condition_def2name(define)
	..()
	switch (define)
		if (AMERICAN)
			return "American"
		if (RUSSIAN)
			return "Soviet"

/obj/map_metadata/siberiad/roundend_condition_def2army(define)
	..()
	switch (define)
		if (AMERICAN)
			return "Americans"
		if (RUSSIAN)
			return "Soviets"

/obj/map_metadata/siberiad/army2name(army)
	..()
	switch (army)
		if ("Americans")
			return "American"
		if ("Soviets")
			return "Soviet"

/obj/map_metadata/siberiad/cross_message(faction)
	if (faction == AMERICAN)
		return "<font size = 4>The <font color = blue>Coalition</font color> may now cross the invisible wall!</font>"
	else if (faction == RUSSIAN)
		return "<font size = 4>The <font color = red>Soviet Army</font color> may now cross the invisible wall!</font>"
	else
		return ""

/obj/map_metadata/siberiad/reverse_cross_message(faction)
	if (faction == AMERICAN)
		return "<span class = 'userdanger'>The <b><font color = blue>Coalition</b></font> may no longer cross the invisible wall!</span>"
	else if (faction == RUSSIAN)
		return "<span class = 'userdanger'>The <b><font color = red>Soviets</b></font> may no longer cross the invisible wall!</span>"
	else
		return ""

/obj/map_metadata/siberiad/update_win_condition()
	if (win_condition_spam_check)
		return FALSE
	for (var/obj/structure/props/computerprops/tracking/siberiad/TS in world)
		if (TS.active)
			ticker.finished = TRUE
			var/message = "The operation is over! The nuclear missile has been launched!"
			for (var/obj/structure/nuclear_missile/nuke in world)
				nuke.activate()
			switch (TS.destination)
				if (1)
					world << SPAN_NOTICE("<font size = 4>[message]</font>")
					world << SPAN_NOTICE("<font size = 4>It is heading towards Seattle. The Coalition's capitol is about to turn to dust.</font>")
				if (2)
					world << SPAN_NOTICE("<font size = 4>[message]</font>")
					world << SPAN_NOTICE("<font size = 4>It is heading towards Novosibirsk. The remnants of the Soviet Union are to be extinct.</font>")
			win_condition_spam_check = TRUE
			return FALSE
	return TRUE

/obj/map_metadata/siberiad/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE

// MAP SPECIFIC OBJECTS //

/obj/structure/props/computerprops/tracking/siberiad
	name = "launch terminal"
	desc = "A terminal used to control the missile silo."
	var/active = FALSE
	var/unlocked = FALSE
	var/destination = 0

/obj/structure/props/computerprops/tracking/siberiad/attack_hand(var/mob/living/human/H as mob)
	if (map && map.ID == MAP_SIBERIAD)
		var/obj/map_metadata/siberiad/SD = map
		if (src.active)
			to_chat(H, SPAN_WARNING("The nuclear missile has already been activated and calibrated."))
			return
		if (!src.unlocked)
			var/code = input(H, "Enter the activation code:", "Access Termninal") as num
			if (code != SD.activation_code)
				to_chat(H, SPAN_WARNING("\icon[src] Wrong password."))
				return
		src.visible_message(SPAN_NOTICE("\icon[src] Initiliazing protocols... Please wait."))
		spawn(100)
			src.visible_message(SPAN_WARNING("\icon[src] Security protocol terminated. Please insert the trajectory path disk."))
			src.unlocked = TRUE

/obj/structure/props/computerprops/tracking/siberiad/attackby(obj/item/O as obj, mob/living/human/user as mob)
	if (!istype(O, /obj/item/weapon/disk/siberiad))
		return
	if (src.active)
		to_chat(user, SPAN_WARNING("The nuclear missile has already been activated and calibrated."))
		return
	if (!unlocked)
		to_chat(user, SPAN_WARNING("Activate the console using the security code first."))
		return
	else
		if (istype(O, /obj/item/weapon/disk/siberiad/soviet))
			destination = 1
		else if (istype(O, /obj/item/weapon/disk/siberiad/nato))
			destination = 2
		src.visible_message(SPAN_NOTICE("\icon[src] Calibrating trajectory... Please wait."))
		spawn(100)
			src.active = TRUE
			src.visible_message(SPAN_WARNING("\icon[src] Nuclear missile activated."))
			switch(destination)
				if (1)
					src.visible_message(SPAN_WARNING("\icon[src] Target destination: SEATTLE <br>(LAT: 47.608013, LONG: -122.335167)."))
				if (2)
					src.visible_message(SPAN_WARNING("\icon[src] Target destination: NOVOSIBIRSK <br>(LAT: 55.018803, LONG: 82.933952)."))

/obj/item/weapon/disk/siberiad
	name = "ballistic trajectory diskette"
	desc = "A diskette containing protocols for setting up the ballistic trajectory a missile."
	icon_state = "disk_black"
	item_state = "disk_black"
	attackby(obj/item/W, mob/living/M)
		return

/obj/item/weapon/disk/siberiad/soviet
	name = "Soviet ballistic trajectory diskette"
	icon_state = "disk_red"
	item_state = "disk_red"

/obj/item/weapon/disk/siberiad/nato
	name = "Coalition ballistic trajectory diskette"
	icon_state = "disk_blue"
	item_state = "disk_blue"

/obj/item/weapon/paper/official/activation_code
	name = "confidential document"
	New()
		..()
		if (map && map.ID == MAP_SIBERIAD)
			var/obj/map_metadata/siberiad/SD = map
			info = "<p><strong>TOP SECRET</strong></p><br><p><em>Ministry of Defense of the USSR</em></p><br><p><strong>Activation code: [SD.activation_code]</strong></p><br><p><strong>Activation Instructions:</strong></p><br><ol><li>Enter the above code into the activation console.</li><br><li>Await verification protocols.</li><br><li>Once verified, insert the ballistic trajectory diskette.</li><br><li>Await missile calibration.</li><br><li>Initiate missile launch.</li><br></ol>"