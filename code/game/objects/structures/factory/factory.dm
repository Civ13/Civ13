//ROBERTS FACTORY FRAMEWORK

/obj/structure/machinery/factory
	name = "furnace"
	desc = "An industrial furnace, used to smelt minerals."
	icon = 'icons/obj/machines/coinsmelter.dmi'
	icon_state = "coinsmelter"
	layer = 2.9
	density = TRUE
	anchored = TRUE
	flags = OPENCONTAINER | NOREACT
	var/base_state = "coinsmelter"
	var/on = FALSE
	var/max_space = 6
	var/fuel = 0
	var/iron = 0
	var/copper = 0
	var/tin = 0
	var/gold = 0
	var/silver = 0
	not_movable = TRUE
	not_disassemblable = FALSE

/obj/structure/machinery/factory/update_icon()
	if (on)
		icon_state = "[base_state]_on"
		set_light(4)
	else
		icon_state = base_state
		set_light(0)

/obj/structure/machinery/factory/attackby(var/obj/item/I, var/mob/living/human/H)
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
					qdel(src)
					return
		if (istype(I, /obj/item/stack/))
			if (istype(I, /obj/item/stack/material/wood))	//FUEL NORMAL (without * multiplication or + addition, only input)
				fuel += I.amount
				H << "You place \the [I] in \the [src], refueling it."
				qdel(I)
				return
			else if (istype(I, /obj/item/stack/material/bamboo))
				fuel += I.amount
				H << "You place \the [I] in \the [src], refueling it."
				qdel(I)
				return
			else if (istype(I, /obj/item/weapon/branch))	// FUEL +0.5 (adds a flat numerical addition ontop of the input reagent's baseline fuel, recommended for non stack objects)
				fuel += I.amount+0.5
				H << "You place \the [I] in \the [src], refueling it."
				qdel(I)
				return
			else if (istype(I, /obj/item/stack/material/leaf))
				fuel += I.amount+0.5
				H << "You place \the [I] in \the [src], refueling it."
				qdel(I)
				return
			else if (istype(I, /obj/item/stack/dung))	// FUEL +1
				fuel += I.amount+1
				H << "You place \the [I] in \the [src], refueling it."
				qdel(I)
				return
			else if (istype(I, /obj/item/stack/ore/charcoal))	//FUEL *2.5 (multiplies it by 2 and a half)
				fuel += I.amount*2.5
				H << "You place \the [I] in \the [src], refueling it."
				qdel(I)
				return
			else if (istype(I, /obj/item/stack/ore/coal))	//FUEL *3
				fuel += I.amount*3
				H << "You place \the [I] in \the [src], refueling it."
				qdel(I)
				return

			else if (istype(I, /obj/item/stack/ore/iron) || istype(I, /obj/item/stack/material/iron))
				iron += I.amount
				H << "You place \the [I] in \the [src], smelting it."
				qdel(I)
				return
			else if (istype(I, /obj/item/stack/ore/copper) || istype(I, /obj/item/stack/material/copper))
				copper += I.amount
				H << "You place \the [I] in \the [src], smelting it."
				qdel(I)
				return
			else if (istype(I, /obj/item/stack/ore/tin) || istype(I, /obj/item/stack/material/tin))
				tin += I.amount
				H << "You place \the [I] in \the [src], smelting it."
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

/obj/structure/machinery/factory/attack_hand(var/mob/living/human/H)
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


/obj/structure/machinery/factory/process()
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

		//EMTPY

/obj/structure/machinery/factory/verb/empty()
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

//ROBERTS FACTORY FRAMEWORK

//COINSMELTER

/obj/structure/machinery/factory/coinsmelter
	name = "coinsmelter"
	desc = "An industrial coin smelter, used to smelter coins into ingots."
	icon = 'icons/obj/machines/coinsmelter.dmi'
	icon_state = "coinsmelter"
	layer = 2.9
	density = TRUE
	anchored = TRUE
	flags = OPENCONTAINER | NOREACT
	base_state = "coinsmelter"
	on = FALSE
	max_space = 6
	fuel = 0
	gold = 0
	copper = 0
	silver = 0
	var/goldcoin = 0
	var/coppercoin = 0
	var/silvercoin = 0
	not_movable = TRUE
	not_disassemblable = FALSE


/obj/structure/machinery/factory/coinsmelter/update_icon()
	if (on)
		icon_state = "[base_state]_on"
		set_light(4)
	else
		icon_state = base_state
		set_light(0)

