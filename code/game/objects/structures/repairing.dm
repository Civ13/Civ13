//Structure
//Grinding Stone
//Electric Sharpener
//Sowing Machine
//Workbench (Armor)

//Handheld
//Needle + Thread (For Clothing)
//Gun Cleaning Kit
//Sharpening Stone
/obj/structure/repair
	name = "repair bench"
	desc = "Repair your gear!."
	icon = 'icons/obj/structures.dmi'
	icon_state = "gunbench1"
	density = TRUE
	anchored = TRUE
	var/idlesprite = "gunbench1"
	var/activesprite = "gunbench1"
	var/delay = 120 //Time to do the action.
	var/noise = 'sound/machines/grindstone.ogg' //Noise to do when doing the action.
	var/repairamount = 0 //0 is full repair, any other number adds until it hits max.
	var/damageamount = 0 //How much max durability to take away.
	var/itemtype1 = null //What type of item can it repair (EX swords, guns, armor.)
	var/itemtype2 = null
	var/itemtype3 = null
	var/itemtype4 = null
	var/actiontext = "repair" //Plural, flavortext
	not_movable = TRUE
	not_disassemblable = FALSE

/obj/structure/repair/gun
	name = "Gun Matenence Bench"
	desc = "Repair guns! NOT FINISHED."

/obj/structure/repair/attackby(obj/item/M as obj, mob/user as mob)
	if(istype(M, itemtype1) || istype(M, itemtype2) || istype(M, itemtype3) || istype(M, itemtype4))
		visible_message("<span class='notice'>[user] starts to [actiontext] the [M.name]</span>")
		icon_state = activesprite
		playsound(src,noise,40,1)
		if (do_after(user, delay, src))
			M.maxhealth -= damageamount
			if(M.health + repairamount > M.maxhealth)
				M.health = M.maxhealth
				icon_state = idlesprite
			else
				M.health += repairamount
				icon_state = idlesprite
			visible_message("<span class='notice'>[user] finishes [actiontext]ing the [M.name]</span>")
			if(M.maxhealth <= 0 || M.health <= 0)
				qdel(M)
				playsound(src, "shatter", 70, TRUE)
				visible_message("<span class='alert'>The [M.name] breaks from strain!</span>")
		else
			visible_message("<span class='notice'>[user] stops [actiontext]ing the [M.name]</span>")
			icon_state = idlesprite

/obj/structure/repair/grindstone
	name = "Grindstone"
	desc = "for sharpening blades."
	icon_state = "grindstone"
	idlesprite = "grindstone"
	activesprite = "grindstone_on"
	itemtype1 = /obj/item/weapon/material/sword
	itemtype2 = /obj/item/weapon/melee
	repairamount = 8 //0 is full repair, any other number adds until it hits max.
	damageamount = 2 //How much max durability to take away.

/obj/structure/repair/workbench
	name = "workbench"
	desc = "for repairing pieces of armor."
	icon_state = "workbench"
	idlesprite = "workbench"
	activesprite = "workbench"
	itemtype1 = /obj/item/clothing/suit/armor
	itemtype2 = /obj/item/clothing/head/helmet
	itemtype3 = /obj/item/weapon/shield
	repairamount = 5 //0 is full repair, any other number adds until it hits max.
	damageamount = 1 //How much max durability to take away.
	noise = 'sound/effects/clang.ogg'
