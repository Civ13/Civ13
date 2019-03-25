/obj/structure/religious
	name = "gravestone"
	desc = "A gravestone made with polished stone."
	icon = 'icons/obj/cross.dmi'
	icon_state = "gravestone"
	var/health = 100
	not_movable = TRUE
	not_disassemblable = FALSE

/obj/structure/religious/gravestone
	name = "gravestone"
	desc = "A gravestone made with polished stone."
	icon = 'icons/obj/cross.dmi'
	icon_state = "gravestone"
	density = FALSE
	anchored = TRUE

/obj/structure/religious/totem
	name = "stone totem"
	desc = "A stone statue, representing a spirit animal of this tribe."
	icon = 'icons/obj/cross.dmi'
	icon_state = "goose"
	density = TRUE
	anchored = TRUE
	var/tribe = "goose"
	var/religion = "none"
	layer = 3.2

/obj/structure/religious/totem/New()
	..()
	spawn(10)
		if (religion != "none")
			name = "[religion]'s stone totem"
			desc = "A stone totem dedicated to the [religion] religion."
			icon_state = pick("bear","mouse","goose","wolf","turkey","monkey")
			if (map.custom_religions[religion][7] == "Shamans")
				map.custom_religions[religion][3] += 25

/obj/structure/religious/animal_statue
	name = "statue"
	desc = "A stone statue."
	icon = 'icons/obj/cross.dmi'
	icon_state = "goose"
	density = TRUE
	anchored = TRUE
	layer = 3.2

/obj/structure/religious/animal_statue/New()
	..()
	var/randimg = pick("bear","mouse","goose","wolf","turkey","monkey")
	icon_state = randimg
	name = "[randimg] statue"

/obj/structure/religious/woodcross1
	name = "small wood cross"
	desc = "A small engraved wood cross."
	icon = 'icons/obj/cross.dmi'
	icon_state = "cross1"
	density = FALSE
	anchored = TRUE
	health = 50
	flammable = TRUE

/obj/structure/religious/woodcross2
	name = "wood cross"
	desc = "An engraved wood cross."
	icon = 'icons/obj/cross.dmi'
	icon_state = "cross2"
	density = FALSE
	anchored = TRUE
	health = 50
	flammable = TRUE

/obj/structure/religious/grave
	name = "open grave"
	desc = "An opened grave."
	icon = 'icons/obj/cross.dmi'
	icon_state = "grave_overlay"
	density = FALSE
	anchored = TRUE
	var/open = TRUE
	not_disassemblable = TRUE
	not_movable = TRUE
/obj/structure/religious/grave/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/shovel) && open)
		visible_message("[user] starts filling up \the [src]...","You start filling up \the [src]...")
		playsound(src,'sound/effects/shovelling.ogg',100,1)
		if (do_after(user, 100, src))
			if (open)
				user << "You fill up \the [src]."
				open = FALSE
				icon_state = "grave_filled"
				name = "grave"
				desc = "a grave."
				for (var/obj/structure/religious/remains/RMN in src.loc)
					RMN.forceMove(src)
				for (var/obj/item/IT in src.loc)
					IT.forceMove(src)
				for (var/mob/living/ML in src.loc)
					if (ML.stat != 0)
						ML.forceMove(src)
					else
						if (istype(ML, /mob/living/carbon/human))
							var/mob/living/carbon/human/H = ML
							H.buriedalive = TRUE
							H.buried_proc()
							ML.anchored = TRUE
							if (H.client)
								H.client.perspective = EYE_PERSPECTIVE
								H.client.eye = src
						else
							ML.stat = DEAD
						ML.forceMove(src)
				for (var/obj/structure/closet/coffin/CF in src.loc)
					for (var/mob/living/carbon/human/HM in CF)
						HM.buriedalive = TRUE
						HM.buried_proc()
						if (HM.client)
							HM.client.perspective = EYE_PERSPECTIVE
							HM.client.eye = src
					CF.forceMove(src)
		else
			return
	else if (istype(W, /obj/item/weapon/shovel) && !open)
		visible_message("[user] starts digging up \the [src]...","You start digging up \the [src]...")
		playsound(src,'sound/effects/shovelling.ogg',100,1)
		if (do_after(user, 100, src))
			if (!open)
				user << "You uncover \the [src]."
				open = TRUE
				icon_state = "grave_overlay"
				name = "open grave"
				desc = "An opened grave."
				for (var/obj/structure/religious/remains/RMN in src)
					RMN.forceMove(src.loc)
				for (var/obj/item/IT in src)
					IT.forceMove(src.loc)
				for (var/mob/living/ML in src)
					if (ML.stat != 0)
						ML.forceMove(src.loc)
					else
						if (istype(ML, /mob/living/carbon/human))
							var/mob/living/carbon/human/H = ML
							H.buriedalive = FALSE
							ML.anchored = FALSE
							if (H.client)
								H.client.eye = H.client.mob
								H.client.perspective = MOB_PERSPECTIVE
						else
							ML.stat = DEAD
						ML.forceMove(src.loc)
				for (var/obj/structure/closet/coffin/CF in src)
					for (var/mob/living/carbon/human/HM in CF)
						HM.buriedalive = FALSE
						if (HM.client)
							HM.client.eye = HM.client.mob
							HM.client.perspective = MOB_PERSPECTIVE
					CF.forceMove(src.loc)
	else
		return

