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
	density = FALSE
	anchored = TRUE
	layer = 2
	icon = 'icons/effects/pooeffect.dmi'
	icon_state = "floor1"
	random_icon_states = list("floor1", "floor2", "floor3", "floor4", "floor5", "floor6", "floor7", "floor8")
	var/dried = 0
	decay_timer = 18000

/obj/effect/decal/cleanable/poo/New()
	..()
	icon = 'icons/effects/pooeffect.dmi'
	icon_state = pick(src.random_icon_states)
	for(var/obj/effect/decal/cleanable/poo/shit in src.loc)
		if(shit != src)
			qdel(shit)
	spawn(6000)
		dried = 1
		name = "dried poo stain"
		desc = "It's a dried poo stain..."

/obj/effect/decal/cleanable/poo/Destroy()
	..()

/obj/effect/decal/cleanable/poo/tracks
	icon_state = "tracks"
	random_icon_states = null

/obj/effect/decal/cleanable/poo/drip
	name = "drips of poo"
	desc = "It's brown."
	density = FALSE
	anchored = TRUE
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
	density = FALSE
	anchored = TRUE
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
		desc = "That's a dried crusty urine stain."

/obj/effect/decal/cleanable/urine/Destroy()
	..()

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
		if (!restoring) // a load keeps the saved look
			icon_state = pick("poop1", "poop2", "poop3", "poop4", "poop5", "poop6", "poop7")
		reagents.add_reagent("poo", 10)
		biteamount = 3

/obj/item/weapon/reagent_containers/food/snacks/poo/animal
	name = "manure"
	desc = "Makes good fertilizer at least."
	decay = 0 // Not food spoilage; only exposed manure ages.
	abandonment_decay = TRUE
	dry_size = 6
	dried_type = /obj/item/stack/dung
	fertilizer_value = 10
	var/manure_ground_age = 0
	var/tmp/manure_ground_since = null
	New()
		..()
		if (!restoring) // a load keeps the saved look
			icon_state = pick("animal1", "animal2", "animal3")

#define MANURE_GROUND_LIFETIME (4 * 60 * 60 * 10)

/obj/item/weapon/reagent_containers/food/snacks/poo/animal/on_runtime_spawn()
	..()
	update_manure_ground_age(world.time)

/obj/item/weapon/reagent_containers/food/snacks/poo/animal/proc/update_manure_ground_age(now)
	if (restoring)
		return
	if (!isturf(loc))
		// A raw loc assignment may have bypassed movement. Do not guess how
		// much of the unobserved interval was spent outside storage.
		manure_ground_since = null
		return
	if (!isnull(manure_ground_since) && now >= manure_ground_since)
		manure_ground_age = min(MANURE_GROUND_LIFETIME, manure_ground_age + now - manure_ground_since)
	manure_ground_since = now

// Account for the old position first. Resetting/restarting the ordinary debris
// clock on movement must not erase the manure's cumulative ground time.
/obj/item/weapon/reagent_containers/food/snacks/poo/animal/Move()
	update_manure_ground_age(world.time)
	. = ..()
	if (. && !QDELETED(src))
		update_manure_ground_age(world.time)

/obj/item/weapon/reagent_containers/food/snacks/poo/animal/forceMove(atom/destination, special_event, list/throw_hop_token)
	update_manure_ground_age(world.time)
	. = ..()
	if (. && !QDELETED(src))
		update_manure_ground_age(world.time)

// Native bag insertion/removal bypasses Move and forceMove.
/obj/item/weapon/reagent_containers/food/snacks/poo/animal/persistence_set_loc(atom/destination)
	update_manure_ground_age(world.time)
	. = ..()
	if (. && !QDELETED(src))
		update_manure_ground_age(world.time)

