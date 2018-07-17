/obj/item/stack/money
	name = "money"
	desc = "A stack of banknotes."
	singular_name = "reichmark"
	icon_state = "money"
	flags = CONDUCT
	w_class = 3.0
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	throw_speed = 5
	throw_range = 20
	matter = list(DEFAULT_WALL_MATERIAL = 1875)
	amount = 20
	max_amount = 500
	attack_verb = list("hit", "bludgeoned", "whacked")
	w_class = 2.0 // fits in pockets
