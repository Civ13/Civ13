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
	desc = "Repair your gear!"
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
	var/itemtype5 = null
	var/itemtype6 = null
	var/itemtype7 = null
	var/itemtype8 = null
	var/itemtype9 = null
	var/itemtype10 = null
	var/itemtype11 = null
	var/actiontext = "repair" //Plural, flavortext
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/repair/gun
	name = "firearm maintenance bench"
	desc = "A bench with several tools for cleaning and repairing firearms."
	repairamount = 25
	damageamount = 1
	itemtype1 = /obj/item/weapon/gun
	itemtype2 = null
	itemtype3 = null
	itemtype4 = null
	actiontext = "restore"
	delay = 180
	noise = 'sound/effects/woodfile.ogg'

/obj/structure/repair/attackby(obj/item/M as obj, mob/user as mob)
	if(istype(M, itemtype1) || istype(M, itemtype2) || istype(M, itemtype3) || istype(M, itemtype4) || istype(M, itemtype5) || istype(M, itemtype6) || istype(M, itemtype7) || istype(M, itemtype8) || istype(M, itemtype9) || istype(M, itemtype10) || istype(M, itemtype11) || (istype(src, /obj/structure/repair/grindstone) && istype(M, /obj/item/weapon/material/part/axehead/hatchet)))
		if (!user || !user.may_do_after)
			return
		if (!repair_ready(M, user))
			return
		visible_message("<span class='notice'>[user] starts to [actiontext] the [M.name]...</span>")
		icon_state = activesprite
		playsound(src,noise,40,1)
		if (do_after(user, delay, src))
			icon_state = idlesprite
			if (QDELETED(M) || !repair_ready(M, user))
				return
			var/previous_health = M.health
			if (M.repair_wear(repairamount, damageamount) && M.health > previous_health && istype(src, /obj/structure/repair/grindstone))
				note_craftsman_head_work(user, M, "sharpen-head", 0.5)
			visible_message("<span class='notice'>[user] finishes [actiontext]ing the [M.name].</span>")
		else
			visible_message("<span class='notice'>[user] stops [actiontext]ing the [M.name].</span>")
			icon_state = idlesprite
	else if (is_tool(M, TOOL_HAMMER) || is_tool(M, TOOL_WRENCH))
		..()
		return
	else
		to_chat(user, "<span class='notice'>You cannot [actiontext] this with a [src.name]!</span>")
		return

// Repair maintains an item and never breaks it: refuse one that needs no work
// or is worn down too far to take another repair.
/obj/structure/repair/proc/repair_ready(obj/item/M, mob/user)
	return item_ready_for_repair(M, user, damageamount, actiontext)

/proc/item_ready_for_repair(obj/item/M, mob/user, strain, actiontext)
	var/obj/item/weapon/material/hatchet/H = M
	var/full_condition = M.health >= M.maxhealth
	if (istype(H) && H.component_wear && H.material)
		H.init_hatchet_wear()
		full_condition = H.hatchet_head_hp >= H.hatchet_head_max
	if (full_condition)
		to_chat(user, "<span class='notice'>\The [M] is in good condition and needs no work.</span>")
		return FALSE
	if (M.too_worn_to_repair(strain))
		to_chat(user, "<span class='warning'>\The [M] is worn down too far to [actiontext] again. Use it until it gives out, then make a new one.</span>")
		return FALSE
	return TRUE

/obj/structure/repair/grindstone
	name = "grindstone"
	desc = "For sharpening blades and refining metalwork."
	icon_state = "grindstone"
	idlesprite = "grindstone"
	activesprite = "grindstone_on"
	itemtype1 = /obj/item/weapon/material/sword
	itemtype2 = /obj/item/weapon/material/spear
	itemtype3 = /obj/item/weapon/material/kitchen/utensil/knife
	itemtype4 = /obj/item/weapon/material/hatchet
	itemtype5 = /obj/item/weapon/material/boarding_axe
	itemtype6 = /obj/item/weapon/material/machete
	itemtype7 = /obj/item/weapon/material/machete1
	itemtype8 = /obj/item/weapon/material/twohanded
	itemtype9 = /obj/item/weapon/material/thrown
	itemtype10 = /obj/item/weapon/material/shovel
	itemtype11 = /obj/item/weapon/material/pickaxe
	repairamount = 8 //0 is full repair, any other number adds until it hits max.
	damageamount = 2 //How much max durability to take away.
	delay = 100
	actiontext = "sharpen"

/obj/structure/repair/workbench
	name = "armor repair workbench"
	desc = "A sturdy workbench specifically designed for repairing various pieces of armor."
	icon_state = "workbench"
	idlesprite = "workbench"
	activesprite = "workbench"
	itemtype1 = /obj/item/clothing/suit/armor
	itemtype2 = /obj/item/clothing/head/helmet
	itemtype3 = /obj/item/weapon/shield
	itemtype4 = /obj/item/clothing/shoes/tsuranuki
	itemtype5 = /obj/item/clothing/gloves/gauntlets
	repairamount = 5 //0 is full repair, any other number adds until it hits max.
	damageamount = 1 //How much max durability to take away.
	noise = 'sound/effects/clang.ogg'
	delay = 140

/obj/item/weapon/gun_cleaning_kit
	name = "gun cleaning kit"
	desc = "A kit of tools used to clean firearms."
	icon = 'icons/obj/guns/gun.dmi'
	icon_state = "guncleaningkit_open"
	slot_flags = SLOT_BELT
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_NORMAL
	w_class = ITEM_SIZE_SMALL

/obj/item/weapon/gun/projectile/proc/file_serial(obj/item/M, mob/user)
	if (is_tool(M, TOOL_KNIFE) && (!(istype(src, /obj/item/weapon/gun/projectile/bow))))
		switch(player_alert(user, "Are you sure you want to scratch the serial number? This cannot be reversed and will make the gun illegal!", "Serial number filing", list("Yes", "No")))
			if ("No")
				return
			if ("Yes")
				to_chat(user, "You start scratching the serial number of \the [src]...")
				if (do_after(user,100,src))
					to_chat(user, "You successfully scratch the serial number, making the gun untraceable.")
					serial = ""
					return
