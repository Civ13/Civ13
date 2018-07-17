/mob/living/maim()

	Weaken(5)
	adjustBruteLoss(50)

	var/appendages = 0
	var/list/arms = list()
	var/list/legs = list()

	if (isliving(src))
		var/mob/living/carbon/human/H = src
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