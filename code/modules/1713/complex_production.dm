/////////////////////////////////////////////////
//////////////////////JAMÓN//////////////////////
/////////////////////////////////////////////////

/obj/item/weapon/pigleg
	name = "raw ham"
	desc = "a raw, bloody pork leg."
	icon = 'icons/obj/complex_foods.dmi'
	icon_state = "bloody_ham"
	force = WEAPON_FORCE_WEAK+5
	throw_range = 2
	w_class = 4.0
	flammable = TRUE
	var/bloody = TRUE
	var/ready = FALSE
	var/salted = FALSE
	var/slices = 5
/obj/item/weapon/pigleg/bloodless
	bloody = FALSE
	name = "bloodless raw ham"
	desc = "a raw, bloodless pork leg."
	icon_state = "no_blood_ham"

/obj/item/weapon/pigleg/salted
	bloody = FALSE
	name = "salted ham"
	desc = "a salted, but not dried, pork leg."
	icon_state = "salted_ham"
	salted = TRUE

/obj/item/weapon/pigleg/salted/dried
	name = "dried ham"
	desc = "a dried, ready to eat ham. Delicious!"
	icon_state = "dried_ham"
	ready = TRUE

/obj/item/weapon/pigleg/salted/dried/packaged
	name = "packaged ham"
	desc = "a dried, ready to eat ham, wrapped in a protective case. Delicious!"
	icon_state = "labeled_ham"

/obj/item/weapon/pigleg/attackby(var/obj/item/W as obj, var/mob/living/carbon/human/user as mob)
	if (slices<=0)
		qdel(src)
	if (istype(W, /obj/item/weapon/material/kitchen/utensil/knife) && slices>0 && ready)
		user << "You carefully cut a thin ham slice from the ham."
		slices--
		new/obj/item/weapon/reagent_containers/food/snacks/curedham(user.loc)
		if (slices<=0)
			qdel(src)
		return
	else if (istype(W, /obj/item/weapon/hammer) && bloody)
		user << "You start beating the ham with the hammer..."
		if (do_after(user, 100, src))
			user << "You finish beating the ham with the hammer, removing the blood."
			bloody = FALSE
			name = "bloodless raw ham"
			desc = "a raw, bloodless pork leg."
			icon_state = "no_blood_ham"
			return
	..()
/obj/structure/salting_container
	name = "salting container"
	desc = "A wood container, used to salt foods for preservation."
	icon = 'icons/obj/complex_foods.dmi'
	icon_state = "salting_container"
	flammable = TRUE
	anchored = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/producttype = null
	var/producttype_name = "ham"
	var/max_capacity = 3
	var/saltamount = 0
	var/salting = FALSE

/obj/item/weapon/reagent_containers/food/snacks/curedham
	name = "cured ham slice"
	desc = "Delicious Iberian-style jamón."
	icon = 'icons/obj/complex_foods.dmi'
	icon_state = "ham_ready_to_eat"
	trash = null
	filling_color = null
	nutriment_desc = list("cured meat" = 4)
	satisfaction = 10
	nutriment_amt = 2
	New()
		..()
		reagents.add_reagent("protein", 4)
		bitesize = 2

/obj/structure/salting_container/attackby(var/obj/item/W as obj, var/mob/living/carbon/human/user as mob)
	if (salting)
		user << "<span class=warning>The container is full!</span>"
		return
	if (istype(W, /obj/item/weapon/reagent_containers/food/condiment/saltpile) && contents.len >= max_capacity)
		if (saltamount < 30)
			user << "You add salt to the container."
			saltamount += W.reagents.get_reagent_amount("sodiumchloride")
			qdel(W)
			if (saltamount >= 30)
				user << "The salting container is now filled up."
				icon_state = "salting_container_processing"
				salting = TRUE
				salting()
			return
	if (!producttype && !contents.len)
		if (istype(W, /obj/item/weapon/pigleg))
			user.drop_from_inventory(W, src, FALSE)
			W.forceMove(src)
			max_capacity = 3
			producttype = W.type
			producttype_name = "ham"
			user << "You add \the [W] to the salting container."
			icon_state = "salting_container_[producttype_name]_[contents.len]"
			return
	else if (producttype == W.type && contents.len < max_capacity)
		user.drop_from_inventory(W, src, FALSE)
		W.forceMove(src)
		user << "You add \the [W] to the salting container."
		icon_state = "salting_container_[producttype_name]_[contents.len]"
		return
	else if (producttype == W.type && contents.len >= max_capacity)
		user << "<span class=warning>You can't add any more [W] to the container.</span>"
		return
	else if (producttype != W.type)
		user << "<span class=warning>This is the wrong type of product!</span>"
		return
	else
		..()

/obj/structure/salting_container/proc/salting()
	spawn(3600)
		salting = FALSE
		icon_state = "salting_container"
		visible_message("The products in the salting container are ready.")
		saltamount = 0
		for (var/obj/item/I in contents)
			qdel(I)
		if (producttype_name == "ham")
			for(var/i=1, i<=max_capacity, i++)
				new/obj/item/weapon/pigleg/salted(loc)

///////////////////////////////LARGE/DEHYDRATOR///////////////////////////////
/obj/structure/drying_rack
	name = "drying rack"
	desc = "A large iron drying rack, used to dry hams and other food products."
	icon = 'icons/obj/complex_foods.dmi'
	icon_state = "drying_rack"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/producttype = null
	var/producttype_name = "ham"
	var/filled = 0
	var/max_capacity = 3
	var/drying = FALSE

/obj/structure/drying_rack/attackby(var/obj/item/stack/W as obj, var/mob/living/carbon/human/H as mob)
	if (filled >= max_capacity)
		H << "<span class='notice'>\The [src] is full!</span>"
		return
	if (filled == 0 || istype(W, producttype))
		if (istype(W, /obj/item/weapon/pigleg) && filled < max_capacity)
			var/obj/item/weapon/pigleg/P = W
			if (P.salted && !P.bloody && !P.ready)
				H << "You hang the [W.name] to dry."
				producttype_name = "ham"
				producttype = /obj/item/weapon/pigleg
				filled += 1
				icon_state = "drying_rack_[producttype_name]_[filled]"
				qdel(W)
				dry_obj(producttype)
				return
	else if (!istype(W, producttype) && filled > 0)
		H << "<span class=warning>You can't dry this at the same time as you dry [producttype_name]."
		return
	else if (filled == 0)
		if (istype(W, /obj/item/weapon/pigleg))
			var/obj/item/weapon/pigleg/P = W
			if (P.salted && !P.bloody && !P.ready)
				H << "You hang the [W.name] to dry."
				producttype_name = "ham"
				producttype = /obj/item/weapon/pigleg
				filled += 1
				icon_state = "drying_rack_[producttype_name]_[filled]"
				qdel(W)
				dry_obj(producttype)
				return

/obj/structure/drying_rack/proc/dry_obj(var/obj_type = null)
	spawn(12000) //20 minutes
		if (!src || !loc)
			return
		if (obj_type == /obj/item/weapon/pigleg)
			if (isturf(src.loc))
				new/obj/item/weapon/pigleg/salted/dried(src.loc)
			visible_message("The [producttype_name] finishes drying.")
			filled -= 1
			if (filled)
				icon_state = "drying_rack_[producttype_name]_[filled]"
			else
				icon_state = "drying_rack"
			return