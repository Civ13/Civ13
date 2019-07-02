/obj/structure/oven
	name = "Oven"
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "oven"
	layer = 2.9
	density = TRUE
	anchored = TRUE
	flags = OPENCONTAINER | NOREACT
	var/base_state = "oven"
	var/on = FALSE
	var/max_space = 7
	var/fuel = 0
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/oven/update_icon()
	if (on)
		icon_state = "[base_state]_on"
	else
		icon_state = base_state

/obj/structure/oven/attackby(var/obj/item/I, var/mob/living/carbon/human/H)
	if (!istype(H))
		return
	if (istype(I, /obj/item/weapon/reagent_containers/glass/small_pot))
		var/obj/item/weapon/reagent_containers/glass/small_pot/POT = I
		H << "You place the [POT] on top of the [src]."
		H.remove_from_mob(POT)
		POT.loc = src.loc
		POT.on_stove = TRUE
		return
	if (istype(I, /obj/item/stack/material/wood))
		fuel += I.amount
		qdel(I)
		return
	if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/poo))
		fuel += 0.5
		qdel(I)
		return
	else if (istype(I, /obj/item/weapon/wrench) || (istype(I, /obj/item/weapon/hammer)))
		if (istype(I, /obj/item/weapon/wrench))
			visible_message("<span class='warning'>[H] starts to [anchored ? "unsecure" : "secure"] \the [src] [anchored ? "from" : "to"] the ground.</span>")
			playsound(src, 'sound/items/Ratchet.ogg', 100, TRUE)
			if (do_after(H,50,src))
				visible_message("<span class='warning'>[H] [anchored ? "unsecures" : "secures"] \the [src] [anchored ? "from" : "to"] the ground.</span>")
				anchored = !anchored
				return
		else if (istype(I, /obj/item/weapon/hammer))
			visible_message("<span class='warning'>[H] starts to deconstruct \the [src].</span>")
			playsound(src, 'sound/items/Ratchet.ogg', 100, TRUE)
			if (do_after(H,50,src))
				visible_message("<span class='warning'>[H] deconstructs \the [src].</span>")
				empty()
				qdel(src)
				return
	else if (istype(I, /obj/item/stack/ore/coal))
		fuel += I.amount*3
		qdel(I)
		return
	var/space = max_space
	for (var/obj/item/II in contents)
		space -= II.w_class
	if (space <= 0 || space - I.w_class < 0)
		H << "<span class = 'warning'>The [name] is full.</span>"
		return
	H.remove_from_mob(I)
	I.loc = src
	visible_message("<span class = 'notice'>[H] puts [I] in the [name].</span>")

// todo: fix eggs not roasting & roasted meat sandwiches turning to burnt mess
/obj/structure/oven/attack_hand(var/mob/living/carbon/human/H)
	if (!on && fuel > 0)
		visible_message("<span class = 'notice'>[H] turns the [name] on.</span>")
		on = TRUE
		fuel -=1
		update_icon()
		if (name == "campfire")
			set_light(5)
		else if (name == "wood stove")
			set_light(1)
		else
			set_light(2)
		spawn (50)
			on = FALSE
			set_light(0)
			update_icon()
			visible_message("<span class = 'notice'>The [name] finishes cooking.</span>")
			process()
			for (var/obj/item/weapon/reagent_containers/glass/small_pot/I in get_turf(src))
				if (istype(I, /obj/item/weapon/reagent_containers/glass/small_pot) && I.on_stove == TRUE)
					I.on_stove = FALSE
					I.reagents.del_reagent("food_poisoning")
					I.reagents.del_reagent("cholera")
					return
	else
		H << "<span class = 'warning'>The [name] doesn't have enough fuel! Fill it with wood or coal.</span>"

