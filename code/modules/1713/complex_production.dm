/////////////////////////////////////////////////
////////////////////PEMMICAN/////////////////////
/////////////////////////////////////////////////
/obj/item/weapon/reagent_containers/food/snacks/pemmican
	name = "Pemmican"
	desc = "A paste of dried meat mixed with melted fat."
	icon = 'icons/obj/complex_foods.dmi'
	icon_state = "pemmican"
	center_of_mass = list("x"=17, "y"=18)
	nutriment_amt = 6
	nutriment_desc = list("salt" = 3, "animal fat" = 2, "meat" = 2)
	non_vegetarian = TRUE
	decay = 180*900 //50% more than the dried meat
	satisfaction = 4 //double than the dried meat
	New()
		..()
		pixel_x = rand(-8, 8)
		pixel_y = rand(-8, 8)
		bitesize = 2

/obj/item/weapon/reagent_containers/food/snacks/driedmeat/minced_driedmeat //Dried meat, basically
	name = "minced dried meat"
	icon = 'icons/obj/complex_foods.dmi'
	icon_state = "minced_driedmeat"

/obj/item/weapon/reagent_containers/food/snacks/driedmeat/minced_driedmeat/attack_self(mob/user)
	if (istype(user.l_hand, /obj/item/weapon/reagent_containers/glass) || istype(user.r_hand, /obj/item/weapon/reagent_containers/glass))
		var/obj/item/weapon/reagent_containers/glass/G
		if(istype(user.l_hand, /obj/item/weapon/reagent_containers/glass))
			G  = user.l_hand
		else
			G  = user.r_hand
		if (G.reagents.get_reagent_amount("fat_oil") >= 5)
			if(do_after(user, 90))
				visible_message("[user.name] pours the [src.name] into the [G.name], mixing it.")
				G.reagents.remove_reagent("fat_oil", 5)
				new/obj/item/weapon/reagent_containers/food/snacks/pemmican(user.loc)
				qdel(src)
				return
	else
		return ..()

/////////////////////////////////////////////////
//////////////////////JAM�N//////////////////////
/////////////////////////////////////////////////

/obj/item/weapon/pigleg
	name = "raw ham"
	desc = "a raw, bloody pork leg."
	icon = 'icons/obj/complex_foods.dmi'
	icon_state = "bloody_ham"
	force = WEAPON_FORCE_WEAK+5
	flags = FALSE
	throw_range = 2
	w_class = ITEM_SIZE_LARGE
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

/obj/item/weapon/pigleg/attackby(var/obj/item/W as obj, var/mob/living/human/user as mob)
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
	desc = "Delicious Iberian-style jamon."
	icon = 'icons/obj/complex_foods.dmi'
	icon_state = "ham_ready_to_eat"
	trash = null
	filling_color = null
	nutriment_desc = list("cured meat" = 4)
	satisfaction = 10
	nutriment_amt = 2
	non_vegetarian = TRUE
	New()
		..()
		reagents.add_reagent("protein", 4)
		bitesize = 2

/obj/structure/salting_container/attackby(var/obj/item/W as obj, var/mob/living/human/user as mob)
	if (salting)
		user << "<span class=warning>The container is full!</span>"
		return
	if (istype(W, /obj/item/weapon/reagent_containers/food/condiment/saltpile) && contents.len <= max_capacity && contents.len)
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
		else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/sausage))
			user.drop_from_inventory(W, src, FALSE)
			W.forceMove(src)
			max_capacity = 5
			producttype = W.type
			producttype_name = "sausage"
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
		if (producttype_name == "sausage")
			for(var/i=1, i<=max_capacity, i++)
				new/obj/item/weapon/reagent_containers/food/snacks/sausage/salted(loc)
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

