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

//This proc is really deprecated.
/*/obj/effect/decal/cleanable/poo/proc/streak(var/list/directions)
	spawn (0)
		var/direction = pick(directions)
		for (var/i = 0, i < pick(1, 200; 2, 150; 3, 50; 4), i++)
			sleep(3)
			if (i > 0)
				new /obj/effect/decal/cleanable/poo(src.loc)
			if (step_to(src, get_step(src, direction), 0))
				break
*/

/obj/effect/decal/cleanable/poo/Crossed(AM as mob|obj, var/forceslip = 0)
	if (istype(AM, /mob/living/carbon) && src.dried == 0)
		var/mob/living/carbon/M = AM
		if (M.m_intent == "walk")
			return

		if(prob(5))
			M.slip("poo")

//These aren't needed for now.
///obj/effect/decal/cleanable/poo/tracks/Crossed(AM as mob|obj)
//	return

//obj/effect/decal/cleanable/poo/drip/Crossed(AM as mob|obj)
//	return

/obj/effect/decal/cleanable/urine
	name = "urine stain"
	desc = "Someone couldn't hold it.."
	density = 0
	anchored = 1
	layer = 2
	icon = 'icons/effects/pooeffect.dmi'
	icon_state = "pee1"
	random_icon_states = list("pee1", "pee2", "pee3")
	var/dried = 0

/obj/effect/decal/cleanable/urine/Crossed(AM as mob|obj)
	if (istype(AM, /mob/living/carbon))
		var/mob/living/carbon/M =	AM
		if ((ishuman(M) && istype(M:shoes, /obj/item/clothing/shoes/galoshes)) || M.m_intent == "walk")
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



/obj/effect/decal/cleanable/cum
	name = "cum"
	desc = "It's pie cream from a cream pie. Or not..."
	density = 0
	layer = 2
	icon = 'honk/icons/effects/cum.dmi'
	blood_DNA = list()
	anchored = 1
	random_icon_states = list("cum1", "cum3", "cum4", "cum5", "cum6", "cum7", "cum8", "cum9", "cum10", "cum11", "cum12")


/obj/effect/decal/cleanable/cum/New()
	..()
	icon_state = pick(random_icon_states)
	for(var/obj/effect/decal/cleanable/cum/jizz in src.loc)
		if(jizz != src)
			qdel(jizz)


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

//TO MAKE add_poo() PROC
/*			reaction_mob(var/mob/M, var/method=TOUCH, var/volume)
		src = null
		if(istype(M, /mob/living/carbon/human) && method==TOUCH)
			if(M:wear_suit) M:wear_suit.add_poo()
			if(M:w_uniform) M:w_uniform.add_poo()
			if(M:shoes) M:shoes.add_poo()
			if(M:gloves) M:gloves.add_poo()
			if(M:head) M:head.add_poo()
		//if(method==INGEST)
		//	if(prob(20))
			//	M.contract_disease(new /datum/disease/gastric_ejections)
			//	holder.add_reagent("gastricejections", 1)
			//	M:toxloss += 0.1
			//	holder.remove_reagent(src.id, 0.2)
*/

/datum/reagent/poo/touch_turf(var/turf/T)
	src = null
	if(!istype(T, /turf/space))
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
	if(!istype(T, /turf/space))
		new /obj/effect/decal/cleanable/urine(T)

//SEMEN
/datum/reagent/semen
	name = "semen"
	id = "semen"
	description = "It's semen."
	reagent_state = LIQUID
	color = COLOR_WHITE
	taste_description = "salt"

/datum/reagent/semen/touch_turf(var/turf/T)
	src = null
	if(!istype(T, /turf/space))
		new /obj/effect/decal/cleanable/cum(T)

/obj/item/weapon/reagent_containers/food/snacks/poo
	name = "poo"
	desc = "A chocolately surprise!"
	icon = 'icons/obj/poop.dmi'
	icon_state = "poop2"
	item_state = "poop"

/obj/item/weapon/reagent_containers/food/snacks/poo/New()
	..()
	icon_state = pick("poop1", "poop2", "poop3", "poop4", "poop5", "poop6", "poop7")
	reagents.add_reagent("poo", 10)
	bitesize = 3

/obj/item/weapon/reagent_containers/food/snacks/poo/throw_impact(atom/hit_atom)
	//if(prob(50)) //this is so we actually have a chance of recovering some from disposal.
	//	return
	playsound(src.loc, "sound/effects/squishy.ogg", 40, 1)
	var/turf/T = src.loc
	if(!istype(T, /turf/space))
		new /obj/effect/decal/cleanable/poo(T)
	//qdel(src) THIS IS BAD AND YOU SHOULD FEEL BAD.
	..()

