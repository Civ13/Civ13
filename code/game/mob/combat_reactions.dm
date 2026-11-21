// Automatic reactions before or after an opponent's action.
//
// Two families share one engine:
// - Martial reflexes (martial arts plan): a school's trained unarmed reflex,
//   by rank, on any non-help intent while idle for 2 seconds with free hands.
//   Wing Chun Bong Sau turns a chest punch aside; Pugilism slips a head punch;
//   Grappling sprawls out of a grab; hard-hand striking blocks and counters.
// - Advanced stance reactions: a trained fighter's stance answers by itself.
//   Measured stop-hits an incoming swing, Guarded ripostes after a parry and
//   counters after a hit, Aggressive answers a hit, Disarming and Low line
//   strike the arm reaching to grab.
// Every reaction goes through the ordinary attack and grab procs, needs the
// fighter awake, standing, free and facing the opponent, costs stamina, has a
// cooldown and never answers another reaction.

/mob
	var/tmp/next_combat_reaction = 0
	var/tmp/next_martial_reflex = 0
	var/tmp/in_combat_reaction = FALSE
	// A zone a reaction forces on the attack it throws (resolve_attack_zone).
	var/tmp/forced_attack_zone = null

// Which reactions each stance allows.
var/global/list/combat_stance_reactions = list(
	COMBAT_STANCE_MEASURED = list(COMBAT_TRIGGER_INCOMING),
	COMBAT_STANCE_AGGRESSIVE = list(COMBAT_TRIGGER_AFTER_HIT),
	COMBAT_STANCE_DISARMING = list(COMBAT_TRIGGER_GRAB_REACH),
	COMBAT_STANCE_LOW = list(COMBAT_TRIGGER_GRAB_REACH),
	COMBAT_STANCE_GUARDED = list(COMBAT_TRIGGER_AFTER_PARRY, COMBAT_TRIGGER_AFTER_HIT))

// Martial reflex chance by rank (martial arts plan); Novice has none yet.
var/global/list/martial_reflex_chance = list(0, 0, 25, 45, 65)

// The martial school and rank (0-4). The martial arts schools PR fills these
// in; until then nobody has a school, so no martial reflex fires.
/mob/living/human/var/martial_school = null

/mob/living/human/proc/martial_rank(school_id)
	return MARTIAL_RANK_NONE

// Trained enough for advanced stance reactions: a weapon skill (or dexterity
// for bare hands) well above average, or a martial rank of Student or more.
/mob/proc/combat_reactions_unlocked(obj/item/weapon)
	return FALSE

/mob/living/human/combat_reactions_unlocked(obj/item/weapon)
	var/skill = getStatCoeff("dexterity")
	if (weapon && ("stat" in weapon.vars) && istext(weapon.vars["stat"]))
		skill = max(skill, getStatCoeff(weapon.vars["stat"]))
	if (skill >= COMBAT_REACTION_SKILL)
		return TRUE
	return !weapon && martial_school && martial_rank(martial_school) >= MARTIAL_RANK_STUDENT

// The weapon in the active hand, if any. Wraps and gloves are worn, not held.
/mob/living/human/proc/combat_reaction_weapon()
	var/obj/item/I = get_active_hand()
	if (I && I.force && !(I.flags & NOBLUDGEON) && !istype(I, /obj/item/weapon/grab))
		return I
	return null

// Hands free for a hand reflex: the active hand holds nothing.
/mob/living/human/proc/combat_hands_free()
	return !get_active_hand()

// Ready to react to `attacker` at all.
/mob/living/human/proc/combat_reaction_ready(mob/living/attacker, stamina)
	if (!attacker || attacker == src || in_combat_reaction || attacker.in_combat_reaction)
		return FALSE // a reaction never answers a reaction
	if (stat != CONSCIOUS || lying || buckled || restrained() || !canmove || incapacitated())
		return FALSE
	if (grabbed_by.len)
		return FALSE
	if (get_dist(src, attacker) > 1)
		return FALSE
	if (get_dir(src, attacker) & reverse_direction(dir))
		return FALSE // never against an attack from behind
	if (stats["stamina"][1] < stamina)
		return FALSE
	return TRUE

// Called from the attack and grab procs with the zone the attack aims at.
// TRUE means a "before" reaction stopped the opponent's action.
/mob/living/human/proc/combat_reaction_try(mob/living/attacker, trigger, zone, obj/item/attacking_weapon)
	if (martial_reflex_try(attacker, trigger, zone, attacking_weapon))
		return TRUE
	return stance_reaction_try(attacker, trigger, zone, attacking_weapon)

// The school reflex for this trigger and zone, or null.
/mob/living/human/proc/martial_reflex_for(trigger, zone, obj/item/attacking_weapon)
	switch (martial_school)
		if ("wing_chun")
			if (trigger == COMBAT_TRIGGER_INCOMING && !attacking_weapon && zone == "chest")
				return "bong_sau"
		if ("pugilism")
			if (trigger == COMBAT_TRIGGER_INCOMING && !attacking_weapon && combat_zone_is_high(zone))
				return "slip"
		if ("grappling")
			if (trigger == COMBAT_TRIGGER_GRAB_REACH)
				return "sprawl"
		if ("hard_hand")
			if (trigger == COMBAT_TRIGGER_INCOMING && !attacking_weapon)
				return "block_counter"
	return null

