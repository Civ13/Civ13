/obj/structure/loom
	name = "loom"
	desc = "A loom, used to transform cotton into cloth."
	icon = 'icons/obj/structures.dmi'
	icon_state = "loom"
	anchored = TRUE
	density = TRUE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/loom/attackby(var/obj/item/stack/W as obj, var/mob/living/human/H as mob) ///obj/item/stack/material/rettedfabric
	if (istype(W, /obj/item/stack/material/cotton))
		H.visible_message("You start to produce the cloth.")
		icon_state = "loom1"
		if (do_after(H, min(W.amount*20, 200), H.loc))
			H.visible_message("You finish producing the cloth.")
			icon_state = "loom"
			var/obj/item/stack/material/cloth/clothes = new/obj/item/stack/material/cloth(H.loc)
			clothes.amount = W.amount
			qdel(W)
		else
			icon_state = "loom"
	if (istype(W, /obj/item/stack/material/rettedfabric))
		H.visible_message("You start to produce the cloth.")
		icon_state = "loom1"
		if (do_after(H, min(W.amount*20, 200), H.loc))
			H.visible_message("You finish producing the cloth.")
			icon_state = "loom"
			var/obj/item/stack/material/cloth/clothes = new/obj/item/stack/material/cloth(H.loc)
			clothes.amount = W.amount
			qdel(W)
		else
			icon_state = "loom"
	if (istype(W, /obj/item/stack/material/preparedkevlar))
		H.visible_message("You start to produce the kevlar.")
		icon_state = "loom1"
		if (do_after(H, min(W.amount*20, 200), H.loc))
			H.visible_message("You finish producing the kevlar.")
			icon_state = "loom"
			var/obj/item/stack/material/kevlar/clothes = new/obj/item/stack/material/kevlar(H.loc)
			clothes.amount = W.amount
			qdel(W)
		else
			icon_state = "loom"
	if (istype(W, /obj/item/stack/material/wool))
		H.visible_message("You start to produce the wool cloth.")
		icon_state = "loom1"
		if (do_after(H, min(W.amount*20, 200), H.loc))
			H.visible_message("You finish producing the wool cloth.")
			icon_state = "loom"
			var/obj/item/stack/material/woolcloth/clothes = new/obj/item/stack/material/woolcloth(H.loc)
			clothes.amount = W.amount
			qdel(W)
		else
			icon_state = "loom"
	if (istype(W,/obj/item/weapon/wrench))
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		H << (anchored ? "<span class='notice'r>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored
	else if (istype(W,/obj/item/weapon/hammer) || istype(W,/obj/item/weapon/hammer/modern))
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		H << "<span class='notice'>You begin dismantling \the [src].</span>"
		if (do_after(H,50,src))
			H << "<span class='notice'>You dismantle \the [src].</span>"
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			qdel(src)

/obj/structure/mill
	name = "mill"
	desc = "A small mill, used to grind cereals into flour."
	icon = 'icons/obj/structures.dmi'
	icon_state = "flour_mill"
	anchored = TRUE
	density = FALSE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/mill/attackby(var/obj/item/stack/W as obj, var/mob/living/human/H as mob)
	if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/wheat) || istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/oat) || istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/barley))
		H.visible_message("You start to mill the [W.name].")
		icon_state = "flour_mill1"
		if (do_after(H, 20, H.loc))
			H.visible_message("You finish milling the [W.name].")
			if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/barley))
				new/obj/item/weapon/reagent_containers/food/condiment/flour/barleyflour(H.loc)
			else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/oat))
				new/obj/item/weapon/reagent_containers/food/condiment/flour/oatflour(H.loc)
			else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/wheat))
				new/obj/item/weapon/reagent_containers/food/condiment/flour(H.loc)
			icon_state = "flour_mill"
			qdel(W)
		else
			icon_state = "flour_mill"

	else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/rice))
		H.visible_message("You start to mill the [W.name].")
		icon_state = "flour_mill1"
		if (do_after(H, 20, H.loc))
			H.visible_message("You finish milling the [W.name].")
			new/obj/item/weapon/reagent_containers/food/snacks/rice(H.loc)
			icon_state = "flour_mill"
			qdel(W)

	else if (istype(W,/obj/item/weapon/wrench))
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		H << (anchored ? "<span class='notice'r>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored
	else if (istype(W,/obj/item/weapon/hammer) || istype(W,/obj/item/weapon/hammer/modern))
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		H << "<span class='notice'>You begin dismantling \the [src].</span>"
		if (do_after(H,50,src))
			H << "<span class='notice'>You dismantle \the [src].</span>"
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			qdel(src)

		else
			icon_state = "flour_mill"

/obj/structure/mill/large
	name = "mill"
	desc = "A small mill, used to grind cereals into flour."
	icon = 'icons/obj/structures.dmi'
	icon_state = "mill_large"
	flammable = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
/obj/structure/mill/large/attackby(var/obj/item/stack/W as obj, var/mob/living/human/H as mob)
	if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/wheat))
		H.visible_message("You start to mill the [W.name].")
		icon_state = "mill_large1"
		if (do_after(H, 36, H.loc))
			H.visible_message("You finish milling the [W.name].")
			new/obj/item/weapon/reagent_containers/food/condiment/flour(H.loc)
			icon_state = "mill_large"
			qdel(W)
		else
			icon_state = "mill_large"

	if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/rice))
		H.visible_message("You start to mill the [W.name].")
		icon_state = "mill_large1"
		if (do_after(H, 36, H.loc))
			H.visible_message("You finish milling the [W.name].")
			new/obj/item/weapon/reagent_containers/food/snacks/rice(H.loc)
			icon_state = "mill_large"
			qdel(W)
		else
			icon_state = "mill_large"

