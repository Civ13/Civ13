// the botany & seed system was removed entirely, so now we have this
// because bay removed the color from sprites, we recolor them manually

/obj/item/weapon/reagent_containers/food/snacks/grown
	name = "some magical supertype of all grown foods. Why is this even here"
	nutriment_amt = 1
	nutriment_desc = list("fruit" = TRUE)
	w_class = 1.0
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
	color = "#6AAF6A"
	decay = 60*600
	New()
		..()
		reagents.add_reagent("peyote", 5)

/obj/item/weapon/reagent_containers/food/snacks/grown/coffee
	name = "green coffee"
	icon_state = "coffee"
	color = "#a5201d"
	decay = 90*600
	satisfaction = 8
	New()
		..()
		reagents.add_reagent("coffee", 15)
// fruit
/obj/item/weapon/reagent_containers/food/snacks/grown/grapes
	name = "bunch of grapes"
	icon_state = "grapes"
	color = "#7a378b"
	satisfaction = 4
	decay = 12*600
/obj/item/weapon/reagent_containers/food/snacks/grown/olives
	name = "bunch of olives"
	icon_state = "olives"
	decay = 35*600
/obj/item/weapon/reagent_containers/food/snacks/grown/mushroom
	name = "bunch of mushrooms"
	icon_state = "mushrooms"
	satisfaction = 4
	decay = 15*600
/obj/item/weapon/reagent_containers/food/snacks/grown/melon
	name = "melon"
	icon_state = "melon"
	satisfaction = 4
	color = "#f08080"

/obj/item/weapon/reagent_containers/food/snacks/grown/lemon
	name = "lemon"
	icon_state = "lemon"
	satisfaction = -2
//	color = "#eedd82"

/obj/item/weapon/reagent_containers/food/snacks/grown/lime
	name = "lime"
	icon_state = "lime"
	satisfaction = -2
//	color = "#32cd32"

/obj/item/weapon/reagent_containers/food/snacks/grown/orange
	name = "orange"
	icon_state = "orange"
	satisfaction = 3
//	color = "#ffa500"

/obj/item/weapon/reagent_containers/food/snacks/grown/apple
	name = "apple"
	icon_state = "apple"
	satisfaction = 3
//	color = "#ff0000"
/obj/item/weapon/reagent_containers/food/snacks/grown/banana
	name = "banana"
	icon_state = "banana"
	satisfaction = 6
	decay = 15*600
/obj/item/weapon/reagent_containers/food/snacks/grown/coconut
	name = "coconut"
	icon_state = "coconut"
	satisfaction = 3
// misc crops
/obj/item/weapon/reagent_containers/food/snacks/grown/rice
	name = "rice stalk"
	icon_state = "rice"
	color = "#dcdcdc"
	nutriment_desc = list("rice" = TRUE)
	decay = 0
	satisfaction = -2
/obj/item/weapon/reagent_containers/food/snacks/grown/wheat
	name = "wheat"
	icon_state = "wheat"
	desc = "wheat. Can be milled."
	color = "#fffaf0"
	nutriment_desc = list("wheat" = TRUE)
	decay = 55*600
	satisfaction = -2
/obj/item/weapon/reagent_containers/food/snacks/grown/tomato
	name = "tomato"
	icon_state = "tomato"
	color = "#ff0000"
	nutriment_desc = list("tomato" = TRUE)
	decay = 15*600
	satisfaction = 3
/obj/item/weapon/reagent_containers/food/snacks/grown/potato
	name = "potato"
	icon_state = "potato"
	color = "#8b7355"
	nutriment_desc = list("potato" = TRUE)
	decay = 70*600
	satisfaction = -3
/obj/item/weapon/reagent_containers/food/snacks/grown/beans
	name = "beans"
	icon_state = "beans"
	color = "#8b7355"
	nutriment_desc = list("beans" = TRUE)
	decay = 60*600
/obj/item/weapon/reagent_containers/food/snacks/grown/cabbage
	name = "head of cabbage"
	icon_state = "cabbage"
	color = "#caff70"
	nutriment_desc = list("cabbage" = TRUE)
	decay = 20*600
/obj/item/weapon/reagent_containers/food/snacks/grown/carrot
	name = "carrot"
	icon_state = "carrot"
	color = "#ff8c00"
	nutriment_desc = list("carrot" = TRUE)

/obj/item/weapon/reagent_containers/food/snacks/grown/corn
	name = "corn"
	icon_state = "corn"
	color = "#8b7355"
	nutriment_desc = list("corn" = TRUE)
	decay = 35*600
	satisfaction = 2
/obj/item/weapon/reagent_containers/food/snacks/grown/corn/attack_self(mob/user as mob)
	if (do_after(user, 120, user.loc))
		new/obj/item/clothing/mask/smokable/pipe/cobpipe(user.loc)
		qdel(src)
		return
	else
		return