/mob/living/human/proc/martial_reflex_try(mob/living/attacker, trigger, zone, obj/item/attacking_weapon)
	if (!martial_school || a_intent == I_HELP || world.time < next_martial_reflex)
		return FALSE
	if (world.time - next_click < MARTIAL_REFLEX_IDLE - 1)
		return FALSE // only while not busy clicking
	if (!combat_hands_free() || !combat_reaction_ready(attacker, MARTIAL_REFLEX_STAMINA))
		return FALSE
	var/reflex = martial_reflex_for(trigger, zone, attacking_weapon)
	if (!reflex)
		return FALSE
	var/rank = clamp(martial_rank(martial_school), MARTIAL_RANK_NONE, MARTIAL_RANK_MASTER)
	var/chance = martial_reflex_chance[rank + 1]
	if (chance <= 0 || !prob(min(95, chance * physical_contest_ratio(src, attacker, 0, 1))))
		return FALSE
	next_martial_reflex = world.time + MARTIAL_REFLEX_COOLDOWN
	stats["stamina"][1] = max(0, stats["stamina"][1] - MARTIAL_REFLEX_STAMINA)
	in_combat_reaction = TRUE
	switch (reflex)
		if ("bong_sau")
			visible_message(SPAN_WARNING("[src] turns [attacker]'s punch aside with a raised forearm!"), SPAN_NOTICE("Bong Sau: you turn the punch aside."))
		if ("slip")
			visible_message(SPAN_WARNING("[src] slips [attacker]'s punch!"), SPAN_NOTICE("You slip the punch."))
		if ("sprawl")
			visible_message(SPAN_WARNING("[src] sprawls out of [attacker]'s reach!"), SPAN_NOTICE("You sprawl out of the grab."))
		if ("block_counter")
			visible_message(SPAN_WARNING("[src] blocks [attacker]'s punch!"), SPAN_NOTICE("You block and counter."))
			combat_react_strike(attacker, null, null, null)
	playsound(loc, 'sound/weapons/thudswoosh.ogg', 40, TRUE, -1)
	adaptStat("dexterity", 1)
	in_combat_reaction = FALSE
	return TRUE

/mob/living/human/proc/stance_reaction_try(mob/living/attacker, trigger, zone, obj/item/attacking_weapon)
	if (!combat_stance_active() || world.time < next_combat_reaction)
		return FALSE
	var/list/allowed = combat_stance_reactions[combat_stance]
	if (!allowed || !(trigger in allowed))
		return FALSE
	if (!combat_reaction_ready(attacker, COMBAT_REACTION_STAMINA))
		return FALSE
	var/obj/item/weapon = combat_reaction_weapon()
	if (!combat_reactions_unlocked(weapon))
		return FALSE
	if (!prob(clamp(30 * combat_read_skill(attacker, weapon), 10, 60)))
		return FALSE
	next_combat_reaction = world.time + COMBAT_REACTION_COOLDOWN
	stats["stamina"][1] = max(0, stats["stamina"][1] - COMBAT_REACTION_STAMINA)
	in_combat_reaction = TRUE
	. = FALSE
	switch (trigger)
		if (COMBAT_TRIGGER_INCOMING)
			// Stop-hit: strike the arm swinging at you, and the swing is spoiled.
			visible_message(SPAN_WARNING("[src] catches [attacker]'s arm mid-swing!"), SPAN_NOTICE("You strike [attacker]'s arm mid-swing."))
			combat_react_strike(attacker, attacker.attacking_arm(), null, weapon)
			. = TRUE
		if (COMBAT_TRIGGER_GRAB_REACH)
			. = combat_react_strike(attacker, attacker.attacking_arm(), "[src] strikes the arm reaching for [p_them_text()]!", weapon)
		if (COMBAT_TRIGGER_AFTER_PARRY)
			combat_react_strike(attacker, attacker.attacking_arm(), "[src] ripostes!", weapon)
		if (COMBAT_TRIGGER_AFTER_HIT)
			combat_react_strike(attacker, combat_stance == COMBAT_STANCE_GUARDED ? attacker.attacking_arm() : null, "[src] answers the blow!", weapon)
	in_combat_reaction = FALSE

/mob/living/human/proc/p_them_text()
	var/datum/gender/T = gender_datums[gender]
	return T ? T.him : "them"

// Throws one ordinary attack at `zone` (or the stance's pick) on the attacker,
// without touching the reactor's own click cooldown.
/mob/living/human/proc/combat_react_strike(mob/living/attacker, zone, message, obj/item/weapon)
	if (QDELETED(attacker) || get_dist(src, attacker) > 1)
		return FALSE
	if (message)
		visible_message(SPAN_WARNING(message))
	var/old_next_move = next_move
	forced_attack_zone = zone
	if (weapon)
		weapon.attack(attacker, src, zone ? zone : resolve_attack_zone(attacker, weapon, COMBAT_ATTACK_WEAPON))
	else if (ishuman(attacker))
		var/old_intent = a_intent
		a_intent = I_HARM
		attacker.attack_hand(src)
		a_intent = old_intent
	forced_attack_zone = null
	next_move = old_next_move
	return TRUE
