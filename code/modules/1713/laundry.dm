// Laundry treatments. Washing clothes with soap or detergent leaves a
// dirt-resistant finish: while the garment is worn it gains dirt more slowly,
// for a number of worn life ticks. Both fields are plain numbers, so they
// survive a save as ordinary changed fields (no world.time stamps).
//
// Hand washing (sink, water, trench) uses a cleaner held in the other hand.
// A washing machine takes one dose that its next finished cycle uses.

#define LAUNDRY_SOAP_RESIST 50 // percent of dirt blocked after a soap wash
#define LAUNDRY_SOAP_TICKS 1800 // worn life ticks (about an hour of wear)
#define LAUNDRY_LARD_RESIST 35
#define LAUNDRY_DETERGENT_RESIST 75
#define LAUNDRY_DETERGENT_TICKS 3600 // about two hours of wear
#define LAUNDRY_SOAP_USE 2 // bar uses spent per laundry wash (a bar has 30)
#define LAUNDRY_DETERGENT_DOSES 20

/obj/item/clothing
	var/dirt_resist = 0 // percent of dirt gain blocked while the finish lasts
	var/dirt_resist_left = 0 // worn life ticks the finish still lasts

// Adds worn dirt, reduced while a laundry finish lasts.
/obj/item/clothing/proc/gain_dirt(amount)
	if (dirt_resist_left > 0)
		amount *= max(0, 100 - dirt_resist) / 100
		dirt_resist_left--
		if (dirt_resist_left <= 0)
			dirt_resist_left = 0
			dirt_resist = 0
	dirtyness += amount
	if (dirtyness > 100)
		dirtyness = 100

// A fresh treatment replaces whatever finish the garment had.
/obj/item/clothing/proc/apply_laundry_treatment(resist, ticks)
	if (resist <= 0 || ticks <= 0)
		return FALSE
	dirt_resist = min(resist, 100)
	dirt_resist_left = ticks
	return TRUE

// Shared by every hand-washing spot. A soap or detergent in the user's other
// hand is spent to leave a finish. Returns the cleaner used, if any.
/obj/item/clothing/proc/hand_wash(mob/user)
	clean_blood()
	radiation = 0
	dirtyness = 0
	fleas = FALSE
	if (!user)
		return null
	var/obj/item/cleaner = user.get_inactive_hand()
	if (!cleaner || cleaner == src || !cleaner.laundry_resist())
		return null
	apply_laundry_treatment(cleaner.laundry_resist(), cleaner.laundry_ticks())
	to_chat(user, SPAN_NOTICE("You scrub \the [src] with \the [cleaner]. It should stay clean for longer."))
	cleaner.use_laundry_dose(user)
	return cleaner

/obj/item/clothing/proc/examine_laundry(mob/user)
	if (dirt_resist_left > 0)
		to_chat(user, SPAN_NOTICE("It was washed with soap or detergent and resists dirt for now."))

// Laundry cleaner interface. Items that are not cleaners answer 0.
/obj/item/proc/laundry_resist()
	return 0

/obj/item/proc/laundry_ticks()
	return 0

/obj/item/proc/use_laundry_dose(mob/user)
	return

/obj/item/weapon/soap/laundry_resist()
	return LAUNDRY_SOAP_RESIST

/obj/item/weapon/soap/laundry_ticks()
	return LAUNDRY_SOAP_TICKS

/obj/item/weapon/soap/lard/laundry_resist()
	return LAUNDRY_LARD_RESIST

/obj/item/weapon/soap/use_laundry_dose(mob/user)
	used += LAUNDRY_SOAP_USE
	if (used >= 30)
		if (user)
			to_chat(user, SPAN_NOTICE("\The [src] is used up."))
		qdel(src)
	else
		update_icon()

/obj/item/weapon/laundry_detergent
	name = "laundry detergent"
	desc = "A box of synthetic washing powder. Clothes washed with it stay clean much longer."
	icon = 'icons/obj/storage.dmi'
	icon_state = "box"
	color = "#9cc8ff"
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	var/doses = LAUNDRY_DETERGENT_DOSES

/obj/item/weapon/laundry_detergent/examine(mob/user, distance)
	..(user, distance)
	to_chat(user, SPAN_NOTICE("Enough for [doses] more wash[doses == 1 ? "" : "es"]."))

/obj/item/weapon/laundry_detergent/laundry_resist()
	return doses > 0 ? LAUNDRY_DETERGENT_RESIST : 0

/obj/item/weapon/laundry_detergent/laundry_ticks()
	return LAUNDRY_DETERGENT_TICKS

/obj/item/weapon/laundry_detergent/use_laundry_dose(mob/user)
	doses--
	if (doses <= 0)
		if (user)
			to_chat(user, SPAN_NOTICE("\The [src] is empty."))
		qdel(src)

// Synthetic detergent: petroleum sulfonated with sulfuric acid and neutralised
// with lye, so it needs an oil supply and an acid plant.
/datum/chemical_reaction/laundry_detergent
	name = "Laundry Detergent"
	id = "laundry_detergent"
	result = null
	required_reagents = list("petroleum" = 10, "sacid" = 5, "lye" = 5)
	result_amount = 1

/datum/chemical_reaction/laundry_detergent/on_reaction(var/datum/reagents/holder, var/created_volume)
	var/location = get_turf(holder.my_atom)
	for (var/i = 1, i <= created_volume, i++)
		new /obj/item/weapon/laundry_detergent(location)

#undef LAUNDRY_SOAP_RESIST
#undef LAUNDRY_SOAP_TICKS
#undef LAUNDRY_LARD_RESIST
#undef LAUNDRY_DETERGENT_RESIST
#undef LAUNDRY_DETERGENT_TICKS
#undef LAUNDRY_SOAP_USE
#undef LAUNDRY_DETERGENT_DOSES
