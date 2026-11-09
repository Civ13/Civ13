/mob/living/human/verb/give(var/mob/living/target in view(1)-usr)
	set category = "IC"
	set name = "Give"

	if (incapacitated())
		return
	if (!istype(target) || target.incapacitated() || target.client == null)
		return

	var/obj/item/I = usr.get_active_hand()
	if (!I)
		I = usr.get_inactive_hand()
	if (!I)
		to_chat(usr, SPAN_WARNING("You don't have anything in your hands to give to \the [target]."))
		return

	if (WWinput(target, "[usr] wants to give you \a [I]. Will you accept it?", null, "Yes", list("Yes","No")) == "No")
		target.visible_message("<span class='notice'>\The [usr] tried to hand \the [I] to \the [target], \
		but \the [target] didn't want it.</span>")
		return

	if (!I) return

	if (!Adjacent(target))
		to_chat(usr, SPAN_WARNING("You need to stay in reaching distance whilst giving an object."))
		to_chat(target, SPAN_WARNING("\The [usr] moved too far away."))
		return

	if (I.loc != usr || (usr.l_hand != I && usr.r_hand != I))
		to_chat(usr, SPAN_WARNING("You need to keep the item in your hands."))
		to_chat(target, SPAN_WARNING("\The [usr] seems to have given up on passing \the [I] to you."))
		return

	if (target.r_hand != null && target.l_hand != null)
		to_chat(target, SPAN_WARNING("Your hands are full."))
		to_chat(usr, SPAN_WARNING("Their hands are full."))
		return

	if (usr.unEquip(I))
		target.put_in_hands(I) // If this fails it will just end up on the floor, but that's fitting for things like dionaea.
		target.visible_message("<span class='notice'>\The [usr] handed \the [I] to \the [target].</span>")

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
		to_chat(user, "Only your faction's leader can change faction permissions.")
		return

	if (civilization != faction)
		to_chat(user, "[src] is not a member of [faction].")
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
		if ((faction_perms[i] == 1) == (answer == "Remove"))
			choices += perm_names[i]
	var/choice = WWinput(user, "Which permission to [answer == "Add" ? "add" : "remove"]?", null, "Cancel", choices)
	var/index = perm_names.Find(choice)
	if (!index)
		return

	// The prompts yielded: recheck the leader and the member before changing anything.
	if (QDELETED(user) || QDELETED(src) || user.stat || user.restrained() || user.civilization != faction || !map.can_manage_faction_permissions(user, faction))
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