/obj/structure/dehydrator
	name = "dehydrator"
	desc = "A wood structure used to dry meat, fish, tobacco, and so on."
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "wood_drier0"
	anchored = TRUE
	density = TRUE
	var/filled = 0
	var/stage = 0
	var/obj_type = /obj/item/weapon/reagent_containers/food/snacks/rawcutlet
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/dehydrator/attackby(var/obj/item/stack/W as obj, var/mob/living/human/H as mob)
	if (filled >= 4)
		H << "<span class='notice'>\The [src] is full!</span>"
		return
	else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/rawcutlet) && filled < 4)
		var/obj/item/weapon/reagent_containers/food/snacks/rawcutlet/RC = W
		if (RC.rotten == TRUE)
			H << "This is rotten."
			return
		else
			H << "You hang the [W.name] to dry."
			filled += 1
			obj_type = W.type
			icon_state = "wood_drier[filled]"
			qdel(W)
			obj_type = /obj/item/weapon/reagent_containers/food/snacks/rawcutlet
			dry_obj(obj_type)
			return
	else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/fishfillet) && filled < 4)
		var/obj/item/weapon/reagent_containers/food/snacks/fishfillet/FF = W
		if (FF.rotten == TRUE)
			H << "This is rotten."
			return
		else
			H << "You hang the [W.name] to dry."
			filled += 1
			obj_type = W.type
			icon_state = "wood_drier[filled]"
			qdel(W)
			obj_type = /obj/item/weapon/reagent_containers/food/snacks/fishfillet
			dry_obj(obj_type)
			return
	else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/salmonfillet) && filled < 4)
		var/obj/item/weapon/reagent_containers/food/snacks/salmonfillet/SF = W
		if (SF.rotten == TRUE)
			H << "This is rotten."
			return
		else
			H << "You hang the [W.name] to dry."
			filled += 1
			obj_type = W.type
			icon_state = "wood_drier[filled]"
			qdel(W)
			obj_type = /obj/item/weapon/reagent_containers/food/snacks/driedsalmon
			dry_obj(obj_type)
			return

	if (istype(W,/obj/item/weapon/wrench))
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		H << (anchored ? "<span class='notice'r>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored
	else if (istype(W,/obj/item/weapon/hammer) || istype(W,/obj/item/weapon/hammer/modern))
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		H << "<span class='notice'>You begin dismantling \the [src].</span>"
		if (do_after(H,50,src))
			H << "<span class='notice'>You dismantle \the [src].</span>"
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			qdel(src)

/obj/structure/dehydrator/proc/dry_obj(var/obj_type = null)
	spawn(1200) //2 minutes
		if (obj_type == /obj/item/weapon/reagent_containers/food/snacks/rawcutlet)
			if (isturf(src.loc))
				new/obj/item/weapon/reagent_containers/food/snacks/driedmeat(src.loc)
			visible_message("The meat finishes drying.")
			filled -= 1
			icon_state = "wood_drier[filled]"
			return
		else if (obj_type == /obj/item/weapon/reagent_containers/food/snacks/fishfillet)
			if (isturf(src.loc))
				new/obj/item/weapon/reagent_containers/food/snacks/driedfish(src.loc)
			visible_message("The fish finishes drying.")
			filled -= 1
			icon_state = "wood_drier[filled]"
			return
		else if (obj_type == /obj/item/weapon/reagent_containers/food/snacks/driedsalmon)
			if (isturf(src.loc))
				new/obj/item/weapon/reagent_containers/food/snacks/driedsalmon(src.loc)
			visible_message("The salmon finishes drying.")
			filled -= 1
			icon_state = "wood_drier[filled]"
			return
/obj/item/weapon/starterjar
	name = "fermentation starter jar"
	icon = 'icons/obj/drinks.dmi'
	desc = "A glass jar, used to multiply yeast."
	icon_state = "jar0"
	item_state = "beaker"
	var/fermenting = 0
	var/fermenting_timer = 0
	var/fermenting_contents = 0
/obj/item/weapon/starterjar/New()
	..()

/obj/item/weapon/starterjar/attackby(obj/O as obj, mob/living/human/user as mob)
	if (fermenting != 0)
		user << "This jar already has a starter culture inside!"
		return
	if (istype(O, /obj/item/weapon/reagent_containers/food/condiment/flour))
		user << "You add flour to the jar."
		fermenting = 1
		icon_state = "jar1"
		fermenting_timer = world.time + 1800
		qdel(O)
		fermenting_process()
		return

	if (istype(O, /obj/item/weapon/reagent_containers/food/snacks/grown/wheat))
		user << "You add wheat to the jar."
		fermenting = 1
		icon_state = "jar1"
		fermenting_timer = world.time + 2400
		qdel(O)
		fermenting_process()
		return

	else if (istype(O, /obj/item/weapon/reagent_containers/food/condiment/enzyme))
		user << "You add some yeast to the jar."
		fermenting = 2
		fermenting_contents++
		icon_state = "jar2"
		qdel(O)
		yeast_growth()
		return

	else if (istype(O,/obj/item/weapon/hammer) || istype(O,/obj/item/weapon/hammer/modern))
		playsound(loc, 'sound/weapons/smash.ogg', 75, 1)
		user << "<span class='notice'>You begin smashing apart \the [src].</span>"
		if (do_after(user,25,src))
			user << "<span class='notice'>You smash apart \the [src].</span>"
			new /obj/item/weapon/material/shard/glass(loc)
			qdel(src)

	else
		..()

/obj/item/weapon/starterjar/proc/fermenting_process()
	if (world.time >= fermenting_timer)
		visible_message("The flour in the jar ferments.")
		fermenting = 2
		fermenting_contents = 1
		icon_state = "jar2"
		yeast_growth()
	else
		spawn(100)
			fermenting_process()

/obj/item/weapon/starterjar/proc/yeast_growth()
	if (fermenting_contents > 0)
		spawn(1800)
			if (fermenting_contents > 0 && fermenting_contents < 5)
				fermenting_contents++
			yeast_growth()

/obj/item/weapon/starterjar/attack_self(var/mob/living/human/user as mob)
	if (fermenting == 2 && fermenting_contents > 0)
		user << "You take some yeast out of the jar."
		new/obj/item/weapon/reagent_containers/food/condiment/enzyme(user.loc)
		fermenting_contents--
		if (fermenting_contents == 0)
			fermenting = 0
			icon_state = "jar0"
	else
		..()


////////////////////////SEED/COLLECTOR/////////////////////////////////////
/obj/item/weapon/storage/seed_collector
	name = "seed collector"
	icon = 'icons/obj/storage.dmi'
	desc = "To store your seeds."
	icon_state = "seed_collector"
	item_state = "backpack"
	var/active = FALSE
	w_class = 4
	slot_flags = SLOT_BACK
	max_w_class = 2
	max_storage_space = 45 // can hold 2 w_class 4 items. 28 let it hold 3
	can_hold = list(
		/obj/item/stack/farming/seeds,
		)
	flammable = TRUE

/obj/item/weapon/storage/seed_collector/attack_self(var/mob/living/human/user as mob)
	active = TRUE
	var/total_storage_space = 0
	for (var/obj/item/I in contents)
		total_storage_space += I.get_storage_cost() //Adds up the combined w_classes which will be in the storage item if the item is added to it.
	if (total_storage_space+1 > max_storage_space)
		user << "<span class='notice'>[src] is too full, make some space.</span>"
		active = FALSE
		return
	if (!(src.loc == user))
		active = FALSE
		return
	else
		for (var/obj/item/stack/farming/seeds/SD in user.loc)
			var/doneexisting = FALSE
			for (var/obj/item/stack/farming/seeds/SDC in contents)
				if (SDC.type == SD.type)
					SDC.amount += SD.amount
					qdel(SD)
					doneexisting = TRUE
					user << "You collect the seeds."
					return
			if (!doneexisting)
				SD.forceMove(src)
				user << "You collect the seeds."
				return

////////////////////////ORE/COLLECTOR//////////////////////////////////////

/obj/item/weapon/storage/ore_collector
	name = "ore collector"
	icon = 'icons/obj/storage.dmi'
	desc = "A leather bag, used to collect ores."
	icon_state = "ore_collector"
	item_state = "backpack"
	var/active = FALSE
	w_class = 4
	slot_flags = SLOT_BACK
	max_w_class = 3
	max_storage_space = 28 // can hold 2 w_class 4 items. 28 let it hold 3
	can_hold = list(
		/obj/item/stack/ore,
		/obj/item/stack/material/stone,
		/obj/item/stack/material/sandstone,
		)
	flammable = TRUE

/obj/item/weapon/storage/ore_collector/attack_self(var/mob/living/human/user as mob)
	active = TRUE
	var/total_storage_space = 0
	for (var/obj/item/I in contents)
		total_storage_space += I.get_storage_cost() //Adds up the combined w_classes which will be in the storage item if the item is added to it.
	if (total_storage_space+3 > max_storage_space)
		user << "<span class='notice'>[src] is too full, make some space.</span>"
		active = FALSE
		return
	if (!(src.loc == user))
		active = FALSE
		return
	else
		for (var/obj/item/stack/ore/OR in user.loc)
			var/doneexisting = FALSE
			for (var/obj/item/stack/ore/ORC in contents)
				if (ORC.type == OR.type)
					ORC.amount += OR.amount
					qdel(OR)
					doneexisting = TRUE
					user << "You collect the ore."
			if (!doneexisting)
				OR.forceMove(src)
				user << "You collect the ore."

		for (var/obj/item/stack/material/stone/SR in user.loc)
			var/doneexisting = FALSE
			for (var/obj/item/stack/material/stone/SRC in contents)
				if (SRC.type == SR.type)
					SRC.amount += SR.amount
					qdel(SR)
					doneexisting = TRUE
					user << "You collect the stone."
			if (!doneexisting)
				SR.forceMove(src)
				user << "You collect the stone."


/////////PRODUCE BASKET (PRODUCE COLLECTOR)////////////
/obj/item/weapon/storage/produce_basket
	name = "produce basket"
	icon = 'icons/obj/storage.dmi'
	desc = "A woven basket, used to collect fruits and vegitables."
	icon_state = "produce_basket"
	item_state = "produce_basket"
	var/active = FALSE
	w_class = 4
	max_w_class = 3
	max_storage_space = 30 //lots of fruits and veggies
	can_hold = list(
		/obj/item/weapon/reagent_containers/food/snacks/grown,
		)
	flammable = TRUE

////////////////////OIL/WELL///////////////////////////
/obj/structure/oilwell
	name = "wooden oil well"
	desc = "An oil well, extracting petroleum to a barrel."
	icon = 'icons/obj/obj32x64.dmi'
	icon_state = "oilwell"
	anchored = TRUE
	density = TRUE
	flammable = TRUE
	var/obj/structure/oil_spring/base = null
	var/list/barrel = list()
	not_movable = TRUE
	not_disassemblable = FALSE

/obj/structure/oilwell/New()
	..()
	for (var/obj/structure/oil_spring/OS in src.loc)
		base = OS
	if (base != null)
		start_extraction()
		return
	else
		return

/obj/structure/oilwell/proc/start_extraction()
	if (base)
		if (barrel)
			spawn(1200)
				extract()
				return
		else
			return

	else
		return

/obj/structure/oilwell/proc/extract()
	if (!isemptylist(barrel))
		if (barrel[1].reagents.total_volume < barrel[1].reagents.maximum_volume)
			barrel[1].reagents.add_reagent("petroleum", min(barrel[1].reagents.maximum_volume - barrel[1].reagents.total_volume, 10))
			base.counter = 0
			spawn(1200)
				extract()
			return
		else
			return
	else
		return

/obj/structure/oilwell/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers/glass/barrel))
		if (isemptylist(barrel))
			barrel += W
			user.drop_from_inventory(W)
			W.forceMove(locate(0,0,0))
			visible_message("[user] puts \the [W] in \the [src].","You put \the [W] in \the [src].")
			start_extraction()
			return

	if (istype(W,/obj/item/weapon/hammer) || istype(W,/obj/item/weapon/hammer/modern))
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		user << "<span class='notice'>You begin dismantling \the [src].</span>"
		if (do_after(user,130,src))
			user << "<span class='notice'>You dismantle \the [src].</span>"
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc) 	//10 out of total of 40 to craft
			qdel(src)

	else
		..()

