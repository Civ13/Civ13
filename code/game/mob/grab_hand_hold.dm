// Body-part grabs and holding hands.
// A grab takes hold of the part the zone selector targets. Taking an empty hand
// of someone awake and standing holds their hand: the grabber keeps the grab,
// and the held person gets a /obj/item/hand_hold in that hand. Either one can
// drop theirs to let go. Reinforcing a hand hold makes the grip firm: the held
// person can only step to tiles beside the grabber and can't drop it; trying
// to drop it counts as a resist.
// Everything here runs on clicks, drops and the grab's own process; nothing new ticks.

// The zone a grab at `zone` takes hold of, or null if that part is missing.
// A random target falls back to the chest rather than missing.
/mob/living/human/proc/grab_target_zone(zone, random = FALSE)
	if (!zone)
		zone = "chest"
	var/obj/item/organ/external/part = get_organ(zone)
	if (part && !part.is_stump())
		return zone
	if (random)
		return "chest"
	return null

// How a grab on `zone` reads in messages ("grabbed X by the ..."); null keeps
// the plain passive grab message. A full hand is taken by the wrist.
/proc/grab_zone_description(zone, mob/living/human/target)
	switch (zone)
		if ("chest", "groin", null)
			return null
		if ("eyes", "mouth")
			return "head"
		if ("l_hand")
			if (target && target.l_hand)
				return "left wrist"
		if ("r_hand")
			if (target && target.r_hand)
				return "right wrist"
	return parse_zone(zone)

/obj/item/weapon/grab/proc/hand_hold_intact()
	return hand_partner && !QDELETED(hand_partner) && !hand_partner.released && hand_partner.held_by(affecting)

// Turns a fresh passive grab on an empty hand into holding hands. FALSE leaves
// it an ordinary grab (full hand, unusable hand, asleep, restrained or lying).
/obj/item/weapon/grab/proc/try_hand_hold()
	if (hand_partner || state != GRAB_PASSIVE)
		return FALSE
	if (grabbed_zone != "l_hand" && grabbed_zone != "r_hand")
		return FALSE
	if (!ishuman(affecting) || !ishuman(assailant) || assailant == affecting)
		return FALSE
	var/mob/living/human/H = affecting
	if (H.stat != CONSCIOUS || H.restrained() || H.lying)
		return FALSE
	if (grabbed_zone == "l_hand" ? H.l_hand : H.r_hand)
		return FALSE
	var/obj/item/organ/external/hand = H.get_organ(grabbed_zone)
	if (!hand || !hand.is_usable())
		return FALSE
	var/obj/item/hand_hold/P = new(null)
	P.grab = src
	P.holder = H
	P.name = "[assailant]'s hand"
	if (!(grabbed_zone == "l_hand" ? H.put_in_l_hand(P) : H.put_in_r_hand(P)))
		P.grab = null
		P.holder = null
		P.released = TRUE
		qdel(P)
		return FALSE
	hand_partner = P
	name = "[H]'s hand"
	return TRUE

// Reinforcing a hand hold: passive becomes a firm grip, and goes no further.
/obj/item/weapon/grab/proc/hand_hold_tighten()
	if (state >= GRAB_AGGRESSIVE)
		to_chat(assailant, SPAN_NOTICE("You're already gripping [affecting]'s hand as firmly as you can."))
		return FALSE
	if (!allow_upgrade)
		return FALSE
	state = GRAB_AGGRESSIVE
	icon_state = "grabbed1"
	hud.icon_state = "!reinforce"
	if (hand_partner)
		hand_partner.icon_state = "grabbed1"
	assailant.visible_message(SPAN_WARNING("[assailant] tightens \his grip on [affecting]'s hand!"), SPAN_WARNING("You tighten your grip on [affecting]'s hand."))
	to_chat(affecting, SPAN_WARNING("[assailant] grips your hand firmly. Resist to pull free."))
	adjust_position()
	return TRUE

