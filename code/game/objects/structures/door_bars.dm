// Bars, bolts and bracing (Val, 2026-11-16: doors barred from either side,
// with interactions that depend on the side you work them from).
//
// Brackets are fitted to one side of a door. With the door shut, a bar dropped
// into them keeps it shut from both sides; only someone on the bar's side can
// lift it out again. A slide bolt is a small bar fitted on the door itself:
// quick to throw, but weaker. Kicks, blows, rams and siege hits wear down the
// bars and bolt before the door. Anyone can also brace a shut door with their
// body on grab intent; whoever pulls on it from the other side then has to win
// a contest of strength, the same one as holding a car door shut.
// Everything here runs on clicks; nothing ticks.

#define DOOR_BAR_DROP_TIME 10		// ds to drop a bar in or lift it out
#define DOOR_BAR_FIT_TIME 80		// ds to fit brackets or a bolt
#define DOOR_BRACE_YANK_TIME 12		// ds of pulling before each yank resolves
#define DOOR_BRACE_TIGHT 1.75		// a tightened hold counts this much more
#define DOOR_BRACE_TIME 10			// ds after bracing before it holds fully
#define DOOR_BRACE_UNBRACED 0.6
#define DOOR_BRACE_STRAIN_PER_YANK 0.15
#define DOOR_BRACE_STRAIN_MAX 0.6
#define DOOR_BRACE_STRAIN_RECOVERY 0.05

/obj/structure/simple_door
	var/list/door_brackets = null		// sides (dirs) with bar brackets
	var/list/door_bar_kind = null		// "[side]" = "wood" or "iron" while barred
	var/list/door_bar_health = null		// "[side]" = health left in that bar
	var/door_bolt_side = 0				// the side the slide bolt is on, 0 for none
	var/door_bolt_shot = FALSE
	var/door_bolt_health = 100

// ---- state ----------------------------------------------------------------------

/obj/structure/simple_door/proc/door_bar_on(side)
	return door_bar_kind && door_bar_kind["[side]"]

/obj/structure/simple_door/proc/door_has_brackets(side)
	return door_brackets && (side in door_brackets)

// Barred or bolted: shut against everyone until it is lifted or broken.
/obj/structure/simple_door/proc/door_barred()
	if (door_bar_kind && door_bar_kind.len)
		return TRUE
	return door_bolt_side && door_bolt_shot

/obj/structure/simple_door/proc/door_bar_name(kind)
	return kind == "iron" ? "iron bar" : "wooden bar"

/obj/structure/simple_door/proc/door_bar_item_type(kind)
	return kind == "iron" ? /obj/item/door_bar/iron : /obj/item/door_bar

// Someone other than the user bracing the door shut.
/obj/structure/simple_door/proc/door_braced_against(mob/user)
	var/obj/item/door_hold/brace/B = door_held()
	return istype(B) && B.holder != user

// "your side" or "the far side", for examine and messages.
/obj/structure/simple_door/proc/door_side_words(side, mob/user)
	var/mine = user ? door_side_of(user) : 0
	if (mine && mine == side)
		return "on your side"
	if (mine)
		return "on the far side"
	return "on its [dir2text(side)] side"

// ---- wear ------------------------------------------------------------------------

// Blows against a barred door land on the bars and bolt first. Returns the
// damage left over for the door itself.
/obj/structure/simple_door/proc/door_bar_absorb(amount)
	if (amount <= 0 || state || !door_barred())
		return amount
	if (door_bar_kind)
		for (var/key in door_bar_kind.Copy())
			if (amount <= 0)
				break
			var/hp = door_bar_health["[key]"]
			var/taken = min(amount, hp)
			hp -= taken
			amount -= taken
			if (hp <= 0)
				visible_message(SPAN_DANGER("The [door_bar_name(door_bar_kind[key])] across \the [src] snaps!"))
				playsound(get_turf(src), 'sound/effects/wooddoorhit.ogg', 100)
				door_bar_kind -= key
				door_bar_health -= key
			else
				door_bar_health[key] = hp
	if (amount > 0 && door_bolt_side && door_bolt_shot)
		var/taken = min(amount, door_bolt_health)
		door_bolt_health -= taken
		amount -= taken
		if (door_bolt_health <= 0)
			visible_message(SPAN_DANGER("The bolt of \the [src] is torn out!"))
			door_bolt_side = 0
			door_bolt_shot = FALSE
			door_bolt_health = initial(door_bolt_health)
	if (door_bar_kind && !door_bar_kind.len)
		door_bar_kind = null
		door_bar_health = null
	update_fitting_overlays()
	return amount

