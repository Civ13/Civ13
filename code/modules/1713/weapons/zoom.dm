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
	var/mount = "none"
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
	max_zoom = 75

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
	var/needs_instruments = FALSE

	var/attack_direction = "NORTH"
	var/list/attack_direction_list = list("NORTH", "EAST", "SOUTH", "WEST")

	var/payload = null
	var/list/payload_list = list("Rockets")

	var/payload_remaining

	var/call_in_time = 3 SECONDS
	var/cooldown = 30 SECONDS
	var/debounce = FALSE

/obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator/binoculars
	name = "binocular designator"
	desc = "A pair of binoculars for calling in airstrikes."
	icon_state = "binoculars"
	needs_instruments = TRUE

	call_in_time = 5 SECONDS
	cooldown = 1 MINUTE
	payload_list = list("50 kg Bomb", "250 kg Bomb")

/obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator/proc/get_faction_aircraft(var/mob/living/human/H)
	var/aircraft_name
	switch (H.faction_text) // Check what faction has called in the airstrike and select an aircraft.
		if (DUTCH)
			aircraft_name = "F-16"
		if (GERMAN)
			if (map.ordinal_age == 6)
				aircraft_name = "Ju 87 Stuka"
			else
				return
		if (AMERICAN)
			if (map.ordinal_age == 6)
				aircraft_name = "P-47"
			else
				aircraft_name = "F-16"
		if (RUSSIAN)
			if (map.ordinal_age == 6)
				aircraft_name = "IL-2"
			else
				aircraft_name = "Su-25"
	return aircraft_name

// Check which faction is using the designator
/obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator/proc/get_faction_num(var/mob/living/human/H)
	var/faction_num
	if (map.faction1 == H.faction_text)
		faction_num = 1
	else if (map.faction2 == H.faction_text)
		faction_num = 2
	return faction_num

// Payload class defines how many times this payload can be used before it needs to re-arm. See global_lists.dm for details
/obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator/proc/get_payload_class()
	var/payload_class
	switch (payload)
		if ("Rockets")
			payload_class = 1
		if ("50 kg Bomb")
			payload_class = 2
		if ("250 kg Bomb")
			payload_class = 3
	return payload_class

/obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator/examine(mob/user)
	..()
	if (ishuman(user))
		var/mob/living/human/H = user
		if (get_faction_num(H) && get_faction_aircraft(H))
			if (payload)
				switch (get_faction_num(H)) // Check how much jets and airstrikes they have left
					if (1)
						payload_remaining = faction1_airstrikes_remaining[get_payload_class()]
					if (2)
						payload_remaining = faction2_airstrikes_remaining[get_payload_class()]

			to_chat(H, "<b>Attack direction: <red>[attack_direction ? attack_direction : "None selected"]</red></b>")
			to_chat(H, "<b>Payload type: <red>[payload ? payload : "None selected"]</red></b>")
			to_chat(H, "<b>Payload type remaining: <red>[payload ? payload_remaining : "None selected"]</red></b>")
		else // Failsafe for if a faction that does not have a jet or a faction which is not defined uses a designator
			to_chat(H, SPAN_DANGER("<b>There's no friendly CAS that you can call in.</b>"))

/obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator/attack_self(var/mob/living/human/H)
	var/selection_type = WWinput(H, "What do you want to change?", "Category selection", "Attack direction", list("Attack direction", "Payload type"))
	var/selection_list
	switch (selection_type)
		if ("Attack direction")
			selection_list = attack_direction_list + "Cancel"
			attack_direction = WWinput(H, "Set attack direction", "Close Air Support", "Cancel", selection_list)
		if ("Payload type")
			selection_list = payload_list + "Cancel"
			payload = WWinput(H, "Set payload", "Close Air Support", "Cancel", selection_list)
	return

/obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator/proc/rangecheck(var/mob/living/human/H, var/atom/target)
	if(!ishuman(H))	return
	if(map.ID == MAP_SYRIA && H.original_job.title != "Delta Force Operator")
		to_chat(H, "You don't know how to use this.")
		return
	else
		if (!checking)
			if (get_faction_num(H) && get_faction_aircraft(H))
				if (payload)
					var/payload_class = get_payload_class()
					switch (get_faction_num(H)) // Check how long the cooldown is and how many airstrikes the faction has left
						if(1)
							debounce = faction1_aircraft_cooldown
							payload_remaining = faction1_airstrikes_remaining[payload_class]
						if (2)
							debounce = faction2_aircraft_cooldown
							payload_remaining = faction2_airstrikes_remaining[payload_class]

					if(debounce <= world.time) // Check if time is further than the cooldown
						switch (get_faction_num(H)) // Re-arm the jet if it was re-arming and came off cooldown
							if (1)
								if (faction1_aircraft_rearming)
									faction1_aircraft_rearming = FALSE
									faction1_airstrikes_remaining = faction1_airstrikes_max
									payload_remaining = faction1_airstrikes_remaining[payload_class]
							if (2)
								if (faction2_aircraft_rearming)
									faction2_aircraft_rearming = FALSE
									faction2_airstrikes_remaining = faction2_airstrikes_max
									payload_remaining = faction2_airstrikes_remaining[payload_class]

						if (payload_remaining > 0) // If they have payloads remaining continue, otherwise make them re-arm
							checking = TRUE
							var/distcon = max(abs(H.x-target.x),abs(H.y-target.y))
							var/gdir = get_dir(H, target)
							to_chat(H, SPAN_DANGER("<big>You begin calling in the target, stay still...</big>"))

							if (do_after(H, call_in_time, src, can_move = FALSE))
								to_chat(H, "<big><b><font color='#ADD8E6'>Calling in airstrike: [distcon] meters [dir2text(gdir)].</font></b></big>")
								checking = FALSE

								var/turf/T = locate(target.x, target.y, target.z)
								T.try_airstrike(H.ckey, H.faction_text, get_faction_aircraft(H), attack_direction, payload, get_payload_class())

								switch (get_faction_num(H)) // Apply cooldown
									if (1)
										faction1_aircraft_cooldown = world.time + cooldown
									if (2)
										faction2_aircraft_cooldown = world.time + cooldown
							else
								to_chat(H, "<big><b><font color='#ADD8E6'>Canceling airstrike.</font></b></big>")
								checking = FALSE
								return
						else
							to_chat(H, SPAN_WARNING("<big><b>Calling CAS to re-arm, stay still...</b></big>"))
							if (do_after(H, 5 SECONDS, src, can_move = FALSE))
								switch (get_faction_num(H)) // Switch CAS to re-arms
									if (1)
										faction1_aircraft_rearming = TRUE
										faction1_aircraft_cooldown = world.time + 5 MINUTES
										to_chat(H, "<big><b><font color='#ADD8E6'>CAS now re-arming, it'll be back in [ceil((faction1_aircraft_cooldown - world.time)/10)/60] minutes.</font></b></big>")
									if (2)
										faction2_aircraft_rearming = TRUE
										faction2_aircraft_cooldown = world.time + 5 MINUTES
										to_chat(H, "<big><b><font color='#ADD8E6'>CAS now re-arming, it'll be back in [ceil((faction2_aircraft_cooldown - world.time)/10)/60] minutes.</font></b></big>")
						return
					else
						switch (get_faction_num(H))
							if (1)
								to_chat(H, "<big><b><font color='#ADD8E6'>CAS is [faction1_aircraft_rearming ? "re-arming" : "making their way back around"], try again in [ceil((faction1_aircraft_cooldown - world.time)/10)] seconds.</font></b></big>")
							if (2)
								to_chat(H, "<big><b><font color='#ADD8E6'>CAS is [faction2_aircraft_rearming ? "re-arming" : "making their way back around"], try again in [ceil((faction2_aircraft_cooldown - world.time)/10)] seconds.</font></b></big>")
						return
				else
					to_chat(H, SPAN_DANGER("<big><b>Select a payload first.</b></big>"))
					return
			else
				to_chat(H, SPAN_DANGER("<big><b>There's no friendly CAS that you can call in.</b></big>"))
				return

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