/obj/structure/oilwell/attack_hand(var/mob/living/human/H)
	if (!isemptylist(barrel))
		H << "You start taking \the barrel from \the [src]..."
		if (do_after(H,35,src))
			visible_message("You remove \the barrel.","[H] removes \the barrel from \the [src].")
		for(var/obj/item/weapon/reagent_containers/glass/barrel/B in barrel)
			B.loc = get_turf(src)
			barrel -= B
			return
	else
		H << "There is no container to remove from \the [src]."
		return


////////////////////PRINTING/PRESS///////////////////////////
/obj/structure/printingpress
	name = "printing press"
	desc = "Used to copy books and papers."
	icon = 'icons/obj/structures.dmi'
	icon_state = "printingpress0"
	anchored = TRUE
	density = TRUE
	flammable = TRUE
	var/list/base = list()
	var/list/copy = list()
	var/copying = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE

/obj/structure/printingpress/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/book) || istype(W, /obj/item/weapon/paper))
		var/tolist = list("Cancel")
		if (isemptylist(copy) && isemptylist(base))
			tolist = list("Original","Copy","Cancel")
		else if (isemptylist(copy) && !isemptylist(base))
			tolist = list("Copy","Cancel")
		else if (!isemptylist(copy) && isemptylist(base))
			tolist = list("Original","Cancel")
		else
			tolist = list("Cancel")
		var/input = WWinput(user, "Add to original or copy?", "Printing Press", "Cancel", tolist)
		if (input == "Cancel")
			return
		else if (input == "Original")
			base += W
			user.drop_from_inventory(W)
			W.forceMove(locate(0,0,0))
			return

		else if (input == "Copy")
			copy += W
			user.drop_from_inventory(W)
			W.forceMove(locate(0,0,0))
			return

	if (istype(W,/obj/item/weapon/wrench))
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		user << (anchored ? "<span class='notice'r>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored
	else if (istype(W,/obj/item/weapon/hammer) || istype(W,/obj/item/weapon/hammer/modern))
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		user << "<span class='notice'>You begin dismantling \the [src].</span>"
		if (do_after(user,60,src))
			user << "<span class='notice'>You dismantle \the [src].</span>"
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc) 	//5 out of 12 to craft
			qdel(src)

	else
		..()

