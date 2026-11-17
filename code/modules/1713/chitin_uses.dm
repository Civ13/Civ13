// Chitin uses: crushed shell. Crabs, trilobites and beetles drop chitin when
// butchered (animal_harvest.dm); the lime kiln burns crushed shell to
// quicklime (clay_lime_fire.dm) and dirt takes it as fertiliser.

// Crab and beetle shell pounded to grit. Spread on a field it sweetens the
// soil; burnt in a lime kiln it gives quicklime like stone does.
/obj/item/stack/crushed_shell
	name = "crushed shell"
	desc = "Crab shell pounded to coarse grit. Spread it on farm soil, or burn it in a lime kiln for quicklime."
	icon = 'icons/obj/materials.dmi'
	icon_state = "crushed_shell"
	singular_name = "handful of crushed shell"
	max_amount = 50
	w_class = ITEM_SIZE_SMALL
	flammable = FALSE
	fertilizer_value = 15
	value = 1