/obj/structure/machinery/factory/coinsmelter/attackby(var/obj/item/I, var/mob/living/human/H)
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
					qdel(src)
					return
		if (istype(I, /obj/item/stack/))
			if (istype(I, /obj/item/stack/material/wood))
				fuel += I.amount
				H << "You place \the [I] in \the [src], refueling it."
				qdel(I)
				return
			else if (istype(I, /obj/item/stack/material/bamboo))
				fuel += I.amount
				H << "You place \the [I] in \the [src], refueling it."
				qdel(I)
				return
			else if (istype(I, /obj/item/weapon/branch))
				fuel += I.amount+0.5
				H << "You place \the [I] in \the [src], refueling it."
				qdel(I)
				return
			else if (istype(I, /obj/item/stack/material/leaf))
				fuel += I.amount+0.5
				H << "You place \the [I] in \the [src], refueling it."
				qdel(I)
				return
			else if (istype(I, /obj/item/stack/dung))
				fuel += I.amount+1
				H << "You place \the [I] in \the [src], refueling it."
				qdel(I)
				return
			else if (istype(I, /obj/item/stack/ore/charcoal))
				fuel += I.amount*2.5
				H << "You place \the [I] in \the [src], refueling it."
				qdel(I)
				return
			else if (istype(I, /obj/item/stack/ore/coal))
				fuel += I.amount*3
				H << "You place \the [I] in \the [src], refueling it."
				qdel(I)
				return				  //INPUT 1

			else if (istype(I, /obj/item/stack/money/goldcoin))
				gold += I.amount/5
				H << "You place \the [I] in \the [src], smelting it."
				qdel(I)
				return
			else if (istype(I, /obj/item/stack/material/gold))
				gold += I.amount
				H << "You place \the [I] in \the [src], smelting it."
				qdel(I)
				return

			else if (istype(I, /obj/item/stack/money/coppercoin))
				copper += I.amount/5
				H << "You place \the [I] in \the [src], smelting it."
				qdel(I)
				return
			else if (istype(I, /obj/item/stack/material/copper))
				copper += I.amount
				H << "You place \the [I] in \the [src], smelting it."
				qdel(I)
				return

			else if (istype(I, /obj/item/stack/money/silvercoin))
				silver += I.amount/10
				H << "You place \the [I] in \the [src], smelting it."
				qdel(I)
				return
			else if (istype(I, /obj/item/stack/material/silver))
				silver += I.amount
				H << "You place \the [I] in \the [src], smelting it."
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
			else if (MT.get_material_name() == "copper")
				H << "You smelt \the [MT] into copper ingots."
				new/obj/item/stack/material/copper(src.loc)
				qdel(I)
			else if (MT.get_material_name() == "silver")
				H << "You smelt \the [MT] into silver ingots."
				new/obj/item/stack/material/silver(src.loc)
				qdel(I)
			else if (MT.get_material_name() == "gold")
				H << "You smelt \the [MT] into gold ingots."
				new/obj/item/stack/material/gold(src.loc)
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

/obj/structure/machinery/factory/coinsmelter/attack_hand(var/mob/living/human/H)
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


/obj/structure/machinery/factory/coinsmelter/process()
	if (gold > 0)
		var/obj/item/stack/money/goldcoin/newgoldcoin = new/obj/item/stack/material/gold(src.loc)
		newgoldcoin.amount = gold
		gold = 0
	if (copper > 0)
		var/obj/item/stack/money/coppercoin/newcoppercoin = new/obj/item/stack/material/copper(src.loc)
		newcoppercoin.amount = copper
		copper = 0
	else if (silver > 0)
		var/obj/item/stack/money/silvercoin/newsilvercoin = new/obj/item/stack/material/silver(src.loc)
		newsilvercoin.amount = silver
		silver = 0

		//EMTPY

/obj/structure/machinery/factory/coinsmelter/verb/emptycoin()
	set category = null
	set name = "Empty"
	set src in range(1, usr)
	if (goldcoin > 0)
		var/obj/item/stack/money/goldcoin/emptyedgoldcoin = new/obj/item/stack/money/goldcoin/(src.loc)
		emptyedgoldcoin.amount = goldcoin
		goldcoin = 0
	if (coppercoin > 0)
		var/obj/item/stack/money/coppercoin/emptyedcoppercoin = new/obj/item/stack/money/coppercoin(src.loc)
		emptyedcoppercoin.amount = coppercoin
		coppercoin = 0
	if (silvercoin > 0)
		var/obj/item/stack/money/silvercoin/emptyedsilvercoin = new/obj/item/stack/money/silvercoin(src.loc)
		emptyedsilvercoin.amount = silvercoin
		silvercoin = 0


		//COINSMELTER
