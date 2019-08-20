
/*
	apply_damage(a,b,c)
	args
	a:damage - How much damage to take
	b:damage_type - What type of damage to take, brute, burn
	c:def_zone - Where to take the damage if its brute or burn
	Returns
	standard FALSE if fail
*/
/mob/living/proc/apply_damage(var/damage = 0,var/damagetype = BRUTE, var/def_zone = null, var/blocked = FALSE, var/used_weapon = null, var/sharp = FALSE, var/edge = FALSE)
	if (!damage || (blocked >= 2))	return FALSE
	switch(damagetype)
		if (BRUTE)
			adjustBruteLoss(damage/(blocked+1))
		if (BURN)
			adjustFireLoss(damage/(blocked+1))
		if (TOX)
			adjustToxLoss(damage/(blocked+1))
		if (OXY)
			adjustOxyLoss(damage/(blocked+1))
		if (CLONE)
			adjustCloneLoss(damage/(blocked+1))
		if (HALLOSS)
			adjustHalLoss(damage/(blocked+1))
	flash_weak_pain()
	updatehealth()
	return TRUE


/mob/living/proc/apply_damages(var/brute = FALSE, var/burn = FALSE, var/tox = FALSE, var/oxy = FALSE, var/clone = FALSE, var/halloss = FALSE, var/def_zone = null, var/blocked = FALSE)
	if (blocked >= 2)	return FALSE
	if (brute)	apply_damage(brute, BRUTE, def_zone, blocked)
	if (burn)	apply_damage(burn, BURN, def_zone, blocked)
	if (tox)	apply_damage(tox, TOX, def_zone, blocked)
	if (oxy)	apply_damage(oxy, OXY, def_zone, blocked)
	if (clone)	apply_damage(clone, CLONE, def_zone, blocked)
	if (halloss) apply_damage(halloss, HALLOSS, def_zone, blocked)
	return TRUE



/mob/living/proc/apply_effect(var/effect = FALSE,var/effecttype = STUN, var/blocked = FALSE, var/check_protection = TRUE)
	if (!effect || (blocked >= 2))	return FALSE
	switch(effecttype)
		if (STUN)
			Stun(effect/(blocked+1))
		if (WEAKEN)
			Weaken(effect/(blocked+1))
		if (PARALYZE)
			Paralyse(effect/(blocked+1))
		if (AGONY)
			halloss += effect // Useful for objects that cause "subdual" damage. PAIN!
		if (IRRADIATE)
			var/rad_protection = check_protection ? getarmor(null, "rad")/100 : FALSE
			rad_act(max((1-rad_protection)*effect/(blocked+1),0))//Rads auto check armor
		if (STUTTER)
			if (status_flags & CANSTUN) // stun is usually associated with stutter
				stuttering = max(stuttering,(effect/(blocked+1)))
		if (EYE_BLUR)
			eye_blurry = max(eye_blurry,(effect/(blocked+1)))
		if (DROWSY)
			drowsyness = max(drowsyness,(effect/(blocked+1)))
	updatehealth()
	return TRUE


/mob/living/proc/apply_effects(var/stun = FALSE, var/weaken = FALSE, var/paralyze = FALSE, var/irradiate = FALSE, var/stutter = FALSE, var/eyeblur = FALSE, var/drowsy = FALSE, var/agony = FALSE, var/blocked = FALSE)
	if (blocked >= 2)	return FALSE
	if (stun)		apply_effect(stun, STUN, blocked)
	if (weaken)		apply_effect(weaken, WEAKEN, blocked)
	if (paralyze)	apply_effect(paralyze, PARALYZE, blocked)
	if (irradiate)	apply_effect(irradiate, IRRADIATE, blocked)
	if (stutter)	apply_effect(stutter, STUTTER, blocked)
	if (eyeblur)	apply_effect(eyeblur, EYE_BLUR, blocked)
	if (drowsy)		apply_effect(drowsy, DROWSY, blocked)
	if (agony)		apply_effect(agony, AGONY, blocked)
	return TRUE

/mob/living/proc/updatehealth()
	if (status_flags & GODMODE)
		health = 100
		stat = CONSCIOUS
	else
		health = maxHealth - getOxyLoss() - getToxLoss() - getFireLoss() - getBruteLoss() - getCloneLoss() - halloss
	if (health <= 0) // experimental block
		death()