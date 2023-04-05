// decisecond click delay (above and beyond mob/next_move)
/mob/var/next_click = 0

/*	Alternately, you could hardcode every mob's variation in a flat ClickOn() proc; however,
	that's a lot of code duplication and is hard to maintain.
	Note that this proc can be overridden, and is in the case of screen objects.*/
/atom/Click(var/location, var/control, var/params) 
	if (src)
		usr.ClickOn(src, params)

/atom/DblClick(var/location, var/control, var/params)
	if (src)
		usr.DblClickOn(src, params)

/*	Standard mob ClickOn()
	Handles exceptions: Buildmode, middle click, modified clicks, mech actions
	  After that, mostly just check your state, check whether you're holding an item,
	  check whether you're adjacent to the target, then pass off the click to whoever
	  is recieving it.
	The most common are:
	* mob/UnarmedAttack(atom,adjacent) - used here only when adjacent, with no item in hand; in the case of humans, checks gloves
	* atom/attackby(item,user) - used only when adjacent
	* item/afterattack(atom,user,adjacent,params) - used both ranged and adjacent
	* mob/RangedAttack(atom,params) - used only ranged, only used for tk and laser eyes but could be changed */
/mob/proc/ClickOn(var/atom/A, var/params)
	if (world.time <= next_click) // Hard check, before anything else, to avoid crashing
		return 
	next_click = world.time + 1
	/*if (client.buildmode)  //unused now
		build_click(src, client.buildmode, params, A)
		return*/
	var/list/modifiers = params2list(params)
	var/icon_x = text2num(modifiers["icon-x"])
	var/icon_y = text2num(modifiers["icon-y"])
	if (modifiers["shift"] && modifiers["ctrl"])
		CtrlShiftClickOn(A)
		return 
	if (modifiers["middle"])
		MiddleClickOn(A)
		return 
	if (modifiers["shift"])
		ShiftClickOn(A)
		return 
	if (modifiers["alt"])
		AltClickOn(A)
		return 
	if (modifiers["ctrl"])
		CtrlClickOn(A)
		return 
	if (ishuman(src)) //src is user who is click and human
		var/mob/living/human/H = src
		if (istype(H.shoes, /obj/item/clothing/shoes/football)) //TODO TO DO: move it to football.dm
			if (H.football)  
				var/obj/item/football/FB = H.football
				H.do_attack_animation(H.football)
				H.football = null
				FB.owner = null
				FB.last_owner = H
				FB.throw_at(A, FB.throw_range, FB.throw_speed, H)
				FB.owner = null
				H.football = null
				H.do_attack_animation(get_step(H,H.dir))
				playsound(loc, 'sound/effects/football_kick.ogg', 100, 1)
				visible_message("[src] kicks \the [FB.name].")
				return
			else if (ishuman(A) && get_dist(H,A) <= 1) //if we dont have the ball, try to apply pressure and take the ball without tackling
				var/mob/living/human/HM = A
				if (HM.civilization != H.civilization && H.stats["stamina"][1] >= 7) //no pressure on same team
					H.setClickCooldown(10)
					H.stats["stamina"][1] = max(H.stats["stamina"][1] - 7, 0)
					H.do_attack_animation(HM)
					var/obj/item/football/opponent_has_ball = null
					if (HM.football)
						opponent_has_ball = HM.football
					if (prob(35) && opponent_has_ball)
						H.visible_message("<font color='red'>[H] takes the ball from [HM]!</font>")
						playsound(H.loc, 'sound/weapons/punch1.ogg', 50, 1)
						HM.football = null
						opponent_has_ball.last_owner = H
						opponent_has_ball.owner = H
						H.football = opponent_has_ball
						opponent_has_ball.forceMove(H.loc)
					else
						H.visible_message("<font color='yellow'>[H] pressures [HM]!</font>")
						H.do_attack_animation(HM)
						playsound(H.loc, 'sound/weapons/punchmiss.ogg', 50, 1)
					return
		if (istype(H.get_active_hand(), /obj/item/weapon/flamethrower)) //TO DO TODO: move it to flamethrower.dm
			var/obj/item/weapon/flamethrower/FL = H.get_active_hand()
			var/cdir = get_dir(H,A)
			FL.fire(H,cdir,A)
		if (istype(H.buckled, /obj/structure/bed/chair/commander)) //TO DO TODO: move it to wheels.dm
			var/obj/item/weapon/attachment/scope/adjustable/binoculars/periscope/P
			if (istype(H.l_hand,/obj/item/weapon/attachment/scope/adjustable/binoculars/periscope))
				P = H.l_hand
				P.rangecheck(H,A)
			else if (istype(H.r_hand,/obj/item/weapon/attachment/scope/adjustable/binoculars/periscope))
				P = H.r_hand
				P.rangecheck(H,A)
		if (istype(H.get_active_hand(), /obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator))
			var/obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator/P = H.get_active_hand()
			P.rangecheck(H,A)
		if (istype(H.get_active_hand(), /obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator_campaign))
			var/obj/item/weapon/attachment/scope/adjustable/binoculars/laser_designator/P = H.get_active_hand()
			P.rangecheck(H,A)
	for (var/obj/structure/noose/N in get_turf(src)) // can't click on anything when we're hanged
		if (N.hanging == src)
			return
	if (lying && istype(A, /turf/floor))
		if (A.Adjacent(src))
			scramble(A)
			return
	if (stat || paralysis || stunned || weakened)
		return
	if (!prone)
		face_atom(A) // change direction to face what you clicked on
	else
		var/cdir = get_dir(src, A)
		if (cdir == NORTH || cdir == NORTHWEST || cdir == NORTHEAST || cdir == WEST)
			dir = WEST
			var/matrix/M = matrix()
			M.Turn(-90)
			M.Translate(1,-6)
			transform = M
		else
			dir = EAST
			var/matrix/M = matrix()
			M.Turn(90)
			M.Translate(1,-6)
			transform = M
	if (!canClick()) // in the year 2000...
		return
	if (istype(A, /obj/structure/multiz/ladder/ww2)) // stop looking down a ladder 
		var/mob/living/human/H = src
		if (istype(H) && H.laddervision)
			H.update_laddervision(null)
			H.visible_message("<span class = 'notice'>[H] stops looking [H.laddervision_direction()] the ladder.</span>")
			return
	if (restrained())
		setClickCooldown(10)
		RestrainedClickOn(A)
		return
	if (in_throw_mode)
		if (isturf(A) || isturf(A.loc))
			throw_item(A)
			return
		throw_mode_off()
	var/obj/item/W = get_active_hand() //trying to resolve an item in hand
	if (!W)
		var/atom/movable/special_MG = null
		if (using_MG) //TO DO TODO: move to mg.dm
			special_MG = using_MG
		if (special_MG && special_MG.loc)
			var/obj/item/weapon/gun/projectile/automatic/stationary/MG = special_MG
			var/can_fire = FALSE
			switch (MG.dir)
				if (EAST)
					if (A.x > MG.x)
						can_fire = TRUE
					else
						can_fire = FALSE
				if (WEST)
					if (A.x < MG.x)
						can_fire = TRUE
					else
						can_fire = FALSE
				if (NORTH, NORTHEAST, NORTHWEST)
					if (A.y > MG.y)
						can_fire = TRUE
					else
						can_fire = FALSE
				if (SOUTH, SOUTHEAST, SOUTHWEST)
					if (A.y < MG.y)
						can_fire = TRUE
					else
						can_fire = FALSE
			if (can_fire)
				MG.afterattack(A, src, FALSE, params)
	if (W && W == A) // Handle attack_self (using item in hand)
		W.attack_self(src, icon_x, icon_y)
		if (hand)
			update_inv_l_hand(0)
		else
			update_inv_r_hand(0)
		return TRUE
	for(var/obj/structure/vehicleparts/frame/F in src.loc) 
		var/found = FALSE
		if(istype(F, /obj/structure/vehicleparts/frame/ship))
			continue
		for(var/obj/structure/vehicleparts/frame/FR in get_turf(A))
			if (FR.axis != F.axis && FR != F)
				if (!F.CanPass(src, get_turf(A)) || !F.CheckExit(src, get_turf(A)))
					return
			if (FR.axis == F.axis)
				found = TRUE
		if (!found)
			return
	//Atoms on your person
	// A is your location but is not a turf; or is on you (backpack); or is on something on you (box in backpack); sdepth is needed here because contents depth does not equate inventory storage depth.
	var/sdepth = A.storage_depth(src)
	if ((!isturf(A) && A == loc) || (sdepth != -1 && sdepth <= 1))
		if (W)
			var/resolved = W.resolve_attackby(A, src, icon_x, icon_y) // Return TRUE in attackby() to prevent afterattack() effects (when safely moving items for example)
			if (!resolved && A && W)
				if (istype(W, /obj/item/weapon/gun))
					var/obj/item/weapon/gun/G = W
					if (G.full_auto)
						var/datum/firemode/F = G.firemodes[G.sel_mode]
						spawn(F.burst_delay)
							W.afterattack(A, src, TRUE, params) // TRUE indicates adjacency
					else
						W.afterattack(A, src, TRUE, params) // TRUE indicates adjacency
				else
					W.afterattack(A, src, TRUE, params) // TRUE indicates adjacency
		else
			if (ismob(A)) // No instant mob attacking
				setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
			UnarmedAttack(A, TRUE, icon_x, icon_y)
		return
	if (!isturf(loc)) // This is going to stop you from telekinesing from inside a closet, but I don't shed many tears for that
		return
	//Atoms on turfs (not on your person)
	// A is a turf or is on a turf, or in something on a turf (pen in a box); but not something in something on a turf (pen in a box in a backpack)
	sdepth = A.storage_depth_turf()
	if (isturf(A) || isturf(A.loc) || (sdepth != -1 && sdepth <= 1))
		if (A.Adjacent(src) || (W && W == get_active_hand() && (istype(W, /obj/item/weapon/barrier))) && A.rangedAdjacent(src)) // see adjacent.dm
			dir = get_dir(src, A)
			if (W && istype(W, /obj/item/weapon/barrier) && A.rangedAdjacent(src) && (isturf(A) || istype(A, /obj/structure/window/barrier/incomplete)))
				if (get_active_hand() != W)
					return
				if (!istype(A, /obj/structure/window/barrier/incomplete))
					A = get_turf(A)
				else
					if (!A.Adjacent(src)) // if we're adding to a sandbag wall, let us stand anywhere in range(1)
						return
				var/needs_to_be_in_front = istype(A, /turf)
				if (needs_to_be_in_front) // but if we're making a new sandbag wall, we have to click right in front of us.
					if (A != get_step(src, dir))
						return
			if (W)
				var/resolved = W.resolve_attackby(A, src, icon_x, icon_y) // Return TRUE in attackby() to prevent afterattack() effects (when safely moving items for example)
				if (!resolved && A && W)
					if (istype(W, /obj/item/weapon/gun))
						var/obj/item/weapon/gun/G = W
						if (G.full_auto)
							var/datum/firemode/F = G.firemodes[G.sel_mode]
							spawn(F.burst_delay)
								W.afterattack(A, src, TRUE, params) // TRUE indicates adjacency
						else
							W.afterattack(A, src, TRUE, params) // TRUE indicates adjacency
					else
						W.afterattack(A, src, TRUE, params) // TRUE indicates adjacency
			else
				if (ismob(A)) // No instant mob attacking
					setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
				UnarmedAttack(A, TRUE, icon_x, icon_y)
			return
		else // non-adjacent click
			if (W)
				if (istype(W, /obj/item/weapon/gun))
					var/obj/item/weapon/gun/G = W
					if (G.full_auto)
						var/datum/firemode/F = G.firemodes[G.sel_mode]
						spawn(F.burst_delay)
							W.afterattack(A, src, FALSE, params)
					else
						W.afterattack(A, src, FALSE, params)
				else
					W.afterattack(A, src, FALSE, params)
			else
				RangedAttack(A, params)
	return

