/*
	Click code cleanup
	~Sayu
*/

// TRUE decisecond click delay (above and beyond mob/next_move)
/mob/var/next_click = FALSE

/*
	Before anything else, defer these calls to a per-mobtype handler.  This allows us to
	remove istype() spaghetti code, but requires the addition of other handler procs to simplify it.

	Alternately, you could hardcode every mob's variation in a flat ClickOn() proc; however,
	that's a lot of code duplication and is hard to maintain.

	Note that this proc can be overridden, and is in the case of screen objects.
*/

/atom/Click(var/location, var/control, var/params) // This is their reaction to being clicked on (standard proc)
	if (src)
		usr.ClickOn(src, params)

/atom/DblClick(var/location, var/control, var/params)
	if (src)
		usr.DblClickOn(src, params)

/*
	Standard mob ClickOn()
	Handles exceptions: Buildmode, middle click, modified clicks, mech actions

	After that, mostly just check your state, check whether you're holding an item,
	check whether you're adjacent to the target, then pass off the click to whoever
	is recieving it.
	The most common are:
	* mob/UnarmedAttack(atom,adjacent) - used here only when adjacent, with no item in hand; in the case of humans, checks gloves
	* atom/attackby(item,user) - used only when adjacent
	* item/afterattack(atom,user,adjacent,params) - used both ranged and adjacent
	* mob/RangedAttack(atom,params) - used only ranged, only used for tk and laser eyes but could be changed
*/

