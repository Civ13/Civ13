
/mob/living/carbon/human/get_visible_implants(var/class = FALSE)
/*
	var/list/visible_implants = list()
	for (var/obj/item/organ/external/organ in organs)
		for (var/obj/item/weapon/O in organ.implants)
			if (!istype(O,/obj/item/weapon/implant) && (O.w_class > class) && !istype(O,/obj/item/weapon/material/shard/shrapnel))
				visible_implants += O

	return(visible_implants)*/
	return list()

/mob/living/carbon/human/embedded_needs_process()
	for (var/obj/item/organ/external/organ in organs)
		for (var/obj/item/O in organ.implants)
		//	if (!istype(O, /obj/item/weapon/implant)) //implant type items do not cause embedding effects, see handle_embedded_objects()
			return TRUE
	return FALSE

/mob/living/carbon/human/proc/handle_embedded_objects()

	for (var/obj/item/organ/external/organ in organs)
		if (organ.status & ORGAN_SPLINTED) //Splints prevent movement.
			continue
		for (var/obj/item/O in organ.implants)
			if (/*!istype(O,/obj/item/weapon/implant) && */prob(2)) //Moving with things stuck in you could be bad.
				// All kinds of embedded objects cause bleeding.
				if (species.flags & NO_PAIN)
					src << "<span class='warning'>You feel [O] moving inside your [organ.name].</span>"
				else
					var/msg = pick( \
						"<span class='warning'>A spike of pain jolts your [organ.name] as you bump [O] inside.</span>", \
						"<span class='warning'>Your movement jostles [O] in your [organ.name] painfully.</span>", \
						"<span class='warning'>Your movement jostles [O] in your [organ.name] painfully.</span>")
					src << msg

				organ.take_damage(rand(1,3), FALSE, FALSE)
				if (!(organ.status & ORGAN_ROBOT) && !(species.flags & NO_BLOOD)) //There is no blood in protheses.
					organ.status |= ORGAN_BLEEDING
					adjustToxLoss(rand(1,3))