/mob/living/maim()

	Weaken(5)
	adjustBruteLoss(50)

	var/appendages = 0
	var/list/arms = list()
	var/list/legs = list()

	if (ishuman(src))
		var/mob/living/human/H = src
		for (var/obj/item/organ/external/arm/A in H.organs)
			++appendages
			arms += A

		for (var/obj/item/organ/external/leg/L in H.organs)
			++appendages
			legs += L

	// combine and shuffle arms and legs so we don't bias either
	for (var/obj/item/organ/external/E in shuffle(arms|legs))
		if (prob(75) && prob(round(100/(arms.len+legs.len))))
			E.droplimb()
			--appendages

	if (!appendages)
		crush()

	for(var/mob/living/human/NB in view(6,src))
		if (!NB.orc)
			NB.mood -= 10
			//NB.ptsd += 1

proc/delayed_decay(var/mob/living/L,var/timer=3000)
	spawn(timer)
		if (L && L.stat == DEAD)
			dead_mob_list -= L
			L.Destroy()
			return
		else
			return