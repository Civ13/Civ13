/mob/living/human
	var/prev_tone = null
/mob/living/human/proc/handle_animalistic(var/type = "Default")
	switch (type)
		if ("Default")
			if (body_build.name != "Default")
				icon = 'icons/mob/human.dmi'
				icon_update = 1
				icon_state = "human"
				s_tone = prev_tone
				src << "<font size=3>You become human again!</font>"
				body_build = get_body_build(gender,"Default")
				damage_multiplier = 1
				movement_speed_multiplier = 1.0
				update_hair()
				change_facial_hair()
				force_update_limbs()
				update_body()
				species.unarmed_attacks = list()
				species.unarmed_attacks += new /datum/unarmed_attack/stomp()
				species.unarmed_attacks += new /datum/unarmed_attack/kick()
				species.unarmed_attacks += new /datum/unarmed_attack/punch()
				species.unarmed_attacks += new /datum/unarmed_attack/bite()
		if ("Satyr")
			if (body_build.name != "Satyr")
				icon = 'icons/mob/human.dmi'
				icon_update = 1
				s_tone = prev_tone
				src << "<font size=3>You turn into a satyr!</font>"
				body_build = get_body_build(gender,"Satyr")
				damage_multiplier = 1
				movement_speed_multiplier = 1.0
				update_hair()
				change_facial_hair()
				force_update_limbs()
				update_body()
				species.unarmed_attacks = list()
				species.unarmed_attacks += new /datum/unarmed_attack/stomp()
				species.unarmed_attacks += new /datum/unarmed_attack/kick()
				species.unarmed_attacks += new /datum/unarmed_attack/punch()
				species.unarmed_attacks += new /datum/unarmed_attack/bite()
		if ("Gorilla")
			if (body_build.name == "Default")
				src << "<font size=3 color='red'>You turn into a Gorilla!</font>"
				icon = 'icons/mob/human.dmi'
				body_build = get_body_build(gender,"Gorilla")
				prev_tone = s_tone
				s_tone = null
				update_hair()
				change_facial_hair()
				force_update_limbs()
				update_body(1,1)
				regenerate_icons()
				damage_multiplier = 2
				movement_speed_multiplier = 1.0
				species.unarmed_attacks = list()
				species.unarmed_attacks += new /datum/unarmed_attack/stomp()
				species.unarmed_attacks += new /datum/unarmed_attack/kick()
				species.unarmed_attacks += new /datum/unarmed_attack/punch()
				species.unarmed_attacks += new /datum/unarmed_attack/bite()
		if ("Orc")
			if (body_build.name == "Default")
				src << "<font size=3 color='red'>You turn into an Orc!</font>"
				icon = 'icons/mob/human.dmi'
				body_build = pick(get_body_build(gender,"Orc"),get_body_build(gender,"Dark Orc"),get_body_build(gender,"Brown Orc"))
				prev_tone = s_tone
				s_tone = null
				update_hair()
				change_facial_hair()
				force_update_limbs()
				update_body(1,1)
				regenerate_icons()
				damage_multiplier = 1.5
				movement_speed_multiplier = 0.9
				species.unarmed_attacks = list()
				species.unarmed_attacks += new /datum/unarmed_attack/stomp()
				species.unarmed_attacks += new /datum/unarmed_attack/kick()
				species.unarmed_attacks += new /datum/unarmed_attack/punch()
				species.unarmed_attacks += new /datum/unarmed_attack/bite()
		if ("Goblin")
			if (body_build.name == "Default")
				src << "<font size=3 color='red'>You turn into a Goblin, gobbel gobbel!</font>"
				icon = 'icons/mob/human.dmi'
				body_build = pick(get_body_build(gender,"Goblin"))
				prev_tone = s_tone
				s_tone = null
				update_hair()
				change_facial_hair()
				force_update_limbs()
				update_body(1,1)
				regenerate_icons()
				damage_multiplier = 0.8
				movement_speed_multiplier = 1.6
				species.unarmed_attacks = list()
				species.unarmed_attacks += new /datum/unarmed_attack/stomp()
				species.unarmed_attacks += new /datum/unarmed_attack/kick()
				species.unarmed_attacks += new /datum/unarmed_attack/punch()
				species.unarmed_attacks += new /datum/unarmed_attack/bite()
		if ("Ant")
			if (body_build.name == "Default")
				src << "<font size=3 color='red'>You turn into an Ant!</font>"
				icon = 'icons/mob/human.dmi'
				body_build = pick(get_body_build(gender,"Ant"),get_body_build(gender,"Black Ant"),get_body_build(gender,"Yellow Ant"))
				prev_tone = s_tone
				s_tone = null
				update_hair()
				change_facial_hair()
				force_update_limbs()
				update_body(1,1)
				movement_speed_multiplier = 1.0
				regenerate_icons()
				species.unarmed_attacks = list()
				species.unarmed_attacks += new /datum/unarmed_attack/stomp()
				species.unarmed_attacks += new /datum/unarmed_attack/kick()
				species.unarmed_attacks += new /datum/unarmed_attack/punch()
				species.unarmed_attacks += new /datum/unarmed_attack/bite()
		if ("Lizard")
			if (body_build.name == "Default")
				src << "<font size=3 color='red'>You turn into a Lizard!</font>"
				icon = 'icons/mob/human.dmi'
				body_build = get_body_build(gender,"Lizard")
				prev_tone = s_tone
				s_tone = null
				update_hair()
				change_facial_hair()
				force_update_limbs()
				update_body(1,1)
				movement_speed_multiplier = 1.2
				regenerate_icons()
				species.unarmed_attacks = list()
				species.unarmed_attacks += new /datum/unarmed_attack/stomp()
				species.unarmed_attacks += new /datum/unarmed_attack/claws()
				species.unarmed_attacks += new /datum/unarmed_attack/bite/sharp()
		if ("Crab")
			if (body_build.name == "Default")
				src << "<font size=3 color='red'>You turn into a Crustacean!</font>"
				icon = 'icons/mob/human.dmi'
				body_build = get_body_build(gender,"Crab")
				prev_tone = s_tone
				s_tone = null
				update_hair()
				change_facial_hair()
				force_update_limbs()
				update_body(1,1)
				movement_speed_multiplier = 0.8
				damage_multiplier = 1.5
				regenerate_icons()
				species.unarmed_attacks = list()
				species.unarmed_attacks += new /datum/unarmed_attack/stomp()
				species.unarmed_attacks += new /datum/unarmed_attack/claws()
				species.unarmed_attacks += new /datum/unarmed_attack/bite/sharp()

		if ("Wolf")
			if (body_build.name == "Default")
				src << "<font size=3 color='red'>You turn into a Wolf!</font>"
				icon = 'icons/mob/human.dmi'
				body_build = get_body_build(gender,"Wolfman")
				prev_tone = s_tone
				s_tone = null
				update_hair()
				change_facial_hair()
				force_update_limbs()
				damage_multiplier = 2
				update_body(1,1)
				movement_speed_multiplier = 1.3
				regenerate_icons()
				species.unarmed_attacks = list()
				species.unarmed_attacks += new /datum/unarmed_attack/stomp()
				species.unarmed_attacks += new /datum/unarmed_attack/claws/strong()
				species.unarmed_attacks += new /datum/unarmed_attack/bite/sharp()
		if ("Werewolf")
			switch (time_of_day)
				if ("Midday","Afternoon","Morning","Early Morning","Evening")
					if (body_build.name != "Default")
						src << "<font size=3>You become human again!</font>"
						handle_animalistic("Default")
						s_tone = prev_tone
				if ("Night")
					if (body_build.name == "Default")
						src << "<font size=3 color='red'>You turn into a werewolf!</font>"
						icon_state = "werewolf"
						body_build = get_body_build(gender,"Werewolf")
						prev_tone = s_tone
						s_tone = null
						update_hair()
						change_facial_hair()
						force_update_limbs()
						update_body()
						strip(get_turf(src))
						damage_multiplier = 3
						movement_speed_multiplier = 1.4
						icon_update = 0
						species.unarmed_attacks = list()
						species.unarmed_attacks += new /datum/unarmed_attack/stomp()
						species.unarmed_attacks += new /datum/unarmed_attack/claws()
						species.unarmed_attacks += new /datum/unarmed_attack/bite/sharp()