/obj/structure/religious/impaledskull
	name = "impaled skull"
	desc = "A skull on a spike."
	icon = 'icons/obj/structures.dmi'
	icon_state = "impaledskull"

/obj/structure/religious/tribalmask
	name = "native wood mask"
	desc = "A decorative wood mask."
	icon = 'icons/misc/tribal.dmi'
	icon_state = "tribalmask1"
	flammable = TRUE

/obj/structure/religious/remains
	name = "human remains"
	desc = "A bunch of human bones. Spooky."
	icon = 'icons/misc/tribal.dmi'
	icon_state = "remains1"
	anchored = FALSE
	not_disassemblable = TRUE
	not_movable = TRUE
/obj/structure/religious/remains/New()
	..()
	icon_state = "remains[rand(1,6)]"

/obj/structure/religious/tribalmask/New()
	..()
	icon_state = "tribalmask[rand(1,2)]"

/obj/structure/religious/attackby(obj/item/W as obj, mob/user as mob)
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	switch(W.damtype)
		if ("fire")
			health -= W.force * 0.3
		if ("brute")
			health -= W.force * 0.3

	playsound(get_turf(src), 'sound/weapons/smash.ogg', 100)
	user.do_attack_animation(src)
	try_destroy()
	..()

/obj/structure/religious/proc/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>The [src] is broken into pieces!</span>")
		qdel(src)
		return

/obj/structure/religious/totem/offerings
	icon = 'icons/misc/support.dmi'
	icon_state = "goose"
	bound_height = 64
	var/power = 175
	health = 100000000
	var/current_tribesmen = 0
	var/reltype = "tribal" //tribal or colony
	not_disassemblable = TRUE
	not_movable = TRUE
/obj/structure/religious/totem/offerings/proc/create_mobs()
	var/I = 0
	while(I < round(current_tribesmen/2))

		var/mob/living/simple_animal/hostile/skeleton/attacker_gods/newmob = new /mob/living/simple_animal/hostile/skeleton/attacker_gods(src.loc)
		newmob.target_loc = loc
		var/randdir = pick(1,2,3,4)
		if (randdir == 1)
			newmob.x=src.x+(rand(-15,15))
			newmob.y=src.y+(rand(12,25))
		else if (randdir == 2)
			newmob.x=src.x+(rand(-15,15))
			newmob.y=src.y+(rand(-12,-25))
		else if (randdir == 3)
			newmob.x=src.x+(rand(-12,-25))
			newmob.y=src.y+(rand(-15,15))
		else
			newmob.x=src.x+(rand(12,25))
			newmob.y=src.y+(rand(-15,15))
		if (istype(get_turf(newmob), /turf/wall) || istype (get_turf(newmob), /turf/floor/dirt/underground) || istype (get_turf(newmob), /turf/floor/beach/water/deep))
			while (istype(get_turf(newmob), /turf/wall) || istype (get_turf(newmob), /turf/floor/dirt/underground) || istype (get_turf(newmob), /turf/floor/beach/water/deep))
				if (randdir == 1)
					newmob.x=src.x+(rand(-15,15))
					newmob.y=src.y+(rand(12,25))
				else if (randdir == 2)
					newmob.x=src.x+(rand(-15,15))
					newmob.y=src.y+(rand(-12,-25))
				else if (randdir == 3)
					newmob.x=src.x+(rand(-12,-25))
					newmob.y=src.y+(rand(-15,15))
				else
					newmob.x=src.x+(rand(12,25))
					newmob.y=src.y+(rand(-15,15))
		I += 1
