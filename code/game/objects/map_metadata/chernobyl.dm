

























/////////////nuclear shit////////

/obj/item/weapon/reagent_containers/nuclear/fuelrod ////mid rad
	icon = 'icons/obj/items.dmi'
	name = "a cracked reactor fuel rod"
	desc = "A rod of nuclear fuel,very radioactive."
	icon_state = "nrod"
	var/radioactive = TRUE
	var/radioactive_amt = 5
	flammable = FALSE
	var/vol = 10
	value = 200
	New()
		..()
		reagents.add_reagent("uranium", 10)

/obj/item/weapon/reagent_containers/nuclear/controlrod ////low rad
	icon = 'icons/obj/items.dmi'
	name = "a reactor control rod"
	desc = "A former reactor control rod. now its slightly radioactive and broken."
	icon_state = "crod"
	var/radioactive = TRUE
	var/radioactive_amt = 1
	var/vol = FALSE
	flammable = FALSE
	value = 100

/obj/item/weapon/reagent_containers/nuclear/meltedsomething ////inside reactor (very dangerous)
	icon = 'icons/obj/items.dmi'
	name = "a melted radioactive mess"
	desc = "Its still hot to the touch, you can see a faint green glow around it, its probably highly radioactive."
	icon_state = "messrad"
	var/radioactive = TRUE
	var/radioactive_amt = 10
	flammable = FALSE
	var/vol = 50
	value = 300
	New()
		..()
		reagents.add_reagent("uranium", 50)

/obj/item/weapon/reagent_containers/nuclear/nuclearwastebarrel ///very low rad
	name = "yellow steel barrel (nuclear waste)"
	desc = "A yellow steel barrel. You can put liquids inside."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "barreln"
	//item_state = ???? TO DO TODO or check
	density = TRUE
	var/label_text = "Nuclear Waste"
	value = 50
	volume = 10
	New()
		..()
		flags &= ~OPENCONTAINER
		reagents.add_reagent("uranium",5)
		reagents.add_reagent("plutonium",5)

///////////////not radioactive
/obj/item/weapon/reagent_containers/nuclear/notnuclear/uraniumref
	name = "uranium refinery"
	desc = "A uranium refinery."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "uranium_refinery"
	flammable = FALSE
	var/not_movable = TRUE
	var/not_disassemblable = TRUE
	density = TRUE
	opacity = FALSE
	anchored = TRUE
