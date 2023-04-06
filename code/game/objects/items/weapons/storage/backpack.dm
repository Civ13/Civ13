
/* backpack.dm*/

/obj/item/weapon/storage/backpack
	name = "backpack"
	desc = "You wear this on your back and put items into it."
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_backpacks.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_backpacks.dmi',
		)
	icon_state = "backpack"
	base_icon = "backpack"
	item_state = "backpack"
	worn_state = "backpack"
	//most backpacks use the default backpack state for inhand overlays
	item_state_slots = list(
		slot_l_hand_str = "backpack",
		slot_r_hand_str = "backpack",
		)
	w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_BACK
	max_w_class = 4
	max_storage_space = 22 // can hold 2 w_class 4 items. 28 let it hold 3
	flammable = TRUE

/obj/item/weapon/storage/backpack/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (use_sound)
		playsound(loc, use_sound, 50, TRUE, -5)
	..()

/obj/item/weapon/storage/backpack/equipped(var/mob/user, var/slot)
	if (slot == slot_back && use_sound)
		playsound(loc, use_sound, 50, TRUE, -5)
	..(user, slot)

/*
/obj/item/weapon/storage/backpack/dropped(mob/user as mob)
	if (loc == user && use_sound)
		playsound(loc, use_sound, 50, TRUE, -5)
	..(user)
*/

/* Satchels*/

/obj/item/weapon/storage/backpack/satchel
	name = "leather satchel"
	desc = "It's a very fancy satchel made with fine leather."
	icon_state = "satchel"
	base_icon = "satchel"
	worn_state = "satchel"
	max_storage_space = 16

/obj/item/weapon/storage/backpack/satchel/gator_satchel
	name = "alligator scale satchel"
	desc = "A fashionable satchel lined with exotic alligator scales"
	icon_state = "gator_satchel"
	base_icon = "gator_satchel"

/obj/item/weapon/storage/backpack/satchel/black
	name = "black leather satchel"
	desc = "A very fancy satchel made out of black leather."
	icon_state = "satchel_black"
	base_icon = "satchel_black"
	worn_state = "satchel_black"

/obj/item/weapon/storage/backpack/satchel/black/germanat
	name = "German Anti Tank Satchel"
	desc = "It's a standard issue satchel for German military personel"
	max_storage_space = 28
	slowdown = 0.1
	can_hold = list(
		/obj/item/ammo_magazine,
		/obj/item/weapon/material,
		/obj/item/weapon/grenade,
		/obj/item/weapon/attachment,
		/obj/item/ammo_casing,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,
		/obj/item/weapon/material/shovel,
		/obj/item/weapon/key,
		/obj/item/ammo_casing/rocket,
		)

/obj/item/weapon/storage/backpack/satchel/black/germanat/pzb
	max_storage_space = 12
	New()
		..()
		new /obj/item/ammo_magazine/pzb_case_ap(src)
		new /obj/item/ammo_magazine/pzb_case(src)
		new /obj/item/ammo_magazine/pzb_case(src)
		new /obj/item/ammo_magazine/pzb_case(src)

/obj/item/weapon/storage/backpack/satchel/black/germanat/rpb54
	New()
		..()
		new /obj/item/ammo_casing/rocket/rpb54(src)
		new /obj/item/ammo_casing/rocket/rpb54(src)
		new /obj/item/ammo_casing/rocket/rpb54(src)
		new /obj/item/ammo_casing/rocket/rpb54(src)
		new /obj/item/ammo_casing/rocket/rpb54(src)

/obj/item/weapon/storage/backpack/satchel/replicant
	name = "synthetic backpack"
	desc = "A very versitile backpack made out of synthetic leather."
	icon_state = "replicant_backpack"
	base_icon = "replicant_backpack"
	worn_state = "replicant_backpack"

/obj/item/weapon/storage/backpack/satchel/police
	name = "police tactical pouch"
	desc = "A tactical pouch made for law enforcement agents."
	icon_state = "policesatchel"
	base_icon = "policesatchel"
	worn_state = "policesatchel"
	max_storage_space = 12

/* Backpacks */

