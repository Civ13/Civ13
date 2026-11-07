/obj/item/flashlight/lantern
	name = "lantern"
	icon_state = "lantern"
	desc = "A simple lantern."
	brightness_on = 6			// luminosity when on
	light_color = rgb(200, 255, 200) // green tint
	on_state = "lantern-on"
	off_state = "lantern"
	value = 12
	fuel = 0 //starts empty
	max_fuel = 3600 // one hour of oil
	unlimited = FALSE
	uses_batteries = FALSE
	refuel_reagents = list("petroleum" = 120, "olive_oil" = 120, "fat_oil" = 120, "cornoil" = 120)
	empty_message = "is out of oil"

/obj/item/flashlight/lantern/copper
	name = "copper lamp"
	icon_state = "copperlamp"
	desc = "A simple copper lantern."
	brightness_on = 6			// luminosity when on
	light_color = rgb(200, 255, 200) // green tint
	on_state = "copperlamp-on"
	off_state = "copperlamp"
	value = 9
	fuel = 0 //starts empty
	unlimited = FALSE

/obj/item/flashlight/lantern/bronze
	name = "bronze etsy lamp"
	icon_state = "etsy"
	item_state = "etsy"
	desc = "A bronze lamp with several wicks."
	brightness_on = 8			// luminosity when on
	light_color = rgb(200, 255, 200) // green tint
	on_state = "etsy-on"
	off_state = "etsy"
	value = 16
	fuel = 0 //starts empty
	max_fuel = 5400 // several wicks, a bigger reservoir
	unlimited = FALSE

/obj/item/flashlight/lantern/bronze/update_icon()
	..()
	if (on)
		item_state = "etsy-on"
	else
		item_state = "etsy"

/obj/item/flashlight/lantern/bronze/on
	icon_state = "torch-on"
	item_state = "torch-on"
	on = TRUE

/obj/item/flashlight/lantern/attack_self(mob/user)
	if (!isturf(user.loc))
		to_chat(user, "You cannot turn the light on while in this [user.loc].") //To prevent some lighting anomalities.)
		return FALSE
	if (fuel > 0)
		on = !on
		playsound(loc, turn_on_sound, 75, TRUE)
		update_icon()
		user.update_action_buttons()
		return TRUE
	else if (fuel <= 0)
		to_chat(user, "<span class='warning'>\The [src] [empty_message]. Fill it with [refuel_hint()].</span>")

/obj/item/flashlight/lantern/attack_hand(mob/user as mob)
	if (loc != user && anchored)
		if (on)
			on = FALSE
			return
		else if (!on && fuel > 0)
			on = TRUE
			return
		else
			on = FALSE
			return
	..()

/obj/item/flashlight/lantern/on
	icon_state = "lantern-on"
	on = TRUE

/obj/item/flashlight/New()
	..()
	if (!max_fuel)
		max_fuel = fuel
	if (!unlimited)
		do_torch()

/obj/item/flashlight/lantern/anchored
	on_state = "lantern-on_a"
	off_state = "lantern_a"
	icon_state = "lantern_a"
	anchored = TRUE
	unlimited = TRUE
	fuel = 10

/obj/item/flashlight/lamp/oldlamp
	name = "stand lamp"
	on_state = "oldlamp-on"
	off_state = "oldlamp"
	icon_state = "oldlamp"
	anchored = FALSE
	unlimited = TRUE
	uses_batteries = FALSE
	fuel = INFINITY

/obj/item/flashlight/lamp/littlelamp
	name = "small lamp"
	on_state = "littlelamp-on"
	off_state = "littlelamp"
	icon_state = "littlelamp"
	unlimited = TRUE
	uses_batteries = FALSE
	fuel = INFINITY

/obj/item/flashlight/lamp/littlelamp/desklamp
	name = "desk lamp"
	on_state = "lampdesk_on"
	off_state = "lampdesk"
	icon_state = "lampdesk"
	unlimited = TRUE
	uses_batteries = FALSE
	fuel = INFINITY

/obj/item/flashlight/lantern/on/anchored
	on_state = "lantern-on"
	off_state = "lantern_on"
	icon_state = "lantern-on"
	anchored = TRUE
	unlimited = TRUE
	fuel = 10

/obj/item/flashlight/torch
	name = "torch"
	icon_state = "torch"
	desc = "A tool handle wrapped in fat or oil. Dip it in animal fat or oil to keep it burning; once it burns down, the handle is left."
	brightness_on = 4			// luminosity when on
	light_color = rgb(254, 200, 200) // red tint
	on_state = "torch-on"
	off_state = "torch"
	item_state = "torch"
	value = 6
	fuel = 300 // 5 mins
	max_fuel = 600
	uses_batteries = FALSE
	refuel_reagents = list("fat_oil" = 30, "olive_oil" = 30, "cornoil" = 30, "petroleum" = 30)
	empty_message = "has burnt down"
	// The handle the torch was wrapped around; it is left when the torch burns out.
	var/handle_material = "wood"

