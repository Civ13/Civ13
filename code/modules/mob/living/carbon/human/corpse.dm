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
	invisibility = 101
	if (!job_master)
		spawntime = 5
	spawn (spawntime)
		if (!job_master)
			qdel(src)
			return
		job_master.EquipRank(src, "Pirate")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(6,7))
		name = "Pirate"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()

mob/living/carbon/human/corpse/british_sailor
	gender = MALE

/mob/living/carbon/human/corpse/british_sailor/New()
	..()
	icon_state = "human_m_s"
	var/spawntime = 0
	invisibility = 101
	if (!job_master)
		spawntime = 5
	spawn (spawntime)
		if (!job_master)
			qdel(src)
			return
		job_master.EquipRank(src, "Royal Navy Seaman")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(6,7))
		apply_damage(rand(0, 35), BRUTE, "head")
		apply_damage(rand(0, 35), BRUTE, "chest")
		apply_damage(rand(0, 35), BRUTE, "l_leg")
		apply_damage(rand(0, 35), BRUTE, "r_leg")
		apply_damage(rand(0, 35), BRUTE, "l_arm")
		apply_damage(rand(0, 35), BRUTE, "r_arm")
		updatehealth()//.
		name = "Royal Navy Seaman"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()

/mob/living/carbon/human/corpse/british
	gender = MALE

/mob/living/carbon/human/corpse/british/New()
	..()
	icon_state = "human_m_s"
	var/spawntime = 0
	invisibility = 101
	if (!job_master)
		spawntime = 5
	spawn (spawntime)
		if (!job_master)
			qdel(src)
			return
		job_master.EquipRank(src, "British Town Guard")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(6,7))
		name = "Redcoat Soldier"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()

/mob/living/carbon/human/corpse/japanese
	gender = MALE

/mob/living/carbon/human/corpse/japanese/New()
	..()
	icon_state = "human_m_s"
	var/spawntime = 0
	invisibility = 101
	if (!job_master)
		spawntime = 5
	spawn (spawntime)
		if (!job_master)
			qdel(src)
			return
		job_master.EquipRank(src, "Nitohei")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(6,7))
		name = "Japanese Soldier"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()

/mob/living/carbon/human/corpse/russian
	gender = MALE

/mob/living/carbon/human/corpse/russian/New()
	..()
	icon_state = "human_m_s"
	var/spawntime = 0
	invisibility = 101
	if (!job_master)
		spawntime = 5
	spawn (spawntime)
		if (!job_master)
			qdel(src)
			return
		job_master.EquipRank(src, "Ryadovoy")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(6,7))
		name = "Russian Soldier"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()

/mob/living/carbon/human/corpse/russiansgt
	gender = MALE

/mob/living/carbon/human/corpse/russiansgt/New()
	..()
	icon_state = "human_m_s"
	var/spawntime = 0
	invisibility = 101
	if (!job_master)
		spawntime = 5
	spawn (spawntime)
		if (!job_master)
			qdel(src)
			return
		job_master.EquipRank(src, "Feldvebel")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(6,7))
		name = "Russian Sergeant"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()

/mob/living/carbon/human/corpse/japanesesgt
	gender = MALE

/mob/living/carbon/human/corpse/japanesesgt/New()
	..()
	icon_state = "human_m_s"
	var/spawntime = 0
	invisibility = 101
	if (!job_master)
		spawntime = 5
	spawn (spawntime)
		if (!job_master)
			qdel(src)
			return
		job_master.EquipRank(src, "Gunso")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(6,7))
		name = "Japanese Sergeant"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()


/mob/living/carbon/human/corpse/japanesecap
	gender = MALE

/mob/living/carbon/human/corpse/japanesecap/New()
	..()
	icon_state = "human_m_s"
	var/spawntime = 0
	invisibility = 101
	if (!job_master)
		spawntime = 5
	spawn (spawntime)
		if (!job_master)
			qdel(src)
			return
		job_master.EquipRank(src, "Rikugun-Tai-i")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(6,7))
		name = "Japanese Captain"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()


/mob/living/carbon/human/corpse/Giant
	gender = MALE

/mob/living/carbon/human/corpse/Giant/New()
	..()
	icon_state = "body_m_giant"
	spawn (50) // must be here or they won't spawn, it seems - Kachnov
		death()