/obj/structure/oven/process()
	for (var/obj/item/I in contents)
		if (istype(I, /obj/item/stack/ore))
			if (istype(I, /obj/item/stack/ore/diamond))
				var/obj/item/stack/material/diamond/NO = new/obj/item/stack/material/diamond(src)
				NO.amount = I.amount
				contents += NO
				contents -= I
				qdel(I)
			else if (istype(I, /obj/item/stack/ore/glass))
				var/obj/item/stack/material/glass/NO = new/obj/item/stack/material/glass(src)
				NO.amount = I.amount
				contents += NO
				contents -= I
				qdel(I)
			else if (istype(I, /obj/item/stack/ore/gold))
				var/obj/item/stack/material/gold/NO = new/obj/item/stack/material/gold(src)
				NO.amount = I.amount
				contents += NO
				contents -= I
				qdel(I)
			else if (istype(I, /obj/item/stack/ore/silver))
				var/obj/item/stack/material/silver/NO = new/obj/item/stack/material/silver(src)
				NO.amount = I.amount
				contents += NO
				contents -= I
				qdel(I)
			else if (istype(I, /obj/item/stack/ore/iron))
				var/obj/item/stack/material/iron/NO = new/obj/item/stack/material/iron(src)
				NO.amount = I.amount
				contents += NO
				contents -= I
				qdel(I)
			else if (istype(I, /obj/item/stack/ore/copper))
				var/obj/item/stack/material/copper/NO = new/obj/item/stack/material/copper(src)
				NO.amount = I.amount
				contents += NO
				contents -= I
				qdel(I)
			else if (istype(I, /obj/item/stack/ore/tin))
				var/obj/item/stack/material/tin/NO = new/obj/item/stack/material/tin(src)
				NO.amount = I.amount
				contents += NO
				contents -= I
				qdel(I)
			else if (istype(I, /obj/item/stack/ore/lead))
				var/obj/item/stack/material/lead/NO = new/obj/item/stack/material/lead(src)
				NO.amount = I.amount
				contents += NO
				contents -= I
				qdel(I)
		else if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/dough))
			contents += new /obj/item/weapon/reagent_containers/food/snacks/sliceable/bread(src)
			contents -= I
			qdel(I)
		else if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/sliceable/flatdough))
			contents += new /obj/item/weapon/reagent_containers/food/snacks/flatbread(src)
			contents -= I
			qdel(I)
		else if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/rawsticks))
			contents += new /obj/item/weapon/reagent_containers/food/snacks/fries(src)
			contents -= I
			qdel(I)
		else if (istype(I, /obj/item/weapon/clay))
			var/obj/item/weapon/clay/CL = I
			contents += new CL.result(src)
			if (CL.result == /obj/item/weapon/clay/claybricks/fired)
				contents += new CL.result(src)
			contents -= I
			qdel(I)

		else if (!istype(I, /obj/item/weapon/reagent_containers/food) || istype(I, /obj/item/weapon/reagent_containers/food/drinks) || istype(I, /obj/item/weapon/reagent_containers/food/snacks/badrecipe) || I.name == "Stew" || findtext(I.name, "soup") || (I.vars.Find("roasted") && I:roasted))
			if (!istype(I, /obj/item/organ))
				contents += new /obj/item/weapon/reagent_containers/food/snacks/badrecipe(src)
				contents -= I
				qdel(I)
			else
				var/obj/item/weapon/reagent_containers/food/snacks/organ/organ = new /obj/item/weapon/reagent_containers/food/snacks/organ(src)
				organ.name = "roasted [I.name]"
				organ.desc = I.desc
				organ.icon = I.icon
				organ.icon_state = I.icon_state
				organ.color = "#E59400"
				organ.reagents.multiply_reagent("nutriment", 5)
				organ.reagents.multiply_reagent("protein", 3)
				organ.reagents.del_reagent("toxin")
				organ.reagents.del_reagent("cholera")
				organ.reagents.del_reagent("food_poisoning")
				organ.roasted = TRUE
				contents -= I
				qdel(I)

		else
			I.name = replacetext(I.name, "raw ", "")
			I.desc = replacetext(I.desc, "raw", "roasted")
			I.name = "roasted [I.name]"
			I.color = "#E59400"
			I.reagents.multiply_reagent("nutriment", 5)
			I.reagents.multiply_reagent("protein", 3)
			I.reagents.del_reagent("food_poisoning")
			I.reagents.del_reagent("cholera")
			if (istype(I, /obj/item/weapon/reagent_containers/food))
				var/obj/item/weapon/reagent_containers/food/F = I
				F.roasted = TRUE
				F.raw = FALSE
				F.satisfaction = abs(F.satisfaction*2)

	for (var/obj/item/I in contents)
		I.loc = get_turf(src)

/obj/structure/oven/fireplace
	name = "campfire"
	desc = "A campfire made with wood logs."
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "fireplace"
	layer = 2.9
	density = FALSE
	anchored = TRUE
	flags = OPENCONTAINER | NOREACT
	base_state = "fireplace"
	on = FALSE
	max_space = 5
	fuel = 4

