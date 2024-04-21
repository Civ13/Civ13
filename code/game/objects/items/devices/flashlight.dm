/obj/item/flashlight
	name = "flashlight"
	desc = "A hand-held emergency light."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "flashlight_off"
	var/off_state = "flashlight_off"
	var/on_state = "flashlight_on"
	item_state = "flashlight"
	w_class = ITEM_SIZE_SMALL
	flags = CONDUCT
	slot_flags = SLOT_BELT
	flags = CONDUCT

	var/on = FALSE
	var/brightness_on = 5 //luminosity when on
	var/turn_on_sound = 'sound/effects/Custom_flashlight.ogg'
	var/fuel = 600 // 10 mins
	var/cooloff = 0
	var/unlimited = FALSE

/obj/item/flashlight/initialize()
	..()
	update_icon()

/obj/item/flashlight/update_icon()
	if (on)
		icon_state = on_state
		set_light(brightness_on)
	else
		icon_state = off_state
		set_light(0)

/obj/item/flashlight/attack_self(mob/user)
	if (!isturf(user.loc))
		user << "You cannot turn the light on while in this [user.loc]." //To prevent some lighting anomalities.
		return FALSE
	on = !on
	playsound(src, turn_on_sound, 75, TRUE)
	update_icon()
	return TRUE


/obj/item/flashlight/attack(mob/living/human/M as mob, mob/user as mob)
	add_fingerprint(user)
	if (istype(src, /obj/item/flashlight/torch) && user.a_intent == I_HARM)
		if (on && world.time > cooloff)
			M.adjustBurnLoss(rand(7,10))
			user.visible_message("<span class='notice'>\The [user] hits [M] with the [src]!</span>", "<span class='notice'>You hit [M] with the [src]!</span>")
			user.do_attack_animation(M)
			if (prob(5))
				M.fire_stacks += 1
			M.IgniteMob()
			playsound(src, 'sound/weapons/thudswoosh.ogg', 75, TRUE)
			cooloff = world.time+10
			return

	if (on && user.targeted_organ == "eyes")

		var/mob/living/human/H = M	//mob has protective eyewear
		if (istype(H))
			for (var/obj/item/clothing/C in list(H.head,H.wear_mask))
				if (istype(C) && (C.body_parts_covered & EYES))
					user << "<span class='warning'>You're going to need to remove [C.name] first.</span>"
					return

			var/obj/item/organ/vision
			if (H.species.vision_organ)
				vision = H.internal_organs_by_name[H.species.vision_organ]
			if (!vision)
				user << "<span class='warning'>You can't find any [H.species.vision_organ ? H.species.vision_organ : "eyes"] on [H]!</span>"

			user.visible_message("<span class='notice'>\The [user] directs [src] to [M]'s eyes.</span>", \
							 	 "<span class='notice'>You direct [src] to [M]'s eyes.</span>")
			if (H == user)	//can't look into your own eyes buster
				if (M.stat == DEAD || M.blinded)	//mob is dead or fully blind
					user << "<span class='warning'>\The [M]'s pupils do not react to the light!</span>"
					return
				if (vision.damage)
					user << "<span class='warning'>There's visible damage to [M]'s [vision.name]!</span>"
				else if (M.eye_blurry)
					user << "<span class='notice'>\The [M]'s pupils react slower than normally.</span>"
				if (M.getBrainLoss() > 15)
					user << "<span class='notice'>There's visible lag between left and right pupils' reactions.</span>"

				var/list/pinpoint = list("oxycodone"=1,"tramadol"=5)
				var/list/dilating = list("peyote"=5,"mindbreaker"=1)
				if (M.reagents.has_any_reagent(pinpoint) || H.ingested.has_any_reagent(pinpoint))
					user << "<span class='notice'>\The [M]'s pupils are already pinpoint and cannot narrow any more.</span>"
				else if (M.reagents.has_any_reagent(dilating) || H.ingested.has_any_reagent(dilating))
					user << "<span class='notice'>\The [M]'s pupils narrow slightly, but are still very dilated.</span>"
				else
					user << "<span class='notice'>\The [M]'s pupils narrow.</span>"

			user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN) //can be used offensively
			if (M.HUDtech.Find("flash"))
				flick("flash", M.HUDtech["flash"])
	else

		return ..()