/obj/structure/printingpress/attack_hand(var/mob/living/human/H)
	if (copying)
		return

	if (isemptylist(base) && isemptylist(copy))
		H << "There is nothing inside the press."
		return

	if (isemptylist(copy))
		for(var/obj/item/weapon/B in base)
			H << "You remove \the [B]."
			B.loc = get_turf(src)
			base -= B
		return

	if (isemptylist(base))
		for(var/obj/item/weapon/C in copy)
			H << "You remove \the [C]."
			C.loc = get_turf(src)
			copy -= C
		return
	if (!isemptylist(base) && !isemptylist(copy))
		if (base[1].type != copy[1].type)
			H << "Both documents must be of the same type."
			for(var/obj/item/weapon/C in copy)
				C.loc = get_turf(src)
				copy -= C
			for(var/obj/item/weapon/B in base)
				B.loc = get_turf(src)
				base -= B
			return
		else
			var/spawntimer = 90
			if (istype(base[1], /obj/item/weapon/book))
				spawntimer = 250
			else if (istype(base[1], /obj/item/weapon/paper))
				spawntimer = 90
			copying = TRUE
			visible_message("Copying \the [base[1]]...")
			icon_state = "printingpress1"
			if (do_after(H, spawntimer, src))
				if (!isemptylist(base) && !isemptylist(copy))
					visible_message("The printing press finishes copying.")
					icon_state = "printingpress0"
					for(var/obj/item/weapon/B in base)
						B.loc = get_turf(src)
						base -= B
						if (istype(B, /obj/item/weapon/book) && !istype(B, /obj/item/weapon/book/holybook) && !istype(B, /obj/item/weapon/book/research))
							var/obj/item/weapon/book/NC = B
							var/obj/item/weapon/book/NB = new/obj/item/weapon/book(src.loc)
							NB.dat = NC.dat
							NB.due_date = NC.due_date
							NB.author = NC.author
							NB.unique = NC.unique
							NB.title = NC.title
						else if (istype(B, /obj/item/weapon/book/holybook))
							var/obj/item/weapon/book/holybook/NC = B
							var/obj/item/weapon/book/holybook/NB = new/obj/item/weapon/book/holybook(src.loc)
							NB.author = NC.author
							NB.title = NC.title
							NB.name = NC.name
							NB.desc = NC.desc
							NB.religion = NC.religion
							NB.religion_type = NC.religion_type
						else if (istype(B, /obj/item/weapon/paper))
							var/obj/item/weapon/paper/NC = B
							var/obj/item/weapon/paper/NP = new/obj/item/weapon/paper(src.loc)
							NP.info = NC.info
							NP.info_links = NC.info_links
							NP.fields = NC.fields
							NP.free_space = NC.free_space
							NP.rigged = NC.rigged
							NP.spam_flag = NC.spam_flag
						else if (istype(B, /obj/item/weapon/book/research))
							var/obj/item/weapon/book/research/NC = B
							var/obj/item/weapon/book/research/NB = new/obj/item/weapon/book/research(src.loc)
							NB.author = NC.author
							NB.title = NC.title
							NB.name = NC.name
							NB.desc = NC.desc
							NB.completed = NC.completed = 0
							NB.k_class = NC.k_class = "none"
							NB.k_level = NC.k_level = 0
							NB.styleb = NC.styleb = "scroll"
							NB.sum_a = NC.sum_a = 0
							NB.sum_b = NC.sum_b = 0
							NB.sum_c = NC.sum_c = 0
							NB.monk = NC.monk = FALSE //if the book was authored by a monk
							NB.religion = NC.religion = "none"
					for(var/obj/item/weapon/C in copy)
						copy -= C
						qdel(C)
					copying = FALSE
					return
			else
				copying = FALSE
				icon_state = "printingpress0"
				return
	return

