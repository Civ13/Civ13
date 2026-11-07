// Verbs and throwing for agent characters: what a player reaches through the
// right-click menu, the verb panels or the command bar (lie down, sleep, give,
// point, check pulse, an item's own verbs such as unloading a gun), and the
// throw hotkey. See docs/agent-control.md#characters.

// BYOND's own type for proc and verb references; declaring its vars lets code read a
// verb's name and category from a mob's or object's verbs list.
/procpath
	var/name
	var/category
	var/desc

// Verb categories and names a player's character has that an agent must not use:
// out-of-character, admin and client settings, and ending the character's life.
/proc/agent_verb_key(text)
	return lowertext(replacetext(trim("[text]"), "_", " "))

/proc/agent_verb_allowed(procpath/P)
	if (!P || !P.name)
		return FALSE
	if (P.category in list("OOC", "Admin", "Debug", "Server", "Fun", "Mapping", "Special Verbs", "Preferences", "Ghost", "Admin.Events"))
		return FALSE
	if (agent_verb_key(P.name) in list("succumb", "abandon mob", "ghost", "disableclick", "disabledblclick", "toggle ai control", "toggle hotkey verbs", "toggle smooth movement", "suicide"))
		return FALSE
	return TRUE

// Names of the verbs an atom offers that an agent may use (at most limit).
// Emotes are left out of the list (the emote action covers them) but can still be called.
/proc/agent_verb_names(atom/T, limit = 60)
	. = list()
	if (!T)
		return
	for (var/V in T.verbs)
		var/procpath/P = V
		if (agent_verb_allowed(P) && P.category != "Emote")
			. |= P.name
			if (length(.) >= limit)
				return

/proc/agent_find_verb(atom/T, wanted)
	wanted = agent_verb_key(wanted)
	for (var/V in T.verbs)
		var/procpath/P = V
		if (agent_verb_allowed(P) && agent_verb_key(P.name) == wanted)
			return P
	return null

// An atom whose verbs the character can reach: itself, what it holds or wears
// (and what is in its bags), or something on a tile next to it.
/proc/agent_verb_reach(mob/living/M, atom/T)
	if (T == M)
		return TRUE
	var/atom/holder = T.loc
	for (var/depth in 1 to 3)
		if (!holder)
			break
		if (holder == M)
			return TRUE
		holder = holder.loc
	return isturf(T.loc) && get_dist(M, T) <= 1 && (T in view(1, M))

// Verbs offered by what the character holds and wears, as "item: verb".
/proc/agent_item_verbs(mob/living/M, limit = 20)
	. = list()
	if (!ishuman(M))
		return
	var/mob/living/human/H = M
	for (var/obj/item/I in H.get_equipped_items() | list(H.l_hand, H.r_hand))
		for (var/name in agent_verb_names(I, 6))
			. += "[I.name]: [name]"
			if (length(.) >= limit)
				return

/datum/agent_control/proc/agent_run_verb(datum/agent_character/C, list/req, from_queue)
	agent_queue_only("verb", from_queue) // many verbs sleep (do_after, sleeping, giving), and a Topic reply must not
	var/mob/living/M = C.body
	if (M.stat != CONSCIOUS)
		agent_fail("cannot_act", "the character is not conscious")
	var/atom/T = isnull(req["target"]) ? M : agent_resolve_target(req["target"])
	if (!isatom(T) || !agent_verb_reach(M, T))
		agent_fail("out_of_reach", "verbs need yourself, something you hold or wear, or something next to you")
	var/wanted = agent_text_arg(req, "name", 64)
	// "item: verb" as listed in item_verbs names the held or worn item.
	var/item_name = null
	var/colon = findtext(wanted, ": ")
	if (colon)
		item_name = lowertext(trim(copytext(wanted, 1, colon)))
		wanted = copytext(wanted, colon + 2)
	var/procpath/P = item_name ? null : agent_find_verb(T, wanted)
	// A verb asked of the character itself may belong to what it holds or wears.
	if (!P && T == M && ishuman(M))
		var/mob/living/human/H = M
		for (var/obj/item/I in list(H.get_active_hand(), H.get_inactive_hand()) | H.get_equipped_items())
			if (item_name && lowertext(I.name) != item_name)
				continue
			P = agent_find_verb(I, wanted)
			if (P)
				T = I
				break
	if (!P)
		agent_fail("not_found", "[T] has no verb [wanted]; verbs: [jointext(agent_verb_names(T), ", ")]")
	// A verb's own argument: someone or something (give, point, pull), or a line of text.
	var/list/verb_args = list()
	if (!isnull(req["onto"]))
		var/atom/onto = agent_resolve_target(req["onto"])
		if (!isatom(onto) || !(onto in view(7, M)) && !(onto in M.contents))
			agent_fail("out_of_view", "the verb's target is not visible to this character")
		verb_args += onto
	else if (!isnull(req["text"]))
		verb_args += copytext(agent_text_arg(req, "text", 256), 1, 257)
	C.next_action = world.time + 2
	usr = M
	call(T, P)(arglist(verb_args))
	return "[P.name] on [T] ([agent_ref(T)])"

// Throw the held item at a target, like throw mode and a click.
/datum/agent_control/proc/agent_throw(datum/agent_character/C, list/req, from_queue)
	agent_queue_only("throw", from_queue) // the throw itself sleeps while the item flies
	var/mob/living/M = C.body
	if (M.stat != CONSCIOUS || M.restrained())
		agent_fail("cannot_act", "the character cannot throw right now")
	var/obj/item/I = M.get_active_hand()
	if (!I)
		agent_fail("empty_hand", "nothing in the active hand to throw")
	var/atom/target = agent_resolve_target(req["target"])
	if (!isatom(target) || !(get_turf(target) in view(7, M)))
		agent_fail("out_of_view", "the target is not visible to this character")
	usr = M
	M.throw_mode_on()
	M.throw_item(target)
	C.next_action = world.time + 5
	return "[I] at [target] ([agent_ref(target)])"
