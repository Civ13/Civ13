/obj
	//Used to store information about the contents of the object.
	var/list/matter
	var/w_class // Size of the object.
	animate_movement = 2
	var/throwforce = TRUE
	var/sharp = FALSE		// whether this object cuts
	var/edge = FALSE		// whether this object is more likely to dismember
	var/in_use = FALSE // If we have a user using us, this will be set on. We will check if the user has stopped using us, and thus stop updating and LAGGING EVERYTHING!
	var/damtype = "brute"
	var/armor_penetration = FALSE //probability of penetrating body armor
	var/heavy_armor_penetration = FALSE //how many mm of steel armor will this penetrate
	var/special_id = FALSE
	var/scoped_invisible = FALSE
	var/is_teleporter = FALSE
	var/is_cover = FALSE
	var/code = 0
	var/cooldownw = DEFAULT_ATTACK_COOLDOWN //how long till you can attack again
	var/cratevalue = 0 //How much the crate costs when importing
	var/flammable = FALSE

	var/secondary_action = FALSE //If it has a secondary action binded to a hotkey, e.g. braking on vehicles
	var/powerneeded = 0 //how much power it draws from a nearby engine. 0 means no power needed.
	var/obj/structure/cable/powersource = null
	var/powered = FALSE
	var/quality = 0
	var/unacidable = FALSE	//For acids interactions, called at Chemistry-Reagents-Compounds.dm

	var/can_buckle = FALSE
	var/buckle_movable = FALSE
	var/buckle_dir = FALSE
	var/buckle_lying = -1 //bed-like behavior, forces mob.lying = buckle_lying if != -1
	var/buckle_require_restraints = FALSE //require people to be handcuffed before being able to buckle. eg: pipes
	var/mob/living/buckled_mob = null

	var/explosion_resistance

/obj/examine(mob/user,distance=-1)
	..(user,distance)
	return distance == -1 || (get_dist(src, user) <= distance)

/obj/proc/matrixangle(x)
	var/matrix/M = matrix()
	M.Turn(x)
	return M

/obj/Destroy()
	processing_objects -= src
	return ..()

/obj/Topic(href, href_list, var/datum/topic_state/state = default_state)
	if (..())
		return TRUE

	// In the far future no checks are made in an overriding Topic() beyond if (..()) return
	// Instead any such checks are made in CanUseTopic()
	if (CanUseTopic(usr, state, href_list) == STATUS_INTERACTIVE)
		CouldUseTopic(usr)
		return FALSE

	CouldNotUseTopic(usr)
	return TRUE

/obj/CanUseTopic(var/mob/user, var/datum/topic_state/state)
	if (user.CanUseObjTopic(src))
		return ..()
	user << "<span class='danger'>\icon[src]Access Denied!</span>"
	return STATUS_CLOSE
/obj/proc/updateturf()
	return TRUE
// for cover floors

/mob/proc/CanUseObjTopic()
	return TRUE

/obj/proc/CouldUseTopic(var/mob/user)
	user.AddTopicPrint(src)

/mob/proc/AddTopicPrint(var/obj/target)
	target.add_hiddenprint(src)

/mob/living/AddTopicPrint(var/obj/target)
	if (Adjacent(target))
		target.add_fingerprint(src)
	else
		target.add_hiddenprint(src)


/obj/proc/CouldNotUseTopic(var/mob/user)
	// Nada

/obj/item/proc/is_used_on(obj/O, mob/user)

/obj/proc/process()
	processing_objects -= src
	return FALSE

/obj/proc/updateUsrDialog()
	if (in_use)
		var/is_in_use = FALSE
		var/list/nearby = viewers(1, src)
		for (var/mob/M in nearby)
			if ((M.client && M.using_object == src))
				is_in_use = TRUE
				attack_hand(M)

		// check for TK users

/*		if (istype(usr, /mob/living/human))
			if (istype(usr.l_hand, /obj/item/tk_grab) || istype(usr.r_hand, /obj/item/tk_grab/))
				if (!(usr in nearby))
					if (usr.client && usr.using_object==src)
						is_in_use = TRUE
						attack_hand(usr)*/
		in_use = is_in_use

/obj/proc/updateDialog()
	// Check that people are actually using the machine. If not, don't update anymore.
	if (in_use)
		var/list/nearby = viewers(1, src)
		var/is_in_use = FALSE
		for (var/mob/M in nearby)
			if ((M.client && M.using_object == src))
				is_in_use = TRUE
				interact(M)
		if (!is_in_use)
			in_use = FALSE

/obj/attack_ghost(mob/user)
	ui_interact(user)
	..()

/obj/proc/interact(mob/user)
	return

/obj/proc/update_icon()
	return

/mob/proc/unset_using_object()
	using_object = null

/mob/proc/set_using_object(var/atom/movable/AM)
	if (using_object)
		unset_using_object()
	using_object = AM
	if (isobj(AM))
		var/obj/O = AM
		O.in_use = TRUE

/obj/item/proc/updateSelfDialog()
	var/mob/M = loc
	if (istype(M) && M.client && M.using_object == src)
		attack_self(M)

/obj/proc/hide(var/hide)
	invisibility = hide ? INVISIBILITY_MAXIMUM : initial(invisibility)

/obj/proc/hides_under_flooring()
	return level == TRUE

/obj/proc/hear_talk(mob/M as mob, text, verb, datum/language/speaking)
	//if (talking_atom)
		//talking_atom.catchMessage(text, M)
/*
	var/mob/mo = locate(/mob) in src
	if (mo)
		var/rendered = "<span class='game say'><span class='name'>[M.name]: </span> <span class='message'>[text]</span></span>"
		mo.show_message(rendered, 2)
		*/
	return

/obj/proc/see_emote(mob/M as mob, text, var/emote_type)
	return

/obj/proc/show_message(msg, type, alt, alt_type)//Message, type of message (1 or 2), alternative message, alt message type (1 or 2)
	return

/obj/proc/damage_flags()
	. = 0
	if(has_edge(src))
		. |= DAM_EDGE
	if(is_sharp(src))
		. |= DAM_SHARP
		if(damtype == BURN)
			. |= DAM_LASER

/obj/proc/secondary_attack_self(mob/living/human/user)
	return