
/datum/job/spanish
	faction = "Station"

/datum/job/spanish/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_spanish_name(H.gender)
	H.real_name = H.name