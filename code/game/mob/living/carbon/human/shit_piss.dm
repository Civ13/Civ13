/*#####SHIT AND PISS#####
##Ok there's a lot of stupid shit here. Literally, but let me explain a bit why I put this here.
##I feel like poo and pee add a degree of autistic realism that you wouldn't otherwise get. And I'm autistic about that kind of thing.
##This file contains all the reagents, decals, objects and life procs. These procs are used in human/life.dm and human/emote.dm
##Have some shitty fun. - Matt
*/

//####DEFINES####
/mob
	var/bladder = 0
	var/bowels = 0
	var/crap_inside = FALSE

//#####DECALS#####
/obj/effect/decal/cleanable/poo
	name = "poo stain"
	desc = "Well that stinks."
	density = 0
	anchored = 1
	layer = 2
	icon = 'icons/effects/pooeffect.dmi'
	icon_state = "floor1"
	random_icon_states = list("floor1", "floor2", "floor3", "floor4", "floor5", "floor6", "floor7", "floor8")
	var/dried = 0
	decay_timer = 18000

/obj/effect/decal/cleanable/poo/New()
	icon = 'icons/effects/pooeffect.dmi'
	icon_state = pick(src.random_icon_states)
	for(var/obj/effect/decal/cleanable/poo/shit in src.loc)
		if(shit != src)
			qdel(shit)
	spawn(6000)
		dried = 1
		name = "dried poo stain"
		desc = "It's a dried poo stain..."

/obj/effect/decal/cleanable/poo/tracks
	icon_state = "tracks"
	random_icon_states = null

/obj/effect/decal/cleanable/poo/drip
	name = "drips of poo"
	desc = "It's brown."
	density = 0
	anchored = 1
	layer = 2
	icon = 'icons/effects/pooeffect.dmi'
	icon_state = "drip1"
	random_icon_states = list("drip1", "drip2", "drip3", "drip4", "drip5")

/obj/effect/decal/cleanable/poo/Crossed(AM as mob|obj, var/forceslip = 0)
	if (istype(AM, /mob/living/human) && src.dried == 0)
		var/mob/living/human/M = AM
		if (M.m_intent == "walk")
			return
		if(prob(5))
			M.slip("poo")

/obj/effect/decal/cleanable/urine
	name = "urine stain"
	desc = "Someone couldn't hold it..."
	density = 0
	anchored = 1
	layer = 2
	icon = 'icons/effects/pooeffect.dmi'
	icon_state = "pee1"
	random_icon_states = list("pee1", "pee2", "pee3")
	var/dried = 0
	decay_timer = 18000

/obj/effect/decal/cleanable/urine/Crossed(AM as mob|obj)
	if (istype(AM, /mob/living/human))
		var/mob/living/human/M =	AM
		if (ishuman(M) && M.m_intent == "walk")
			return
		if((!dried) && prob(5))
			M.slip("urine")

/obj/effect/decal/cleanable/urine/New()
	..()
	icon_state = pick(random_icon_states)
	//spawn(10) src.reagents.add_reagent("urine",5)
	for(var/obj/effect/decal/cleanable/urine/piss in src.loc)
		if(piss != src)
			qdel(piss)
	spawn(800)
		dried = 1
		name = "dried urine stain"
		desc = "That's a dried crusty urine stain. Fucking janitors."

//#####REAGENTS#####
//SHIT
/datum/reagent/poo
	name = "poo"
	id = "poo"
	description = "It's poo."
	reagent_state = LIQUID
	color = "#643200"
	taste_description = "literal shit"

/datum/reagent/poo/on_mob_life(var/mob/living/M)
	if(!M)
		M = holder.my_atom

	M.adjustToxLoss(1)
	holder.remove_reagent(src.id, 0.2)
	..()
	return

/datum/reagent/poo/touch_turf(var/turf/T)
	src = null
	new /obj/effect/decal/cleanable/poo(T)

//URINE
/datum/reagent/urine
	name = "urine"
	id = "urine"
	description = "It's pee."
	reagent_state = LIQUID
	color = COLOR_YELLOW
	taste_description = "urine"

/datum/reagent/urine/touch_turf(var/turf/T)
	src = null
	new /obj/effect/decal/cleanable/urine(T)

//#####ITEMS#####
//SHIT
/obj/item/weapon/reagent_containers/food/snacks/poo
	name = "poo"
	desc = "A chocolately surprise!"
	icon = 'icons/effects/pooeffect.dmi'
	icon_state = "poop2"
	item_state = "poop"
	satisfaction = -25 //tastes like shit
	disgusting = TRUE
	decay = 20*600
	New()
		..()
		icon_state = pick("poop1", "poop2", "poop3", "poop4", "poop5", "poop6", "poop7")
		reagents.add_reagent("poo", 10)
		biteamount = 3

