/mob/living/carbon/human/megastalin
	takes_less_damage = TRUE
	movement_speed_multiplier = 1.50
	size_multiplier = 3.00
	f_style = "Selleck Mustache"
	has_hunger_and_thirst = FALSE

/mob/living/carbon/human/megastalin/New(_loc, new_species, snowflake = FALSE)
	..(_loc, new_species)
	var/oloc = loc
	job_master.EquipRank(src, "Kapitan")
	if (snowflake)
		spawn (1)
			loc = oloc
			name = "MEGA STALIN"
			real_name = "MEGA STALIN"
			setStat("strength", 500)
			setStat("engineering", 450)
			setStat("rifle", 450)
			setStat("mg", 450)
			setStat("smg", 450)
			setStat("pistol", 450)
			setStat("heavyweapon", 450)
			setStat("medical", 450)
			setStat("shotgun", 450)
			setStat("survival", 100)