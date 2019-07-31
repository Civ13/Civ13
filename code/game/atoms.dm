/atom
	layer = 2
	appearance_flags = TILE_BOUND
	var/level = 2
	var/flags = FALSE

	var/list/fingerprints
	var/list/fingerprintshidden
	var/fingerprintslast = null

	var/list/blood_DNA
	var/was_bloodied
	var/blood_color
	var/last_bumped = FALSE
	var/pass_flags = FALSE
	var/throwpass = FALSE
	var/germ_level = GERM_LEVEL_AMBIENT // The higher the germ level, the more germ on the atom.
	var/simulated = TRUE //filter for actions - used by lighting overlays
//	var/fluorescent // Shows up under a UV light.
	var/allow_spin = TRUE

	///Chemistry.
	var/datum/reagents/reagents = null

	//var/chem_is_open_container = FALSE
	// replaced by OPENCONTAINER flags and atom/proc/is_open_container()
	///Chemistry.

	//Detective Work, used for the duplicate data points kept in the scanners
	var/list/original_atom

	// supply trains

	var/uses_initial_density = FALSE

	var/initial_density = FALSE

	var/uses_initial_opacity = FALSE

	var/initial_opacity = FALSE

/atom/Destroy()
	if (reagents)
		qdel(reagents)
		reagents = null
	. = ..()

/atom/proc/CanPass(atom/movable/mover, turf/target, height=1.5, air_group = FALSE)
	//Purpose: Determines if the object (or airflow) can pass this atom.
	//Called by: Movement, airflow.
	//Inputs: The moving atom (optional), target turf, "height" and air group
	//Outputs: Boolean if can pass.

	return (!density || !height || air_group)


/atom/proc/reveal_blood()
	return

/atom/proc/assume_air(datum/gas_mixture/giver)
	return null

/atom/proc/remove_air(amount)
	return null

/atom/proc/return_air()
	if (loc)
		return loc.return_air()
	else
		return null

//return flags that should be added to the viewer's sight var.
//Otherwise return a negative number to indicate that the view should be cancelled.
/atom/proc/check_eye(user as mob)
	return -1

/atom/proc/on_reagent_change()
	return

/atom/proc/Bumped(AM as mob|obj)
	return

// Convenience proc to see if a container is open for chemistry handling
// returns true if open
// false if closed
/atom/proc/is_open_container()
	return flags & OPENCONTAINER

/*//Convenience proc to see whether a container can be accessed in a certain way.

	proc/can_subract_container()
		return flags & EXTRACT_CONTAINER

	proc/can_add_container()
		return flags & INSERT_CONTAINER
*/

/atom/proc/CheckExit()
	return TRUE

// If you want to use this, the atom must have the PROXMOVE flag, and the moving
// atom must also have the PROXMOVE flag currently to help with lag. ~ ComicIronic
/atom/proc/HasProximity(atom/movable/AM as mob|obj)
	return

/atom/proc/emp_act(var/severity)
	return

/atom/proc/pre_bullet_act(var/obj/item/projectile/P)

/atom/proc/bullet_act(var/obj/item/projectile/P, def_zone)
	P.on_hit(src, FALSE, def_zone)
	. = FALSE

/atom/proc/in_contents_of(container)//can take class or object instance as argument
	if (ispath(container))
		if (istype(loc, container))
			return TRUE
	else if (src in container)
		return TRUE
	return

/*
 *	atom/proc/search_contents_for (path,list/filter_path=null)
 * Recursevly searches all atom contens (including contents contents and so on).
 *
 * ARGS: path - search atom contents for atoms of this type
 *	   list/filter_path - if set, contents of atoms not of types in this list are excluded from search.
 *
 * RETURNS: list of found atoms
 */

/atom/proc/search_contents_for (path,list/filter_path=null)
	var/list/found = list()
	for (var/atom/A in src)
		if (istype(A, path))
			found += A
		if (filter_path)
			var/pass = FALSE
			for (var/type in filter_path)
				pass |= istype(A, type)
			if (!pass)
				continue
		if (A.contents.len)
			found += A.search_contents_for (path,filter_path)
	return found





