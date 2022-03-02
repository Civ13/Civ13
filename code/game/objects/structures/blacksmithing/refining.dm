////Furnaces////
/obj/structure/furnace
	name = "bloomery"
	desc = "An industrial bloomery, used to smelter iron into sponge iron. Can also be used to recycle materials."
	icon = 'icons/obj/metallurgy.dmi'
	icon_state = "bloomery"
	layer = 2.9
	density = TRUE
	anchored = TRUE
	flags = OPENCONTAINER | NOREACT
	var/base_state = "bloomery"
	var/on = FALSE
	var/fuel = 0
	var/iron = 0
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
				return

			if (istype(I, /obj/item/stack/ore/iron))
				iron += I.amount
				H << "You place \the [I] in \the [src]."
				qdel(I)
				return
			else
				H << "<span class = 'warning'>You can't smelt this.</span>"
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
				new/obj/item/stack/material/tin(src.loc)
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
		spawn (250)
			on = FALSE
			update_icon()
			visible_message("<span class = 'notice'>The [name] finishes smelting.</span>")
			process()
	else
		H << "<span class = 'warning'>The [name] doesn't have enough fuel! Fill it with wood or coal.</span>"


/obj/structure/furnace/process()
	if (iron > 0)
		var/obj/item/stack/ore/iron_sponge/result = new/obj/item/stack/ore/iron_sponge(src.loc)
		result.amount = iron
		iron = 0
		return
/obj/structure/furnace/verb/empty()
	set category = null
	set name = "Empty"
	set src in range(1, usr)
	if (iron > 0)
		var/obj/item/stack/ore/iron/emptyediron = new/obj/item/stack/ore/iron(src.loc)
		emptyediron.amount = iron
		iron = 0


////////ADVANCED METALLURGY STUFF/////////
/obj/structure/furnace/blast_furnace
	name = "blast furnace"
	desc = "An industrial blast furnace, used to make advanced alloys."
	icon = 'icons/obj/metallurgy.dmi'
	icon_state = "blast_furnace"
	base_state = "blast_furnace"

/obj/structure/furnace/blast_furnace/attackby(var/obj/item/I, var/mob/living/human/H)
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
				return

			if (istype(I, /obj/item/stack/ore/iron))
				iron += I.amount
				H << "You place \the [I] in \the [src]."
				qdel(I)
				return
			else
				H << "<span class = 'warning'>You can't smelt this.</span>"
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
	else
		..()

/obj/structure/furnace/blast_furnace/process()
	if (iron > 0)
		var/obj/item/stack/ore/iron_pig/result = new/obj/item/stack/ore/iron_pig(src.loc)
		result.amount = iron
		iron = 0
		return

////////ADVANCED METALLURGY STUFF/////////
/obj/structure/furnace/kiln
	name = "clay kiln"
	desc = "A clay brick kiln, used for metallurgy."
	icon = 'icons/obj/metallurgy.dmi'
	icon_state = "clay_kiln"
	base_state = "clay_kiln"

/obj/structure/furnace/kiln/stone
	name = "stone kiln"
	desc = "A stone kiln, used for metallurgy."
	icon_state = "stone_kiln"
	base_state = "stone_kiln"

/obj/structure/furnace/kiln/sandstone
	name = "sandstone kiln"
	desc = "A sandstone kiln, used for metallurgy."
	icon_state = "sandstone_kiln"
	base_state = "sandstone_kiln"

/obj/structure/furnace/kiln/attackby(var/obj/item/I, var/mob/living/human/H)
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
				return

			for (var/obj/item/weapon/clay/mold/MCC in contents)
				H << "<span class = 'warning'>\The [name] is full.</span>"
				return

		else if (istype(I, /obj/item/weapon/material))
			var/obj/item/weapon/material/MT = I
			if (MT.get_material_name() == "wood")
				fuel += 1
				H << "You break \the [MT] and put it into the [src], refueling it."
				qdel(I)
		if (istype(I, /obj/item/weapon/clay/mold))
			var/obj/item/weapon/clay/mold/MC = I
			if (MC.fired && MC.capacity == 0 && MC.max_capacity > 0 && MC.contents_materials.len)
				H.remove_from_mob(I)
				I.loc = src
				visible_message("<span class = 'notice'>[H] puts [I] in \the [name].</span>")
				return

/obj/structure/furnace/kiln/process()
	for (var/obj/item/weapon/clay/mold/MCC in contents)
		if (MCC.fired && MCC.capacity == 0 && MCC.max_capacity > 0 && MCC.contents_materials.len)
			if (("copper" in MCC.contents_materials) && ("tin" in MCC.contents_materials))
				MCC.capacity = min(MCC.contents_materials["copper"],MCC.contents_materials["tin"])
				MCC.contents_materials["copper"] -= MCC.capacity
				MCC.contents_materials["tin"] -= MCC.capacity
				MCC.current_material = "bronze"
			else
				for(var/i in MCC.contents_materials)
					MCC.capacity = MCC.contents_materials[i]
					MCC.current_material = i
			MCC.contents_materials = list()
			MCC.loc = src.loc
			MCC.update_icon()