/mob/living/carbon/human/corpse
	icon = 'icons/mob/human.dmi'
	icon_state = "corpse_map_state"

/mob/living/carbon/human/corpse/New()
	..()
	death()

/mob/living/carbon/human/corpse/SS
	gender = MALE

/mob/living/carbon/human/corpse/SS/New()
	..()
	icon_state = "body_m_s"
	var/spawntime = 0
	if (!job_master)
		spawntime = 300
	spawn (spawntime)
		if (!job_master)
			qdel(src)
			return
		job_master.EquipRank(src, "SS-Schutze")
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()