/obj/structure/drying_rack/attackby(var/obj/item/stack/W as obj, var/mob/living/human/H as mob)
	if (filled >= max_capacity)
		H << "<span class='notice'>\The [src] is full!</span>"
		return
	if (filled == 0 || istype(W, producttype))
		if (istype(W, /obj/item/weapon/pigleg) && filled < max_capacity)
			var/obj/item/weapon/pigleg/P = W
			if (P.salted && !P.bloody && !P.ready)
				max_capacity = 3
				H << "You hang the [W.name] to dry."
				producttype_name = "ham"
				producttype = /obj/item/weapon/pigleg
				filled += 1
				icon_state = "drying_rack_[producttype_name]_[filled]"
				qdel(W)
				dry_obj(producttype)
				return
		if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/sausage/salted))
			max_capacity = 5
			H << "You hang the [W.name] to dry."
			producttype_name = "salami"
			producttype = /obj/item/weapon/reagent_containers/food/snacks/sausage/salted
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
				max_capacity = 3
				H << "You hang the [W.name] to dry."
				producttype_name = "ham"
				producttype = /obj/item/weapon/pigleg
				filled += 1
				icon_state = "drying_rack_[producttype_name]_[filled]"
				qdel(W)
				dry_obj(producttype)
				return
		if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/sausage/salted))
			max_capacity = 5
			H << "You hang the [W.name] to dry."
			producttype_name = "salami"
			producttype = /obj/item/weapon/reagent_containers/food/snacks/sausage/salted
			filled += 1
			icon_state = "drying_rack_[producttype_name]_[filled]"
			qdel(W)
			dry_obj(producttype)
			return
/obj/structure/drying_rack/proc/dry_obj(var/obj_type = null)
	spawn(1500) //2.5 minutes or so.
		if (obj_type == /obj/item/weapon/reagent_containers/food/snacks/sausage/salted)
			if (isturf(src.loc))
				new/obj/item/weapon/reagent_containers/food/snacks/sausage/salted/salami(src.loc)
			visible_message("The [producttype_name] finishes drying.")
			filled -= 1
			if (filled)
				icon_state = "drying_rack_[producttype_name]_[filled]"
			else
				icon_state = "drying_rack"
			return
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
	w_class = ITEM_SIZE_NORMAL
	flammable = TRUE
	var/rotten = FALSE
	flags = FALSE

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

/obj/item/weapon/chicken_carcass/attackby(obj/item/weapon/W as obj, mob/living/human/user as mob)
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
	rotten_icon_state = "rotten_chicken_breast"
	rots = TRUE
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
	rotten_icon_state = "rotten_chicken_breast"

	attackby(obj/item/weapon/W as obj, mob/living/human/user as mob)
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
	rotten_icon_state = "rotten_chicken_wing"

	New()
		..()
		reagents.remove_reagent("protein", 2)
	attackby(obj/item/weapon/W as obj, mob/living/human/user as mob)

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
	rotten_icon_state = "rotten_chicken_drumstick"
	New()
		..()
		reagents.remove_reagent("protein", 2)

	attackby(obj/item/weapon/W as obj, mob/living/human/user as mob)
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

/////////////////////////////////////////////////
////////////////////SALAMIMIMI///////////////////
/////////////////////////////////////////////////
/obj/item/weapon/reagent_containers/food/snacks/cow
	icon = 'icons/obj/complex_foods.dmi'
/obj/item/weapon/reagent_containers/food/snacks/pig
	icon = 'icons/obj/complex_foods.dmi'

/obj/item/weapon/reagent_containers/food/snacks/cow/stomach
	name = "cow stomach"
	desc = "A stomach from a cow."
	icon_state = "cow_stomach"
	bitesize = 1
	satisfaction = -1
	rotten_icon_state = "cow_stomach_rotten"
	raw = TRUE
	rots = TRUE
	non_vegetarian = TRUE
	decay = 15*1000
	New()
		..()
		reagents.add_reagent("protein", 6)

