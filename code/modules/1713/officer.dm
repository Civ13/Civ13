//ARTILLERY

#define kanonier_msg " Artillery, airstrikes and supplies can now be requested within <b>15 square meters</b> of this position."

var/global/list/valid_coordinates = list()
/mob/living/carbon/human/var/checking_coords[4]
/mob/living/carbon/human/var/can_check_distant_coordinates = FALSE

/mob/living/carbon/human/proc/make_artillery_officer()
	verbs += /mob/living/carbon/human/proc/Check_Coordinates
	verbs += /mob/living/carbon/human/proc/Reset_Coordinates
	can_check_distant_coordinates = TRUE

/mob/living/carbon/human/proc/make_artillery_scout()
	verbs += /mob/living/carbon/human/proc/Check_Coordinates_Chump
	verbs += /mob/living/carbon/human/proc/Reset_Coordinates_Chump
	can_check_distant_coordinates = TRUE

/mob/living/carbon/human/proc/make_artillery_radioman()
	verbs += /mob/living/carbon/human/proc/order_airstrike

/mob/living/carbon/human/proc/make_commander()
	verbs += /mob/living/carbon/human/proc/Commander_Announcement

/mob/living/carbon/human/proc/remove_commander()
	verbs -= /mob/living/carbon/human/proc/Commander_Announcement


/mob/living/carbon/human/proc/make_title_changer()
	verbs += /mob/living/carbon/human/proc/Add_Title
	verbs += /mob/living/carbon/human/proc/Remove_Title

/mob/living/carbon/human/proc/remove_title_changer()
	verbs -= /mob/living/carbon/human/proc/Add_Title
	verbs -= /mob/living/carbon/human/proc/Remove_Title


/proc/check_coords_check()
	return (!map || map.faction2_can_cross_blocks() || map.faction1_can_cross_blocks())
/mob/living/carbon/human/proc/Commander_Announcement()
	set category = "Officer"
	set name = "Faction Announcement"
	set desc="Announce to everyone in your faction."
	var/messaget = "Governor Announcement"
	var/message = russian_to_cp1251(input("Global message to send:", "IC Announcement", null, null))  as message
	if (message)
		message = sanitize(message, 500, extra = FALSE)
		message = replacetext(message, "\n", "<br>") // required since we're putting it in a <p> tag
	for (var/mob/living/carbon/human/M)
		if (!map.civilizations || map.ID == MAP_TRIBES)
			if (faction_text == M.faction_text)
				messaget = "[name] announces:"
				M.show_message("<big><span class=notice><b>[messaget]</b></big><p style='text-indent: 50px'>[message]</p></span>", 2)
			log_admin("Governor Announcement: [key_name(usr)] - [messaget] : [message]")
		else
			if (civilization == M.civilization && civilization != "none" && world.time > announcement_cooldown)
				messaget = "[name] announces:"
				M.show_message("<big><span class=notice><b>[messaget]</b></big><p style='text-indent: 50px'>[message]</p></span>", 2)
	announcement_cooldown = world.time+1800
	log_admin("Faction Announcement: [key_name(usr)] - [messaget] : [message]")

/mob/living/carbon/human/proc/Check_Coordinates()
	set category = "Officer"
	if (!check_coords_check())
		usr << "<span class = 'warning'>You can't use this yet.</span>"
		return
	if (checking_coords[1] && checking_coords[2])
		checking_coords[3] = x
		checking_coords[4] = y
		valid_coordinates["[x],[y]"] = TRUE
		var/dist = "[checking_coords[3] - checking_coords[1]],[checking_coords[4] - checking_coords[2]]"
		usr << "<span class = 'notice'>You finished tracking coordinates at <b>[x],[y]</b>. You moved an offset of <b>[dist]</b>.[kanonier_msg]</span>"
		checking_coords[3] = null
		checking_coords[4] = null // continue to track from the same starting location
	else
		checking_coords[1] = x
		checking_coords[2] = y
		usr << "<span class = 'notice'>You've started checking coordinates at <b>[x], [y]</b>.</span>"