// ---- hands on a shut door ---------------------------------------------------

// Returns TRUE when bars, a bolt or a brace handled the hand.
/obj/structure/simple_door/proc/door_bar_hand(mob/user)
	if (state || isSwitchingStates || !ishuman(user))
		return FALSE
	var/mob/living/human/H = user
	if (H.stat != CONSCIOUS || H.restrained() || get_dist(H, src) > 1)
		return FALSE
	var/side = door_side_of(H)
	if (!side)
		return FALSE
	if (H.a_intent == I_HELP)
		if (door_bar_on(side))
			return lift_door_bar(H, side)
		if (door_bolt_side == side && door_bolt_shot)
			door_bolt_shot = FALSE
			playsound(get_turf(src), 'sound/effects/door_lock_unlock.ogg', 50)
			H.visible_message(SPAN_NOTICE("[H] draws the bolt of \the [src]."), SPAN_NOTICE("You draw the bolt."))
			update_fitting_overlays()
			return TRUE
		if (door_barred())
			if (door_noise_ready())
				H.visible_message(SPAN_NOTICE("[H] pushes on \the [src], but it won't budge."), SPAN_WARNING("It won't budge. It's barred from the other side."))
				playsound(get_turf(src), 'sound/effects/wooddoorhit.ogg', 40)
			return TRUE
		if (door_braced_against(H))
			yank_braced_door(H)
			return TRUE
		return FALSE
	if (H.a_intent == I_GRAB)
		if (door_bolt_side == side && !door_bolt_shot)
			door_bolt_shot = TRUE
			playsound(get_turf(src), 'sound/effects/door_lock_unlock.ogg', 60)
			H.visible_message(SPAN_NOTICE("[H] shoots the bolt of \the [src]."), SPAN_NOTICE("You shoot the bolt."))
			update_fitting_overlays()
			return TRUE
		take_door_brace(H)
		return TRUE
	return FALSE

/obj/structure/simple_door/proc/lift_door_bar(mob/living/human/user, side)
	if (user.get_active_hand())
		to_chat(user, SPAN_WARNING("You need a free hand to lift the bar."))
		return TRUE
	var/kind = door_bar_kind["[side]"]
	user.visible_message(SPAN_NOTICE("[user] starts lifting the bar off \the [src]."), SPAN_NOTICE("You start lifting the bar."))
	if (!do_after(user, DOOR_BAR_DROP_TIME, src))
		return TRUE
	if (QDELETED(src) || !door_bar_on(side) || door_side_of(user) != side || user.get_active_hand())
		return TRUE
	var/path = door_bar_item_type(kind)
	var/obj/item/door_bar/B = new path(get_turf(user))
	B.bar_health = door_bar_health["[side]"]
	door_bar_kind -= "[side]"
	door_bar_health -= "[side]"
	if (!door_bar_kind.len)
		door_bar_kind = null
		door_bar_health = null
	user.put_in_hands(B)
	playsound(get_turf(src), 'sound/effects/wooddoorhit.ogg', 30)
	user.visible_message(SPAN_NOTICE("[user] lifts the bar off \the [src]."), SPAN_NOTICE("You lift the bar out of its brackets."))
	update_fitting_overlays()
	return TRUE

// ---- bracing with your body ---------------------------------------------------

/obj/structure/simple_door/proc/take_door_brace(mob/living/human/user)
	var/obj/item/door_hold/hold = door_held()
	if (hold)
		if (hold.holder == user)
			hold.toggle_grip(user)
		else
			to_chat(user, SPAN_WARNING("[hold.holder] is already bracing the door."))
		return FALSE
	if (user.get_active_hand())
		to_chat(user, SPAN_WARNING("You need a free hand to brace the door."))
		return FALSE
	var/obj/item/door_hold/brace/B = new(get_turf(user))
	if (!B.attach(user, src))
		qdel(B)
		return FALSE
	B.hold_started = world.time
	B.strain_time = world.time
	user.visible_message(SPAN_NOTICE("[user] braces \the [src] shut."), SPAN_NOTICE("You brace the door shut with your body. Tighten your grip to hold it harder; drop it to let go."))
	return TRUE