/obj/item/weapon/reagent_containers/food/snacks/pig/stomach
	name = "pig stomach"
	desc = "A stomach from a pig."
	icon_state = "pig_stomach"
	bitesize = 1
	satisfaction = -1
	rotten_icon_state = "pig_stomach_rotten"
	raw = TRUE
	rots = TRUE
	non_vegetarian = TRUE
	decay = 15*1000
	New()
		..()
		reagents.add_reagent("protein", 4)

//I am just adding it to pig/stomach since it drops less the a big ol' cow/stomach.
/obj/item/weapon/reagent_containers/food/snacks/pig/stomach/goat
	name = "goat stomach"
	desc = "A stomach from a goat."

/obj/item/weapon/reagent_containers/food/snacks/pig/stomach/sheep
	name = "sheep stomach"
	desc = "A stomach from a sheep."

/obj/item/stack/sausagecasing
	name = "Sausage Casing"
	desc = "A casing made from a animals stomach to hold meat."
	icon = 'icons/obj/complex_foods.dmi'
	icon_state = "sausage_casing"
	force = 0
	throw_range = 1
	w_class = 0.0
	flammable = TRUE

/obj/item/weapon/reagent_containers/food/snacks/cow/stomach/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (!rotten && istype(W,/obj/item/weapon/material/kitchen/utensil/knife))
		new /obj/item/weapon/reagent_containers/food/snacks/tripe(src)
		new /obj/item/weapon/reagent_containers/food/snacks/tripe(src)
		user << "You cut the lining out of the stomach."
		if(map.ordinal_age >= 1)
			var/obj/item/stack/sausagecasing/SC = new /obj/item/stack/sausagecasing(src)
			SC.amount = 3
		qdel(src)
	else
		..()
/obj/item/weapon/reagent_containers/food/snacks/pig/stomach/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (!rotten && istype(W,/obj/item/weapon/material/kitchen/utensil/knife))
		new /obj/item/weapon/reagent_containers/food/snacks/tripe(src)
		user << "You cut the lining out of the stomach."
		if(map.ordinal_age >= 1)
			var/obj/item/stack/sausagecasing/SC = new /obj/item/stack/sausagecasing(src)
			SC.amount = 2
		qdel(src)
	else
		..()
/obj/item/weapon/reagent_containers/food/snacks/tripe
	name = "tripe"
	desc = "stomach lining, tasty!"
	icon = 'icons/obj/complex_foods.dmi'
	icon_state = "tripe"
	bitesize = 1
	raw = FALSE
	rotten_icon_state = "tripe_rotten"
	rots = TRUE
	decay = 15*1200
	satisfaction = -1
	non_vegetarian = TRUE
	New()
		..()
		reagents.add_reagent("protein", 2)

/obj/item/weapon/reagent_containers/food/snacks/sausage
	name = "sausage"
	desc = "Meat in a convenient casing."
	icon_state = "sausage"
	icon = 'icons/obj/complex_foods.dmi'
	bitesize = 4
	raw = TRUE
	rotten_icon_state = "sausage_rotten"
	rots = TRUE
	decay = 16*800
	satisfaction = -3
	non_vegetarian = TRUE
	New()
		..()
		reagents.add_reagent("protein", 2)

/obj/item/weapon/reagent_containers/food/snacks/sausage/bratwurst
	name = "bratwurst"
	desc = "German sausage in a slightly larger casing ."
	icon_state = "bratwurst"
	icon = 'icons/obj/complex_foods.dmi'
	bitesize = 5
	raw = TRUE
	rotten_icon_state = "bratwurst_rotten"
	rots = TRUE
	decay = 16*800
	satisfaction = -2.5
	non_vegetarian = TRUE
	New()
		..()
		reagents.add_reagent("protein", 4)

