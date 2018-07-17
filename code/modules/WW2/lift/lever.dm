/obj/lift_lever // same icon as the train lever for now
	anchored = 1.0
	density = TRUE
	icon = 'icons/WW2/train_lever.dmi'
	icon_state = "lever_none"
	var/none_state = "lever_none"
	var/pushed_state = "lever_pulled" // lever_pushed is the wrong direction
	var/orientation = "NONE"
	var/lever_id = "defaultliftleverid"
	name = "supply lift lever"

/obj/lift_lever/New()
	..()
	lever_list += src

/obj/lift_lever/Destroy()
	lever_list -= src
	..()

/obj/lift_lever/attack_hand(var/mob/user as mob)
	if (user && istype(user, /mob/living/carbon/human))
		function(user)

/obj/lift_lever/proc/function(var/mob/user as mob)
	if (orientation == "NONE")
		icon_state = pushed_state
		orientation = "PUSHED"
		for (var/obj/lift_controller/down/lift in range(10, src))
			if (istype(lift))
				if (lift.activate())
					visible_message("<span class = 'danger'>[user] pushes the lever forwards!</span>")
					break
	spawn (3)
		icon_state = none_state
		orientation = "NONE"

	playsound(get_turf(src), 'sound/effects/lever.ogg', 100, TRUE)

/obj/lift_lever/linked
	var/obj/lift_lever/counterpart = null

/obj/lift_lever/linked/attack_hand(var/mob/user)
	if (user && istype(user, /mob/living/carbon/human) && counterpart)
		function(user)

/obj/lift_lever/linked/function(var/mob/user as mob)
	if (orientation == "NONE")
		icon_state = pushed_state
		orientation = "PUSHED"
		for (var/obj/lift_controller/down/lift in range(10, counterpart))
			if (istype(lift))
				if (lift.activate())
					visible_message("<span class = 'danger'>[user] pushes the lever forwards!</span>")
					break
	spawn (3)
		icon_state = none_state
		orientation = "NONE"


// subtypes

/obj/lift_lever/soviet
	lever_id = "sovietliftlever"

/obj/lift_lever/linked/soviet
	lever_id = "sovietliftlever"
