/datum/preferences
	//The mob should have a gender you want before running this proc. Will run fine without H
	proc/randomize_appearance_for (var/mob/living/carbon/human/H)
		gender = pick(MALE, FEMALE)
		var/datum/species/current_species = all_species[species]

		if (current_species)
			if (current_species.appearance_flags & HAS_SKIN_TONE)
				s_tone = random_skin_tone()
			if (current_species.appearance_flags & HAS_EYE_COLOR)
				randomize_eyes_color()
		b_type = pick("A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-")
		h_style = random_hair_style(gender, species)
		f_style = random_facial_hair_style(gender, species)
		randomize_hair_color("hair")
		randomize_hair_color("facial")

		age = rand(current_species.min_age, current_species.max_age)
		if (H)
			copy_to(H,1)


	proc/randomize_hair_color(var/target = "hair")
		if (prob (75) && target == "facial") // Chance to inherit hair color
			r_facial = r_hair
			g_facial = g_hair
			b_facial = b_hair
			return

		var/red
		var/green
		var/blue

		var/col = pick ("Black", "Light Brown", "Dark Brown", "Red", "Orange", "Light Blond", "Blond", "Dirty Blond", "Light Grey", "Grey")
		var/hex_hair = hair_colors[col]
		red = hex2num(copytext(hex_hair, 2, 4))
		green = hex2num(copytext(hex_hair, 4, 6))
		blue = hex2num(copytext(hex_hair, 6, 8))

		switch(target)
			if ("hair")
				r_hair = red
				g_hair = green
				b_hair = blue
			if ("facial")
				r_facial = red
				g_facial = green
				b_facial = blue

	proc/randomize_eyes_color()
		var/red
		var/green
		var/blue

		var/col2 = pick ("Black", "Brown", "Dark Brown", "Green", "Blue")
		var/hex_eyes = eye_colors[col2]
		red = hex2num(copytext(hex_eyes, 2, 4))
		green = hex2num(copytext(hex_eyes, 4, 6))
		blue = hex2num(copytext(hex_eyes, 6, 8))

		r_eyes = red
		g_eyes = green
		b_eyes = blue

	proc/update_preview_icons()		//seriously. This is horrendous.

		qdel_list(preview_icons_front)
		qdel_list(preview_icons_back)
		qdel_list(preview_icons_east)
		qdel_list(preview_icons_west)
		qdel_list(preview_icons)

		var/g = "_m"
		if (gender == FEMALE)	g = "_f"

		var/datum/body_build/body = get_body_build(gender, body_build)

		var/icon/icobase
		var/datum/species/current_species = all_species[species]

		if (current_species)
			icobase = current_species.icobase
		else
			icobase = 'icons/mob/human_races/r_human.dmi'

		for (var/v in TRUE to 3)

			var/icon/I = new /icon(icobase, "torso[g][body.index]")
			I.Blend(new /icon(icobase, "groin[g][body.index]"), ICON_OVERLAY)
			I.Blend(new /icon(icobase, "head[g][body.index]"), ICON_OVERLAY)

			for (var/name in list("r_arm","r_hand","r_leg","r_foot","l_leg","l_foot","l_arm","l_hand"))

				I.Blend(new /icon(icobase, "[name][g][body.index]"), ICON_OVERLAY)

			// Skin color
			if (current_species && (current_species.appearance_flags & HAS_SKIN_COLOR))
				I.Blend(rgb(r_skin, g_skin, b_skin), ICON_ADD)

			// Skin tone
			if (current_species && (current_species.appearance_flags & HAS_SKIN_TONE))
				if (s_tone >= 0)
					I.Blend(rgb(s_tone, s_tone, s_tone), ICON_ADD)
				else
					I.Blend(rgb(-s_tone,  -s_tone,  -s_tone), ICON_SUBTRACT)

			var/icon/eyes = new/icon('icons/mob/human_face.dmi', "eyes[body.index]")
			if ((current_species && (current_species.appearance_flags & HAS_EYE_COLOR)))
				eyes.Blend(rgb(r_eyes, g_eyes, b_eyes), ICON_ADD)

			var/datum/sprite_accessory/hair_style = hair_styles_list[h_style]
			if (hair_style)
				var/icon/hair = new/icon("icon" = hair_style.icon, "icon_state" = "[hair_style.icon_state]_s")
				hair.Blend(rgb(r_hair, g_hair, b_hair), ICON_ADD)
				eyes.Blend(hair, ICON_OVERLAY)

			var/datum/sprite_accessory/facial_hair_style = facial_hair_styles_list[f_style]
			if (facial_hair_style)
				var/icon/facial = new/icon("icon" = facial_hair_style.icon, "icon_state" = "[facial_hair_style.icon_state]_s")
				facial.Blend(rgb(r_facial, g_facial, b_facial), ICON_ADD)
				eyes.Blend(facial, ICON_OVERLAY)

			var/icon/clothes = null

			switch (v)
				if (2)
					clothes = new /icon('icons/mob/uniform.dmi', "demo_pirate")
				if (3)
					clothes = new /icon('icons/mob/uniform.dmi', "demo_british")

			if (clothes)
				I.Blend(clothes, ICON_OVERLAY)

			I.Blend(eyes, ICON_OVERLAY)

			preview_icons += I
			preview_icons_front += icon(I, dir = SOUTH)
			preview_icons_back += icon(I, dir = NORTH)
			preview_icons_east += icon(I, dir = EAST)
			preview_icons_west += icon(I, dir = WEST)

			qdel(eyes)
			qdel(clothes)
