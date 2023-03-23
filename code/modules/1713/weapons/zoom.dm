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
	desc = "A laser designator for marking airstrikes. <b>You have 5 airstrikes left.</b>"
	icon_state = "laser_designator"
	max_zoom = ZOOM_CONSTANT*4
	attachable = FALSE
	value = 15
	w_class = ITEM_SIZE_SMALL
	var/checking = FALSE
	var/airstrikes_remaining = 5
	var/delay = 20 SECONDS
	var/debounce = FALSE

/obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator/examine(mob/user)
	..()
	desc = "A laser designator for marking airstrikes. <b>You have [airstrikes_remaining] airstrikes left.</b>"

/obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator/proc/rangecheck(var/mob/living/human/H, var/atom/target)
	if (!checking)
		if (airstrikes_remaining > 0)
			if (debounce <= world.time)
				
				
				checking = TRUE
				var/dist1 = abs(H.x-target.x)
				var/dist2 = abs(H.y-target.y)
				var/distcon = max(dist1,dist2)
				var/gdir = get_dir(H, target)
				H << SPAN_DANGER("<big>You lasing the target, stay still...</big>")
				var/input = WWinput(H, "Strafe in what direction?", "Close Air Support", "Cancel", list("Cancle", "NORTH", "EAST", "SOUTH", "WEST"))
				if (input != "Cancel")
					if (do_after(H, 80, src, can_move = FALSE))
						H << "<big><b><font color='#ADD8E6'>Calling in airstrike: [distcon] meters [dir2text(gdir)].</font></b></big>"
						checking = FALSE

						var/turf/T = locate(target.x,target.y,target.z)
						airstrike(T,H,input)
						debounce = world.time + delay
					else
						H << "<big><b><font color='#ADD8E6'>Canceling airstrike.</font></b></big>"
						checking = FALSE
				else
					H << "<big><b><font color='#ADD8E6'>Canceling airstrike.</font></b></big>"
					return
			else
				H << "<big><b><font color='#ADD8E6'>Close Air Support is making their way back around, try again in [(debounce - world.time)/10] seconds.</font></b></big>"
				return
		else
			H << SPAN_DANGER("<big><b>Close Air Support is out of ammunition.</big></b>")
			return

/obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator/proc/airstrike(var/turf/T, mob/living/human/user as mob,var/direction)
	message_admins("[user.name] ([user.ckey]) called in an airstrike with \the [src] at ([T.x],[T.y],[T.z])(<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[T.x];Y=[T.y];Z=[T.z]'>JMP towards</a>)")
	log_game("[user.name] ([user.ckey]) called in an airstrike with \the [src] at ([T.x],[T.y],[T.z])(<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[T.x];Y=[T.y];Z=[T.z]'>JMP</a>)")
	airstrikes_remaining--
	var/strikenum = 5

	var/xoffset = 0
	var/yoffset = 0

	var/direction_xoffset = 0
	var/direction_yoffset = 0
	switch(user.faction_text)
		if ("DUTCH")
			new /obj/effect/plane_flyby/f16_no_message(T)
			world << SPAN_DANGER("<font size=4>The clouds open up as a F-16 cuts through and fires off a burst of rockets!</font>")
		if ("RUSSIAN")
			new /obj/effect/plane_flyby/su25_no_message(T)
			world << SPAN_DANGER("<font size=4>The clouds open up as a Su-25 cuts through and fires off a burst of rockets!</font>")
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