/obj/structure/oven/fireplace/proc/smoke_signals()
	for (var/mob/living/carbon/human/HH in range(25,src))
		if (!HH.blinded && !HH.paralysis && HH.sleeping <= 0 && HH.stat == 0)
			var/currdir = "somewhere"
			if (z == HH.z)
				if (y < HH.y)
					currdir = "south"
				if (y > HH.y)
					currdir = "north"
				if (y == HH.y)
					currdir = ""
				if (x <= HH.x)
					currdir = "[currdir]west"
				if (x > HH.x)
					currdir = "[currdir]east"
				if (x == HH.x)
					currdir = ""
			if (currdir != "somewhere" && currdir != "")
				HH << "You see some smoke signals [currdir] of you..."

/obj/structure/oven/fireplace/attackby(var/obj/item/I, var/mob/living/carbon/human/H)
	if (on && (istype(I, /obj/item/stack/material/leather) || istype(I, /obj/item/stack/material/cloth)))
		H << "You produce some smoke signals."
		smoke_signals()
	else
		..()
/obj/structure/oven/fireplace/Crossed(mob/living/carbon/M as mob)
	if (icon_state == "[base_state]_on" && ishuman(M))
		M.apply_damage(rand(2,4), BURN, "l_leg")
		M.apply_damage(rand(2,4), BURN, "r_leg")
		visible_message("<span class = 'warning'>[M] gets burnt by the [name]!</span>")


/obj/structure/oven/verb/empty()
	set category = null
	set name = "Empty"
	set src in range(1, usr)
	for (var/obj/item/I in contents)
		I.loc = get_turf(src)


/obj/structure/furnace
	name = "furnace"
	desc = "An industrial furnace, used to smelter minerals."
	icon = 'icons/obj/structures.dmi'
	icon_state = "brick_furnace"
	layer = 2.9
	density = TRUE
	anchored = TRUE
	flags = OPENCONTAINER | NOREACT
	var/base_state = "brick_furnace"
	var/on = FALSE
	var/max_space = 6
	var/fuel = 0
	var/iron = 0
	var/copper = 0
	var/tin = 0
	not_movable = TRUE
	not_disassemblable = FALSE

/obj/structure/furnace/update_icon()
	if (on)
		icon_state = "[base_state]_on"
	else
		icon_state = base_state

/obj/structure/furnace/attackby(var/obj/item/I, var/mob/living/carbon/human/H)
	if (!istype(H))
		return
	if (H.a_intent == I_HELP)
		if (istype(I, /obj/item/weapon/wrench) || (istype(I, /obj/item/weapon/hammer)))
			if (istype(I, /obj/item/weapon/wrench))
				visible_message("<span class='warning'>[H] starts to [anchored ? "unsecure" : "secure"] \the [src] [anchored ? "from" : "to"] the ground.</span>")
				playsound(src, 'sound/items/Ratchet.ogg', 100, TRUE)
				if (do_after(H,50,src))
					visible_message("<span class='warning'>[H] [anchored ? "unsecures" : "secures"] \the [src] [anchored ? "from" : "to"] the ground.</span>")
					anchored = !anchored
					return
			else if (istype(I, /obj/item/weapon/hammer))
				visible_message("<span class='warning'>[H] starts to deconstruct \the [src].</span>")
				playsound(src, 'sound/items/Ratchet.ogg', 100, TRUE)
				if (do_after(H,50,src))
					visible_message("<span class='warning'>[H] deconstructs \the [src].</span>")
					empty()
					qdel(src)
					return
		if (istype(I, /obj/item/stack/))
			if (istype(I, /obj/item/stack/material/wood))
				fuel += I.amount
				qdel(I)
				return
			else if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/poo))
				fuel += 0.5
				qdel(I)
				return
			else if (istype(I, /obj/item/stack/ore/coal))
				fuel += I.amount*3
				qdel(I)
				return
			else if (istype(I, /obj/item/stack/ore/iron) || istype(I, /obj/item/stack/material/iron))
				iron += I.amount
				qdel(I)
				return
			else if (istype(I, /obj/item/stack/ore/copper) || istype(I, /obj/item/stack/material/copper))
				copper += I.amount
				qdel(I)
				return
			else if (istype(I, /obj/item/stack/ore/tin) || istype(I, /obj/item/stack/material/tin))
				tin += I.amount
				qdel(I)
				return
			else
				H << "<span class = 'warning'>You can't smelt this.</span>"
				return
			var/space = max_space
			for (var/obj/item/II in contents)
				space -= II.w_class
			if (space <= 0 || space - I.w_class < 0)
				H << "<span class = 'warning'>\The [name] is full.</span>"
				return
			H.remove_from_mob(I)
			I.loc = src
			visible_message("<span class = 'notice'>[H] puts [I] in \the [name].</span>")
		else if (istype(I, /obj/item/weapon/material))
			var/obj/item/weapon/material/MT = I
			if (MT.get_material_name() == "wood")
				fuel += 1
				H << "You break \the [MT] and put it into the [src], refueling it."
				qdel(I)
			else if (MT.get_material_name() == "bronze")
				H << "You smelt \the [MT] into bronze ingots."
				new/obj/item/stack/material/bronze(src.loc)
				qdel(I)
			else if (MT.get_material_name() == "copper")
				H << "You smelt \the [MT] into copper ingots."
				new/obj/item/stack/material/copper(src.loc)
				qdel(I)
			else if (MT.get_material_name() == "tin")
				H << "You smelt \the [MT] into tin ingots."
				new/obj/item/stack/material/tin(src.loc)
				qdel(I)
			else if (MT.get_material_name() == "iron")
				H << "You smelt \the [MT] into iron ingots."
				new/obj/item/stack/material/iron(src.loc)
				qdel(I)
			else if (MT.get_material_name() == "steel")
				H << "You smelt \the [MT] into steel sheets."
				new/obj/item/stack/material/steel(src.loc)
				qdel(I)
		else if (istype(I, /obj/item) && I.basematerials.len)
			H << "You put \the [I] into \the [src] to recycle it."
			if (I.basematerials[1] == "tin")
				tin += I.basematerials[2]
			qdel(I)

		else
			..()
	else
		..()

