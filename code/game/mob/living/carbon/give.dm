/mob/living/human/verb/give(var/mob/living/target in view(1)-usr)
	set category = "IC"
	set name = "Give"

	if (!client || incapacitated())
		return
	if (!istype(target) || target.incapacitated() || !target.client)
		return

	var/obj/item/I = get_active_hand()
	if (!I)
		I = get_inactive_hand()
	if (!I)
		to_chat(src, SPAN_WARNING("You don't have anything in your hands to give to \the [target]."))
		return

	var/client/giver_connection = client
	var/client/receiver_connection = target.client
	var/answer = WWinput(target, "[src] wants to give you \a [I]. Will you accept it?", null, "Yes", list("Yes","No"))
	if (QDELETED(src) || QDELETED(target) || QDELETED(I) || client != giver_connection || target.client != receiver_connection)
		return
	if (answer == "No")
		target.visible_message(SPAN_NOTICE("\The [src] tried to hand \the [I] to \the [target], but \the [target] didn't want it."))
		return
	if (answer != "Yes")
		return

	give_held_item(I, target)

/mob/living/human/proc/give_held_item(obj/item/I, mob/living/target)
	if (QDELETED(src) || QDELETED(target) || QDELETED(I) || incapacitated() || target.incapacitated())
		return FALSE
	if (!Adjacent(target))
		to_chat(src, SPAN_WARNING("You need to stay in reaching distance whilst giving an object."))
		to_chat(target, SPAN_WARNING("\The [src] moved too far away."))
		return FALSE
	if (I.loc != src || !item_is_in_hands(I))
		to_chat(src, SPAN_WARNING("You need to keep the item in your hands."))
		to_chat(target, SPAN_WARNING("\The [src] seems to have given up on passing \the [I] to you."))
		return FALSE
	if (target.hands_are_full())
		to_chat(target, SPAN_WARNING("Your hands are full."))
		to_chat(src, SPAN_WARNING("Their hands are full."))
		return FALSE
	if (!canUnEquip(I) || I.nodrop || I.nodrop_special_check())
		return FALSE

	if (istype(I, /obj/item/stack))
		if (!give_held_stack(I, target))
			return FALSE
	else if (!unEquip(I) || QDELETED(I) || I.loc == src || !target.put_in_hands(I))
		return FALSE
	target.visible_message(SPAN_NOTICE("\The [src] handed \the [I] to \the [target]."))
	return TRUE

// Never stage stacks on a turf: Crossed() can merge a nearby stack into the gift.
/mob/living/human/proc/give_held_stack(obj/item/stack/I, mob/living/target)
	if (!ishuman(target) || target.lying || I.extraction_surface_source)
		return FALSE
	var/in_left_hand = l_hand == I
	if (!transfer_held_item_to(I, target))
		return FALSE
	if (target.put_in_active_hand(I) || target.put_in_inactive_hand(I))
		return TRUE
	// If admission unexpectedly changes, return the stack without touching the ground.
	if (!QDELETED(I) && I.loc == target && I.forceMove(src))
		if (!(in_left_hand ? put_in_l_hand(I) : put_in_r_hand(I)))
			put_in_active_hand(I) || put_in_inactive_hand(I)
	return FALSE