/obj/item/weapon/reagent_containers/food/snacks/poo/animal
	name = "manure"
	desc = "Makes good fertilizer at least."
	dry_size = 6
	dried_type = /obj/item/stack/dung
	fertilizer_value = 10
	New()
		..()
		icon_state = pick("animal1", "animal2", "animal3")

/obj/item/weapon/reagent_containers/food/snacks/poo/fertilizer
	name = "compost"
	desc = "Natural fertilizer for your plants."
	decay = 120*600
	dry_size = 6
	dried_type = /obj/item/stack/dung
	fertilizer_value = 60
	New()
		..()
		icon_state = pick("animal1", "animal2", "animal3")

/obj/item/stack/dung
	icon = 'icons/effects/pooeffect.dmi'
	icon_state = "dry_dung"
	name = "dry dung"
	desc = "Fertilizer for your plants (or fuel)."
	value = 0
	can_stack = TRUE
	singular_name = "dry dung"
	fertilizer_value = 20
	max_amount = 40

/obj/item/weapon/reagent_containers/food/snacks/poo/throw_impact(atom/hit_atom)
	playsound(src.loc, "sound/effects/squishy.ogg", 40, 1)
	var/turf/T = src.loc
	new /obj/effect/decal/cleanable/poo(T)
	qdel(src)
	..()

//PISS
/obj/item/weapon/reagent_containers/glass/bottle/urine
	name = "urine bottle"
	desc = "A small bottle. Contains urine."
	icon = 'icons/obj/chemical.dmi'
	icon_state = "bottle15"
	New()
		..()
		reagents.add_reagent("urine", 30)

//#####LIFE PROCS#####
/mob/living/human/proc/print_excrement()
	if(bowels >= 250)
		switch(bowels)
			if(250 to 400)
				to_chat(src, "<span class='info'><b>You need to poo.</b></span>")
			if(400 to 450)
				to_chat(src, "<span class='notice'><b>You really need to poo!</b></span>")
			if(450 to 500)
				to_chat(src, "<span class='warning'><b>You're about to shit yourself!</b></span>")
			if(500 to INFINITY)
				to_chat(src, "<span class='danger'><b>OH MY GOD YOU HAVE TO SHIT!</b></span>")
	if(bladder >= 100)//Your bladder is smaller than your colon
		switch(bladder)
			if(100 to 250)
				to_chat(src, "<span class='notice'><b>You need to pee.</b></span>")
			if(250 to 400)
				to_chat(src, "<span class='notice'><b>You really need to pee!</b></span>")
			if(400 to 500)
				to_chat(src, "<span class='warning'><b>You're about to piss yourself!</b></span>")
			if(500 to INFINITY)
				to_chat(src, "<span class='danger'><b>OH MY GOD YOU HAVE TO PEE!</b></span>")
	return

//poo and pee counters. This is called in human_life.
/mob/living/human/proc/handle_excrement()
	if(bowels <= 0)
		bowels = 0
	if(bladder <= 0)
		bladder = 0
	if(bowels >= 250)
		switch(bowels)
			if(250 to 400)
				if(prob(5))
					to_chat(src, "<b>You need to use the bathroom.</b>")
					bowels += 10
			if(400 to 450)
				if(prob(7))
					to_chat(src, "<span class='danger'>You really need to use the restroom!</span>")
					bowels += 15
			if(450 to 500)
				if(prob(2))
					handle_shit()
				else if(prob(10))
					to_chat(src, "<span class='danger'>You're about to shit yourself!</span>")
					bowels += 25
			if(500 to 550)
				if(prob(15))
					handle_shit()
				else if(prob(30))
					to_chat(src, "<span class='danger'>OH MY GOD YOU HAVE TO SHIT!</span>")
					bowels += 35
			if(550 to INFINITY)
				handle_shit()
	if(bladder >= 100)//Your bladder is smaller than your colon
		switch(bladder)
			if(100 to 250)
				if(prob(5))
					to_chat(src, "<b>You need to use the bathroom.</b>")
					bladder += 10
			if(250 to 400)
				if(prob(7))
					to_chat(src, "<span class='danger'>You really need to use the restroom!</span>")
					bladder += 15
			if(400 to 500)
				if(prob(2))
					handle_piss()
				else if(prob(10))
					to_chat(src, "<span class='danger'>You're about to piss yourself!</span>")
					bladder += 25
			if(500 to 550)
				if(prob(15))
					handle_piss()
				else if(prob(30))
					to_chat(src, "<span class='danger'>OH MY GOD YOU HAVE TO PEE!</span>")
					bladder += 35
			if(550 to INFINITY)
				handle_piss()

