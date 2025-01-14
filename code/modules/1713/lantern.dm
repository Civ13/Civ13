/obj/item/flashlight/tiki_torch
	name = "tiki torch"
	desc = "A tiki style torch."
	brightness_on = 8			// luminosity when on
	light_color = rgb(254, 200, 200) // red tint
	on_state = "tikitorch-on"
	off_state = "tikitorch"
	item_state = "torch"
	icon_state = "tikitorch"
	value = 10
	fuel = 600 // 10 mins
	anchored = FALSE
	flammable = TRUE

/obj/item/flashlight/tiki_torch/update_icon()
	..()
	if (on)
		item_state = "tikitorch-on"
	else
		item_state = "tikitorch"

/obj/item/flashlight/tiki_torch/attack_hand(var/mob/living/human/user)
	attack_self(user)

/obj/item/flashlight/tiki_torch/verb_pickup()
	set src in oview(1)
	set category = null
	set name = "Pick up"

	return

/obj/item/flashlight/proc/do_torch()
	if(!crafted) // Flashlight optimization
		update_icon()
		return
	spawn(10)
		if (fuel == 50 && on)
			visible_message("<span class='warning'>\The [src] is about to run out!</span>")
			fuel -= 1
			do_torch()
		else if (fuel > 0 && on)
			fuel -= 1
			do_torch()
		else if (fuel <= 0 && on)
			visible_message("\The [src] goes off.")
			if (istype(src, /obj/item/flashlight/tiki_torch))
				qdel(src)
				return
			else
				on = FALSE
				update_icon()
				do_torch()
		else if (on == FALSE)
			do_torch()

/obj/item/flashlight/tiki_torch/on
	unlimited = TRUE
	icon_state = "tikitorch-on"
	item_state = "tikitorch-on"
	on = TRUE
/obj/item/flashlight/tiki_torch/on/anchor
	anchored = TRUE

/obj/item/flashlight/tiki_torch/on/anchor/unlimited
	unlimited = TRUE
/obj/item/flashlight/flashlight
	unlimited = TRUE
	name = "flashlight"
	desc = "an electrical flashlight."
	icon_state = "flashlight_off"
	item_state = "modern_flashlight"
	on_state = "flashlight_on"
	off_state = "flashlight_off"
	slot_flags = SLOT_BELT | SLOT_ID | SLOT_POCKET
	unlimited = TRUE

/obj/item/flashlight/modern
	unlimited = TRUE
	name = "flashlight"
	desc = "an electrical flashlight."
	icon_state = "modernlight_off"
	item_state = "modern_flashlight"
	on_state = "modernlight_on"
	off_state = "modernlight_off"
	slot_flags = SLOT_BELT | SLOT_ID | SLOT_POCKET

/obj/item/flashlight/militarylight
	unlimited = TRUE
	name = "military flashlight"
	desc = "An electrical military flashlight. Comes with adjustable lenses."
	icon_state = "militarylight_off"
	item_state = "militarylight"
	on_state = "militarylight_on"
	off_state = "militarylight_off"
	slot_flags = SLOT_BELT | SLOT_ID | SLOT_POCKET
	var/lens = 3
	secondary_action = TRUE

/obj/item/flashlight/militarylight/secondary_attack_self(mob/living/human/user)

	lens +=1
	if (lens > 3)
		lens = 1

	switch (lens)
		if (1)
			light_range = 1.5
			brightness_on = 2.5
			light_color = "#ad2005"
			on_state = "militarylight_on_red"
			lens = 1
			user << "<span class='notice'>You put on a <b><font color =#960000>red</font color></b> lens on your flashlight.</span>"
			update_icon()
			return
		if (2)
			light_range = 1.5
			brightness_on = 2.5
			light_color = "#17ad2a"
			on_state ="militarylight_on_green"
			lens = 2
			update_icon()
			user << "<span class='notice'>You put on a <b><font color=#006400>green</font color></b> lens on your flashlight.</span>"
			return
		if (3)
			light_range = 5
			brightness_on = 5
			light_color = "#fcffd6"
			on_state ="militarylight_on"
			lens = 3
			user << "<span class='notice'>You <b>remove</b> the lens from your flashlight.</span>"
			update_icon()
			return

/obj/item/flashlight/militarylight/alt
	unlimited = TRUE
	icon_state = "militarylightalt_off"
	item_state = "militarylightalt"
	on_state = "militarylightalt_on"
	off_state = "militarylightalt_off"

/obj/item/flashlight/militarylight/alt/secondary_attack_self(mob/living/human/user)

	lens +=1
	if (lens > 3)
		lens = 1

	switch (lens)
		if (1)
			light_range = 1.5
			brightness_on = 2.5
			light_color = "#ad2005"
			on_state = "militarylightalt_on_red"
			lens = 1
			user << "<span class='notice'>You put on a <b><font color =#960000>red</font color></b> lens on your flashlight.</span>"
			update_icon()
			return
		if (2)
			light_range = 1.5
			brightness_on = 2.5
			light_color = "#17ad2a"
			on_state ="militarylightalt_on_green"
			lens = 2
			update_icon()
			user << "<span class='notice'>You put on a <b><font color=#006400>green</font color></b> lens on your flashlight.</span>"
			return
		if (3)
			light_range = 5
			brightness_on = 5
			light_color = "#fcffd6"
			on_state ="militarylightalt_on"
			lens = 3
			user << "<span class='notice'>You <b>remove</b> the lens from your flashlight.</span>"
			update_icon()
			return


/obj/item/flashlight/japflashlight
	unlimited = TRUE
	name = "japanese dynamo flashlight"
	desc = "A japanese flashlight with a dynamo mechanism and adjustable light intensity."
	icon_state = "flashlightjap_off"
	item_state = "militarylight"
	on_state = "flashlightjap_on"
	off_state = "flashlightjap_off"
	slot_flags = SLOT_BELT | SLOT_ID | SLOT_POCKET
	var/intensity = 3
	secondary_action = TRUE

/obj/item/flashlight/japflashlight/secondary_attack_self(mob/living/human/user)

	intensity +=1
	if (intensity > 3)
		intensity = 1

	switch (intensity)
		if (1)
			light_range = 3
			brightness_on = 3
			intensity = 1
			user << "<span class='notice'>You <b>reduce</b> the intensity of your flashlight.</span>"
			return
		if (2)
			light_range = 2
			brightness_on = 2
			intensity = 2
			user << "<span class='notice'>You <b>reduce further</b> the intensity of your flashlight.</span>"
			return
		if (3)
			light_range = 5
			brightness_on = 5
			intensity = 3
			user << "<span class='notice'>You switch back the intensity to <b>normal</b> on your flashlight.</span>"
			return