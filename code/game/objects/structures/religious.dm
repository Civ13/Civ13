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

/obj/structure/religious/runestone
	name = "runestone"
	desc = "A large rock with a symbol carved into it."
	icon = 'icons/obj/statue.dmi'
	icon_state = "runestone"
	density = FALSE
	anchored = TRUE

/obj/structure/religious/runestone/runestone2
	icon_state = "runestone_2"

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

/obj/structure/religious/olmec_head
	name = "large stone head"
	desc = "A large stone head."
	icon = 'icons/obj/statue.dmi'
	icon_state = "olmec_head"
	density = TRUE
	anchored = TRUE
	layer = 3.2

/obj/structure/religious/moai
	name = "moai statue"
	desc = "A large stone statue."
	icon = 'icons/obj/statue.dmi'
	icon_state = "moai2_bottom"
	density = TRUE
	anchored = TRUE
	layer = 6
	var/image/top = null

	New()
		..()
		top = image(icon='icons/obj/statue.dmi', icon_state = "moai2_top", layer=3.2)
		top.pixel_y = 32
		update_icon()

	update_icon()
		..()
		overlays.Cut()
		overlays += top

/obj/structure/religious/moai/long
	name = "long moai statue"
	icon_state = "moai1_bottom"

	New()
		..()
		top.icon_state = "moai1_top"
		update_icon()


obj/structure/religious/monument
	name = "monumental construction"
	desc = "ping a @contributor or sergeant on the discord if you can see this."
	icon = 'icons/obj/statue.dmi'
	icon_state = null
	density = TRUE
	anchored = TRUE
	health = 500
	layer = 6
	var/image/top = null

	New()
		..()
		if (top)
			top.icon_state = null
		update_icon()

/obj/structure/religious/monument/obelisk
	name = "monumental sandstone obelisk"
	desc = "A large sandstone obelisk."
	icon_state = "obelisk_bottom"

	New()
		..()
		top = image(icon='icons/obj/statue.dmi', icon_state = "obelisk_top", layer=3.2)
		top.pixel_y = 32
		update_icon()

	update_icon()
		..()
		overlays.Cut()
		overlays += top

/obj/structure/religious/monument/megalith
	name = "monumental stone megalith"
	desc = "A enormous rough stone megalith planted into the ground."
	icon_state = "megalith_bottom"

	New()
		..()
		top = image(icon='icons/obj/statue.dmi', icon_state = "megalith_top", layer=3.2)
		top.pixel_y = 32
		update_icon()

	update_icon()
		..()
		overlays.Cut()
		overlays += top

/obj/structure/religious/monument/pillar_monument
	name = "monumental stone pillar"
	desc = "A tall pillar that stands triumphantly and is easy to the eye."
	icon_state = "monumental_pillar_bottom"

	New()
		..()
		top = image(icon='icons/obj/statue.dmi', icon_state = "monumental_pillar_top", layer=3.2)
		top.pixel_y = 32
		update_icon()

	update_icon()
		..()
		overlays.Cut()
		overlays += top

/obj/structure/religious/monument/crucero
	name = "monumental crucero cross"
	desc = "A large edifice of a cross, as if to impact a statement."
	icon_state = "crucero_bottom"
	New()
		..()
		top = image(icon='icons/obj/statue.dmi', icon_state = "crucero_top", layer=3.2)
		top.pixel_y = 32
		update_icon()

	update_icon()
		..()
		overlays.Cut()
		overlays += top

/obj/structure/religious/monument/venus
	name = "monumental marble statue of venus"
	desc = "A chiselled marble statue of the classical goddess venus, she is barely covered for modesty."
	icon_state = "venus_bottom"

	New()
		..()
		top = image(icon='icons/obj/statue.dmi', icon_state = "venus_top", layer=3.2)
		top.pixel_y = 32
		update_icon()

	update_icon()
		..()
		overlays.Cut()
		overlays += top

/obj/structure/religious/monument/karl_marx
	name = "monumental bronze statue of karl marx"
	desc = "The father of communism himself, enshrined in bronze."
	icon_state = "communist_santa_bottom"

	New()
		..()
		top = image(icon='icons/obj/statue.dmi', icon_state = "communist_santa_top", layer=3.2)
		top.pixel_y = 32
		update_icon()

	update_icon()
		..()
		overlays.Cut()
		overlays += top