/obj/structure/furnace/attack_hand(var/mob/living/carbon/human/H)
	if (!on && fuel > 1)
		visible_message("<span class = 'notice'>[H] turns the [name] on.</span>")
		on = TRUE
		fuel -=2
		update_icon()
		spawn (110)
			on = FALSE
			update_icon()
			visible_message("<span class = 'notice'>The [name] finishes smelting.</span>")
			process()
	else
		H << "<span class = 'warning'>The [name] doesn't have enough fuel! Fill it with wood or coal.</span>"


/obj/structure/furnace/process()
	if (iron > 0)
		var/obj/item/stack/material/steel/newsteel = new/obj/item/stack/material/steel(src.loc)
		newsteel.amount = iron
		iron = 0
	if (tin > 0 && copper > 0)
		var/obj/item/stack/material/bronze/newbronze = new/obj/item/stack/material/bronze(src.loc)
		var/amountconsumed = min(tin,copper)
		newbronze.amount = min(tin,copper)*3
		tin -= amountconsumed
		copper -= amountconsumed
	else if (tin == 0 && copper > 0)
		var/obj/item/stack/material/copper/newcopper = new/obj/item/stack/material/copper(src.loc)
		newcopper.amount = copper
		copper = 0
	else if (tin > 0 && copper == 0)
		var/obj/item/stack/material/tin/newtin = new/obj/item/stack/material/tin(src.loc)
		newtin.amount = tin
		tin = 0
/obj/structure/furnace/verb/empty()
	set category = null
	set name = "Empty"
	set src in range(1, usr)
	if (iron > 0)
		var/obj/item/stack/ore/iron/emptyediron = new/obj/item/stack/ore/iron(src.loc)
		emptyediron.amount = iron
		iron = 0
	if (copper > 0)
		var/obj/item/stack/ore/copper/emptyedcopper = new/obj/item/stack/ore/copper(src.loc)
		emptyedcopper.amount = copper
		copper = 0
	if (tin > 0)
		var/obj/item/stack/ore/tin/emptyedtin = new/obj/item/stack/ore/tin(src.loc)
		emptyedtin.amount = tin
		tin = 0

/obj/structure/oven/woodstove
	name = "wood stove"
	desc = "A stove fueled with wood logs."
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "woodstove"
	layer = 2.9
	density = TRUE
	anchored = TRUE
	flags = OPENCONTAINER | NOREACT
	base_state = "woodstove"
	on = FALSE
	max_space = 9
	fuel = 4