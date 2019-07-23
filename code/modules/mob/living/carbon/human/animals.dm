/mob/living/carbon/human
	var/prev_tone = null
/mob/living/carbon/human/proc/handle_animalistic(var/type = "Default")
	if (type == "Default")
		if (body_build.name != "Default")
			icon = 'icons/mob/human.dmi'
			icon_update = 1
			icon_state = "human"
			s_tone = prev_tone
			src << "<font size=3>You become human again!</font>"
			body_build = get_body_build(gender,"Default")
			damage_multiplier = 1
			update_hair()
			change_facial_hair()
			force_update_limbs()
			update_body()
	else if (type == "Gorilla")
		if (body_build.name == "Default")
			src << "<font size=3 color='red'>You turn into a gorilla!</font>"
			icon = 'icons/mob/human.dmi'
			body_build = get_body_build(gender,"Gorilla")
			prev_tone = s_tone
			s_tone = null
			update_hair()
			change_facial_hair()
			force_update_limbs()
			update_body(1,1)
			icon = 'icons/mob/human.dmi'
			regenerate_icons()
			damage_multiplier = 2
	else if (type == "Orc")
		if (body_build.name == "Default")
			src << "<font size=3 color='red'>You turn into an Orc!</font>"
			icon = 'icons/mob/human.dmi'
			body_build = get_body_build(gender,"Orc")
			prev_tone = s_tone
			s_tone = null
			update_hair()
			change_facial_hair()
			force_update_limbs()
			update_body(1,1)
			icon = 'icons/mob/human.dmi'
			regenerate_icons()
			damage_multiplier = 2
	else if (type == "Werewolf")
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
					icon_update = 0
					icon = 'icons/mob/human.dmi'