//mob verbs are faster than object verbs. See mob/verb/examine.
/mob/living/verb/pulled(atom/movable/AM as mob|obj in oview(1))
	set name = "Pull"
	set category = null

	if (AM.Adjacent(src))
		start_pulling(AM)

//mob verbs are faster than object verbs. See above.
/mob/living/pointed(atom/A as mob|obj|turf in view())
	if (stat || !canmove || restrained())
		return FALSE
	if (status_flags & FAKEDEATH)
		return FALSE
	if (!..())
		return FALSE

	usr.visible_message("<b>[src]</b> points to [A]")
	return TRUE

/*one proc, four uses
swapping: if it's TRUE, the mobs are trying to switch, if FALSE, non-passive is pushing passive
default behaviour is:
 - non-passive mob passes the passive version
 - passive mob checks to see if its mob_bump_flag is in the non-passive's mob_bump_flags
 - if si, the proc returns
*/
/mob/living/proc/can_move_mob(var/mob/living/swapped, swapping = FALSE, passive = FALSE)
	if (!swapped)
		return TRUE
	if (!passive)
		return swapped.can_move_mob(src, swapping, TRUE)
	else
		var/context_flags = FALSE
		if (swapping)
			context_flags = swapped.mob_swap_flags
		else
			context_flags = swapped.mob_push_flags
		if (!mob_bump_flag) //nothing defined, go wild
			return TRUE
		if (mob_bump_flag & context_flags)
			return TRUE
		return FALSE

/mob/living/Bump(atom/movable/AM, yes)

	// no more pushing people past prishtina blocks - Kachnov
	if (istype(AM, /obj/structure/closet))
		for (var/mob/living/carbon/human/H in AM)
			if (map.check_prishtina_block(H, get_step(get_turf(AM), dir)))
				return

	else if (ishuman(AM))
		if (map.check_prishtina_block(AM, get_step(get_turf(AM), dir)))
			return

	spawn(0)
		if ((!( yes ) || now_pushing) || !loc)
			return
		now_pushing = TRUE
		if (istype(AM, /mob/living))
			var/mob/living/tmob = AM

			for (var/mob/living/M in range(tmob, TRUE))
				if (tmob.pinned.len ||  ((M.pulling == tmob && ( tmob.restrained() && !( M.restrained() ) && M.stat == FALSE)) || locate(/obj/item/weapon/grab, tmob.grabbed_by.len)) )
					if ( !(world.time % 5) )
						src << "<span class='warning'>[tmob] is restrained, you cannot push past</span>"
					now_pushing = FALSE
					return
				if ( tmob.pulling == M && ( M.restrained() && !( tmob.restrained() ) && tmob.stat == FALSE) )
					if ( !(world.time % 5) )
						src << "<span class='warning'>[tmob] is restraining [M], you cannot push past</span>"
					now_pushing = FALSE
					return

			//Leaping mobs just land on the tile, no pushing, no anything.
			if (status_flags & LEAPING)
				loc = tmob.loc
				status_flags &= ~LEAPING
				now_pushing = FALSE
				return

			if (can_swap_with(tmob)) // mutual brohugs all around!
				var/turf/oldloc = loc
				forceMove(tmob.loc)
				tmob.forceMove(oldloc)
				now_pushing = FALSE
				/*
				for (var/mob/living/carbon/slime/slime in view(1,tmob))
					if (slime.Victim == tmob)
						slime.UpdateFeed()*/
				return

			if (!can_move_mob(tmob, FALSE, FALSE))
				now_pushing = FALSE
				return
			if (a_intent == I_HELP || restrained())
				now_pushing = FALSE
				return
			if (istype(tmob, /mob/living/carbon/human) && (FAT in tmob.mutations))
				if (prob(40) && !(FAT in mutations))
					src << "<span class='danger'>You fail to push [tmob]'s fat ass out of the way.</span>"
					now_pushing = FALSE
					return
			/*if (tmob.r_hand && istype(tmob.r_hand, /obj/item/weapon/shield/riot))
				if (prob(99))
					now_pushing = FALSE
					return
			if (tmob.l_hand && istype(tmob.l_hand, /obj/item/weapon/shield/riot))
				if (prob(99))
					now_pushing = FALSE
					return*/
			if (!(tmob.status_flags & CANPUSH))
				now_pushing = FALSE
				return

			tmob.LAssailant = src

		now_pushing = FALSE
		spawn(0)
			..()
			if (!istype(AM, /atom/movable))
				return
			if (!now_pushing)
				now_pushing = TRUE

				if (!AM.anchored)
					var/t = get_dir(src, AM)
					if (istype(AM, /obj/structure/window))
						for (var/obj/structure/window/win in get_step(AM,t))
							now_pushing = FALSE
							return
					step(AM, t)
					if (ishuman(AM) && AM:grabbed_by)
						for (var/obj/item/weapon/grab/G in AM:grabbed_by)
							step(G:assailant, get_dir(G:assailant, AM))
							G.adjust_position()
				now_pushing = FALSE
			return
	return