/obj/item/weapon/reagent_containers/food/snacks/poo/animal/check_abandonment(now)
	if (QDELETED(src) || !is_abandonment_waste())
		unregister_abandoned_item()
		return FALSE
	update_manure_ground_age(now)
	if (restoring || !isturf(loc) || manure_ground_age < MANURE_GROUND_LIFETIME || abandonment_protected())
		return FALSE
	if (persistence_save_active())
		return FALSE // A moving save may be capturing this pile across a yield.
	qdel(src)
	return TRUE

/obj/item/weapon/reagent_containers/food/snacks/poo/animal/before_save()
	..()
	// Only fold in elapsed time. The scheduler, not the serializer, disposes it.
	update_manure_ground_age(world.time)

/obj/item/weapon/reagent_containers/food/snacks/poo/animal/persistence_runtime_var(key)
	return key == "manure_ground_since" || ..()

/obj/item/weapon/reagent_containers/food/snacks/poo/animal/persistence_import_fields(list/saved_fields)
	..()
	if (!("manure_ground_age" in saved_fields) || !isnum(manure_ground_age))
		manure_ground_age = 0
	else
		manure_ground_age = clamp(manure_ground_age, 0, MANURE_GROUND_LIFETIME)
	manure_ground_since = null

/obj/item/weapon/reagent_containers/food/snacks/poo/animal/persistence_restore_finished()
	..()
	update_manure_ground_age(world.time)

#undef MANURE_GROUND_LIFETIME

/obj/item/weapon/reagent_containers/food/snacks/poo/fertilizer
	name = "compost"
	desc = "Natural fertilizer for your plants."
	decay = 0 // fertilizer keeps until it is used
	dry_size = 6
	dried_type = /obj/item/stack/dung
	fertilizer_value = 60
	New()
		..()
		if (!restoring) // a load keeps the saved look
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

	// Clutching your groin keeps it in for now, at a cost.
	if(holding_it_in)
		adjust_mood(-0.5, "holding it in")
		return
	if((bowels >= 450 || bladder >= 400) && client && world.time >= next_hold_it_in_hint)
		next_hold_it_in_hint = world.time + 10 MINUTES
		to_chat(src, SPAN_NOTICE("Grab your groin with both hands free to hold it in."))

	if(bowels >= 250)
		switch(bowels)
			if(250 to 400)
				if(prob(5))
					to_chat(src, "<b>You need to use the bathroom.</b>")
					bowels += 10
			if(400 to 450)
				if(prob(7))
					to_chat(src, SPAN_DANGER("You really need to use the restroom!"))
					bowels += 15
			if(450 to 500)
				if(prob(2))
					handle_shit()
				else if(prob(10))
					to_chat(src, SPAN_DANGER("You're about to shit yourself!"))
					bowels += 25
			if(500 to 550)
				if(prob(15))
					handle_shit()
				else if(prob(30))
					to_chat(src, SPAN_DANGER("OH MY GOD YOU HAVE TO SHIT!"))
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
					to_chat(src, SPAN_DANGER("You really need to use the restroom!"))
					bladder += 15
			if(400 to 500)
				if(prob(2))
					handle_piss()
				else if(prob(10))
					to_chat(src, SPAN_DANGER("You're about to piss yourself!"))
					bladder += 25
			if(500 to 550)
				if(prob(15))
					handle_piss()
				else if(prob(30))
					to_chat(src, SPAN_DANGER("OH MY GOD YOU HAVE TO PEE!"))
					bladder += 35
			if(550 to INFINITY)
				handle_piss()

// Holding it in: grab intent on your own groin with both hands empty, once the
// bladder or bowels are about to give out. It holds off an accident for a short
// while; you waddle, it wears on your mood, and both hands stay busy. The hold
// ends when you let go (grab again), a hand fills, you pass out, the urge passes
// or time runs out. Running out strains you and makes the urge worse.
#define HOLD_IT_IN_TIME (40 SECONDS)
#define HOLD_IT_IN_COOLDOWN (20 SECONDS)
#define HOLD_IT_IN_STRAIN 40