/obj/item/weapon/storage/backpack/ww2/jap
	name = "japanese backpack"
	desc = "It's a standard issue backpack for japanese military personel"
	icon_state = "jappack"
	item_state = "jappack"
	worn_state = "jappack"
	base_icon = "jappack"
	max_storage_space = 24
/obj/item/weapon/storage/backpack/ww2/jap/full
	New()
		..()
		new /obj/item/weapon/bedroll(src)
		new /obj/item/weapon/reagent_containers/glass/small_pot/hangou(src)
		new /obj/item/weapon/material/shovel/trench(src)
		new /obj/item/clothing/suit/storage/coat/ww2/japcoat(src)
		new /obj/item/clothing/head/helmet/ww2/japhelm(src)
		new /obj/item/weapon/grenade/ww2/type97(src)
		new /obj/item/weapon/grenade/ww2/type97(src)

/obj/item/weapon/storage/backpack/ww2/jap/ammo_crate
	name = "japanese ammo crate"
	desc = "It's a crate equipped with straps for carrying, often used by assistant gunners."
	icon_state = "ammo_crate"
	item_state = "ammo_crate"
	worn_state = "ammo_crate"
	base_icon = "ammo_crate"
	max_storage_space = 24
	can_hold = list(
		/obj/item/ammo_magazine,
		/obj/item/weapon/material,
		/obj/item/weapon/grenade,
		/obj/item/weapon/attachment,
		/obj/item/ammo_casing,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,
		/obj/item/weapon/material/shovel,
		/obj/item/weapon/key,
		)

/obj/item/weapon/storage/backpack/ww2/jap/ammo_crate/full
	New()
		..()
		new /obj/item/ammo_magazine/type99(src)
		new /obj/item/ammo_magazine/type99(src)
		new /obj/item/ammo_magazine/type99(src)
		new /obj/item/ammo_magazine/type99(src)
		new /obj/item/ammo_magazine/type99(src)
		new /obj/item/ammo_magazine/type99(src)
		new /obj/item/ammo_magazine/type99(src)
		new /obj/item/ammo_magazine/type99(src)
		new /obj/item/ammo_magazine/type99(src)
		new /obj/item/ammo_magazine/type99(src)

/obj/item/weapon/storage/backpack/ww2/german
	name = "backpack"
	desc = "A standard issue backpack for German military personel"
	icon_state = "germanpack"
	item_state = "germanpack"
	worn_state = "germanpack"
	base_icon = "germanpack"
	max_storage_space = 24
	can_hold = list(
		/obj/item/ammo_magazine,
		/obj/item/weapon/material,
		/obj/item/weapon/grenade,
		/obj/item/weapon/attachment,
		/obj/item/ammo_casing,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,
		/obj/item/weapon/material/shovel,
		/obj/item/weapon/key,
		)
/obj/item/weapon/storage/backpack/ww2/russian
	name = "backpack"
	desc = "A standard issue backpack for Soviet military personel."
	icon_state = "germanpack" //To be replaced with proper, high quality sprites
	item_state = "germanpack" //To be replaced with proper, high quality sprites
	worn_state = "germanpack" //To be replaced with proper, high quality sprites
	base_icon = "germanpack" //To be replaced with proper, high quality sprites
	max_storage_space = 24
	can_hold = list(
		/obj/item/ammo_magazine,
		/obj/item/weapon/material,
		/obj/item/weapon/grenade,
		/obj/item/weapon/attachment,
		/obj/item/ammo_casing,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen,
		/obj/item/weapon/material/shovel,
		/obj/item/weapon/key,
		)

/obj/item/weapon/storage/backpack/ww2/russian/at
	New()
		..()
		new /obj/item/weapon/grenade/ww2/rgd33(src)
		new /obj/item/weapon/grenade/ww2/rgd33(src)
		new /obj/item/weapon/grenade/antitank/rpg40(src)
		new /obj/item/weapon/grenade/antitank/rpg40(src)
		new /obj/item/weapon/grenade/smokebomb/rdg2(src)
		new /obj/item/weapon/grenade/smokebomb/rdg2(src)
		new /obj/item/weapon/plastique/russian(src)
		new /obj/item/weapon/plastique/russian(src)

