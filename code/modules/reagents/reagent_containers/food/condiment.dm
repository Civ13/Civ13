
///////////////////////////////////////////////Condiments
//Notes by Darem: The condiments food-subtype is for stuff you don't actually eat but you use to modify existing food. They all
//	leave empty containers when used up and can be filled/re-filled with other items. Formatting for first section is identical
//	to mixed-drinks code. If you want an object that starts pre-loaded, you need to make it in addition to the other code.

//Food items that aren't eaten normally and leave an empty container behind.
/obj/item/weapon/reagent_containers/food/condiment
	name = "Condiment Container"
	desc = "Just your average condiment container."
	icon = 'icons/obj/food.dmi'
	icon_state = "emptycondiment"
	flags = OPENCONTAINER
	possible_transfer_amounts = list(1,5,10)
	center_of_mass = list("x"=16, "y"=6)
	volume = 50
	flammable = TRUE
	attackby(var/obj/item/weapon/W as obj, var/mob/user as mob)
		return

	attack_self(var/mob/user as mob)
		return

	attack(var/mob/M as mob, var/mob/user as mob, var/def_zone)
		if (standard_feed_mob(user, M))
			return

	afterattack(var/obj/target, var/mob/user, var/proximity)
		if (!proximity)
			return

		if (istype(target, /obj/structure/pot))
			return

		if (standard_dispenser_refill(user, target))
			return
		if (standard_pour_into(user, target))
			return

		if (istype(target, /obj/item/weapon/reagent_containers/food/snacks)) // These are not opencontainers but we can transfer to them
			if (!reagents || !reagents.total_volume)
				user << "<span class='notice'>There is no condiment left in \the [src].</span>"
				return

			if (!target.reagents.get_free_space())
				user << "<span class='notice'>You can't add more condiment to \the [target].</span>"
				return

			var/trans = reagents.trans_to_obj(target, amount_per_transfer_from_this)
			user << "<span class='notice'>You add [trans] units of the condiment to \the [target].</span>"
		else
			..()

	feed_sound(var/mob/user)
		playsound(user.loc, 'sound/items/drink.ogg', rand(10, 50), TRUE)

	self_feed_message(var/mob/user)
		user << "<span class='notice'>You swallow some of contents of \the [src].</span>"

	on_reagent_change()
		if (icon_state == "saltshakersmall" || icon_state == "peppermillsmall")
			return
		if (reagents.reagent_list.len > 0)
			switch(reagents.get_master_reagent_id())
				if ("ketchup")
					name = "Ketchup"
					desc = "You feel more American already."
					icon_state = "ketchup"
					center_of_mass = list("x"=16, "y"=6)
				if ("capsaicin")
					name = "Hotsauce"
					desc = "You can almost TASTE the stomach ulcers now!"
					icon_state = "hotsauce"
					center_of_mass = list("x"=16, "y"=6)
				if ("enzyme")
					name = "Yeast"
					desc = "Used in fermentation of food and drinks."
					icon_state = "enzyme"
					center_of_mass = list("x"=16, "y"=6)
				if ("soysauce")
					name = "Soy Sauce"
					desc = "A salty soy-based flavoring."
					icon_state = "soysauce"
					center_of_mass = list("x"=16, "y"=6)
				if ("frostoil")
					name = "Coldsauce"
					desc = "Leaves the tongue numb in its passage."
					icon_state = "coldsauce"
					center_of_mass = list("x"=16, "y"=6)
				if ("sodiumchloride")
					name = "Salt Shaker"
					desc = "Salt. From the oceans, presumably."
					icon_state = "saltshaker"
					center_of_mass = list("x"=16, "y"=10)
				if ("blackpepper")
					name = "Pepper Mill"
					desc = "Often used to flavor food or make people sneeze."
					icon_state = "peppermillsmall"
					center_of_mass = list("x"=16, "y"=10)
				if ("cornoil")
					name = "Corn Oil"
					desc = "A delicious oil used in cooking. Made from corn."
					icon_state = "oliveoil"
					center_of_mass = list("x"=16, "y"=6)
				if ("sugar")
					name = "Sugar"
					desc = "Sweet!"
					center_of_mass = list("x"=16, "y"=6)
				if ("tea")
					name = "Tea Leaves"
					desc = "Mix with hot water."
					center_of_mass = list("x"=16, "y"=6)
				if ("flour")
					name = "flour sack"
					desc = "A sack of wheat flour."
					center_of_mass = list("x"=16, "y"=6)
				else
					name = "Misc Condiment Bottle"
					if (reagents.reagent_list.len==1)
						desc = "Looks like it is [reagents.get_master_reagent_name()], but you are not sure."
					else
						desc = "A mixture of various condiments. [reagents.get_master_reagent_name()] is one of them."
					icon_state = "mixedcondiments"
					center_of_mass = list("x"=16, "y"=6)
		else
			icon_state = "emptycondiment"
			name = "Condiment Bottle"
			desc = "An empty condiment bottle."
			center_of_mass = list("x"=16, "y"=6)
			qdel(src)
			return

