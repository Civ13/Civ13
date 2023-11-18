/*
Should be used for all zoom mechanics
Parts of code courtesy of Super3222
*/

/obj/item/weapon/attachment/scope
	name = "generic scope"
	icon = 'icons/obj/device.dmi'
	icon_state = "telescope1"
	zoomdevicename = null
	var/zoom_amt = 3
	var/zoomed = FALSE
	var/datum/action/toggle_scope/azoom
	flammable = FALSE
	attachment_type = ATTACH_SCOPE
	slot_flags = SLOT_POCKET|SLOT_BELT|SLOT_ID
	value = 15

/obj/item/weapon/attachment/scope/Destroy()
	azoom = null
	..()

/obj/item/weapon/attachment/scope/New()
	..()
	build_zooming()

/obj/item/weapon/attachment/scope/adjustable
	name = "generic adjustable scope"
	var/min_zoom = 3
	var/max_zoom = 3
	var/looking = FALSE

/obj/item/weapon/attachment/scope/adjustable/New()
	..()
	zoom_amt = max_zoom // this really makes more sense IMO, 95% of people will just set it to the max - Kachnov

//Not actually an attachment
/obj/item/weapon/attachment/scope/adjustable/binoculars
	name = "telescope"
	desc = "A naval telescope."
	max_zoom = ZOOM_CONSTANT*3
	attachable = FALSE
	value = 15

/obj/item/weapon/attachment/scope/adjustable/binoculars/small
	name = "telescope"
	desc = "A small telescope."
	max_zoom = 10
	attachable = FALSE
	value = 15

/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars
	name = "binoculars"
	desc = "A pair of binoculars."
	icon_state = "binoculars"
	max_zoom = ZOOM_CONSTANT*3
	attachable = FALSE
	value = 15
	var/checking = FALSE

/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars/proc/rangecheck(var/mob/living/human/H, var/atom/target)
	if (checking)
		return
	if (!H.looking)
		return

	checking = TRUE
	var/dist1 = abs(H.x-target.x)
	var/dist2 = abs(H.y-target.y)
	var/distcon = max(dist1,dist2)
	var/gdir = get_dir(H, target)
	H << "You start checking the range..."
	if (do_after(H, 40, src, can_move = FALSE))
		H << "<big><b><font color='#ADD8E6'>Range: about [max(0,distcon+rand(-1,1))] meters [dir2text(gdir)]</font></b></big>"
		checking = FALSE
	else
		checking = FALSE

/obj/item/weapon/attachment/scope/adjustable/binoculars/periscope
	name = "periscope"
	desc = "A solid metal periscope."
	icon_state = "periscope"
	max_zoom = ZOOM_CONSTANT*3
	attachable = FALSE
	value = 15
	var/obj/structure/bed/chair/commander/commanderchair = null
	nothrow = TRUE
	nodrop = TRUE
	w_class = ITEM_SIZE_HUGE
	var/checking = FALSE

/obj/item/weapon/attachment/scope/adjustable/binoculars/periscope/naval
	name = "periscope"
	desc = "A solid metal periscope."
	icon_state = "periscope"
	max_zoom = ZOOM_CONSTANT*4

/obj/item/weapon/attachment/scope/adjustable/binoculars/periscope/proc/rangecheck(var/mob/living/human/H, var/atom/target)
	if (checking)
		return

	checking = TRUE
	var/dist1 = abs(H.x-target.x)
	var/dist2 = abs(H.y-target.y)
	var/distcon = max(dist1,dist2)
	var/gdir = get_dir(H, target)
	H << "You start checking the range..."
	if (do_after(H, 25, src, can_move = TRUE))
		H << "<big><b><font color='#ADD8E6'>Range: about [max(0,distcon+rand(-1,1))] meters [dir2text(gdir)].</font></b></big>"
		checking = FALSE
	else
		checking = FALSE

/obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator
	name = "laser designator"
	desc = "A laser designator for marking airstrikes."
	icon_state = "laser_designator"
	max_zoom = ZOOM_CONSTANT*4
	attachable = FALSE
	value = 15
	w_class = ITEM_SIZE_SMALL
	var/checking = FALSE
	var/aircraft_remaining
	var/airstrikes_remaining
	
	var/delay = 20 SECONDS
	var/debounce = FALSE

/obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator/examine(mob/user)
	..()
	if (ishuman(user))
		var/mob/living/human/H = user
		switch (H.faction_text) // Check how much jets and airstrikes they have left
			if (DUTCH)
				aircraft_remaining = faction1_aircraft_remaining
				airstrikes_remaining = faction1_airstrikes_remaining
			if (RUSSIAN)
				aircraft_remaining = faction2_aircraft_remaining
				airstrikes_remaining = faction2_airstrikes_remaining
			if (AMERICAN)
				aircraft_remaining = faction1_aircraft_remaining
				airstrikes_remaining = faction1_airstrikes_remaining
			if (BRITISH)
				aircraft_remaining = faction1_aircraft_remaining
				airstrikes_remaining = faction1_airstrikes_remaining
		to_chat(user, "<b>There are [aircraft_remaining] aircraft in your Area of Operations.</b>")
		to_chat(user, "<b>You have [airstrikes_remaining] airstrikes remaining.</b>")

/obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator/proc/rangecheck(var/mob/living/human/H, var/atom/target)
	if (map.ID == MAP_SYRIA && H.original_job.title != "Delta Force Operator")
		to_chat(H, "You don't know how to use this.")
		return
	else
		if (!checking)
			switch (H.faction_text) // Check how much jets and airstrikes they have left
				if (DUTCH)
					aircraft_remaining = faction1_aircraft_remaining
					airstrikes_remaining = faction1_airstrikes_remaining
				if (RUSSIAN)
					aircraft_remaining = faction2_aircraft_remaining
					airstrikes_remaining = faction2_airstrikes_remaining
				if (AMERICAN)
					aircraft_remaining = faction1_aircraft_remaining
					airstrikes_remaining = faction1_airstrikes_remaining
				if (BRITISH)
					aircraft_remaining = faction1_aircraft_remaining
					airstrikes_remaining = faction1_airstrikes_remaining
			if (aircraft_remaining > 0)
				if (airstrikes_remaining > 0)
					if (debounce <= world.time) // Cooldown
						checking = TRUE
						var/dist1 = abs(H.x-target.x)
						var/dist2 = abs(H.y-target.y)
						var/distcon = max(dist1,dist2)
						var/gdir = get_dir(H, target)
						to_chat(H, SPAN_DANGER("<big>You lasing the target, stay still...</big>"))
						var/input = WWinput(H, "Strafe in what direction?", "Close Air Support", "Cancel", list("Cancel", "NORTH", "EAST", "SOUTH", "WEST"))
						if (input != "Cancel")
							if (do_after(H, 1.5 SECONDS, src, can_move = FALSE))
								to_chat(H, "<big><b><font color='#ADD8E6'>Calling in airstrike: [distcon] meters [dir2text(gdir)].</font></b></big>")
								checking = FALSE

								var/turf/T = locate(target.x,target.y,target.z)
								try_airstrike(T, H, input)
								debounce = world.time + delay
							else
								to_chat(H, "<big><b><font color='#ADD8E6'>Canceling airstrike.</font></b></big>")
								checking = FALSE
								return
						else
							to_chat(H, "<big><b><font color='#ADD8E6'>Canceling airstrike.</font></b></big>")
							checking = FALSE
							return
					else
						to_chat(H, "<big><b><font color='#ADD8E6'>Close Air Support is making their way back around, try again in [(debounce - world.time)/10] seconds.</font></b></big>")
						return
				else
					to_chat(H, SPAN_DANGER("<big><b>All avaliable aircraft are out of ammunition.</big></b>"))
					return
			else
				to_chat(H, SPAN_DANGER("<big><b>There are no more avaliable aircraft in your Area of Operations.</big></b>"))
				return

/obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator/proc/try_shoot_down_aircraft(var/turf/T, mob/living/human/user as mob, var/direction, var/aircraft_name = "Unknown Aircraft")
	spawn(8 SECONDS)
		var/sound/sam_sound = sound('sound/effects/aircraft/sa6_sam_site.ogg', repeat = FALSE, wait = FALSE, channel = 777)
		sam_sound.priority = 250
		for (var/mob/M in player_list)
			if (!new_player_mob_list.Find(M))
				to_chat(M, SPAN_DANGER("<big>A SAM site fires at the [aircraft_name]!</big>"))
				M.client << sam_sound
		spawn(5 SECONDS)
			if (prob(95)) // Shoot down the jet
				var/sound/uploaded_sound = sound((pick('sound/effects/aircraft/effects/metal1.ogg','sound/effects/aircraft/effects/metal2.ogg')), repeat = FALSE, wait = FALSE, channel = 777)
				uploaded_sound.priority = 250
				for (var/mob/M in player_list)
					if (!new_player_mob_list.Find(M))
						to_chat(M, SPAN_DANGER("<big>The SAM directly hits the [aircraft_name], shooting it down!</big>"))
						if (M.client)
							M.client << uploaded_sound
				
				switch (user.faction_text)
					if (DUTCH)
						faction1_aircraft_remaining--
					if (RUSSIAN)
						faction2_aircraft_remaining--
					if (AMERICAN)
						faction1_aircraft_remaining--
					if (BRITISH)
						faction1_aircraft_remaining--
				message_admins("[map.roundend_condition_def2name(user.faction_text)] Aircraft [aircraft_name] has been shot down.")
				log_game("Aircraft [aircraft_name] has been shot down.")
				return
			else // Evade the Anti-Air
				var/sound/uploaded_sound = sound((pick('sound/effects/aircraft/effects/missile1.ogg','sound/effects/aircraft/effects/missile2.ogg')), repeat = FALSE, wait = FALSE, channel = 777)
				uploaded_sound.priority = 250
				for (var/mob/M in player_list)
					if (!new_player_mob_list.Find(M))
						to_chat(M, SPAN_NOTICE("<big><b>The SAM misses the [aircraft_name]!</b></big>"))
						if (M.client)
							M.client << uploaded_sound
				airstrike(T, user, direction, aircraft_name)

/obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator/proc/try_airstrike(var/turf/T, mob/living/human/user as mob, var/direction)
	message_admins("[user.ckey] ([user.faction_text]) called in an airstrike with \the [src] at ([T.x],[T.y],[T.z])(<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[T.x];Y=[T.y];Z=[T.z]'>JMP towards</a>)", user.ckey)
	log_game("[user.ckey] ([user.faction_text]) called in an airstrike with \the [src] at ([T.x],[T.y],[T.z])(<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[T.x];Y=[T.y];Z=[T.z]'>JMP</a>)")
	switch (user.faction_text)
		if (DUTCH)
			faction1_airstrikes_remaining--
		if (RUSSIAN)
			faction2_airstrikes_remaining--
		if (AMERICAN)
			faction1_airstrikes_remaining--
		if (BRITISH)
			faction1_airstrikes_remaining--

	var/aircraft_name
	switch(user.faction_text)
		if (DUTCH)
			new /obj/effect/plane_flyby/f16_no_message(T)
			aircraft_name = "F-16"
		if (RUSSIAN)
			new /obj/effect/plane_flyby/su25_no_message(T)
			aircraft_name = "Su-25"
		if (AMERICAN)
			new /obj/effect/plane_flyby/f16_no_message(T)
			aircraft_name = "F-16"
	to_chat(world, SPAN_DANGER("<font size=4>The clouds open up as a [aircraft_name] cuts through.</font>"))
	
	var/anti_air_in_range = FALSE
	for (var/obj/structure/milsim/anti_air/AA in range(60, T))
		if (AA.faction_text != user.faction_text)
			anti_air_in_range++
	if (anti_air_in_range)
		try_shoot_down_aircraft(T, user, direction, aircraft_name)
	else
		airstrike(T, user, direction, aircraft_name)
	return

/obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator/proc/airstrike(var/turf/T, mob/living/human/user as mob, var/direction, var/aircraft_name = "Unknown Aircraft")
	var/strikenum = 5

	var/xoffset = 0
	var/yoffset = 0

	var/direction_xoffset = 0
	var/direction_yoffset = 0

	to_chat(world, SPAN_DANGER("<font size=4>And fires off a burst of rockets!</font>"))
	
	spawn(15)
		for (var/i = 1, i <= strikenum, i++)
			switch (direction)
				if ("NORTH")
					direction_yoffset += 3
					xoffset = rand(-2,2)
					yoffset = rand(0,1)
				if ("EAST")
					direction_xoffset += 3
					xoffset = rand(0,1)
					yoffset = rand(-2,2)
				if ("SOUTH")
					direction_yoffset -= 3
					xoffset = rand(-2,2)
					yoffset = rand(0,1)
				if ("WEST")
					direction_xoffset -= 3
					xoffset = rand(0,1)
					yoffset = rand(-2,2)
			spawn(i*8)
				explosion(locate((T.x + xoffset + direction_xoffset),(T.y + yoffset + direction_yoffset),T.z),0,1,5,3,sound='sound/weapons/Explosives/FragGrenade.ogg')

/obj/item/weapon/attachment/scope/adjustable/verb/adjust_scope_verb()
	set name = "Adjust Zoom"
	set category = null
	var/mob/living/human/user = usr
	if (istype(src, /obj/item/weapon/gun))
		var/obj/item/weapon/gun/G = src
		for (var/obj/item/weapon/attachment/scope/adjustable/A in G.attachments)
			src = A
	adjust_scope(user)

/obj/item/weapon/attachment/scope/adjustable/proc/adjust_scope(mob/living/human/user)

	if (!Adjacent(user))
		return

	if (looking)
		return

	if (user.looking)
		user.look_into_distance(user, 0)

	looking = TRUE

	if (do_after(user, 7, src))

		looking = FALSE

		var/input = input(user, "Set the zoom amount.", "Zoom" , "") as num
		if (input == zoom_amt)
			return

		var/dial_check = FALSE

		if (input > max_zoom)
			if (zoom_amt == max_zoom)
				user << "<span class='warning'>You can't adjust it any further.</span>"
				return
			else
				zoom_amt = max_zoom
				dial_check = TRUE
		else if (input < min_zoom)
			if (zoom_amt == min_zoom)
				user << "<span class='warning'>You can't adjust it any further.</span>"
				return
			else
				zoom_amt = min_zoom
		else
			if (input > zoom_amt)
				dial_check = TRUE
			zoom_amt = input

		user << "<span class='notice'>You twist the dial on [src] [dial_check ? "clockwise, increasing" : "counterclockwise, decreasing"] the zoom range to [zoom_amt].</span>"

//Proc, so that gun accessories/scopes/etc. can easily add zooming.
/obj/item/weapon/attachment/scope/proc/build_zooming()
	azoom = new()
	azoom.scope = src
	actions += azoom

/obj/item/weapon/attachment/scope/on_enter_storage(S)
	..(S)
	if (azoom)
		azoom.Remove(azoom.owner)

/obj/item/weapon/attachment/scope/on_changed_slot()
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

/obj/item/weapon/attachment/scope/dropped(mob/user)
	..()
	if (azoom)
		azoom.Remove(user)
