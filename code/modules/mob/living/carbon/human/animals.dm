/mob/living/carbon/human/proc/handle_animalistic(var/type = "Default")
	if (type == "Default")
		if (icon_state != "human")
			src << "<font size=3>You become human again!</font>"
			icon = initial(icon)
			icon_state = "human"
			body_build = get_body_build(gender,"Default")
			icon_update = 1
			damage_multiplier = 1
			name = real_name
			update_hair()
			change_facial_hair()
			force_update_limbs()
			update_body()
	else if (type == "Gorilla")
		if (icon_state == "human")
			src << "<font size=3 color='red'>You turn into a gorilla!</font>"
			icon = 'icons/mob/human.dmi'
//			icon_update = 0
			icon_state = "gorilla"
			body_build = get_body_build(gender,"Gorilla")
			update_hair()
			change_facial_hair()
			force_update_limbs()
			update_body()
			damage_multiplier = 2
			name = "gorilla"
	else if (type == "Wolfman")
		switch (time_of_day)
			if ("Midday","Afternoon","Morning","Early Morning","Evening")
				if (icon_state != "human")
					src << "<font size=3>You become human again!</font>"
					handle_animalistic("Default")
			if ("Night")
				if (icon_state == "human")
					src << "<font size=3 color='red'>You turn into a werewolf!</font>"
					icon = 'icons/mob/human.dmi'
					icon_state = "werewolf"
//					icon_update = 0
					body_build = get_body_build(gender,"Wolfman")
					update_hair()
					change_facial_hair()
					force_update_limbs()
					update_body()
					strip(get_turf(src))
					damage_multiplier = 3
					name = "werewolf"