/mob/proc/setClickCooldown(var/timeout)
	next_move = max(world.time + timeout, next_move)

/mob/proc/canClick()
	if (config.no_click_cooldown || next_move <= world.time)
		return TRUE
	return FALSE

// Default behavior: ignore double clicks, the second click that makes the doubleclick call already calls for a normal click
/mob/proc/DblClickOn(var/atom/A, var/params)
	return

/*
	Translates into attack_hand, etc.

	Note: proximity_flag here is used to distinguish between normal usage (flag=1),
	and usage when clicking on things telekinetically (flag=0).  This proc will
	not be called at ranged except with telekinesis.

	proximity_flag is not currently passed to attack_hand, and is instead used
	in human click code to allow glove touches only at melee range.
*/
/mob/proc/UnarmedAttack(var/atom/A, var/proximity_flag, icon_x, icon_y)
	return

/mob/living/UnarmedAttack(var/atom/A, var/proximity_flag, icon_x, icon_y)
	if (!ticker)
		src << "You cannot attack people before the game has started."
		return FALSE
	if (stat)
		return FALSE
	return TRUE

/*
	Ranged unarmed attack:

	This currently is just a default for all mobs, involving
	laser eyes and telekinesis.  You could easily add exceptions
	for things like ranged glove touches, spitting alien acid/neurotoxin,
	animals lunging, etc.
*/
/mob/proc/RangedAttack(var/atom/A, var/params)
	return