//All atoms
/atom/proc/examine(mob/user, var/distance = -1, var/infix = "", var/suffix = "")
	//This reformat names to get a/an properly working on item descriptions when they are bloody
	var/f_name = "\a [src][infix]."
	if (blood_DNA && !istype(src, /obj/effect/decal))
		if (gender == PLURAL)
			f_name = "some "
		else
			f_name = "a "
		if (blood_color != "#030303")
			f_name += "<span class='danger'>blood-stained</span> [name][infix]!"
		else
			f_name += "oil-stained [name][infix]."
	if (!isobserver(user))
		user.visible_message("<font size=1>[user.name] looks at [src].</font>")
	user << "\icon[src] That's [f_name] [suffix]"
	user << desc

	return distance == -1 || (get_dist(src, user) <= distance)

//called to set the atom's dir and used to add behaviour to dir-changes
/atom/proc/set_dir(new_dir)
	var/old_dir = dir
	if (new_dir == old_dir)
		return FALSE

	dir = new_dir
	dir_set_event.raise_event(src, old_dir, new_dir)
	return TRUE

/atom/proc/ex_act()
	return


/atom/proc/fire_act()
	if (isobject(src))
		var/obj/NS = src
		if (!NS.flammable)
			return
		else
			if (prob(27))
				visible_message("<span class = 'warning'>\The [NS] is burned away.</span>")
				if (prob(3))
					new/obj/effect/effect/smoke(loc)
				qdel(src)
	else
		return

/atom/proc/melt()
	return

/atom/proc/hitby(atom/movable/AM as mob|obj)
	if (density)
		AM.throwing = FALSE
	if (istype(AM, /obj/item/weapon/snowball))
		var/obj/item/weapon/snowball/SB = AM
		SB.icon_state = "snowball_hit"
		SB.update_icon()
		spawn(6)
			qdel(SB)
		return
	return

/atom/proc/add_hiddenprint(mob/living/M as mob)
	if (isnull(M)) return
	if (isnull(M.key)) return
	if (ishuman(M))
		var/mob/living/carbon/human/H = M
		if (!istype(H.dna, /datum/dna))
			return FALSE
		if (H.gloves)
			if (fingerprintslast != H.key)
				fingerprintshidden += text("\[[time_stamp()]\] (Wearing gloves). Real name: [], Key: []",H.real_name, H.key)
				fingerprintslast = H.key
			return FALSE
		if (!( fingerprints ))
			if (fingerprintslast != H.key)
				fingerprintshidden += text("\[[time_stamp()]\] Real name: [], Key: []",H.real_name, H.key)
				fingerprintslast = H.key
			return TRUE
	else
		if (fingerprintslast != M.key)
			fingerprintshidden += text("\[[time_stamp()]\] Real name: [], Key: []",M.real_name, M.key)
			fingerprintslast = M.key
	return