/mob/living/carbon/human/proc/Reset_Coordinates()
	set category = "Officer"
	if (!check_coords_check())
		usr << "<span class = 'warning'>You can't use this yet.</span>"
		return
	if (checking_coords[1] && checking_coords[2])
		var/x = checking_coords[1]
		var/y = checking_coords[2]
		checking_coords[1] = null
		checking_coords[2] = null
		usr << "<span class = 'notice'>You are no longer tracking from <b>[x],[y]</b>.</span>"
		checking_coords[3] = null
		checking_coords[4] = null

// the only thing different about these verbs is the category

/mob/living/carbon/human/proc/Check_Coordinates_Chump()
	set category = "Scout"
	set name = "Check Coordinates"
	if (!check_coords_check())
		usr << "<span class = 'warning'>You can't use this yet.</span>"
		return
	if (checking_coords[1] && checking_coords[2])
		checking_coords[3] = x
		checking_coords[4] = y
		valid_coordinates["[x],[y]"] = TRUE
		var/dist = "[checking_coords[3] - checking_coords[1]],[checking_coords[4] - checking_coords[2]]"
		usr << "<span class = 'notice'>You finished tracking coordinates at <b>[x],[y]</b>. You moved an offset of <b>[dist]</b>.[kanonier_msg]</span>"
		checking_coords[3] = null
		checking_coords[4] = null // continue to track from the same starting location
	else
		checking_coords[1] = x
		checking_coords[2] = y
		usr << "<span class = 'notice'>You've started checking coordinates at <b>[x],[y]</b>.</span>"

/mob/living/carbon/human/proc/Reset_Coordinates_Chump()
	set category = "Scout"
	set name = "Reset Coordinates"
	if (!check_coords_check())
		usr << "<span class = 'warning'>You can't use this yet.</span>"
		return
	if (checking_coords[1] && checking_coords[2])
		var/x = checking_coords[1]
		var/y = checking_coords[2]
		checking_coords[1] = null
		checking_coords[2] = null
		usr << "<span class = 'warning'>You are no longer tracking from <b>[x],[y]</b>.</span>"
		checking_coords[3] = null
		checking_coords[4] = null

// artyman/officer/scout getting coordinates
/mob/living/carbon/human/RangedAttack(var/turf/t)
	if (checking_coords[1] && istype(t))
		if (can_check_distant_coordinates && get_turf(src) != t)
			var/offset_x = t.x - x
			var/offset_y = t.y - y
			src << "<span class = 'notice'>This turf has an offset of <b>[offset_x],[offset_y]</b> and coordinates of <b>[t.x],[t.y]</b>.[kanonier_msg]</span>"
			valid_coordinates["[t.x],[t.y]"] = TRUE
	else
		return ..()

//OTHER



