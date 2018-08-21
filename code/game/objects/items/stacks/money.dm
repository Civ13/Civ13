/obj/item/stack/coin
	name = "gold coins"
	desc = "Shiny gold coins."
	singular_name = "coin"
	icon_state = "money"
	flags = CONDUCT
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	throw_speed = 8
	throw_range = 10
	matter = list(DEFAULT_WALL_MATERIAL = 1875)
	amount = 10
	max_amount = 500
	attack_verb = list("hit")
	w_class = 2.0 // fits in pockets
	var/value = 1

/obj/item/stack/coin/goldnugget
	name = "gold nuggets"
	desc = "A shiny gold nugget."
	singular_name = "nugget"
	icon_state = "money"
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_NORMAL
	throw_speed = 5
	throw_range = 7
	amount = 1
	max_amount = 5
	value = 10

	/obj/item/stack/coin/gems
	name = "gems"
	desc = "Assorted precious gems."
	singular_name = "gem"
	icon_state = "money"
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_WEAK
	throw_speed = 5
	throw_range = 7
	amount = 1
	max_amount = 8
	value = 6

	/obj/item/stack/money/pearls
	name = "pearls"
	desc = "a bunch of pearls. Looks valuable!"
	singular_name = "nugget"
	icon_state = "money"
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	throw_speed = 4
	throw_range = 8
	amount = 5
	max_amount = 15
	value = 4