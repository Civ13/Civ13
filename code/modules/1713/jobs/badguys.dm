////////////////////////////////////////////CIVILIAN///////////////////////////////////////////////////////
/datum/job/civilian
	faction = "Human"

/datum/job/civilian/give_random_name(var/mob/living/human/H)
	if (is_civilizations || is_nomad)
		H.name = H.species.get_random_name(H.gender)
		H.real_name = H.name
	else
		H.give_random_civ_name()

