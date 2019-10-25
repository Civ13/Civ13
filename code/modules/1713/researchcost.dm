//experimental alternative research method - using resources to increase research.

/obj/structure/researchdesk
	name = "research desk"
	desc = "Use this study several items and increase your research levels."
	icon = 'icons/obj/structures.dmi'
	icon_state = "researchdesk"
	var/money = 0
	var/marketval = 0
	var/moneyin = 0
	density = TRUE
	anchored = TRUE
	var/done = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE

/obj/structure/researchdesk/New()
	..()
	if(map.chad_mode_plus)
		icon_state = "altar_of_chad"

/obj/structure/researchdesk/attackby(var/obj/item/W as obj, var/mob/living/carbon/human/H as mob)
	if (!map.civilizations || map.ID == MAP_CIVILIZATIONS || map.ID == MAP_TRIBES)
		return

	if (!W)
		return

	if (H.civilization == "none")
		H << "You are not part of any factions."
		return

	if(!map.chad_mode_plus) //if not chad mode, normal value check
		if (W.value == 0)
			H << "This item has no research value."
			return
	else //if is chad mode, only humans will suffice.
		if (!istype(W, /mob/living/carbon/human))
			H << "This item has no research value."
			return

	if (done == FALSE)
		if (!map.chad_mode_plus) //Normal research
			if (istype(W, /obj/item/stack))
				marketval = W.value
				moneyin = (((marketval*W.amount)/100)*2)
			else
				marketval = W.value
				moneyin = ((marketval/100)*2)
		else //If it IS Chad mode plus.
			if (istype(W, /mob/living/carbon/human))
				marketval = 8
				moneyin = 8
			else
				H << "<span class='alert'>Only humans will suffice.</span>"
				return
		done = TRUE
		var/list/display = list("Industrial", "Military", "Health", "Cancel")
		var/choice = WWinput(H, "This is worth [moneyin] research points. Which category to research?", "Research Desk", "Cancel", display)
		if (choice == "Cancel" && W)
			done = FALSE
			return
		else if (choice == "Industrial" && W)
			map.custom_civs[H.civilization][1] += (moneyin)
			if(map.chad_mode_plus)
				var/mob/living/carbon/human/SACRIFICE as mob
				SACRIFICE = W
				SACRIFICE.gib()
			else
				qdel(W)
			done = FALSE
			return
		else if (choice == "Military" && W)
			map.custom_civs[H.civilization][2] += (moneyin)
			if(map.chad_mode_plus)
				var/mob/living/carbon/human/SACRIFICE as mob
				SACRIFICE = W
				SACRIFICE.gib()
			else
				qdel(W)
			done = FALSE
			return
		else if (choice == "Health" && W)
			map.custom_civs[H.civilization][3] += (moneyin)
			if(map.chad_mode_plus)
				var/mob/living/carbon/human/SACRIFICE as mob
				SACRIFICE = W
				SACRIFICE.gib()
			else
				qdel(W)
			done = FALSE
			return
		else
			done = FALSE
			return
	else
		done = FALSE
		marketval = 0
		moneyin = 0
		return