/mob/proc/RestrainedClickOn(var/atom/A)
	return

/*
	Middle click
	Only used for swapping hands
*/
/mob/proc/MiddleClickOn(var/atom/A)
	A.MiddleClick(src)
	return

/atom/proc/MiddleClick(var/mob/M)
	middle_click_intent_check(M)
	return
// In case of use break glass


/mob/proc/ShiftMiddleClickOn(var/atom/A)
	A.ShiftMiddleClick(src)
	return

/atom/proc/ShiftMiddleClick(var/mob/living/user)
	if (istype(user, /mob/living))
		user.pointed(src)


// In case of use break glass
/*
/atom/proc/MiddleClick(var/mob/M as mob)
	return
*/

/*
	Shift click
	For most mobs, examine.
	This is overridden in ai.dm
*/


/mob/proc/ShiftClickOn(var/atom/A)
	A.ShiftClick(src)
	return

/atom/proc/ShiftClick(var/mob/user)
	if (user.client && user.client.eye == user)
		user.examinate(src)
	return

/*
	Ctrl click
	For most objects, pull
*/
/mob/proc/CtrlClickOn(var/atom/A)
	A.CtrlClick(src)
	return
/atom/proc/CtrlClick(var/mob/user)
	return

/atom/movable/CtrlClick(var/mob/user)
	if (Adjacent(user))
		user.start_pulling(src)

