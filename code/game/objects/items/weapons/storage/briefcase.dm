/obj/item/weapon/storage/briefcase
	name = "briefcase"
	desc = "It's made of AUTHENTIC faux-leather and has a price-tag still attached. Its owner must be a real professional."
	icon_state = "briefcase"
	item_state = "briefcase"
	flags = CONDUCT
	force = WEAPON_FORCE_NORMAL
	throwforce = WEAPON_FORCE_NORMAL
	throw_speed = TRUE
	throw_range = 4
	w_class = ITEM_SIZE_LARGE
	max_w_class = 3
	max_storage_space = 16

/obj/item/weapon/storage/briefcase/kgb

/obj/item/weapon/storage/briefcase/kgb/New()
	..()
	new /obj/item/weapon/attachment/bayonet(src)
	new /obj/item/clothing/mask/gas/military(src)
	new /obj/item/clothing/mask/gas/military(src)
	new /obj/item/clothing/glasses/thermal(src)
	new /obj/item/weapon/grenade/chemical/white_phosphorus(src)
	new /obj/item/weapon/grenade/antitank/rpg40(src)
	new /obj/item/ammo_magazine/makarov(src)
	new /obj/item/stack/medical/advanced/bruise_pack(src)