/* Religious Monuments*/

/obj/structure/religious/monument/cultist
	name = "monumental cultist statue"
	desc = "ping a @contributor or sergeant on the discord if you can see this."
	icon_state = null
	var/religion = "none"

	New()
		..()
		top = image(icon='icons/obj/statue.dmi', icon_state = null, layer=3.2)
		top.pixel_y = 32
		update_icon()

	update_icon()
		..()
		overlays.Cut()
		overlays += top

/obj/structure/religious/monument/cultist/cthulu
	name = "monumental ominous statue of the deep-one"
	desc = "A large seated statue of creature, its visage is unsettling and the inscription on the base is written in a cryptic set of symbols."
	icon_state = "cthulu_bottom"

	New()
		..()
		top = image(icon='icons/obj/statue.dmi', icon_state = "cthulu_top", layer=3.2)
		top.pixel_y = 32
		update_icon()

	update_icon()
		..()
		overlays.Cut()
		overlays += top

/obj/structure/religious/monument/cultist/moloch
	name = "monumental ominous statue of the evil-one"
	desc = "A statue of a demonic being, its lifelike wings and features are prominently displayed in the stone."
	icon_state = "moloch_bottom"

	New()
		..()
		top = image(icon='icons/obj/statue.dmi', icon_state = "moloch_top", layer=3.2)
		top.pixel_y = 32
		update_icon()

	update_icon()
		..()
		overlays.Cut()
		overlays += top

/obj/structure/religious/monument/cultist/outsider
	name = "monumental ominous statue of the outsider"
	desc = "A statue of a extra-dimensional creature, it is baffling to look with strange physiology for dramatic effect."
	icon_state = "outsider_bottom"

	New()
		..()
		top = image(icon='icons/obj/statue.dmi', icon_state = "outsider_top", layer=3.2)
		top.pixel_y = 32
		update_icon()

	update_icon()
		..()
		overlays.Cut()
		overlays += top

/obj/structure/religious/monument/cultist/sauron
	name = "monumental ominous statue of the ruler"
	desc = "A statue of a tall armored figure, sceptre clutched firmly in hand, it radiates a area of uneasyness and authority."
	icon_state = "sauron_bottom"

	New()
		..()
		top = image(icon='icons/obj/statue.dmi', icon_state = "sauron_top", layer=3.2)
		top.pixel_y = 32
		update_icon()

	update_icon()
		..()
		overlays.Cut()
		overlays += top

/obj/structure/religious/monument/cultist/sauron/reverse //for mapping
	name = "monumental ominous statue of the ruler"
	desc = "A statue of a tall armored figure, sceptre clutched firmly in hand, it radiates a area of uneasyness and authority."
	icon_state = "reverse_sauron_bottom"

	New()
		..()
		top = image(icon='icons/obj/statue.dmi', icon_state = "reverse_sauron_top", layer=3.2)
		top.pixel_y = 32
		update_icon()

	update_icon()
		..()
		overlays.Cut()
		overlays += top

/obj/structure/religious/monument/cultist/sauron/examine(var/mob/living/L)
	if (L.original_job_title == "Orc tribesman")
		name = "monumental ominous statue of morgoth"
		desc = "A statue of a the dark lord morgoth, sceptre clutched firmly in hand, it cuts a impressive fiugure of authority."
		return

/obj/structure/religious/monument/cultist/sauron/reverse/examine(var/mob/living/L)
	if (L.original_job_title == "Orc tribesman")
		name = "monumental ominous statue of morgoth"
		desc = "A statue of a the dark lord morgoth, sceptre clutched firmly in hand, it cuts a impressive fiugure of authority."
		return

/obj/structure/religious/monument/monk
	name = "monumental monk statue"
	desc = "ping a @contributor or sergeant on the discord if you can see this."
	icon_state = null
	var/religion = "none"

	New()
		..()
		top = image(icon='icons/obj/statue.dmi', icon_state = null, layer=3.2)
		top.pixel_y = 32
		update_icon()

	update_icon()
		..()
		overlays.Cut()
		overlays += top

/obj/structure/religious/monument/monk/quangshi
	name = "monumental stone buddha"
	desc = "This large stone statue of bhudda, it extrubes a exceptional feeling of tranqulity and harmonious nature."
	icon_state = "quangshi_bottom"

	New()
		..()
		top = image(icon='icons/obj/statue.dmi', icon_state = "quangshi_top", layer=3.2)
		top.pixel_y = 32
		update_icon()

	update_icon()
		..()
		overlays.Cut()
		overlays += top

