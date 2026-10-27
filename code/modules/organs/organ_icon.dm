var/global/list/limb_icon_cache = list()

/obj/item/organ/external/set_dir()
	return

/obj/item/organ/external/proc/compile_icon()
	overlays.Cut()
	 // This is a kludge, only one icon has more than one generation of children though.
	for (var/obj/item/organ/external/organ in contents)
		if (organ.children && organ.children.len)
			for (var/obj/item/organ/external/child in organ.children)
				overlays += child.mob_icon
		overlays += organ.mob_icon

/obj/item/organ/external/proc/sync_colour_to_human(var/mob/living/human/human_mob)
	s_tone = null
	s_col = null
	h_col = null
	if (species && human_mob.species && species.name != human_mob.species.name)
		return
	if (!isnull(human_mob.s_tone) && (human_mob.species.appearance_flags & HAS_SKIN_TONE))
		s_tone = human_mob.s_tone
	if (human_mob.species.appearance_flags & HAS_SKIN_COLOR)
		s_col = list(human_mob.r_skin, human_mob.g_skin, human_mob.b_skin)
	h_col = list(human_mob.r_hair, human_mob.g_hair, human_mob.b_hair)

/obj/item/organ/external/head/sync_colour_to_human(var/mob/living/human/human_mob)
	..()
	var/obj/item/organ/eyes/eyes = owner.internal_organs_by_name["eyes"]
	if (eyes) eyes.update_colour()

/obj/item/organ/external/head/removed()
	update_icon(1)
	..()

/obj/item/organ/external/head/update_icon()

	..()
	overlays.Cut()
	if (!owner || !owner.species)
		return
	if (owner.species.has_organ["eyes"])
		var/icon/eyes_icon = new/icon('icons/mob/human_face.dmi', "eyes[owner.body_build.index]")
		var/obj/item/organ/eyes/eyes = owner.internal_organs_by_name["eyes"]
		if (eyes)
			eyes_icon.Blend(rgb(eyes.eye_colour[1], eyes.eye_colour[2], eyes.eye_colour[3]), ICON_ADD)
		else
			eyes_icon.Blend(rgb(128,0,0), ICON_ADD)
		mob_icon.Blend(eyes_icon, ICON_OVERLAY)
		overlays |= eyes_icon

	if (owner.lip_style && (species && (species.appearance_flags & HAS_LIPS)))
		var/icon/lip_icon = new/icon('icons/mob/human_face.dmi', "lips[owner.lip_style][owner.body_build.index]")
		overlays |= lip_icon
		mob_icon.Blend(lip_icon, ICON_OVERLAY)

	if (owner.f_style && !owner.body_build.nofacialhair)
		var/datum/sprite_accessory/facial_hair_style = facial_hair_styles_list[owner.f_style]
		if (facial_hair_style && facial_hair_style.species_allowed && (species.get_bodytype() in facial_hair_style.species_allowed))
			var/icon/facial_s = new/icon("icon" = facial_hair_style.icon, "icon_state" = "[facial_hair_style.icon_state]_s")
			if (facial_hair_style.do_colouration)
				facial_s.Blend(rgb(owner.r_facial, owner.g_facial, owner.b_facial), ICON_ADD)
			overlays |= facial_s

	if (owner.h_style && !owner.body_build.nohair && !(owner.head && (owner.head.flags_inv & BLOCKHEADHAIR)))
		var/datum/sprite_accessory/hair_style = hair_styles_list[owner.h_style]
		if (hair_style && (species.get_bodytype() in hair_style.species_allowed))
			var/icon/hair_s = new/icon("icon" = hair_style.icon, "icon_state" = "[hair_style.icon_state]_s")
			if (hair_style.do_colouration && islist(h_col) && h_col.len >= 3)
				hair_s.Blend(rgb(h_col[1], h_col[2], h_col[3]), ICON_ADD)
			overlays |= hair_s

	icon = mob_icon

/obj/item/organ/external/update_icon(var/regenerate = FALSE)
	if (!owner)//special check
		qdel(src)
		return
	var/gender = "_m"
/*	if (!gendered_icon)
		gender = null
	else */
	if (!owner.ant && !owner.wolfman && !owner.orc && !owner.crab && !owner.gorillaman && !owner.lizard)
		if (dna && dna.GetUIState(DNA_UI_GENDER))
			gender = "_f"
		else if (owner && owner.gender == FEMALE)
			gender = "_f"

	icon_state = "[icon_name][gender][owner.body_build.index]"
	icon = 'icons/mob/human_races/r_human.dmi'
	mob_icon = new/icon(icon, icon_state)
	if (status & ORGAN_DEAD)
		mob_icon.ColorTone(rgb(10,50,0))
		mob_icon.SetIntensity(0.7)

	if (s_tone)
		if (s_tone >= 0)
			mob_icon.Blend(rgb(s_tone, s_tone, s_tone), ICON_ADD)
		else
			mob_icon.Blend(rgb(-s_tone,  -s_tone,  -s_tone), ICON_SUBTRACT)
	else
		if (s_col && s_col.len >= 3)
			mob_icon.Blend(rgb(s_col[1], s_col[2], s_col[3]), ICON_ADD)

	dir = EAST
	icon = mob_icon

/obj/item/organ/external/proc/get_icon()
	update_icon()
	return mob_icon
