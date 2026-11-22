// Car doors by hand (Val, 2026-11-15).
// A land vehicle's door can be worked with an empty hand. From outside, a shut
// door that isn't locked can be pulled open; from inside, a driver or passenger
// can take hold of it on grab intent and hold it shut. The hold is an item in
// the hand that uses the generic tightened grip (grip.dm): "Tighten or Loosen
// Grip" or using it in hand braces it, a fall can shake a loose hold free, and a
// blow to the hand can break it. Someone outside yanking on a held door starts a
// contest of strength against the hold. Locked doors stay locked from outside:
// only the vehicle's key opens them there. Inside, the handle or the emergency
// release opens a locked door (vehicle_exits.dm). Everything runs on clicks and moves; nothing ticks.

#define CAR_DOOR_YANK_TIME 12			// ds of pulling before each yank resolves
#define CAR_DOOR_TIGHT_GRIP 1.75		// a tightened hold counts this much more
#define CAR_DOOR_BOTH_HANDS 1.25		// pulling with both hands free
#define CAR_DOOR_BRACE_TIME 10			// ds after taking hold before it is braced
#define CAR_DOOR_UNBRACED 0.6			// an unbraced hold counts this much
#define CAR_DOOR_STRAIN_PER_YANK 0.15	// each yank held off tires the holder
#define CAR_DOOR_STRAIN_MAX 0.6
#define CAR_DOOR_STRAIN_RECOVERY 0.05	// strain recovered per second of rest

/obj/structure/vehicleparts/frame
	// A frame with a lock (a door code or a car key) keeps its doors locked
	// while shut until its key unlocks them. A door shut by hand stays unlocked.
	var/door_unlocked = FALSE
	var/tmp/obj/item/car_door_hold/door_hold = null

// Walls with a working door or hatch on this frame.
/obj/structure/vehicleparts/frame/proc/opening_walls()
	. = list()
	for (var/list/wall in list(w_front, w_back, w_left, w_right))
		if (wall.len >= 7 && wall[6])
			. += list(wall)

// Land vehicle doors only: ships and submarines keep their own hatches.
/obj/structure/vehicleparts/frame/proc/has_hand_door()
	if (istype(src, /obj/structure/vehicleparts/frame/ship))
		return FALSE
	for (var/list/wall in opening_walls())
		if (findtext(wall[1], "door"))
			return TRUE
	return FALSE

/obj/structure/vehicleparts/frame/proc/doors_open()
	for (var/list/wall in opening_walls())
		if (wall[7])
			return TRUE
	return FALSE

/obj/structure/vehicleparts/frame/proc/has_door_lock()
	return doorcode || axis?.keyed_vehicle_id

/obj/structure/vehicleparts/frame/proc/doors_locked()
	return has_door_lock() && !door_unlocked && !doors_open()

// Opens or shuts every door on the frame, and the matching doors of a
// convertible's roof sections beside it.
/obj/structure/vehicleparts/frame/proc/set_doors_open(open)
	open = open ? TRUE : FALSE
	for (var/list/wall in opening_walls())
		wall[7] = open
	if (removesroof)
		for (var/obj/structure/vehicleparts/frame/VP in range(1, loc))
			if (VP == src || VP.axis != axis || !VP.removesroof)
				continue
			for (var/list/W in VP.opening_walls())
				W[7] = open
			VP.door_unlocked = door_unlocked
			VP.noroof = open
			VP.update_icon()
		noroof = open
	if (open && door_hold)
		door_hold.release(TRUE)
	update_icon()

// A matching key: an open door shuts and locks, a shut unlocked door locks,
// and a locked door unlocks and swings open.
/obj/structure/vehicleparts/frame/proc/key_turn_doors(mob/living/human/H)
	if (!opening_walls().len)
		return FALSE
	if (doors_open() || door_unlocked)
		door_unlocked = FALSE
		set_doors_open(FALSE)
		if (H)
			H.visible_message("[H] locks the door.")
	else
		door_unlocked = TRUE
		set_doors_open(TRUE)
		if (H)
			H.visible_message("[H] unlocks the door.")
	playsound(loc, 'sound/effects/door_lock_unlock.ogg', 100)
	if (H)
		H.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	return TRUE