/obj/item/weapon/storage/backpack/ww2/sapper
	name = "sapper backpack"
	New()
		..()
		new /obj/item/stack/material/iron/twentyfive(src)
		new /obj/item/stack/material/steel/twentyfive(src)
		new /obj/item/stack/material/wood/twentyfive(src)
		new /obj/item/weapon/material/shovel/spade/small(src)
		new /obj/item/weapon/plastique/russian(src)

/obj/item/weapon/storage/backpack/ww2/sapper/german
	New()
		..()
		new /obj/item/weapon/grenade/ww2/stg1924(src)
		new /obj/item/weapon/grenade/ww2/stg1924(src)
		new /obj/item/weapon/grenade/smokebomb(src)
		new /obj/item/weapon/grenade/smokebomb(src)
		new /obj/item/weapon/grenade/antitank/stg24_bundle(src)

/obj/item/weapon/storage/backpack/ww2/sapper/russian
	New()
		..()
		new /obj/item/weapon/grenade/antitank/rpg40
		new /obj/item/weapon/grenade/ww2/rgd33(src)
		new /obj/item/weapon/grenade/ww2/rgd33(src)
		new /obj/item/weapon/grenade/smokebomb/rdg2(src)
		new /obj/item/weapon/grenade/smokebomb/rdg2(src)

/obj/item/weapon/storage/backpack/ww2/american
	name = "american backpack"
	desc = "It's a standard issue backpack for American military personel"
	icon_state = "uspack"
	item_state = "uspack"
	worn_state = "uspack"
	base_icon = "uspack"
	max_storage_space = 24

/obj/item/weapon/storage/backpack/paratrooper
	name = "parachute pack"
	desc = "A backpack with a built-in parachute."
	icon_state = "parachute"
	item_state = "parachute"
	worn_state = "parachute"
	base_icon = "parachute"
	w_class = ITEM_SIZE_HUGE
	max_storage_space = 0

/obj/item/weapon/storage/backpack/scavpack
	name = "scavenger pack"
	desc = "A makeshift backpack made of a mix of materials."
	icon_state = "scavpack"
	item_state = "scavpack"
	max_storage_space = 24

/obj/item/weapon/storage/backpack/rucksack
	name = "rucksack"
	desc = "A big rucksack made for long walks."
	icon_state = "rucksack"
	item_state = "backpack"
	base_icon = "rucksack"
	w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_BACK
	max_w_class = 4
	max_storage_space = 28

/obj/item/weapon/storage/backpack/rucksack/small
	name = "small army rucksack"
	desc = "A small black army rucksack, made to allow you to be mobile while carrying everything you need."
	icon_state = "smallruck"
	item_state = "smallruck"
	base_icon = "smallruck"
	w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_BACK
	max_w_class = 4
	max_storage_space = 14

/obj/item/weapon/storage/backpack/rucksack/small/extracap
	name = "army rucksack"
	desc = "A bit small black army rucksack, made to allow you to be mobile while carrying everything you need."
	max_storage_space = 22

/obj/item/weapon/storage/backpack/rucksack/small/extracap/medicalh
	New()
		..()
		new/obj/item/stack/medical/advanced/bruise_pack(src)
		new/obj/item/stack/medical/advanced/ointment(src)
		new/obj/item/stack/medical/advanced/sulfa(src)
		new/obj/item/stack/medical/splint(src)
		new/obj/item/weapon/storage/pill_bottle/tramadol(src)
		new/obj/item/roller(src)
		new/obj/item/weapon/pill_pack/adrenaline(src)
		new/obj/item/weapon/storage/firstaid/surgery(src)

/obj/item/weapon/storage/backpack/rucksack/small/milpack
	New()
		..()
		new/obj/item/weapon/reagent_containers/food/drinks/bottle/canteen/full(src)
		new/obj/item/weapon/can/filled(src)
		new/obj/item/weapon/reagent_containers/syringe/adrenaline(src)
		new/obj/item/weapon/material/kitchen/utensil/knife/military(src)
		new/obj/item/weapon/reagent_containers/pill/paracetamol(src)

