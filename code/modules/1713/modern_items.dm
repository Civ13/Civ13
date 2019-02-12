///Mostly electrically powered stuff

/obj/structure/lamp
	name = "small lamp post"
	desc = "A small lamp post, good for outdoor illumination."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "lamppost_small"
	var/base_icon = "lamppost_small"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	var/on = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	powerneeded = 2
	var/light_amt = 6 //light range
	layer = 3.95

/obj/structure/lamp/New()
	..()
	do_light()

/obj/structure/lamp/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack/cable_coil))
		if (powersource)
			user << "There's already a cable connected here! Split it further from the [src]."
			return
		var/obj/item/stack/cable_coil/CC = W
		powersource = CC.place_turf(get_turf(src), user, turn(get_dir(user,src),180))
		powersource.connections += src
		user << "You connect the cable to the [src]."
	else
		..()


/obj/structure/lamp/proc/do_light()
	if (check_power())
		set_light(light_amt)
		icon_state = "[base_icon]_on"
		powered = TRUE
		on = TRUE
	else
		set_light(0)
		icon_state = base_icon
		powered = FALSE
		on = FALSE

	spawn(10)
		do_light()

/obj/structure/lamp/proc/check_power()
	if (!powersource || powerneeded == 0)
		return FALSE
	else
		if (powersource.powered && ((powersource.powerflow-powersource.currentflow) >= powerneeded))
			if (!on)
				powersource.update_power(powerneeded,1)
				on = TRUE
				powersource.currentflow += powerneeded
				powersource.lastupdate2 = world.time
			return TRUE
		else
			if (on)
				powersource.update_power(powerneeded,1)
				on = FALSE
				powersource.currentflow -= powerneeded
				powersource.lastupdate2 = world.time
			return FALSE

/obj/structure/lamp/lamppost_small
	name = "small lamp post"
	desc = "A small lamp post, good for outdoor illumination."
	icon_state = "lamppost_small"
	powerneeded = 2
	light_amt = 6

/obj/structure/lamp/lamp_small
	name = "small lightbulb"
	desc = "A small lightbulb."
	icon_state = "bulb"
	base_icon = "bulb"
	powerneeded = 1
	light_amt = 3
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/lamp/lamp_big
	name = "light tube"
	desc = "A light tube."
	icon_state = "tube"
	base_icon = "tube"
	powerneeded = 1.3
	light_amt = 4
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/refinery
	name = "refinery"
	desc = "A petroleum refinery."
	icon = 'icons/obj/obj32x64.dmi'
	icon_state = "refinery"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/list/barrel = list()
	var/volume = 0
	var/maxvolume = 300
	var/active = FALSE
	var/product = "gasoline"
	powerneeded = 20

/obj/structure/refinery/attackby(var/obj/item/stack/W as obj, var/mob/living/carbon/human/H as mob)
	if (istype(W, /obj/item/weapon/reagent_containers/glass/barrel))
		if (isemptylist(barrel))
			barrel += W
			H.drop_from_inventory(W)
			W.forceMove(locate(0,0,0))
			visible_message("[H] puts \the [W] in \the [src].","You put \the [W] in \the [src].")
			return
		else
			if (volume >= maxvolume)
				H << "<span class = 'notice'>The refinery is full.</span>"
				return
			var/obj/item/weapon/reagent_containers/glass/barrel/C = W
			if (C.reagents.has_reagent("petroleum",1))
				var/barrelamt = C.reagents.get_reagent_amount("petroleum")
				if (barrelamt < (maxvolume-volume))
					C.reagents.remove_reagent("petroleum",barrelamt)
					volume += barrelamt
					visible_message("[H] pours \the [W] into \the [src].","You pour [barrelamt] units of petroleum from \the [W] into \the [src].")
					if (volume > maxvolume)
						volume = maxvolume
					return
				else
					C.reagents.remove_reagent("petroleum",(maxvolume-volume))
					volume += (maxvolume-volume)
					visible_message("[H] pours \the [W] into \the [src].","You pour [maxvolume-volume] units of petroleum from \the [W] into \the [src].")
					if (volume > maxvolume)
						volume = maxvolume
					return
			else
				H << "<span class = 'notice'>This [W] has no crude petroleum in it!</span>"
				return
	else if (istype(W, /obj/item/stack/cable_coil))
		if (powersource)
			H << "There's already a cable connected here! Split it further from the [src]."
			return
		var/obj/item/stack/cable_coil/CC = W
		powersource = CC.place_turf(get_turf(src), H, turn(get_dir(H,src),180))
		powersource.connections += src
		H << "You connect the cable to the [src]."

	else
		..()