// Inside: standing on this frame, or on a frame of the same vehicle next to it.
// Riders on the roof are outside.
/obj/structure/vehicleparts/frame/proc/door_inside(mob/living/human/H)
	if (!H || H.vehicle_deck || !isturf(H.loc))
		return FALSE
	if (H.loc == loc)
		return TRUE
	if (!axis || get_dist(H, src) > 1)
		return FALSE
	for (var/obj/structure/vehicleparts/frame/F in H.loc)
		if (F.axis == axis)
			return TRUE
	return FALSE

/obj/structure/vehicleparts/frame/proc/door_held()
	if (door_hold && !door_hold.valid_hold())
		door_hold.release()
	return door_hold

/obj/structure/vehicleparts/frame/attack_hand(mob/living/human/user)
	if (!ishuman(user) || user.vehicle_deck || !Adjacent(user) || !has_hand_door())
		return ..()
	if (user.stat != CONSCIOUS || user.restrained())
		return
	if (door_inside(user))
		inside_door_hand(user)
	else
		outside_door_hand(user)

/obj/structure/vehicleparts/frame/proc/shut_door_by_hand(mob/living/human/user)
	door_unlocked = TRUE
	set_doors_open(FALSE)
	playsound(loc, 'sound/effects/door_lock_unlock.ogg', 40)
	user.visible_message("[user] pulls the door of \the [src] shut.", "You pull the door shut.")
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)

/obj/structure/vehicleparts/frame/proc/inside_door_hand(mob/living/human/user)
	if (user.a_intent == I_GRAB)
		take_door_hold(user)
		return
	if (doors_open())
		shut_door_by_hand(user)
		return
	if (doors_locked())
		inside_release(user)
		return
	var/obj/item/car_door_hold/hold = door_held()
	if (hold && hold.holder != user)
		to_chat(user, SPAN_WARNING("[hold.holder] is holding the door shut."))
		return
	set_doors_open(TRUE)
	playsound(loc, 'sound/effects/door_lock_unlock.ogg', 40)
	user.visible_message("[user] opens the door of \the [src].", "You open the door.")
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)

/obj/structure/vehicleparts/frame/proc/take_door_hold(mob/living/human/user)
	var/obj/item/car_door_hold/hold = door_held()
	if (hold)
		if (hold.holder == user)
			hold.toggle_grip(user)
		else
			to_chat(user, SPAN_WARNING("[hold.holder] already has hold of the door."))
		return FALSE
	if (user.get_active_hand())
		to_chat(user, SPAN_WARNING("You need a free hand to hold the door."))
		return FALSE
	if (doors_open())
		shut_door_by_hand(user)
	hold = new /obj/item/car_door_hold(get_turf(user))
	if (!hold.attach(user, src))
		qdel(hold)
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] grabs hold of the door of \the [src]."), SPAN_NOTICE("You grab hold of the door. Tighten your grip to brace it against anyone pulling from outside."))
	return TRUE

/obj/structure/vehicleparts/frame/proc/outside_door_hand(mob/living/human/user)
	if (doors_open())
		shut_door_by_hand(user)
		return
	if (doors_locked())
		playsound(loc, 'sound/effects/door_lock_unlock.ogg', 25)
		user.visible_message(SPAN_WARNING("[user] tugs at the door of \the [src], but it's locked."), SPAN_WARNING("You tug at the door, but it's locked."))
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		return
	if (!door_held())
		set_doors_open(TRUE)
		playsound(loc, 'sound/effects/door_lock_unlock.ogg', 40)
		user.visible_message("[user] pulls open the door of \the [src].", "You pull the door open.")
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		return
	yank_door(user)

