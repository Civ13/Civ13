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

/obj/structure/oven/update_icon()
	if (on)
		icon_state = "[base_state]_on"
	else
		icon_state = base_state

/obj/structure/oven/attackby(var/obj/item/I, var/mob/living/carbon/human/H)
	if (!istype(H))
		return
	if (istype(I, /obj/item/stack/material/wood))
		fuel += I.amount
		qdel(I)
		return
	else if (istype(I, /obj/item/weapon/wrench) || (istype(I, /obj/item/weapon/hammer)))
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
		else
			set_light(2)
		spawn (50)
			on = FALSE
			set_light(0)
			update_icon()
			visible_message("<span class = 'notice'>The [name] finishes cooking.</span>")
			process()
	else
		H << "<span class = 'warning'>The [name] doesn't have enough fuel! Fill it with wood or coal.</span>"

/obj/structure/oven/process()
	for (var/obj/item/I in contents)
		if (istype(I, /obj/item/stack/ore))
			if (istype(I, /obj/item/stack/ore/diamond))
				for (var/COUNT = 1; COUNT <= I.amount; COUNT++)
					contents += new/obj/item/stack/material/diamond(src)
				contents -= I
				qdel(I)
			else if (istype(I, /obj/item/stack/ore/glass))
				for (var/COUNT = 1; COUNT <= I.amount; COUNT++)
					contents += new/obj/item/stack/material/glass(src)
				contents -= I
				qdel(I)
			else if (istype(I, /obj/item/stack/ore/gold))
				for (var/COUNT = 1; COUNT <= I.amount; COUNT++)
					contents += new/obj/item/stack/material/gold(src)
				contents -= I
				qdel(I)
			else if (istype(I, /obj/item/stack/ore/silver))
				for (var/COUNT = 1; COUNT <= I.amount; COUNT++)
					contents += new/obj/item/stack/material/silver(src)
				contents -= I
				qdel(I)
			else if (istype(I, /obj/item/stack/ore/iron))
				for (var/COUNT = 1; COUNT <= I.amount; COUNT++)
					contents += new/obj/item/stack/material/iron(src)
				contents -= I
				qdel(I)
			else if (istype(I, /obj/item/stack/ore/copper))
				for (var/COUNT = 1; COUNT <= I.amount; COUNT++)
					contents += new/obj/item/stack/material/copper(src)
				contents -= I
				qdel(I)
		else if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/dough))
			contents += new /obj/item/weapon/reagent_containers/food/snacks/sliceable/bread(src)
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
			if (istype(I, /obj/item/weapon/reagent_containers/food))
				var/obj/item/weapon/reagent_containers/food/F = I
				F.roasted = TRUE
				F.raw = FALSE

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

/obj/structure/oven/fireplace/Crossed(mob/living/carbon/M as mob)
	if (icon_state == "[base_state]_on")
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

/obj/structure/furnace/update_icon()
	if (on)
		icon_state = "[base_state]_on"
	else
		icon_state = base_state

/obj/structure/furnace/attackby(var/obj/item/I, var/mob/living/carbon/human/H)
	if (!istype(H))
		return
	if (istype(I, /obj/item/stack/material/wood))
		fuel += I.amount
		qdel(I)
		return
	else if (istype(I, /obj/item/stack/ore/coal))
		fuel += I.amount*3
		qdel(I)
		return
	else if (istype(I, /obj/item/stack/ore/iron))
		iron += I.amount
		qdel(I)
		return
	else if (istype(I, /obj/item/stack/ore/copper))
		copper += I.amount
		qdel(I)
		return
	else if (istype(I, /obj/item/stack/ore/tin))
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
		H << "<span class = 'warning'>The [name] is full.</span>"
		return
	H.remove_from_mob(I)
	I.loc = src
	visible_message("<span class = 'notice'>[H] puts [I] in the [name].</span>")


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

/obj/structure/furnace/verb/empty()
	set category = null
	set name = "Empty"
	set src in range(1, usr)
	if (iron > 0)
		var/obj/item/stack/material/iron/emptyediron = new/obj/item/stack/material/iron(src.loc)
		emptyediron.amount = iron
		iron = 0
	if (copper > 0)
		var/obj/item/stack/material/copper/emptyedcopper = new/obj/item/stack/material/copper(src.loc)
		emptyedcopper.amount = copper
		copper = 0
	if (tin > 0)
		var/obj/item/stack/material/tin/emptyedtin = new/obj/item/stack/material/tin(src.loc)
		emptyedtin.amount = tin
		tin = 0