/obj/structure/refinery/verb/empty()
	set category = null
	set name = "Remove Barrel"
	set src in range(1, usr)

	if (active)
		usr << "<span class = 'notice'>You need to shut the refinery down first!</span>"
		return
	if (!isemptylist(barrel))
		usr << "You start taking \the [barrel[1]] from \the [src]..."
		if (do_after(usr,35,src))
			visible_message("You remove \the [barrel[1]].","[usr] removes \the [barrel[1]] from \the [src].")
		for(var/obj/item/weapon/reagent_containers/glass/barrel/B in barrel)
			B.loc = get_turf(src)
			barrel -= B
			active = FALSE
			powered = FALSE
			return
	else
		usr << "<span class = 'notice'>There is no barrel to remove from \the [src].</span>"
		return

/obj/structure/refinery/verb/set_product()
	set category = null
	set name = "Set Output"
	set src in range(1, usr)

	if (active)
		usr << "<span class = 'notice'>You need to shut the refinery down first!</span>"
		return
	else
		var/prod = WWinput(usr, "What to produce?", "Refinery", "Cancel", list("Gasoline","Diesel","Cancel"))
		if (prod == "Cancel")
			return
		else if (prod == "Gasoline")
			product = "Gasoline"
			usr << "This refinery will now produce <b>Gasoline</b>."
			return
		else if (prod == "Diesel")
			product = "Diesel"
			usr << "This refinery will now produce <b>Diesel</b>."
			return
/obj/structure/refinery/attack_hand(var/mob/living/carbon/human/H)
	if (isemptylist(barrel))
		H << "<span class = 'notice'>There is no barrel to collect the refined products.</span>"
		return
	if (volume < 1)
		H << "<span class = 'notice'>The refinery is empty! Put some crude petroleum in first.</span>"
		return
	if (active)
		active = FALSE
		powered = FALSE
		powersource.update_power(powerneeded,1)
		powersource.currentflow -= powerneeded
		powersource.lastupdate2 = world.time
		H << "You power off the refinery."
		return

	else if (!active && !powersource.powered)
		H << "<span class = 'notice'>There is not enough power to start the refinery.</span>"
		return
	else if (!active && powersource.powered && ((powersource.powerflow-powersource.currentflow) >= powerneeded))
		active = TRUE
		powered = TRUE
		powersource.update_power(powerneeded,1)
		powersource.currentflow += powerneeded
		powersource.lastupdate2 = world.time
		power_on()
		H << "You power the refinery."
		return
	else
		H << "<span class = 'notice'>There is not enough power to start the refinery.</span>"
		return
/obj/structure/refinery/proc/power_on()
	if (powered && active)
		update_icon()
		spawn(600)
			refine()
	else
		update_icon()
		return


/obj/structure/refinery/proc/refine()
	if (powered && active && volume >= 1 && !isemptylist(barrel))
		if (!barrel[1])
			active = FALSE
			update_icon()
			return
		if (barrel[1].reagents.total_volume >= barrel[1].reagents.maximum_volume)
			visible_message("The refinery stops working. The [barrel[1]] is full.")
			active = FALSE
			update_icon()
			return
		update_icon()
		var/amt = 10
		if (volume < 10)
			amt = volume
			if (volume < 0)
				volume = 0
		if (product == "gasoline")
			volume -= amt
			barrel[1].reagents.add_reagent("gasoline",0.8*amt)
		else if (product == "diesel")
			volume -= amt
			barrel[1].reagents.add_reagent("diesel",0.7*amt)
		else // default to diesel
			volume -= amt
			barrel[1].reagents.add_reagent("diesel",0.7*amt)
		spawn(600)
			refine()
		return
	else
		update_icon()
		return
/obj/structure/refinery/update_icon()
	if (active)
		icon_state = "refinery1"
	else
		icon_state = "refinery"