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
	playsound(loc, turn_on_sound, 75, TRUE)
	update_icon()
	return TRUE


/obj/item/flashlight/attack(mob/living/carbon/human/M as mob, mob/user as mob)
	add_fingerprint(user)
	if (istype(src, /obj/item/flashlight/torch) && user.a_intent == I_HURT)
		if (on && world.time > cooloff)
			M.adjustFireLoss(rand(7,10))
			user.visible_message("<span class='notice'>\The [user] hits [M] with the [src]!</span>", "<span class='notice'>You hit [M] with the [src]!</span>")
			user.do_attack_animation(M)
			if (prob(5))
				M.fire_stacks += 1
			M.IgniteMob()
			playsound(loc, 'sound/weapons/thudswoosh.ogg', 75, TRUE)
			cooloff = world.time+10
			return

	if (on && user.targeted_organ == "eyes")

		var/mob/living/carbon/human/H = M	//mob has protective eyewear
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
	var/on_damage = 7
	fuel = 0
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