/proc/swap_density_check(var/mob/swapper, var/mob/swapee)
	var/turf/T = get_turf(swapper)
	if (T.density)
		return TRUE
	for (var/atom/movable/A in T)
		if (A == swapper)
			continue
		if (!A.CanPass(swapee, T, TRUE))
			return TRUE

/mob/living/proc/can_swap_with(var/mob/living/tmob)
	if (tmob.buckled || buckled)
		return FALSE
	//BubbleWrap: people in handcuffs are always switched around as if they were on 'help' intent to prevent a person being pulled from being seperated from their puller
	if (!(tmob.mob_always_swap || (tmob.a_intent == I_HELP || tmob.restrained()) && (a_intent == I_HELP || restrained())))
		return FALSE
	if (!tmob.canmove || !canmove)
		return FALSE

	if (swap_density_check(src, tmob))
		return FALSE

	if (swap_density_check(tmob, src))
		return FALSE

	return can_move_mob(tmob, TRUE, FALSE)

/mob/living/verb/succumb()
	set hidden = TRUE
	if ((health < 0 && health > (5-maxHealth))) // Health below Zero but above 5-away-from-death, as before, but variable
		adjustOxyLoss(health + maxHealth * 2) // Deal 2x health in OxyLoss damage, as before but variable.
		health = maxHealth - getOxyLoss() - getToxLoss() - getFireLoss() - getBruteLoss()
		src << "<span class = 'notice'>You have given up life and succumbed to death.</span>"


//This proc is used for mobs which are affected by pressure to calculate the amount of pressure that actually
//affects them once clothing is factored in. ~Errorage
/mob/living/proc/calculate_affecting_pressure(var/pressure)
	return


//sort of a legacy burn method for /electrocute, /shock, and the e_chair
/mob/living/proc/burn_skin(burn_amount)
	if (istype(src, /mob/living/carbon/human))
		//world << "DEBUG: burn_skin(), mutations=[mutations]"
		if (mShock in mutations) //shockproof
			return FALSE
		if (COLD_RESISTANCE in mutations) //fireproof
			return FALSE
		var/mob/living/carbon/human/H = src	//make this damage method divide the damage to be done among all the body parts, then burn each body part for that much damage. will have better effect then just randomly picking a body part
		var/divided_damage = (burn_amount)/(H.organs.len)
		var/extradam = FALSE	//added to when organ is at max dam
		for (var/obj/item/organ/external/affecting in H.organs)
			if (!affecting)	continue
			if (affecting.take_damage(0, divided_damage+extradam))	//TODO: fix the extradam stuff. Or, ebtter yet...rewrite this entire proc ~Carn
				H.UpdateDamageIcon()
		H.updatehealth()
		return TRUE

/mob/living/proc/adjustBodyTemp(actual, desired, incrementboost)
	var/temperature = actual
	var/difference = abs(actual-desired)	//get difference
	var/increments = difference/10 //find how many increments apart they are
	var/change = increments*incrementboost	// Get the amount to change by (x per increment)

	// Too cold
	if (actual < desired)
		temperature += change
		if (actual > desired)
			temperature = desired
	// Too hot
	if (actual > desired)
		temperature -= change
		if (actual < desired)
			temperature = desired
//	if (istype(src, /mob/living/carbon/human))
//		world << "[src] ~ [bodytemperature] ~ [temperature]"
	return temperature


// ++++ROCKDTBEN++++ MOB PROCS -- Ask me before touching.
// Stop! ... Hammertime! ~Carn
// I touched them without asking... I'm soooo edgy ~Erro (added nodamage checks)

