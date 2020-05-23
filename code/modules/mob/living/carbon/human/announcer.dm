/mob/living/human/announcer

/mob/living/human/announcer/New(var/new_loc, var/new_species = null)
	..(new_loc, new_species)
	mob_list -= src
	living_mob_list -= src
	human_mob_list -= src