/obj/item/weapon/reagent_containers/food/condiment/enzyme
	name = "Yeast"
	desc = "Used in fermentation of food and drinks."
	icon_state = "enzyme"
	decay = 30*600
	New()
		..()
		reagents.add_reagent("enzyme", 50)

/obj/item/weapon/reagent_containers/food/condiment/sugar
	decay = 45*600
	New()
		..()
		reagents.add_reagent("sugar", 50)
/obj/item/weapon/reagent_containers/food/condiment/saltshaker		//Seperate from above since it's a small shaker rather then
	name = "Salt Shaker"											//	a large one.
	desc = "Salt. From the oceans, presumably."
	icon_state = "saltshakersmall"
	possible_transfer_amounts = list(1,20) //for clown turning the lid off
	amount_per_transfer_from_this = TRUE
	volume = 20
	New()
		..()
		reagents.add_reagent("sodiumchloride", 20)

/obj/item/weapon/reagent_containers/food/condiment/peppermill
	name = "Pepper Mill"
	desc = "Often used to flavor food or make people sneeze."
	icon_state = "peppermillsmall"
	possible_transfer_amounts = list(1,20) //for clown turning the lid off
	amount_per_transfer_from_this = TRUE
	volume = 20
	New()
		..()
		reagents.add_reagent("blackpepper", 20)

/obj/item/weapon/reagent_containers/food/condiment/flour
	name = "flour sack"
	desc = "A bag of flour. Good for baking!"
	icon = 'icons/obj/food.dmi'
	icon_state = "flour"
	item_state = "flour"
	decay = 45*600
	satisfaction = -3
	New()
		..()
		reagents.add_reagent("flour", 30)
		pixel_x = rand(-10.0, 10)
		pixel_y = rand(-10.0, 10)
/obj/item/weapon/reagent_containers/food/condiment/flour/attack_self(mob/user)
	var/obj/item/weapon/reagent_containers/glass/WW
	if (!istype(user.l_hand, /obj/item/weapon/reagent_containers/glass))
		if(!istype(user.r_hand, /obj/item/weapon/reagent_containers/glass))
			user << "<span class = 'warning'>You need to be holding water in the other hand to make dough.</span>"
			return
		else
			WW = user.r_hand
	else
		WW = user.l_hand
	if (WW.reagents.has_reagent("water", 5))
		if (src.reagents.has_reagent("flour", 5))
			WW.reagents.remove_reagent("water", 5)
			src.reagents.remove_reagent("flour", 5)
			new/obj/item/weapon/reagent_containers/food/snacks/dough(user.loc)
			return
		else
			user << "<span class = 'warning'>You need more flour.</span>"
			return
	else
		user << "<span class = 'warning'>You need more water.</span>"
		return

/obj/item/weapon/reagent_containers/food/condiment/bsugar
	name = "sugarcane sugar"
	desc = "a pile of unrefined brown sugar."
	icon = 'icons/obj/food.dmi'
	icon_state = "sugar"
	item_state = "flour"
	satisfaction = 8
	New()
		..()
		reagents.add_reagent("sugar", 30)
		pixel_x = rand(-10.0, 10)
		pixel_y = rand(-10.0, 10)
	decay = 60*00
/obj/item/weapon/reagent_containers/food/condiment/tealeaves
	name = "tea leaves"
	desc = "some tea leaves. mix with hot water."
	icon = 'icons/obj/food.dmi'
	icon_state = "tea_leaves_dried"
	item_state = "flour"
	decay = 80*600
	satisfaction = 4
	New()
		..()
		reagents.add_reagent("tea", 10)
		pixel_x = rand(-10.0, 10)
		pixel_y = rand(-10.0, 10)