// Someone outside pulls on a door someone inside is holding shut.
/obj/structure/vehicleparts/frame/proc/yank_door(mob/living/human/user)
	var/obj/item/car_door_hold/hold = door_hold
	user.visible_message(SPAN_WARNING("[user] grabs the door of \the [src] and starts yanking on it!"), SPAN_WARNING("Someone is holding the door shut. You start yanking on it!"))
	if (hold.holder)
		to_chat(hold.holder, SPAN_DANGER("[user] is yanking on the door you're holding!"))
	if (!do_after(user, CAR_DOOR_YANK_TIME, src))
		return FALSE
	if (QDELETED(src) || !Adjacent(user) || door_inside(user) || doors_open())
		return FALSE
	if (doors_locked())
		to_chat(user, SPAN_WARNING("The door has been locked."))
		return FALSE
	hold = door_held()
	if (!hold)
		set_doors_open(TRUE)
		user.visible_message(SPAN_WARNING("[user] yanks the door of \the [src] open!"), SPAN_NOTICE("The door gives way and swings open."))
		playsound(loc, 'sound/effects/door_lock_unlock.ogg', 60)
		return TRUE
	var/mob/living/human/holder = hold.holder
	var/pull = car_door_pull_strength(user)
	var/resist = hold.resist_strength()
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	if (prob(car_door_yank_chance(pull, resist)))
		hold.release(TRUE)
		set_doors_open(TRUE)
		playsound(loc, 'sound/effects/door_lock_unlock.ogg', 80)
		user.visible_message(SPAN_DANGER("[user] yanks the door of \the [src] open, tearing it out of [holder]'s grip!"), SPAN_NOTICE("You yank the door open!"))
		to_chat(holder, SPAN_DANGER("The door is torn out of your grip!"))
		return TRUE
	hold.add_strain()
	playsound(loc, 'sound/effects/door_lock_unlock.ogg', 40)
	user.visible_message(SPAN_WARNING("[holder] holds the door of \the [src] shut against [user]'s yank!"), SPAN_WARNING("The door won't budge; someone is holding it shut."))
	to_chat(holder, SPAN_NOTICE("You hold the door shut, but your arm is tiring."))
	return FALSE

/proc/car_door_pull_strength(mob/living/human/H)
	. = max(0.1, H.getStatCoeff("strength"))
	if (H.has_empty_hand(TRUE))
		. *= CAR_DOOR_BOTH_HANDS

// Chance (percent) a yank tears the door free.
/proc/car_door_yank_chance(pull, resist)
	if (resist <= 0)
		return 100
	return clamp(round(100 * pull / (pull + resist)), 5, 95)

/obj/structure/vehicleparts/frame/examine(mob/user, distance = -1)
	. = ..()
	if (user && has_belly_hatch() && door_inside(user))
		to_chat(user, SPAN_NOTICE("Her escape hatch is in the floor: right-click her to drop through it while she is stopped."))
	if (!user || get_dist(user, src) > 3 || !has_hand_door())
		return
	var/state = doors_open() ? "open" : (doors_locked() ? "shut and locked" : "shut")
	to_chat(user, SPAN_NOTICE("Its door is [state][door_inside(user) && doors_locked() ? ": the inside release opens it" : ""]."))
	var/obj/item/car_door_hold/hold = door_held()
	if (hold)
		to_chat(user, SPAN_NOTICE("[hold.holder] is holding it shut[hold.grip_tightened ? " with a tight grip" : ""]."))

// The hand on the door. Dropping it lets go.
/obj/item/car_door_hold
	name = "car door"
	desc = "You're holding a car door shut. Tighten your grip to brace it against anyone pulling from outside; drop it to let go."
	icon = 'icons/mob/screen/1713Style.dmi'
	icon_state = "grabbed"
	item_state = "nothing"
	abstract = TRUE
	w_class = ITEM_SIZE_HUGE
	grip_tightenable = TRUE
	jostle_drop_chance = 60
	should_save = FALSE
	var/tmp/obj/structure/vehicleparts/frame/door_frame = null
	var/tmp/mob/living/human/holder = null
	var/tmp/hold_started = 0
	var/tmp/strain = 0
	var/tmp/strain_time = 0
	var/tmp/released = FALSE

/obj/item/car_door_hold/proc/attach(mob/living/human/user, obj/structure/vehicleparts/frame/F)
	if (!user || !F || !user.put_in_active_hand(src))
		return FALSE
	holder = user
	door_frame = F
	F.door_hold = src
	hold_started = world.time
	strain_time = world.time
	name = "[F.name] door"
	GLOB.moved_event.register(holder, src, /obj/item/car_door_hold/proc/holder_moved)
	return TRUE