/obj/item/flashlight/torch/update_icon()
	..()
	if (on)
		item_state = "torch-on"
	else
		item_state = "torch"

/obj/item/flashlight/torch/on
	icon_state = "torch-on"
	item_state = "torch-on"
	on = TRUE

/obj/item/flashlight/torch/on/unlimited
	unlimited = TRUE
	anchored = TRUE


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
	max_fuel = 1800
	anchored = FALSE
	flammable = TRUE
	uses_batteries = FALSE
	refuel_reagents = list("fat_oil" = 60, "olive_oil" = 60, "cornoil" = 60, "petroleum" = 60)
	empty_message = "is out of oil"

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

// Global so the refresh still runs after the burnt-out light is deleted.
/proc/refresh_light_holder_later(obj/item/weapon/storage/internal/holder)
	spawn(1)
		if (holder && !holder.gcDestroyed)
			holder.update_icon()

/obj/item/flashlight/proc/do_torch()
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
			if (burn_out_light())
				return
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
	name = "flashlight"
	desc = "an electrical flashlight."
	icon_state = "flashlight_off"
	item_state = "modern_flashlight"
	on_state = "flashlight_on"
	off_state = "flashlight_off"
	slot_flags = SLOT_BELT | SLOT_ID | SLOT_POCKET

/obj/item/flashlight/modern
	name = "flashlight"
	desc = "an electrical flashlight."
	icon_state = "modernlight_off"
	item_state = "modern_flashlight"
	on_state = "modernlight_on"
	off_state = "modernlight_off"
	slot_flags = SLOT_BELT | SLOT_ID | SLOT_POCKET

//"spooky" version of the flashlight, reduced range, red tint
/obj/item/flashlight/modern/darknight
	icon_state = "militarylight_off"
	item_state = "militarylight"
	on_state = "militarylight_on_red"
	off_state = "militarylight_off"
	light_range = 2.5
	brightness_on = 5
	light_color = "#ad2005"

/obj/item/flashlight/militarylight
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
			to_chat(user, "<span class='notice'>You put on a <b><font color =#960000>red</font color></b> lens on your flashlight.</span>")
			update_icon()
			return
		if (2)
			light_range = 1.5
			brightness_on = 2.5
			light_color = "#17ad2a"
			on_state ="militarylight_on_green"
			lens = 2
			update_icon()
			to_chat(user, "<span class='notice'>You put on a <b><font color=#006400>green</font color></b> lens on your flashlight.</span>")
			return
		if (3)
			light_range = 5
			brightness_on = 5
			light_color = "#fcffd6"
			on_state ="militarylight_on"
			lens = 3
			to_chat(user, "<span class='notice'>You <b>remove</b> the lens from your flashlight.</span>")
			update_icon()
			return

/obj/item/flashlight/militarylight/alt
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
			to_chat(user, "<span class='notice'>You put on a <b><font color =#960000>red</font color></b> lens on your flashlight.</span>")
			update_icon()
			return
		if (2)
			light_range = 1.5
			brightness_on = 2.5
			light_color = "#17ad2a"
			on_state ="militarylightalt_on_green"
			lens = 2
			update_icon()
			to_chat(user, "<span class='notice'>You put on a <b><font color=#006400>green</font color></b> lens on your flashlight.</span>")
			return
		if (3)
			light_range = 5
			brightness_on = 5
			light_color = "#fcffd6"
			on_state ="militarylightalt_on"
			lens = 3
			to_chat(user, "<span class='notice'>You <b>remove</b> the lens from your flashlight.</span>")
			update_icon()
			return


/obj/item/flashlight/japflashlight
	name = "japanese dynamo flashlight"
	desc = "A japanese flashlight with a dynamo mechanism and adjustable light intensity. Wind the dynamo to charge it."
	fuel = 600
	max_fuel = 600
	uses_batteries = FALSE
	empty_message = "needs winding"
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
			to_chat(user, "<span class='notice'>You <b>reduce</b> the intensity of your flashlight.</span>")
			return
		if (2)
			light_range = 2
			brightness_on = 2
			intensity = 2
			to_chat(user, "<span class='notice'>You <b>reduce further</b> the intensity of your flashlight.</span>")
			return
		if (3)
			light_range = 5
			brightness_on = 5
			intensity = 3
			to_chat(user, "<span class='notice'>You switch back the intensity to <b>normal</b> on your flashlight.</span>")
			return