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
	unlimited = FALSE

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
	desc = "A bronze lamp with several candle holders."
	brightness_on = 8			// luminosity when on
	light_color = rgb(200, 255, 200) // green tint
	on_state = "etsy-on"
	off_state = "etsy"
	value = 16
	fuel = 0 //starts empty
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
		user << "You cannot turn the light on while in this [user.loc]." //To prevent some lighting anomalities.
		return FALSE
	if (fuel > 0)
		on = !on
		playsound(loc, turn_on_sound, 75, TRUE)
		update_icon()
		user.update_action_buttons()
		return TRUE
	else if (fuel <= 0)
		visible_message("<span class='warning'>\The [src] is out of fuel!</span>")

/obj/item/flashlight/lantern/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers))
		if (W.reagents.has_reagent("petroleum", 1))
			var/regamt = W.reagents.get_reagent_amount("petroleum")
			W.reagents.remove_reagent("petroleum", regamt)
			fuel += (regamt*120)
			user << "You refuel the lantern with petroleum."
			return
		else if (W.reagents.has_reagent("olive_oil", 1))
			var/regamt = W.reagents.get_reagent_amount("olive_oil")
			W.reagents.remove_reagent("olive_oil", regamt)
			fuel += (regamt*120)
			user << "You refuel the lantern with olive oil."
			return
/obj/item/flashlight/lantern/attack_hand(mob/user as mob)
	if (anchored)
		if (on)
			on = FALSE
		else if (!on && fuel > 0)
			on = TRUE
		else
			on = FALSE
	else
		..()

/obj/item/flashlight/lantern/on
	icon_state = "lantern-on"
	on = TRUE

/obj/item/flashlight/New()
	..()
	if (!unlimited)
		do_torch()

/obj/item/flashlight/lantern/anchored
	on_state = "lantern-on_a"
	off_state = "lantern_a"
	icon_state = "lantern_a"
	anchored = TRUE
	unlimited = TRUE
	fuel = 10

/obj/item/flashlight/lantern/on/anchored
	on_state = "lantern-on_a"
	off_state = "lantern_a"
	icon_state = "lantern-on_a"
	anchored = TRUE
	unlimited = TRUE
	fuel = 10

/obj/item/flashlight/torch
	name = "torch"
	icon_state = "torch"
	desc = "A simple wood stick with animal fat on top."
	brightness_on = 4			// luminosity when on
	light_color = rgb(254, 200, 200) // red tint
	on_state = "torch-on"
	off_state = "torch"
	item_state = "torch"
	value = 6
	fuel = 300 // 5 mins

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
			if (istype(src, /obj/item/flashlight/torch))
				qdel(src)
				return
			else
				on = FALSE
				update_icon()
				do_torch()
		else if (on == FALSE)
			do_torch()


/obj/item/flashlight/flashlight
	unlimited = TRUE
	name = "flashlight"
	desc = "an electrical flashlight."
	icon_state = "flashlight_off"
	on_state = "flashlight_on"
	off_state = "flashlight_off"