/mob/living/human
	var/tmp/holding_it_in = 0			// world.time the hold gives out, or 0
	var/tmp/next_hold_it_in = 0			// world.time the next hold may start
	var/tmp/next_hold_it_in_hint = 0	// world.time the hint may show again

/mob/living/human/persistence_runtime_var(key)
	if (key == "holding_it_in" || key == "next_hold_it_in" || key == "next_hold_it_in_hint")
		return TRUE
	return ..()

/mob/living/human/proc/excrement_urgent()
	return bladder >= 400 || bowels >= 450

/mob/living/human/proc/hold_it_in_blocker()
	if (stat || paralysis || sleeping)
		return "You can't do that right now."
	if (!excrement_urgent())
		return "You can still hold it without that."
	if (!self_hand_free("l_hand") || !self_hand_free("r_hand"))
		return "You need both hands free to hold it in."
	if (world.time < next_hold_it_in)
		return "You can't clench again just yet."
	return null

// Grab intent on yourself aimed at the groin. A bleeding groin is pressed on
// first; otherwise it starts or ends holding it in. FALSE means not handled.
/mob/living/human/proc/try_hold_it_in()
	if (holding_it_in)
		release_hold_it_in(SPAN_NOTICE("You let go and try to relax."))
		return TRUE
	var/blocker = hold_it_in_blocker()
	if (blocker)
		to_chat(src, SPAN_WARNING(blocker))
		return FALSE
	holding_it_in = world.time + HOLD_IT_IN_TIME
	next_calculate_tally = -1
	var/their = gender == FEMALE ? "her" : gender == MALE ? "his" : "their"
	visible_message(SPAN_NOTICE("[src] clutches [their] groin and squirms."), \
					SPAN_NOTICE("You clutch your groin and clench. You can't hold it for long."))
	addtimer(CALLBACK(src, PROC_REF(check_hold_it_in)), 10)
	return TRUE

/mob/living/human/proc/check_hold_it_in()
	if (QDELETED(src) || !holding_it_in)
		return
	if (!excrement_urgent())
		release_hold_it_in(SPAN_NOTICE("The urge eases off."), FALSE)
		return
	if (stat || paralysis || sleeping || !self_hand_free("l_hand") || !self_hand_free("r_hand"))
		release_hold_it_in(SPAN_WARNING("You lose your grip on yourself."))
		return
	if (world.time >= holding_it_in)
		if (bladder >= 400)
			bladder += HOLD_IT_IN_STRAIN
		if (bowels >= 450)
			bowels += HOLD_IT_IN_STRAIN
		release_hold_it_in(SPAN_DANGER("You can't hold it any longer!"))
		return
	addtimer(CALLBACK(src, PROC_REF(check_hold_it_in)), 10)

/mob/living/human/proc/release_hold_it_in(message, cooldown = TRUE)
	holding_it_in = 0
	next_calculate_tally = -1
	if (cooldown)
		next_hold_it_in = world.time + HOLD_IT_IN_COOLDOWN
	if (message)
		to_chat(src, message)

/mob/living/human/proc/hold_it_in_slowdown()
	return holding_it_in ? 2 : 0

#undef HOLD_IT_IN_TIME
#undef HOLD_IT_IN_COOLDOWN
#undef HOLD_IT_IN_STRAIN

