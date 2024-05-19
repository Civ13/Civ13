/obj/aiming_overlay
	name = ""
	desc = ""
	icon = 'icons/effects/Targeted.dmi'
	icon_state = "locking"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	layer = FLY_LAYER
	simulated = FALSE
	mouse_opacity = FALSE

	var/mob/living/aiming_at   // Who are we currently targeting, if anyone?
	var/obj/item/aiming_with   // What are we targeting with?
	var/mob/living/owner	   // Who do we belong to?
	var/locked =	FALSE		  // Have we locked on?
	var/lock_time = FALSE		  // When -will- we lock on?
	var/active =	FALSE		  // Is our owner intending to take hostages?
	var/target_permissions = FALSE // Permission bitflags.

/obj/aiming_overlay/New(var/newowner)
	..()
	owner = newowner
	loc = null
	verbs.Cut()

/obj/aiming_overlay/proc/toggle_permission(var/perm)

	if (target_permissions & perm)
		target_permissions &= ~perm
	else
		target_permissions |= perm

	var/message = "no longer permitted to "
	var/use_span = "warning"
	if (target_permissions & perm)
		message = "now permitted to "
		use_span = "notice"

	switch(perm)
		if (TARGET_CAN_MOVE)
			message += "move"
		if (TARGET_CAN_CLICK)
			message += "use items"
		if (TARGET_CAN_RADIO)
			message += "use a radio"
		else
			return

	owner << "<span class='[use_span]'>[aiming_at ? "\The [aiming_at] is" : "Your targets are"] [message].</span>"
	if (aiming_at)
		aiming_at << "<span class='[use_span]'>You are [message].</span>"

/obj/aiming_overlay/process()
	if (!owner)
		qdel(src)
		return
	..()
	update_aiming()

/obj/aiming_overlay/Destroy()
	cancel_aiming(1)
	owner = null
	return ..()

obj/aiming_overlay/proc/update_aiming_deferred()
	set waitfor = FALSE
	sleep(0)
	update_aiming()

/obj/aiming_overlay/proc/update_aiming()

	if (!owner)
		qdel(src)
		return

	if (!aiming_at)
		cancel_aiming()
		return

	if (!locked && lock_time >= world.time)
		locked = TRUE
		update_icon()

	var/cancel_aim = TRUE

	var/gun_view = 7
	for (var/obj/item/weapon/gun/G in owner.contents)
		for (var/obj/item/weapon/attachment/scope/S in G.contents)
			if (S.zoomed)
				gun_view += S.zoom_amt

	if (!(aiming_with in owner) || (istype(owner, /mob/living/human) && (owner.l_hand != aiming_with && owner.r_hand != aiming_with)))
		owner << "<span class='warning'>You must keep hold of your weapon!</span>"
	else if (owner.eye_blind)
		owner << "<span class='warning'>You are blind and cannot see your target!</span>"
	else if (!aiming_at || !istype(aiming_at.loc, /turf))
		owner << "<span class='warning'>You have lost sight of your target!</span>"
	else if (owner.incapacitated() || owner.lying || owner.restrained())
		owner << "<span class='warning'>You must be conscious and standing to keep track of your target!</span>"
	else if (aiming_at.alpha == FALSE || (aiming_at.invisibility > owner.see_invisible))
		owner << "<span class='warning'>Your target has become invisible!</span>"
	else if (!(aiming_at in view(gun_view, owner)))
		owner << "<span class='warning'>Your target is too far away to track!</span>"
	else
		cancel_aim = FALSE

	forceMove(get_turf(aiming_at))

	if (cancel_aim)
		cancel_aiming()
		return

	if (!owner.incapacitated() && owner.client)
		spawn(0)
			owner.set_dir(get_dir(get_turf(owner), get_turf(src)))

