// Bringing the recently dead back. Help-intent CPR on a dead body can restart
// the heart, and a defibrillator does it in one shock. Both use the same
// rules: the death must be recent, the body intact and the person's spirit
// still around. Some things keep a body dead for good (no head, ruined vital
// organs, too much poison, rot, or too long a wait); others only until they
// are treated (lethal wounds or blood loss).

#define CPR_REVIVAL_CYCLE (5 SECONDS)
#define REVIVAL_POISON_LIMIT 100 // toxin damage taken plus still to come
#define REVIVAL_BRAIN_DAMAGE_MAX 50 // stays under the 60 that kills outright

// world.time the death clock started; 0 when there is no fresh death. Not
// saved, so a body loaded from a save is never fresh.
/mob/living/human/var/tmp/revival_clock = 0
/mob/living/human/var/tmp/revival_ckey = null
/mob/living/human/var/tmp/list/revival_recipe_nodes = null
/mob/living/human/var/tmp/cpr_revival_busy = FALSE

// A save taken during CPR must not keep the lock on the restored body.
/mob/living/human/persistence_runtime_var(key)
	return key == "cpr_revival_busy" || ..()

// Called by death() before the dead forget what they knew.
/mob/living/human/proc/note_revival_window()
	revival_clock = max(world.time, 1) // 0 means no fresh death
	revival_ckey = ckey
	revival_recipe_nodes = islist(known_recipe_nodes) ? known_recipe_nodes.Copy() : null

/mob/living/human/proc/revival_window()
	return config.defib_timer MINUTES

/mob/living/human/proc/time_dead_for_revival()
	return revival_clock ? world.time - revival_clock : INFINITY

// The ghost that still belongs to this body, if it is on this server.
/mob/living/human/proc/revival_ghost()
	if (!revival_ckey)
		return null
	for (var/mob/observer/ghost/G in player_list)
		if (G.ckey == revival_ckey && (!mind || G.mind == mind))
			return G
	return null

// TRUE when the person has gone on: they left this server, took a new
// character or gave up their body for good. NPCs have no spirit to lose.
/mob/living/human/proc/revival_spirit_gone()
	if (!revival_ckey)
		return FALSE
	if (ckey == revival_ckey)
		return FALSE // still bound to the body, even if logged out
	var/mob/observer/ghost/G = revival_ghost()
	if (!G || !G.can_reenter_corpse)
		return TRUE
	for (var/mob/living/human/other in human_mob_list)
		if (other != src && other.stat != DEAD && other.ckey == revival_ckey)
			return TRUE
	return FALSE

// Toxin damage the poisons still in the body would deal.
/mob/living/human/proc/pending_poison_damage()
	. = 0
	for (var/datum/reagents/R in list(reagents, ingested))
		for (var/datum/reagent/toxin/T in R.reagent_list)
			. += T.volume * max(T.strength, 0)

// Why this body cannot be brought back now, or null. With include_treatable
// FALSE, only the reasons no treatment can fix.
/mob/living/human/proc/resuscitation_blocker(include_treatable = TRUE)
	if (stat != DEAD)
		return "[src] is not dead."
	if (istype(src, /mob/living/human/corpse) || !species)
		return "[src] is beyond any help."
	if (!species.has_organ["heart"])
		return "[src] has no heartbeat to restart."
	var/obj/item/organ/external/head = organs_by_name["head"]
	if (!head || (head.status & ORGAN_DESTROYED))
		return "[src] has no head."
	if (!can_defib)
		return "[src]'s body is too badly ruined."
	for (var/organ_tag in species.has_organ)
		var/obj/item/organ/O = species.has_organ[organ_tag]
		if (!initial(O.vital) && organ_tag != "heart")
			continue
		O = internal_organs_by_name[organ_tag]
		if (!O)
			return "[src] is missing a vital organ."
		if ((O.status & ORGAN_DEAD) || O.damage > O.max_damage)
			return "[src]'s [O.name] is ruined."
	if (species.has_organ["brain"])
		var/obj/item/organ/brain/B = internal_organs_by_name["brain"]
		if (!B || B.damage >= 60)
			return "[src]'s brain is too badly damaged."
	if (rotting_stage > 0)
		return "[src] has begun to rot."
	if (time_dead_for_revival() > revival_window())
		return "[src] has been dead too long."
	if (revival_spirit_gone())
		return "[src]'s spirit has moved on."
	if (getToxLoss() + pending_poison_damage() >= REVIVAL_POISON_LIMIT)
		return "There is too much poison in [src]'s body."
	if (!include_treatable)
		return null
	updatehealth()
	if (health + getOxyLoss() <= config.health_threshold_dead)
		return "[src]'s wounds are too severe. Treat them first."
	if (!(species.flags & NO_BLOOD) && get_blood_volume() < BLOOD_VOLUME_SURVIVE)
		return "[src] has lost too much blood. Give them blood first."
	return null

// Mouth-to-mouth needs a mouth that is not covered.
/mob/living/human/proc/revival_mouth_free()
	if (!check_has_mouth())
		return FALSE
	if (head && (head.body_parts_covered & FACE))
		return FALSE
	if (wear_mask && (wear_mask.body_parts_covered & FACE))
		return FALSE
	return TRUE

