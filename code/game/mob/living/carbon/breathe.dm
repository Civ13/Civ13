//Common breathing procs

//Handle possble chem smoke effect
/mob/living/human/proc/handle_chemical_smoke(var/datum/gas_mixture/environment)
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

/mob/living/human/proc/handle_breath(datum/gas_mixture/breath)
	return TRUE

/mob/living/human/proc/handle_post_breath(datum/gas_mixture/breath)
	return TRUE