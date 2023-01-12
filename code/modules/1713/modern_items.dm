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
	not_movable = FALSE
	not_disassemblable = TRUE
	powerneeded = 2
	var/light_amt = 6 //light range
	layer = 3.95
	var/brightness_color = null
	var/lamp_inside = TRUE
	var/lamp_broken = FALSE
	var/ltype = "lbulb"
/obj/structure/lamp/New()
	..()
	do_light()
/obj/structure/lamp/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (istype(mover, /obj/item/projectile))
		if (prob(80))
			return TRUE
		else
			return FALSE
	else
		return ..()
/obj/structure/lamp/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W,/obj/item/lightbulb) && !lamp_inside)
		var/obj/item/lightbulb/L = W
		if (!L.broken && L.ltype == ltype)
			user << "You put the lightbulb in."
			qdel(W)
			lamp_inside = TRUE
			lamp_broken = FALSE
			icon_state = base_icon
			update_icon()
			return
	if (istype(W,/obj/item/weapon/wrench) && !not_movable)
		if (powersource)
			user << "<span class='notice'>Remove the cables first.</span>"
			return
		if (istype(src, /obj/structure/engine))
			var/obj/structure/engine/EN = src
			if (!isemptylist(EN.connections))
				user << "<span class='notice'>Remove the cables first.</span>"
				return
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		user << (anchored ? "<span class='notice'>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored
		return
	if (!anchored)
		user << "<span class='notice'>Fix the lamp in place with a wrench first.</span>"
		return
	if (istype(W, /obj/item/stack/cable_coil))
		if (powersource)
			user << "There's already a cable connected here! Split it further from the [src]."
			return
		var/obj/item/stack/cable_coil/CC = W
		powersource = CC.place_turf(get_turf(src), user, turn(get_dir(user,src),180))
		if (!powersource)
			return
		powersource.connections += src
		var/opdir1 = 0
		var/opdir2 = 0
		if (powersource.tiledir == "horizontal")
			opdir1 = 4
			opdir2 = 8
		else if  (powersource.tiledir == "vertical")
			opdir1 = 1
			opdir2 = 2
		powersource.update_icon()

		if (opdir1 != 0 && opdir2 != 0)
			for(var/obj/structure/cable/NCOO in get_turf(get_step(powersource,opdir1)))
				if ((NCOO.tiledir == powersource.tiledir) && NCOO != powersource)
					if (!(powersource in NCOO.connections) && !list_cmp(powersource.connections, NCOO.connections))
						NCOO.connections += powersource
					if (!(NCOO in powersource.connections) && !list_cmp(powersource.connections, NCOO.connections))
						powersource.connections += NCOO
					user << "You connect the two cables."

			for(var/obj/structure/cable/NCOC in get_turf(get_step(powersource,opdir2)))
				if ((NCOC.tiledir == powersource.tiledir) && NCOC != powersource)
					if (!(powersource in NCOC.connections) && !list_cmp(powersource.connections, NCOC.connections))
						NCOC.connections += powersource
					if (!(NCOC in powersource.connections) && !list_cmp(powersource.connections, NCOC.connections))
						powersource.connections += NCOC
		user << "You connect the cable to the [src]."
	else
		..()


/obj/structure/lamp/update_icon()
	if (lamp_inside && !lamp_broken && on)
		icon_state = "[base_icon]_on"
	else if (lamp_inside && !lamp_broken && !on)
		icon_state = base_icon
	else if (!lamp_inside)
		icon_state = "[base_icon]_empty"
	else if (lamp_inside && lamp_broken)
		icon_state = "[base_icon]_broken"
/obj/structure/lamp/proc/do_light()
	if (!lamp_broken && lamp_inside)
		if (check_power() || powerneeded == 0)
			if (brightness_color)
				set_light(light_amt, 1, brightness_color)
			else
				set_light(light_amt)
			update_icon()
			powered = TRUE
			on = TRUE
		else
			set_light(0)
			update_icon()
			powered = FALSE
			on = FALSE
	else
		set_light(0)
		update_icon()
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


/obj/structure/lamp/bullet_act(var/obj/item/projectile/Proj)
	if (lamp_inside && !lamp_broken)
		visible_message("\The [src] shatters!")
		playsound(src, 'sound/effects/hit_on_shattered_glass.ogg', 70, TRUE)
//		new/obj/item/weapon/material/shard(loc)
		on = FALSE
		lamp_broken = TRUE
		icon_state = "[base_icon]_broken"
		update_icon()
//	if (powersource)
//		var/obj/structure/cable/CB = powersource
//		CB.connections -= src
//		powersource = null
//	qdel(src)
	..()

/obj/item/lightbulb
	name = "lightbulb"
	icon = 'icons/obj/lighting.dmi'
	icon_state = "lbulb"
	anchored = FALSE
	density = FALSE
	opacity = FALSE
	var/broken = FALSE
	var/ltype = "lbulb"
	flags = CONDUCT

/obj/item/lightbulb/broken
	name = "broken lightbulb"
	icon_state = "lbulb_broken"
	broken = TRUE

/obj/item/lightbulb/tube
	name = "light tube"
	icon_state = "ltube"
	ltype = "ltube"

/obj/item/lightbulb/tube/broken
	name = "broken light tube"
	icon_state = "ltube_broken"
	broken = TRUE

/obj/structure/lamp/attack_hand(mob/living/human/user as mob)
	if (lamp_inside)
		if (lamp_broken)
			user << "You remove the broken lightbulb."
			lamp_inside = FALSE
			lamp_broken = FALSE
			var/obj/item/lightbulb/broken/LP = new/obj/item/lightbulb/broken
			LP.ltype = ltype
			LP.icon_state = "[ltype]_broken"
			LP.update_icon()
			user.put_in_active_hand(LP)

		else
			user << "You remove the lightbulb."
			lamp_inside = FALSE
			var/obj/item/lightbulb/LP = new/obj/item/lightbulb
			LP.ltype = ltype
			LP.icon_state = "[ltype]"
			LP.update_icon()
			user.put_in_active_hand(LP)
		icon_state = "[base_icon]_empty"
		update_icon()
	else
		..()

/obj/structure/lamp/lamppost_small
	name = "small lamp post"
	desc = "A small lamp post, good for outdoor illumination."
	icon_state = "lamppost_small"
	powerneeded = 2
	light_amt = 6
/obj/structure/lamp/lamppost_small/alwayson
	powerneeded = 0
	on = TRUE
/obj/structure/lamp/streetlight
	name = "street light"
	desc = "A street light, good for illuminating the streets."
	icon = 'icons/obj/lighting_32x64.dmi'
	base_icon = "streetlight"
	icon_state = "streetlight"
	powerneeded = 3
	light_amt = 7
/obj/structure/lamp/streetlight/alwayson
	powerneeded = 0
	on = TRUE


/obj/structure/lamp/lamp_small
	name = "small lightbulb"
	desc = "A small lightbulb."
	icon_state = "bulb"
	base_icon = "bulb"
	powerneeded = 1
	light_amt = 3
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/lamp/lamp_small/broken
	lamp_broken= TRUE
	icon_state = "bulb_broken"

/obj/structure/lamp/lamp_small/alwayson
	powerneeded = 0
	on = TRUE
/obj/structure/lamp/lamp_small/alwayson/white
	brightness_color = "#ffffff"
/obj/structure/lamp/lamp_small/alwayson/red
	brightness_color = "#da0205"
/obj/structure/lamp/lamp_small/alwayson/space
	icon_state = "spacelights"
	base_icon = "spacelights"
	brightness_color = "bee9e4"
/obj/structure/lamp/lamp_small/tank
	powerneeded = 1
	var/obj/structure/engine/connection = null
	on = FALSE

/obj/structure/lamp/lamp_small/tank/check_power()
	if (!connection || powerneeded == 0)
		return FALSE
	else
		if (connection.on)
			if (!on)
				on = TRUE
			return TRUE
		else
			if (on)
				on = FALSE
			return FALSE

/obj/structure/lamp/lamp_small/tank/red
	icon_state = ""
	base_icon = ""
	brightness_color = "#da0205"

/obj/structure/lamp/lamp_small/tank/floodlight
	brightness_color = "#fff898"
	icon_state = ""
	base_icon = ""
	light_amt = 8

/obj/structure/lamp/lamp_small/tank/red/police
	name = "police lights"
	pixel_x=32
	update_icon()
		..()
		switch(dir)
			if(NORTH)
				pixel_x=-16
				pixel_y=0
			if(SOUTH)
				pixel_x=16
				pixel_y=0
			if(WEST)
				pixel_y=-16
				pixel_x=0
			if(EAST)
				pixel_y=16
				pixel_x=0
/obj/structure/lamp/lamp_small/tank/blue
	brightness_color = "#0202da"
/obj/structure/lamp/lamp_small/tank/blue/police
	name = "police lights"
	pixel_x=-32
	update_icon()
		..()
		switch(dir)
			if(NORTH)
				pixel_x=16
				pixel_y=0
			if(SOUTH)
				pixel_x=-16
				pixel_y=0
			if(WEST)
				pixel_y=16
				pixel_x=0
			if(EAST)
				pixel_y=-16
				pixel_x=0
/obj/structure/lamp/lamp_big
	name = "light tube"
	desc = "A light tube."
	icon_state = "tube"
	base_icon = "tube"
	powerneeded = 1.3
	light_amt = 4
	not_movable = FALSE
	not_disassemblable = FALSE
	ltype = "ltube"

/obj/structure/lamp/lamp_big/broken
	lamp_broken= TRUE
	icon_state = "tube_broken"

/obj/structure/lamp/lamp_big/alwayson
	powerneeded = 0
	on = TRUE
/obj/structure/lamp/lamp_big/alwayson/white
	brightness_color = "#ffffff"

/obj/structure/refinery
	name = "petroleum refinery"
	desc = "A petroleum refinery."
	icon = 'icons/obj/obj32x64.dmi'
	icon_state = "refinery"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/list/barrel = list()
	var/volume = 0
	var/volume_et = 0
	var/volume_di = 0
	var/maxvolume = 300
	var/active = FALSE
	var/product = "gasoline"
	powerneeded = 1

/obj/structure/refinery/attackby(var/obj/item/W as obj, var/mob/living/human/H as mob)
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
		if (!anchored)
			H << "<span class='notice'>Fix the refinery in place with a wrench first.</span>"
			return
		if (powersource)
			H << "There's already a cable connected here! Split it further from the [src]."
			return
		var/obj/item/stack/cable_coil/CC = W
		powersource = CC.place_turf(get_turf(src), H, turn(get_dir(H,src),180))
		if (powersource)
			powersource.connections += src

			var/opdir1 = 0
			var/opdir2 = 0
			if (powersource && powersource.tiledir == "horizontal")
				opdir1 = 4
				opdir2 = 8
			else if  (powersource && powersource.tiledir == "vertical")
				opdir1 = 1
				opdir2 = 2
			powersource.update_icon()

			if (opdir1 != 0 && opdir2 != 0)
				for(var/obj/structure/cable/NCOO in get_turf(get_step(powersource,opdir1)))
					if ((NCOO.tiledir == powersource.tiledir) && NCOO != powersource)
						if (!(powersource in NCOO.connections) && !list_cmp(powersource.connections, NCOO.connections))
							NCOO.connections += powersource
						if (!(NCOO in powersource.connections) && !list_cmp(powersource.connections, NCOO.connections))
							powersource.connections += NCOO
						H << "You connect the two cables."

				for(var/obj/structure/cable/NCOC in get_turf(get_step(powersource,opdir2)))
					if ((NCOC.tiledir == powersource.tiledir) && NCOC != powersource)
						if (!(powersource in NCOC.connections) && !list_cmp(powersource.connections, NCOC.connections))
							NCOC.connections += powersource
						if (!(NCOC in powersource.connections) && !list_cmp(powersource.connections, NCOC.connections))
							powersource.connections += NCOC
						H << "You connect the two cables."
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
			product = "gasoline"
			usr << "This refinery will now produce <b>Gasoline</b>."
			return
		else if (prod == "Diesel")
			product = "diesel"
			usr << "This refinery will now produce <b>Diesel</b>."
			return
/obj/structure/refinery/attack_hand(var/mob/living/human/H)
	if (active)
		active = FALSE
		powered = FALSE
		powersource.update_power(powerneeded,1)
		powersource.currentflow -= powerneeded
		powersource.lastupdate2 = world.time
		H << "You power off the refinery."
		return
	if (isemptylist(barrel))
		H << "<span class = 'notice'>There is no barrel to collect the refined products.</span>"
		return
	if (volume <= 0 && volume_di <= 0 && volume_et <= 0)
		H << "<span class = 'notice'>The refinery is empty! Put some precursors in first.</span>"
		return

	if (!active && powersource && !powersource.powered)
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
	if (active)
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
//////////////////////////////////////BIOFUELS////////////////////////////////////

/obj/structure/refinery/biofuel
	name = "biofuel refinery"
	desc = "A biofuel refinery, used to produce ethanol and biodiesel."
	maxvolume = 300
	product = "biodiesel"

/obj/structure/refinery/biofuel/attackby(var/obj/item/W as obj, var/mob/living/human/H as mob)
	if (istype(W, /obj/item/weapon/reagent_containers/glass/barrel))
		if (isemptylist(barrel))
			barrel += W
			H.drop_from_inventory(W)
			W.forceMove(locate(0,0,0))
			visible_message("[H] puts \the [W] in \the [src].","You put \the [W] in \the [src].")
			return
		else
			if (volume_et+volume_di >= maxvolume)
				H << "<span class = 'notice'>The refinery is full.</span>"
				return
			var/obj/item/weapon/reagent_containers/glass/barrel/C = W
			if (C.reagents.has_reagent("olive_oil",1))
				var/barrelamt = C.reagents.get_reagent_amount("olive_oil")
				if (barrelamt < (maxvolume-volume_di))
					C.reagents.remove_reagent("olive_oil",barrelamt)
					volume_di += barrelamt
					visible_message("[H] pours \the [W] into \the [src].","You pour [barrelamt] units of olive oil from \the [W] into \the [src].")
					if (volume_di+volume_et > maxvolume)
						volume_di = maxvolume-volume_et
					return
				else
					C.reagents.remove_reagent("olive_oil",(maxvolume-volume_di))
					volume_di += (maxvolume-volume_di)
					visible_message("[H] pours \the [W] into \the [src].","You pour [maxvolume-volume] units of olive oil from \the [W] into \the [src].")
					if (volume_di+volume_et > maxvolume)
						volume_di = maxvolume-volume_et
					return
			else if (C.reagents.has_reagent("ethanol",1))
				var/barrelamt = C.reagents.get_reagent_amount("ethanol")
				if (barrelamt < (maxvolume-volume_et))
					var/strength = 0
					var/maxetvol = 0
					for (var/datum/reagent/ethanol/E in C.reagents.reagent_list)
						maxetvol += E.volume
						strength += E.volume*E.strength
					if (maxetvol <= 0)
						H << "<span class = 'notice'>This [W] has no biofuel percursors in it!</span>"
						return
					strength /= maxetvol
					strength = 1-(strength/100)
					C.reagents.remove_reagent("ethanol",barrelamt)
					volume_et += barrelamt*strength
					visible_message("[H] pours \the [W] into \the [src].","You pour [barrelamt] units of unpurified ethanol from \the [W] into \the [src].")
					if (volume_di+volume_et > maxvolume)
						volume_di = maxvolume-volume_di
					return
				else
					C.reagents.remove_reagent("ethanol",(maxvolume-volume_et))
					volume_et += (maxvolume-volume_et)
					visible_message("[H] pours \the [W] into \the [src].","You pour [maxvolume-volume] units of unpurified ethanol from \the [W] into \the [src].")
					if (volume_di+volume_et > maxvolume)
						volume_et = maxvolume-volume_di
					return
			else if (C.reagents.has_reagent("fat_oil",1))
				var/barrelamt = C.reagents.get_reagent_amount("fat_oil")
				if (barrelamt < (maxvolume-volume_di))
					C.reagents.remove_reagent("fat_oil",barrelamt)
					volume_di += barrelamt
					visible_message("[H] pours \the [W] into \the [src].","You pour [barrelamt] units of olive oil from \the [W] into \the [src].")
					if (volume_di+volume_et > maxvolume)
						volume_di = maxvolume-volume_et
					return
				else
					C.reagents.remove_reagent("fat_oil",(maxvolume-volume_di))
					volume_di += (maxvolume-volume_di)
					visible_message("[H] pours \the [W] into \the [src].","You pour [maxvolume-volume] units of olive oil from \the [W] into \the [src].")
					if (volume_di+volume_et > maxvolume)
						volume_di = maxvolume-volume_et
					return
			else
				H << "<span class = 'notice'>This [W] has no biofuel percursors in it!</span>"
				return
	else if (istype(W, /obj/item/stack/cable_coil))
		if (!anchored)
			H << "<span class='notice'>Fix the refinery in place with a wrench first.</span>"
			return
		if (powersource)
			H << "There's already a cable connected here! Split it further from the [src]."
			return
		var/obj/item/stack/cable_coil/CC = W
		powersource = CC.place_turf(get_turf(src), H, turn(get_dir(H,src),180))
		powersource.connections += src

		var/opdir1 = 0
		var/opdir2 = 0
		if (powersource.tiledir == "horizontal")
			opdir1 = 4
			opdir2 = 8
		else if  (powersource.tiledir == "vertical")
			opdir1 = 1
			opdir2 = 2
		powersource.update_icon()

		if (opdir1 != 0 && opdir2 != 0)
			for(var/obj/structure/cable/NCOO in get_turf(get_step(powersource,opdir1)))
				if ((NCOO.tiledir == powersource.tiledir) && NCOO != powersource)
					if (!(powersource in NCOO.connections) && !list_cmp(powersource.connections, NCOO.connections))
						NCOO.connections += powersource
					if (!(NCOO in powersource.connections) && !list_cmp(powersource.connections, NCOO.connections))
						powersource.connections += NCOO
					H << "You connect the two cables."

			for(var/obj/structure/cable/NCOC in get_turf(get_step(powersource,opdir2)))
				if ((NCOC.tiledir == powersource.tiledir) && NCOC != powersource)
					if (!(powersource in NCOC.connections) && !list_cmp(powersource.connections, NCOC.connections))
						NCOC.connections += powersource
					if (!(NCOC in powersource.connections) && !list_cmp(powersource.connections, NCOC.connections))
						powersource.connections += NCOC
					H << "You connect the two cables."
		H << "You connect the cable to the [src]."

	else
		..()


/obj/structure/refinery/biofuel/set_product()
	set category = null
	set name = "Set Output"
	set src in range(1, usr)

	if (active)
		usr << "<span class = 'notice'>You need to shut the refinery down first!</span>"
		return
	else
		var/prod = WWinput(usr, "What to produce?", "Refinery", "Cancel", list("Ethanol","Biodiesel","Cancel"))
		if (prod == "Cancel")
			return
		else if (prod == "Ethanol")
			product = "ethanol"
			usr << "This refinery will now produce <b>Ethanol</b>."
			return
		else if (prod == "Biodiesel")
			product = "biodiesel"
			usr << "This refinery will now produce <b>Biodiesel</b>."
			return


/obj/structure/refinery/biofuel/refine()
	if (powered && active && (volume_di > 0 || volume_et > 0) && !isemptylist(barrel))
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
		if (volume_et < 0)
			volume_et = 0
		if (volume_di < 0)
			volume_di = 0
		if (product == "ethanol")
			if (volume_et < 10)
				amt = volume_et
			volume_et -= amt
			barrel[1].reagents.add_reagent("pethanol",amt)
		else if (product == "biodiesel")
			if (volume_di < 10)
				amt = volume_di
			volume_di -= amt
			barrel[1].reagents.add_reagent("biodiesel",0.7*amt)
		else // default to diesel
			if (volume_di < 10)
				amt = volume_di
			volume_di -= amt
			barrel[1].reagents.add_reagent("biodiesel",0.7*amt)
		spawn(600)
			refine()
		return
	else
		update_icon()
		return

////////////////////////bakelizer (plastic maker)///////////////////

/obj/structure/bakelizer
	name = "bakelizer"
	desc = "A machine used to transform petroleum into plastics."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "bakelizer"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/list/barrel = list()
	var/volume = 0
	var/active = FALSE
	var/plastic = 0
	powerneeded = 1

/obj/structure/bakelizer/attackby(var/obj/item/W as obj, var/mob/living/human/H as mob)
	if (istype(W, /obj/item/weapon/reagent_containers))
		var/obj/item/weapon/reagent_containers/C = W
		if (C.reagents.has_reagent("petroleum",1))
			var/barrelamt = C.reagents.get_reagent_amount("petroleum")
			C.reagents.remove_reagent("petroleum",barrelamt)
			volume += barrelamt
			visible_message("[H] pours \the [W] into \the [src].","You pour [barrelamt] units of petroleum from \the [W] into \the [src].")
			desc = "A machine used to transform petroleum into plastics. Has [volume] petroleum and [plastic] plastic sheets inside."
			return
		else
			H << "<span class = 'notice'>This [W] has no crude petroleum in it!</span>"
			return
	else if (istype(W, /obj/item/stack/cable_coil))
		if (!anchored)
			H << "<span class='notice'>Fix the bakelizer in place with a wrench first.</span>"
			return
		if (powersource)
			H << "There's already a cable connected here! Split it further from the [src]."
			return
		var/obj/item/stack/cable_coil/CC = W
		powersource = CC.place_turf(get_turf(src), H, turn(get_dir(H,src),180))
		powersource.connections += src

		var/opdir1 = 0
		var/opdir2 = 0
		if (powersource.tiledir == "horizontal")
			opdir1 = 4
			opdir2 = 8
		else if  (powersource.tiledir == "vertical")
			opdir1 = 1
			opdir2 = 2
		powersource.update_icon()

		if (opdir1 != 0 && opdir2 != 0)
			for(var/obj/structure/cable/NCOO in get_turf(get_step(powersource,opdir1)))
				if ((NCOO.tiledir == powersource.tiledir) && NCOO != powersource)
					if (!(powersource in NCOO.connections) && !list_cmp(powersource.connections, NCOO.connections))
						NCOO.connections += powersource
					if (!(NCOO in powersource.connections) && !list_cmp(powersource.connections, NCOO.connections))
						powersource.connections += NCOO
					H << "You connect the two cables."

			for(var/obj/structure/cable/NCOC in get_turf(get_step(powersource,opdir2)))
				if ((NCOC.tiledir == powersource.tiledir) && NCOC != powersource)
					if (!(powersource in NCOC.connections) && !list_cmp(powersource.connections, NCOC.connections))
						NCOC.connections += powersource
					if (!(NCOC in powersource.connections) && !list_cmp(powersource.connections, NCOC.connections))
						powersource.connections += NCOC
					H << "You connect the two cables."
		H << "You connect the cable to the [src]."

	else
		..()


/obj/structure/bakelizer/attack_hand(var/mob/living/human/H)
	if (active)
		active = FALSE
		powered = FALSE
		powersource.update_power(powerneeded,1)
		powersource.currentflow -= powerneeded
		powersource.lastupdate2 = world.time
		H << "You power off the [src]."
		update_icon()
		return
	if (volume < 1)
		H << "<span class = 'notice'>The bakelizer is empty! Put some crude petroleum in first.</span>"
		return

	if (!active && !powersource.powered)
		H << "<span class = 'notice'>There is not enough power to start the [src].</span>"
		update_icon()
		return
	else if (!active && powersource.powered && ((powersource.powerflow-powersource.currentflow) >= powerneeded))
		active = TRUE
		powered = TRUE
		powersource.update_power(powerneeded,1)
		powersource.currentflow += powerneeded
		powersource.lastupdate2 = world.time
		power_on()
		H << "You power the [src]."
		update_icon()
		return
	else
		H << "<span class = 'notice'>There is not enough power to start the [src].</span>"
		return
/obj/structure/bakelizer/proc/power_on()
	if (powered && active)
		update_icon()
		spawn(600)
			refine()
	else
		update_icon()
		return


/obj/structure/bakelizer/proc/refine()
	if (!powered || !active)
		return
	if (volume <= 0)
		volume = 0
		desc = "A machine used to transform petroleum into plastics. Has [volume] petroleum and [plastic] plastic sheets inside."
		return
	else if (volume >= 5)
		volume-=5
		plastic+=1
		desc = "A machine used to transform petroleum into plastics. Has [volume] petroleum and [plastic] plastic sheets inside."
		spawn(600)
			refine()
		return
/obj/structure/bakelizer/verb/empty()
	set category = null
	set name = "Remove Plastic"
	set src in range(1, usr)

	if (!plastic)
		usr << "Theres no finished plastic in the [src]."
		desc = "A machine used to transform petroleum into plastics. Has [volume] petroleum and 0 plastic sheets inside."
		return
	else if (plastic <= 0)
		plastic = 0
		desc = "A machine used to transform petroleum into plastics. Has [volume] petroleum and 0 plastic sheets inside."
		return
	else if (plastic > 0)
		var/obj/item/stack/material/plastic/P = new/obj/item/stack/material/plastic(get_turf(src))
		P.amount = plastic
		plastic = 0
		desc = "A machine used to transform petroleum into plastics. Has [volume] petroleum and 0 plastic sheets inside."
		return
/obj/structure/bakelizer/update_icon()
	if (active)
		icon_state = "bakelizer_on"
	else
		icon_state = "bakelizer"

/obj/structure/shopping_cart
	name = "shopping cart"
	desc = "A metal shopping cart."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "shopping_cart"
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	anchored = FALSE
	density = TRUE
	opacity = FALSE
	var/obj/item/weapon/storage/internal/storage
	var/max_storage = 6
/obj/structure/shopping_cart/update_icon()
	overlays.Cut()
	for (var/obj/item/I in storage)
		var/image/IM = image(I.icon, I.icon_state, layer=src.layer-0.1)
		var/matrix/M = matrix()
		M.Scale(0.7)
		IM.transform = M
		overlays += IM
	..()

/obj/structure/shopping_cart/New()
	..()
	storage = new/obj/item/weapon/storage/internal(src)
	storage.storage_slots = max_storage
	storage.max_w_class = 5
	storage.max_storage_space = max_storage*5
	update_icon()
/obj/structure/shopping_cart/Destroy()
	qdel(storage)
	storage = null
	..()

/obj/structure/shopping_cart/attack_hand(mob/user as mob)
	if (istype(user, /mob/living/human) && user in range(1,src))
		storage.open(user)
		update_icon()
	else
		return
/obj/structure/shopping_cart/MouseDrop(obj/over_object as obj)
	if (storage.handle_mousedrop(usr, over_object))
		..(over_object)
		update_icon()

/obj/structure/shopping_cart/attackby(obj/item/W as obj, mob/user as mob)
	..()
	storage.attackby(W, user)
	update_icon()
///////////////////////////////////////////////////////////////////////////////Katana Wall Stand////////////////////////
/obj/structure/katana_stand
	name = "katana display"
	desc = "A display for a katana mounted to a wall."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "katana_stand"
	item_state = "katana_stand"
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	var/obj/item/weapon/storage/internal/storage
	var/max_storage = 3
	New()
		..()
		storage.can_hold = list(/obj/item/clothing/accessory/storage/sheath/katana, /obj/item/clothing/accessory/storage/sheath/katana/full, /obj/item/weapon/material/sword/katana)

/obj/structure/katana_stand/update_icon()
	if (storage.contents.len > 0)
		icon_state = "katana_stand1"
	else
		icon_state = "katana_stand"

/obj/structure/katana_stand/New()
	..()
	storage = new/obj/item/weapon/storage/internal(src)
	storage.storage_slots = 1
	storage.max_w_class = 3
	storage.max_storage_space = max_storage*3
	update_icon()

/obj/structure/katana_stand/Destroy()
	qdel(storage)
	storage = null
	..()

/obj/structure/katana_stand/attack_hand(mob/user as mob)
	if (istype(user, /mob/living/human) && user in range(1,src))
		storage.open(user)
		update_icon()
	else
		return

/obj/structure/katana_stand/MouseDrop(obj/over_object as obj)
	if (storage.handle_mousedrop(usr, over_object))
		..(over_object)
		update_icon()

/obj/structure/katana_stand/attackby(obj/item/W as obj, mob/user as mob)
	..()
	storage.attackby(W, user)
	update_icon()

/obj/structure/katana_stand/full

/obj/structure/katana_stand/full/New()
	..()
	new /obj/item/weapon/material/sword/katana(src)

/obj/structure/floodlight //Works in the basic way, will need more coding for powersupply, being destroyable, etc.
	name = "floodlight"
	desc = "A floodlight, good for outdoor illumination in dark conditions."
	icon ='icons/obj/lighting.dmi'
	icon_state = "floodlight"
	var/floodlighton = 0
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	powerneeded = 0

/obj/structure/floodlight/on
	New()
		..()
		floodlighton = 1
		set_light (8)
		icon_state ="floodlight_on"

/obj/structure/floodlight/Destroy()
	set_light (0)
	..()

/obj/structure/floodlight/attack_hand(var/mob/living/human/H)
	if (floodlighton == 0)
		floodlighton = 1
		set_light (8)
		icon_state ="floodlight_on"
		playsound (loc, 'sound/effects/Custom_flashlight.ogg', 75, TRUE)
	else
		floodlighton = 0
		set_light (0)
		icon_state ="floodlight"
		playsound (loc, 'sound/effects/Custom_flashlight.ogg', 75, TRUE)


/obj/structure/metal_detector
	name = "walkthrough metal detector"
	desc = "Detects metallic objects when people pass through it."
	icon ='icons/obj/modern_structures.dmi'
	icon_state = "metal_detector1"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	layer = 2.99 //below doors
	powerneeded = 0
	var/on = TRUE

	New()
		..()
		if (on)
			set_light(2, 0.5, "#62cc53")
		else
			set_light(0)

	proc/toggle()
		if (on)
			on = FALSE
			icon_state = "metal_detector"
		else
			on = TRUE
			icon_state = "metal_detector1"

	proc/checkmob(mob/living/human/H)
		if (!on)
			return FALSE
		if (!H)
			return FALSE
		for(var/obj/item/I in H)
			if(I.flags & CONDUCT)
				return TRUE
			for(var/obj/item/I1	in I)
				if(I1.flags & CONDUCT)
					return TRUE
				for(var/obj/item/I2	in I1)
					if(I2.flags & CONDUCT)
						return TRUE
					for(var/obj/item/I3	in I2)
						if(I3.flags & CONDUCT)
							return TRUE
		return FALSE

	Crossed(AM as mob)
		if (isobserver(AM)) return
		if (istype(AM, /obj/item/projectile)) return
		if (ishuman(AM))
			trigger(AM)

	Bumped(AM as mob)
		if (isobserver(AM)) return
		if (istype(AM, /obj/item/projectile)) return
		if (ishuman(AM))
			trigger(AM)

	proc/trigger(mob/living/human/H)
		if (!H)
			return
		if (checkmob(H))
			bleep()

	proc/bleep()
		icon_state = "metal_detector2"
		playsound(loc, 'sound/machines/metal_detector.ogg', 100, 0)
		set_light(2, 0.5,"#ce3535")
		spawn(30)
			icon_state = "metal_detector1"
			set_light(2, 0.5, "#62cc53")

	attack_hand(mob)
		if (!ishuman(mob))
			return
		if(!on)
			on = TRUE
			visible_message("[mob] turns the metal detector on.","You turn the metal detector on.")
			set_light(2, 0.5, "#62cc53")
		else
			visible_message("<span class='warning'>[mob] is trying to turn the metal detector off!</span>","You start turning the metal detector off...")
			if(do_after(mob, 50, src))
				visible_message("<span class='warning'>[mob] turns the metal detector off.</span>","You turn the metal detector off.")
				on = FALSE
				set_light(0)