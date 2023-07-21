//Food items that are eaten normally and don't leave anything behind.
/obj/item/weapon/reagent_containers/food/snacks/MRE
	name = "MRE"
	desc = "horrible food"
	nutriment_desc = list("horrible food" = 1)
	nutriment_amt = 5
	var/open = FALSE
	var/opens = TRUE
	var/base_state = ""
	trash = null
	flammable = TRUE
	decay = 1200*6000
	non_vegetarian = TRUE
/obj/item/weapon/reagent_containers/food/snacks/MRE/attack(mob/M as mob, mob/user as mob, def_zone)
	if (!open && opens && M == user)
		user << "<span class = 'warning'>Open it first.</span>"
		return FALSE
	return ..(M, user, def_zone)

/obj/item/weapon/reagent_containers/food/snacks/MRE/attack_self(var/mob/living/human/H)
	if (!istype(H))
		return
	if (!open && opens)
		playsound(get_turf(src), 'sound/effects/rip_pack.ogg', 100)
		visible_message("<span class = 'notice'>[H] opens [src].</span>")
		icon_state = "[base_state]_open"
		open = TRUE
	return

// generic MRE

/obj/item/weapon/reagent_containers/food/snacks/MRE/generic
	base_state = "mre_food"
	icon_state = "mre_food"
	name = "MRE"
	opens = FALSE
	trash = /obj/item/weapon/generic_MRE_trash
	flags = FALSE
/obj/item/weapon/generic_MRE_trash
	icon = 'icons/obj/food/food.dmi'
	icon_state = "mre_food_trash"
	name = "MRE trash"
	desc = "The remains of some MRE."
	w_class = ITEM_SIZE_TINY

/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/german
	name = "German MRE: Sauerkraut"
	desc = "A pickled cabbage MRE."
	nutriment_desc = list("pickled cabbage" = 1)

/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/british
	name = "British MRE: Meat"
	desc = "A meat MRE."
	nutriment_desc = list("meat" = 1)

/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/french
	name = "French MRE: Cheese"
	desc = "A cheese MRE."
	nutriment_desc = list("cheese" = 1)

/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/pirates
	name = "Soviet MRE: Cabbage"
	desc = "A cabbage MRE."
	nutriment_desc = list("overcooked cabbage" = 1)

/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/italian
	name = "Italian MRE: Spaghetti"
	desc = "Mama mia!"
	nutriment_desc = list("spaghett" = 1, "tomat" = 1, "spicia meatball")

/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/american
	name = "American MRE: Meat"
	desc = "A package of meat and vegetables."
	nutriment_desc = list("meat" = 1, "carot" = 2, "corn" = 2, "cabbage" = 2, "potato" = 2)

/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/blugoslavian
	name = "Blugoslavian MRE: General Combat Rations"
	desc = "A sealed package of everything you need to keep up the fight!."
	nutriment_desc = list("meat" = 2, "carot" = 1, "corn" = 1, "cabbage" = 1, "potato" = 1, "tea", 2)

/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/blugoslavian/officer
	name = "Blugoslavian Officer MRE: Pizza with Coffee"
	desc = "A sealed package of the good stuff, reserved only for the best of the best!."
	nutriment_desc = list("coffee", 5, "baked pastry" = 4, "spices" = 2, "cheese" = 4)

/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/redmenian
	name = "Redmenian MRE: General Combat Rations"
	desc = "A sealed package of everything you need to keep up the fight!."
	nutriment_desc = list("meat" = 2, "carot" = 1, "corn" = 1, "cabbage" = 1, "potato" = 1, "tea", 2)

/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/redmenian/officer
	name = "Redmenian Officer MRE: Sweetroll with Coffee"
	desc = "A sealed package of the good stuff, reserved only for the best of the best!."
	nutriment_desc = list("coffee", 5, "baked pastry" = 2, "sweetness" = 3, "icing" = 2, "donut" = 2)

/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/japanese
	name = "Japanese MRE: Noodles"
	desc = "A package of precooked noodles and dry meat."
	nutriment_desc = list("noodles" = 1, "carot" = 1, "corn" = 1, "cabbage" = 1, "potato" = 1, "dried meat" = 1)

/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/russian
	name = "Russian MRE: Potatoes"
	desc = "A package of precooked potatoes."
	nutriment_desc = list("potato" = 1,)

/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/idf
	name = "IDF MRE: Whitefish"
	desc = "A package of unidentified kosher whitefish."
	nutriment_desc = list("fish" = 1,)

/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/russian/modern
	name = "Russian MRE: Combat rations"
	desc = "A package of potatoes, meat, canned veggies and some tea."
	nutriment_desc = list("potato" = 1, "meat" = 2, "canned vegetables" = 2,"tea" = 2)

/obj/item/weapon/reagent_containers/food/snacks/MRE/generic/space
	name = "Ration pack"
	desc = "A package of polystarch portion bread and veg-meat."
	nutriment_desc = list("polystarch" = 1, "veg-meat" =1)