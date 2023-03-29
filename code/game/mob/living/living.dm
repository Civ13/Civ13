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

	usr.visible_message("<b>[src]</b> points to [A].")
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

	// no more pushing people past caribbean blocks - Kachnov
	if (istype(AM, /obj/structure/closet))
		for (var/mob/living/human/H in AM)
			if (map.check_caribbean_block(H, get_step(get_turf(AM), dir)))
				return

	else if (ishuman(AM))
		if (map && map.check_caribbean_block(AM, get_step(get_turf(AM), dir)))
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
						src << "<span class='warning'>[tmob] is restrained, you cannot push past.</span>"
					now_pushing = FALSE
					return
				if ( tmob.pulling == M && ( M.restrained() && !( tmob.restrained() ) && tmob.stat == FALSE) )
					if ( !(world.time % 5) )
						src << "<span class='warning'>[tmob] is restraining [M], you cannot push past.</span>"
					now_pushing = FALSE
					return

			//Leaping mobs just land on the tile, no pushing, no anything.
			if (status_flags & LEAPING)
				loc = tmob.loc
				status_flags &= ~LEAPING
				now_pushing = FALSE
				return

			if (can_swap_with(tmob)) // mutual brohugs all around!
				if (istype(src, /mob/living/human))
					var/mob/living/human/H = src
					if (H.riding)
						var/mob/living/simple_animal/horse/HR = H.riding_mob
						if (!tmob.anchored)
							var/t = get_dir(H, tmob)
							step(tmob, t)
						if (HR.loc != H.loc)
							HR.loc = H.loc
							HR.forceMove(H.loc)
							HR.trample(tmob)
						H.riding_mob.update_icons()
					else
						var/turf/oldloc = loc
						forceMove(tmob.loc)
						tmob.forceMove(oldloc)
						now_pushing = FALSE
				else if (istype(src, /mob/living/simple_animal/horse))
					var/mob/living/simple_animal/horse/HR = src
					if (!tmob.anchored)
						var/t = get_dir(HR, tmob)
						step(tmob, t)
				else
					var/turf/oldloc = loc
					forceMove(tmob.loc)
					tmob.forceMove(oldloc)
					now_pushing = FALSE
					return

			if (!can_move_mob(tmob, FALSE, FALSE))
				now_pushing = FALSE
				return
			if (a_intent == I_HELP || restrained())
				now_pushing = FALSE
				return
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
	if (map && (map.ID == MAP_FOOTBALL || map.ID == MAP_FOOTBALL_CAMPAIGN))
		return FALSE
	if (ishuman(src))
		var/mob/living/human/H = src
		if (H.shoes && istype(H.shoes, /obj/item/clothing/shoes/football))
			return FALSE
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
	set name = "Succumb"
	set desc = "Succumb to death."
	set category = "IC"
	if (getTotalDmg() > 60)
		if (WWinput(src, "Are you sure you want to succumb? You only live once.", "", "Cancel", list("Succumb", "Cancel")) == "Succumb")
			adjustBrainLoss(300)
			death()
			src << "<span class = 'notice'>You have given up life and succumbed to death.</span>"
			return
	else
		src << "<span class = 'notice'>You cannot succumb in this map unless you have very high damage!</span>"
		return


//This proc is used for mobs which are affected by pressure to calculate the amount of pressure that actually
//affects them once clothing is factored in. ~Errorage
/mob/living/proc/calculate_affecting_pressure(var/pressure)
	return


//sort of a legacy burn method for /electrocute, /shock, and the e_chair
/mob/living/proc/burn_skin(burn_amount)
	if (istype(src, /mob/living/human))
		//world << "DEBUG: burn_skin(), mutations=[mutations]"
		var/mob/living/human/H = src	//make this damage method divide the damage to be done among all the body parts, then burn each body part for that much damage. will have better effect then just randomly picking a body part
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
//	if (istype(src, /mob/living/human))
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
		var/mob/living/human/H = src
		if (H.takes_less_damage)
			amount /= H.getStatCoeff("strength")
	bruteloss = min(max(bruteloss + amount, FALSE),(maxHealth*2))
	return TRUE

/mob/living/proc/getOxyLoss()
	return oxyloss

/mob/living/proc/adjustOxyLoss(var/amount)
	if (status_flags & GODMODE)	return FALSE	//godmode
	if (ishuman(src))
		var/mob/living/human/H = src
		if (H.takes_less_damage)
			amount /= H.getStatCoeff("strength")
	oxyloss = min(max(oxyloss + amount, FALSE),(maxHealth*2))

/mob/living/proc/setOxyLoss(var/amount)
	if (status_flags & GODMODE)	return FALSE	//godmode
	if (ishuman(src))
		var/mob/living/human/H = src
		if (H.takes_less_damage)
			amount /= H.getStatCoeff("strength")
	oxyloss = amount

/mob/living/proc/getToxLoss()
	return toxloss

/mob/living/proc/adjustToxLoss(var/amount)
	if (status_flags & GODMODE)	return FALSE	//godmode
	if (ishuman(src))
		var/mob/living/human/H = src
		if (H.takes_less_damage)
			amount /= H.getStatCoeff("strength")
	toxloss = min(max(toxloss + amount, FALSE),(maxHealth*2))