/mob/living/proc/getBruteLoss()
	return bruteloss

/mob/living/proc/adjustBruteLoss(var/amount)
	if (status_flags & GODMODE)	return FALSE	//godmode
	if (ishuman(src))
		var/mob/living/carbon/human/H = src
		if (H.takes_less_damage)
			amount /= H.getStatCoeff("strength")
	bruteloss = min(max(bruteloss + amount, FALSE),(maxHealth*2))
	return TRUE

/mob/living/proc/getOxyLoss()
	return oxyloss

/mob/living/proc/adjustOxyLoss(var/amount)
	if (status_flags & GODMODE)	return FALSE	//godmode
	if (ishuman(src))
		var/mob/living/carbon/human/H = src
		if (H.takes_less_damage)
			amount /= H.getStatCoeff("strength")
	oxyloss = min(max(oxyloss + amount, FALSE),(maxHealth*2))

/mob/living/proc/setOxyLoss(var/amount)
	if (status_flags & GODMODE)	return FALSE	//godmode
	if (ishuman(src))
		var/mob/living/carbon/human/H = src
		if (H.takes_less_damage)
			amount /= H.getStatCoeff("strength")
	oxyloss = amount

/mob/living/proc/getToxLoss()
	return toxloss

/mob/living/proc/adjustToxLoss(var/amount)
	if (status_flags & GODMODE)	return FALSE	//godmode
	if (ishuman(src))
		var/mob/living/carbon/human/H = src
		if (H.takes_less_damage)
			amount /= H.getStatCoeff("strength")
	toxloss = min(max(toxloss + amount, FALSE),(maxHealth*2))

/mob/living/proc/setToxLoss(var/amount)
	if (status_flags & GODMODE)	return FALSE	//godmode
	if (ishuman(src))
		var/mob/living/carbon/human/H = src
		if (H.takes_less_damage)
			amount /= H.getStatCoeff("strength")
	toxloss = amount

/mob/living/proc/getFireLoss()
	return fireloss

/mob/living/proc/adjustFireLoss(var/amount)
	if (status_flags & GODMODE)	return FALSE	//godmode
	if (ishuman(src))
		var/mob/living/carbon/human/H = src
		if (H.takes_less_damage)
			amount /= H.getStatCoeff("strength")
	fireloss = min(max(fireloss + amount, FALSE),(maxHealth*2))

/mob/living/proc/getCloneLoss()
	return cloneloss

/mob/living/proc/adjustCloneLoss(var/amount)
	if (status_flags & GODMODE)	return FALSE	//godmode
	if (ishuman(src))
		var/mob/living/carbon/human/H = src
		if (H.takes_less_damage)
			amount /= H.getStatCoeff("strength")
	cloneloss = min(max(cloneloss + amount, FALSE),(maxHealth*2))

/mob/living/proc/setCloneLoss(var/amount)
	if (status_flags & GODMODE)	return FALSE	//godmode
	cloneloss = amount

/mob/living/proc/getBrainLoss()
	return brainloss

/mob/living/proc/adjustBrainLoss(var/amount)
	if (status_flags & GODMODE)	return FALSE	//godmode
	brainloss = min(max(brainloss + amount, FALSE),(maxHealth*2))

/mob/living/proc/setBrainLoss(var/amount)
	if (status_flags & GODMODE)	return FALSE	//godmode
	brainloss = amount

/mob/living/proc/getHalLoss()
	return halloss

/mob/living/proc/adjustHalLoss(var/amount)
	if (status_flags & GODMODE)	return FALSE	//godmode
	halloss = min(max(halloss + amount, FALSE),(maxHealth*2))

/mob/living/proc/setHalLoss(var/amount)
	if (status_flags & GODMODE)	return FALSE	//godmode
	halloss = amount

/mob/living/proc/getTotalLoss()
	return getBruteLoss() + getOxyLoss() + getToxLoss() + getFireLoss() + getCloneLoss() + getBrainLoss() + getHalLoss()

/mob/living/proc/getMaxHealth()
	return maxHealth

/mob/living/proc/setMaxHealth(var/newMaxHealth)
	maxHealth = newMaxHealth

// ++++ROCKDTBEN++++ MOB PROCS //END

/mob/proc/get_contents()


