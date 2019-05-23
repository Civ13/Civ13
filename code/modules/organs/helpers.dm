/mob/living/carbon/human/proc/get_bodypart(zone)
	if(!zone)
		zone = "chest"
	for(var/X in organs)
		var/obj/item/organ/external/L = X
		if(L.limb_name == zone)
			return L

/mob/living/carbon/human/proc/get_missing_limbs()
	var/list/full = list("head", "chest", "groin", "l_arm", "r_arm", "r_leg", "l_leg","l_hand","r_hand", "l_foot", "r_foot")
	for(var/zone in full)
		if(get_bodypart(zone))
			full -= zone
	return full