// Someone pulls on a door that someone else is bracing shut.
/obj/structure/simple_door/proc/yank_braced_door(mob/living/human/user)
	var/obj/item/door_hold/brace/B = door_held()
	if (!istype(B))
		return FALSE
	user.visible_message(SPAN_WARNING("[user] throws their weight against \the [src]!"), SPAN_WARNING("Someone is holding the door shut. You push against it!"))
	if (B.holder)
		to_chat(B.holder, SPAN_DANGER("[user] is forcing the door you're bracing!"))
	if (!do_after(user, DOOR_BRACE_YANK_TIME, src))
		return FALSE
	if (QDELETED(src) || state || get_dist(user, src) > 1 || door_barred())
		return FALSE
	B = door_held()
	if (!istype(B))
		return TryToSwitchState(user)
	var/mob/living/human/holder = B.holder
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	if (prob(car_door_yank_chance(car_door_pull_strength(user), B.resist_strength())))
		B.release(TRUE)
		to_chat(holder, SPAN_DANGER("The door is forced out of your grip!"))
		user.visible_message(SPAN_DANGER("[user] forces \the [src] open!"), SPAN_NOTICE("You force the door open!"))
		return TryToSwitchState(user)
	B.add_strain()
	playsound(get_turf(src), 'sound/effects/wooddoorhit.ogg', 50)
	user.visible_message(SPAN_WARNING("[holder] holds \the [src] shut against [user]!"), SPAN_WARNING("The door won't give; someone is holding it shut."))
	to_chat(holder, SPAN_NOTICE("You hold the door shut, but you're tiring."))
	return FALSE

/obj/item/door_hold/brace
	desc = "You're bracing a door shut. Tighten your grip to hold it harder; drop it to let go."
	grip_tightenable = TRUE
	jostle_drop_chance = 60
	var/tmp/hold_started = 0
	var/tmp/strain = 0
	var/tmp/strain_time = 0

/obj/item/door_hold/brace/valid_hold()
	if (released || !holder || !door || QDELETED(holder) || QDELETED(door))
		return FALSE
	if (!held_by(holder) || holder.stat != CONSCIOUS || holder.restrained())
		return FALSE
	return !door.state && get_dist(holder, door) <= 1 && holder.z == door.z && door.door_side_of(holder)

/obj/item/door_hold/brace/attack_self(mob/user)
	toggle_grip(user)

/obj/item/door_hold/brace/set_grip(mob/user, tight, silent = FALSE)
	. = ..()
	if (. && tight)
		hold_started = world.time

/obj/item/door_hold/brace/proc/current_strain()
	return max(0, strain - DOOR_BRACE_STRAIN_RECOVERY * (world.time - strain_time) / 10)

/obj/item/door_hold/brace/proc/add_strain()
	strain = min(DOOR_BRACE_STRAIN_MAX, current_strain() + DOOR_BRACE_STRAIN_PER_YANK)
	strain_time = world.time

/obj/item/door_hold/brace/proc/resist_strength()
	if (!valid_hold())
		return 0
	. = max(0.1, holder.getStatCoeff("strength"))
	if (grip_tightened)
		. *= DOOR_BRACE_TIGHT
	if (world.time - hold_started < DOOR_BRACE_TIME)
		. *= DOOR_BRACE_UNBRACED
	. *= 1 - current_strain()

// ---- items on the door ----------------------------------------------------------

// Bar items, brackets, bolts and a hammer for taking them off. TRUE when handled.
/obj/structure/simple_door/proc/door_bar_attackby(obj/item/W, mob/living/human/user)
	if (istype(W, /obj/item/door_bar))
		drop_door_bar(W, user)
		return TRUE
	if (istype(W, /obj/item/door_brackets) || istype(W, /obj/item/door_bolt))
		fit_door_bar_part(W, user)
		return TRUE
	if (user.a_intent != I_HARM && is_tool(W, TOOL_HAMMER))
		var/side = door_side_of(user)
		if (side && ((door_bolt_side == side && !door_bolt_shot) || (door_has_brackets(side) && !door_bar_on(side))))
			return remove_door_bar_part(W, user, side)
	return FALSE