/obj/structure/religious/monument/priesthood
	name = "monumental priesthood statue"
	desc = "ping a @contributor or sergeant on the discord if you can see this."
	icon_state = null
	var/religion = "none"

	New()
		..()
		top = image(icon='icons/obj/statue.dmi', icon_state = null, layer=3.2)
		top.pixel_y = 32
		update_icon()

	update_icon()
		..()
		overlays.Cut()
		overlays += top

/obj/structure/religious/monument/priesthood/saint
	name = "monumental saint statue"
	desc = "A enormous stone statue of a angellic saint, with a sword firmly gripped in hand."
	icon_state = "saint_bottom"
	religion = "none"

	New()
		..()
		top = image(icon='icons/obj/statue.dmi', icon_state = "saint_top", layer=3.2)
		top.pixel_y = 32
		update_icon()

	update_icon()
		..()
		overlays.Cut()
		overlays += top

/obj/structure/religious/monument/shaman
	name = "monumental shaman statue"
	desc = "ping a @contributor or sergeant on the discord if you can see this."
	icon_state = null
	var/religion = "none"

	New()
		..()
		top = image(icon='icons/obj/statue.dmi', icon_state = null, layer=3.2)
		top.pixel_y = 32
		update_icon()

	update_icon()
		..()
		overlays.Cut()
		overlays += top

/obj/structure/religious/monument/shaman/ape
	name = "monumental statue of a giant ape"
	desc = "A enormous stone statue of a fearsome ape, it is beating its chest furiously."
	icon_state = "great_ape_bottom"
	religion = "none"

	New()
		..()
		top = image(icon='icons/obj/statue.dmi', icon_state = "great_ape_top", layer=3.2)
		top.pixel_y = 32
		update_icon()

	update_icon()
		..()
		overlays.Cut()
		overlays += top

/obj/structure/religious/monument/shaman/ape/examine(var/mob/living/L)
	if (L.original_job_title == "Gorilla tribesman")
		desc = "A enormous stone statue of a fearsome ape, it is a exemplar specimen of our kind, a real adonis."
		return

/*-Religious Monuments*/


/obj/structure/religious/aztec_statue
	name = "aztec statue"
	desc = "An aztec-style statue."
	icon = 'icons/obj/statue.dmi'
	icon_state = "aztec_statue"
	density = TRUE
	anchored = TRUE
	layer = 3.2

/obj/structure/religious/tiki_statue
	name = "tiki statue"
	desc = "A tiki style statue."
	icon = 'icons/obj/statue.dmi'
	icon_state = "tikistatue1"
	density = TRUE
	anchored = TRUE
	layer = 3.2
	flammable = TRUE

/obj/structure/religious/tiki_statue/small
	name = "tiki statue"
	icon_state = "tikistatue2"

/obj/structure/religious/totem_pole
	name = "wood totem pole"
	desc = "A wood totem pole, with several animals."
	icon = 'icons/obj/obj32x64.dmi'
	icon_state = "totem_pole"
	density = TRUE
	anchored = TRUE
	layer = 3.2
	flammable = TRUE

/obj/structure/religious/gargoyle
	name = "gargoyle statue"
	desc = "A statue of a watchful gargoyle."
	icon = 'icons/obj/statue.dmi'
	icon_state = "gargoyle"
	density = TRUE
	anchored = TRUE
	layer = 3.2

/obj/structure/religious/angel
	name = "angel statue"
	desc = "A statue of a watchful angel."
	icon = 'icons/obj/statue.dmi'
	icon_state = "angel"
	density = TRUE
	anchored = TRUE
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

/obj/structure/religious/totem/sandstone
	name = "sandstone totem"
	desc = "A sandstone statue, representing a spirit animal of this tribe."
	icon = 'icons/obj/cross.dmi'
	icon_state = "sandstone_snake"

/obj/structure/religious/totem/sandstone/New()
	..()
	spawn(10)
		if (religion != "none")
			name = "[religion]'s stone totem"
			desc = "A stone totem dedicated to the [religion] religion."
			icon_state = pick("sandstone_snake","sandstone_alligator","sandstone_ram","sandstone_eue")
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

