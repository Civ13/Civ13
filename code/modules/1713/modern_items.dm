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

/obj/structure/lamp/New()
	..()
	do_light()

/obj/structure/lamp/attackby(obj/item/weapon/W as obj, mob/user as mob)
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


/obj/structure/lamp/proc/do_light()
	if (check_power() || powerneeded == 0)
		if (brightness_color)
			set_light(light_amt, 1, brightness_color)
		else
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

/obj/structure/lamp/lamp_small/alwayson
	powerneeded = 0
	on = TRUE
/obj/structure/lamp/lamp_small/alwayson/red
	brightness_color = "#da0205"

/obj/structure/lamp/lamp_big
	name = "light tube"
	desc = "A light tube."
	icon_state = "tube"
	base_icon = "tube"
	powerneeded = 1.3
	light_amt = 4
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/lamp/lamp_big/alwayson
	powerneeded = 0
	on = TRUE

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
	powerneeded = 1

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


/obj/structure/fuelpump
	name = "fuel pump"
	desc = "A fuel pump. You need to pay to use it."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "oilpump1"
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE

	var/price = 0 //price per unit
	var/fueltype = "none"

	var/maxvol = 300 //maximum fuel inside
	var/vol = 0 //current fuel inside
	var/unlockedvol = 0 //fuel that can be withdrown, after purchase
	var/list/storedval = list() //money inside
	var/unlocked = 0

	var/keycode = "0000"
	var/customcolor = 0

/obj/structure/fuelpump/n
	icon_state = "oilpump3"

/obj/structure/fuelpump/s
	icon_state = "oilpump4"

/obj/structure/fuelpump/small
	icon_state = "oilpump2"

/obj/structure/fuelpump/star
	icon_state = "oilpump1"

/obj/structure/fuelpump/proc/updatedesc()
	desc = "This pump has [vol] units of [fueltype] available. Price: [price*10] silver coins per unit. Copper and Gold accepted too."

/obj/structure/fuelpump/proc/do_color()
	if (customcolor)
		var/image/colorov = image("icon" = icon, "icon_state" = "[icon_state]mask")
		colorov.color = customcolor
		overlays += colorov

/obj/structure/fuelpump/attack_hand(var/mob/living/carbon/human/user)
	if (unlocked)
		if (unlockedvol>0)
			var/ch3 = WWinput("This pump still has [unlockedvol] inside! Are you sure you want to finish?","[name]","No",list("No","Yes"))
			if (ch3 == "Yes")
				unlocked = 0
				unlockedvol = 0
				return
			else
				return
		else
			user << "You lock the pump, finishing the transaction."
			unlocked = 0
			unlockedvol = 0
			return

/obj/structure/fuelpump/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/key))
		if (unlocked)
			user << "The pump is being used! Finish it first."
			return
		if (W.code == keycode)
			var/input = WWinput(user, "What do you want to do?", "Fuel Pump Management", "Cancel", list("Withdraw Money", "Change Name", "Change Fuel", "Change Price", "Cancel"))
			if (input == "Cancel")
				return

			else if (input == "Withdraw Money")
				if (isemptylist(storedval))
					user << "<span class = 'notice'>The [src] has no money inside!</span>"
					return
				else
					for (var/obj/OB in storedval)
						OB.forceMove(get_turf(user))
						storedval -= OB
						user << "You empty the safe."
						return
			else if (input == "Change Name")
				var/custn = input(user, "Choose a name for this pump:") as text|null
				if (custn == "" || custn == null)
					return
				else
					name = custn
					updatedesc()
					return
			else if (input == "Change Fuel")
				if (vol > 0)
					user << "<span class = 'notice'>The [src] still has fuel inside! Empty it before changing!</span>"
					return
				else
					var/choice = WWinput(user, "What fuel to set this pump to?", "Fuel Pump Management", "cancel", list("cancel","gasoline","diesel","biodiesel","ethanol","petroleum"))
					if (choice == "cancel")
						return
					else
						fueltype = choice
						updatedesc()
						return
			else if (input == "Change Price")
				var/custp = input(user, "What should the price be, in silver coins? Will be automatically converted. (Default: 3. Min: 0, Max: 500):") as num|null
				if (!isnum(custp))
					return
				if (custp < 0)
					custp = 0
				else if (custp > 500)
					custp = 500
				price = (custp/10) //to standartize
				updatedesc()
			else
				return
		else
			user << "<span class = 'notice'>The key doesn't match this lock!</span>"
			return
	else if (istype(W, /obj/item/stack/money))
		if (unlocked)
			user << "The pump is being used! Finish it first."
			return
		var/obj/item/stack/money/MN = W
		var/valp = MN.amount*MN.value
		if ((valp/price) <= vol)
			var/ch2 = WWinput(user, "You can buy [(valp/price)] units of [fueltype] with this amount. Confirm?", "[name]", "No", list("No","Yes"))
			if (ch2 == "No")
				return
			else if (ch2 == "Yes" && (user.l_hand == W || user.r_hand == W))
				user.drop_from_inventory(W)
				storedval += W
				W.forceMove(locate(0,0,0))
				unlockedvol = (valp/price)
				user << "<span class = 'notice'>You can now withdraw [unlockedvol] units of [fueltype] from this pump.</span>"
				unlocked = 1
				return
			else
				return
		else
			user << "<span class = 'notice'>The fuelpump doesn't have that much fuel inside! Try with a smaller amount. This pump has [vol] units of [fueltype] inside.</span>"

	else if (istype(W, /obj/item/weapon/reagent_containers/glass))
		var/obj/item/weapon/reagent_containers/glass/GC = W
		if (fueltype == "none")
			user << "This fuel pump has no associated fuel type."
			return
		if (unlocked && unlockedvol<=0)
			unlockedvol = 0
			user << "All the paid for fuel has been used. Finish the transaction."
			updatedesc()
			return
		if (unlocked && unlockedvol>0)
			var/avvol = GC.reagents.maximum_volume-GC.reagents.total_volume
			if (unlockedvol <= avvol)
				vol -= unlockedvol
				GC.reagents.add_reagent(fueltype,unlockedvol)
				user << "You fill the [GC] with all the purchased [fueltype]."
				unlockedvol = 0
				updatedesc()
				return
			else if (unlockedvol > avvol)
				unlockedvol -= avvol
				vol -= avvol
				GC.reagents.add_reagent(fueltype,avvol)
				user << "You fill the [GC] completely. There are [unlockedvol] units remanining in the pump."
				updatedesc()
				return

		if (!unlocked)
			if (vol < maxvol)
				if (GC.reagents.has_reagent(fueltype))
					if (GC.reagents.get_reagent_amount(fueltype)<= maxvol-vol)
						vol += (GC.reagents.get_reagent_amount(fueltype))
						GC.reagents.del_reagent(fueltype)
						user << "You empty \the [W] into \the [src]."
						updatedesc()
						return
					else
						var/amttransf = maxvol-vol
						vol += amttransf
						GC.reagents.remove_reagent(fueltype,amttransf)
						user << "You fill \the [src] completly with \the [W]."
						updatedesc()
						return
				else
					user << "\The [W] has no [fueltype] in it."
					return
			else
				user << "\The [src] is already full."
				return
	else
		..()