// Self-help when hurt: pushing yourself back up after a knockdown and pressing
// a free hand on your own bleeding wound. These deadlines are transient and
// never save data.
/mob/living/human
	var/tmp/next_get_up = 0			// world.time of the next allowed get-up attempt
	var/tmp/getting_up = FALSE		// a get-up attempt is running
	var/tmp/next_get_up_hint = 0	// world.time the knockdown hint may show again
	// The limb each of your own hands is holding shut; one bleed per hand.
	var/tmp/obj/item/organ/external/self_pressure_l = null
	var/tmp/obj/item/organ/external/self_pressure_r = null

/mob/living/human/persistence_runtime_var(key)
	if (key == "next_get_up" || key == "getting_up" || key == "next_get_up_hint" || key == "self_pressure_l" || key == "self_pressure_r")
		return TRUE
	return ..()

#define GET_UP_COOLDOWN (15 SECONDS)
#define GET_UP_STAMINA 15
#define GET_UP_MAX_SHOCK 80

// Why this person can't push themselves up right now, or null when they can.
// ignore_cooldown is used while an attempt is already under way.
/mob/living/human/proc/get_up_blocker(ignore_cooldown = FALSE)
	if (stat)
		return "You can't get up while you're out cold."
	if (!weakened)
		return "You aren't knocked down."
	if (paralysis || stunned || sleeping || (status_flags & FAKEDEATH))
		return "You're too dazed to get up."
	if (buckled)
		return "You can't get up while you're strapped down."
	for (var/obj/item/weapon/grab/G in grabbed_by)
		if (G.force_down)
			return "[G.assailant] is pinning you to the ground!"
	if (!get_up_has_limb(list("l_arm", "r_arm")))
		return "You have no arm to push yourself up with."
	if (!get_up_has_limb(list("l_leg", "r_leg")))
		return "You can't get your legs under you."
	if (shock_stage >= GET_UP_MAX_SHOCK)
		return "The pain is too much to get up."
	if (stats["stamina"][1] < GET_UP_STAMINA)
		return "You're too exhausted to get up."
	if (!ignore_cooldown && (getting_up || world.time < next_get_up))
		return "You need to catch your breath before trying again."
	return null

/mob/living/human/proc/get_up_has_limb(list/limbs)
	for (var/limb in limbs)
		var/obj/item/organ/external/E = organs_by_name[limb]
		if (E && E.is_usable() && !(E.status & ORGAN_DESTROYED))
			return TRUE
	return FALSE

// Longer knockdowns take longer to shake off, but it is always quicker than
// waiting it out: about 0.6 s per remaining knockdown tick, 2 to 8 seconds.
/mob/living/human/proc/get_up_delay()
	var/delay = Clamp(weakened * 6, 20, 80)
	if (handcuffed)
		delay *= 2
	return max(20, round(delay / max(0.5, getStatCoeff("strength"))))

/mob/living/human/resist_knockdown()
	return try_get_up()

// Resist while knocked down: a short, interruptible push back to your feet.
/mob/living/human/proc/try_get_up()
	var/blocker = get_up_blocker()
	if (blocker)
		to_chat(src, SPAN_WARNING(blocker))
		return FALSE
	getting_up = TRUE
	next_get_up = world.time + GET_UP_COOLDOWN
	stats["stamina"][1] = max(0, stats["stamina"][1] - GET_UP_STAMINA)
	var/delay = get_up_delay()
	visible_message(SPAN_NOTICE("[src] tries to push [gender == FEMALE ? "herself" : gender == MALE ? "himself" : "themselves"] back up."), \
					SPAN_NOTICE("You try to push yourself back up."))
	var/start = world.time
	var/start_weakened = weakened
	var/start_hurt = getBruteLoss() + getBurnLoss()
	var/datum/progressbar/bar = client ? new(src, delay, src) : null
	. = TRUE
	while (world.time < start + delay)
		sleep(1)
		if (QDELETED(src))
			return FALSE
		if (bar)
			bar.update(world.time - start)
		if (!weakened)
			break // it wore off on its own
		if (weakened > start_weakened || getBruteLoss() + getBurnLoss() > start_hurt + 5 || get_up_blocker(TRUE))
			. = FALSE
			break
	if (bar)
		qdel(bar)
	getting_up = FALSE
	if (!.)
		to_chat(src, SPAN_WARNING("You collapse back down."))
		return FALSE
	finish_get_up()
	return TRUE

/mob/living/human/proc/finish_get_up()
	SetWeakened(0)
	resting = 0
	update_canmove()
	update_icons()
	visible_message(SPAN_NOTICE("[src] gets back up."), SPAN_NOTICE("You get back on your feet."))

// Shown once every few minutes when a knockdown starts.
/mob/living/human/proc/get_up_hint(was_weakened)
	if (was_weakened || weakened < 3 || stat || !client || world.time < next_get_up_hint)
		return
	next_get_up_hint = world.time + 5 MINUTES
	to_chat(src, SPAN_NOTICE("You've been knocked down. Click yourself on help intent, or use Resist, to push yourself back up sooner."))