/obj/structure/religious/totem/offerings/proc/check_favours()
	spawn(1800)
		//very angry
		if (power < 50)
			if (weather == WEATHER_NONE)
				change_weather_somehow()
			visible_message("The gods are angry, sending heavy rains!")
			if (prob(100-power))
				var/diseasedone = FALSE
				for (var/mob/living/carbon/human/HH in range(10,loc))
					if (diseasedone == FALSE)
						HH.disease = TRUE
						if (99)
							HH.disease_type = "flu"
						else
							HH.disease_type = "plague"
						HH.disease_progression = 0
						diseasedone = TRUE
//				world << "You feel a chill down your spine, something evil is close by..."
//				create_mobs()
		//angry
		else if (power >= 50 && power < 100)
			if (prob(100-power))
				visible_message("Heavy winds and rain have destroyed the crops!")
				if (weather == WEATHER_NONE)
					change_weather_somehow()
				for (var/obj/structure/farming/plant/P in range(30,loc))
					P.icon_state = "[P.plant]-dead"
					P.desc = "A dead [P.plant] plant."
					P.name = "dead [P.plant] plant"
					P.stage = 11

		//neutral
		else if (power >= 100 && power < 150)
			//nothing
			world << ""

		//pleased
		else if (power >= 150 && power < 250)
			if (prob(power/250))
				if (weather == WEATHER_RAIN || WEATHER_SNOW)
					change_weather_somehow()
					visible_message("The gods have blessed us with good weather!")
		//very pleased
		else if (power >= 250)
			if (weather == WEATHER_RAIN || WEATHER_SNOW)
				change_weather_somehow()
			visible_message("The gods have blessed us with good weather!")
			if (prob(50) && human_clients_mob_list.len>0)
				if (prob(30))
					visible_message("The gods send us offerings!")
					new /obj/item/weapon/reagent_containers/food/condiment/tealeaves(loc)
				else if (prob(20))
					visible_message("The gods send us offerings!")
					new /obj/item/weapon/reagent_containers/pill/opium(loc)
				else if (prob(20))
					visible_message("The gods send us offerings!")
					new /obj/item/stack/medical/splint(loc)
		if (power > 50)
			for (var/obj/effect/landmark/npctarget/TG in loc)
				qdel(TG)
		check_favours()
		return