/mob/living/carbon/human/proc/order_airstrike()
	set category = "Officer"
	set name = "Order Airstrike"
	var/icon/radio
	var/currfreq = 0
	for (var/obj/structure/radio/R in range(1,src))
		if (!radio)
			radio = getFlatIcon(R)
			currfreq = R.freq
	for (var/obj/item/weapon/radio/R in range(1,src))
		if (!radio)
			radio = getFlatIcon(R)
			currfreq = R.freq
	if (currfreq == 0)
		src << "<span class='notice'>There is no radio nearby! You need one to order an airstrike.</span>"
		return
	if (map.artillery_count > 0 && world.time >= map.artillery_last+map.artillery_timer)
		var/list/validchoices = map.valid_artillery
		var/valid_coords_check = FALSE
		validchoices += "Cancel"
		var/input1 = WWinput(src, "Which type of airstrike to request?", "Order Airstrike", "Cancel", validchoices)
		if (input1 == "Cancel")
			return
		else
			var/inputx = input(src, "Choose the X coordinate:") as num
			if (inputx > world.maxx)
				inputx = world.maxx
			if (inputx < 0)
				inputx = 1
			var/inputy = input(src, "Choose the Y coordinate:") as num
			if (inputy > world.maxy)
				inputy = world.maxy
			if (inputy < 0)
				inputy = 1
			if (global.valid_coordinates.Find("[inputx],[inputy]"))
				valid_coords_check = TRUE
			else
				for (var/coords in global.valid_coordinates)
					var/splitcoords = splittext(coords, ",")
					var/coordx = text2num(splitcoords[1])
					var/coordy = text2num(splitcoords[2])
					if (abs(coordx - inputx) <= 15)
						if (abs(coordy - inputy) <= 15)
							valid_coords_check = TRUE
			if (!valid_coords_check)
				src << "\icon[radio] <font size=2 color=#FFAE19><b>Air Force Command, [currfreq]kHz:</font></b><font size=2]> <span class = 'small_message'>([default_language.name])</span> \"Negative, [name], I repeat, negative. Those coordinates were not reported by a scout or officer. Over.\"</font>"
				return
			for (var/mob/living/carbon/human/friendlies in range(7, locate(inputx,inputy,src.z)))
				if (friendlies.faction_text == faction_text && friendlies.stat != DEAD)
					src << "\icon[radio] <font size=2 color=#FFAE19><b>Air Force Command, [currfreq]kHz:</font></b><font size=2]> <span class = 'small_message'>([default_language.name])</span> \"Negative, [name], I repeat, negative. Friendlies in the area. Choose another area. Over.\"</font>"
					return
			src << "\icon[radio] <font size=2 color=#FFAE19><b>Air Force Command, [currfreq]kHz:</font></b><font size=2> <span class = 'small_message'>([default_language.name])</span> \"Roger, [name], [input1] bombing run underway on [inputx],[inputy]. Stay clear. Over.\"</font>"
			map.artillery_count--
			map.artillery_last = world.time
			spawn(rand(15,25)*10)
				airstrike(input1,inputx,inputy,src.z)
			message_admins("[key_name_admin(src)] ordered an [input1] airstrike at ([inputx],[inputy],[src.z]).")
			log_game("[key_name_admin(src)] ordered an [input1] airstrike at ([inputx],[inputy],[src.z]).")
			return
	else if (map.artillery_count <= 0)
		map.artillery_count = 0
		src << "<span class='warning'>There are no more airstrikes available.</span>"
		return
	else if (world.time < map.artillery_last+map.artillery_timer)
		src << "<span class='warning'>You can't order an airstrike yet! Wait [round(((map.artillery_last+map.artillery_timer)-world.time)/600)] minutes.</span>"
		return

/mob/living/carbon/human/proc/airstrike(var/type, var/inputx, var/inputy, var/inputz)
	var/turf/T = get_turf(locate(inputx,inputy,inputz))
	if (!T)
		return
	if (type == "White Phosphorus")
		new/obj/effect/effect/smoke/chem/payload/white_phosphorus_gas(T)
	else if (type == "Explosive")
		var/xoffsetmin = inputx-6
		var/xoffsetmax = inputx+6
		var/yoffsetmin = inputy-6
		var/yoffsetmax = inputy+6
		for (var/i = 1, i < 6, i++)
			var/turf/O = get_turf(locate(rand(xoffsetmin,xoffsetmax),rand(yoffsetmin,yoffsetmax),inputz))
			explosion(O,1,1,3,1)
	else if (type == "Napalm")
		var/xoffsetmin = inputx-7
		var/xoffsetmax = inputx+7
		var/yoffsetmin = inputy-7
		var/yoffsetmax = inputy+7
		for (var/i = 1, i < 6, i++)
			var/turf/O = get_turf(locate(rand(xoffsetmin,xoffsetmax),rand(yoffsetmin,yoffsetmax),inputz))
			explosion(O,0,1,1,3)
			for (var/mob/living/LS1 in O)
				LS1.adjustFireLoss(35)
				LS1.fire_stacks += rand(8,10)
				LS1.IgniteMob()
			new/obj/effect/burning_oil(O)
		spawn(10)
			xoffsetmin = inputx-4
			xoffsetmax = inputx+4
			yoffsetmin = inputy-4
			yoffsetmax = inputy+4
			for (var/i = 1, i < 18, i++)
				var/turf/O = get_turf(locate(rand(xoffsetmin,xoffsetmax),rand(yoffsetmin,yoffsetmax),inputz))
				for (var/mob/living/LS1 in O)
					LS1.adjustFireLoss(14)
					LS1.fire_stacks += rand(2,4)
					LS1.IgniteMob()
				new/obj/effect/burning_oil(O)