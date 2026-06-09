/////////////////////////////
// Helpers for DNA2
/////////////////////////////

// Pads FALSEs to t until length == u
/proc/add_zero2(t, u)
	var/temp1
	while (length(t) < u)
		t = "0[t]"
	temp1 = t
	if (length(t) > u)
		temp1 = copytext(t,2,u+1)
	return temp1

// DNA Gene activation boundaries, see dna2.dm.
// Returns a list object with 4 numbers.
/proc/GetDNABounds(var/block)
	var/list/BOUNDS=dna_activity_bounds[block]
	if (!istype(BOUNDS))
		return DNA_DEFAULT_BOUNDS
	return BOUNDS

// Scramble UI or SE.
/proc/scramble(var/UI, var/mob/M, var/prob)
	if (!M)	return
	M.dna.check_integrity()
	if (UI)
		for (var/i = TRUE, i <= DNA_UI_LENGTH-1, i++)
			if (prob(prob))
				M.dna.SetUIValue(i,rand(1,4095),1)
		M.dna.UpdateUI()
		M.UpdateAppearance()

	else
		for (var/i = TRUE, i <= DNA_SE_LENGTH-1, i++)
			if (prob(prob))
				M.dna.SetSEValue(i,rand(1,4095),1)
		M.dna.UpdateSE()
	return

// /proc/updateappearance has changed behavior, so it's been removed
// Use mob.UpdateAppearance() instead.

// Simpler. Don't specify UI in order for the mob to use its own.
/mob/proc/UpdateAppearance(var/list/UI=null)
	if (istype(src, /mob/living/human))
		if (UI!=null)
			dna.UI=UI
			dna.UpdateUI()
		dna.check_integrity()
		var/mob/living/human/H = src
		H.r_hair   = dna.GetUIValueRange(DNA_UI_HAIR_R,	255)
		H.g_hair   = dna.GetUIValueRange(DNA_UI_HAIR_G,	255)
		H.b_hair   = dna.GetUIValueRange(DNA_UI_HAIR_B,	255)

		H.r_facial = dna.GetUIValueRange(DNA_UI_BEARD_R,   255)
		H.g_facial = dna.GetUIValueRange(DNA_UI_BEARD_G,   255)
		H.b_facial = dna.GetUIValueRange(DNA_UI_BEARD_B,   255)

		H.r_skin   = dna.GetUIValueRange(DNA_UI_SKIN_R,	255)
		H.g_skin   = dna.GetUIValueRange(DNA_UI_SKIN_G,	255)
		H.b_skin   = dna.GetUIValueRange(DNA_UI_SKIN_B,	255)

		H.r_eyes   = dna.GetUIValueRange(DNA_UI_EYES_R,	255)
		H.g_eyes   = dna.GetUIValueRange(DNA_UI_EYES_G,	255)
		H.b_eyes   = dna.GetUIValueRange(DNA_UI_EYES_B,	255)
		H.update_eyes()

		H.s_tone   = 35 - dna.GetUIValueRange(DNA_UI_SKIN_TONE, 220) // Value can be negative.

		if (dna.GetUIState(DNA_UI_GENDER))
			H.gender = FEMALE
		else
			H.gender = MALE

		//Hair
		var/hair = dna.GetUIValueRange(DNA_UI_HAIR_STYLE,hair_styles_list.len)
		if ((0 < hair) && (hair <= hair_styles_list.len))
			H.h_style = hair_styles_list[hair]

		//Facial Hair
		var/beard = dna.GetUIValueRange(DNA_UI_BEARD_STYLE,facial_hair_styles_list.len)
		if ((0 < beard) && (beard <= facial_hair_styles_list.len))
			H.f_style = facial_hair_styles_list[beard]

		H.force_update_limbs()
		H.update_eyes()
		H.update_hair()

		return TRUE
	else
		return FALSE


