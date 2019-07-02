/obj/item/organ/brain
	name = "brain"
	health = 200 //They need to live awhile longer than other organs. Is this even used by organ code anymore?
	desc = "A piece of juicy meat found in a person's head."
	organ_tag = "brain"
	parent_organ = "head"
	vital = TRUE
	icon_state = "brain"
	force = 1.0
	w_class = 2.0
	throwforce = 1.0
	throw_speed = 3
	throw_range = 5
	relative_size = 60
	attack_verb = list("attacked", "slapped", "whacked")
	var/mob/living/carbon/brain/brainmob = null

	var/const/damage_threshold_count = 10
	var/damage_threshold_value
	var/healed_threshold = 1
	var/oxygen_reserve = 6

/obj/item/organ/brain/New()
	..()
	health = config.default_brain_health

/obj/item/organ/brain/Destroy()
	..()

/obj/item/organ/brain/examine(mob/user) // -- TLE
	..(user)
	user << "This one seems particularly lifeless. Perhaps it will regain some of its luster later.."

/obj/item/organ/brain/removed(var/mob/living/user)

	name = "[owner.real_name]'s brain"

	..()

/obj/item/organ/brain/replaced(var/mob/living/target)

	if (target.key)
		target.ghostize()
	..()

/obj/item/organ/brain/proc/take_internal_damage(var/damage, var/silent)
	set waitfor = 0
	..()
	if(damage >= 10) //This probably won't be triggered by oxyloss or mercury. Probably.
		var/damage_secondary = damage * 0.20
		owner.eye_blurry += damage_secondary
		owner.confused += damage_secondary * 2
		owner.Paralyse(damage_secondary)
		owner.Weaken(round(damage, 1))

/obj/item/organ/brain/proc/brain_damage_callback(var/damage) //Confuse them as a somewhat uncommon aftershock. Side note: Only here so a spawn isn't used. Also, for the sake of a unique timer.
	to_chat(owner, "<span class = 'notice' font size='10'><B>I can't remember which way is forward...</B></span>")
	owner.confused += damage

/obj/item/organ/brain/proc/handle_disabilities()
	return

/obj/item/organ/brain/proc/handle_damage_effects()
	if(owner.stat)
		return
	if(damage > 0 && prob(1))
		owner.custom_pain("Your head feels numb and painful.",10)
	if(is_bruised() && prob(1) && owner.eye_blurry <= 0)
		to_chat(owner, "<span class='warning'>It becomes hard to see for some reason.</span>")
		owner.eye_blurry = 10
	if(damage >= 0.5*max_damage && prob(1) && owner.get_active_hand())
		to_chat(owner, "<span class='danger'>Your hand won't respond properly, and you drop what you are holding!</span>")
		owner.drop_item()
	if(damage >= 0.6*max_damage)
		owner.slurring = max(owner.slurring, 2)
	if(is_broken())
		if(!owner.lying)
			to_chat(owner, "<span class='danger'>You black out!</span>")
		owner.Paralyse(10)


/obj/item/organ/brain/proc/can_recover()
	return ~status & ORGAN_DEAD

/obj/item/organ/brain/proc/get_current_damage_threshold()
	return round(damage / damage_threshold_value)

/obj/item/organ/brain/proc/past_damage_threshold(var/threshold)
	return (get_current_damage_threshold() > threshold)

/obj/item/organ/brain/proc/handle_severe_brain_damage()
	set waitfor = FALSE
	healed_threshold = 0
	to_chat(owner, "<span class = 'notice' font size='10'><B>Where am I...?</B></span>")
	sleep(5 SECONDS)
	if(!owner)
		return
	to_chat(owner, "<span class = 'notice' font size='10'><B>What's going on...?</B></span>")
	sleep(10 SECONDS)
	if(!owner)
		return
	to_chat(owner, "<span class = 'notice' font size='10'><B>What happened...?</B></span>")
	alert(owner, "You have taken massive brain damage! You will not be able to remember the events leading up to your injury.", "Brain Damaged")

/obj/item/organ/brain/process()
	if(owner)
		if(damage > max_damage / 2 && healed_threshold)
			handle_severe_brain_damage()

		if(damage < (max_damage / 4))
			healed_threshold = 1

		handle_disabilities()
		handle_damage_effects()

		// Brain damage from low oxygenation or lack of blood.
		// No heart? You are going to have a very bad time. Not 100% lethal because heart transplants should be a thing.
		var/blood_volume = owner.get_blood_oxygenation()
		if(blood_volume < BLOOD_VOLUME_SURVIVE)
			if(!owner.chem_effects[CE_STABLE] || prob(60))
				oxygen_reserve = max(0, oxygen_reserve-1)
		else
			oxygen_reserve = min(initial(oxygen_reserve), oxygen_reserve+1)
		if(!oxygen_reserve) //(hardcrit)
			owner.Paralyse(3)
		var/can_heal = damage && damage < max_damage && (damage % damage_threshold_value || (!past_damage_threshold(3) && owner.chem_effects[CE_STABLE]))
		var/damprob
		//Effects of bloodloss
		switch(blood_volume)

			if(BLOOD_VOLUME_SAFE to INFINITY)
				if(can_heal)
					damage = max(damage-1, 0)
			if(BLOOD_VOLUME_OKAY to BLOOD_VOLUME_SAFE)
				if(prob(1))
					to_chat(owner, "<span class='warning'>You feel [pick("dizzy","woozy","faint")]...</span>")
				damprob = owner.chem_effects[CE_STABLE] ? 30 : 60
				if(!past_damage_threshold(2) && prob(damprob))
					take_internal_damage(1)
			if(BLOOD_VOLUME_BAD to BLOOD_VOLUME_OKAY)
				owner.eye_blurry = max(owner.eye_blurry,6)
				damprob = owner.chem_effects[CE_STABLE] ? 40 : 80
				if(!past_damage_threshold(4) && prob(damprob))
					take_internal_damage(1)
				if(!owner.paralysis && prob(10))
					owner.Paralyse(rand(1,3))
					to_chat(owner, "<span class='warning'>You feel extremely [pick("dizzy","woozy","faint")]...</span>")
			if(BLOOD_VOLUME_SURVIVE to BLOOD_VOLUME_BAD)
				owner.eye_blurry = max(owner.eye_blurry,6)
				damprob = owner.chem_effects[CE_STABLE] ? 60 : 100
				if(!past_damage_threshold(6) && prob(damprob))
					take_internal_damage(1)
				if(!owner.paralysis && prob(15))
					owner.Paralyse(3,5)
					to_chat(owner, "<span class='warning'>You feel extremely [pick("dizzy","woozy","faint")]...</span>")
			if(-(INFINITY) to BLOOD_VOLUME_SURVIVE) // Also see heart.dm, being below this point puts you into cardiac arrest.
				owner.eye_blurry = max(owner.eye_blurry,6)
				damprob = owner.chem_effects[CE_STABLE] ? 80 : 100
				if(prob(damprob))
					take_internal_damage(1)
				if(prob(damprob))
					take_internal_damage(1)