// The grab is ending (dropped, resisted, out of reach): let the other hand go too.
/obj/item/weapon/grab/proc/hand_hold_release()
	var/obj/item/hand_hold/P = hand_partner
	hand_partner = null
	if (P && !P.released)
		P.grab = null
		P.release(FALSE)

// A firm hand grip lets the held person step around the grabber but never to
// a tile that isn't next to them. Returns the grabber when a step to `dest` is blocked.
/mob/proc/hand_hold_leash_blocks(atom/dest)
	if (!grabbed_by || !grabbed_by.len || !dest)
		return null
	for (var/obj/item/weapon/grab/G in grabbed_by)
		if (!G.hand_partner || G.state < GRAB_AGGRESSIVE || !G.assailant)
			continue
		var/turf/T = get_turf(dest)
		var/turf/A = get_turf(G.assailant)
		if (!T || !A || T.z != A.z || get_dist(T, A) > 1)
			return G.assailant
	return null

// The held person's half of a hand hold.
/obj/item/hand_hold
	name = "hand"
	desc = "You're holding someone's hand. Drop it to let go. If they grip it firmly, you'll have to resist to pull free."
	icon = 'icons/mob/screen/1713Style.dmi'
	icon_state = "grabbed"
	item_state = "nothing"
	abstract = TRUE
	w_class = ITEM_SIZE_HUGE
	layer = 21
	should_save = FALSE
	var/tmp/obj/item/weapon/grab/grab = null
	var/tmp/mob/living/human/holder = null
	var/tmp/released = FALSE

/obj/item/hand_hold/proc/firm()
	return !released && grab && !QDELETED(grab) && grab.state >= GRAB_AGGRESSIVE

// A firm grip can't be shaken off by dropping it while awake; passing out lets go.
/obj/item/hand_hold/nodrop_special_check()
	return firm() && holder && holder.stat == CONSCIOUS

/obj/item/hand_hold/nothrow_special_check()
	return TRUE

// Dropping a firmly held hand is a resist attempt instead.
/obj/item/hand_hold/player_drop_refused(mob/user)
	if (!firm())
		return FALSE
	var/mob/living/L = user
	if (istype(L) && !L.stat && L.canClick())
		L.setClickCooldown(20)
		to_chat(L, SPAN_WARNING("[grab.assailant] has a firm grip on your hand. You try to pull free!"))
		L.resist_grab()
	return TRUE

/obj/item/hand_hold/attack_self(mob/user)
	if (!grab || !grab.assailant || !ismob(user) || !user.canClick())
		return
	user.setClickCooldown(10)
	user.visible_message(SPAN_NOTICE("[user] squeezes [grab.assailant]'s hand."), SPAN_NOTICE("You squeeze [grab.assailant]'s hand."))

/obj/item/hand_hold/attack(mob/M, mob/user)
	return FALSE

/obj/item/hand_hold/dropped(mob/user)
	..()
	release(TRUE)

// Ends the hold from this side. by_holder: the held person let go themselves.
/obj/item/hand_hold/proc/release(by_holder)
	if (released)
		return
	released = TRUE
	var/obj/item/weapon/grab/G = grab
	grab = null
	if (G && !QDELETED(G))
		G.hand_partner = null
		if (by_holder && holder && G.assailant)
			holder.visible_message(SPAN_NOTICE("[holder] lets go of [G.assailant]'s hand."), SPAN_NOTICE("You let go of [G.assailant]'s hand."))
		qdel(G)
	if (holder && held_by(holder))
		holder.drop_from_inventory(src, null, TRUE)
	holder = null
	loc = null
	if (!QDELETED(src))
		qdel(src)

/obj/item/hand_hold/Destroy()
	if (!released)
		release(FALSE)
	holder = null
	grab = null
	return ..()

// Items can refuse a drop the player asked for (Q, the drop button) and do
// something else instead. Automatic drops still use nodrop_special_check().
/obj/item/proc/player_drop_refused(mob/user)
	return FALSE