/obj/item/weapon/reagent_containers/food/snacks/sausage/salted
	name = "salted sausage"
	desc = "Meat in a convenient casing. Salted"
	icon_state = "sausage_salted"
	icon = 'icons/obj/complex_foods.dmi'
	bitesize = 4
	raw = TRUE
	rots = FALSE
	satisfaction = -4
	non_vegetarian = TRUE
	decay = 32*800
	New()
		..()
		reagents.add_reagent("protein", 2)

/obj/item/stack/sausagecasing/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W,/obj/item/weapon/reagent_containers/food/snacks/mince))
		user << "You start stuffing the casing with the mince."
		if (do_after(user, 10))
			user << "You stuff the casing with the mince."
			new /obj/item/weapon/reagent_containers/food/snacks/sausage(user.loc)
			qdel(W)
			if(src.amount < 1)
				qdel(src)
			else
				src.amount -=1
	else
		..()

/obj/item/weapon/reagent_containers/food/snacks/sausage/salted/salami
	name = "salami"
	desc = "Meat in a convenient casing, dried and salted."
	icon_state = "salami"
	icon = 'icons/obj/complex_foods.dmi'
	bitesize = 4
	raw = FALSE
	rots = FALSE
	satisfaction = 1
	non_vegetarian = TRUE
	decay = 0
	New()
		..()
		reagents.add_reagent("protein", 4)


/obj/item/weapon/reagent_containers/food/snacks/sausage/salted/salami/attackby(var/obj/item/W as obj, var/mob/living/human/user as mob)
	if (istype(W, /obj/item/weapon/material/kitchen/utensil/knife))
		user << "You slice the salami up."
		new/obj/item/weapon/reagent_containers/food/snacks/sausage/salted/salami/slice(user.loc)
		new/obj/item/weapon/reagent_containers/food/snacks/sausage/salted/salami/slice(user.loc)
		new/obj/item/weapon/reagent_containers/food/snacks/sausage/salted/salami/slice(user.loc)
		new/obj/item/weapon/reagent_containers/food/snacks/sausage/salted/salami/slice(user.loc)
		qdel(src)
		return

/obj/item/weapon/reagent_containers/food/snacks/sausage/salted/salami/slice
	name = "salami slice"
	desc = "Meat in a convenient casing, dried and salted, sliced."
	icon_state = "salami_slice"
	icon = 'icons/obj/complex_foods.dmi'
	bitesize = 1
	raw = FALSE
	rots = FALSE
	satisfaction = 3
	non_vegetarian = TRUE
	New()
		..()
		reagents.add_reagent("protein", 1)

/////////////////////////////////////////////////
////////////////////MINCER///////////////////////
/////////////////////////////////////////////////

//Todo: For salami, mincing, and all food in general, transfer reagents between stages.
//Make mincing work similar to how stew does, all ingredients described.

/obj/item/weapon/reagent_containers/food/snacks/mince
	name = "minced meat"
	desc = "Blended meat."
	icon = 'icons/obj/complex_foods.dmi'
	icon_state = "minced_meat"
	filling_color = "#DB0000"
	bitesize = 2
	raw = TRUE
	rotten_icon_state = "minced_meat_rotten"
	rots = TRUE
	decay = 15*800
	satisfaction = -3
	non_vegetarian = TRUE
	New()
		..()
		reagents.add_reagent("protein", 2)

/obj/item/weapon/reagent_containers/food/snacks/meatball
	name = "meatball"
	desc = "Round meat."
	icon = 'icons/obj/complex_foods.dmi'
	icon_state = "meatball_raw"
	filling_color = "#DB0000"
	bitesize = 3
	raw = TRUE
	rotten_icon_state = "meatball_rotten"
	rots = TRUE
	decay = 15*800
	satisfaction = -4
	non_vegetarian = TRUE
	New()
		..()
		reagents.add_reagent("protein", 2)

