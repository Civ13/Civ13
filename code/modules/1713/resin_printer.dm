// Resin 3D printing (Val, 2026-11-21; plan "Resin materials plan", PR 9).
//
// In the Digital Age the bakelizer (resin_laminate.dm) can be set to
// photopolymer resin: every 5 petroleum fills 2 bottles, taken out with its
// Remove verb. The resin 3D printer is a second printer beside the plastic one
// (factory_fabricators.dm). It runs only the printing rows whose feedstock is
// photopolymer (config/crafting/factory_recipes.txt), and the plastic printer
// no longer lists those rows, so every plastic recipe is unchanged. Bottles go
// in by hand or by arms and belts; it needs cable power like the plastic one.
//
// Resin prints are small and precise: lathe-grade gear sets, bearings and
// springs, chess sets and dice.
//
// Printer sprites by Fable (icons/obj/resin_works.dmi); the bottle reuses the
// chemistry bottle.

/obj/item/stack/photopolymer
	name = "photopolymer resin"
	desc = "Bottles of thin, light-curing printer resin. Load them into a resin 3D printer."
	singular_name = "bottle"
	icon = 'icons/obj/chemical.dmi'
	icon_state = "bottle-2"
	w_class = ITEM_SIZE_SMALL
	max_amount = 20
	value = 4

// TRUE when a factory recipe is a resin print (its feedstock is photopolymer).
/proc/factory_resin_print(datum/factory_recipe/R)
	if (!R || !R.inputs)
		return FALSE
	for (var/input_type in R.inputs)
		if (ispath(input_type, /obj/item/stack/photopolymer))
			return TRUE
	return FALSE

// Which printing rows a printer runs: the plastic printer takes the others.
/obj/structure/factory_fabricator/printer/proc/prints_resin()
	return FALSE

/obj/structure/factory_fabricator/printer/resin
	name = "resin 3D printer"
	desc = "A vat printer that cures photopolymer resin layer by layer with light, for small, precise parts the plastic printer cannot make. Set what it prints by hand, then load resin bottles by hand or with arms and belts. Cable it to run; prints are left in front of it."
	icon = 'icons/obj/resin_works.dmi'
	icon_state = "resin_printer"
	base_state = "resin_printer"

/obj/structure/factory_fabricator/printer/resin/prints_resin()
	return TRUE

/obj/structure/factory_fabricator/printer/resin/update_icon()
	icon_state = (powered && fab_active) ? "[base_state]_on" : base_state

// Lathe-grade machine parts printed in resin (machine_parts.dm).
/obj/item/machine_part/gear/printed
	part_material = "plastic"
	precise = TRUE
	castable = FALSE

/obj/item/machine_part/bearing/printed
	part_material = "plastic"
	precise = TRUE
	castable = FALSE

/obj/item/machine_part/spring/printed
	part_material = "plastic"
	precise = TRUE
	castable = FALSE

// The bakelizer's photopolymer bottles (Remove verb, modern_items.dm).
/obj/structure/bakelizer/var/photopolymer = 0

/obj/structure/bakelizer/proc/bakelizer_eject_photopolymer(mob/user)
	if (photopolymer <= 0)
		photopolymer = 0
		return FALSE
	new /obj/item/stack/photopolymer(get_turf(src), photopolymer)
	photopolymer = 0
	bakelizer_desc()
	if (user)
		to_chat(user, SPAN_NOTICE("You take the bottles of photopolymer resin out of \the [src]."))
	return TRUE
