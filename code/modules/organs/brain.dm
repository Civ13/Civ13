/obj/item/organ/brain
	name = "brain"
	health = 60 //They need to live awhile longer than other organs. Is this even used by organ code anymore?
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
	var/damage_threshold_value = 10
	var/healed_threshold = 1
	var/oxygen_reserve = 90 //number of processes that the brain can hold with low blood pressure 1 process = 2 secs, according to current obj process


/obj/item/organ/brain/New()
	..()
	health = config.default_brain_health
	max_damage = 60
	if(species)
		max_damage = species.total_health
	min_bruised_damage = max_damage*0.25
	min_broken_damage = max_damage*0.75

	damage_threshold_value = round(max_damage / damage_threshold_count)

/obj/item/organ/brain/Destroy()
	. = ..()

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

		if(owner.paralysis < 1) // Skip it if we're already down.

			if(owner.stat == CONSCIOUS)
				if(damage > 0 && prob(1))
					owner.custom_pain("Your head feels numb and painful.",9)
				if(is_bruised() && prob(1) && owner.eye_blurry <= 0)
					to_chat(owner, "<span class='warning'>It becomes hard to see for some reason.</span>")
					owner.eye_blurry = 10
				if(is_broken() && prob(1) && owner.get_active_hand())
					to_chat(owner, "<span class='danger'>Your hand won't respond properly, and you drop what you are holding!</span>")
					owner.drop_item()
				if((damage >= (max_damage * 0.75)))
					if(!owner.lying && prob(2))
						to_chat(owner, "<span class='danger'>You black out!</span>")
						owner.Paralyse(10)

		// Brain damage from low oxygenation or lack of blood.
		// No heart? You are going to have a very bad time. Not 100% lethal because heart transplants should be a thing.
		var/blood_volume = owner.get_effective_blood_volume()

		if(owner.is_asystole()) // Heart is missing or isn't beating and we're not breathing (hardcrit)
			blood_volume = min(blood_volume, BLOOD_VOLUME_SURVIVE)
			owner.Paralyse(3)

		else
			var/blood_volume_mod = max(0, 1 - owner.getOxyLoss()/(owner.maxHealth/2))
			if(owner.chem_effects["oxygen"] == 1) // Dexalin.
				blood_volume_mod = max(blood_volume_mod, 0.5)
			else if(owner.chem_effects["oxygen"] >= 2) // Dexplus.
				blood_volume_mod = max(blood_volume_mod, 0.8)
			blood_volume = blood_volume * blood_volume_mod
		//Effects of bloodloss
		switch(blood_volume)

			if(BLOOD_VOLUME_SAFE to INFINITY)
				if((damage%damage_threshold_value)>=1)
					damage--
					if (oxygen_reserve < 90)
						oxygen_reserve++
			if(BLOOD_VOLUME_OKAY to BLOOD_VOLUME_SAFE)
				if(prob(1))
					to_chat(owner, "<span class='warning'>You feel [pick("dizzy","woozy","faint")]...</span>")
				if (oxygen_reserve > 0)
					oxygen_reserve--
				if(!past_damage_threshold(2) && oxygen_reserve <= 1)
					take_damage(1)
			if(BLOOD_VOLUME_BAD to BLOOD_VOLUME_OKAY)
				owner.eye_blurry = max(owner.eye_blurry,6)
				if (oxygen_reserve > 0)
					oxygen_reserve--
				if(!past_damage_threshold(4) && oxygen_reserve <= 1)
					take_damage(1)
				if(prob(15))
					owner.Paralyse(rand(1,3))
					to_chat(owner, "<span class='warning'>You feel extremely [pick("dizzy","woozy","faint")]...</span>")
			if(BLOOD_VOLUME_SURVIVE to BLOOD_VOLUME_BAD)
				owner.eye_blurry = max(owner.eye_blurry,6)
				if (oxygen_reserve > 0)
					oxygen_reserve--
				if(!past_damage_threshold(6) && oxygen_reserve <= 1)
					take_damage(1)
				if(prob(15))
					owner.Paralyse(3,5)
					to_chat(owner, "<span class='warning'>You feel extremely [pick("dizzy","woozy","faint")]...</span>")
			if(-(INFINITY) to BLOOD_VOLUME_SURVIVE) // Also see heart.dm, being below this point puts you into cardiac arrest.
				owner.eye_blurry = max(owner.eye_blurry,6)
				if (oxygen_reserve > 0)
					oxygen_reserve -= 2
				if (oxygen_reserve <= 1)
					take_damage(1)
	..()
