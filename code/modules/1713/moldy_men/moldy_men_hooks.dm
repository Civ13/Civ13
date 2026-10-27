// Example integration hooks for the Moldy Men sabotage system.
// Call these from relevant destruction / interaction procs.

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
