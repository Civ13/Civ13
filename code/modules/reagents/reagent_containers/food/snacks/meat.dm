/obj/item/weapon/reagent_containers/food/snacks/meat
	name = "meat"
	desc = "A slab of meat."
	icon_state = "meat"
	health = 180
	filling_color = "#FF1C1C"
	center_of_mass = list("x"=16, "y"=14)
	raw = TRUE
	New()
		..()
		reagents.add_reagent("protein", 5)
		bitesize = 3

/obj/item/weapon/reagent_containers/food/snacks/meat/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (!roasted && istype(W,/obj/item/weapon/material/knife))
		new /obj/item/weapon/reagent_containers/food/snacks/rawcutlet(src)
		new /obj/item/weapon/reagent_containers/food/snacks/rawcutlet(src)
		new /obj/item/weapon/reagent_containers/food/snacks/rawcutlet(src)
		user << "You cut the meat into thin strips."
		qdel(src)
	else
		..()

// Seperate definitions because some food likes to know if it's human.
// TODO: rewrite kitchen code to check a var on the meat item so we can remove
// all these sybtypes.
/obj/item/weapon/reagent_containers/food/snacks/meat/human
	name = "human meat"
	desc = "Tastes like chicken."

/obj/item/weapon/reagent_containers/food/snacks/meat/monkey
	name = "monkey meat"
	desc = "Tastes like human."

/obj/item/weapon/reagent_containers/food/snacks/meat/turtle
	name = "turtle meat"
	desc = "Tastes like... something."

/obj/item/weapon/reagent_containers/food/snacks/meat/poisonfrog
	name = "poisononous frog meat"
	desc = "Probably not a good idea to put it in the stew."
	var/uses = 4
	New()
		..()
		reagents.add_reagent("food_poisoning", 15)
		reagents.add_reagent("cyanide", 25)