/obj/structure/simple_door/proc/drop_door_bar(obj/item/door_bar/B, mob/living/human/user)
	var/side = door_side_of(user)
	if (state)
		to_chat(user, SPAN_WARNING("Shut \the [src] first."))
		return FALSE
	if (!side || !door_has_brackets(side))
		to_chat(user, SPAN_WARNING("There are no bar brackets on your side of \the [src]."))
		return FALSE
	if (door_bar_on(side))
		to_chat(user, SPAN_WARNING("\The [src] is already barred on your side."))
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] starts dropping \the [B] into the brackets of \the [src]."), SPAN_NOTICE("You start dropping the bar into place."))
	if (!do_after(user, DOOR_BAR_DROP_TIME, src))
		return FALSE
	if (QDELETED(src) || QDELETED(B) || state || isSwitchingStates || user.get_active_hand() != B || door_side_of(user) != side || door_bar_on(side))
		return FALSE
	if (!door_bar_kind)
		door_bar_kind = list()
		door_bar_health = list()
	door_bar_kind["[side]"] = B.bar_kind
	door_bar_health["[side]"] = B.bar_health
	user.drop_from_inventory(B)
	qdel(B)
	var/obj/item/door_hold/hold = door_held()
	if (hold)
		hold.release(TRUE)
	playsound(get_turf(src), 'sound/effects/wooddoorhit.ogg', 60)
	user.visible_message(SPAN_NOTICE("[user] bars \the [src]."), SPAN_NOTICE("You bar the door. Only someone on your side can lift the bar."))
	update_fitting_overlays()
	return TRUE

/obj/structure/simple_door/proc/fit_door_bar_part(obj/item/W, mob/living/human/user)
	var/side = door_side_of(user)
	var/is_bolt = istype(W, /obj/item/door_bolt)
	if (!side)
		to_chat(user, SPAN_WARNING("Stand on one side of \the [src] to fit \the [W] to that side."))
		return FALSE
	if (is_bolt ? door_bolt_side : door_has_brackets(side))
		to_chat(user, SPAN_WARNING(is_bolt ? "\The [src] already has a bolt." : "\The [src] already has bar brackets on your side."))
		return FALSE
	if (!door_tool_in_hands(user, TOOL_HAMMER))
		to_chat(user, SPAN_WARNING("Hold a hammer in your other hand to fit \the [W]."))
		return FALSE
	if (door_barred())
		to_chat(user, SPAN_WARNING("\The [src] is barred. Lift the bar first."))
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] starts fitting \the [W] to \the [src]."), SPAN_NOTICE("You start fitting \the [W] to your side of \the [src]."))
	if (!do_after(user, DOOR_BAR_FIT_TIME, src))
		return FALSE
	if (QDELETED(src) || QDELETED(W) || user.get_active_hand() != W || door_side_of(user) != side)
		return FALSE
	if (is_bolt ? door_bolt_side : door_has_brackets(side))
		return FALSE
	if (is_bolt)
		var/obj/item/door_bolt/bolt = W
		door_bolt_side = side
		door_bolt_shot = FALSE
		door_bolt_health = bolt.bolt_health
	else
		if (!door_brackets)
			door_brackets = list()
		door_brackets += side
	user.drop_from_inventory(W)
	qdel(W)
	playsound(get_turf(src), 'sound/items/Ratchet.ogg', 50, TRUE)
	user.visible_message(SPAN_NOTICE("[user] fits [is_bolt ? "a bolt" : "bar brackets"] to \the [src]."), SPAN_NOTICE(is_bolt ? "You fit the bolt. Use grab intent on the shut door to shoot it, and an empty hand to draw it." : "You fit the brackets. Drop a bar into them with the door shut to bar it."))
	update_fitting_overlays()
	return TRUE

/obj/structure/simple_door/proc/remove_door_bar_part(obj/item/W, mob/living/human/user, side)
	var/bolt = door_bolt_side == side && !door_bolt_shot
	user.visible_message(SPAN_NOTICE("[user] starts prising [bolt ? "the bolt" : "the bar brackets"] off \the [src]."), SPAN_NOTICE("You start taking [bolt ? "the bolt" : "the brackets"] off."))
	if (!do_after(user, DOOR_BAR_FIT_TIME / 2, src))
		return TRUE
	if (QDELETED(src) || user.get_active_hand() != W || door_side_of(user) != side)
		return TRUE
	var/turf/T = get_turf(user)
	if (bolt)
		if (door_bolt_side != side || door_bolt_shot)
			return TRUE
		var/obj/item/door_bolt/B = new(T)
		B.bolt_health = door_bolt_health
		door_bolt_side = 0
		door_bolt_health = initial(door_bolt_health)
		user.put_in_hands(B)
	else
		if (!door_has_brackets(side) || door_bar_on(side))
			return TRUE
		door_brackets -= side
		if (!door_brackets.len)
			door_brackets = null
		user.put_in_hands(new /obj/item/door_brackets(T))
	to_chat(user, SPAN_NOTICE("You take [bolt ? "the bolt" : "the brackets"] off."))
	update_fitting_overlays()
	return TRUE