/obj/item/weapon/storage/backpack/rucksack/small/medical
	New()
		..()
		new/obj/item/stack/medical/advanced/bruise_pack(src)
		new/obj/item/stack/medical/advanced/ointment(src)
		new/obj/item/stack/medical/advanced/sulfa(src)
		new/obj/item/stack/medical/splint(src)
		new/obj/item/weapon/storage/pill_bottle/tramadol(src)
		new/obj/item/weapon/pill_pack/adrenaline(src)

/obj/item/weapon/storage/backpack/rucksack/small/command
	New()
		..()
		new/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(src)
		new/obj/item/weapon/storage/box/flare(src)
		new/obj/item/weapon/grenade/coldwar/rgd5(src)
		new/obj/item/weapon/compass(src)
		new/obj/item/weapon/grenade/smokebomb(src)
		new/obj/item/weapon/storage/box/sandbags(src)
		new/obj/item/weapon/material/kitchen/utensil/knife/military(src)

/obj/item/weapon/storage/backpack/rucksack/small/commandami
	New()
		..()
		new/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars(src)
		new/obj/item/weapon/storage/box/flare(src)
		new/obj/item/weapon/grenade/coldwar/m67(src)
		new/obj/item/weapon/compass(src)
		new/obj/item/weapon/grenade/smokebomb(src)
		new/obj/item/weapon/storage/box/sandbags(src)
		new/obj/item/weapon/material/kitchen/utensil/knife/military(src)

/obj/item/weapon/storage/backpack/rucksack/rpg
	New()
		..()
		new/obj/item/ammo_casing/rocket/og7v(src)
		new/obj/item/ammo_casing/rocket/og7v(src)
		new/obj/item/ammo_casing/rocket/pg7v(src)
		new/obj/item/ammo_casing/rocket/pg7v(src)
		new/obj/item/ammo_casing/rocket/pg7v(src)
		new/obj/item/ammo_casing/rocket/pg7v(src)

/obj/item/weapon/storage/backpack/rpg_pack
	name = "RPG-7 rocket backpack"
	desc = "An ammunition carrier made out of canvas. This one is able to carry up to 3 rockets."
	icon_state = "backpack_rpg_tan"
	item_state = "backpack_rpg_tan"
	base_icon = "backpack_rpg_tan"
	w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_BACK
	can_hold = list(
		/obj/item/ammo_casing/rocket/og7v,
		/obj/item/ammo_casing/rocket/pg7v,
		/obj/item/ammo_casing/rocket/atgm)
	max_w_class = 4
	max_storage_space = 24

/obj/item/weapon/storage/backpack/rpg_pack/olive
	icon_state = "backpack_rpg_olive"
	item_state = "backpack_rpg_olive"
	base_icon = "backpack_rpg_olive"

/obj/item/weapon/storage/backpack/rpg_pack/filled
	New()
		..()
		new/obj/item/ammo_casing/rocket/og7v(src)
		new/obj/item/ammo_casing/rocket/og7v(src)
		new/obj/item/ammo_casing/rocket/pg7v(src)

/obj/item/weapon/storage/backpack/rpg_pack/filled/at
	New()
		..()
		new/obj/item/ammo_casing/rocket/pg7v(src)
		new/obj/item/ammo_casing/rocket/pg7v(src)
		new/obj/item/ammo_casing/rocket/pg7v(src)

/obj/item/weapon/storage/backpack/rpg_pack/olive/filled
	New()
		..()
		new/obj/item/ammo_casing/rocket/og7v(src)
		new/obj/item/ammo_casing/rocket/og7v(src)
		new/obj/item/ammo_casing/rocket/pg7v(src)

/obj/item/weapon/storage/backpack/rpg_pack/olive/filled/at
	New()
		..()
		new/obj/item/ammo_casing/rocket/pg7v(src)
		new/obj/item/ammo_casing/rocket/pg7v(src)
		new/obj/item/ammo_casing/rocket/pg7v(src)

/obj/item/weapon/storage/backpack/heavyrucksack
	name = "heavy rucksack"
	desc = "A big heavyduty rucksack made for big, heavy objects."
	icon_state = "heavyrucksack"
	item_state = "backpack"
	base_icon = "heavyrucksack"
	w_class = ITEM_SIZE_HUGE
	slot_flags = SLOT_BACK
	max_w_class = 5
	max_storage_space = 28

