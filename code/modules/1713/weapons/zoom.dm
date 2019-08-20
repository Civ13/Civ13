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
	attachment_type = ATTACH_SCOPE
	slot_flags = SLOT_POCKET|SLOT_BELT
	value = 15

/obj/item/weapon/attachment/scope/New()
	..()
	build_zooming()

/obj/item/weapon/attachment/scope/adjustable
	name = "generic adjustable scope"
	var/min_zoom = 3
	var/max_zoom = 3
	var/zooming = FALSE

/obj/item/weapon/attachment/scope/adjustable/New()
	..()
	zoom_amt = max_zoom // this really makes more sense IMO, 95% of people will just set it to the max - Kachnov

/obj/item/weapon/attachment/scope/adjustable/sniper_scope/zoom()
	..()
	if (A_attached)
		var/obj/item/weapon/gun/G = loc //loc is the gun this is attached to
//		var/zoom_offset = round(7 * zoom_amt)
		if (zoomed)
	/*		if (G.accuracy)
				G.accuracy = G.scoped_accuracy + zoom_offset*/
			if (G.recoil)
				G.recoil = round(G.recoil*(zoom_amt/5)+1) //recoil is worse when looking through a scope
		else
			G.accuracy = initial(G.accuracy)
			G.recoil = initial(G.recoil)

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

/obj/item/weapon/attachment/scope/adjustable/verb/adjust_scope_verb()
	set name = "Adjust Zoom"
	set category = null
	var/mob/living/carbon/human/user = usr
	if (istype(src, /obj/item/weapon/gun))
		var/obj/item/weapon/gun/G = src
		for (var/obj/item/weapon/attachment/scope/adjustable/A in G.attachments)
			src = A
	adjust_scope(user)

/obj/item/weapon/attachment/scope/adjustable/proc/adjust_scope(mob/living/carbon/human/user)

	if (!Adjacent(user))
		return

	if (zooming)
		return

	if (zoomed)
		zoom(user, 0)

	zooming = TRUE

	if (do_after(user, 7, src))

		zooming = FALSE

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

// An ugly hack called a boolean proc, made it like this to allow special
// behaviour without big overrides. So special snowflake weapons like the minigun
// can use zoom without overriding the original zoom proc.
//	user: user mob
//	devicename: name of what device you are peering through, set by zoom()
//	silent: boolean controlling whether it should tell the user why they can't zoom in or not
// I am sorry for creating this abomination -- Irra
/obj/item/weapon/attachment/scope/proc/can_zoom(mob/living/user, var/silent = FALSE)
	var/mob/living/carbon/human/H = user
	if (user.stat || !ishuman(user))
		if (!silent) user << "You are unable to focus through \the [src]."
		return FALSE
	if (H.wear_mask && istype(H.wear_mask, /obj/item/clothing/mask))
		var/obj/item/clothing/mask/currmask = H.wear_mask
		if (currmask.blocks_scope)
			if (!silent) user << "You can't use the [src] while wearing \the [currmask]!"
			return FALSE
	else if (global_hud.darkMask[1] in user.client.screen)
		if (!silent) user << "Your visor gets in the way of looking through \the [src]."
		return FALSE
	else if (!A_attached)
		if (user.client.pixel_x || user.client.pixel_y) //Keep people from looking through two scopes at once
			if (!silent) user << "You are too distracted to look through \the [src]."
			return FALSE
		if (user.get_active_hand() != src)
			if (!silent) user << "You are too distracted to look through \the [src]."
			return FALSE
	else if (user.get_active_hand() != loc)
		if (!silent) user << "You are too distracted to look through \the [src]."
		return FALSE
	else
		var/obj/item/organ/eyes/E = H.internal_organs_by_name["eyes"]
		if (E.is_bruised() || E.is_broken() || H.eye_blind > 0)
			if (!silent) user << "<span class = 'danger'>Your eyes are injured! You can't use \the [src].</span>"
			return FALSE
	return TRUE

/mob/living/var/next_zoom = -1
/mob/living/var/dizzycheck = FALSE

