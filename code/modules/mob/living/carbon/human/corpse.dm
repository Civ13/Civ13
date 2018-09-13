/mob/living/carbon/human/corpse
	icon = 'icons/mob/human.dmi'
	icon_state = "corpse_map_state"

/mob/living/carbon/human/corpse/New()
	..()
	death()

/mob/living/carbon/human/corpse/pirate
	gender = MALE

/mob/living/carbon/human/corpse/pirate/New()
	..()
	icon_state = "human_m_s"
	var/spawntime = 0
	if (!job_master)
		spawntime = 5
	spawn (spawntime)
		if (!job_master)
			qdel(src)
			return
		job_master.EquipRank(src, "Pirate")
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()


/mob/living/carbon/human/corpse/british
	gender = MALE

/mob/living/carbon/human/corpse/british/New()
	..()
	icon_state = "human_m_s"
	var/spawntime = 0
	if (!job_master)
		spawntime = 5
	spawn (spawntime)
		if (!job_master)
			qdel(src)
			return
		job_master.EquipRank(src, "British Town Guard")
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()


/mob/living/carbon/human/corpse/Giant
	gender = MALE

/mob/living/carbon/human/corpse/Giant/New()
	..()
	icon_state = "body_m_giant"
	spawn (50) // must be here or they won't spawn, it seems - Kachnov
		death()