/obj/item/weapon/reagent_containers/food/snacks/patty
	name = "meat patty"
	desc = "Circular meat."
	icon_state = "patty_raw"
	icon = 'icons/obj/complex_foods.dmi'
	filling_color = "#DB0000"
	bitesize = 3
	raw = TRUE
	rotten_icon_state = "patty_rotten"
	rots = TRUE
	decay = 15*800
	satisfaction = -4
	non_vegetarian = TRUE
	New()
		..()
		reagents.add_reagent("protein", 2)

/obj/structure/meat_grinder
	name = "meat grinder"
	desc = "A tool used for grinding meat."
	icon = 'icons/obj/complex_foods.dmi'
	icon_state = "meat_grinder_new"
	var/empty_state = "meat_grinder_new"
	var/full_state = "meat_grinder_new_full"
	var/active_state = "meat_grinder_new_grinding"
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/input
	var/output_amount = 0

/obj/structure/meat_grinder/attack_hand(mob/living/human/user as mob)
	if (input != null)
		user << "You start to crank the lever."
		icon_state = active_state
		if (do_after(user, 35))
			playsound(loc, 'sound/effects/rollermove.ogg', 35, TRUE)
			user << "The grinder plops out some mince!"
			for(var/i=1, i<=output_amount, i++)
				new /obj/item/weapon/reagent_containers/food/snacks/mince(get_turf(src))
			input = null
			icon_state = empty_state
		else
			icon_state = full_state

/obj/structure/meat_grinder/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if(input==null)
		if (istype(W, /obj/item/weapon/pigleg) || istype(W, /obj/item/weapon/chicken_carcass))
			input = W
			output_amount = 4
			icon_state = full_state
			user << "You insert the [W] into the [src]"
			qdel(W)
			return
		else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/meat) || istype(W, /obj/item/weapon/reagent_containers/food/snacks/rawfish/) || istype(W, /obj/item/weapon/reagent_containers/food/snacks/chicken))
			input = W
			output_amount = 2
			icon_state = full_state
			user << "You insert the [W] into the [src]"
			qdel(W)
			return
		else if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/rawcutlet) || istype(W, /obj/item/weapon/reagent_containers/food/snacks/fishfillet))
			input = W
			output_amount = 1
			icon_state = full_state
			user << "You insert the [W] into the [src]"
			qdel(W)
			return
		else
			..()
	else
		..()

///////////////////////////////////////////
/////////////CUTTING BOARD/////////////////
///////////////////////////////////////////

/obj/structure/cutting_board
	name = "cutting board"
	desc = "A wood board used to prepare food."
	icon = 'icons/obj/complex_foods.dmi'
	icon_state = "cutting_board"
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/input = null

/obj/structure/cutting_board/attack_hand(var/mob/living/human/H)
	if(input != null)
		if(do_after(H, 20))
			H << "You scrape off the cutting board"
			input = null
			icon_state = "cutting_board_dirty"
			return
		else
			H << "You stop scraping off the cutting board"
			return
	else if(input == null && icon_state == "cutting_board_dirty")
		if(do_after(H, 15))
			H << "You clean the cutting board of all it's filty grime"
			icon_state = "cutting_board"
			return
		else
			H << "You stop cleaning the cutting board"
			return