/atom/proc/add_fingerprint(mob/living/M as mob, ignoregloves = FALSE)
	if (isnull(M)) return
	if (isnull(M.key)) return
	if (ishuman(M))
		//Add the list if it does not exist.
		if (!fingerprintshidden)
			fingerprintshidden = list()

		//First, make sure their DNA makes sense.
		var/mob/living/carbon/human/H = M
		if (!istype(H.dna, /datum/dna) || !H.dna.uni_identity || (length(H.dna.uni_identity) != 32))
			if (!istype(H.dna, /datum/dna))
				H.dna = new /datum/dna(null)
				H.dna.real_name = H.real_name
		H.check_dna()

		//Now, deal with gloves.
		if (H.gloves && H.gloves != src)
			if (fingerprintslast != H.key)
				fingerprintshidden += text("\[[]\](Wearing gloves). Real name: [], Key: []",time_stamp(), H.real_name, H.key)
				fingerprintslast = H.key
			H.gloves.add_fingerprint(M)

		//Deal with gloves the pass finger/palm prints.
		if (!ignoregloves)
			if (H.gloves != src)
				if (prob(75) && istype(H.gloves))
					return FALSE
				else if (H.gloves)
					return FALSE

		//More adminstuffz
		if (fingerprintslast != H.key)
			fingerprintshidden += text("\[[]\]Real name: [], Key: []",time_stamp(), H.real_name, H.key)
			fingerprintslast = H.key

		//Make the list if it does not exist.
		if (!fingerprints)
			fingerprints = list()

		//Hash this shit.
		var/full_print = H.get_full_print()

		// Add the fingerprints
		//
		if (fingerprints[full_print])
			switch(stringpercent(fingerprints[full_print]))		//tells us how many stars are in the current prints.

				if (28 to 32)
					if (prob(1))
						fingerprints[full_print] = full_print 		// You rolled a one buddy.
					else
						fingerprints[full_print] = stars(full_print, rand(0,40)) // 24 to 32

				if (24 to 27)
					if (prob(3))
						fingerprints[full_print] = full_print     	//Sucks to be you.
					else
						fingerprints[full_print] = stars(full_print, rand(15, 55)) // 20 to 29

				if (20 to 23)
					if (prob(5))
						fingerprints[full_print] = full_print		//Had a good run didn't ya.
					else
						fingerprints[full_print] = stars(full_print, rand(30, 70)) // 15 to 25

				if (16 to 19)
					if (prob(5))
						fingerprints[full_print] = full_print		//Welp.
					else
						fingerprints[full_print]  = stars(full_print, rand(40, 100))  // FALSE to 21

				if (0 to 15)
					if (prob(5))
						fingerprints[full_print] = stars(full_print, rand(0,50)) 	// small chance you can smudge.
					else
						fingerprints[full_print] = full_print

		else
			fingerprints[full_print] = stars(full_print, rand(0, 20))	//Initial touch, not leaving much evidence the first time.


		return TRUE
	else
		//Smudge up dem prints some
		if (fingerprintslast != M.key)
			fingerprintshidden += text("\[[]\]Real name: [], Key: []",time_stamp(), M.real_name, M.key)
			fingerprintslast = M.key

	//Cleaning up shit.
	if (fingerprints && !fingerprints.len)
		qdel(fingerprints)
	return


/atom/proc/transfer_fingerprints_to(var/atom/A)

	if (!istype(A.fingerprints,/list))
		A.fingerprints = list()

	if (!istype(A.fingerprintshidden,/list))
		A.fingerprintshidden = list()

	if (!istype(fingerprintshidden, /list))
		fingerprintshidden = list()

	//skytodo
	//A.fingerprints |= fingerprints            //detective
	//A.fingerprintshidden |= fingerprintshidden    //admin
	if (A.fingerprints && fingerprints)
		A.fingerprints |= fingerprints.Copy()            //detective
	if (A.fingerprintshidden && fingerprintshidden)
		A.fingerprintshidden |= fingerprintshidden.Copy()    //admin	A.fingerprintslast = fingerprintslast


//returns TRUE if made bloody, returns FALSE otherwise
/atom/proc/add_blood(mob/living/carbon/human/M as mob)

	if (flags & NOBLOODY)
		return FALSE

	if (!blood_DNA || !istype(blood_DNA, /list))	//if our list of DNA doesn't exist yet (or isn't a list) initialise it.
		blood_DNA = list()

	was_bloodied = TRUE
	blood_color = "#A10808"
	if (istype(M))
		if (!istype(M.dna, /datum/dna))
			M.dna = new /datum/dna(null)
			M.dna.real_name = M.real_name
		M.check_dna()
		if (M.species)
			blood_color = M.species.blood_color
	. = TRUE
	return TRUE

/atom/proc/add_vomit_floor(mob/living/carbon/M as mob, var/toxvomit = FALSE)
	if ( istype(src, /turf) )
		var/obj/effect/decal/cleanable/vomit/this = new /obj/effect/decal/cleanable/vomit(src)

		// Make toxins vomit look different
		if (toxvomit)
			this.icon_state = "vomittox_[pick(1,4)]"

/atom/proc/clean_blood()
	if (!simulated)
		return
//	fluorescent = FALSE
	germ_level = FALSE
	if (istype(blood_DNA, /list))
		blood_DNA = null
		return TRUE

/atom/proc/checkpass(passflag)
	return pass_flags&passflag

/atom/proc/isinspace()
	return FALSE