/obj/structure/religious/animal_statue/sandstone
	name = "sandstone statue"
	desc = "A sandstone statue."
	icon = 'icons/obj/cross.dmi'
	icon_state = "sandstone_snake"

/obj/structure/religious/animal_statue/sandstone/New()
	..()
	var/randimg = pick("sandstone_snake","sandstone_alligator","sandstone_ram","sandstone_eue")
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
	var/filled = 0
	not_disassemblable = TRUE
	not_movable = TRUE
/obj/structure/religious/grave/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/material/shovel) && open)
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
						if (istype(ML, /mob/living/human))
							var/mob/living/human/H = ML
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
					for (var/mob/living/human/HM in CF)
						HM.buriedalive = TRUE
						HM.buried_proc()
						if (HM.client)
							HM.client.perspective = EYE_PERSPECTIVE
							HM.client.eye = src
					CF.forceMove(src)
		else
			return
	else if (istype(W, /obj/item/weapon/material/shovel) && !open)
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
				for (var/obj/structure/closet/crate/CR in src)
					CR.forceMove(src.loc)
				for (var/mob/living/ML in src)
					if (ML.stat != 0)
						ML.forceMove(src.loc)
					else
						if (istype(ML, /mob/living/human))
							var/mob/living/human/H = ML
							H.buriedalive = FALSE
							ML.anchored = FALSE
							if (H.client)
								H.client.eye = H.client.mob
								H.client.perspective = MOB_PERSPECTIVE
						else
							ML.stat = DEAD
						ML.forceMove(src.loc)
				for (var/obj/structure/closet/coffin/CF in src)
					for (var/mob/living/human/HM in CF)
						HM.buriedalive = FALSE
						if (HM.client)
							HM.client.eye = HM.client.mob
							HM.client.perspective = MOB_PERSPECTIVE
					CF.forceMove(src.loc)
	if (istype(W, /obj/item/weapon/barrier) && open)
		visible_message("[user] throws the dirt into \the [src].", "You throw the dirt into \the [src].")
		filled++
		qdel(W)
		if (filled >= 2)
			visible_message("The grave gets covered.")
			qdel(src)
			return
	else
		return

/obj/structure/religious/grave/initialize()
	..()
	if (!open)		// if closed, any item at the crate's loc is put in the contents
		var/obj/item/I
		icon_state = "grave_filled"
		for (I in loc)
			if (I.density || I.anchored || I == src) continue
			I.forceMove(src)
	update_icon()

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

		var/mob/living/simple_animal/hostile/human/skeleton/attacker_gods/newmob = new /mob/living/simple_animal/hostile/human/skeleton/attacker_gods(src.loc)
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
				for (var/mob/living/human/HH in range(10,loc))
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
				if (weather == WEATHER_WET)
					change_weather_somehow()
					visible_message("The gods have blessed us with good weather!")
		//very pleased
		else if (power >= 250)
			if (weather == WEATHER_WET)
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
		else if (istype(I, /obj/item/stack/teeth) || istype(I, /obj/item/stack/material/tobacco_green) || istype(I, /obj/item/stack/material/tobacco))
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

////////////////////STATUES///////////////////////
/obj/structure/religious/statue
	name = "statue"
	desc = "A human statue."
	icon = 'icons/obj/statue.dmi'
	icon_state = "human_male_base"
	density = TRUE
	anchored = TRUE
	layer = 3.2
	var/list/statue_layers = list()
	var/statue_material = "stone"
	New()
		..()
		spawn(1)
			if (name == "statue")
				name = "[statue_material] statue"
				update_icon()

/obj/structure/religious/statue/update_icon()
	..()
	overlays.Cut()
	for (var/i in statue_layers)
		if (findtext(i, "cl_"))
			var/image/timg = image(icon, i)
			overlays += timg
	for (var/i in statue_layers)
		if (findtext(i, "obj_"))
			var/image/timg = image(icon, i)
			overlays += timg
	color=get_material_by_name(statue_material).icon_colour

/obj/structure/religious/statue/king
	statue_layers = list("cl_king", "obj_spear", "obj_shield2")
	statue_material = "stone"
	New()
		..()
		name = "The King"

/obj/structure/religious/statue/king/sandstone
	statue_layers = list("cl_king", "obj_spear", "obj_shield2")
	statue_material = "sandstone"
	New()
		..()
		name = "The King"