///////////////////////canning//////////////////////
/obj/structure/canner
	name = "canner"
	desc = "A pressure tool used to seal cans."
	icon = 'icons/obj/cans.dmi'
	icon_state = "canner"
	anchored = TRUE
	density = FALSE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/canner/attackby(var/obj/item/W as obj, var/mob/living/human/H as mob)
	if (istype(W, /obj/item/weapon/can))
		var/obj/item/weapon/can/C = W
		if (C.stored.len)
			H << "You start sealing \the [C]..."
			icon_state = "canner_active"
			if (do_after(H, 50, H.loc))
				H << "You finish sealing \the [C]."
				C.open = FALSE
				C.sealed = TRUE
				C.update_icon()
				icon_state = "canner"
			else
				icon_state = "canner"

	if (istype(W,/obj/item/weapon/wrench))
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		H << (anchored ? "<span class='notice'r>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored
	else if (istype(W,/obj/item/weapon/hammer) || istype(W,/obj/item/weapon/hammer/modern))
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		H << "<span class='notice'>You begin dismantling \the [src].</span>"
		if (do_after(H,50,src))
			H << "<span class='notice'>You dismantle \the [src].</span>"
			new /obj/item/stack/material/iron(loc)
			new /obj/item/stack/material/iron(loc)
			new /obj/item/stack/material/iron(loc)
			new /obj/item/stack/material/iron(loc) 	//4 out of 7 to craft
			qdel(src)

/obj/item/weapon/can
	name = "empty can"
	desc = "A tin can that can keep food good for a long time. Can fit 5 units."
	icon = 'icons/obj/cans.dmi'
	icon_state = "can_empty"
	var/base_icon = "can"
	w_class = 2.0
	flammable = FALSE
	slot_flags = null
	var/max_capacity = 5
	var/brand = ""
	var/list/stored = list()
	var/open = TRUE
	var/sealed = FALSE
	var/customcolor1 = null
	var/customcolor2 = null
	basematerials = list("tin",0.45)

/obj/item/weapon/can/small
	name = "empty small can"
	desc = "A tin can that can keep food good for a long time. Can fit 3 units."
	icon_state = "small_can_empty"
	base_icon = "small_can"
	w_class = 1.0
	slot_flags = SLOT_POCKET
	max_capacity = 3
	basematerials = list("tin",0.3)

/obj/item/weapon/can/large
	name = "empty large can"
	desc = "A tin can that can keep food good for a long time. Can fit 10 units."
	icon_state = "large_can_empty"
	base_icon = "large_can"
	w_class = 3.0
	slot_flags = null
	max_capacity = 10
	basematerials = list("tin",0.9)

/obj/item/weapon/can/update_icon()
	if (open)
		if (stored.len)
			icon_state = "[base_icon]_open"
		else
			icon_state = "[base_icon]_empty"
	else
		icon_state = "[base_icon]"

/obj/item/weapon/can/attackby(var/obj/item/W as obj, var/mob/living/human/H as mob)
	if (istype(W, /obj/item/weapon/reagent_containers/food/snacks) && open)
		if (stored.len < max_capacity && !sealed)
			stored += W
			H.drop_from_inventory(W)
			W.forceMove(src)
			H << "You put \the [W] in \the [src]."
			icon_state = "[base_icon]_open"
			if (stored.len == 1)
				name = "[brand]canned [W]"
				name = replacetext(name, "the","")
			else
				if (!findtext(name, "[W]"))
					name = replacetext(name, " and ",", ")
					name = "[name] and [W]"
					name = replacetext(name, "the","")
			if (!findtext(W.name, "canned"))
				W.name = replacetext(W.name, "the","")
				W.name = "canned [W.name]"
			name = replacetext(name, "  "," ")
			var/obj/item/weapon/reagent_containers/food/snacks/S = W
			if (S.satisfaction > 0)
				S.satisfaction *= 0.5 //canned food doesn't taste as good
			else
				S.satisfaction *= 1.5 //food that is already bad will taste worse when canned
			return
		else
			H << "<span class='notice'>\the [src] is full!</span>"
			return
	if (istype(W, /obj/item/weapon/material/kitchen/utensil/knife))
		if (!open)
			open = TRUE
			update_icon()
			H << "You open \the [src]."
			return
	else
		..()

/obj/item/weapon/can/attack_hand(mob/living/human/user)
	if (stored.len && user.has_empty_hand() && loc == user && open)
		for (var/obj/item/I in stored)
			I.loc = user.loc
			stored -= I
			user.put_in_active_hand(I)
			user << "You remove \the [I] from \the [src]."
			if (!stored.len)
				name = "empty [brand]can"
				icon_state = "[base_icon]_empty"
			return
	else
		..()

/obj/item/weapon/can/proc/do_color()

	if (customcolor1)
		var/image/colorov1 = image("icon" = icon, "icon_state" = "[base_icon]_o1")
		colorov1.color = customcolor1
		overlays += colorov1

	if (customcolor2)
		var/image/colorov2 = image("icon" = icon, "icon_state" = "[base_icon]_o2")
		colorov2.color = customcolor2
		overlays += colorov2

/obj/item/weapon/can/filled
	var/list/randbrand = list("Master Taislin", "Metsobeshi", "Old Man", "Welmert", "McDonohugh", "McKellen's Delight", "Freeman", "Kostas Finest", "Slowman", "Pajeet Special", "Toyoda", "Uma Delicia", "Ooga's Cuisine", "Burner King")
	var/list/custcolor = list("#e6194b", "#3cb44b", "#ffe119", "#4363d8", "#f58231", "#911eb4", "#46f0f0", "#f032e6", "#bcf60c", "#fabebe", "#008080", "#e6beff", "#9a6324", "#fffac8", "#800000", "#aaffc3", "#808000", "#ffd8b1", "#000075", "#808080", "#ffffff", "#000000")
	var/list/filllist = list(/obj/item/weapon/reagent_containers/food/snacks/grown/grapes, /obj/item/weapon/reagent_containers/food/snacks/grown/olives, /obj/item/weapon/reagent_containers/food/snacks/grown/mushroom, /obj/item/weapon/reagent_containers/food/snacks/grown/melon, /obj/item/weapon/reagent_containers/food/snacks/grown/orange, /obj/item/weapon/reagent_containers/food/snacks/grown/apple, /obj/item/weapon/reagent_containers/food/snacks/grown/banana, /obj/item/weapon/reagent_containers/food/snacks/grown/coconut, /obj/item/weapon/reagent_containers/food/snacks/grown/tomato, /obj/item/weapon/reagent_containers/food/snacks/grown/beans, /obj/item/weapon/reagent_containers/food/snacks/grown/cabbage, /obj/item/weapon/reagent_containers/food/snacks/grown/carrot, /obj/item/weapon/reagent_containers/food/snacks/grown/corn)
	var/currspawn = null
	icon_state = "can"
/obj/item/weapon/can/filled/New()
	..()
	currspawn = pick(filllist)
	brand = "[pick(randbrand)]"
	stored = fill()
	open = FALSE
	sealed = TRUE
	customcolor1 = pick(custcolor)
	customcolor2 = pick(custcolor)
	name = "[brand]'s [stored[1].name]"
	spawn(1)
		do_color()

/obj/item/weapon/can/filled/proc/fill()
	var/list/tlist = list()
	currspawn = pick(filllist)
	for (var/i=1, i <= rand(3,5), i++)
		var/obj/item/weapon/reagent_containers/food/snacks/grown/GS = new currspawn(src)
		GS.name = "canned [GS.name]"
		if (GS.satisfaction > 0)
			GS.satisfaction *= 0.5 //canned food doesn't taste as good
		else
			GS.satisfaction *= 1.5 //food that is already bad will taste worse when canned
		tlist += GS
	return tlist

/obj/structure/compost
	name = "compost bin"
	desc = "A wood box, used to turn trash and scraps into fertilizer."
	icon = 'icons/obj/structures.dmi'
	icon_state = "compostbin"
	anchored = TRUE
	density = TRUE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/max = 10
	var/current = 0

/obj/structure/compost/attackby(var/obj/item/W as obj, var/mob/living/human/H as mob)
	if (current >= max)
		H << "<span class='warning'>The compost bin is full!</span>"
		return

	else if (istype(W, /obj/item/weapon/reagent_containers/food))
		current+=0.5
		H << "You place \the [W] in \the [src], composting it."
		compost()
		qdel(W)
		return
	else if (istype(W, /obj/item/weapon/leaves))
		current+=0.25
		H << "You place \the [W] in \the [src], composting it."
		compost()
		qdel(W)
		return
	else if (istype(W, /obj/item/stack/farming/seeds))
		if (current >= max)
			H << "<span class = 'warning'>You need to reduce the current stack of \ [W] first to fit inside \ the [src]!</span>"
			return
		else
			current+=W.amount/10 	//divides (using /) by tenths from each plant input of 1, 0.10 gain per seed, 10 seeds = 1 unit. 100 seeds = 10
			H << "You place \the [W] in \the [src], composting it."
			compost()
			qdel(W)
	else if (istype(W, /obj/item/stack/material/poppy) || istype(W, /obj/item/stack/material/tobacco) || istype(W, /obj/item/stack/material/coca))
		if (current >= max)
			H << "<span class = 'warning'>You need to reduce the current stack of \ [W] first to fit inside \ the [src]!</span>"
			return
		else
			current+=W.amount/4 	//by fourths from each stack plant input of 1, 0.25 gain per plant, 4 stackplants = 1 unit. 40 stackplants = 10
			H << "You place \the [W] in \the [src], composting it."
			compost()
			qdel(W)
	else if (istype(W, /obj/item/stack/material/flax) || istype(W, /obj/item/stack/material/hemp) || istype(W, /obj/item/stack/material/rettedfabric))
		if (current >= max)
			H << "<span class = 'warning'>You need to reduce the current stack of \ [W] first to fit inside \ the [src]!</span>"
			return
		else
			current+=W.amount/4 	//by fourths from each stack plant input of 1, 0.25 gain per plant, 4 stackplants = 1 unit. 40 stackplants = 10
			H << "You place \the [W] in \the [src], composting it."
			compost()
			qdel(W)
			return

	if (istype(W,/obj/item/weapon/wrench))
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		H << (anchored ? "<span class='notice'r>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored
	else if (istype(W,/obj/item/weapon/hammer) || istype(W,/obj/item/weapon/hammer/modern))
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		H << "<span class='notice'>You begin dismantling \the [src].</span>"
		if (do_after(H,50,src))
			H << "<span class='notice'>You dismantle \the [src].</span>"
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			new /obj/item/stack/material/wood(loc)
			qdel(src)

/obj/structure/compost/proc/compost(mob/living/human/H as mob)
	spawn(500)
	visible_message("The composted material begins to degrade.")
	if (current>=1)
		current=max(0,current-1)
		spawn(1500)
			if (src)
				new/obj/item/weapon/reagent_containers/food/snacks/poo/fertilizer(loc)
				return
