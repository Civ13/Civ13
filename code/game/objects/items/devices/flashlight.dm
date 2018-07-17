/obj/item/flashlight
	name = "flashlight"
	desc = "A hand-held emergency light."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "flashlight_off"
	var/off_state = "flashlight_off"
	var/on_state = "flashlight_on"
	item_state = "flashlight"
	w_class = 2
	flags = CONDUCT
	slot_flags = SLOT_BELT

	matter = list(DEFAULT_WALL_MATERIAL = 50,"glass" = 20)

	action_button_name = "Toggle Flashlight"
	var/on = FALSE
	var/brightness_on = 5 //luminosity when on
	var/turn_on_sound = 'sound/effects/Custom_flashlight.ogg'

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
	playsound(loc, turn_on_sound, 75, TRUE)
	update_icon()
	user.update_action_buttons()
	return TRUE


/obj/item/flashlight/attack(mob/living/M as mob, mob/living/user as mob)
	add_fingerprint(user)
	if (on && user.targeted_organ == "eyes")

		if ((CLUMSY in user.mutations) && prob(50))	//too dumb to use flashlight properly
			return ..()	//just hit them in the head

		var/mob/living/carbon/human/H = M	//mob has protective eyewear
		if (istype(H))
			for (var/obj/item/clothing/C in list(H.head,H.wear_mask,H.glasses))
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
				if (XRAY in M.mutations)
					user << "<span class='notice'>\The [M] pupils give an eerie glow!</span>"
				if (vision.damage)
					user << "<span class='warning'>There's visible damage to [M]'s [vision.name]!</span>"
				else if (M.eye_blurry)
					user << "<span class='notice'>\The [M]'s pupils react slower than normally.</span>"
				if (M.getBrainLoss() > 15)
					user << "<span class='notice'>There's visible lag between left and right pupils' reactions.</span>"

				var/list/pinpoint = list("oxycodone"=1,"tramadol"=5)
				var/list/dilating = list("space_drugs"=5,"mindbreaker"=1)
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

/obj/item/flashlight/pen
	name = "penlight"
	desc = "A pen-sized light, used by medical staff."
	icon_state = "penlight"
	item_state = ""
	flags = CONDUCT
	slot_flags = SLOT_EARS
	brightness_on = 2
	w_class = TRUE

// the desk lamps are a bit special
/obj/item/flashlight/lamp
	name = "desk lamp"
	desc = "A desk lamp with an adjustable mount."
	icon_state = "lamp"
	item_state = "lamp"
	brightness_on = 4
	w_class = 4
	flags = CONDUCT

	on = TRUE


// green-shaded desk lamp
/obj/item/flashlight/lamp/green
	desc = "A classic green-shaded desk lamp."
	icon_state = "lampgreen"
	item_state = "lampgreen"
	brightness_on = 4
	light_color = "#FFC58F"

/obj/item/flashlight/lamp/verb/toggle_light()
	set name = "Toggle light"
	set category = null
	set src in oview(1)

	if (!usr.stat)
		attack_self(usr)

// FLARES

/obj/item/flashlight/flare
	name = "flare"
	desc = "A red standard-issue flare. There are instructions on the side reading 'pull cord, make light'."
	w_class = 2.0
	brightness_on = 4 // Pretty bright.
	light_power = 2
	light_color = "#e58775"
	icon_state = "flare"
	off_state = "flare"
	on_state = "flare-on"
	item_state = "flare"
	action_button_name = null //just pull it manually, neckbeard.
	var/fuel = 0
	var/on_damage = 7
	var/produce_heat = 1500
	turn_on_sound = 'sound/effects/Custom_flare.ogg'

/obj/item/flashlight/flare/nighttime
/obj/item/flashlight/flare/nighttime/New()
	..()
	fuel = INFINITY
	turn_on()

/obj/item/flashlight/flare/New()
	fuel = rand(800, 1000) // Sorry for changing this so much but I keep under-estimating how long X number of ticks last in seconds.
	..()

