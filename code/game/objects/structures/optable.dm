/obj/structure/optable
	name = "Operating Table"
	desc = "Used for advanced medical procedures."
	icon = 'icons/WW2/ww2_operating_table.dmi'
	icon_state = "table2-idle"
	density = TRUE
	anchored = 1.0
	var/mob/living/carbon/human/victim = null
	var/strapped = 0.0

/obj/structure/optable/New()
	..()
	processing_objects += src

/obj/structure/optable/Del()
	processing_objects -= src
	..()

//	spawn(100) //Wont the MC just call this process() before and at the 10 second mark anyway?
//		process()

/obj/structure/optable/ex_act(severity)

	switch(severity)
		if (1.0)
			//SN src = null
			qdel(src)
			return
		if (2.0)
			if (prob(50))
				//SN src = null
				qdel(src)
				return
		if (3.0)
			if (prob(25))
				density = FALSE
		else
	return

/obj/structure/optable/attack_hand(mob/user as mob)
	if (HULK in usr.mutations)
		visible_message("<span class='danger'>\The [usr] destroys \the [src]!</span>")
		density = FALSE
		qdel(src)
	return

/obj/structure/optable/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (air_group || (height==0)) return TRUE

	if (istype(mover) && mover.checkpass(PASSTABLE))
		return TRUE
	else
		return FALSE


/obj/structure/optable/MouseDrop_T(obj/O as obj, mob/user as mob)

	if ((!( istype(O, /obj/item/weapon) ) || user.get_active_hand() != O))
		return
	user.drop_item()
	if (O.loc != loc)
		step(O, get_dir(O, src))
	return

/obj/structure/optable/proc/check_victim()
	if (locate(/mob/living/carbon/human, loc))
		var/mob/living/carbon/human/M = locate(/mob/living/carbon/human, loc)
		if (M.lying)
			victim = M
			icon_state = M.pulse() ? "table2-active" : "table2-idle"
			return TRUE
	victim = null
	icon_state = "table2-idle"
	return FALSE

/obj/structure/optable/process()
	check_victim()

/obj/structure/optable/proc/take_victim(mob/living/carbon/C, mob/living/carbon/user as mob)
	if (C == user)
		user.visible_message("[user] climbs on \the [src].","You climb on \the [src].")
	else
		visible_message("<span class='notice'>\The [C] has been laid on \the [src] by [user].</span>", 3)
	if (C.client)
		C.client.perspective = EYE_PERSPECTIVE
		C.client.eye = src
	C.resting = TRUE
	C.loc = loc
	for (var/obj/O in src)
		O.loc = loc
	add_fingerprint(user)
	if (ishuman(C))
		var/mob/living/carbon/human/H = C
		victim = H
		icon_state = H.pulse() ? "table2-active" : "table2-idle"
	else
		icon_state = "table2-idle"

/obj/structure/optable/MouseDrop_T(mob/target, mob/user)

	var/mob/living/M = user
	if (user.stat || user.restrained() || !check_table(user) || !iscarbon(target))
		return
	if (istype(M))
		take_victim(target,user)
	else
		return ..()

/obj/structure/optable/verb/climb_on()
	set name = "Climb On Table"
	set category = null
	set src in oview(1)

	if (usr.stat || !ishuman(usr) || usr.restrained() || !check_table(usr))
		return

	take_victim(usr,usr)

/obj/structure/optable/attackby(obj/item/weapon/W as obj, mob/living/carbon/user as mob)
	if (istype(W, /obj/item/weapon/grab))
		var/obj/item/weapon/grab/G = W
		if (iscarbon(G.affecting) && check_table(G.affecting))
			take_victim(G.affecting,usr)
			qdel(W)
			return

/obj/structure/optable/proc/check_table(mob/living/carbon/patient as mob)
	check_victim()
	if (victim && get_turf(victim) == get_turf(src) && victim.lying)
		usr << "<span class='warning'>\The [src] is already occupied!</span>"
		return FALSE
	if (patient.buckled)
		usr << "<span class='notice'>Unbuckle \the [patient] first!</span>"
		return FALSE
	return TRUE