// ---- display, take-down and wreckage -------------------------------------------

/obj/structure/simple_door/proc/door_bar_overlay_states()
	. = list()
	if (state)
		return
	if (door_bar_kind && door_bar_kind.len)
		var/first = door_bar_kind[1]
		. += "bar_[door_bar_kind[first]]"
	else if (door_brackets && door_brackets.len)
		. += "brackets"
	if (door_bolt_side)
		. += door_bolt_shot ? "bolt_shut" : "bolt_open"

/obj/structure/simple_door/proc/door_bar_examine(mob/user)
	if (door_brackets)
		for (var/side in door_brackets)
			if (door_bar_on(side))
				to_chat(user, SPAN_NOTICE("It is barred with a [door_bar_name(door_bar_kind["[side]"])] [door_side_words(side, user)]."))
			else
				to_chat(user, SPAN_NOTICE("It has bar brackets [door_side_words(side, user)]."))
	if (door_bolt_side)
		to_chat(user, SPAN_NOTICE("It has a bolt [door_side_words(door_bolt_side, user)], [door_bolt_shot ? "shot" : "drawn back"]."))
	var/obj/item/door_hold/brace/B = door_held()
	if (istype(B))
		to_chat(user, SPAN_NOTICE("[B.holder] is bracing it shut[B.grip_tightened ? " with all their weight" : ""]."))

// Fittings returned when the door is taken down; it is never barred by then.
/obj/structure/simple_door/proc/door_bar_parts_returned(turf/T)
	if (!T)
		return
	if (door_brackets)
		for (var/side in door_brackets)
			new /obj/item/door_brackets(T)
		door_brackets = null
	if (door_bolt_side)
		var/obj/item/door_bolt/B = new(T)
		B.bolt_health = door_bolt_health
		door_bolt_side = 0

// A smashed door drops its bars; its brackets and bolt go with it.
/obj/structure/simple_door/proc/door_bars_destroyed()
	var/turf/T = get_turf(src)
	if (T && door_bar_kind)
		for (var/key in door_bar_kind)
			var/path = door_bar_item_type(door_bar_kind[key])
			var/obj/item/door_bar/B = new path(T)
			B.bar_health = door_bar_health[key]
	door_bar_kind = null
	door_bar_health = null
	door_brackets = null
	door_bolt_side = 0

// ---- items ---------------------------------------------------------------------------

/obj/item/door_bar
	name = "wooden bar"
	desc = "A heavy timber beam. Drop it into the bar brackets of a shut door, from the brackets' side, to bar the door against both sides."
	icon = 'icons/obj/doors/door_bars.dmi'
	icon_state = "item_bar_wood"
	w_class = ITEM_SIZE_LARGE
	force = 10
	var/bar_kind = "wood"
	var/bar_health = 150

/obj/item/door_bar/iron
	name = "iron bar"
	desc = "A forged iron bar. Drop it into the bar brackets of a shut door, from the brackets' side, to bar the door against both sides."
	icon_state = "item_bar_iron"
	force = 14
	bar_kind = "iron"
	bar_health = 400

/obj/item/door_bar/examine(mob/user, distance = -1)
	. = ..()
	if (bar_health < initial(bar_health))
		to_chat(user, SPAN_WARNING("It is cracked and dented."))

/obj/item/door_brackets
	name = "bar brackets"
	desc = "A pair of timber hooks for pegging to one side of a door. With a hammer in your other hand, use them on the door from the side you want them on."
	icon = 'icons/obj/doors/door_bars.dmi'
	icon_state = "item_brackets"
	w_class = ITEM_SIZE_NORMAL

/obj/item/door_bolt
	name = "slide bolt"
	desc = "An iron slide bolt with its keeper. With a hammer in your other hand, use it on a door from the side you want it on. It is quicker to throw than a bar, but weaker."
	icon = 'icons/obj/doors/door_bars.dmi'
	icon_state = "item_bolt"
	w_class = ITEM_SIZE_SMALL
	var/bolt_health = 100

#undef DOOR_BAR_DROP_TIME
#undef DOOR_BAR_FIT_TIME
#undef DOOR_BRACE_YANK_TIME
#undef DOOR_BRACE_TIGHT
#undef DOOR_BRACE_TIME
#undef DOOR_BRACE_UNBRACED
#undef DOOR_BRACE_STRAIN_PER_YANK
#undef DOOR_BRACE_STRAIN_MAX
#undef DOOR_BRACE_STRAIN_RECOVERY
