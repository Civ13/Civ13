#define SEAFOOD_DRY_MODIFIER 19 //temporary it placed here. TO DO - move after categorising snacks to snacks.dm
#define MEAT_DRY_MODIFIER 17 //temporary it placed here. TO DO - move after categorising snacks to snacks.dm
#define SALT_MODIFIER 10 //temporary it placed here. TO DO - move after categorising snacks and reworking salting to snacks.dm
#define DRY_MODIFIER 15 //temporary it placed here. TO DO - move after categorising snacks to snacks.dm
#define GROWN_DRY_MODIFIER 21 //temporary it placed here. TO DO - move after categorising snacks to snacks.dm

/obj/item/weapon/reagent_containers/food/snacks/meat
	name = "meat"
	desc = "A slab of meat."
	icon_state = "meat"
	health = 180
	filling_color = "#FF1C1C"
	center_of_mass = list("x"=16, "y"=14)
	raw = TRUE
	rotten_icon_state = "rottenmeat"
	rots = TRUE
	non_vegetarian = TRUE
	decay = 15*600
	New()
		..()
		reagents.add_reagent("protein", 5)
		bitesize = 3
	satisfaction = -4
/obj/item/weapon/reagent_containers/food/snacks/meat/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (!roasted && !rotten && (istype(W,/obj/item/weapon/attachment/bayonet)  || istype(W, /obj/item/weapon/material/hatchet) || istype(W,/obj/item/weapon/material/kitchen/utensil/knife)))
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
	desc = "Tastes like kind of like ham..."
	disgusting = TRUE

/obj/item/weapon/reagent_containers/food/snacks/meat/monkey
	name = "monkey meat"
	desc = "Tastes like human."

/obj/item/weapon/reagent_containers/food/snacks/meat/turtle
	name = "turtle meat"
	desc = "Tastes like... something."

/obj/item/weapon/reagent_containers/food/snacks/meat/poisonfrog
	name = "poisonous frog meat"
	desc = "Probably not a good idea to put it in the stew."
	disgusting = TRUE
	var/uses = 4
	New()
		..()
		reagents.add_reagent("food_poisoning", 15)
		reagents.add_reagent("cyanide", 25)

/obj/item/weapon/reagent_containers/food/snacks/meat/poisonfrog/attack_self(mob/user as mob)

	var/obj/item/ammo_casing/CURRENT = null
	if (user.l_hand == src && istype(user.r_hand, /obj/item/ammo_casing/arrow) && uses >= 1)
		CURRENT = user.r_hand
	else if (user.r_hand == src && istype(user.l_hand, /obj/item/ammo_casing/arrow) && uses >= 1)
		CURRENT = user.l_hand
	if (CURRENT)
		if (istype(CURRENT, /obj/item/ammo_casing/arrow))
			user << "You dip the arrow into the poisonous frog's skin."
			CURRENT.name = "poisoned arrow"
			CURRENT.icon_state = "arrowp"
			CURRENT.projectile_type = /obj/item/projectile/arrow/arrow/vial
			CURRENT.damtype = TOX
			CURRENT.BB = new/obj/item/projectile/arrow/arrow/vial/poisonous(CURRENT)
			CURRENT.contents = list(CURRENT.BB)
			uses = (uses - 1)
		else if (istype(CURRENT, /obj/item/ammo_casing/bolt))
			user << "You dip the bolt into the poisonous frog's skin."
			CURRENT.name = "poisoned bolt"
			CURRENT.icon_state = "boltp"
			CURRENT.projectile_type = /obj/item/projectile/arrow/bolt/vial
			CURRENT.damtype = TOX
			CURRENT.BB = new/obj/item/projectile/arrow/bolt/vial/poisonous(CURRENT)
			CURRENT.contents = list(CURRENT.BB)
			uses = (uses - 1)
		return
	else
		return