/mob/proc/ClickOn(var/atom/A, var/params)

	if (world.time <= next_click) // Hard check, before anything else, to avoid crashing
		return

	next_click = world.time + 1

	/*if (client.buildmode)
		build_click(src, client.buildmode, params, A)
		return*/

	var/list/modifiers = params2list(params)
	if (modifiers["shift"] && modifiers["ctrl"])
		CtrlShiftClickOn(A)
		return TRUE
	if (modifiers["middle"])
		MiddleClickOn(A)
		return TRUE
	if (modifiers["shift"])
		ShiftClickOn(A)
		return FALSE
	if (modifiers["alt"]) // alt and alt-gr (rightalt)
		AltClickOn(A)
		return TRUE
	if (modifiers["ctrl"])
		CtrlClickOn(A)
		return TRUE

	// can't click on stuff when we're lying, unless it's a bed
	if (ishuman(src))
		var/mob/living/carbon/human/H = src
		if (H.lying)
			if (ismob(A) || (A.loc && istype(A.loc, /turf)))
				if (!istype(A, /obj/structure/bed))
					return

	// can't click on anything when we're hanged
	for (var/obj/structure/noose/N in get_turf(src))
		if (N.hanging == src)
			return

	if (lying && istype(A, /turf/floor))
		if (A.Adjacent(src))
			scramble(A)
			return

	if (stat || paralysis || stunned || weakened)
		return

	face_atom(A) // change direction to face what you clicked on

	if (!canClick()) // in the year 2000...
		return

	if (istype(loc, /obj/tank))
		if (A == loc)
			var/obj/tank/tank = loc
			var/obj/item/ammo_magazine/maxim/hand = get_active_hand()
			var/exit_tank = FALSE
			if (l_hand && r_hand && istype(l_hand, /obj/item/ammo_magazine/maxim) && istype(r_hand, /obj/item/ammo_magazine/maxim))
				if ((WWinput(src, "Exit the tank or replace the MG belt?", "Choose", "Replace MG Belt", list("Exit", "Replace MG Belt"))) == "Exit")
					exit_tank = TRUE
			// reloading the tank MG
			if (hand && istype(hand) && !exit_tank)
				if (tank.MG && tank.MG.magazine_type == hand.type)
					tank.tank_message("<span class = 'warning'>[src] starts to replace the MG belt...</span>")
					if (do_after(src, 50))
						var/obj/item/ammo_magazine/maxim/oldmag = tank.MG.ammo_magazine
						tank.MG.ammo_magazine = hand
						remove_from_mob(hand)
						if (oldmag)
							oldmag.update_icon()
							put_in_any_hand_if_possible(oldmag, prioritize_active_hand = TRUE)
						tank.tank_message("<span class = 'warning'>[src] finishes replacing the MG belt.</span>")
				return
			else
				// leaving the tank
				tank.handle_seat_exit(src)
				return

	// stop looking down a ladder
	if (istype(A, /obj/structure/multiz/ladder/ww2))
		var/mob/living/carbon/human/H = src
		if (istype(H) && H.laddervision)
			H.update_laddervision(null)
			H.visible_message("<span class = 'notice'>[H] stops looking [H.laddervision_direction()] the ladder.</span>")
			return

	if (restrained())
		setClickCooldown(10)
		RestrainedClickOn(A)
		return TRUE

	if (in_throw_mode)
		if (isturf(A) || isturf(A.loc))
			throw_item(A)
			return TRUE
		throw_mode_off()

	var/obj/item/W = get_active_hand()

	if (!W)

		var/atom/movable/special_MG = null
		var/tankcheck = FALSE

		if (using_MG)
			special_MG = using_MG
		else if (istank(loc))
			var/obj/tank/T = loc
			if (T.back_seat() == src && !T.halftrack)
				special_MG = T.MG
				special_MG.dir = T.dir // for dir checks below
				switch (T.dir) // tank sprite memes
					if (NORTH, NORTHEAST, NORTHWEST)
						special_MG.loc = locate(T.x+1, T.y+2, T.z)
					if (SOUTH, SOUTHEAST, SOUTHWEST)
						special_MG.loc = locate(T.x+1, T.y-1, T.z)
					if (EAST)
						special_MG.loc = locate(T.x+3, T.y+2, T.z)
					if (WEST)
						special_MG.loc = locate(T.x-1, T.y+1, T.z)
				tankcheck = TRUE
			else if (T.halftrack)
				special_MG = T.MG
				special_MG.dir = T.dir // for dir checks below
				switch (T.dir) // tank sprite memes
					if (NORTH, NORTHEAST, NORTHWEST)
						special_MG.loc = locate(T.x, T.y+2, T.z)
					if (SOUTH, SOUTHEAST, SOUTHWEST)
						special_MG.loc = locate(T.x, T.y-1, T.z)
					if (EAST)
						special_MG.loc = locate(T.x+3, T.y+1, T.z)
					if (WEST)
						special_MG.loc = locate(T.x-2, T.y+1, T.z)
				tankcheck = TRUE

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

			if (!can_fire)
				goto skip

			MG.Fire(A, src, force = TRUE)

			skip

		if (tankcheck)
			special_MG.loc = null


	if (W == A) // Handle attack_self
		W.attack_self(src)
		if (hand)
			update_inv_l_hand(0)
		else
			update_inv_r_hand(0)
		return TRUE

	//Atoms on your person
	// A is your location but is not a turf; or is on you (backpack); or is on something on you (box in backpack); sdepth is needed here because contents depth does not equate inventory storage depth.
	var/sdepth = A.storage_depth(src)
	if ((!isturf(A) && A == loc) || (sdepth != -1 && sdepth <= 1))
		// faster access to objects already on you
	//	if (A.loc != src)
	//		setMoveCooldown(10) //getting something out of a backpack

		if (W)
			var/resolved = W.resolve_attackby(A, src)
			if (!resolved && A && W)
				W.afterattack(A, src, TRUE, params) // TRUE indicates adjacency
		else
			if (ismob(A)) // No instant mob attacking
				setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
			UnarmedAttack(A, TRUE)
		return TRUE

	if (!isturf(loc)) // This is going to stop you from telekinesing from inside a closet, but I don't shed many tears for that
		return

	//Atoms on turfs (not on your person)
	// A is a turf or is on a turf, or in something on a turf (pen in a box); but not something in something on a turf (pen in a box in a backpack)
	sdepth = A.storage_depth_turf()
	if (isturf(A) || isturf(A.loc) || (sdepth != -1 && sdepth <= 1))
		if (A.Adjacent(src) || (W && W == get_active_hand() && (istype(W, /obj/item/weapon/flamethrower/flammenwerfer) || istype(W, /obj/item/weapon/sandbag))) && A.rangedAdjacent(src)) // see adjacent.dm

			dir = get_dir(src, A)

			if (W && istype(W, /obj/item/weapon/flamethrower/flammenwerfer) && A.rangedAdjacent(src))
				if (get_active_hand() != W)
					return
				var/obj/item/weapon/flamethrower/flammenwerfer/fw = W
				if (fw.lit)
					A = get_turf(A) // make sure we flame a mob's turf, not them
				else
					if (!A.Adjacent(src)) // no punching people with werfers from a distance
						return

			else if (W && istype(W, /obj/item/weapon/sandbag) && A.rangedAdjacent(src) && (isturf(A) || istype(A, /obj/structure/window/sandbag/incomplete)))
				if (get_active_hand() != W)
					return

				if (!istype(A, /obj/structure/window/sandbag/incomplete))
					A = get_turf(A)
				else
					if (!A.Adjacent(src)) // if we're adding to a sandbag wall, let us stand anywhere in range(1)
						return

				var/needs_to_be_in_front = istype(A, /turf)

				if (needs_to_be_in_front) // but if we're making a new sandbag wall, we have to click right in front of us.
					if (A != get_step(src, dir))
						return


		//	setMoveCooldown(5)

			if (W)
				// Return TRUE in attackby() to prevent afterattack() effects (when safely moving items for example)
				var/resolved = W.resolve_attackby(A,src)
				if (!resolved && A && W)
					W.afterattack(A, src, TRUE, params) // TRUE: clicking something Adjacent
			else
				if (ismob(A)) // No instant mob attacking
					setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
				UnarmedAttack(A, TRUE)
			return
		else // non-adjacent click
			if (W)
				W.afterattack(A, src, FALSE, params) // FALSE: not Adjacent
			else
				RangedAttack(A, params)
	return TRUE

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
/mob/proc/UnarmedAttack(var/atom/A, var/proximity_flag)
	return