/obj/item/flashlight/flare/process()
	var/turf/pos = get_turf(src)
	if (pos)
		pos.hotspot_expose(produce_heat, 5)
	fuel = max(fuel - 1, FALSE)
	if (!fuel || !on)
		turn_off()
		if (!fuel)
			icon_state = "[initial(icon_state)]-empty"
		processing_objects -= src

/obj/item/flashlight/flare/proc/turn_off()
	on = FALSE
	force = initial(force)
	damtype = initial(damtype)
	update_icon()

/obj/item/flashlight/flare/attack_self(mob/user)
	if (turn_on(user))
		playsound(loc, turn_on_sound, 75, TRUE)
		user.visible_message("<span class='notice'>\The [user] activates \the [src].</span>", "<span class='notice'>You pull the cord on the flare, activating it!</span>")

/obj/item/flashlight/flare/proc/turn_on(var/mob/user)
	if (on)
		return FALSE
	if (!fuel)
		if (user)
			user << "<span class='notice'>It's out of fuel.</span>"
		return FALSE
	on = TRUE
	force = on_damage
	damtype = "fire"
	processing_objects += src
	update_icon()
	return TRUE

/obj/item/flashlight/glowstick
	name = "green glowstick"
	desc = "A military-grade glowstick."
	w_class = 2.0
	color = "#49F37C"
	icon_state = "glowstick"
	item_state = "glowstick"
	action_button_name = null
	var/fuel = FALSE

/obj/item/flashlight/glowstick/New()
	pixel_x = rand(-12,12)
	pixel_y = rand(-12,12)
	fuel = rand(1600, 2000)
	light_color = color
	..()

/obj/item/flashlight/glowstick/process()
	fuel = max(fuel - 1, FALSE)
	if (!fuel)
		turn_off()
		processing_objects -= src
		update_icon()

/obj/item/flashlight/glowstick/proc/turn_off()
	on = FALSE
	update_icon()

/obj/item/flashlight/glowstick/update_icon()
	item_state = "glowstick"
	overlays.Cut()
	if (!fuel)
		icon_state = "glowstick-empty"
		set_light(0)
	else if (on)
		var/image/I = image(icon,"glowstick-on",color)
		I.blend_mode = BLEND_ADD
		overlays += I
		item_state = "glowstick-on"
		set_light(2.5, TRUE)
	else
		icon_state = "glowstick"
	var/mob/M = loc
	if (istype(M))
		if (M.l_hand == src)
			M.update_inv_l_hand()
		if (M.r_hand == src)
			M.update_inv_r_hand()

/obj/item/flashlight/glowstick/attack_self(mob/user)

	if (!fuel)
		user << "<span class='notice'>The [src] is spent.</span>"
		return
	if (on)
		user << "<span class='notice'>The [src] is already lit.</span>"
		return

	. = ..()
	if (.)
		user.visible_message("<span class='notice'>[user] cracks and shakes the glowstick.</span>", "<span class='notice'>You crack and shake the glowstick, turning it on!</span>")
		processing_objects += src

/obj/item/flashlight/glowstick/red
	name = "red glowstick"
	color = "#FC0F29"

/obj/item/flashlight/glowstick/blue
	name = "blue glowstick"
	color = "#599DFF"

/obj/item/flashlight/glowstick/orange
	name = "orange glowstick"
	color = "#FA7C0B"

/obj/item/flashlight/glowstick/yellow
	name = "yellow glowstick"
	color = "#FEF923"

/obj/item/flashlight/glowstick/random
	name = "glowstick"
	desc = "A party-grade glowstick."
	color = "#FF00FF"

/obj/item/flashlight/glowstick/random/New()
	color = rgb(rand(50,255),rand(50,255),rand(50,255))
	..()

/obj/item/flashlight/slime
	gender = PLURAL
	name = "glowing slime extract"
	desc = "A glowing ball of what appears to be amber."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "floor1" //not a slime extract sprite but... something close enough!
	item_state = "slime"
	w_class = TRUE
	brightness_on = 6
	on = TRUE //Bio-luminesence has one setting, on.

/obj/item/flashlight/slime/New()
	..()
	set_light(brightness_on)

/obj/item/flashlight/slime/update_icon()
	return

/obj/item/flashlight/slime/attack_self(mob/user)
	return //Bio-luminescence does not toggle.
