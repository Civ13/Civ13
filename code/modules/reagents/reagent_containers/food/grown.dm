// the botany & seed system was removed entirely, so now we have this
// because bay removed the color from sprites, we recolor them manually

/obj/item/weapon/reagent_containers/food/snacks/grown
	name = "some magical supertype of all grown foods. Why is this even here"
	nutriment_amt = 1
	nutriment_desc = list("fruit" = TRUE)
	w_class = ITEM_SIZE_TINY
	value = 3
	bitesize = 2
	decay = 25*600
/obj/item/weapon/reagent_containers/food/snacks/grown/chinchona
	name = "chinchona plant"
	icon = 'icons/obj/flora/plants.dmi'
	icon_state = "chinchona_inhand"
	desc = "Contains quinine."
	nutriment_amt = 1
	nutriment_desc = "bitter"
	decay = 70*600
	New()
		..()
		reagents.del_reagents()
		reagents.add_reagent("quinine", 10)

/obj/item/weapon/reagent_containers/food/snacks/grown/peyote
	name = "peyote cactus"
	icon_state = "peyote"
	desc = "A potent hallucinogenic."
	filling_color = "#6AAF6A"
	decay = 120*600
	New()
		..()
		reagents.add_reagent("peyote", 5)

/obj/item/weapon/reagent_containers/food/snacks/grown/juniper
	name = "juniper berry"
	icon_state = "juniper_berry"
	desc = "A normal looking berry."
	filling_color = "#6AAF6A"
	decay = 60*600
	New()
		..()
		reagents.add_reagent("juniper", 5)

/obj/item/weapon/reagent_containers/food/snacks/grown/sapote
	name = "sapote fruit"
	icon_state = "sapote"
	desc = "A very strange fruit with a nutty flavor."
	color = "#4CBB17"
	decay = 60*600
	New()
		..()
		reagents.add_reagent("sapotejuice", 2)

/obj/item/weapon/reagent_containers/food/snacks/grown/parsnip
	name = "parsnip root"
	icon_state = "parsnip"
	desc = "A useful sweetner for food."
	filling_color = "#dad0bc"
	decay = 60*600
	New()
		..()
		reagents.add_reagent("sugar", 2)

/obj/item/weapon/reagent_containers/food/snacks/grown/zucchini
	name = "Zucchini gourd"
	icon_state = "zucchini"
	desc = "A straight gourd plant."
	filling_color = "#6AAF6A"
	decay = 60*600
	New()
		..()
		reagents.add_reagent("zucchinijuice", 5)

/obj/item/weapon/reagent_containers/food/snacks/grown/sapodilla
	name = "sapodilla"
	icon_state = "sapodilla"
	desc = "strangely sweet."
	color = "#f3bc5f"
	decay = 60*600
	New()
		..()
		reagents.add_reagent("sapodillajuice", 5)

/obj/item/weapon/reagent_containers/food/snacks/grown/redpepper
	name = "red pepper"
	icon_state = "paprika_pepper"
	desc = "A very useful pepper for spicing up food."
	decay = 60*600
	New()
		..()
		reagents.add_reagent("capsaicin", 8)

/obj/item/weapon/reagent_containers/food/snacks/grown/liquorice
	name = "liquorice"
	icon_state = "liquorice_root"
	desc = "A very strange tasting root."
	decay = 0
	New()
		..()
		reagents.add_reagent("liquorice", 8)

/obj/item/weapon/reagent_containers/food/snacks/grown/celery
	name = "celery"
	icon_state = "celery_stalk"
	desc = "Tastes like green."
	decay = 60*600
	New()
		..()
		reagents.add_reagent("celery", 8)

/obj/item/weapon/reagent_containers/food/snacks/grown/agave
	name = "agave"
	icon_state = "agave_leaf"
	desc = "A desert plant that is moderately useful."
	decay = 60*600
	New()
		..()
		reagents.add_reagent("agave", 10)