/obj/structure/religious/totem/offerings/proc/check_power()
	spawn(600)
		if (reltype == "tribal")
			if (tribe == "goose")
				for (var/datum/job/indians/tribes/red/R in job_master.faction_organized_occupations)
					current_tribesmen = R.current_positions
			else if (tribe == "turkey")
				for (var/datum/job/indians/tribes/blue/R in job_master.faction_organized_occupations)
					current_tribesmen = R.current_positions
			else if (tribe == "bear")
				for (var/datum/job/indians/tribes/black/R in job_master.faction_organized_occupations)
					current_tribesmen = R.current_positions
			else if (tribe == "wolf")
				for (var/datum/job/indians/tribes/white/R in job_master.faction_organized_occupations)
					current_tribesmen = R.current_positions
			else if (tribe == "monkey")
				for (var/datum/job/indians/tribes/green/R in job_master.faction_organized_occupations)
					current_tribesmen = R.current_positions
			else if (tribe == "mouse")
				for (var/datum/job/indians/tribes/yellow/R in job_master.faction_organized_occupations)
					current_tribesmen = R.current_positions
			if (power > 0)
				power = (power-(current_tribesmen))
			var/pleasedval = "very angry!"
			if (power >= 50 && power < 100)
				pleasedval = "somewhat angry."
			if (power >= 100 && power < 150)
				pleasedval = "neutral."
			if (power >= 150 && power < 250)
				pleasedval = "somewhat pleased."
			if (power >= 250)
				pleasedval = "very pleased!"
			desc = "A [icon_state] stone totem. The gods seem to be [pleasedval]"
			check_power()
			return
		else
			current_tribesmen = human_clients_mob_list.len
			if (power > 0)
				power = (power-(2*current_tribesmen))
			var/pleasedval = "very angry!"
			if (power >= 50 && power < 100)
				pleasedval = "somewhat angry."
			if (power >= 100 && power < 150)
				pleasedval = "neutral."
			if (power >= 150 && power < 250)
				pleasedval = "somewhat pleased."
			if (power >= 250)
				pleasedval = "very pleased!"
			desc = "A big stone cross. God seem to be [pleasedval]"
			check_power()
			return

/obj/structure/religious/totem/offerings/New()
	..()
	if (reltype == "tribal")
		icon_state = tribe
		name = "[tribe] totem"
		desc = "A stone [tribe] totem."
		spawn(10)
			check_power()
			check_favours()
	else
		icon_state = "cross"
		name = "big stone cross"
		desc = "A stone cross."
		spawn(10)
			check_power()
			check_favours()

/obj/structure/religious/totem/offerings/attackby(obj/item/I as obj, mob/user as mob)
	if (power <= 1000)
		if (istype(I, /obj/item/organ/heart))
			power = (power + 75)
			if (reltype == "tribal")
				visible_message("The gods take [user]'s offering of \the [I]! They are very pleased!")
			else
				visible_message("God takes [user]'s offering of \the [I]! He is very pleased!")
			new /obj/effect/effect/smoke/fast(loc)
			qdel(I)
			return
		else if (istype(I, /obj/item/stack/teeth) || istype(I, /obj/item/stack/material/tobacco))
			power = (power + (I.amount*12))
			if (reltype == "tribal")
				visible_message("The gods take [user]'s offering of \the [I]! They are pleased!")
			else
				visible_message("God takes [user]'s offering of \the [I]! He is pleased!")
			new /obj/effect/effect/smoke/fast(loc)
			qdel(I)
			return
		else if (istype(I, /obj/item/weapon/reagent_containers/food/snacks))
			power = (power + 10)
			if (reltype == "tribal")
				visible_message("The gods take [user]'s offering of \the [I]! They are pleased!")
			else
				visible_message("God takes [user]'s offering of \the [I]! He is pleased!")
			new /obj/effect/effect/smoke/fast(loc)
			qdel(I)
			return
	else
		if (reltype == "tribal")
			visible_message("The gods reject [user]'s offering of \the [I]. They are satiated for now.")
		else
			visible_message("God rejects [user]'s offering of \the [I]. He is satisfied for now.")
		return
	..()

/obj/structure/religious/totem/offerings/attack_hand(mob/user as mob)
	if (user.druggy > 10)
		var/list/display1 = list("Heal (150)", "Cancel")
		var/choice1 = WWinput(user, "Your tribe has [power] favour points. What power do you request?", "Communicating with the Gods", "Cancel", display1)
		if (choice1 == "Cancel")
			return
		if (choice1 == "Heal (150)")
			var/list/closemobs = list("Cancel")
			for (var/mob/living/M in range(3,loc))
				closemobs += M
			var/choice2 = WWinput(user, "Who to heal?", "Healing Power", "Cancel", closemobs)
			if (choice2 == "Cancel")
				return
			else
				if (power >= 150)
					var/mob/living/healed = choice2
					healed.revive()
					power = (power - 150)
					return
				else
					user << "Not enough favour points."
					return
			return
	else
		user << "You failed to communicate with the gods. You need drugs to connect yourself with the astral plane."
		return