// Percent chance that one round of CPR restarts the heart.
/mob/living/human/proc/cpr_revival_chance(mob/living/human/rescuer)
	var/chance = 10 + 10 * rescuer.getStatCoeff("medical")
	if (rescuer.original_job && rescuer.original_job.is_medic)
		chance += 10
	if (reagents && reagents.get_reagent_amount("adrenaline") >= 5)
		chance += 25
	return clamp(chance, 5, 80)

/mob/living/human/proc/try_cpr_revival(mob/living/human/rescuer)
	var/reason = resuscitation_blocker()
	if (reason)
		to_chat(rescuer, SPAN_WARNING(reason))
		return FALSE
	if (cpr_revival_busy)
		return FALSE // one round of compressions at a time
	var/mob/observer/ghost/G = revival_ghost()
	if (G)
		G.notify_revive("Someone is trying to resuscitate you!", 'sound/machines/ping.ogg')
	rescuer.visible_message("<span class='danger'>\The [rescuer] starts chest compressions on \the [src]!</span>", SPAN_NOTICE("You start chest compressions on \the [src]."), "You hear pumping.")
	cpr_revival_busy = TRUE
	var/finished = do_after(rescuer, CPR_REVIVAL_CYCLE, src)
	cpr_revival_busy = FALSE
	if (!finished || stat != DEAD)
		return FALSE
	reason = resuscitation_blocker()
	if (reason)
		to_chat(rescuer, SPAN_WARNING(reason))
		return FALSE
	// Compressions keep blood moving, so the clock stands still while they last.
	revival_clock = min(world.time, revival_clock + CPR_REVIVAL_CYCLE)
	if (rescuer.revival_mouth_free() && revival_mouth_free())
		adjustOxyLoss(-(min(getOxyLoss(), 10)))
	if (prob(5 / max(rescuer.getStatCoeff("medical"), 0.1)))
		var/obj/item/organ/external/chest = get_organ("chest")
		if (chest)
			chest.fracture()
	if (!prob(cpr_revival_chance(rescuer)))
		rescuer.visible_message("<span class='danger'>\The [rescuer] performs CPR on \the [src].</span>", SPAN_NOTICE("Still no pulse. Keep going."))
		return FALSE
	return restart_from_death(rescuer)

// Brain damage grows with the time the brain went without blood.
/mob/living/human/proc/apply_revival_brain_damage(dead_for)
	var/safe = config.defib_braindamage_timer MINUTES
	var/window = revival_window()
	if (dead_for <= safe || window <= safe)
		return
	var/scale = clamp((dead_for - safe) / (window - safe), 0, 1)
	var/damage = getBrainLoss() + (REVIVAL_BRAIN_DAMAGE_MAX - getBrainLoss()) * scale
	setBrainLoss(clamp(damage, getBrainLoss(), REVIVAL_BRAIN_DAMAGE_MAX))

// Brings a dead body back to life after a successful CPR round or shock.
/mob/living/human/proc/restart_from_death(mob/user)
	if (stat != DEAD || resuscitation_blocker())
		return FALSE
	var/dead_for = time_dead_for_revival()
	// Back just above death; the wounds that remain still need care.
	updatehealth()
	var/short = config.health_threshold_dead + 10 - health
	if (short > 0)
		adjustOxyLoss(-(min(getOxyLoss(), short)))
	revival_clock = 0
	unregister_corpse_decay()
	reset_corpse_decay_age()
	start_to_rot = FALSE
	rotting_stage = 0
	switch_from_dead_to_living_mob_list()
	timeofdeath = 0
	set_stat(UNCONSCIOUS) // Life() wakes them when they are well enough
	shock_stage = min(shock_stage, 100)
	var/obj/item/organ/heart/heart = internal_organs_by_name["heart"]
	if (istype(heart))
		heart.pulse = PULSE_NORM
		heart.handle_pulse()
	apply_revival_brain_damage(dead_for)
	if (islist(revival_recipe_nodes))
		known_recipe_nodes = revival_recipe_nodes
	revival_recipe_nodes = null
	never_set_faction_huds = TRUE
	regenerate_appearance()
	update_canmove()
	updatehealth()
	Weaken(rand(10, 25))
	visible_message("<span class='notice'>\The [src] jerks and gasps for breath!</span>")
	return_revived_spirit()
	if (persistence_owner_ckey && region_home_enabled())
		revival_home_note(persistence_owner_ckey)
	log_game("[user ? key_name(user) : "Someone"] resuscitated [key_name(src)] after [round(dead_for / 10)] seconds dead.")
	return TRUE

// A death sent the home back to the mainland; the living keep it here.
/proc/revival_home_note(account)
	set waitfor = FALSE
	region_home_note(account, "arrive")

// The person's ghost goes back into the body they were revived in.
/mob/living/human/proc/return_revived_spirit()
	var/mob/observer/ghost/G = revival_ghost()
	revival_ckey = null
	if (!G || !G.client || !G.can_reenter_corpse || ckey)
		return FALSE
	to_chat(G, "<span class='ghostalert'><font size=4>You have been resuscitated!</font></span>")
	G.reenter_corpse()
	return TRUE

#undef CPR_REVIVAL_CYCLE
#undef REVIVAL_POISON_LIMIT
#undef REVIVAL_BRAIN_DAMAGE_MAX
