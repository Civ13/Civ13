/mob/living/human/announcer

/mob/living/human/announcer/New(var/new_loc, var/new_species = null)
	..(new_loc, new_species)
	mob_list -= src
	unregister_living_mob(src)
	human_mob_list -= src