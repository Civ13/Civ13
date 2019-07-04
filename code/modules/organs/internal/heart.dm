/obj/item/organ/heart
	name = "heart"
	icon_state = "heart-on"
	organ_tag = "heart"
	parent_organ = "chest"
	dead_icon = "heart-off"
	var/pulse = PULSE_NORM
	var/heartbeat = FALSE
	var/beat_sound = 'sound/effects/singlebeat.ogg'
	var/tmp/next_blood_squirt = 0
	var/efficiency = 1.0
	w_class = 2
	relative_size = 15
	max_damage = 45
	var/open
	var/list/external_pump

/obj/item/organ/heart/process()
	if (owner)
		handle_pulse()
		if (pulse)	handle_heartbeat()
		handle_blood()
	..()

/obj/item/organ/heart/proc/handle_pulse()
	if (owner.stat == DEAD)
		pulse = PULSE_NONE	//that's it, you're dead (or your metal heart is), nothing can influence your pulse
		return
	if (owner.life_tick % 5 == 0)//update pulse every 5 life ticks (~1 tick/sec, depending on server load)
		pulse = PULSE_NORM

		if (round(owner.vessel.get_reagent_amount("blood")) <= BLOOD_VOLUME_BAD)	//how much blood do we have
			pulse  = PULSE_THREADY	//not enough :(

		if (owner.status_flags & FAKEDEATH || owner.chem_effects[CE_NOPULSE])
			pulse = PULSE_NONE		//pretend that we're dead. unlike actual death, can be inflienced by meds

		pulse = Clamp(pulse + owner.chem_effects[CE_PULSE], PULSE_SLOW, PULSE_2FAST)

/obj/item/organ/heart/proc/handle_heartbeat()
	if (pulse >= PULSE_2FAST || owner.shock_stage >= 10)
		//PULSE_THREADY - maximum value for pulse, currently it 5.
		//High pulse value corresponds to a fast rate of heartbeat.
		//Divided by 2, otherwise it is too slow.
		var/rate = (PULSE_THREADY - pulse)/2

		if (heartbeat >= rate)
			heartbeat = FALSE
			//owner << sound(beat_sound,0,0,0,50)//Heartbeating sounds are really fucking annoying.
		else
			heartbeat++

/obj/item/organ/heart/proc/handle_blood()
	if (!owner)
		return
	if (owner.stat == DEAD && owner.bodytemperature >= 170)	//Dead or cryosleep people do not pump the blood.
		return

	var/blood_volume_raw = owner.vessel.get_reagent_amount("blood")
	var/blood_volume = round((blood_volume_raw/species.blood_volume)*100) // Percentage.

	blood_volume *= efficiency
	// Damaged heart virtually reduces the blood volume, as the blood isn't
	// being pumped properly anymore.
	if (is_broken())
		blood_volume *= 0.7
	else if (is_bruised())
		blood_volume *= 0.8

	//Effects of bloodloss
	switch(blood_volume)
		if (BLOOD_VOLUME_OKAY to BLOOD_VOLUME_SAFE)
			if (prob(1))
				owner << "<span class='warning'>You feel [pick("dizzy","woosey","faint")]</span>"
			if (owner.getOxyLoss() < 20 && prob(30))
				owner.adjustOxyLoss(1.0)
		if (BLOOD_VOLUME_BAD to BLOOD_VOLUME_OKAY)
			if (prob(15))
				owner.eye_blurry = max(owner.eye_blurry,6)
				if (owner.getOxyLoss() < 50)
					owner.adjustOxyLoss(3.0)
				owner.adjustOxyLoss(6.0)
				owner.Paralyse(rand(1,3))
				owner << "<span class='warning'>You feel extremely [pick("dizzy","woosey","faint")]</span>"
		if (BLOOD_VOLUME_SURVIVE to BLOOD_VOLUME_BAD)
			if (prob(15))
				owner << "<span class='warning'>You feel extremely [pick("dizzy","woosey","faint")]</span>"
				owner.adjustOxyLoss(10.0)
				owner.adjustToxLoss(7.0)
		else if (blood_volume < BLOOD_VOLUME_SURVIVE)
			owner.death()

	//Blood regeneration if there is some space
	if (blood_volume_raw < species.blood_volume)
		var/datum/reagent/blood/B = owner.get_blood(owner.vessel)
		B.volume += 0.1 // regenerate blood VERY slowly
		if (CE_BLOODRESTORE in owner.chem_effects)
			B.volume += owner.chem_effects[CE_BLOODRESTORE]

	if(pulse != PULSE_NONE)
		//Bleeding out
		var/blood_max = 0
		var/list/do_spray = list()
		for(var/obj/item/organ/external/temp in owner.organs)

			var/open_wound
			if(temp.status & ORGAN_BLEEDING)

				for(var/datum/wound/W in temp.wounds)

					if(!open_wound && (W.damage_type == CUT || W.damage_type == PIERCE) && W.damage && !W.is_treated())
						open_wound = TRUE

					if(W.bleeding())
						if(temp.applied_pressure)
							if(ishuman(temp.applied_pressure))
								var/mob/living/carbon/human/H = temp.applied_pressure
								H.bloody_hands(src, 0)
							//somehow you can apply pressure to every wound on the organ at the same time
							//you're basically forced to do nothing at all, so let's make it pretty effective
							var/min_eff_damage = max(0, W.damage - 10) / 6 //still want a little bit to drip out, for effect
							blood_max += max(min_eff_damage, W.damage - 30) / 40
						else
							blood_max += W.damage / 40

			if(temp.status & ORGAN_ARTERY_CUT)
				var/bleed_amount = Floor((owner.vessel.total_volume / (temp.applied_pressure ? 500 : 250))*temp.arterial_bleed_severity)
				if(bleed_amount)
					if(open_wound)
						blood_max += bleed_amount
						do_spray += "the [temp.artery_name] in \the [owner]'s [temp.name]"
					else
						owner.vessel.remove_reagent("blood", bleed_amount)

		switch(pulse)
			if(PULSE_SLOW)
				blood_max *= 0.8
			if(PULSE_FAST)
				blood_max *= 1.25
			if(PULSE_2FAST, PULSE_THREADY)
				blood_max *= 1.5

		if(CE_STABLE in owner.chem_effects) // inaprovaline
			blood_max *= 0.8

		if(world.time >= next_blood_squirt && istype(owner.loc, /turf) && do_spray.len)
			owner.visible_message("<span class='danger'>Blood squirts from [pick(do_spray)]!</span>")
			playsound(owner, 'sound/effects/gore/blood_splat.ogg', 100, 0)
			// It becomes very spammy otherwise. Arterial bleeding will still happen outside of this block, just not the squirt effect.
			next_blood_squirt = world.time + 100
			var/turf/sprayloc = get_turf(owner)
			blood_max -= owner.drip(ceil(blood_max/3), sprayloc)
			if(blood_max > 0)
				blood_max -= owner.blood_squirt(blood_max, sprayloc)
				if(blood_max > 0)
					owner.drip(blood_max, get_turf(owner))
		else
			owner.drip(blood_max)

/obj/item/organ/heart/proc/is_working()
	if(!is_usable())
		return FALSE

	return pulse > PULSE_NONE || (owner.status_flags & FAKEDEATH)