/obj/item/weapon/reagent_containers/food/snacks/rawfish
	name = "raw fish"
	desc = "A fresh fish. Should probably cook it first."
	icon_state = "rawfish"
	health = 180
	filling_color = "#606060"
	center_of_mass = list("x"=16, "y"=14)
	raw = TRUE
	rotten_icon_state = "rottenfish"
	rots = TRUE
	non_vegetarian = TRUE
	decay = 15*600
	New()
		..()
		reagents.add_reagent("protein", 4)
		reagents.add_reagent("food_poisoning", 1)
		bitesize = 3
	satisfaction = -4

/obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon
	name = "raw salmon"
	desc = "A fresh salmon. Should probably cook it first."
	icon_state = "salmon"

/obj/item/weapon/reagent_containers/food/snacks/rawfish/cod
	name = "raw cod"
	desc = "A fresh cod salmon. Should probably cook it first."
	icon_state = "cod"
	rotten_icon_state = "rotten_cod"
	rots = TRUE
	New()
		..()
		reagents.add_reagent("protein", 2)
	satisfaction = -6
/obj/item/weapon/reagent_containers/food/snacks/rawfish/cod/salted
	name = "salted cod"
	desc = "A piece of salted cod."
	icon_state = "salted_cod"
	rotten_icon_state = "salted_cod"
	rots = FALSE
	rotten = FALSE
	decay = 0
	New()
		..()
		reagents.remove_reagent("food_poisoning",1)
	satisfaction = 4
/obj/item/weapon/reagent_containers/food/snacks/rawfish/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (!roasted && !istype(src,/obj/item/weapon/reagent_containers/food/snacks/rawfish/cod) && !rotten && (istype(W,/obj/item/weapon/attachment/bayonet) || istype(W,/obj/item/weapon/material/kitchen/utensil/knife) || istype(W, /obj/item/weapon/material/hatchet)))
		new /obj/item/weapon/reagent_containers/food/snacks/fishfillet(src)
		new /obj/item/weapon/reagent_containers/food/snacks/fishfillet(src)
		new /obj/item/weapon/reagent_containers/food/snacks/fishfillet(src)
		user << "You cut the fish into thin fillets."
		qdel(src)
	else
		..()

/obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (!roasted && !rotten && (istype(W,/obj/item/weapon/attachment/bayonet) || istype(W,/obj/item/weapon/material/kitchen/utensil/knife) || istype(W, /obj/item/weapon/material/hatchet)))
		new /obj/item/weapon/reagent_containers/food/snacks/salmonfillet(src)
		new /obj/item/weapon/reagent_containers/food/snacks/salmonfillet(src)
		new /obj/item/weapon/reagent_containers/food/snacks/salmonfillet(src)
		user << "You cut the salmon into thin fillets."
		qdel(src)
	else
		..()

/obj/item/weapon/reagent_containers/food/snacks/rawcrab
	name = "crab meat"
	desc = "Fresh crab meat. Looks tasty."
	icon_state = "raw_crabmeat"
	health = 180
	filling_color = "#7F0000"
	center_of_mass = list("x"=16, "y"=14)
	raw = TRUE
	rotten_icon_state = "rotraw_crabmeat"
	rots = TRUE
	non_vegetarian = TRUE
	satisfaction = -10
	New()
		..()
		reagents.add_reagent("protein", 4)
		reagents.add_reagent("food_poisoning", 1)
		bitesize = 3

/obj/item/weapon/reagent_containers/food/snacks/rawlobster
	name = "lobster"
	desc = "A fresh lobster. Yum!"
	icon_state = "lobster_raw"
	health = 180
	filling_color = "#7F0000"
	center_of_mass = list("x"=16, "y"=14)
	raw = TRUE
	rotten_icon_state = "lobster_rottenraw"
	rots = TRUE
	non_vegetarian = TRUE
	satisfaction = -10
	New()
		..()
		reagents.add_reagent("protein", 4)
		reagents.add_reagent("food_poisoning", 1)
		bitesize = 3

