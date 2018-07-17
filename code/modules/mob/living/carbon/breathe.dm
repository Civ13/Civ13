//Common breathing procs

//Start of a breath chain, calls breathe()
/mob/living/carbon/handle_breathing()
	if (life_tick%2==0 || failed_last_breath || (health < config.health_threshold_crit)) 	//First, resolve location and get a breath
		breathe()

/mob/living/carbon/proc/breathe()
	return TRUE

/mob/living/carbon/proc/get_breath_from_internal(var/volume_needed=BREATH_VOLUME) //hopefully this will allow overrides to specify a different default volume without breaking any cases where volume is passed in.
	return TRUE

/mob/living/carbon/proc/get_breath_from_environment(var/volume_needed=BREATH_VOLUME)
	return volume_needed

//Handle possble chem smoke effect
/mob/living/carbon/proc/handle_chemical_smoke(var/datum/gas_mixture/environment)
/*	if (species && environment.return_pressure() < species.breath_pressure/5)
		return //pressure is too low to even breathe in.
		*/
	if (wear_mask && (wear_mask.flags & BLOCK_GAS_SMOKE_EFFECT))
		return

	for (var/obj/effect/effect/smoke/chem/smoke in view(1, src))
		if (smoke.reagents.total_volume)
			smoke.reagents.trans_to_mob(src, 5, CHEM_INGEST, copy = TRUE)
			smoke.reagents.trans_to_mob(src, 5, CHEM_BLOOD, copy = TRUE)
			// I dunno, maybe the reagents enter the blood stream through the lungs?
			break // If they breathe in the nasty stuff once, no need to continue checking

/mob/living/carbon/proc/handle_breath(datum/gas_mixture/breath)
	return TRUE

/mob/living/carbon/proc/handle_post_breath(datum/gas_mixture/breath)
	return TRUE