//Recursive function to find everything a mob is holding.
/mob/living/get_contents(var/obj/item/weapon/storage/Storage = null)
	var/list/L = list()

	if (Storage) //If it called itself
		L += Storage.return_inv()
		return L

	else

		L += contents
		for (var/obj/item/weapon/storage/S in contents)	//Check for storage items
			L += get_contents(S)

		return L

/mob/living/proc/check_contents_for (A)
	var/list/L = get_contents()

	for (var/obj/B in L)
		if (B.type == A)
			return TRUE
	return FALSE


/mob/living/proc/can_inject()
	return TRUE

/mob/living/proc/get_organ_target()
	var/mob/shooter = src
	var/t = shooter:targeted_organ
	if ((t in list( "eyes", "mouth" )))
		t = "head"
	var/obj/item/organ/external/def_zone = ran_zone(t)
	return def_zone


// heal ONE external organ, organ gets randomly selected from damaged ones.
/mob/living/proc/heal_organ_damage(var/brute, var/burn)
	adjustBruteLoss(-brute)
	adjustFireLoss(-burn)
	updatehealth()

// damage ONE external organ, organ gets randomly selected from damaged ones.
/mob/living/proc/take_organ_damage(var/brute, var/burn, var/emp=0)
	if (status_flags & GODMODE)	return FALSE	//godmode
	adjustBruteLoss(brute)
	adjustFireLoss(burn)
	updatehealth()

// heal MANY external organs, in random order
/mob/living/proc/heal_overall_damage(var/brute, var/burn)
	adjustBruteLoss(-brute)
	adjustFireLoss(-burn)
	updatehealth()

// damage MANY external organs, in random order
/mob/living/proc/take_overall_damage(var/brute, var/burn, var/used_weapon = null)
	if (status_flags & GODMODE)	return FALSE	//godmode
	adjustBruteLoss(brute)
	adjustFireLoss(burn)
	updatehealth()

/mob/living/proc/restore_all_organs()
	return



/mob/living/proc/revive()
	rejuvenate()
	if (buckled)
		buckled.unbuckle_mob()
	if (iscarbon(src))
		var/mob/living/carbon/C = src

		if (C.handcuffed && !initial(C.handcuffed))
			C.drop_from_inventory(C.handcuffed)
		C.handcuffed = initial(C.handcuffed)

		if (C.legcuffed && !initial(C.legcuffed))
			C.drop_from_inventory(C.legcuffed)
		C.legcuffed = initial(C.legcuffed)
	ExtinguishMob()
	fire_stacks = 0

/mob/living/proc/rejuvenate()
	reagents.clear_reagents()

	// shut down various types of badness
	setToxLoss(0)
	setOxyLoss(0)
	setCloneLoss(0)
	setBrainLoss(0)
	SetParalysis(0)
	SetStunned(0)
	SetWeakened(0)

	// shut down ongoing problems
	radiation = FALSE
	bodytemperature = T20C
	sdisabilities = FALSE
	disabilities = FALSE

	// fix blindness and deafness
	blinded = FALSE
	eye_blind = FALSE
	eye_blurry = FALSE
	ear_deaf = FALSE
	ear_damage = FALSE
	heal_overall_damage(getBruteLoss(), getFireLoss())

	// fix all of our organs
	restore_all_organs()

	// remove the character from the list of the dead
	if (stat == DEAD)
		dead_mob_list -= src
		living_mob_list += src
		tod = null
		timeofdeath = FALSE

	// restore us to conciousness
	stat = CONSCIOUS

	// make the icons look correct
	regenerate_icons()

	failed_last_breath = FALSE //So mobs that died of oxyloss don't revive and have perpetual out of breath.

	return

/mob/living/proc/UpdateDamageIcon()
	return