/obj/item/weapon/storage/backpack/heavyrucksack/atgm
	New()
		..()
		new/obj/item/ammo_casing/rocket/atgm(src)
		new/obj/item/ammo_casing/rocket/atgm(src)
		new/obj/item/ammo_casing/rocket/atgm/apcr(src)
		new/obj/item/ammo_casing/rocket/atgm/apcr(src)
		new/obj/item/ammo_casing/rocket/atgm/he(src)
		new/obj/item/ammo_casing/rocket/atgm/he(src)

/obj/item/weapon/storage/backpack/civbag
	name = "backpack"
	desc = "A big backpack made for long walks."
	icon_state = "civback"
	item_state = "backpack"
	base_icon = "civback"
	w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_BACK
	max_w_class = 5
	max_storage_space = 28

/obj/item/weapon/storage/backpack/duffel
	name = "duffel bag"
	desc = "A generic duffel bag."
	icon_state = "duffel"
	item_state = "duffel"
	base_icon = "duffel"
	w_class = ITEM_SIZE_LARGE
	slot_flags = SLOT_BACK
	max_w_class = 3
	max_storage_space = 22

/obj/item/weapon/storage/backpack/duffel/black
	name = "black duffel bag"
	desc = "A generic black duffel bag."
	icon_state = "bduffel"
	item_state = "bduffel"
	base_icon = "bduffel"

/obj/item/weapon/storage/backpack/buttpack
	name = "US Army buttpack"
	desc = "Standard issue buttpack for american military personel."
	icon_state = "us_buttpack"
	item_state = "us_buttpack"
	item_state_slots = list(
		slot_l_hand_str = "us_buttpack",
		slot_r_hand_str = "us_buttpack",
		)
	worn_state = "us_buttpack"
	base_icon = "us_buttpack"
	slot_flags = SLOT_BACK
	max_storage_space = 8

/obj/item/weapon/storage/backpack/sovpack
	name = "Sidor rucksack"
	desc = "Soviet standard issue rucksack."
	icon_state = "sovpack"
	item_state = "sovpack"
	item_state_slots = list(
		slot_l_hand_str = "sovpack",
		slot_r_hand_str = "sovpack",
		)
	worn_state = "sovpack"
	base_icon = "sovpack"
	slot_flags = SLOT_BACK
	max_storage_space = 12

/obj/item/weapon/storage/backpack/duffel/shaman
	name = "shaman's duffel bag"
	desc = "A duffel bag full of \"medical supplies\"."
	New()
		..()
		new /obj/item/stack/medical/bruise_pack/bint/leather(src)
		new /obj/item/stack/medical/advanced/herbs(src)
		new /obj/item/stack/medical/splint(src)
		new /obj/item/weapon/material/kitchen/utensil/knife/bone(src)
		new /obj/item/stack/material/rope(src)
		new /obj/item/flashlight/torch(src)
		new /obj/item/clothing/mask/smokable/cigarette/joint(src)
		new /obj/item/clothing/mask/smokable/cigarette/joint(src)
		new /obj/item/clothing/mask/smokable/cigarette/joint(src)
		new /obj/item/weapon/reagent_containers/pill/cocaine(src)
		new /obj/item/weapon/reagent_containers/pill/cocaine(src)
		new /obj/item/weapon/reagent_containers/pill/cocaine(src)
		new /obj/item/weapon/reagent_containers/pill/opium(src)
		new /obj/item/weapon/reagent_containers/pill/opium(src)
		new /obj/item/weapon/reagent_containers/food/snacks/grown/peyote(src)
		new /obj/item/weapon/pill_pack/pervitin(src)


/obj/item/weapon/storage/backpack/duffel/ungineer
	name = "United Nations Enigneer's duffel"
	desc = "A duffel bag full of engineering supplies."
	New()
		..()
		new /obj/item/weapon/storage/box/sandbags(src)
		new /obj/item/weapon/storage/box/sandbags(src)
		new /obj/item/stack/material/barbwire/twnt(src)
		new /obj/item/stack/material/wood/twentyfive(src)
		new /obj/item/weapon/material/shovel/spade/small(src)
		new /obj/item/weapon/grenade/smokebomb(src)
		new /obj/item/weapon/grenade/smokebomb(src)

