// Nylon (Val, 2026-11-21; plan "Resin materials plan", PR 7).
//
// From WW2 the bakelizer (resin_laminate.dm) can be set to nylon thread: every
// 5 petroleum spins 2 skeins, taken out with its Remove verb. Weave the thread
// at a loom (production.dm) into nylon cloth, a light, strong, rot-proof
// fabric for canopies, ponchos, folding umbrellas and rope.
//
// Sprites by Fable (icons/obj/fabrics.dmi).

/obj/item/stack/nylon_thread
	name = "nylon thread"
	desc = "Smooth, glassy synthetic thread. Weave it at a loom into nylon cloth."
	singular_name = "skein"
	icon = 'icons/obj/fabrics.dmi'
	icon_state = "nylon_thread"
	w_class = ITEM_SIZE_SMALL
	max_amount = 50
	value = 2
	flammable = TRUE

/material/nylon
	name = "nylon"
	display_name = "nylon"
	use_name = "nylon"
	icon_colour = "#6E7F5A"
	hardness = 12
	weight = 2
	sheet_singular_name = "bolt"
	sheet_plural_name = "bolts"
	stack_type = /obj/item/stack/material/nylon
	door_icon_base = "wood"
	flags = MATERIAL_PADDING
	resilience = 0.0
	density = 4
	firmness = 6
	toughness = 70
	wear = 45
	heat_limit = 200
	corrosion = 0
	spring = 50
	shaping = SHAPE_SEWN

/obj/item/stack/material/nylon
	name = "nylon"
	desc = "Tough, light nylon cloth. It does not rot and dries in minutes."
	icon = 'icons/obj/fabrics.dmi'
	icon_state = "nylon"
	default_type = "nylon"
	apply_colour = FALSE
	value = 5
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE

/obj/item/stack/material/nylon/New()
	update_icon()
	return ..()

/obj/item/stack/material/nylon/update_icon()
	icon_state = "nylon[pile_suffix(amount, list(13, 26, 39))]"
