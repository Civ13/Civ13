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
	var/skill1 = "strength" //Skill related to thing you are repairing.
	var/skill2 = "crafting"
	var/skill3 = "dexterity"
	not_movable = TRUE
	not_disassemblable = FALSE

/obj/structure/repair/gun
	name = "Firearm Maintenance Bench"
	desc = "A bench with several tools for cleaning and repairing firearms." //Noise to do when doing the action.
	repairamount = 25
	damageamount = 1
	itemtype1 = null
	itemtype2 = null
	itemtype3 = null
	itemtype4 = null
	actiontext = "clean/repair"
	delay = 180
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
	else
		user << ("<span class='notice'>You cannot repair this with a [src.name]!</span>")
/obj/structure/repair/grindstone
	name = "Grindstone"
	desc = "for sharpening blades."
	icon_state = "grindstone"
	idlesprite = "grindstone"
	activesprite = "grindstone_on"
	itemtype1 = /obj/item/weapon/material/sword
	itemtype2 = /obj/item/weapon/melee
	itemtype3 = /obj/item/weapon/material/kitchen/utensil/knife
	itemtype4 = /obj/item/weapon/material/hatchet
	repairamount = 8 //0 is full repair, any other number adds until it hits max.
	damageamount = 2 //How much max durability to take away.
	delay = 100

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
	delay = 140
