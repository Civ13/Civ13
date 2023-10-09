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
	item_state = "firstaid"
	throw_speed = 2
	throw_range = 8
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand.dmi',
		)
	var/empty = FALSE
	slot_flags = SLOT_BELT

/obj/item/weapon/storage/firstaid/adv
	name = "field dressing kit"
	desc = "Contains basic medical treatments."
	icon_state = "medical_bag"
	item_state = "medical_bag"
	slot_flags = SLOT_BACK

/obj/item/weapon/storage/firstaid/adv/New()
	..()
	if (empty) return
	new  /obj/item/weapon/doctor_handbook(src)
	new /obj/item/stack/medical/advanced/bruise_pack(src)
	new /obj/item/stack/medical/advanced/ointment(src)
	new /obj/item/stack/medical/bruise_pack/bint/medic(src)
	new /obj/item/stack/medical/splint(src)
	return

/obj/item/weapon/storage/firstaid/combat
	name = "combat medicine kit"
	desc = "Contains drugs and antiseptics used in combat situations."
	icon_state = "medical_satchel"
	item_state = "medical_satchel"
	slot_flags = SLOT_BACK | SLOT_BELT


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

/obj/item/weapon/storage/firstaid/early
	name = "medicine kit"
	desc = "Contains some drugs and a antiseptic to help someone survive."
	icon_state = "bezerk2"
	item_state = "bezerk2"
	slot_flags = SLOT_BACK | SLOT_BELT | SLOT_POCKET


/obj/item/weapon/storage/firstaid/early/New()
	..()
	if (empty) return
	new /obj/item/weapon/reagent_containers/syringe(src)
	new /obj/item/weapon/reagent_containers/glass/bottle/opium(src)
	new /obj/item/weapon/reagent_containers/glass/bottle/adrenaline(src)
	new /obj/item/weapon/reagent_containers/glass/bottle/antitoxin(src)
	new /obj/item/stack/medical/advanced/sulfa(src)
	return

/obj/item/weapon/storage/firstaid/advsmall
	name = "first-aid kit"
	desc = "Contains basic first-aid medicine."
	icon_state = "advfirstaid2"
	item_state = "advfirstaid2"

/obj/item/weapon/storage/firstaid/advsmall/New()
	..()
	if (empty) return
	new /obj/item/stack/medical/advanced/bruise_pack(src)
	new /obj/item/stack/medical/advanced/ointment(src)
	new /obj/item/stack/medical/splint(src)
	new /obj/item/weapon/pill_pack/tramadol(src)
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
	new /obj/item/weapon/storage/pill_bottle/antitox(src)
	new /obj/item/weapon/storage/pill_bottle/penicillin(src)
	new /obj/item/weapon/reagent_containers/syringe/morphine(src)
	new /obj/item/weapon/reagent_containers/syringe/morphine(src)
	return


/obj/item/weapon/storage/firstaid/surgery
	name = "surgery kit"
	desc = "Contains tools for surgery."
	icon_state = "surgerykit"
	item_state = "surgerykit"

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
	icon_state = "surgerykit"
	item_state = "surgerykit"
	storage_slots = 7
	max_w_class = 3
	max_storage_space = 28

	make_exact_fit()

/obj/item/weapon/storage/firstaid/surgery_bronze //TO DO: have some other more ancient looking sprite
	name = "surgery kit"
	desc = "Contains tools for surgery."
	icon_state = "surgerykit"
	item_state = "surgerykit"

/obj/item/weapon/storage/firstaid/surgery_bronze/New()
	..()
	if (empty) return
	new /obj/item/weapon/surgery/bonesetter/bronze(src)
	new /obj/item/weapon/surgery/cautery/bronze(src)
	new /obj/item/weapon/surgery/bone_saw/bronze(src)
	new /obj/item/weapon/surgery/hemostat/bronze(src)
	new /obj/item/weapon/surgery/retractor/bronze(src)
	new /obj/item/weapon/surgery/scalpel/bronze(src)
	new /obj/item/stack/medical/advanced/bruise_pack(src)


/// Temp refactor of in-belt medkits

/obj/item/weapon/storage/firstaid/ifak
	name = "individual first-aid kit"
	desc = "Contains basic first-aid."
	icon_state = "ifirstaid"
	item_state = "ifirstaid"
	w_class = ITEM_SIZE_SMALL
	slot_flags = SLOT_BACK | SLOT_BELT | SLOT_POCKET
	can_hold = list(
		/obj/item/stack/medical,
		/obj/item/weapon/pill_pack,
		/obj/item/weapon/reagent_containers/syringe
		)
/obj/item/weapon/storage/firstaid/ifak/New()
	..()
	new /obj/item/stack/medical/bruise_pack/gauze(src)
	new /obj/item/stack/medical/splint/small(src)
	new /obj/item/weapon/pill_pack/paracetamol(src)
	new /obj/item/weapon/reagent_containers/syringe/morphine(src)
	return

/obj/item/weapon/storage/box/firstaid //TO-DO: Redo this "box" subtype, it's kind of shitcode
	name = "medical kit"
	desc = "Contains medical supplies."
	icon_state = "medkit"
	item_state = "medkit"
	can_hold = list(
		/obj/item/stack/medical,
		/obj/item/weapon/pill_pack,
		/obj/item/weapon/storage/pill_bottle,
		/obj/item/weapon/reagent_containers/syringe
		)
/obj/item/weapon/storage/box/firstaid/New()
	..()
	new /obj/item/stack/medical/advanced/bruise_pack(src)
	new /obj/item/stack/medical/advanced/ointment(src)
	new /obj/item/stack/medical/splint(src)
	new /obj/item/weapon/storage/pill_bottle/tramadol(src)
	new /obj/item/weapon/reagent_containers/syringe/morphine(src)
	new /obj/item/weapon/reagent_containers/syringe/morphine(src)
	return