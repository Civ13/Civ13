// Integration hooks for the Moldy Men sabotage system.
// School property: structures mapped inside the academy's roofed and house areas,
// marked once after the map loads. Each one awards points once, when a Moldy Man
// destroys it; anything built or brought in later never counts.

/obj/structure/var/school_property = FALSE

/obj/map_metadata/wizard_boy/proc/mark_school_property()
	for (var/area/A in area_list)
		if (!istype(A, /area/caribbean/roofed) && !istype(A, /area/caribbean/houses))
			continue
		for (var/obj/structure/S in A)
			S.school_property = TRUE

// Called from /obj/structure/Destroy(). The destroying player is usr while their
// click or verb is still running; a stale usr far from the object earns nothing.
/proc/moldy_school_property_destroyed(obj/structure/S)
	var/mob/living/human/H = usr
	if (!istype(H) || H.stat != CONSCIOUS || H.z != S.z || get_dist(H, S) > 7)
		return
	moldy_school_destroyed(H)

/proc/moldy_school_destroyed(mob/living/human/H)
	var/obj/map_metadata/wizard_boy/W = map
	if (!istype(W) || !W.sabotage || !H || !H.client)
		return
	if (!W.is_moldy_man(H.client.ckey))
		return
	W.sabotage.award_points(25, "School object destroyed")

/proc/moldy_minor_vandalism(mob/living/human/H)
	var/obj/map_metadata/wizard_boy/W = map
	if (!istype(W) || !W.sabotage || !H || !H.client)
		return
	if (!W.is_moldy_man(H.client.ckey))
		return
	W.sabotage.award_points(5, "Minor vandalism completed")