/mob/living/proc/setToxLoss(var/amount)
	if (status_flags & GODMODE)	return FALSE	//godmode
	if (ishuman(src))
		var/mob/living/human/H = src
		if (H.takes_less_damage)
			amount /= H.getStatCoeff("strength")
	toxloss = amount

/mob/living/proc/getFireLoss()
	return fireloss

/mob/living/proc/adjustFireLoss(var/amount)
	if (status_flags & GODMODE)	return FALSE	//godmode
	if (ishuman(src))
		var/mob/living/human/H = src
		if (H.takes_less_damage)
			amount /= H.getStatCoeff("strength")
	fireloss = min(max(fireloss + amount, FALSE),(maxHealth*2))

/mob/living/proc/getCloneLoss()
	return cloneloss

/mob/living/proc/adjustCloneLoss(var/amount)
	if (status_flags & GODMODE)	return FALSE	//godmode
	if (ishuman(src))
		var/mob/living/human/H = src
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
//since gettotalloss() counts halloss it broke the check_instadeath() proc
/mob/living/proc/getTotalDmg()
	return getBruteLoss() + getToxLoss() + getFireLoss() + getBrainLoss()

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
	if (t == "random")
		t = pick("l_foot","r_foot","l_leg","r_leg","chest","groin","l_arm","r_arm","l_hand","r_hand","eyes","mouth","head")
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
	if (ishuman(src))
		var/mob/living/human/C = src

		if (C.handcuffed && !initial(C.handcuffed))
			C.drop_from_inventory(C.handcuffed)
		C.handcuffed = initial(C.handcuffed)

		if (C.legcuffed && !initial(C.legcuffed))
			C.drop_from_inventory(C.legcuffed)
		C.legcuffed = initial(C.legcuffed)
	ExtinguishMob()
	fire_stacks = 0

/mob/living/proc/rejuvenate()
	if (reagents)
		reagents.clear_reagents()

	// shut down various types of badness
	setToxLoss(0)
	setOxyLoss(0)
	setCloneLoss(0)
	setBrainLoss(0)
	SetParalysis(0)
	SetStunned(0)
	SetWeakened(0)
	setHalLoss(0)

	// shut down ongoing problems
	radiation = FALSE
	bodytemperature = T20C
	sdisabilities = FALSE
	disabilities = FALSE

	// fix all disseases
	if (ishuman(src))
		var/mob/living/human/H = src
		H.disease = FALSE
		H.disease_progression = 0
		H.disease_type = "none"

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

						var/area/A = get_area(M)
						if (A.has_gravity)
							//this is the gay blood on floor shit -- Added back -- Skie
							if (M.lying && (prob(M.getBruteLoss() / 6)))
								var/turf/location = M.loc
								if (istype(location, /turf))
									location.add_blood(M)


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

	update_vision_cone()

	if (client)
		for(var/obj/chat_text/CT in client.stored_chat_text)
			CT.glide_size = src.glide_size
			CT.forceMove(src.loc)


/mob/living/verb/resist()
	set name = "Resist"
	set category = "IC"

	if (!stat && canClick())
		setClickCooldown(20)
		resist_grab()
		if (!weakened)
			process_resist()

/mob/living/proc/process_resist()

	//unbuckling yourself
	if (buckled)
		spawn() escape_buckle()
		return TRUE

	//Breaking out of a locker?
	if ( loc && (istype(loc, /obj/structure/closet)) )
		var/obj/structure/closet/C = loc
		spawn() C.mob_breakout(src)
		return TRUE


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
				if (prob(19)) //same chance of breaking the grab as disarm
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

/mob/living/proc/has_brain()
	return TRUE

/mob/living/proc/has_eyes()
	return TRUE

/mob/living/human/drop_from_inventory(var/obj/item/W, var/atom/Target = null)
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

	if (AM.anchored || istype(AM, /obj/item/football))
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

		if (!ishuman(src))
			M.LAssailant = null
		else
			M.LAssailant = usr

	else if (isobj(AM))
		var/obj/I = AM
		if (!can_pull_size || can_pull_size < I.w_class || istype(I, /obj/item/football))
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
		var/mob/living/human/H = AM
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

/mob/living/proc/forcelife()
	if (src && stat != DEAD)
		life_forced = TRUE
		spawn(10)
			if (world.realtime>=last_life_tick+9)
				Life()
			forcelife()
	else if (src)
		life_forced = FALSE
	else
		return
/mob/living/proc/slip(var/slipped_on,stun_duration=8)
	return FALSE
//Code to handle merging stacks when they are in mob's direct inventory.
//Called when object enters the contents of a mob. Storage items not supported yet.
//Not used because people don't like it. Might be useful for merging in containers.
/* /mob/living/Entered(var/obj/item/stack/O)
 * 	..()
 * 	if(istype(O, /obj/item/stack))
 * 		if(O.amount != O.max_amount)
 * 			for(var/obj/item/stack/S in contents)
 * 				if(S.stacktype == O.stacktype && S.amount != S.max_amount)
 * 					if(O.amount == O.max_amount)
 * 						break
 * 					S.merge(O)
 */