//Shitting
/mob/living/human/proc/handle_shit()
	var/message = null
	if (src.bowels >= 30)
		//Poo in the loo.
		var/obj/structure/toilet/T = locate() in src.loc
		var/mob/living/M = locate() in src.loc
		if ((T && T.open) || (M.crap_inside))
			if (M.crap_inside)
				message = "<B>[src]</B> defecates into the hole."
			else
				message = "<B>[src]</B> defecates into \the [T]."
			var/obj/item/weapon/reagent_containers/food/snacks/poo/V = new/obj/item/weapon/reagent_containers/food/snacks/poo(src.loc)
			if(reagents)
				reagents.trans_to(V, rand(1,5))
			V.forceMove(T)
		else if(w_uniform)
			message = "<B>[src]</B> shits \his pants."
			reagents.add_reagent("poo", 10)
			adjust_hygiene(-25)
			mood -= 25
			w_uniform.shit_overlay = image(icon = 'icons/mob/human_races/masks/sickness.dmi', icon_state="shit")
			w_uniform.overlays += w_uniform.shit_overlay
			w_uniform.update_icon()
			update_icons()
		//Poo on the face.
		else if(M != src && M.lying) //Can only shit on them if they're lying down.
			message = "<span class='danger'><b>[src]</b> shits right on <b>[M]</b>'s face!</span>"
			if (M && M.reagents)
				M.reagents.add_reagent("poo", 10)
		//Poo on the floor.
		else
			message = "<B>[src]</B> [pick("shits", "craps", "poops")]."
			var/obj/item/weapon/reagent_containers/food/snacks/poo/V = new/obj/item/weapon/reagent_containers/food/snacks/poo(src.loc)
			if(reagents)
				reagents.trans_to(V, rand(1,5))
		playsound(src.loc, 'sound/effects/poo2.ogg', 60, 1)
		bowels -= rand(120,150)
	else
		to_chat(src, "You don't have to.")
		return
	visible_message("[message]")

//Peeing
/mob/living/human/proc/handle_piss()
	var/message = null
	if (bladder < 30)
		to_chat(src, "You don't have to.")
		return
	var/mob/living/M = locate() in src.loc
	var/obj/structure/toilet/T = locate() in src.loc
	var/obj/structure/toilet/T2 = locate() in src.loc
	var/obj/structure/sink/S = locate() in src.loc
	var/obj/item/weapon/reagent_containers/RC = locate() in src.loc
	if((S) && gender != FEMALE)//In the urinal or sink.
		message = "<B>[src]</B> urinates into [S]."
		reagents.remove_any(rand(5,10))
	else if( (T && T.open) || (T2 && T2.open) )//In the toilet.
		message = "<B>[src]</B> urinates into [T]."
		reagents.remove_any(rand(5,10))
	else if (M.crap_inside) //Into the hole inside the outhouse.
		message = "<B>[src]</B> urinates into the hole."
		reagents.remove_any(rand(5,10))
	else if(RC && (istype(RC,/obj/item/weapon/reagent_containers/food/drinks || istype(RC,/obj/item/weapon/reagent_containers/glass))))
		if(RC.is_open_container())
			//Inside a beaker, glass, drink, etc.
			message = "<B>[src]</B> urinates into [RC]."
			var/amount = rand(5,10)
			RC.reagents.add_reagent("urine", amount)
			if(reagents)
				reagents.trans_to(RC, amount)
	else if(w_uniform)//In your pants.
		message = "<B>[src]</B> pisses \his pants."
		adjust_hygiene(-25)
		mood -= 15
		w_uniform.piss_overlay = image(icon = 'icons/mob/human_races/masks/sickness.dmi', icon_state="piss")
		w_uniform.overlays += w_uniform.piss_overlay
		w_uniform.update_icon()
		update_icons()
	else//On the floor.
		var/turf/TT = src.loc
		var/obj/effect/decal/cleanable/urine/D = new/obj/effect/decal/cleanable/urine(src.loc)
		if(reagents)
			reagents.trans_to(D, rand(5,10))
		message = "<B>[src]</B> pisses on the [TT.name]."
	bladder -= rand(100,130)
	visible_message("[message]")