/obj/item/weapon/storage/backpack/duffel/unsniper
	name = "United Nations Marksman's duffel"
	desc = "A duffel bag full of marksman supplies."
	New()
		..()
		new /obj/item/weapon/gun_cleaning_kit(src)
		new /obj/item/ammo_magazine/m14box(src)
		new /obj/item/ammo_magazine/m14box(src)
		new /obj/item/weapon/material/shovel/trench(src)
		new /obj/item/ammo_magazine/m14(src)
		new /obj/item/ammo_magazine/m14(src)
		new /obj/item/ammo_magazine/m1911(src)
		new /obj/item/weapon/grenade/smokebomb/m18smoke(src)

/obj/item/weapon/storage/backpack/duffel/unmg
	name = "United Nations Gunner's duffel"
	desc = "A duffel bag full of gunner's supplies."
	New()
		..()
		new /obj/item/weapon/gun_cleaning_kit(src)
		new /obj/item/ammo_magazine/madsen/box(src)
		new /obj/item/ammo_magazine/madsen/box(src)
		new /obj/item/weapon/material/shovel/trench(src)
		new /obj/item/ammo_magazine/madsen(src)
		new /obj/item/ammo_magazine/madsen(src)
		new /obj/item/ammo_magazine/m1911(src)
		new /obj/item/ammo_magazine/m1911(src)
		new /obj/item/weapon/grenade/coldwar/m67(src)

/obj/item/weapon/storage/backpack/duffel/unbasic
	name = "United Nations Peacekeeper duffel"
	desc = "A duffel bag full of basic supplies."
	New()
		..()
		new /obj/item/weapon/gun_cleaning_kit(src)
		new /obj/item/ammo_magazine/m14box(src)
		new /obj/item/ammo_magazine/m14box(src)
		new /obj/item/weapon/material/shovel/trench(src)
		new /obj/item/ammo_magazine/fal(src)
		new /obj/item/ammo_magazine/fal(src)
		new /obj/item/ammo_magazine/m1911(src)
		new /obj/item/weapon/grenade/coldwar/m67(src)

/obj/item/weapon/storage/backpack/duffel/unsgt
	name = "United Nations Sergeant's duffel"
	desc = "A duffel bag full of Sergeant's supplies."
	New()
		..()
		new /obj/item/weapon/storage/box/firstaid/advsmall(src)
		new /obj/item/ammo_magazine/greasegun/box(src)
		new /obj/item/ammo_magazine/greasegun/box(src)
		new /obj/item/weapon/material/shovel/trench(src)
		new /obj/item/ammo_magazine/greasegun(src)
		new /obj/item/ammo_magazine/greasegun(src)
		new /obj/item/ammo_magazine/m1911(src)
		new /obj/item/weapon/grenade/coldwar/m67(src)
		new /obj/item/weapon/grenade/incendiary/anm14(src)

/obj/item/weapon/storage/backpack/duffel/un
	name = "United Nations Assault backpack"
	desc = "A duffel bag full of basic supplies."

/obj/item/weapon/storage/backpack/duffel/un/mk
	New()
		..()
		new /obj/item/weapon/gun_cleaning_kit(src)
		new /obj/item/ammo_magazine/mk18(src)
		new /obj/item/ammo_magazine/mk18(src)
		new /obj/item/weapon/material/shovel/trench(src)
		new /obj/item/ammo_magazine/mk18(src)
		new /obj/item/ammo_magazine/mk18(src)
		new /obj/item/ammo_magazine/m1911(src)
		new /obj/item/weapon/grenade/coldwar/m67(src)

/obj/item/weapon/storage/backpack/duffel/un/p90
	New()
		..()
		new /obj/item/ammo_magazine/p90(src)
		new /obj/item/ammo_magazine/p90(src)
		new /obj/item/ammo_magazine/p90(src)
		new /obj/item/weapon/material/shovel/trench(src)
		new /obj/item/ammo_magazine/p90(src)
		new /obj/item/ammo_magazine/p90(src)
		new /obj/item/ammo_magazine/p90(src)
		new /obj/item/weapon/grenade/coldwar/nonfrag/m26(src)