#undef GET_UP_COOLDOWN
#undef GET_UP_STAMINA
#undef GET_UP_MAX_SHOCK

// The limbs a free hand can reach to press on. A hand can't press on its own
// arm, so the other hand has to cover those.
/mob/living/human/proc/self_pressure_blocked_limbs(pressing_hand)
	if (pressing_hand == "l_hand")
		return list("l_hand", "l_arm")
	return list("r_hand", "r_arm")

// Choose where to press: the aimed limb when it bleeds, otherwise the worst
// bleeding limb the free hand can reach. Returns the zone or null.
/mob/living/human/proc/self_pressure_zone(target_zone, pressing_hand)
	var/list/blocked = self_pressure_blocked_limbs(pressing_hand)
	var/obj/item/organ/external/aimed = get_organ(target_zone)
	if (aimed && (aimed.status & ORGAN_BLEEDING) && !(aimed.limb_name in blocked) && !aimed.applied_pressure)
		return aimed.limb_name
	var/best_zone = null
	var/best_damage = -1
	for (var/obj/item/organ/external/E in organs)
		if (!(E.status & ORGAN_BLEEDING) || (E.limb_name in blocked) || E.applied_pressure)
			continue
		var/bleed = E.brute_dam + ((E.status & ORGAN_ARTERY_CUT) ? 100 : 0)
		if (bleed > best_damage)
			best_damage = bleed
			best_zone = E.limb_name
	return best_zone

// Grab intent on yourself with an empty hand: press on a bleeding wound.
/mob/living/human/proc/try_self_pressure(target_zone)
	if (stat || paralysis)
		return FALSE
	var/pressing_hand = hand ? "l_hand" : "r_hand"
	var/obj/item/organ/external/hand_organ = organs_by_name[pressing_hand]
	if (get_active_hand() || !hand_organ || !hand_organ.is_usable())
		to_chat(src, SPAN_WARNING("You need a free, working hand to press on a wound."))
		return FALSE
	// Each hand holds one bleed: pressing elsewhere moves this hand there.
	var/obj/item/organ/external/held = self_pressure_hand_limb(pressing_hand)
	var/zone = self_pressure_zone(target_zone, pressing_hand)
	if (zone && held && held.limb_name == zone)
		to_chat(src, SPAN_NOTICE("You're already holding your [held.name] with this hand."))
		return FALSE
	if (zone && held)
		release_self_pressure(pressing_hand)
	if (!zone)
		var/obj/item/organ/external/aimed = get_organ(target_zone)
		var/bleeding = FALSE
		for (var/obj/item/organ/external/E in organs)
			if (E.status & ORGAN_BLEEDING)
				bleeding = TRUE
				break
		if (!bleeding)
			to_chat(src, SPAN_NOTICE("You aren't bleeding anywhere."))
		else if (aimed && aimed.applied_pressure && (aimed.status & ORGAN_BLEEDING))
			to_chat(src, SPAN_WARNING("[ismob(aimed.applied_pressure) ? "Someone" : "\A [aimed.applied_pressure]"] is already pressing on your [aimed.name]."))
		else
			to_chat(src, SPAN_WARNING("You can't reach that wound with this hand. Try your other hand."))
		return FALSE
	return apply_pressure(src, zone)

/mob/living/human/proc/self_pressure_hand_limb(pressing_hand)
	var/obj/item/organ/external/E = pressing_hand == "l_hand" ? self_pressure_l : self_pressure_r
	if (E && (E.owner != src || E.applied_pressure != src))
		E = null
	return E

/mob/living/human/proc/set_self_pressure_hand(pressing_hand, obj/item/organ/external/E)
	if (pressing_hand == "l_hand")
		self_pressure_l = E
	else
		self_pressure_r = E

/mob/living/human/proc/release_self_pressure(pressing_hand)
	var/obj/item/organ/external/E = self_pressure_hand_limb(pressing_hand)
	set_self_pressure_hand(pressing_hand, null)
	if (E)
		E.applied_pressure = null
		to_chat(src, SPAN_NOTICE("You let go of your [E.name]."))

// TRUE while the user still has a free hand on the wound: their own empty hand
// for themselves, or a grab on the patient for someone else.
/mob/living/human/proc/still_pressing(mob/living/user, pressing_hand, obj/item/organ/external/organ)
	if (QDELETED(user) || user.stat || user.paralysis)
		return FALSE
	if (user == src)
		if (organ && (pressing_hand == "l_hand" ? self_pressure_l : self_pressure_r) != organ)
			return FALSE
		var/obj/item/organ/external/hand_organ = organs_by_name[pressing_hand]
		if (!hand_organ || !hand_organ.is_usable())
			return FALSE
		return !(pressing_hand == "l_hand" ? l_hand : r_hand)
	if (!user.Adjacent(src))
		return FALSE
	for (var/obj/item/weapon/grab/G in list(user.l_hand, user.r_hand))
		if (G.affecting == src)
			return TRUE
	return FALSE
