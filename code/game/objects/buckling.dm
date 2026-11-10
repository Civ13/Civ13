/obj/attack_hand(mob/living/user)
	. = ..()
	if (can_buckle && buckled_mob)
		user_unbuckle_mob(user)

/obj/MouseDrop_T(mob/living/M, mob/living/user)
	. = ..()
	if (can_buckle && istype(M))
		user_buckle_mob(M, user)

/obj/Destroy()
	unbuckle_mob()
	return ..()


/obj/proc/buckle_mob(mob/living/M)
	if (!can_buckle || !istype(M) || (M.loc != loc) || M.buckled || M.pinned.len || (buckle_require_restraints && !M.restrained()))
		return FALSE

	M.settle_on_tile()
	M.buckled = src
	M.facing_dir = null
	M.set_dir(buckle_dir ? buckle_dir : dir)
	M.update_canmove()
	buckled_mob = M
	post_buckle_mob(M)
	if (istype(src, /obj/structure/bed/bedroll) && istype(M, /mob/living/human))
		var/obj/structure/bed/bedroll/BR = src
		BR.used = TRUE
		BR.check_use(M)
	return TRUE

// Free movement leaves a body at a pixel offset on its tile, and that offset
// keeps across loc changes. Anything that seats a mob (chairs, beds, vehicles)
// settles it squarely on its tile, or it sits beside the seat and, being
// counted on the next tile east or north, gets run into by its own vehicle.
/mob/living/proc/settle_on_tile()
	if (!step_x && !step_y)
		return
	step_x = 0
	step_y = 0
	if (ishuman(src))
		var/mob/living/human/H = src
		H.human_subtile_offset_owned = FALSE
	else if (istype(src, /mob/living/simple_animal))
		var/mob/living/simple_animal/A = src
		A.npc_subtile_offset_owned = FALSE

/obj/proc/unbuckle_mob()
	if (buckled_mob && buckled_mob.buckled == src)
		. = buckled_mob
		buckled_mob.buckled = null
		buckled_mob.anchored = initial(buckled_mob.anchored)
		buckled_mob.update_canmove()
		buckled_mob.pixel_x = 0
		buckled_mob.pixel_y = 0
		buckled_mob = null
		if (istype(src, /obj/structure/bed/chair/drivers))
			var/obj/structure/bed/chair/drivers/DC = src
			if (DC.axis)
				DC.axis.driver = null
		if (istype(src, /obj/structure/bed/bedroll) && istype(., /mob/living/human))
			var/obj/structure/bed/bedroll/BR = src
			BR.used = FALSE
			BR.check_use(.)
		post_buckle_mob(.)

/obj/proc/post_buckle_mob(mob/living/M)
	return

/obj/proc/user_buckle_mob(mob/living/M, mob/user)
	if (!ticker)
		to_chat(user, SPAN_WARNING("You can't buckle anyone in before the game starts."))
	if (!user.Adjacent(M) || user.restrained() || user.lying || user.stat)
		return
	if (M == buckled_mob)
		return
	add_fingerprint(user)
	unbuckle_mob()

	if (buckle_mob(M))
		if (M == user)
			M.visible_message(\
				"<span class='notice'>[M.name] buckles themselves to [src].</span>",\
				"<span class='notice'>You buckle yourself to [src].</span>",\
				"<span class='notice'>You hear metal clanking.</span>")
		else
			M.visible_message(\
				"<span class='danger'>[M.name] is buckled to [src] by [user.name]!</span>",\
				"<span class='danger'>You are buckled to [src] by [user.name]!</span>",\
				"<span class='notice'>You hear metal clanking.</span>")

/obj/proc/user_unbuckle_mob(mob/user)
	var/mob/living/M = unbuckle_mob()
	if (M)
		if (M != user)
			M.visible_message(\
				"<span class='notice'>[M.name] was unbuckled by [user.name]!</span>",\
				"<span class='notice'>You were unbuckled from [src] by [user.name].</span>",\
				"<span class='notice'>You hear metal clanking.</span>")
		else
			M.visible_message(\
				"<span class='notice'>[M.name] unbuckled themselves!</span>",\
				"<span class='notice'>You unbuckle yourself from [src].</span>",\
				"<span class='notice'>You hear metal clanking.</span>")
		add_fingerprint(user)
	return M

