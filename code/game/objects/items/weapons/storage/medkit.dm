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
	slot_flags = SLOT_BELT

/obj/item/weapon/storage/firstaid/adv
	name = "first-aid kit"
	desc = "Contains basic medical treatments."
	icon_state = "medical_bag"
	item_state = "medical_bag"
	slot_flags = SLOT_BACK

/obj/item/weapon/storage/firstaid/adv/New()
	..()
	if (empty) return
	new  /obj/item/weapon/doctor_handbook(src)
	new /obj/item/stack/medical/advanced/bruise_pack(src)
	new /obj/item/stack/medical/advanced/bruise_pack(src)
	new /obj/item/stack/medical/advanced/ointment(src)
	new /obj/item/stack/medical/splint(src)
	return

/obj/item/weapon/storage/firstaid/combat
	name = "combat medicine kit"
	desc = "Contains drugs and antiseptics used in combat situations."
	icon_state = "medical_satchel"
	item_state = "medical_satchel"

/obj/item/weapon/storage/firstaid/combat/New()
	..()
	if (empty) return
	new /obj/item/weapon/reagent_containers/syringe/adrenaline(src)
	new /obj/item/weapon/reagent_containers/syringe/adrenaline(src)
	new /obj/item/weapon/storage/pill_bottle/tramadol(src)
	new /obj/item/weapon/reagent_containers/syringe/sulfanomides(src)
	new /obj/item/stack/medical/advanced/sulfa(src)
	new /obj/item/weapon/reagent_containers/syringe/morphine(src)
	new /obj/item/weapon/reagent_containers/syringe/morphine(src)
	return

/obj/item/weapon/storage/firstaid/combat/modern
	name = "combat medicine kit"
	desc = "Contains drugs and antiseptics used in combat situations."
	icon_state = "medical_satchel"
	item_state = "firstaid_2"

/obj/item/weapon/storage/firstaid/combat/modern/New()
	..()
	if (empty) return
	new /obj/item/weapon/reagent_containers/syringe/adrenaline(src)
	new /obj/item/weapon/reagent_containers/syringe/adrenaline(src)
	new /obj/item/weapon/storage/pill_bottle/tramadol(src)
	new /obj/item/weapon/storage/pill_bottle/penicillin(src)
	new /obj/item/weapon/reagent_containers/syringe/morphine(src)
	new /obj/item/weapon/reagent_containers/syringe/morphine(src)
	return


/obj/item/weapon/storage/firstaid/surgery
	name = "surgery kit"
	desc = "Contains tools for surgery."
	icon_state = "firstaid2"
	item_state = "firstaid_2"

/obj/item/weapon/storage/firstaid/surgery/New()
	..()
	if (empty) return
	new /obj/item/weapon/surgery/bonesetter(src)
	new /obj/item/weapon/surgery/cautery(src)
	new /obj/item/weapon/surgery/bone_saw(src)
	new /obj/item/weapon/surgery/hemostat(src)
	new /obj/item/weapon/surgery/retractor(src)
	new /obj/item/weapon/surgery/scalpel(src)
	new /obj/item/stack/medical/advanced/bruise_pack(src)

/obj/item/weapon/storage/firstaid/surgery_empty
	name = "surgery kit"
	desc = "Contains tools for surgery."
	icon_state = "firstaid2"
	item_state = "firstaid_2"
	storage_slots = 7
	max_w_class = 3
	max_storage_space = 28

	make_exact_fit()
