/* First aid storage
 * Contains:
 *		First Aid Kits
 * 		Pill Bottles
 */

/*
 * First Aid Kits
 */
/obj/item/weapon/storage/firstaid
	name = "first-aid kit"
	desc = "It's an emergency medical kit for general wounds."
	icon_state = "firstaid2"
	item_state = "firstaid_2"
	throw_speed = 2
	throw_range = 8
	var/empty = FALSE


/obj/item/weapon/storage/firstaid/fire
	name = "fire first-aid kit"
	desc = "It's an emergency medical kit for burns."
	icon_state = "firefirstaid2"
	item_state = "firstaid_2"

	New()
		..()
		if (empty) return

		new /obj/item/stack/medical/ointment( src )
		new /obj/item/stack/medical/ointment( src )
		new /obj/item/weapon/reagent_containers/pill/kelotane( src )
		new /obj/item/weapon/reagent_containers/pill/kelotane( src )
		new /obj/item/weapon/reagent_containers/pill/kelotane( src ) //Replaced ointment with these since they actually work --Errorage
		return


/obj/item/weapon/storage/firstaid/regular
	icon_state = "firstaid2"

	New()
		..()
		if (empty) return
		new /obj/item/stack/medical/bruise_pack(src)
		new /obj/item/stack/medical/bruise_pack(src)
		new /obj/item/stack/medical/bruise_pack(src)
		new /obj/item/stack/medical/ointment(src)
		new /obj/item/stack/medical/ointment(src)
		return


/obj/item/weapon/storage/firstaid/o2
	name = "oxygen deprivation first aid"
	desc = "A box full of tools and chemicals for treating oxygen deprivation."
	icon_state = "o22"
	item_state = "firstaid_2"

	New()
		..()
		if (empty) return
		new /obj/item/weapon/reagent_containers/pill/dexalin( src )
		new /obj/item/weapon/reagent_containers/pill/dexalin( src )
		new /obj/item/weapon/reagent_containers/pill/dexalin( src )
		new /obj/item/weapon/reagent_containers/pill/dexalin( src )
		return

/obj/item/weapon/storage/firstaid/adv
	name = "advanced first-aid kit"
	desc = "Contains advanced medical treatments."
	icon_state = "advfirstaid2"
	item_state = "firstaid_2"

/obj/item/weapon/storage/firstaid/adv/New()
	..()
	if (empty) return
	new /obj/item/stack/medical/advanced/bruise_pack(src)
	new /obj/item/stack/medical/advanced/bruise_pack(src)
	new /obj/item/stack/medical/advanced/bruise_pack(src)
	new /obj/item/stack/medical/advanced/ointment(src)
	new /obj/item/stack/medical/advanced/ointment(src)
	new /obj/item/stack/medical/splint(src)
	return

/obj/item/weapon/storage/firstaid/combat
	name = "combat medicine kit"
	desc = "Contains advanced medicine used in combat."
	icon_state = "bezerk2"
	item_state = "firstaid_2"

/obj/item/weapon/storage/firstaid/combat/New()
	..()
	if (empty) return
	new /obj/item/weapon/storage/pill_bottle/bicaridine(src)
	new /obj/item/weapon/storage/pill_bottle/dermaline(src)
	new /obj/item/weapon/storage/pill_bottle/dexalin_plus(src)
	new /obj/item/weapon/storage/pill_bottle/dylovene(src)
	new /obj/item/weapon/storage/pill_bottle/tramadol(src)
	new /obj/item/weapon/storage/pill_bottle/penicillin(src)
	new /obj/item/stack/medical/splint(src)
	return

/obj/item/weapon/storage/firstaid/surgery
	name = "surgery kit"
	desc = "Contains tools for surgery."
	icon_state = "firstaid2"
	item_state = "firstaid_2"

/obj/item/weapon/storage/firstaid/surgery/New()
	..()
	if (empty) return
	new /obj/item/weapon/bonesetter(src)
	new /obj/item/weapon/cautery(src)
	new /obj/item/weapon/bone_saw(src)
	new /obj/item/weapon/hemostat(src)
	new /obj/item/weapon/retractor(src)
	new /obj/item/weapon/scalpel(src)
	new /obj/item/weapon/surgicaldrill(src)
	new /obj/item/weapon/bonegel(src)
	new /obj/item/stack/medical/advanced/bruise_pack(src)

	make_exact_fit()