/obj/item/weapon/attachment/scope/proc/zoom(mob/living/user, forced_zoom, var/bypass_can_zoom = FALSE)

	if (!user || !user.client)
		return

	if (user.next_zoom > world.time)
		return

	user.next_zoom = world.time + 10

	switch(forced_zoom)
		if (FALSE)
			zoomed = FALSE
		if (TRUE)
			zoomed = TRUE
		else
			zoomed = !zoomed

	if (zoomed)
		if (!can_zoom(user) && !bypass_can_zoom)//Zoom checks
			zoomed = FALSE
			return
		else
			user.dizzycheck = TRUE
			if (do_after(user, 5, user, TRUE))//Scope delay
				var/_x = 0
				var/_y = 0
				switch(user.dir)
					if (NORTH)
						_y = zoom_amt
					if (EAST)
						_x = zoom_amt
					if (SOUTH)
						_y = -zoom_amt
					if (WEST)
						_x = -zoom_amt
				if (zoom_amt > world.view && user && user.client)//So we can still see the player at the edge of the screen if the zoom amount is greater than the world view
					var/view_offset = round((zoom_amt - world.view)/2, TRUE)
					user.client.view += view_offset
					switch(user.dir)
						if (NORTH)
							_y -= view_offset
						if (EAST)
							_x -= view_offset
						if (SOUTH)
							_y += view_offset
						if (WEST)
							_x += view_offset
					animate(user.client, pixel_x = world.icon_size*_x, pixel_y = world.icon_size*_y, 4, TRUE)
					animate(user.client, pixel_x = 0, pixel_y = 0)
					user.client.pixel_x = world.icon_size*_x
					user.client.pixel_y = world.icon_size*_y
				else // Otherwise just slide the camera
					animate(user.client, pixel_x = world.icon_size*_x, pixel_y = world.icon_size*_y, 4, TRUE)
					animate(user.client, pixel_x = 0, pixel_y = 0)
					user.client.pixel_x = world.icon_size*_x
					user.client.pixel_y = world.icon_size*_y
				user.visible_message("[user] peers through the [zoomdevicename ? "[zoomdevicename] of \the [name]" : "[name]"].")
			else
				zoomed = FALSE
	else //Resets everything
		user.client.pixel_x = 0
		user.client.pixel_y = 0
		user.client.view = world.view
		user.visible_message("[zoomdevicename ? "[user] looks up from \the [name]" : "[user] lowers \the [name]"].")

	if (zoomed)
		// prevent scopes from bugging out opened storage objs in mob process
		for (var/obj/item/weapon/storage/S in user.contents)
			S.close_all()
		for (var/obj/item/clothing/under/U in user.contents)
			for (var/obj/item/clothing/accessory/storage/S in U.accessories)
				S.hold.close_all()
		user.dizzycheck = TRUE
	else
		user.dizzycheck = FALSE

	if (user.aiming)
		user.aiming.update_aiming()

	// make other buttons invisible
	var/moved = 0
	if (ishuman(user))
		var/mob/living/carbon/human/H = user
		if (H.using_zoom())
			for (var/obj/screen/movable/action_button/AB in user.client.screen)
				if (AB.name == "Toggle Sights" && AB != azoom.button && azoom.button.screen_loc)
					AB.invisibility = 101
					if (azoom && azoom.button && findtext(azoom.button.screen_loc,":"))
						var/azoom_button_screenX = text2num(splittext(splittext(azoom.button.screen_loc, ":")[1], "+")[2])
						var/AB_screenX = text2num(splittext(splittext(AB.screen_loc, ":")[1], "+")[2])

						// see if we need to move this button left to compensate
						if (azoom_button_screenX > AB_screenX)
							++moved
					else if (azoom && azoom.button)
						var/azoom_button_screenX = text2num(splittext(azoom.button.screen_loc, ",")[1])
						var/AB_screenX = text2num(splittext(splittext(AB.screen_loc, ":")[1], "+")[2])

						// see if we need to move this button left to compensate
						if (azoom_button_screenX > AB_screenX)
							++moved
		else
			if (user && user.client)
				for (var/obj/screen/movable/action_button/AB in user.client.screen)
					if (AB.name == "Toggle Sights")
						AB.invisibility = 0

	// actually shift the button
	azoom.button.pixel_x = -(moved*32)
	azoom.button.UpdateIcon()

/datum/action/toggle_scope
	name = "Toggle Sights"
	check_flags = AB_CHECK_ALIVE|AB_CHECK_RESTRAINED|AB_CHECK_STUNNED|AB_CHECK_LYING
	button_icon_state = "sniper_zoom"
	var/obj/item/weapon/attachment/scope/scope = null
	var/boundto = null

/datum/action/toggle_scope/IsAvailable()
	. = ..()
	if (scope.zoomed)
		return FALSE

/datum/action/toggle_scope/Trigger()
	..()
	scope.zoom(owner)

/datum/action/toggle_scope/Remove(mob/living/L)
	if (scope.zoomed)
		scope.zoom(L, FALSE)
	..()

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

/mob/living/carbon/human/Move()
	..()
	handle_zooms_with_movement()

// resets zoom on movement
/mob/living/carbon/human/proc/handle_zooms_with_movement()

	if (client && actions.len)
		if (client.pixel_x || client.pixel_y) //Cancel currently scoped weapons
			for (var/datum/action/toggle_scope/T in actions)
				if (T.scope.zoomed && m_intent=="run")
					shake_camera(src, 2, rand(2,3))

	for (var/obj/item/weapon/gun/projectile/automatic/stationary/M in range(2, src))
		if (M.last_user == src && loc != get_turf(M))
			M.stopped_using(src)
			M.last_user = null
// reset all zooms - called from Life(), Weaken(), ghosting and more
/mob/living/carbon/human/proc/handle_zoom_stuff(var/forced = FALSE)

	var/success = FALSE

	if (stat == UNCONSCIOUS || stat == DEAD || forced)
		if (client && actions.len)
			if (client.pixel_x || client.pixel_y) //Cancel currently scoped weapons
				for (var/datum/action/toggle_scope/T in actions)
					if (T.scope.zoomed)
						T.scope.zoom(src, FALSE)
						success = TRUE

	for (var/obj/item/weapon/gun/projectile/automatic/stationary/M in range(2, src))
		if (M.last_user == src && (loc != get_turf(M) || forced))
			M.stopped_using(src)
			M.last_user = null
			success = TRUE

	if (success && client)
		client.pixel_x = 0
		client.pixel_y = 0
		client.view = world.view

/mob/living/carbon/human/proc/using_zoom()
	if (using_MG)
		return TRUE
	if (stat == CONSCIOUS)
		if (client && actions.len)
			if (client.pixel_x || client.pixel_y) //Cancel currently scoped weapons
				for (var/datum/action/toggle_scope/T in actions)
					if (T.scope.zoomed)
						return TRUE
	return FALSE


