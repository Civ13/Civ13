/obj/item/weapon/gun/projectile/automatic
	force = 15
	throwforce = 30
	// not accurate at all
	accuracy_list = list(

		// small body parts: head, hand, feet
		"small" = list(
			SHORT_RANGE_STILL = 30,
			SHORT_RANGE_MOVING = 27,

			MEDIUM_RANGE_STILL = 21,
			MEDIUM_RANGE_MOVING = 19,

			LONG_RANGE_STILL = 11,
			LONG_RANGE_MOVING = 10,

			VERY_LONG_RANGE_STILL = 8,
			VERY_LONG_RANGE_MOVING = 7),

		// medium body parts: limbs
		"medium" = list(
			SHORT_RANGE_STILL = 38,
			SHORT_RANGE_MOVING = 34,

			MEDIUM_RANGE_STILL = 30,
			MEDIUM_RANGE_MOVING = 27,

			LONG_RANGE_STILL = 23,
			LONG_RANGE_MOVING = 21,

			VERY_LONG_RANGE_STILL = 11,
			VERY_LONG_RANGE_MOVING = 10),

		// large body parts: chest, groin
		"large" = list(
			SHORT_RANGE_STILL = 45,
			SHORT_RANGE_MOVING = 41,

			MEDIUM_RANGE_STILL = 38,
			MEDIUM_RANGE_MOVING = 34,

			LONG_RANGE_STILL = 30,
			LONG_RANGE_MOVING = 27,

			VERY_LONG_RANGE_STILL = 15,
			VERY_LONG_RANGE_MOVING = 14),
	)

	accuracy_increase_mod = 2.00
	accuracy_decrease_mod = 6.00
	KD_chance = KD_CHANCE_VERY_LOW