/obj/item/weapon/reagent_containers/food/snacks/rawlobster/boiled
	name = "boiled lobster"
	desc = "A boiled lobster. Looks very tasty."
	icon_state = "lobster_boiled"
	health = 180
	filling_color = "#7F0000"
	center_of_mass = list("x"=16, "y"=14)
	raw = FALSE
	rotten_icon_state = "lobster_rottenboiled"
	rots = TRUE
	non_vegetarian = TRUE
	satisfaction = 25
	New()
		..()
		reagents.remove_reagent("food_poisoning")

/obj/item/weapon/reagent_containers/food/snacks/cockroach
	name = "cockroach"
	desc = "A dead cockroach. No, please don't make me eat it..."
	icon_state = "cockroach"
	rotten_icon_state = "rotten_cockroach"
	filling_color = "#773B00"
	raw = TRUE
	disgusting = TRUE
	non_vegetarian = TRUE
	satisfaction = -20
	rots = TRUE
	New()
		..()
		reagents.add_reagent("protein", 1)
		reagents.add_reagent("food_poisoning", 1)
		bitesize = 3

/obj/item/weapon/reagent_containers/food/snacks/octopus
	name = "octopus"
	desc = "A fresh octopus. Yum!"
	icon_state = "purple_octopus"
	filling_color = "#7F0000"
	center_of_mass = list("x"=16, "y"=14)
	raw = TRUE
	rotten_icon_state = "octopus_rotten"
	rots = TRUE
	non_vegetarian = TRUE
	satisfaction = -10
	dried_type = /obj/item/weapon/reagent_containers/food/snacks/octopus/dried
	dry_size = 7
	New()
		..()
		icon_state = pick("purple_octopus", "red_octopus")
		reagents.add_reagent("protein", 1)
		reagents.add_reagent("nutriment", 5, list("seafood"=3))
		reagents.add_reagent("food_poisoning", pick(0,1,1,2)) //25% chance not poison, 50% poison, 25% double poison

/obj/item/weapon/reagent_containers/food/snacks/octopus/dried
	icon = 'icons/obj/food/dryed.dmi'
	name = "dried octopus rings"
	desc = "Good snack, where to get a beer?"
	filling_color = "#9b5a1d"
	center_of_mass = list("x"=16, "y"=16)
	rots = FALSE
	raw = FALSE
	dried_type = null
	satisfaction = 9
	biteamount = 6
	New()
		..()
		icon_state = "octopus_rings"
		reagents.del_reagent("food_poisoning")
		decay *= SEAFOOD_DRY_MODIFIER

/obj/item/weapon/reagent_containers/food/snacks/cracked_shellfish
	name = "cracked shellfish"
	desc = "Fresh shellfish, cracked open with a knife."
	icon_state = "cracked_shellfish"
	health = 30
	filling_color = "#7F0000"
	raw = TRUE
	rotten_icon_state = "cracked_shellfish_rotten"
	rots = TRUE
	non_vegetarian = TRUE
	satisfaction = -4
	decay = 5*600
	New()
		..()
		reagents.add_reagent("protein", 1)
		reagents.add_reagent("food_poisoning", 1)
		bitesize = 1

/obj/item/weapon/reagent_containers/food/snacks/animalfat
	name = "animal"
	desc = "Its a fresh and raw animal fat."
	icon_state = "animalfat"
	health = 100
	filling_color = "#FFF783"
	raw = TRUE
	rotten_icon_state = "rottenanimalfat"
	rots = TRUE
	non_vegetarian = TRUE
	disgusting = TRUE
	decay = 5*600
	New()
		..()
		reagents.add_reagent("lard", 10)
		bitesize = 3
	satisfaction = -7 //Its disgusting raw,

/obj/item/shellfish
	name = "shellfish"
	desc = "A fresh, closed shellfish. You need a knife to open it."
	icon_state = "shellfish"
	icon = 'icons/obj/food/food.dmi'

	attackby(obj/item/I, mob/user)
		if (istype(I, /obj/item/weapon/attachment/bayonet) || istype(I, /obj/item/weapon/material/kitchen/utensil/knife) || istype(I, /obj/item/weapon/material/hatchet))
			user << "You crack open \the [src]."
			new /obj/item/weapon/reagent_containers/food/snacks/cracked_shellfish(user.loc)
			qdel(src)
			return