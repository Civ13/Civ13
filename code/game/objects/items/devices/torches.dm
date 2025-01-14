///////////////////
/* Default Torch */
///////////////////

/obj/item/torch
	name = "\improper torch"
	desc = "A stick with a fire at the end of it"
	icon = 'icons/obj/lighting.dmi'
	icon_state = "torch"
	w_class = ITEM_SIZE_SMALL
	flags = CONDUCT
	slot_flags = SLOT_BELT
	flags = CONDUCT
	light_color = rgb(254, 200, 200)

	var/active = FALSE		//Use setActive() to alter.
	var/light_intensity = 3	//Luminosity when active.
	var/fuel = 300			//How long the torch will stay active (in 2*seconds).
	var/fuellimit = 300

//Alter the "active" Variable
/obj/item/torch/proc/setActive(var/_active)
	if(active == _active || (fuel <= 0 && _active == TRUE))
		return
	active = _active
	ignition_source = _active
	if(active)
		set_light(light_intensity)
		processing_objects += src
	else
		set_light(0)
		processing_objects -= src
	update_icon()

//Run on Fuel Empty
/obj/item/torch/proc/fuelEmptied()
	setActive(FALSE)
	if(usr)
		usr.remove_from_mob(src)
	qdel(src)

//Update Icon
/obj/item/torch/update_icon()
	..()
	icon_state = initial(icon_state)
	if(active)
		icon_state += "-on"

//Ignite Torch by Attacking Ignition Source
/obj/item/torch/afterattack(atom/target, mob/user, proximity_flag)
	if(!proximity_flag)
		return ..()
	if(!active && istype(target, /obj))
		var/obj/O = target
		if(O.ignition_source)
			to_chat(user, "<span class='notice'>You ignite \the [src] with \the [target]</span>")
			setActive(TRUE)
			return
	..()

//Ignite Torch by Being Attacked by Ignition Source
/obj/item/torch/attackby(obj/item/I, mob/user)
	if(!active && I.ignition_source)
		to_chat(user, "<span class='notice'>You ignite \the [I] with \the [src]</span>")
		setActive(TRUE)
		return
	..()

//Examine
/obj/item/torch/examine(mob/user)
	..()
	var/timeleft = -round(-fuel / 30)
	to_chat(user, "<span class='notice'>\The [src] has about [timeleft] [timeleft == 1 ? "minute" : "minutes"] of fuel left.</span>")

//Toggle Off
/obj/item/torch/attack_self(mob/user)
	if(active)
		setActive(FALSE)
	..()

//Fuel Usage
/obj/item/torch/process()
	fuel--
	if(fuel <= 0)
		fuelEmptied()



/////////////
/* Lantern */
/////////////

/obj/item/torch/lantern
	name = "\improper lantern"
	desc = "A refuelable metal torch."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "lantern"
	fuel = 0
	light_intensity = 6
	light_color = rgb(200, 255, 200)
	value = 12

//Prevents Lantern From Being Deleted
/obj/item/torch/lantern/fuelEmptied()
	setActive(FALSE)

//Fuel Lantern
/obj/item/torch/lantern/attackby(obj/item/I, mob/user) //Chemicals should get a fuel value to make this simpler.
	if (istype(I, /obj/item/weapon/reagent_containers))
		var/regamt = -round(-fuellimit/30)
		if (I.reagents.has_reagent("petroleum", 1))
			regamt = min(regamt, I.reagents.get_reagent_amount("petroleum"))
			I.reagents.remove_reagent("petroleum", regamt)
			user << "You refuel the lantern with petroleum."
		else if (I.reagents.has_reagent("olive_oil", 1))
			regamt = min(regamt, I.reagents.get_reagent_amount("olive_oil"))
			I.reagents.remove_reagent("olive_oil", regamt)
			user << "You refuel the lantern with olive oil."
		else if (I.reagents.has_reagent("fat_oil", 1))
			regamt = min(regamt, I.reagents.get_reagent_amount("fat_oil"))
			I.reagents.remove_reagent("fat_oil", regamt)
			user << "You refuel the lantern with fat oil."
		fuel += min(regamt*30, fuellimit - fuel)
		return
	..()



//////////////
/* Variants */
//////////////

/obj/item/torch/on/New()
	..()
	setActive(TRUE)

/obj/item/torch/lantern/on/New()
	..()
	setActive(TRUE)

/obj/item/torch/lantern/copper
	name = "copper lamp"
	icon_state = "copperlamp"
	desc = "A simple copper lantern."
	light_intensity = 6					// luminosity when on
	light_color = rgb(200, 255, 200)	// green tint
	value = 9

/obj/item/torch/lantern/bronze
	name = "bronze etsy lamp"
	icon_state = "etsy"
	item_state = "etsy"
	desc = "A bronze lamp with several wicks."
	light_intensity = 8					// luminosity when on
	light_color = rgb(200, 255, 200)	// green tint
	value = 16

/obj/item/torch/lantern/anchored
	anchored = TRUE
	fuel = INFINITY

/obj/item/torch/lantern/oldlamp
	name = "stand lamp"
	icon_state = "oldlamp"
	fuel = INFINITY

/obj/item/flashlight/lamp/littlelamp
	name = "small lamp"
	icon_state = "littlelamp"
	fuel = INFINITY

/obj/item/torch/lantern/anchored/on/New()
	..()
	setActive(TRUE)