// FLARES

/obj/item/flashlight/flare
	name = "flare"
	desc = "A red flare. There are instructions on the side reading 'pull cord, make light'. Lasts for about 5 minutes."
	brightness_on = 4 // Pretty bright.
	light_power = 2
	light_color = "#e58775"
	icon_state = "flare"
	item_state = "flare"
	turn_on_sound = 'sound/effects/Custom_flare.ogg'
	fuel = 0
	slot_flags = SLOT_POCKET|SLOT_BELT

	var/burnt_out = FALSE
	var/projectile_type  = /obj/item/flashlight/flare/on

	var/show_flame = TRUE
	var/flame_tint = "#ffcccc"
	var/flame_base_tint = "#ff0000"

/obj/item/flashlight/flare/New()
	. = ..()
	fuel = rand(290, 450) // Sorry for changing this so much but I keep under-estimating how long X number of ticks last in seconds.

/obj/item/flashlight/flare/update_icon()
	overlays?.Cut()
	. = ..()
	if(on)
		icon_state = "[initial(icon_state)]-on"
		if(show_flame)
			var/image/flame = image('icons/obj/lighting.dmi', src, "flare_flame")
			flame.color = flame_tint
			flame.appearance_flags = RESET_COLOR|RESET_TRANSFORM
			var/image/flame_base = image('icons/obj/lighting.dmi', src, "flare_flame")
			flame_base.color = flame_base_tint
			flame_base.appearance_flags = RESET_COLOR
			flame_base.blend_mode = BLEND_ADD
			flame.overlays += flame_base
			overlays += flame
	else if(burnt_out)
		icon_state = "[initial(icon_state)]-empty"
	else
		icon_state = "[initial(icon_state)]"

/obj/item/flashlight/flare/dropped(mob/user)
	. = ..()
	if(ishuman(user) && on)
		var/mob/living/human/H = user
		H.throw_mode_off()

/obj/item/flashlight/flare/process()
	fuel = max(fuel - 1, FALSE)
	if(fuel <= 0 || !on)
		burn_out()

/obj/item/flashlight/flare/pickup()
	pixel_x = 0
	pixel_y = 0
	return ..()

/obj/item/flashlight/flare/proc/burn_out()
	turn_off()
	fuel = 0
	burnt_out = TRUE
	update_icon()

/obj/item/flashlight/flare/proc/turn_off()
	on = FALSE
	force = initial(force)
	damtype = initial(damtype)
	processing_objects -= src

/obj/item/flashlight/flare/proc/turn_on()
	on = TRUE
	force = 7
	damtype = "fire"
	processing_objects += src
	update_icon()
	return TRUE

/obj/item/flashlight/flare/attack_self(mob/living/user as mob)
	if(!fuel)
		to_chat(user, SPAN_NOTICE("It's out of fuel."))
		return FALSE
	if(on)
		if(!do_after(user, 2 SECONDS, src))
			return
		if(!on)
			return
		user.visible_message(SPAN_WARNING("[user] snuffs out [src]."), SPAN_WARNING("You snuff out [src], burning your hand."))
		user.adjustBurnLoss(7)
		burn_out()
		//TODO: add snuff out sound
		return

	// All good, turn it on.
	if(src)
		user.visible_message(SPAN_NOTICE("[user] activates the flare."), SPAN_NOTICE("You pull the cord on the flare, activating it!"))
		playsound(src, turn_on_sound, 75, TRUE)
		turn_on()
		var/mob/living/human/H = user
		if(istype(H) && !H.in_throw_mode)
			H.throw_mode_on()

/obj/item/flashlight/flare/throw_impact(atom/hit_atom)
	if (on)
		if (ishuman(hit_atom))
			var/mob/living/human/H = hit_atom
			H.IgniteMob()
	..()