/mob/living/Move(a, b, flag)
	if (buckled)
		return

	if (restrained())
		stop_pulling()


	var/t7 = TRUE
	if (restrained())
		for (var/mob/living/M in range(src, TRUE))
			if ((M.pulling == src && M.stat == FALSE && !( M.restrained() )))
				t7 = null
	if ((t7 && (pulling && ((get_dist(src, pulling) <= 1 || pulling.loc == loc) && (client && client.moving)))))
		var/turf/T = loc
		. = ..()

		if (pulling && pulling.loc)
			if (!( isturf(pulling.loc) ))
				stop_pulling()
				return

		/////
		if (pulling && pulling.anchored)
			stop_pulling()
			return

		if (!restrained())
			var/diag = get_dir(src, pulling)
			if ((diag - 1) & diag)
			else
				diag = null
			if ((get_dist(src, pulling) > 1 || diag))
				if (isliving(pulling))
					var/mob/living/M = pulling
					var/ok = TRUE
					if (locate(/obj/item/weapon/grab, M.grabbed_by))
						if (prob(75))
							var/obj/item/weapon/grab/G = pick(M.grabbed_by)
							if (istype(G, /obj/item/weapon/grab))
								for (var/mob/O in viewers(M, null))
									O.show_message(text("<span class = 'red'>[] has been pulled from []'s grip by [].</span>", G.affecting, G.assailant, src), TRUE)
								//G = null
								qdel(G)
						else
							ok = FALSE
						if (locate(/obj/item/weapon/grab, M.grabbed_by.len))
							ok = FALSE
					if (ok)
						var/atom/movable/t = M.pulling
						M.stop_pulling()

						if (!istype(M.loc, /turf/space))
							var/area/A = get_area(M)
							if (A.has_gravity)
								//this is the gay blood on floor shit -- Added back -- Skie
								if (M.lying && (prob(M.getBruteLoss() / 6)))
									var/turf/location = M.loc
									if (istype(location, /turf))
										location.add_blood(M)
								//pull damage with injured people
								/*	if (prob(25))
										M.adjustBruteLoss(1)
										visible_message("<span class='danger'>\The [M]'s [M.isSynthetic() ? "state worsens": "wounds open more"] from being dragged!</span>")
								if (M.pull_damage())
									if (prob(25))
										M.adjustBruteLoss(2)
										visible_message("<span class='danger'>\The [M]'s [M.isSynthetic() ? "state" : "wounds"] worsen terribly from being dragged!</span>")
										var/turf/location = M.loc
										if (istype(location, /turf))
											location.add_blood(M)
											if (ishuman(M))
												var/mob/living/carbon/human/H = M
												var/blood_volume = round(H.vessel.get_reagent_amount("blood"))
												if (blood_volume > 0)
													H.vessel.remove_reagent("blood", TRUE)
										*/

						step(pulling, get_dir(pulling.loc, T))
						if (t)
							M.start_pulling(t)
				else
					if (pulling)
						if (istype(pulling, /obj/structure/window))
							var/obj/structure/window/W = pulling
							if (W.is_full_window())
								for (var/obj/structure/window/win in get_step(pulling,get_dir(pulling.loc, T)))
									stop_pulling()
					if (pulling)
						step(pulling, get_dir(pulling.loc, T))
	else
		stop_pulling()
		. = ..()

	if (s_active && !( s_active in contents ) && get_turf(s_active) != get_turf(src))	//check !( s_active in contents ) first so we hopefully don't have to call get_turf() so much.
		s_active.close(src)
/*
	if (update_slimes)
		for (var/mob/living/carbon/slime/M in view(1,src))
			M.UpdateFeed(src)*/

	for (var/mob/M in oview(src))
		M.update_vision_cone()

	update_vision_cone()

/mob/living/verb/resist()
	set name = "Resist"
	set category = "IC"

	if (!stat && canClick())
		setClickCooldown(20)
		resist_grab()
		if (!weakened)
			process_resist()

/mob/living/proc/process_resist()
	//Getting out of someone's inventory.
	if (istype(loc, /obj/item/weapon/holder))
		escape_inventory(loc)
		return

	//unbuckling yourself
	if (buckled)
		spawn() escape_buckle()
		return TRUE

	//Breaking out of a locker?
	if ( loc && (istype(loc, /obj/structure/closet)) )
		var/obj/structure/closet/C = loc
		spawn() C.mob_breakout(src)
		return TRUE

