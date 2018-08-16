/datum/job/french
	faction = "Station"

/datum/job/french/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_french_name(H.gender)
	H.real_name = H.name