// Show a message to all mobs and objects in sight of this atom
// Use for objects performing visible actions
// message is output to anyone who can see, e.g. "The [src] does something!"
// blind_message (optional) is what blind people will hear e.g. "You hear something!"
/atom/proc/visible_message(var/message, var/blind_message)

	var/list/see = get_mobs_or_objects_in_view(7,src) | viewers(get_turf(src), null)

	for (var/I in see)
		if (isobj(I))
			spawn(0)
				if (I) //It's possible that it could be deleted in the meantime.
					var/obj/O = I
					O.show_message( message, TRUE, blind_message, 2)
		else if (ismob(I))
			var/mob/M = I
			if (M.see_invisible >= invisibility) // Cannot view the invisible
				M.show_message( message, TRUE, blind_message, 2)
			else if (blind_message)
				M.show_message(blind_message, 2)

// Show a message to all mobs and objects in earshot of this atom
// Use for objects performing audible actions
// message is the message output to anyone who can hear.
// deaf_message (optional) is what deaf people will see.
// hearing_distance (optional) is the range, how many tiles away the message can be heard.
/atom/proc/audible_message(var/message, var/deaf_message, var/hearing_distance)

	var/range = 7
	if (hearing_distance)
		range = hearing_distance
	var/list/hear = get_mobs_or_objects_in_view(range,src)

	for (var/I in hear)
		if (isobj(I))
			spawn(0)
				if (I) //It's possible that it could be deleted in the meantime.
					var/obj/O = I
					O.show_message( message, 2, deaf_message, TRUE)
		else if (ismob(I))
			var/mob/M = I
			M.show_message( message, 2, deaf_message, TRUE)

/atom/Entered(var/atom/movable/AM, var/atom/old_loc, var/special_event)
	if (loc && special_event == MOVED_DROP)
		AM.forceMove(loc, MOVED_DROP)
		return CANCEL_MOVE_EVENT
	return ..()

/turf/Entered(var/atom/movable/AM, var/atom/old_loc, var/special_event)
	return ..(AM, old_loc, FALSE)

//Kicking
/atom/proc/kick_act(mob/living/carbon/human/user)
	if (!user.canClick())
		return
	//They're not adjcent to us so we can't kick them. Can't kick in straightjacket or while being incapacitated (except lying), can't kick while legcuffed or while being locked in closet
	if(!Adjacent(user) || user.incapacitated(INCAPACITATION_STUNNED|INCAPACITATION_KNOCKOUT|INCAPACITATION_BUCKLED_PARTIALLY|INCAPACITATION_BUCKLED_FULLY) \
		|| istype(user.loc, /obj/structure/closet))
		return

	if(user.handcuffed && prob(45) && !user.incapacitated(INCAPACITATION_FORCELYING))//User can fail to kick smbd if cuffed
		user.visible_message("<span class='danger'>[user.name] loses \his balance while trying to kick \the [src].</span>", \
					"<span class='warning'> You lost your balance.</span>")
		user.Weaken(1)
		return

	if(user.middle_click_intent == "kick")//We're in kick mode, we can kick.
		for(var/limbcheck in list("l_leg","r_leg"))//But we need to see if we have legs.
			var/obj/item/organ/affecting = user.get_organ(limbcheck)
			if(!affecting)//Oh shit, we don't have have any legs, we can't kick.
				return 0

		user.setClickCooldown(16)
		return 1 //We do have legs now though, so we can kick.

//Kicking
/atom/proc/bite_act(mob/living/carbon/human/user)
	if (!user.canClick())
		return
	if(!Adjacent(user) || user.incapacitated(INCAPACITATION_STUNNED|INCAPACITATION_KNOCKOUT) || istype(user.loc, /obj/structure/closet) || !ishuman(src))
		return
	var/mob/living/carbon/human/target = src
	if(user.middle_click_intent == "bite")//We're in bite mode, so bite the opponent
		var/limbcheck = user.targeted_organ
		if (limbcheck == "random")
			limbcheck = pick("l_arm","r_arm","l_hand","r_hand")
		if(limbcheck in list("l_hand","r_hand","l_arm","r_arm") || user.werewolf)
			var/obj/item/organ/external/affecting = target.get_organ(limbcheck)
			if(!affecting)
				user << "<span class='notice'>[src] is missing that body part.</span>"
				return FALSE
			else
				visible_message("<span class='danger'>[user] bites the [src]'s [affecting.name]!</span>","<span class='danger'>You bite the [src]'s [affecting.name]!</span>")
				if (ishuman(src) && ishuman(user))
					if (user.werewolf && user.body_build.name != "Default")
						affecting.createwound(BRUISE, rand(15,21)*user.getStatCoeff("strength"))
						if (prob(20))
							target.werewolf = 1
					else
						affecting.createwound(BRUISE, rand(6,9)*user.getStatCoeff("strength"))
					target.emote("painscream")
				else
					target.adjustBruteLoss(rand(6,7))
				if (prob(30))
					if (limbcheck == "l_hand")
						if (target.l_hand)
							// Disarm left hand
							//Urist McAssistant dropped the macguffin with a scream just sounds odd. Plus it doesn't work with NO_PAIN
							target.visible_message("<span class='danger'>[target] drops \the [target.l_hand]!</span>")
							target.drop_l_hand()
					if (limbcheck == "r_hand")
						if (target.r_hand)
							// Disarm right hand
							target.visible_message("<span class='danger'>[target] drops \the [target.r_hand]!</span>")
							target.drop_r_hand()
		else
			user << "<span class='notice'>You cannot bite that part of the body, it's too far away!</span>"
			return FALSE

		user.setClickCooldown(25)
		return TRUE