/obj/item/flashlight/flare/on/New()
	..()
	turn_on()
/obj/item/flashlight/flare/alwayson/New()
	..()
	fuel = INFINITY
	turn_on()

/obj/item/flashlight/flare/white
	name = "white phosphorus flare"
	desc = "A white phosphorus flare. There are instructions on the side reading 'pull cord, make light'. Lasts for about 5 minutes."
	icon_state = "flareW"
	flame_base_tint = "#eeeeee"
	projectile_type = /obj/item/flashlight/flare/white/on
/obj/item/flashlight/flare/white/on/New()
	. = ..()
	turn_on()

/obj/item/flashlight/flare/signal
	name = "signal flare"
	desc = "A signal flare for signalling spot to aircraft above. There are instructions on the side reading 'pull cord, make light'. Lasts for about 2 minutes."
	icon_state = "flareW"
	flame_base_tint = "#07d800"
	var/mob/living/human/caller = null
	
	var/attack_direction = "NORTH"
	var/list/attack_direction_list = list("NORTH", "EAST", "SOUTH", "WEST")

	var/payload = null
	var/list/payload_list = list("Rockets")

	var/call_in_time = 10 SECONDS

/obj/item/flashlight/flare/signal/attack_self(mob/living/user as mob)
	if(!ishuman(user))
		return
	var/mob/living/human/H = user
	if(!fuel)
		to_chat(user, SPAN_NOTICE("It's out of fuel."))
		return FALSE
	if(on)
		if(!do_after(user, 2 SECONDS, src))
			return
		if(!on)
			return
		user.visible_message(SPAN_WARNING("[user] snuffs out [src]."), SPAN_WARNING("You snuff out [src], burning your hand."))
		user.adjustBurnLoss(7)
		burn_out()
		//TODO: add snuff out sound
		return

	// All good, turn it on.
	if(src)
		caller = H
		user.visible_message(SPAN_NOTICE("[user] activates the flare."), SPAN_NOTICE("You pull the cord on the flare, activating it!"))
		playsound(src, turn_on_sound, 75, TRUE)
		turn_on()
		if(istype(H) && !H.in_throw_mode)
			H.throw_mode_on()
		var/call_in_time_offset = rand(-30,30)
		sleep((call_in_time + call_in_time_offset))
		activate_signal()

/obj/item/flashlight/flare/signal/proc/get_faction_aircraft(var/mob/living/human/H)
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
			aircraft_name = "F-16"
		if (RUSSIAN)
			if (map.ordinal_age == 6)
				aircraft_name = "IL-2"
			else
				aircraft_name = "Su-25"
	return aircraft_name

/obj/item/flashlight/flare/signal/proc/get_faction_num(var/mob/living/human/H)
	var/faction_num
	if (map.faction1 == H.faction_text)
		faction_num = 1
	else if (map.faction2 == H.faction_text)
		faction_num = 2
	return faction_num

/obj/item/flashlight/flare/signal/proc/get_payload_class()
	var/payload_class
	switch (payload)
		if ("Rockets")
			payload_class = 1
		if ("50 kg Bomb")
			payload_class = 2
		if ("250 kg Bomb")
			payload_class = 3
	return payload_class

/obj/item/flashlight/flare/signal/proc/activate_signal()
	anchored = TRUE
	var/turf/T = get_turf(src)
	payload = payload_list[1]
	attack_direction = pick(attack_direction_list)

	T.try_airstrike(caller.ckey, caller.faction_text, get_faction_aircraft(caller), attack_direction, payload, get_payload_class())
	sleep(50)
	qdel(src)

// Projectile
/obj/item/projectile/flare
	icon_state = "flare"
	damage = 10
	damage_type = BURN
/obj/item/projectile/flare/on_impact(mob/living/human/M as mob)
	ignite_turf_lowchance(get_turf(M),3,70)
	spawn (0.01)
		qdel(src)
	..()