/mob/living/proc/escape_inventory(obj/item/weapon/holder/H)
	if (H != loc) return

	var/mob/M = H.loc //Get our mob holder (if any).

	if (istype(M))
		M.drop_from_inventory(H)
		M << "<span class='warning'>\The [H] wriggles out of your grip!</span>"
		src << "<span class='warning'>You wriggle out of \the [M]'s grip!</span>"

		// Update whether or not this mob needs to pass emotes to contents.
		for (var/atom/A in M.contents)
			if (istype(A,/obj/item/weapon/holder))
				return
		M.status_flags &= ~PASSEMOTES

	else if (istype(H.loc,/obj/item/clothing/accessory/holster))
		var/obj/item/clothing/accessory/holster/holster = H.loc
		if (holster.holstered == H)
			holster.clear_holster()
		src << "<span class='warning'>You extricate yourself from \the [holster].</span>"
		H.forceMove(get_turf(H))
	else if (istype(H.loc,/obj/item))
		src << "<span class='warning'>You struggle free of \the [H.loc].</span>"
		H.forceMove(get_turf(H))

/mob/living/proc/escape_buckle()
	if (buckled)
		buckled.user_unbuckle_mob(src)

/mob/living/proc/resist_grab()
	var/resisting = FALSE
	for (var/obj/O in requests)
		requests.Remove(O)
		qdel(O)
		resisting++
	for (var/obj/item/weapon/grab/G in grabbed_by)
		resisting++
		switch(G.state)
			if (GRAB_PASSIVE)
				qdel(G)
			if (GRAB_AGGRESSIVE)
				if (prob(60)) //same chance of breaking the grab as disarm
					visible_message("<span class='warning'>[src] has broken free of [G.assailant]'s grip!</span>")
					qdel(G)
			if (GRAB_NECK)
				//If the you move when grabbing someone then it's easier for them to break free. Same if the affected mob is immune to stun.
				if (((world.time - G.assailant.l_move_time < 30 || !stunned) && prob(15)) || prob(3))
					visible_message("<span class='warning'>[src] has broken free of [G.assailant]'s headlock!</span>")
					qdel(G)
	if (resisting)
		visible_message("<span class='danger'>[src] resists!</span>")


/mob/living/verb/lay_down()
	set name = "Rest"
	set category = "IC"

	resting = !resting
	src << "<span class='notice'>You are [resting ? "now resting" : "no longer resting"].</span>"

/mob/living/proc/is_allowed_vent_crawl_item(var/obj/item/carried_item)
	return isnull(get_inventory_slot(carried_item))

/mob/living/proc/handle_ventcrawl(var/obj/machinery/atmospherics/unary/vent_pump/vent_found = null, var/ignore_items = FALSE) // -- TLE -- Merged by Carn
	return FALSE

/mob/living/proc/cannot_use_vents()
	return "You can't fit into that vent."

/mob/living/proc/has_brain()
	return TRUE

/mob/living/proc/has_eyes()
	return TRUE

/mob/living/proc/slip(var/slipped_on,stun_duration=8)
	return FALSE

/mob/living/carbon/drop_from_inventory(var/obj/item/W, var/atom/Target = null)
	if (W in internal_organs)
		return
	..()

//damage/heal the mob ears and adjust the deaf amount
/mob/living/adjustEarDamage(var/damage, var/deaf)
	ear_damage = max(0, ear_damage + damage)
	ear_deaf = max(0, ear_deaf + deaf)

//pass a negative argument to skip one of the variable
/mob/living/setEarDamage(var/damage, var/deaf)
	if (damage >= 0)
		ear_damage = damage
	if (deaf >= 0)
		ear_deaf = deaf

/mob/proc/can_be_possessed_by(var/mob/observer/ghost/possessor)
	return istype(possessor) && possessor.client

/mob/living/can_be_possessed_by(var/mob/observer/ghost/possessor)
	if (!..())
		return FALSE
	if (!possession_candidate)
		possessor << "<span class='warning'>That animal cannot be possessed.</span>"
		return FALSE
	/*
	if (jobban_isbanned(possessor, "Animal"))
		possessor << "<span class='warning'>You are banned from animal roles.</span>"
		return FALSE
	*/
	if (!possessor.MayRespawn(1,0))
		return FALSE
	return TRUE

/mob/living/proc/do_possession(var/mob/observer/ghost/possessor)

	if (!(istype(possessor) && possessor.ckey))
		return FALSE

	if (ckey || client)
		possessor << "<span class='warning'>\The [src] already has a player.</span>"
		return FALSE

	message_admins("<span class='adminnotice'>[key_name_admin(possessor)] has taken control of \the [src].</span>")
	log_admin("[key_name(possessor)] took control of \the [src].")
	ckey = possessor.ckey
	qdel(possessor)
