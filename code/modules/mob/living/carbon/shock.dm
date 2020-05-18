/mob/living/var/traumatic_shock = FALSE
/mob/living/human/var/shock_stage = FALSE

// proc to find out in how much pain the mob is at the moment
/mob/living/human/proc/updateshock()

	traumatic_shock = 			\
	1	* getOxyLoss() + 		\
	0.7	* getToxLoss() + 		\
	1.5	* getFireLoss() + 		\
	1.7	* getBruteLoss() + 		\
	1.7	* getCloneLoss() + 		\
	0.5	* halloss + 			\
	-1	* analgesic

	// broken or ripped off organs will add quite a bit of pain
	if (istype(src,/mob/living/human))
		var/mob/living/human/M = src
		for (var/obj/item/organ/external/organ in M.organs)
			if (organ && (organ.is_broken() || organ.open))
				traumatic_shock += 30

	if (bloodstr)
		for (var/datum/reagent/ethanol/E in ingested.reagent_list)
			traumatic_shock -= E.volume
		for (var/datum/reagent/adrenaline/A in ingested.reagent_list)
			traumatic_shock -= A.volume*2
			shock_stage -= A.volume/2
		for (var/datum/reagent/opium/O in ingested.reagent_list)
			traumatic_shock -= O.volume/2
			shock_stage -= O.volume/4
	if (traumatic_shock < 0)
		traumatic_shock = FALSE

	return traumatic_shock