/obj/item/weapon/reagent_containers/food/snacks/grown/parsley
	name = "parsley"
	icon_state = "parsley"
	decay = 90*600
	satisfaction = 2
	New()
		..()
		reagents.add_reagent("parsley", 15)

/obj/item/weapon/reagent_containers/food/snacks/grown/coffee
	name = "green coffee"
	icon_state = "coffee"
	color = "#a5201d"
	decay = 180*600
	satisfaction = 8
	New()
		..()
		reagents.add_reagent("coffee", 15)
// fruit
/obj/item/weapon/reagent_containers/food/snacks/grown/grapes
	name = "bunch of grapes"
	icon_state = "grapes_b"
	filling_color = "#7a378b"
	satisfaction = 4
	decay = 12*600
/obj/item/weapon/reagent_containers/food/snacks/grown/olives
	name = "bunch of olives"
	icon_state = "olives"
	decay = 20*600

/obj/item/weapon/reagent_containers/food/snacks/grown/mushroompsy
	name = "Psilocybin mushroom"
	icon_state = "mushrooms"
	satisfaction = 10
	decay = 35*600
	New()
		..()
		reagents.add_reagent("thc", 30)

/obj/item/weapon/reagent_containers/food/snacks/grown/mushroom
	name = "bunch of mushrooms"
	icon_state = "mushrooms"
	satisfaction = 4
	decay = 30*600

/obj/item/weapon/reagent_containers/food/snacks/grown/watermelon
	name = "watermelon"
	icon_state = "watermelon"
	satisfaction = 4
	filling_color = "#f08080"
	decay = 20*600
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/watermelonslice
	slices_num = 12

/obj/item/weapon/reagent_containers/food/snacks/watermelonslice
	name = "watermelon slice"
	desc = "Slice of juicy watermelon."
	icon_state = "watermelonslice"
	filling_color = "#f08080"
	decay = 18*600

/obj/item/weapon/reagent_containers/food/snacks/grown/pumpkin
	name = "pumpkin"
	icon_state = "pumpkin"
	satisfaction = 4
	filling_color = "#eb9e45"
	decay = 100*600
	slice_path = /obj/item/weapon/reagent_containers/food/snacks/pumpkinslice
	slices_num = 12

/obj/item/weapon/reagent_containers/food/snacks/pumpkinslice
	name = "pumpkin slice"
	desc = "Slice of pumpkin."
	icon_state = "pumpkinslice"
	filling_color = "#eb9e45"
	decay = 20*600

/obj/item/weapon/reagent_containers/food/snacks/grown/lemon //Added proper reagents to food.
	name = "lemon"
	icon_state = "lemon"
	satisfaction = 1
	decay = 100*600
	filling_color = "#eedd82"
	New()
		..()
		reagents.add_reagent("lemonjuice", 20)

/obj/item/weapon/reagent_containers/food/snacks/grown/lime //Added proper reagents to food.
	name = "lime"
	icon_state = "lime"
	satisfaction = 1
	decay = 100*600
	filling_color = "#a7ce68"
	New()
		..()
		reagents.add_reagent("limejuice", 20)

/obj/item/weapon/reagent_containers/food/snacks/grown/orange //Added proper reagents to food.
	name = "orange"
	icon_state = "orange"
	satisfaction = 3
	decay = 100*600
	filling_color = "#ffae00"
	New()
		..()
		reagents.add_reagent("orangejuice", 20)

/obj/item/weapon/reagent_containers/food/snacks/grown/apple //Added proper reagents to food.
	name = "apple"
	icon_state = "apple_green"
	satisfaction = 3
	decay = 50*600
	filling_color = "#dfffaa"
	New()
		..()
		reagents.add_reagent("applejuice", 15)

/obj/item/weapon/reagent_containers/food/snacks/grown/banana //Added proper reagents to food.
	name = "banana"
	icon_state = "banana"
	satisfaction = 6
	decay = 15*600
	filling_color = "#fff896"
	New()
		..()
		reagents.add_reagent("banana", 10)

