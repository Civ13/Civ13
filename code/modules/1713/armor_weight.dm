// Armor weight: ballistic plates slid into a carrier add their own weight on
// top of the carrier's slowdown, so a fully plated vest is slower than an
// empty one.

#define ARMOR_PLATE_SLOWDOWN 0.1

/mob/living/human/proc/armor_plate_slowdown()
	. = 0
	for (var/obj/item/clothing/C in list(w_uniform, wear_suit))
		for (var/obj/item/clothing/accessory/armor/coldwar/plates/P in C.accessories)
			if (!P.hold)
				continue
			for (var/obj/item/weapon/armorplates/plate in P.hold.contents)
				. += ARMOR_PLATE_SLOWDOWN

#undef ARMOR_PLATE_SLOWDOWN
