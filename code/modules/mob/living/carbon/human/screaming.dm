/proc/scream_sound(var/mob/m, var/dying = FALSE)

	if (!ishuman(m))
		return FALSE

	if (m.stat == UNCONSCIOUS || m.stat == DEAD)
		return FALSE

	var/mob/living/carbon/human/H = m
	if (H.gender == MALE)
		playsound(get_turf(H), 'sound/voice/scream_male.ogg', 100, extrarange = 50)
	else
		playsound(get_turf(H), 'sound/voice/scream_female.ogg', 100, extrarange = 50)