/obj/item/weapon/reagent_containers/food/snacks/grown/apricot //Added proper reagents to food.
	name = "apricot"
	icon_state = "apricot"
	satisfaction = 6
	decay = 15*600
	New()
		..()
		reagents.add_reagent("apricotjuice", 15)

/obj/item/weapon/reagent_containers/food/snacks/grown/cherry //Added proper reagents to food.
	name = "cherry"
	icon_state = "cherry"
	satisfaction = 6
	decay = 15*600
	New()
		..()
		reagents.add_reagent("cherryjelly", 10)

/obj/item/weapon/reagent_containers/food/snacks/grown/coconut
	name = "coconut"
	icon_state = "coconut"
	satisfaction = 3
	decay = 150*600
	New()
		..()
		reagents.add_reagent("coconutmilk", 20)

/obj/item/weapon/reagent_containers/food/snacks/grown/cocoa
	name = "cocoa beans"
	icon_state = "cocoa"
	satisfaction = -2
	decay = 150*600
	New()
		..()
		reagents.add_reagent("cocoa", 20)

// misc crops
/obj/item/weapon/reagent_containers/food/snacks/grown/rice
	name = "rice stalk"
	icon_state = "rice"
	filling_color = "#dcdcdc"
	nutriment_desc = list("rice" = TRUE)
	decay = 0
	satisfaction = -2
/obj/item/weapon/reagent_containers/food/snacks/grown/wheat
	name = "wheat"
	icon_state = "wheat"
	desc = "wheat. Can be milled."
	filling_color = "#fffaf0"
	nutriment_desc = list("wheat" = TRUE)
	decay = 500*6000
	satisfaction = -2
/obj/item/weapon/reagent_containers/food/snacks/grown/oat
	name = "oat"
	icon_state = "oat"
	desc = "oats. Can be milled."
	filling_color = "#fffaf0"
	nutriment_desc = list("oats" = TRUE)
	decay = 200*6000
	satisfaction = -2
/obj/item/weapon/reagent_containers/food/snacks/grown/barley
	name = "barley"
	icon_state = "barley"
	desc = "barley. Can be milled."
	filling_color = "#fffaf0"
	nutriment_desc = list("barley" = TRUE)
	decay = 200*6000
	satisfaction = -2
/obj/item/weapon/reagent_containers/food/snacks/grown/tomato
	name = "tomato"
	icon_state = "tomato"
	filling_color = "#eb2535"
	nutriment_desc = list("tomato" = TRUE)
	decay = 15*600
	satisfaction = 3
/obj/item/weapon/reagent_containers/food/snacks/grown/potato
	name = "potato"
	icon_state = "potato"
	filling_color = "#fce4c0"
	nutriment_desc = list("potato" = TRUE)
	decay = 70*6000
	satisfaction = -3
/obj/item/weapon/reagent_containers/food/snacks/grown/beans
	name = "beans"
	icon_state = "beans_brownred"
	filling_color = "#a14130"
	nutriment_desc = list("beans" = TRUE)
	decay = 100*6000

/obj/item/weapon/reagent_containers/food/snacks/grown/cabbage
	name = "head of cabbage"
	icon_state = "cabbage"
	filling_color = "#caff70"
	nutriment_desc = list("cabbage" = TRUE)
	decay = 20*600

/obj/item/weapon/reagent_containers/food/snacks/grown/carrot
	name = "carrot"
	icon_state = "carrot"
	filling_color = "#ff5e00"
	nutriment_desc = list("carrot" = TRUE)
	decay = 25*600

/obj/item/weapon/reagent_containers/food/snacks/grown/corn
	name = "corn"
	icon_state = "corn"
	filling_color = "#cebb4f"
	nutriment_desc = list("corn" = TRUE)
	decay = 10*600
	satisfaction = 2

/obj/item/weapon/reagent_containers/food/snacks/grown/corn/attack_self(mob/user as mob)
	if (do_after(user, 120, user.loc))
		new/obj/item/clothing/mask/smokable/pipe/cobpipe(user.loc)
		qdel(src)
		return
	else
		return
