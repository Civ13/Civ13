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

/obj/structure/researchdesk/attackby(var/obj/item/W as obj, var/mob/living/human/H as mob)
	if (!map.civilizations || map.ID == MAP_NATIONSRP || map.ID == MAP_NATIONSRP_TRIPLE || map.ID == MAP_NATIONSRPMED || map.ID == MAP_NATIONSRP_WW2 || map.ID == MAP_NATIONSRP_COLDWAR || map.ID == MAP_NATIONSRP_COLDWAR_CAMPAIGN || map.ID == MAP_NOMADS_PERSISTENCE_BETA || map.ID == MAP_CIVILIZATIONS || map.ID == MAP_TRIBES || map.ID == MAP_FOUR_KINGDOMS || map.ID == MAP_THREE_TRIBES)
		return

	if (!W)
		return

	if (H.civilization == "none")
		H << "You are not part of any factions."
		return

	if (W.value == 0)
		H << "This item has no research value."
		return
	if (map.age1_done == FALSE)
		if (world.time < 36000 && map.custom_civs[H.civilization][1]+map.custom_civs[H.civilization][2]+map.custom_civs[H.civilization][3] >= (19*3))
			H << "You are already too advanced. You can research again in [(36000-world.time)/600] minutes."
			return
	else if (map.age1_done == TRUE && map.age2_done == FALSE)
		if (world.time < map.age2_timer && map.custom_civs[H.civilization][1]+map.custom_civs[H.civilization][2]+map.custom_civs[H.civilization][3] >= (map.age1_top*3))
			H << "You are already too advanced. You can research again in [(map.age2_timer-world.time)/600] minutes."
			return
	else if (map.age2_done == TRUE && map.age3_done == FALSE)
		if (world.time < map.age3_timer && map.custom_civs[H.civilization][1]+map.custom_civs[H.civilization][2]+map.custom_civs[H.civilization][3] >= (map.age2_top*3))
			H << "You are already too advanced. You can research again in [(map.age3_timer-world.time)/600] minutes."
			return
	else if (map.age3_done == TRUE && map.age4_done == FALSE)
		if (world.time < map.age3_timer && map.custom_civs[H.civilization][1]+map.custom_civs[H.civilization][2]+map.custom_civs[H.civilization][3] >= (map.age3_top*3))
			H << "You are already too advanced. You can research again in [(map.age4_timer-world.time)/600] minutes."
			return
	else if (map.age4_done == TRUE && map.age5_done == FALSE)
		if (world.time < map.age5_timer && map.custom_civs[H.civilization][1]+map.custom_civs[H.civilization][2]+map.custom_civs[H.civilization][3] >= (map.age4_top*3))
			H << "You are already too advanced. You can research again in [(map.age5_timer-world.time)/600] minutes."
			return
	if (!map.civilizations || map.ID == MAP_TRIBES || map.ID == MAP_FOUR_KINGDOMS || map.ID == MAP_THREE_TRIBES)
		return
	if (done == FALSE)
		if (istype(W, /obj/item/stack))
			marketval = W.value
			moneyin = (((marketval*W.amount)/100)*2)
		else
			marketval = W.value
			moneyin = ((marketval/100)*2)
		done = TRUE
		var/list/display = list("Industrial", "Military", "Health", "Cancel")
		var/choice = WWinput(H, "This is worth [moneyin] research points. Which category to research?", "Research Desk", "Cancel", display)
		if (choice == "Cancel" && W)
			done = FALSE
			return
		else if (choice == "Industrial" && W)
			map.custom_civs[H.civilization][1] += (moneyin)
			qdel(W)
			done = FALSE
			return
		else if (choice == "Military" && W)
			map.custom_civs[H.civilization][2] += (moneyin)
			qdel(W)
			done = FALSE
			return
		else if (choice == "Health" && W)
			map.custom_civs[H.civilization][3] += (moneyin)
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

//Chad Mode +

/obj/structure/researchdesk/chad
	name = "Altar of Chad."
	desc = "Grab live or dead people and sacrifice them."
	icon = 'icons/obj/structures.dmi'
	icon_state = "altar_of_chad"
	money = 0
	marketval = 0
	moneyin = 0
	density = TRUE
	anchored = TRUE
	done = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE

/obj/structure/researchdesk/chad/attackby(var/obj/item/W as obj, var/mob/living/human/H as mob)
	if (!W)
		return

	if (H.civilization == "none")
		H << "You are not part of any factions."
		return

	if (istype(W, /obj/item/weapon/grab))
		var/obj/item/weapon/grab/G = W
		var/mob/living/affecting = G.affecting
		if(!istype(affecting, /mob/living/human) && !istype(affecting, /mob/living/human/corpse))
			H << "This item has no research value."
			return
	if (map.age1_done == FALSE)
		if (world.time < 36000 && map.custom_civs[H.civilization][1]+map.custom_civs[H.civilization][2]+map.custom_civs[H.civilization][3] >= (19*3))
			H << "You are already too advanced. You can research again in [(36000-world.time)/600/60] hours."
			return
	else if (map.age1_done == TRUE && map.age2_done == FALSE)
		if (world.time < map.age2_timer && map.custom_civs[H.civilization][1]+map.custom_civs[H.civilization][2]+map.custom_civs[H.civilization][3] >= (map.age1_top*3))
			H << "You are already too advanced. You can research again in [(map.age2_timer-world.time)/600/60] hours."
			return
	else if (map.age2_done == TRUE && map.age3_done == FALSE)
		if (world.time < map.age3_timer && map.custom_civs[H.civilization][1]+map.custom_civs[H.civilization][2]+map.custom_civs[H.civilization][3] >= (map.age2_top*3))
			H << "You are already too advanced. You can research again in [(map.age3_timer-world.time)/600/60] hours."
			return
	else if (map.age3_done == TRUE && map.age4_done == FALSE)
		if (world.time < map.age3_timer && map.custom_civs[H.civilization][1]+map.custom_civs[H.civilization][2]+map.custom_civs[H.civilization][3] >= (map.age3_top*3))
			H << "You are already too advanced. You can research again in [(map.age4_timer-world.time)/600/60] hours."
			return
	else if (map.age4_done == TRUE && map.age5_done == FALSE)
		if (world.time < map.age5_timer && map.custom_civs[H.civilization][1]+map.custom_civs[H.civilization][2]+map.custom_civs[H.civilization][3] >= (map.age4_top*3))
			H << "You are already too advanced. You can research again in [(map.age5_timer-world.time)/600/60] hours."
			return

	if (done == FALSE)
		if (istype(W, /obj/item/weapon/grab))
			var/obj/item/weapon/grab/G = W
			var/mob/living/human/affecting = G.affecting
			if(istype(affecting, /mob/living/human))
				marketval = 10
				moneyin = 10
			else if(istype(affecting, /mob/living/human/corpse))
				marketval = 5
				moneyin = 5
			else
				H << "<span class='alert'>That is not a human!</span>"
				return
		else
			H << "<span class='alert'>You need to grab a human.</span>"
			return
		done = TRUE
		var/list/display = list("Industrial", "Military", "Health", "Cancel")
		var/choice = WWinput(H, "Worth [moneyin] points, what do you want them for?", "Altar of Chad", "Cancel", display)
		if (choice == "Cancel" && W)
			done = FALSE
			return
		else if (choice == "Industrial" && W)
			var/obj/item/weapon/grab/G = W
			var/mob/living/human/affecting = G.affecting
			if(affecting.lastKnownCkey != H.ckey)
				if(affecting != null)
					if(affecting.civilization != "none")
						map.custom_civs[affecting.civilization][1] = map.default_research
					affecting.crush()
					map.custom_civs[H.civilization][1] += (moneyin)
				else
					H << "<span class='alert'> You need to be holding someone.</span>"
					return
			else
				H << "<span class='alert'> Sacrificing yourself isn't very cash money of you.</span>"
				qdel(affecting)
				return
			done = FALSE
			return
		else if (choice == "Military" && W)
			var/obj/item/weapon/grab/G = W
			var/mob/living/human/affecting = G.affecting
			if(affecting.lastKnownCkey != H.ckey)
				if(affecting != null)
					if(affecting.civilization != "none")
						map.custom_civs[affecting.civilization][2] = map.default_research
					affecting.crush()
					map.custom_civs[H.civilization][2] += (moneyin)
				else
					H << "<span class='alert'> You need to be holding someone.</span>"
					return
			else
				H << "<span class='alert'> Sacrificing yourself isn't very cash money of you.</span>"
				qdel(affecting)
				return
			done = FALSE
			return
		else if (choice == "Health" && W)
			var/obj/item/weapon/grab/G = W
			var/mob/living/human/affecting = G.affecting
			if(affecting.lastKnownCkey != H.ckey)
				if(affecting != null)
					if(affecting.civilization != "none")
						map.custom_civs[affecting.civilization][3] = map.default_research
					affecting.crush()
					map.custom_civs[H.civilization][3] += (moneyin)
				else
					H << "<span class='alert'> You need to be holding someone.</span>"
					return
			else
				H << "<span class='alert'> Sacrificing yourself isn't very cash money of you.</span>"
				qdel(affecting)
				return
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