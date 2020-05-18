/mob/living/human/corpse
	icon = 'icons/mob/human.dmi'
	icon_state = "corpse_map_state"

/mob/living/human/corpse/New()
	..()
	death()

/mob/living/human/corpse/pirate
	gender = MALE

/mob/living/human/corpse/pirate/New()
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

mob/living/human/corpse/british_sailor
	gender = MALE

/mob/living/human/corpse/british_sailor/New()
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

/mob/living/human/corpse/british
	gender = MALE

/mob/living/human/corpse/british/New()
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

/mob/living/human/corpse/japanese
	gender = MALE

/mob/living/human/corpse/japanese/New()
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
		job_master.EquipRank(src, "Shiro Nitohei")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(6,7))
		name = "Japanese Soldier"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()

/mob/living/human/corpse/japanese_ww2
	gender = MALE

/mob/living/human/corpse/japanese_ww2/New()
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

/mob/living/human/corpse/japanese_ww2_antitank
	gender = MALE

/mob/living/human/corpse/japanese_ww2_antitank/New()
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
		job_master.EquipRank(src, "Nitohei Taisen-sha")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(6,7))
		name = "Japanese Soldier"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()

/mob/living/human/corpse/ww2_jap_sl
	gender = MALE

/mob/living/human/corpse/ww2_jap_sl/New()
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
		job_master.EquipRank(src, "IJA Gunso")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(6,7))
		name = "Japanese Sergeant"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()

/mob/living/human/corpse/ww2_jap_medic
	gender = MALE

/mob/living/human/corpse/ww2_jap_medic/New()
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
		job_master.EquipRank(src, "Sento-i")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(6,7))
		name = "Japanese Medic"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()

/mob/living/human/corpse/ww2_jap_mg
	gender = MALE

/mob/living/human/corpse/ww2_jap_mg/New()
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
		job_master.EquipRank(src, "Taiho")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(6,7))
		name = "Japanese Machinegunner"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()
/mob/living/human/corpse/russian
	gender = MALE

/mob/living/human/corpse/russian/New()
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

/mob/living/human/corpse/russian_soviet
	gender = MALE

/mob/living/human/corpse/russian_soviet/New()
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
		job_master.EquipRank(src, "K.A. Soldat")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(6,7))
		name = "Russian Soldier"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()

/mob/living/human/corpse/russian_soviet_sgt
	gender = MALE

/mob/living/human/corpse/russian_soviet_sgt/New()
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
		job_master.EquipRank(src, "K.A. Serjant")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(6,7))
		name = "Russian Sergeant"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()

mob/living/human/corpse/russian_soviet_tanker
	gender = MALE

/mob/living/human/corpse/russian_soviet_tanker/New()
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
		job_master.EquipRank(src, "Tankist")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(6,7))
		name = "Russian Tanker"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()

/mob/living/human/corpse/russiansgt
	gender = MALE

/mob/living/human/corpse/russiansgt/New()
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

/mob/living/human/corpse/japanesesgt
	gender = MALE

/mob/living/human/corpse/japanesesgt/New()
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


/mob/living/human/corpse/japanesecap
	gender = MALE

/mob/living/human/corpse/japanesecap/New()
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


/mob/living/human/corpse/Giant
	gender = MALE

/mob/living/human/corpse/Giant/New()
	..()
	icon_state = "body_m_giant"
	spawn (50) // must be here or they won't spawn, it seems - Kachnov
		death()

/mob/living/human/corpse/prisoner
	gender = MALE

/mob/living/human/corpse/prisoner/New()
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
		job_master.EquipRank(src, "DO NOT USE")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(6,7))
		name = "Escaped Prisoner"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()

/mob/living/human/corpse/bandit
	gender = MALE
	h_style = "Fade"

/mob/living/human/corpse/bandit/New()
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
		job_master.EquipRank(src, "Bandit")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(30,45))
		name = "Bandit"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()

/mob/living/human/corpse/pmc
	gender = MALE

/mob/living/human/corpse/pmc/New()
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
		job_master.EquipRank(src, "Bandit")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(30,45))
		name = "pmc"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()

/mob/living/human/corpse/ww2_american
	gender = MALE

/mob/living/human/corpse/ww2_american/New()
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
		job_master.EquipRank(src, "US Rifleman")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(30,45))
		name = "American Soldier"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()

/mob/living/human/corpse/ww2_american_medic
	gender = MALE

/mob/living/human/corpse/ww2_american_medic/New()
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
		job_master.EquipRank(src, "US Field Medic")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(30,45))
		name = "American Medic"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()

/mob/living/human/corpse/ww2_american_sl
	gender = MALE

/mob/living/human/corpse/ww2_american_sl/New()
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
		job_master.EquipRank(src, "US Sergeant")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(30,45))
		name = "American Sergeant"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()

/mob/living/human/corpse/ww2_american_mg
	gender = MALE

/mob/living/human/corpse/ww2_american_mg/New()
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
		job_master.EquipRank(src, "US Machine Gunner")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(30,45))
		name = "American Machinegunner"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()

/mob/living/human/corpse/beggar
	gender = MALE

/mob/living/human/corpse/beggar/New()
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
		job_master.EquipRank(src, "Beggar")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(30,45))
		name = "Beggar"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()

/mob/living/human/corpse/beggar_f
	gender = FEMALE

/mob/living/human/corpse/beggar_f/New()
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
		job_master.EquipRank(src, "Beggar")
		dir = pick(NORTH,SOUTH,EAST,WEST)
		adjustBruteLoss(rand(30,45))
		name = "Beggar"
		invisibility = 0
		spawn (50) // must be here or they won't spawn, it seems - Kachnov
			death()