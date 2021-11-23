/mob/verb/on_press_spacebar()

	set category = null

	if (ishuman(src) && !src.stat)
		var/mob/living/human/H = src
		H.look_into_distance(src)
		return
	return FALSE

/client/verb/attack_direction()
	set name = "attack-direction"
	set hidden = TRUE

	if (!mob)
		return

	if (!istype(mob,/mob/living))
		return

	var/mob/living/current_mob = mob
	if (!current_mob || current_mob.stat != CONSCIOUS)
		return
	var/turf/T = get_step(mob, mob.dir)
	var/mob/living/target = null
	for(var/mob/living/L in T)
		if(L.stat != DEAD)
			target = L
			break
	if(target)
		mob.ClickOn(target)
	return
