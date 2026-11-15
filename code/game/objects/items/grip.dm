// Tightened grip: a held item can opt in (grip_tightenable) to being clenched
// in the hand. A clenched item survives falls and stuns, and a blow to the hand
// breaks the grip instead of knocking it away. The price is that its contents
// can't be reached until the grip is loosened (grip_blocks_access).
// Everything here runs on events (a fall, a stun, a hit, a click); nothing ticks.

/obj/item
	// The item can be held in a tightened grip ("Tighten Grip" verb, or its own use-in-hand).
	var/grip_tightenable = FALSE
	// Set while clenched; cleared whenever the item leaves the hand.
	var/tmp/grip_tightened = FALSE
	// Chance (percent) the item slips from a loose hand when its holder is knocked
	// down. A stun that leaves them standing uses half of it. Zero never slips.
	var/jostle_drop_chance = 0

/obj/item/proc/held_by(mob/M)
	return M && (M.l_hand == src || M.r_hand == src)

/obj/item/proc/can_tighten_grip(mob/user)
	return grip_tightenable && held_by(user)

// Tightens (tight = TRUE) or loosens the grip. Returns TRUE if it changed.
/obj/item/proc/set_grip(mob/user, tight, silent = FALSE)
	tight = tight ? TRUE : FALSE
	if (grip_tightened == tight)
		return FALSE
	if (tight && !can_tighten_grip(user))
		return FALSE
	grip_tightened = tight
	if (user && !silent)
		if (tight)
			to_chat(user, SPAN_NOTICE("You tighten your grip on \the [src]. Nothing will shake it loose, but you'll have to loosen your grip to get at it."))
		else
			to_chat(user, SPAN_NOTICE("You loosen your grip on \the [src]."))
		balloon_alert(user, tight ? "grip tightened" : "grip loosened")
	grip_changed(user)
	return TRUE

/obj/item/proc/toggle_grip(mob/user)
	if (!grip_tightened && !can_tighten_grip(user))
		if (user)
			to_chat(user, SPAN_WARNING("You can't get a tighter grip on \the [src]."))
		return FALSE
	return set_grip(user, !grip_tightened)

// Hook for items that show or react to their grip.
/obj/item/proc/grip_changed(mob/user)
	return

// Call before letting someone reach into, add to or take from the item.
// TRUE (and a message) means the grip is in the way.
/obj/item/proc/grip_blocks_access(mob/user)
	if (!grip_tightened)
		return FALSE
	if (user)
		to_chat(user, SPAN_WARNING("Your grip on \the [src] is too tight to get at it. Loosen your grip first."))
	return TRUE

// The item is forced out of H's hand (a fall or a blow). Items that scatter,
// like a handful of rounds, override this.
/obj/item/proc/knocked_from_hand(mob/living/human/H)
	return H.drop_from_inventory(src)

/obj/item/proc/can_be_knocked_from_hand(mob/living/human/H)
	return !nodrop && !abstract && held_by(H)

/mob/living/human/verb/toggle_held_grip()
	set name = "Tighten or Loosen Grip"
	set desc = "Clench the item in your active hand so falls and blows can't shake it loose, or relax your grip to use it."
	set category = "IC"
	if (stat != CONSCIOUS || restrained())
		return
	var/obj/item/I = get_active_hand()
	if (!I)
		to_chat(src, SPAN_WARNING("You have nothing in your hand to grip."))
		return
	I.toggle_grip(src)

// A fall (knocked_down) or a stun that leaves them standing. Loose items that
// can slip may fall out; a tightened grip always holds.
/mob/living/human/proc/jostle_held_items(knocked_down)
	for (var/obj/item/I in list(l_hand, r_hand))
		if (!I.jostle_drop_chance || I.grip_tightened || !I.can_be_knocked_from_hand(src))
			continue
		if (!prob(knocked_down ? I.jostle_drop_chance : I.jostle_drop_chance / 2))
			continue
		visible_message(SPAN_WARNING("[src] loses hold of \the [I]!"), SPAN_WARNING("You lose hold of \the [I]!"))
		I.knocked_from_hand(src)

// A hit landed on a hand ("l_hand"/"r_hand") with the given force or damage.
// It may knock the held item away, or break a tightened grip on it instead.
/mob/living/human/proc/hand_struck(zone, force)
	var/obj/item/I
	if (zone == "l_hand")
		I = l_hand
	else if (zone == "r_hand")
		I = r_hand
	if (!I || force <= 0 || !I.can_be_knocked_from_hand(src))
		return FALSE
	if (!prob(hand_strike_drop_chance(force)))
		return FALSE
	if (I.grip_tightened)
		I.set_grip(src, FALSE, silent = TRUE)
		visible_message(SPAN_WARNING("[src]'s grip on \the [I] is broken!"), SPAN_DANGER("The blow breaks your grip on \the [I]!"))
		return TRUE
	visible_message(SPAN_DANGER("The blow knocks \the [I] from [src]'s hand!"), SPAN_DANGER("The blow knocks \the [I] from your hand!"))
	I.knocked_from_hand(src)
	return TRUE

/proc/hand_strike_drop_chance(force)
	return clamp(force * 1.5, 5, 40)
