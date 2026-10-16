
/mob/living/Login()
	..()
	if(client) client.stoptitlemusic()
	//Mind updates
	mind_initialize()	//updates the mind (or creates and initializes one if one doesn't exist)
	mind.active = TRUE		//indicates that the mind is currently synced with a client
	if(istype(src, /mob/living/human))
		var/mob/living/human/H = src
		H.record_persistence_owner()
	//If they're SSD, remove it so they can wake back up.
//	update_antag_icons(mind)
	return .
