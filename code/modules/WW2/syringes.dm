// morphine syringes
/obj/item/weapon/reagent_containers/syringe/morphine
	name = "Morphine injector"
	desc = "Injector containing 5 units of morphine. Administer two of these to make someone sleep."
	icon = 'icons/WW2/medical.dmi'
	icon_state = "ww2_injector"
	w_class = 2
	volume = 5

/obj/item/weapon/reagent_containers/syringe/morphine/New()
	..()
	reagents.add_reagent("morphine", 5)
	mode = SYRINGE_INJECT

/obj/item/weapon/reagent_containers/syringe/morphine/update_icon()
	if (reagents.total_volume > 0)
		icon_state = "ww2_injector_full"
	else
		icon_state = "ww2_injector_empty"