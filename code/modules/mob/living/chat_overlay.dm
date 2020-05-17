//mostly ported from BurgerStation, 17/05/2020

#define TILE_SIZE 32

/mob/living
	var/obj/chat_text/chat_text
	var/list/stored_chat_text = list()

/obj/chat_text
	name = "overlay"
	desc = "overlay object"
	plane = CHAT_PLANE

	icon = null

	var/mob/living/owner

/obj/chat_text/Destroy()
	owner.stored_chat_text -= src
	owner = null
	return ..()

/obj/chat_text/New(var/atom/desired_loc,var/desired_text)

	if(isliving(desired_loc))
		owner = desired_loc

		for(var/obj/chat_text/CT in owner.stored_chat_text)
			qdel(CT)

		owner.stored_chat_text += src

		forceMove(get_turf(desired_loc))

		maptext_width = TILE_SIZE*ceil(11*0.5)
		maptext_x = -(maptext_width-TILE_SIZE)*0.5
		maptext_y = TILE_SIZE*0.75
		maptext = "<center>[desired_text]</center>"

		spawn(100)
			animate(src,alpha=0,time=10)
			sleep(10)
			if(src)
				qdel(src)

		return ..()
	else
		qdel(src)

	return FALSE