/*
	Alt click
	Unused except for AI
*/
/mob/proc/AltClickOn(var/atom/A)
	A.AltClick(src)
	return

/atom/proc/AltClick(var/mob/user)
	/*
	var/turf/T = get_turf(src)
	if (T && user.TurfAdjacent(T))
		if (user.listed_turf == T)
			user.listed_turf = null
		else
			user.listed_turf = T
			user.client.statpanel = "Turf"
	*/
	return TRUE

/mob/proc/TurfAdjacent(var/turf/T)
	return T.AdjacentQuick(src)

/*
	Control+Shift click
	Unused except for AI
*/
/mob/proc/CtrlShiftClickOn(var/atom/A)
	A.CtrlShiftClick(src)
	return

/atom/proc/CtrlShiftClick(var/mob/user)
	return

// Simple helper to face what you clicked on, in case it should be needed in more than one place
/mob/proc/face_atom(var/atom/A)
	if (!A || !x || !y || !A.x || !A.y) return
	var/dx = A.x - x
	var/dy = A.y - y
	if (!dx && !dy) return

	var/direction
	if (abs(dx) < abs(dy))
		if (dy > 0)	direction = NORTH
		else		direction = SOUTH
	else
		if (dx > 0)	direction = EAST
		else		direction = WEST
	if (direction != dir)
		facedir(direction)

/mob/proc/scramble(var/turf/floor/F)
	if (F.density)
		return FALSE
	if (stat || buckled || paralysis || stunned || sleeping || (status_flags & FAKEDEATH) || restrained() || (weakened > 10))
		return FALSE
	if (!has_limbs)
		src << "<span class = 'red'>You can't even move yourself - you have no limbs!</span>"
		return FALSE
	if (scrambling)
		return FALSE
	if (map.check_caribbean_block(src, F) || map.check_caribbean_block(src, get_turf(src))) // you somehow got here, fuck you - Kachnov
		return FALSE

	var/oloc = loc
	var/slowness = weakened ? 1.50 : 1.00
	scrambling = TRUE
	sleep(9*slowness)
	visible_message("<span class = 'red'><b>[src]</b> crawls with difficulty!</span>")
	var/nloc = loc
	if (nloc == oloc)
		Move(F)
	scrambling = FALSE

/mob/proc/proning(var/turf/floor/F)
	if (F.density)
		return FALSE
	if (stat || buckled || paralysis || stunned || sleeping || (status_flags & FAKEDEATH) || restrained() || (weakened > 10))
		return FALSE
	if (!has_limbs)
		src << "<span class = 'red'>You can't even move yourself - you have no limbs!</span>"
		return FALSE
	if (scrambling)
		return FALSE
	if (map.check_caribbean_block(src, F) || map.check_caribbean_block(src, get_turf(src))) // you somehow got here, fuck you - Kachnov
		return FALSE
	var/oloc = loc
	scrambling = TRUE
	lying = TRUE
	facing_dir = dir
	if (dir == NORTH || dir == NORTHWEST || dir == NORTHEAST || dir == WEST)
		dir = WEST
	else
		dir = EAST
	sleep(get_prone_delay())
	var/nloc = loc
	if (nloc == oloc)
		Move(F)
	scrambling = FALSE

/atom/proc/middle_click_intent_check(var/mob/M)
	if (map && map.ID == MAP_FOOTBALL)
		if (ishuman(M))
			var/mob/living/human/H = M
			if (H.football)
				H.football.owner = null
				H.football.last_owner = H
				H.football = null
		jump_act(src, M)
	if (map && map.ID == MAP_FOOTBALL_CAMPAIGN)
		if (ishuman(M))
			var/mob/living/human/H = M
			if (H.football)
				H.football.owner = null
				H.football.last_owner = H
				H.football = null
		jump_act(src, M)
	else
		if(M.middle_click_intent == "kick")
			return kick_act(M)
		else if(M.middle_click_intent == "jump")
			jump_act(src, M)
		else if(M.middle_click_intent == "bite")
			bite_act(M)
		else
			M.swap_hand()
