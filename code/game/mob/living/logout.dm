/mob/living/Logout()
	..()
	if (mind)
		//Per BYOND docs key remains set if the player DCs, becomes null if switching bodies.
		if (!key)	//key and mind have become seperated.
			mind.active = FALSE	//This is to stop say, a mind.transfer_to call on a corpse causing a ghost to re-enter its body.

/mob/living/human/Logout()
	if (client && client.human_subtile_visual_actor == src)
		client.human_subtile_release_visuals()
	human_subtile_release_glide()
	human_clients_mob_list -= src
	return ..()
