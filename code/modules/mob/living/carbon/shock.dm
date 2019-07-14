/mob/living/var/traumatic_shock = FALSE
/mob/living/carbon/var/shock_stage = FALSE

// proc to find out in how much pain the mob is at the moment
/mob/living/carbon/proc/updateshock()

	traumatic_shock = 			\
	1	* getOxyLoss() + 		\
	0.7	* getToxLoss() + 		\
	1.5	* getFireLoss() + 		\
	1.2	* getBruteLoss() + 		\
	1.7	* getCloneLoss() + 		\
	2	* halloss + 			\
	-1	* analgesic

	// broken or ripped off organs will add quite a bit of pain
	if (istype(src,/mob/living/carbon/human))
		var/mob/living/carbon/human/M = src
		for (var/obj/item/organ/external/organ in M.organs)
			if (organ && (organ.is_broken() || organ.open))
				traumatic_shock += 30

	if (bloodstr)
		for (var/datum/reagent/ethanol/E in ingested.reagent_list)
			traumatic_shock -= E.volume
		for (var/datum/reagent/adrenaline/A in ingested.reagent_list)
			traumatic_shock -= A.volume
			shock_stage -= A.volume/4
		for (var/datum/reagent/opium/O in ingested.reagent_list)
			traumatic_shock -= O.volume/4
			shock_stage -= O.volume/8
	if (traumatic_shock < 0)
		traumatic_shock = FALSE

	return traumatic_shock
