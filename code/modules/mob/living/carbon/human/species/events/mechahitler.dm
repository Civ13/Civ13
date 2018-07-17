/mob/living/carbon/human/mechahitler
	takes_less_damage = TRUE
	movement_speed_multiplier = 1.50
	size_multiplier = 2.50
	f_style = "Square Mustache"
	has_hunger_and_thirst = FALSE

/mob/living/carbon/human/mechahitler/New(_loc, new_species, snowflake = FALSE)
	..(_loc, new_species)
	var/oloc = loc
	job_master.EquipRank(src, "Hauptmann")
	if (snowflake)
		spawn (1)
			loc = oloc
			name = "MECHA HITLER"
			real_name = "MECHA HITLER"
			setStat("strength", 450)
			setStat("engineering", 500)
			setStat("rifle", 500)
			setStat("mg", 500)
			setStat("smg", 500)
			setStat("pistol", 500)
			setStat("heavyweapon", 500)
			setStat("medical", 500)
			setStat("shotgun", 500)
			setStat("survival", 100)