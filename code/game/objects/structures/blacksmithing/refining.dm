
////Furnaces////
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

/obj/structure/furnace/sandstone
	name = "sandstone furnace"
	desc = "An industrial furnace, used to smelter minerals."
	icon = 'icons/obj/structures.dmi'
	icon_state = "sandstone_brick_furnace"
	layer = 2.9
	density = TRUE
	anchored = TRUE
	flags = OPENCONTAINER | NOREACT
	base_state = "sandstone_brick_furnace"
	on = FALSE
	max_space = 6
	fuel = 0
	iron = 0
	copper = 0
	tin = 0
	not_movable = TRUE
	not_disassemblable = FALSE

/obj/structure/furnace/clay
	name = "clay furnace"
	desc = "An industrial furnace, used to smelter minerals."
	icon = 'icons/obj/structures.dmi'
	icon_state = "clay_brick_furnace"
	layer = 2.9
	density = TRUE
	anchored = TRUE
	flags = OPENCONTAINER | NOREACT
	base_state = "clay_brick_furnace"
	on = FALSE
	max_space = 6
	fuel = 0
	iron = 0
	copper = 0
	tin = 0
	not_movable = TRUE
	not_disassemblable = FALSE

/obj/structure/furnace/update_icon()
	if (on)
		icon_state = "[base_state]_on"
		set_light(4)
	else
		icon_state = base_state
		set_light(0)

/obj/structure/furnace/attackby(var/obj/item/I, var/mob/living/human/H)
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
				H << "You place \the [I] in \the [src], smelting it."
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
			else if (istype(I, /obj/item/weapon/leaves))
				fuel += I.amount+0.5
				H << "You place \the [I] in \the [src], refueling it."
				qdel(I)
				return
			else if (istype(I, /obj/item/weapon/reagent_containers/food/snacks/poo))
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
				return

			if (istype(I, /obj/item/stack/ore/iron) || istype(I, /obj/item/stack/material/iron))
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

/obj/structure/furnace/attack_hand(var/mob/living/human/H)
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

////////ADVANCED METALLURGY STUFF/////////
/obj/structure/furnace/blast_furnace
	name = "blast furnace"
	desc = "An industrial blast furnace, used to make advanced alloys."
	icon = 'icons/obj/metallurgy.dmi'
	icon_state = "blast_furnace"
	base_state = "blast_furnace"

////////ADVANCED METALLURGY STUFF/////////
/obj/structure/furnace/kiln
	name = "kiln"
	desc = "A clay brick kiln, used for metallurgy."
	icon = 'icons/obj/metallurgy.dmi'
	icon_state = "kiln"
	base_state = "kiln"
