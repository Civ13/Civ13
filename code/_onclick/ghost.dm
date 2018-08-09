/client/var/inquisitive_ghost = TRUE
/mob/observer/ghost/verb/toggle_inquisition() // warning: unexpected inquisition
	set name = "Toggle Inquisitiveness"
	set desc = "Sets whether your ghost examines everything on click by default"
	set category = "Ghost"
	if (!client) return
	client.inquisitive_ghost = !client.inquisitive_ghost
	if (client.inquisitive_ghost)
		src << "<span class='notice'>You will now examine everything you click on.</span>"
	else
		src << "<span class='notice'>You will no longer examine things you click on.</span>"

/mob/observer/ghost/DblClickOn(var/atom/A, var/params)
/*	if (client.buildmode)
		build_click(src, client.buildmode, params, A)
		return*/

	if (can_reenter_corpse && mind && mind.current)
		if (A == mind.current || (mind.current in A)) // double click your corpse or whatever holds it
			reenter_corpse()						// (cloning scanner, body bag, closet, mech, etc)
			return

	// Things you might plausibly want to follow
	if (istype(A,/atom/movable))
		ManualFollow(A)
	// Otherwise jump
	else
		stop_following()
		forceMove(get_turf(A))

		if (istype(A, /turf/open))
			movedown()

/mob/observer/ghost/ClickOn(var/atom/A, var/params)
/*	if (client.buildmode)
		build_click(src, client.buildmode, params, A)
		return*/
	if (!canClick()) return
	setClickCooldown(4)
	// You are responsible for checking config.ghost_interaction when you override this function
	// Not all of them require checking, see below
	A.attack_ghost(src)

// Oh by the way this didn't work with old click code which is why clicking shit didn't spam you
/atom/proc/attack_ghost(mob/observer/ghost/user as mob)
	if (user.client && user.client.inquisitive_ghost)
		user.examinate(src)
	return