/obj/item/car_door_hold/proc/valid_hold()
	if (released || !holder || !door_frame || QDELETED(holder) || QDELETED(door_frame))
		return FALSE
	if (!held_by(holder) || holder.stat != CONSCIOUS || holder.restrained())
		return FALSE
	return door_frame.door_inside(holder) && !door_frame.doors_open()

// The vehicle moves its riders and frames one after another; check once it settles.
/obj/item/car_door_hold/proc/holder_moved(atom/movable/mover, atom/old_loc, atom/new_loc)
	addtimer(CALLBACK(src, PROC_REF(check_hold)), 1)

/obj/item/car_door_hold/proc/check_hold()
	if (!released && !valid_hold())
		release()

/obj/item/car_door_hold/proc/current_strain()
	return max(0, strain - CAR_DOOR_STRAIN_RECOVERY * (world.time - strain_time) / 10)

/obj/item/car_door_hold/proc/add_strain()
	strain = min(CAR_DOOR_STRAIN_MAX, current_strain() + CAR_DOOR_STRAIN_PER_YANK)
	strain_time = world.time

// How hard the hold resists a yank: strength, a tightened grip, whether it was
// braced in time, and how tired the arm is.
/obj/item/car_door_hold/proc/resist_strength()
	if (!valid_hold())
		return 0
	. = max(0.1, holder.getStatCoeff("strength"))
	if (grip_tightened)
		. *= CAR_DOOR_TIGHT_GRIP
	if (world.time - hold_started < CAR_DOOR_BRACE_TIME)
		. *= CAR_DOOR_UNBRACED
	. *= 1 - current_strain()

/obj/item/car_door_hold/attack_self(mob/user)
	toggle_grip(user)

/obj/item/car_door_hold/set_grip(mob/user, tight, silent = FALSE)
	. = ..()
	// Re-gripping takes a moment to brace again.
	if (. && tight)
		hold_started = world.time

// A blow to the hand can break the hold like any held item.
/obj/item/car_door_hold/can_be_knocked_from_hand(mob/living/human/H)
	return held_by(H)

/obj/item/car_door_hold/knocked_from_hand(mob/living/human/H)
	release()
	return TRUE

/obj/item/car_door_hold/dropped(mob/user)
	..()
	release()

/obj/item/car_door_hold/proc/release(silent = FALSE)
	if (released)
		return
	released = TRUE
	var/mob/living/human/H = holder
	if (H)
		GLOB.moved_event.unregister(H, src, /obj/item/car_door_hold/proc/holder_moved)
	if (door_frame && door_frame.door_hold == src)
		door_frame.door_hold = null
	holder = null
	door_frame = null
	if (H && (H.l_hand == src || H.r_hand == src))
		H.remove_from_mob(src)
		if (!silent)
			to_chat(H, SPAN_NOTICE("You let go of the door."))
	if (!QDELETED(src))
		qdel(src)

/obj/item/car_door_hold/Destroy()
	release(TRUE)
	return ..()

// Grab hold of the door of the vehicle you're in without having to click it.
/mob/living/human/verb/hold_car_door()
	set name = "Hold Car Door"
	set desc = "Grab hold of the door beside you and hold it shut, or let go of it."
	set category = "IC"
	if (stat != CONSCIOUS || restrained())
		return
	for (var/obj/item/car_door_hold/hold in list(l_hand, r_hand))
		hold.release()
		return
	var/obj/structure/vehicleparts/frame/best = null
	for (var/obj/structure/vehicleparts/frame/F in range(1, src))
		if (!F.has_hand_door() || !F.door_inside(src))
			continue
		if (!best || (F.loc == loc && best.loc != loc))
			best = F
	if (!best)
		to_chat(src, SPAN_WARNING("There is no car door beside you."))
		return
	best.take_door_hold(src)

#undef CAR_DOOR_YANK_TIME
#undef CAR_DOOR_TIGHT_GRIP
#undef CAR_DOOR_BOTH_HANDS
#undef CAR_DOOR_BRACE_TIME
#undef CAR_DOOR_UNBRACED
#undef CAR_DOOR_STRAIN_PER_YANK
#undef CAR_DOOR_STRAIN_MAX
#undef CAR_DOOR_STRAIN_RECOVERY
