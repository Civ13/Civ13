/mob/verb/on_press_spacebar()

	set category = null

	if (ishuman(src) && !src.stat)
		var/mob/living/human/H = src
		H.look_into_distance(src)
		return
	return FALSE