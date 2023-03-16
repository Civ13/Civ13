//Melee, two handed.
/obj/item/weapon/sledgehammer
	name = "generic sledgehammer"
	desc = "A generic sledgehammer, very heavy, but good for crushing things."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "sledgehammer"
	item_state = "sledgehammer"
	edge = FALSE
	sharp = FALSE
	equiptimer = 35
	force = 32

//Needs two hands to use.
/obj/item/weapon/sledgehammer/proc/special_check(mob/user)
		/*if(orc == 1 || gorillaman == 1)
			//Orcs and Apes can use it onehanded.
		else*/
	if (!(user.has_empty_hand(both = FALSE)))
		user << "<span class='warning'>You need both hands to swing the [src]!</span>"
		return FALSE
	..()

/obj/item/weapon/sledgehammer/stone/sledgehammer
	name = "Stone Sledgehammer"
	desc = "A stone sledgehammer, very heavy, but good for crushing things."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "stone_sledgehammer"
	item_state = "stone_sledgehammer"
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_PAINFUL
	w_class = ITEM_SIZE_LARGE
	flammable = FALSE
	equiptimer = 32
	weight = 80
	force = 24
/obj/item/weapon/sledgehammer/lead/sledgehammer
	name = "Lead Sledgehammer"
	desc = "A lead sledgehammer, extremely heavy, nearly impossible to use."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "lead_sledgehammer"
	item_state = "lead_sledgehammer"
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_PAINFUL
	w_class = ITEM_SIZE_LARGE
	flammable = FALSE
	equiptimer = 35
	weight = 80
	force = 32

/obj/item/weapon/sledgehammer/bronze/sledgehammer
	name = "Bronze Sledgehammer"
	desc = "A bronze sledgehammer, pretty heavy, but good for crushing things."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "bronze_sledgehammer"
	item_state = "bronze_sledgehammer"
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_PAINFUL
	w_class = ITEM_SIZE_LARGE
	flammable = FALSE
	equiptimer = 32
	weight = 80
	force = 40

/obj/item/weapon/sledgehammer/iron/sledgehammer
	name = "Iron Sledgehammer"
	desc = "A Iron sledgehammer, very heavy, but good for crushing things."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "iron_sledgehammer"
	item_state = "Iron_sledgehammer"
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_PAINFUL
	w_class = ITEM_SIZE_LARGE
	flammable = FALSE
	equiptimer = 32
	weight = 80
	force = 52

/obj/item/weapon/sledgehammer/steel/sledgehammer
	name = "Steel Sledgehammer"
	desc = "A Steel sledgehammer, extremely heavy, but good for crushing things."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "steel_sledgehammer"
	item_state = "steel_sledgehammer"
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_PAINFUL
	w_class = ITEM_SIZE_LARGE
	flammable = FALSE
	equiptimer = 35
	weight = 80
	force = 66
	slowdown = 5

/obj/item/weapon/sledgehammer/uranium/sledgehammer
	name = "Uranium Sledgehammer"
	desc = "A Uranium sledgehammer, kinda heavy, but good for crushing things."
	icon = 'icons/obj/weapons.dmi'
	icon_state = "uranium_sledgehammer"
	item_state = "uranium_sledgehammer"
	slot_flags = SLOT_BACK
	force = WEAPON_FORCE_PAINFUL
	w_class = ITEM_SIZE_LARGE
	flammable = FALSE
	equiptimer = 30
	weight = 80
	force = 60

/obj/item/weapon/sledgehammer/uranium/attack()
	explosion(src.loc, 2, 2, 2, 2)
	radiation_pulse(src.loc, 4, 15, 300, TRUE)
	qdel(src)