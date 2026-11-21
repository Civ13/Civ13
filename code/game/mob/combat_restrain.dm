// Restrain stance: the Grappling school's advanced stance walks a fighter
// through an arrest. With grab intent, each click on the person you hold takes
// the next step that fits their state:
//   firm hold (aggressive grab) -> jointlock -> pin to the ground -> bind the
//   hands with handcuffs or rope from your hands, belt or pockets -> bind the
//   legs if you carry legcuffs -> lead or carry them away.
// It never tightens a grab past a firm hold, so it is never lethal. Each step
// goes through the ordinary grab and cuffing procs, so a victim who resists out
// of the grab drops the flow back to the start, and every step is logged.

/obj/item/weapon/grab
	var/tmp/restrain_locked = FALSE // the Restrain stance has jointlocked them

// Trained enough to follow through an arrest: dexterity well above average or
// a Student rank in Grappling.
/mob/living/human/proc/restrain_flow_unlocked()
	if (getStatCoeff("dexterity") >= COMBAT_REACTION_SKILL)
		return TRUE
	return martial_rank("grappling") >= MARTIAL_RANK_STUDENT

/mob/living/human/proc/restrain_flow_ready()
	if (combat_stance != COMBAT_STANCE_RESTRAIN)
		return FALSE
	if (!restrain_flow_unlocked())
		to_chat(src, SPAN_WARNING("You lack the training to follow through an arrest; your grab works as usual."))
		return FALSE
	return TRUE

/mob/living/human/proc/restrain_log(mob/living/human/target, what)
	admin_attack_log(src, target, "Restrain stance: [what]", "Restrain stance: [what] by the attacker", "restrain stance: [what]")

// The arm a jointlock bends: the grabbed arm, the arm of a grabbed hand, else
// their weapon arm.
/mob/living/human/proc/restrain_lock_zone(obj/item/weapon/grab/G)
	switch (G.grabbed_zone)
		if ("l_arm", "r_arm")
			return G.grabbed_zone
		if ("l_hand", "r_hand")
			return combat_hand_arm(G.grabbed_zone)
	var/hand_zone = combat_weapon_hand(G.affecting)
	return hand_zone ? combat_hand_arm(hand_zone) : "r_arm"

// One step of the arrest. `previous_action` is the grab's last action before
// this click, for the ordinary upgrade wait. TRUE if a step was taken.
/mob/living/human/proc/restrain_step(obj/item/weapon/grab/G, previous_action)
	var/mob/living/human/T = G.affecting
	if (!istype(T) || G.hand_partner || G.carrying)
		return FALSE
	G.reset_kill_state()
	if (G.state < GRAB_AGGRESSIVE)
		if (world.time < previous_action + G.grab_upgrade_cooldown())
			G.last_action = previous_action
			to_chat(src, SPAN_WARNING("You are still working your grip on [T]."))
			return FALSE
		if (!G.take_firm_hold())
			return FALSE
		restrain_log(T, "took a firm hold")
		return TRUE
	if (!T.lying && !G.force_down)
		if (!G.restrain_locked)
			G.jointlock(T, src, restrain_lock_zone(G))
			G.restrain_locked = TRUE
			restrain_log(T, "jointlocked")
			return TRUE
		G.pin_down(T, src)
		if (!QDELETED(T) && T.lying)
			restrain_log(T, "pinned")
		return TRUE
	if (!T.handcuffed)
		var/obj/item/weapon/handcuffs/cuffs = restrain_find_item(/obj/item/weapon/handcuffs)
		if (!cuffs)
			to_chat(src, SPAN_WARNING("You have nothing to bind [T]'s hands with. Keep handcuffs or rope in a hand, on your belt or in a pocket."))
			return FALSE
		if (!restrain_take_in_hand(cuffs))
			to_chat(src, SPAN_WARNING("You need a free hand to bind [T]'s hands."))
			return FALSE
		if (cuffs.place_handcuffs(T, src))
			restrain_log(T, "bound hands with [cuffs]")
		return TRUE
	if (!T.legcuffed)
		var/obj/item/weapon/legcuffs/L = restrain_find_item(/obj/item/weapon/legcuffs)
		if (L)
			return restrain_bind_legs(G, L)
	to_chat(src, SPAN_NOTICE("[T] is restrained. Pull [p_them_text_of(T)] along, or click yourself to carry [p_them_text_of(T)]."))
	return FALSE

/mob/living/human/proc/p_them_text_of(mob/living/human/H)
	return istype(H) ? H.p_them_text() : "them"

// Restraints of `kind` in the free hand, worn on the belt, carried in the belt
// or in a pocket.
/mob/living/human/proc/restrain_find_item(kind)
	for (var/obj/item/I in list(get_inactive_hand(), belt, l_store, r_store))
		if (istype(I, kind))
			return I
	if (istype(belt, /obj/item/weapon/storage))
		for (var/obj/item/I in belt.contents)
			if (istype(I, kind))
				return I
	return null

// Moves `I` into the free hand. FALSE if that hand holds something else.
/mob/living/human/proc/restrain_take_in_hand(obj/item/I)
	if (I == get_inactive_hand())
		return TRUE
	if (get_inactive_hand())
		return FALSE
	if (istype(I.loc, /obj/item/weapon/storage))
		var/obj/item/weapon/storage/S = I.loc
		if (!S.remove_from_storage(I, src))
			return FALSE
	else if (I.loc == src)
		if (!unEquip(I, FALSE, src))
			return FALSE
	else
		return FALSE
	if (put_in_inactive_hand(I))
		return TRUE
	put_in_hands(I)
	return FALSE

// Ties the legs of a pinned, cuffed victim with carried legcuffs.
/mob/living/human/proc/restrain_bind_legs(obj/item/weapon/grab/G, obj/item/weapon/legcuffs/L)
	var/mob/living/human/T = G.affecting
	if (!T.has_organ("l_leg") || !T.has_organ("r_leg"))
		to_chat(src, SPAN_WARNING("[T] needs two legs to bind."))
		return FALSE
	if (!restrain_take_in_hand(L))
		to_chat(src, SPAN_WARNING("You need a free hand to bind [T]'s legs."))
		return FALSE
	visible_message(SPAN_DANGER("[src] starts binding [T]'s legs with \the [L]!"), SPAN_NOTICE("You start binding [T]'s legs."))
	if (!do_after(src, COMBAT_RESTRAIN_LEGS_TIME, T))
		return FALSE
	if (QDELETED(G) || G.affecting != T || T.legcuffed || L.loc != src || !(T.lying || T.handcuffed))
		return FALSE
	drop_from_inventory(L)
	T.equip_to_slot(L, slot_legcuffed)
	if (T.legcuffed != L)
		if (!QDELETED(L) && L.loc != T)
			put_in_hands(L)
		return FALSE
	visible_message(SPAN_DANGER("[src] has bound [T]'s legs with \the [L]!"), SPAN_NOTICE("You bind [T]'s legs."))
	setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	restrain_log(T, "bound legs with [L]")
	return TRUE