//Shitting
/mob/living/human/proc/handle_shit()
	var/message = null
	if (src.bowels < 30 && stat != DEAD)
		to_chat(src, "You don't have to shit.")
		return

	//Poo in the loo.
	var/obj/structure/toilet/T = locate() in src.loc
	var/mob/living/M = excrement_target_mob()
	var/in_outhouse = istype(loc, /obj/structure/toilet/outhouse)
	if ((T && T.open) || in_outhouse)
		if (in_outhouse)
			message = "<B>[src]</B> defecates into the hole."
		else
			message = "<B>[src]</B> defecates into \the [T]."
		var/obj/item/weapon/reagent_containers/food/snacks/poo/V = new/obj/item/weapon/reagent_containers/food/snacks/poo(src.loc)
		if(reagents)
			reagents.trans_to(V, rand(1,5))
		if (!in_outhouse && T.is_plumbed())
			T.flush_waste(V) // Flushed down the drain (sewers.dm), so it cannot be fished back out of the cistern.
		else
			var/obj/structure/toilet/pit = in_outhouse ? loc : T
			pit.take_night_soil(V) // Kept in the pit until it is dug out (latrine_waste.dm).

	else if(w_uniform)
		message = "<B>[src]</B> shits \his pants."
		reagents.add_reagent("poo", 10)
		adjust_hygiene(-25)
		adjust_mood(-(25), "soiling yourself")
		w_uniform.shit_overlay = image(icon = 'icons/mob/human_races/masks/sickness.dmi', icon_state="shit")
		w_uniform.overlays += w_uniform.shit_overlay
		w_uniform.update_icon()
		update_icons()

	//Poo on the face.
	else if(M && M.lying) //Can only shit on them if they're lying down.
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
	visible_message("<span class='warning'>[message]</span>")

// Another living mob on this tile, or null. The outhouse is checked by loc,
// not crap_inside: that flag is only set for mobs with a client and can stay
// TRUE after a logout or restart, which sent every later poo into nullspace.
/mob/living/human/proc/excrement_target_mob()
	for (var/mob/living/L in loc)
		if (L != src)
			return L
	return null

//Peeing
/mob/living/human/proc/handle_piss()
	var/message = null
	if (bladder < 30 && stat != DEAD)
		to_chat(src, "You don't have to piss.")
		return

	var/in_outhouse = istype(loc, /obj/structure/toilet/outhouse)
	var/obj/structure/toilet/T = locate() in src.loc
	var/obj/structure/sink/S = locate() in src.loc
	var/obj/item/weapon/reagent_containers/RC = locate() in src.loc

	if((S) && gender != FEMALE)//In the urinal or sink.
		message = "<B>[src]</B> urinates into \the [S]."
		reagents.remove_any(rand(5,10))

	else if(T && T.open)//In the toilet.
		message = "<B>[src]</B> urinates into \the [T]."
		reagents.remove_any(rand(5,10))
		if (T.keeps_waste())
			T.take_urine(rand(5,10))

	else if (in_outhouse) //Into the hole inside the outhouse.
		message = "<B>[src]</B> urinates into the hole."
		reagents.remove_any(rand(5,10))
		var/obj/structure/toilet/outhouse/O = loc
		O.take_urine(rand(5,10))

	else if(RC && (istype(RC, /obj/item/weapon/reagent_containers/food/drinks) || istype(RC, /obj/item/weapon/reagent_containers/glass)) && RC.is_open_container())
		//Inside a beaker, glass, drink, etc.
		message = "<B>[src]</B> urinates into \the [RC]."
		var/amount = rand(5,10)
		RC.reagents.add_reagent("urine", amount)
		if(reagents)
			reagents.trans_to(RC, amount)

	else if(w_uniform)//In your pants.
		message = "<B>[src]</B> pisses \his pants."
		adjust_hygiene(-25)
		adjust_mood(-(15), "soiling yourself")
		w_uniform.piss_overlay = image(icon = 'icons/mob/human_races/masks/sickness.dmi', icon_state="piss")
		w_uniform.overlays += w_uniform.piss_overlay
		w_uniform.update_icon()
		update_icons()

	else//On the floor.
		var/turf/TT = src.loc
		var/obj/effect/decal/cleanable/urine/D = new/obj/effect/decal/cleanable/urine(src.loc)
		if(reagents)
			reagents.trans_to(D, rand(5,10))
		message = "<B>[src]</B> pisses on \the [TT.name]."

	bladder -= rand(100,130)
	visible_message("<span class='warning'>[message]</span>")
