/proc/scream_sound(var/mob/m, var/dying = FALSE)

	if (!ishuman(m))
		return FALSE

	if (m.stat == UNCONSCIOUS || m.stat == DEAD)
		return FALSE

	var/mob/living/human/H = m
	if (H.gender == MALE)
		var/list/screamlist = list('sound/voice/screams/scream1.ogg','sound/voice/screams/scream2.ogg','sound/voice/screams/scream3.ogg','sound/voice/screams/scream4.ogg','sound/voice/screams/scream5.ogg','sound/voice/screams/scream6.ogg',)
		playsound(get_turf(H), pick(screamlist), 100, extrarange = 50)
	else
		playsound(get_turf(H), 'sound/voice/scream_female.ogg', 100, extrarange = 50)


/proc/warning_scream_sound(var/mob/m, var/dying = FALSE)

	if (!ishuman(m))
		return FALSE

	if (m.stat == UNCONSCIOUS || m.stat == DEAD)
		return FALSE

	var/mob/living/human/H = m
	if (H.gender == MALE)
		var/list/screamlist = list('sound/voice/screams/scream21.ogg','sound/voice/screams/scream22.ogg','sound/voice/screams/scream23.ogg','sound/voice/screams/scream24.ogg')
		playsound(get_turf(H), pick(screamlist), 100, extrarange = 50)
	else
		playsound(get_turf(H), 'sound/voice/scream_female.ogg', 100, extrarange = 50)