/*
	if (round_is_spooky(6)) // Six or more active cultists.
		src << "<span class='notice'>You reach out with tendrils of ectoplasm and invade the mind of \the [src]...</span>"
		src << "<b>You have assumed direct control of \the [src].</b>"
		src << "<span class='notice'>Due to the spookiness of the round, you have taken control of the poor animal as an invading, possessing spirit - roleplay accordingly.</span>"
		universal_speak = TRUE
		universal_understand = TRUE
		//cultify() // Maybe another time.
		return*/

	src << "<b>You are now \the [src]!</b>"
	src << "<span class='notice'>Remember to stay in character for a mob of this type!</span>"
	return TRUE

/mob/living/throw_mode_off()
	in_throw_mode = FALSE
	if (HUDneed.Find("throw"))
		var/obj/screen/HUDthrow/HUD = HUDneed["throw"]
		HUD.update_icon()

/mob/living/throw_mode_on()
	in_throw_mode = TRUE
	if (HUDneed.Find("throw"))
		var/obj/screen/HUDthrow/HUD = HUDneed["throw"]
		HUD.update_icon()

	/*if (var/obj/screen/HUDthrow/HUD in client.screen)
		if (HUD.name == "throw") //in case we don't have the HUD and we use the hotkey
			HUD.toggle_throw_mode()
			break*/

/mob/living/stop_pulling()

	set name = "Stop Pulling"
	set category = "IC"


	if (pulling)
		pulling.pulledby = null
		pulling = null
/*		if (pullin)
			pullin.icon_state = "pull0"*/
		if (HUDneed.Find("pull"))
			var/obj/screen/HUDthrow/HUD = HUDneed["pull"]
			HUD.update_icon()

/mob/living/start_pulling(var/atom/movable/AM)

	if ( !AM || !usr || src==AM || !isturf(loc) )	//if there's no person pulling OR the person is pulling themself OR the object being pulled is inside something: abort!
		return

	if (AM.anchored)
		src << "<span class='warning'>It won't budge!</span>"
		return

	var/mob/M = AM
	if (ismob(AM))

		if (!can_pull_mobs || !can_pull_size)
			src << "<span class='warning'>It won't budge!</span>"
			return

		if ((mob_size < M.mob_size) && (can_pull_mobs != MOB_PULL_LARGER))
			src << "<span class='warning'>It won't budge!</span>"
			return

		if ((mob_size == M.mob_size) && (can_pull_mobs == MOB_PULL_SMALLER))
			src << "<span class='warning'>It won't budge!</span>"
			return

		// If your size is larger than theirs and you have some
		// kind of mob pull value AT ALL, you will be able to pull
		// them, so don't bother checking that explicitly.

		if (!iscarbon(src))
			M.LAssailant = null
		else
			M.LAssailant = usr

	else if (isobj(AM))
		var/obj/I = AM
		if (!can_pull_size || can_pull_size < I.w_class)
			src << "<span class='warning'>It won't budge!</span>"
			return

	if (pulling)
		var/pulling_old = pulling
		stop_pulling()
		// Are we pulling the same thing twice? Just stop pulling.
		if (pulling_old == AM)
			return

	pulling = AM
	AM.pulledby = src

	/*if (pullin)
		pullin.icon_state = "pull1"*/
	if (HUDneed.Find("pull"))
		var/obj/screen/HUDthrow/HUD = HUDneed["pull"]
		HUD.update_icon()
/*
	if (ishuman(AM))
		var/mob/living/carbon/human/H = AM
		if (H.pull_damage())
			src << "\red <b>Pulling \the [H] in their current condition would probably be a bad idea.</b>"
*/
	//Attempted fix for people flying away through space when cuffed and dragged.
	if (ismob(AM))
		var/mob/pulled = AM
		pulled.inertia_dir = FALSE


/atom/movable/proc/receive_damage(atom/A)
	var/pixel_x_diff = rand(-3,3)
	var/pixel_y_diff = rand(-3,3)
	animate(src, pixel_x = pixel_x + pixel_x_diff, pixel_y = pixel_y + pixel_y_diff, time = 2)
	animate(pixel_x = initial(pixel_x), pixel_y = initial(pixel_y), time = 2)

/mob/living/receive_damage(atom/A)
	..()