/obj/aiming_overlay/proc/aim_at(var/mob/target, var/obj/thing)

	if (!owner)
		return

	if (owner.incapacitated())
		to_chat(owner, SPAN_WARNING("You cannot aim a gun in your current state."))
		return
	/*if (owner.lying && !owner.prone)
		to_chat(owner, SPAN_WARNING("You cannot aim a gun while lying on the floor."))
		return*/
	if (owner.restrained())
		to_chat(owner, SPAN_WARNING("You cannot aim a gun while handcuffed."))
		return

	var/success = FALSE

	if (aiming_at)
		if (aiming_at == target)
			return
		cancel_aiming(1)
		owner.visible_message("<span class='danger'>\The [owner] starts to turn \the [thing] on \the [target]!</span>")
		if (do_after(owner, 9, target))
			owner.visible_message("<span class='danger'>\The [owner] turns \the [thing] on \the [target]!</span>")
			success = TRUE
	else
		owner.visible_message("<span class='danger'>\The [owner] starts to aim \the [thing] at \the [target]!</span>")
		if (do_after(owner, 9, target))
			owner.visible_message("<span class='danger'>\The [owner] aims \the [thing] at \the [target]!</span>")
			success = TRUE

	if (success)
		if (owner.client)
			owner.client.add_gun_icons()
		if (istype(thing, /obj/item/weapon/gun/projectile/bow)) // All bows are lower-cased, so therefore not proper-nouns, and so we can use \a
			to_chat(target, SPAN_DANGER("You now have \a [thing] pointed at you. <big>No sudden moves!</big>"))
		else if (istype(thing, /obj/item/weapon/gun/projectile/pistol)) // Pistols are usually upper-cased, so therefore classed as proper-nouns, and so we have to specify.
			to_chat(target, SPAN_DANGER("You now have a pistol pointed at you. <big>No sudden moves!</big>"))
		//else if (istype(thing, /obj/item/weapon/gun/projectile/submachinegun)) // This is not really correct; calling it a submachine gun (SMG) since, by definition, an SMG fires a pistol-caliber cartridge. And we have ak7
			//to_chat(target, SPAN_DANGER("You now have a submachinegun pointed at you. <big>No sudden moves!</big>"))
		else
			to_chat(target, SPAN_DANGER("You now have a weapon pointed at you. <big>No sudden moves!</big>"))
		aiming_with = thing
		aiming_at = target
		if (istype(aiming_with, /obj/item/weapon/gun))
			playsound(get_turf(owner), 'sound/weapons/TargetOn.ogg', 50,1)

		forceMove(get_turf(target))
		processing_objects |= src

		aiming_at.aimed |= src
		toggle_active(1)
		locked = FALSE
		update_icon()
		lock_time = world.time + 35
		GLOB.moved_event.register(owner, src, /obj/aiming_overlay/proc/update_aiming)
		GLOB.moved_event.register(aiming_at, src, /obj/aiming_overlay/proc/target_moved)
		GLOB.destroyed_event.register(aiming_at, src, /obj/aiming_overlay/proc/cancel_aiming)

/obj/aiming_overlay/update_icon()
	if (locked)
		icon_state = "locked"
	else
		icon_state = "locking"

/obj/aiming_overlay/proc/toggle_active(var/force_state = null)
	if (!isnull(force_state))
		if (active == force_state)
			return
		active = force_state
	else
		active = !active

	if (!active)
		cancel_aiming()

	if (owner.client)
		if (active)
			owner << "<span class='notice'>You will now aim rather than fire.</span>"
			owner.client.add_gun_icons()
		else
			owner << "<span class='notice'>You will no longer aim rather than fire.</span>"
			owner.client.remove_gun_icons()

/obj/aiming_overlay/proc/cancel_aiming(var/no_message = FALSE)
	if (!aiming_with || !aiming_at)
		return
	if (istype(aiming_with, /obj/item/weapon/gun))
		playsound(get_turf(owner), 'sound/weapons/TargetOff.ogg', 50,1)
	if (!no_message)
		owner.visible_message("<span class='notice'>\The [owner] lowers \the [aiming_with].</span>")

	GLOB.moved_event.unregister(owner, src)
	if (aiming_at)
		GLOB.moved_event.unregister(aiming_at, src)
		GLOB.destroyed_event.unregister(aiming_at, src)
		aiming_at.aimed -= src
		aiming_at = null

	aiming_with = null
	loc = null
	processing_objects -= src

/obj/aiming_overlay/proc/target_moved()
	update_aiming()
	trigger(TARGET_CAN_MOVE)