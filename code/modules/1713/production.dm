/obj/structure/loom
	name = "loom"
	desc = "A loom, used to transform cotton into cloth."
	icon = 'icons/obj/structures.dmi'
	icon_state = "loom"

/obj/structure/loom/attackby(var/obj/item/stack/W as obj, var/mob/living/carbon/human/H as mob)
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
/obj/structure/mill
	name = "mill"
	desc = "A small mill, used to grind cereals into flour."
	icon = 'icons/obj/structures.dmi'
	icon_state = "flour_mill"

/obj/structure/mill/attackby(var/obj/item/stack/W as obj, var/mob/living/carbon/human/H as mob)
	if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/wheat))
		H.visible_message("You start to mill the [W.name].")
		icon_state = "flour_mill1"
		if (do_after(H, 20, H.loc))
			H.visible_message("You finish milling the [W.name].")
			var/obj/item/weapon/reagent_containers/food/condiment/flour/flour = new/obj/item/weapon/reagent_containers/food/condiment/flour(H.loc)
			flour.reagents.remove_reagent("flour", 20)
			icon_state = "flour_mill"
			qdel(W)
		else
			icon_state = "flour_mill"

/obj/structure/dehydrator
	name = "dehydrator"
	desc = "A wood structure used to dry meat, fish, tobacco, and so on."
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "wood_drier0"
	var/filled = 0
	var/stage = 0
	var/obj_type = /obj/item/weapon/reagent_containers/food/snacks/rawcutlet

/obj/structure/dehydrator/attackby(var/obj/item/stack/W as obj, var/mob/living/carbon/human/H as mob)
	if (filled >= 4)
		H << "<span class='notice'>\The [src] is full!</span>"
		return
	else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/rawcutlet) && filled < 4)
		var/obj/item/weapon/reagent_containers/food/snacks/rawcutlet/RC = W
		if (RC.rotten == TRUE)
			H << "This [src] is rotten."
			return
		else
			H << "You hang the [W.name] to dry."
			filled += 1
			obj_type = W.type
			icon_state = "wood_drier[filled]"
			qdel(W)
			dry_obj(obj_type)
			return

/obj/structure/dehydrator/proc/dry_obj(var/obj_type = null)
	spawn(1200) //2 minutes
		if (obj_type == /obj/item/weapon/reagent_containers/food/snacks/rawcutlet)
			new/obj/item/weapon/reagent_containers/food/snacks/driedmeat(src.loc)
			visible_message("The meat finishes drying.")
			filled -= 1
			icon_state = "wood_drier[filled]"
			return