//Jumping
/atom/proc/jump_act(atom/target, mob/living/carbon/human/user)
	if (!user.canClick())
		return
	//No jumping on the ground dummy && No jumping in space && No jumping in straightjacket or while being incapacitated (except handcuffs) && No jumping vhile being legcuffed or locked in closet
	if(user.incapacitated(INCAPACITATION_STUNNED|INCAPACITATION_KNOCKOUT|INCAPACITATION_BUCKLED_PARTIALLY|INCAPACITATION_BUCKLED_FULLY|INCAPACITATION_FORCELYING) || user.isinspace() \
		|| istype(user.loc, /obj/structure/closet))
		return

	for(var/limbcheck in list("l_leg","r_leg"))//But we need to see if we have legs.
		var/obj/item/organ/affecting = user.get_organ(limbcheck)
		if(!affecting)//Oh shit, we don't have have any legs, we can't jump.
			return
	var/maxdist = 2
	if (ishuman(user))
		if (user.gorillaman)
			maxdist = 3
	if (istype(target, /turf/floor/beach/water) || user.stats["stamina"][1] <= 25 || get_dist(target,user)>maxdist)
		return
	if ((istype(target, /obj) && target.density == TRUE) || (istype(target, /turf) && target.density == TRUE))
		return
	//is there a wall in the way?
	if (get_dist(target,user)==2)
		var/dir_to_tgt = get_dir(user,target)
		for(var/obj/O in range(1,user))
			if (get_dir(user,O) == dir_to_tgt && (O.density == TRUE || istype(O, /obj/structure/window/sandbag/railing)))
				user << "<span class='danger'>You hit the [O]!</span>"
				user.adjustBruteLoss(rand(2,7))
				user.Weaken(2)
				user.setClickCooldown(22)
				return
		for(var/turf/T in range(1,user))
			if (get_dir(user,T) == dir_to_tgt && T.density == TRUE)
				user << "<span class='danger'>You hit the [T]!</span>"
				user.adjustBruteLoss(rand(2,7))
				user.Weaken(2)
				user.setClickCooldown(22)
				return
	if (maxdist == 3 && get_dist(target,user)==3)
		var/dir_to_tgt = get_dir(user,target)
		for(var/obj/O in range(2,user))
			if (get_dir(user,O) == dir_to_tgt && (O.density == TRUE || istype(O, /obj/structure/window/sandbag/railing)))
				user << "<span class='danger'>You hit the [O]!</span>"
				user.adjustBruteLoss(rand(2,7))
				user.Weaken(2)
				user.setClickCooldown(22)
				return
		for(var/turf/T in range(2,user))
			if (get_dir(user,T) == dir_to_tgt && T.density == TRUE)
				user << "<span class='danger'>You hit the [T]!</span>"
				user.adjustBruteLoss(rand(2,7))
				user.Weaken(2)
				user.setClickCooldown(22)
				return
	//Nice, we can jump, let's do that then.
	playsound(user, user.gender == MALE ? 'sound/effects/jump_male.ogg' : 'sound/effects/jump_female.ogg', 25)
	user.visible_message("[user] jumps.")
	user.stats["stamina"][1] = max(user.stats["stamina"][1] - rand(20,40), 0)
	user.throw_at(target, 5, 0.5, user)
	user.setClickCooldown(22)