/mob/living/UnarmedAttack(var/atom/A, var/proximity_flag)

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
	if (!mutations.len) return
/*	if ((LASER in mutations) && a_intent == I_HURT)
		LaserEyes(A) // moved into a proc below
	else */
	/*
	if (TK in mutations)
		switch(get_dist(src,A))
			if (1 to 5) // not adjacent may mean blocked by window
				setMoveCooldown(2)
			if (5 to 7)
				setMoveCooldown(5)
			if (8 to tk_maxrange)
				setMoveCooldown(10)
			else
				return
		A.attack_tk(src)*/
/*
	Restrained ClickOn

	Used when you are handcuffed and click things.
	Not currently used by anything but could easily be.
*/
/mob/proc/RestrainedClickOn(var/atom/A)
	return

/*
	Middle click
	Only used for swapping hands
*/
/mob/proc/MiddleClickOn(var/atom/A)
	swap_hand()
	return

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
	var/turf/T = get_turf(src)
	if (T && user.TurfAdjacent(T))
		if (user.listed_turf == T)
			user.listed_turf = null
		else
			user.listed_turf = T
			user.client.statpanel = "Turf"
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

/*
	Misc helpers

	Laser Eyes: as the name implies, handles this since nothing else does currently
	face_atom: turns the mob towards what you clicked on
*/
/*
/mob/proc/LaserEyes(atom/A)
	return

/mob/living/LaserEyes(atom/A)
	setClickCooldown(4)
	var/turf/T = get_turf(src)

	var/obj/item/projectile/beam/LE = new (T)
	LE.icon = 'icons/effects/genetics.dmi'
	LE.icon_state = "eyelasers"
	playsound(usr.loc, 'sound/weapons/taser2.ogg', 75, TRUE)
	LE.launch(A)

/mob/living/carbon/human/LaserEyes()
	if (nutrition>0)
		..()
		nutrition = max(nutrition - rand(1,5),0)
		handle_regular_hud_updates()
	else
		src << "<span class='warning'>You're out of energy!  You need food!</span>"
*/
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
	if (map.check_prishtina_block(src, F) || map.check_prishtina_block(src, get_turf(src))) // you somehow got here, fuck you - Kachnov
		return FALSE

	var/oloc = loc
	var/slowness = weakened ? 1.50 : 1.00
	scrambling = TRUE
	sleep(9*slowness)
	visible_message("<span class = 'red'><b>[src]</b> crawls!</span>")
	var/nloc = loc
	if (nloc == oloc)
		Move(F)
	scrambling = FALSE