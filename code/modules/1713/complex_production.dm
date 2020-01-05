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
	if (istype(W, /obj/item/weapon/reagent_containers/food/condiment/saltpile) && contents.len <= max_capacity)
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
		else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/rawfish/cod))
			user.drop_from_inventory(W, src, FALSE)
			W.forceMove(src)
			max_capacity = 3
			producttype = W.type
			producttype_name = "cod"
			user << "You add \the [W] to the salting container."
			icon_state = "salting_container_[producttype_name]_[contents.len]"
			return
	else if (producttype == W.type && contents.len < max_capacity && !salting)
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
		if (producttype_name == "cod")
			for(var/i=1, i<=max_capacity, i++)
				new/obj/item/weapon/reagent_containers/food/snacks/rawfish/cod/salted(loc)
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

/////////////////////////////////////////////////
//////////////////////CHICKEN////////////////////
/////////////////////////////////////////////////

/obj/item/weapon/chicken_carcass
	name = "chicken carcass"
	desc = "a whole chicken."
	icon = 'icons/obj/food/chicken.dmi'
	icon_state = "chicken_carcass"
	force = WEAPON_FORCE_WEAK
	throw_range = 2
	w_class = 3.0
	flammable = TRUE
	var/rotten = FALSE

/obj/item/weapon/chicken_carcass/New()
	..()
	spawn(3000) //5 minutes
		icon_state = "rotten_[icon]"
		name = "rotten [name]"
		rotten = TRUE
		spawn(1000)
			if (isturf(loc) && prob(30))
				var/scavengerspawn = rand(1,3)
				if(scavengerspawn ==  1)
					new/mob/living/simple_animal/mouse(get_turf(src))
				else if(scavengerspawn ==  2)
					new/mob/living/simple_animal/cockroach(get_turf(src))
				else
					new/mob/living/simple_animal/fly(get_turf(src))
		spawn(3600)
			qdel(src)

/obj/item/weapon/chicken_carcass/attackby(obj/item/weapon/W as obj, mob/living/carbon/human/user as mob)
	if (istype(W, /obj/item/weapon/material/kitchen/utensil/knife) && !rotten)
		user << "You start separating the chicken parts..."
		if (do_after(user, 75, src))
			user << "You finish cutting the chicken."
			new/obj/item/weapon/reagent_containers/food/snacks/chicken/breast(loc)
			new/obj/item/weapon/reagent_containers/food/snacks/chicken/wing(loc)
			new/obj/item/weapon/reagent_containers/food/snacks/chicken/drumstick(loc)
			qdel(src)
		return
	..()
/obj/item/weapon/reagent_containers/food/snacks/chicken
	name = "chicken part"
	icon = 'icons/obj/food/chicken.dmi'
	desc = "A large chicken breast."
	icon_state = "chicken_breast"
	health = 180
	filling_color = "#E7B7B4"
	raw = TRUE
	var/rotten = FALSE
	non_vegetarian = TRUE
	decay = 15*600
	New()
		..()
		reagents.add_reagent("protein", 3)
	bitesize = 3
	satisfaction = -3

/obj/item/weapon/reagent_containers/food/snacks/chicken/breast
	name = "chicken breast"
	desc = "A large chicken breast."
	icon_state = "chicken_breast"

	attackby(obj/item/weapon/W as obj, mob/living/carbon/human/user as mob)
		if (istype(W, /obj/item/weapon/hammer) && !findtext(icon_state, "flat") && !rotten)
			user << "You start flattening the chicken breast..."
			if (do_after(user, 50, src))
				user << "You finish flattening the chicken breast."
				name = "flattened chicken breast"
				icon_state = "chicken_breast_flat"
			return
		else if (istype(W, /obj/item/weapon/reagent_containers/food/condiment/flour) && !rotten && !findtext(icon_state, "crumbed") && findtext(icon_state, "flat"))
			var/obj/item/weapon/reagent_containers/food/condiment/flour/F = W
			if (F.reagents.has_reagent("flour", 5))
				F.reagents.remove_reagent("flour", 5)
			user << "You roll \the [src] in the flour."
			satisfaction = -4
			icon_state = "[icon_state]_crumbed"
			name = "crumbed [name]"
			return
		..()
/obj/item/weapon/reagent_containers/food/snacks/chicken/wing
	name = "chicken wing"
	desc = "A chicken wing."
	icon_state = "chicken_wing"
	bitesize = 2
	satisfaction = -2
	New()
		..()
		reagents.remove_reagent("protein", 2)
	attackby(obj/item/weapon/W as obj, mob/living/carbon/human/user as mob)

		if (istype(W, /obj/item/weapon/reagent_containers/food/condiment/flour) && !rotten && !findtext(icon_state, "crumbed"))
			var/obj/item/weapon/reagent_containers/food/condiment/flour/F = W
			if (F.reagents.has_reagent("flour", 5))
				F.reagents.remove_reagent("flour", 5)
			user << "You roll \the [src] in the flour."
			icon_state = "[icon_state]_crumbed"
			name = "crumbed [name]"
			satisfaction = -3
			return
		..()

/obj/item/weapon/reagent_containers/food/snacks/chicken/drumstick
	name = "chicken drumstick"
	desc = "A chicken drumstick."
	icon_state = "chicken_drumstick"
	bitesize = 2
	satisfaction = -2
	New()
		..()
		reagents.remove_reagent("protein", 2)

	attackby(obj/item/weapon/W as obj, mob/living/carbon/human/user as mob)
		if (istype(W, /obj/item/weapon/reagent_containers/food/condiment/flour) && !rotten && !findtext(icon_state, "crumbed"))
			var/obj/item/weapon/reagent_containers/food/condiment/flour/F = W
			if (F.reagents.has_reagent("flour", 5))
				F.reagents.remove_reagent("flour", 5)
			user << "You roll \the [src] in the flour."
			satisfaction = -3
			icon_state = "[icon_state]_crumbed"
			name = "crumbed [name]"
			return
		..()
/obj/item/weapon/reagent_containers/food/snacks/chicken/New()
	..()
	spawn(3000) //5 minutes
		icon_state = "rotten_[icon]"
		name = "rotten [name]"
		if (reagents)
			reagents.remove_reagent("protein", 2)
			reagents.add_reagent("food_poisoning", 1)
		rotten = TRUE
		satisfaction = -10
		spawn(1000)
			if (isturf(loc) && prob(30))
				var/scavengerspawn = rand(1,3)
				if(scavengerspawn ==  1)
					new/mob/living/simple_animal/mouse(get_turf(src))
				else if(scavengerspawn ==  2)
					new/mob/living/simple_animal/cockroach(get_turf(src))
				else
					new/mob/living/simple_animal/fly(get_turf(src))
		spawn(3600)
			qdel(src)