//#####BOTTLES#####

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

//poo and pee counters. This is called in human/handle_stomach.
/mob/living/carbon/human/proc/handle_excrement()
	if(bowels <= 0)
		bowels = 0
	if(bladder <= 0)
		bladder = 0

	if(bowels >= 250)
		switch(bowels)
			if(250 to 400)
				if(prob(5))
					to_chat(src, "<b>You need to use the bathroom.</b>")
					bowels += 15
			if(400 to 450)
				if(prob(5))
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
					bladder += 15
			if(250 to 400)
				if(prob(5))
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
/mob/living/carbon/human/proc/handle_shit()
	var/message = null
	if (src.bowels >= 30)

		//Poo in the loo.
		var/obj/structure/toilet/T = locate() in src.loc
		var/obj/machinery/disposal/toilet/T2 = locate() in src.loc
		var/mob/living/M = locate() in src.loc
		if(T && T.open)
			message = "<B>[src]</B> defecates into \the [T]."

		else if (T2 && T2.open)
			message = "<B>[src]</B> defecates into \the [T2]."
			var/obj/item/weapon/reagent_containers/food/snacks/poo/V = new/obj/item/weapon/reagent_containers/food/snacks/poo(src.loc)
			if(reagents)
				reagents.trans_to(V, rand(1,5))

			if(T2.CanInsertItem(src)) //attempt to insert the shit into the toilet.
				V.forceMove(T2)
			else
				shit_left++

		else if(w_uniform)
			message = "<B>[src]</B> shits \his pants."
			reagents.add_reagent("poo", 10)
			adjust_hygiene(-25)
			add_event("shitself", /datum/happiness_event/hygiene/shit)

		//Poo on the face.
		else if(M != src && M.lying)//Can only shit on them if they're lying down.
			message = "<span class='danger'><b>[src]</b> shits right on <b>[M]</b>'s face!</span>"
			M.reagents.add_reagent("poo", 10)

		//Poo on the floor.
		else
			message = "<B>[src]</B> [pick("shits", "craps", "poops")]."
			var/obj/item/weapon/reagent_containers/food/snacks/poo/V = new/obj/item/weapon/reagent_containers/food/snacks/poo(src.loc)
			if(reagents)
				reagents.trans_to(V, rand(1,5))

			shit_left++//Global var for round end, not how much piss is left.

		playsound(src.loc, 'sound/effects/poo2.ogg', 60, 1)
		bowels -= rand(60,80)

	else
		to_chat(src, "You don't have to.")
		return

	visible_message("[message]")

//Peeing
/mob/living/carbon/human/proc/handle_piss()
	var/message = null
	if (bladder < 30)
		to_chat(src, "You don't have to.")
		return

	var/obj/structure/urinal/U = locate() in src.loc
	var/obj/machinery/disposal/toilet/T = locate() in src.loc
	var/obj/machinery/disposal/toilet/T2 = locate() in src.loc
	var/obj/structure/sink/S = locate() in src.loc
	var/obj/item/weapon/reagent_containers/RC = locate() in src.loc
	if((U || S) && gender != FEMALE)//In the urinal or sink.
		message = "<B>[src]</B> urinates into [U ? U : S]."
		reagents.remove_any(rand(1,8))

	else if( (T && T.open) || (T2 && T2.open) )//In the toilet.
		message = "<B>[src]</B> urinates into [T]."
		reagents.remove_any(rand(1,8))

	else if(RC && (istype(RC,/obj/item/weapon/reagent_containers/food/drinks || istype(RC,/obj/item/weapon/reagent_containers/glass))))
		if(RC.is_open_container())
			//Inside a beaker, glass, drink, etc.
			message = "<B>[src]</B> urinates into [RC]."
			var/amount = rand(1,8)
			RC.reagents.add_reagent("urine", amount)
			if(reagents)
				reagents.trans_to(RC, amount)

	else if(w_uniform)//In your pants.
		message = "<B>[src]</B> pisses \his pants."
		adjust_hygiene(-25)
		add_event("pissedself", /datum/happiness_event/hygiene/pee)

	else//On the floor.
		var/turf/TT = src.loc
		var/obj/effect/decal/cleanable/urine/D = new/obj/effect/decal/cleanable/urine(src.loc)
		if(reagents)
			reagents.trans_to(D, rand(1,8))
		message = "<B>[src]</B> pisses on the [TT.name]."
		piss_left++//Global var for round end, not how much piss is left.

	bladder -= 50
	visible_message("[message]")

