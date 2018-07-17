/obj/structure/siren
	name = "air raid siren"
	desc = "Rotate it to sound the alarm."
	icon_state = "siren"
	layer = MOB_LAYER + 1
	anchored = TRUE
	density = TRUE
	var/cooldown = FALSE
	density = TRUE
	var/health = 270
	var/maxhealth = 270


/obj/structure/siren/attack_hand(mob/user)
	if ((cooldown < world.time - 1200) || (world.time < 1200))
		user << "<span class='notice'>You turn the [src], creating an ear-splitting noise!</span>"
		playsound(user, 'sound/misc/siren.ogg', 100, TRUE)
		cooldown = world.time
	return //It's just a loudspeaker

///obj/structure/siren/process()
//	return //to stop icon from changing