/mob/living/human/verb/recruit()
	set category = null
	set name = "Recruit"
	set desc = "Invite into your faction."

	set src in view(1)

	if (!ishuman(src) || !ishuman(usr))
		return
	var/mob/living/human/user = usr

	if (user.stat || user.restrained() || !isliving(user))
		return

	if (user == src)
		to_chat(user, "You cannot recruit yourself.")
		return

	if (user.original_job_title != "Nomad" && !findtext(user.original_job_title,"Civilization"))
		to_chat(user, "You can't recruit in this map.")
		return

	if (user.civilization == "none" || user.civilization == null)
		to_chat(user, "You are not part of a faction.")
		return

	var/faction = user.civilization
	if (!map.can_recruit_for_faction(user, faction))
		to_chat(user, "You don't have the permissions to recruit.")
		return

	if (src.incapacitated() || src.client == null)
		to_chat(user, "The target does not seem to respond...")
		return

	var/blocked = faction_enrollment_block(faction, TRUE)
	if (blocked)
		to_chat(user, "You can't recruit [src]. [blocked]")
		return

	var/answer = WWinput(src, "[user] wants to recruit you into their faction, [faction]. Will you accept?", null, "Yes", list("Yes","No"))
	if (answer == "No")
		to_chat(user, "[src] has rejected your offer.")
		return
	if (answer != "Yes")
		return

	// The prompt yielded: recheck the recruiter, the recruit and their distance.
	if (QDELETED(user) || QDELETED(src) || user.stat || user.restrained() || user.civilization != faction || !map.can_recruit_for_faction(user, faction))
		to_chat(src, "The offer to join [faction] is no longer valid.")
		return
	if (src.incapacitated() || src.client == null || get_dist(user, src) > 1)
		to_chat(user, "[src] is no longer close enough to recruit.")
		return
	if (!enroll_in_faction(faction, TRUE))
		blocked = faction_enrollment_block(faction, TRUE)
		to_chat(user, "You can't recruit [src]. [blocked]")
		to_chat(src, "You can't join [faction] right now.")
		return
	to_chat(user, "[src] accepts your offer. They are now part of [faction].")
	to_chat(src, "You accept [user]'s offer. You are now part of [faction].")

/mob/living/human/verb/faction_perms()
	set category = null
	set name = "Faction Perms"
	set desc = "Change the faction permissions of this person."

	set src in view(1)

	if (!ishuman(src) || !ishuman(usr))
		return
	var/mob/living/human/user = usr

	if (user.stat || user.restrained() || !isliving(user))
		return

	if (!map.civilizations || user.civilization == "none" || user.civilization == null)
		to_chat(user, "You are not part of a faction.")
		return

	var/faction = user.civilization
	if (!map.can_manage_faction_permissions(user, faction))
		to_chat(user, "You don't have the permissions to change faction permissions.")
		return

	if (civilization != faction)
		to_chat(user, "[src] is not a member of [faction].")
		return
	if (map.is_faction_leader(src, faction) && !map.is_faction_leader(user, faction))
		to_chat(user, "You can't change your leader's permissions.")
		return

	if (src.incapacitated() || src.client == null)
		to_chat(user, "The target does not seem to respond...")
		return

	var/answer = WWinput(user, "Add or Remove a permission?", null, "Add", list("Add","Remove","Cancel"))
	if (answer != "Add" && answer != "Remove")
		return
	var/list/choices = list("Cancel")
	var/list/perm_names = list("Permission Management", "Announcements", "Giving Titles", "Recruitment")
	for (var/i = 1, i <= perm_names.len, i++)
		if (i == FACTION_PERM_RECRUITMENT && answer == "Add" && !map.nomads)
			continue
		if (!map.can_manage_faction_permissions(user, faction, i))
			continue
		if ((faction_perms[i] == 1) == (answer == "Remove"))
			choices += perm_names[i]
	var/choice = WWinput(user, "Which permission to [answer == "Add" ? "add" : "remove"]?", null, "Cancel", choices)
	var/index = perm_names.Find(choice)
	if (!index)
		return

	// The prompts yielded: recheck the leader and the member before changing anything.
	if (QDELETED(user) || QDELETED(src) || user.stat || user.restrained() || user.civilization != faction || !map.can_manage_faction_permissions(user, faction, index))
		return
	if (civilization != faction)
		to_chat(user, "[src] is no longer a member of [faction].")
		return

	if (answer == "Add")
		if (faction_perms[index] == 1)
			return
		faction_perms[index] = 1
		switch (index)
			if (2)
				make_commander()
			if (3)
				make_title_changer()
		to_chat(src, "<big>You gained the [choice] permission.</big>")
	else
		if (faction_perms[index] == 0)
			return
		faction_perms[index] = 0
		switch (index)
			if (2)
				remove_commander()
			if (3)
				remove_title_changer()
		to_chat(src, "<big>You lost the [choice] permission.</big>")
	to_chat(user, "[src] [answer == "Add" ? "now has" : "no longer has"] the [choice] permission.")