/obj/structure/cutting_board/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if(istype(W, /obj/item/weapon/material/kitchen/utensil/knife))
		if(input != null)
			if(istype(input, /obj/item/weapon/reagent_containers/food/snacks/fishfillet) || istype(input, /obj/item/weapon/reagent_containers/food/snacks/rawcutlet))
				user << "You begin to mince the [input]."
				playsound(loc, 'sound/effects/stamp.ogg', 60, TRUE)
				if(do_after(user, 180))
					playsound(loc, 'sound/effects/stamp.ogg', 60, TRUE)
					input = null
					icon_state = "cutting_board_dirty"
					new /obj/item/weapon/reagent_containers/food/snacks/mince(src.loc)
					return
				else
					user << "You stop mincing"
					return
			else if(istype(input, /obj/item/weapon/reagent_containers/food/snacks/meat) || istype(input, /obj/item/weapon/reagent_containers/food/snacks/rawfish))
				user << "You begin to mince the [input]."
				playsound(loc, 'sound/effects/stamp.ogg', 60, TRUE)
				if(do_after(user, 180))
					playsound(loc, 'sound/effects/stamp.ogg', 60, TRUE)
					input = null
					icon_state = "cutting_board_dirty"
					new /obj/item/weapon/reagent_containers/food/snacks/mince(src.loc)
					new /obj/item/weapon/reagent_containers/food/snacks/mince(src.loc)
					return
				else
					user << "You stop mincing"
					return
			else if(istype(input, /obj/item/weapon/reagent_containers/food/snacks/mince))
				playsound(loc, 'sound/effects/squishy.ogg', 10, TRUE)
				if(do_after(user, 10))
					playsound(loc, 'sound/effects/squishy.ogg', 10, TRUE)
					user << "You form the [input] into a meatball!"
					input = null
					icon_state = "cutting_board_dirty"
					new /obj/item/weapon/reagent_containers/food/snacks/meatball(src.loc)
					return
				else
					user << "You stop forming the [input]"
					return
			else if(istype(input, /obj/item/weapon/reagent_containers/food/snacks/meatball))
				user << "You smash the [input] into a patty!"
				playsound(loc, 'sound/effects/squishy.ogg', 5, TRUE)
				input = null
				icon_state = "cutting_board_dirty"
				new /obj/item/weapon/reagent_containers/food/snacks/patty(src.loc)
				return
			else if(istype(input, /obj/item/weapon/reagent_containers/food/snacks/driedmeat))
				user << "You begin to mince the [input]."
				playsound(loc, 'sound/effects/stamp.ogg', 60, TRUE)
				if(do_after(user, 180))
					playsound(loc, 'sound/effects/stamp.ogg', 60, TRUE)
					input = null
					icon_state = "cutting_board_dirty"
					new /obj/item/weapon/reagent_containers/food/snacks/driedmeat/minced_driedmeat(src.loc)
					return
			else
				user << "You need to put something on the cutting board!"
				return
	else if(input == null && istype(W, /obj/item/weapon/reagent_containers/food/snacks))
		if(istype(input, /obj/item/weapon/reagent_containers/food/snacks/fishfillet) || istype(input, /obj/item/weapon/reagent_containers/food/snacks/rawcutlet))
			input = W
			user << "You place the [W] on the cutting board."
			icon_state = "cutting_board_cutlet"
			qdel(W)
			return
		else if(istype(W, /obj/item/weapon/reagent_containers/food/snacks/mince))
			input = W
			user << "You place the [W] on the cutting board."
			icon_state = "cutting_board_mince"
			qdel(W)
			return
		else if(istype(W, /obj/item/weapon/reagent_containers/food/snacks/mince))
			input = W
			user << "You place the [W] on the cutting board."
			icon_state = "cutting_board_mince"
			qdel(W)
			return
		else if(istype(W, /obj/item/weapon/reagent_containers/food/snacks/meat))
			input = W
			user << "You place the [W] on the cutting board."
			icon_state = "cutting_board_steak"
			qdel(W)
			return
		else if(istype(W, /obj/item/weapon/reagent_containers/food/snacks/rawfish))
			input = W
			user << "You place the [W] on the cutting board."
			icon_state = "cutting_board_fish"
			qdel(W)
			return
		else if(istype(W, /obj/item/weapon/reagent_containers/food/snacks/meatball))
			input = W
			user << "You place the [W] on the cutting board."
			icon_state = "cutting_board_meatball"
			qdel(W)
			return
		else if(istype(W, /obj/item/weapon/reagent_containers/food/snacks/driedmeat))
			input = W
			user << "You place the [W] on the cutting board."
			icon_state = "cutting_board_driedmeat"
			qdel(W)
			return
		else
			user << "You cannot put that on [src]!"
	else
		..()
	..()
