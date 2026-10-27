/obj/item/organ/lungs
	name = "lungs"
	icon_state = "lungs"
	gender = PLURAL
	organ_tag = "lungs"
	parent_organ = "chest"


	var/active_breathing = 1

	relative_size = 60
	w_class = ITEM_SIZE_SMALL
/obj/item/organ/lungs/set_dna(var/datum/dna/new_dna)
	..()

/obj/item/organ/lungs/proc/handle_breath(datum/gas_mixture/breath)
	return
/obj/item/organ/lungs/proc/handle_temperature_effects(datum/gas_mixture/breath)
	return


/obj/item/organ/lungs/process()
	..()

	if (!owner)
		return

	if (germ_level > INFECTION_LEVEL_ONE)
		if (prob(5))
			owner.emote("cough")		//respitory tract infection

	#ifndef NO_INTERNAL_BLEEDING
	if (is_bruised())
		if (prob(2))
			spawn owner.emote("me", TRUE, "coughs up blood!")
			owner.drip(10)
		if (prob(4))
			spawn owner.emote("me", TRUE, "gasps for air!")
			owner.losebreath += 15
	#endif