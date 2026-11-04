// Characters driven by agents (docs/agent-control.md#characters).
//
// Two kinds: characters an agent spawns for the host (no ckey, owned by that
// agent) and a player's own character after the player opts in with the
// "Toggle AI Control" verb (any agent with the characters scope may drive it
// until the player turns it off). Agents act through the same mob procs a
// player's input reaches: movement, say, emote, clicks and hand actions, so
// ordinary range, cooldown and mechanic rules apply.

#define AGENT_CHARACTER_MESSAGES 100

/datum/agent_character
	var/mob/living/body
	var/owner_agent // spawned characters: the agent that owns them
	var/handover_ckey // opted-in characters: the player who allowed it
	var/list/messages = list()
	var/message_serial = 0
	var/next_action = 0

/datum/agent_character/proc/capture(message)
	var/text = agent_plain_text(message)
	if (!length(trim(text)))
		return
	message_serial++
	messages += list(list("id" = message_serial, "time" = world.time, "text" = text))
	if (messages.len > AGENT_CHARACTER_MESSAGES)
		messages.Cut(1, 2)

/datum/agent_character/proc/can_drive(datum/agent_identity/A)
	if (handover_ckey)
		return TRUE
	return owner_agent == A.name

/proc/agent_character_for(mob/M)
	if (!agent_characters.len || !M)
		return null
	return agent_characters[M]

/datum/agent_control/proc/prune_characters()
	for (var/mob/M in agent_characters.Copy())
		if (QDELETED(M))
			agent_characters -= M

/datum/agent_control/proc/character_arg(datum/agent_identity/A, list/req)
	prune_characters()
	var/mob/living/M = agent_resolve_target(req["character"])
	var/datum/agent_character/C = agent_characters[M]
	if (!C || !C.can_drive(A))
		agent_fail("forbidden", "that character is not under this agent's control")
	return C

/proc/agent_dir(text)
	switch (lowertext("[text]"))
		if ("north", "n", "up") return NORTH
		if ("south", "s", "down") return SOUTH
		if ("east", "e", "right") return EAST
		if ("west", "w", "left") return WEST
		if ("northeast", "ne") return NORTHEAST
		if ("northwest", "nw") return NORTHWEST
		if ("southeast", "se") return SOUTHEAST
		if ("southwest", "sw") return SOUTHWEST
	agent_fail("bad_args", "dir must be north, south, east, west or a diagonal")

/datum/agent_control/proc/act_character_spawn(datum/agent_identity/A, list/req)
	prune_characters()
	var/owned = 0
	for (var/mob/M in agent_characters)
		var/datum/agent_character/C = agent_characters[M]
		if (C.owner_agent == A.name)
			owned++
	if (owned >= max_characters)
		agent_fail("limit", "this agent already controls [owned] of [max_characters] allowed characters")
	var/path = req["type"] ? text2path("[req["type"]]") : /mob/living/human
	if (!ispath(path, /mob/living))
		agent_fail("bad_type", "type must be a /mob/living path")
	var/turf/T = get_turf(agent_resolve_target(req["target"]))
	if (!T)
		agent_fail("bad_target", "target has no turf")
	var/mob/living/M = new path(T)
	if (istext(req["name"]) && length(trim(req["name"])))
		var/new_name = sanitize(copytext(req["name"], 1, 33))
		M.fully_replace_character_name(M.real_name, new_name)
		// Humans pick a map identity (nomads_spawn) half a second after New.
		spawn(6)
			if (!QDELETED(M) && M.real_name != new_name)
				M.fully_replace_character_name(M.real_name, new_name)
	var/datum/agent_character/C = new
	C.body = M
	C.owner_agent = A.name
	agent_characters[M] = C
	audit(A, "character_spawn", "[M] ([agent_ref(M)], [M.type]) at [T.x],[T.y],[T.z]")
	return character_state(C)

/datum/agent_control/proc/act_character_list(datum/agent_identity/A, list/req)
	prune_characters()
	var/list/out = list()
	for (var/mob/living/M in agent_characters)
		var/datum/agent_character/C = agent_characters[M]
		if (!C.can_drive(A))
			continue
		var/list/row = agent_encode(M)
		row["kind"] = C.handover_ckey ? "handover" : "spawned"
		if (C.handover_ckey)
			row["player"] = C.handover_ckey
			row["player_connected"] = M.client ? TRUE : FALSE
		row["stat"] = M.stat
		out += list(row)
	audit_read(A, "character_list")
	return list("characters" = out, "allow_handover" = allow_handover)

/datum/agent_control/proc/character_state(datum/agent_character/C)
	var/mob/living/M = C.body
	var/list/out = agent_encode(M)
	out["stat"] = M.stat
	out["health"] = M.health
	out["max_health"] = M.maxHealth
	out["dir"] = dir2text(M.dir)
	out["intent"] = M.a_intent
	out["active_hand"] = M.hand ? "left" : "right"
	out["left_hand"] = agent_encode(M.l_hand)
	out["right_hand"] = agent_encode(M.r_hand)
	out["can_move"] = M.canmove && !M.restrained() && !M.buckled && M.stat == CONSCIOUS
	var/area/area = get_area(M)
	if (area)
		out["area"] = area.name
	for (var/stat_name in list("nutrition", "water", "bladder", "stamina", "mood", "bodytemperature"))
		if (stat_name in M.vars)
			out[stat_name] = agent_encode(M.vars[stat_name])
	if (istype(M, /mob/living/human))
		var/mob/living/human/H = M
		var/list/worn = list()
		for (var/obj/item/I in H.get_equipped_items())
			worn += I.name
		out["worn"] = worn
		if (H.original_job_title)
			out["job"] = H.original_job_title
	return out

/datum/agent_control/proc/act_character_observe(datum/agent_identity/A, list/req)
	var/datum/agent_character/C = character_arg(A, req)
	var/mob/living/M = C.body
	var/radius = clamp(round(text2num("[req["radius"]]") || 5), 1, 7)
	var/since = text2num("[req["since"]]") || 0
	audit_read(A, "character_observe", "[M] ([agent_ref(M)])")
	var/turf/here = get_turf(M)
	var/list/nearby = list()
	if (here)
		for (var/atom/movable/AM in view(radius, M))
			if (AM == M || !isturf(AM.loc) || AM.invisibility > M.see_invisible || !AM.name)
				continue
			if (nearby.len >= 64)
				break
			var/turf/T = get_turf(AM)
			var/list/row = list("ref" = agent_ref(AM), "name" = AM.name, "type" = "[AM.type]", "dx" = T.x - here.x, "dy" = T.y - here.y)
			if (AM.density)
				row["dense"] = TRUE
			if (ismob(AM))
				var/mob/other = AM
				row["mob"] = TRUE
				row["stat"] = other.stat
			nearby += list(row)
	var/list/surroundings = list()
	if (here)
		for (var/d in list(NORTH, SOUTH, EAST, WEST))
			var/turf/T = get_step(here, d)
			if (!T)
				surroundings[dir2text(d)] = "edge"
				continue
			var/blocked = T.density
			if (!blocked)
				for (var/atom/movable/AM in T)
					if (AM.density && AM != M)
						blocked = TRUE
						break
			surroundings[dir2text(d)] = list("turf" = T.name, "type" = "[T.type]", "blocked" = blocked ? TRUE : FALSE)
	var/list/heard = list()
	for (var/list/message in C.messages)
		if (message["id"] > since)
			heard += list(message)
	return list("self" = character_state(C), "here" = here ? list("turf" = here.name, "type" = "[here.type]") : null, "surroundings" = surroundings, "nearby" = nearby, "messages" = heard, "last_message" = C.message_serial)

/datum/agent_control/proc/act_character_act(datum/agent_identity/A, list/req)
	var/datum/agent_character/C = character_arg(A, req)
	var/mob/living/M = C.body
	// Topic calls have no usr; click, pull and emote paths read it as the actor.
	usr = M
	var/action = lowertext("[req["do"]]")
	if (world.time < C.next_action && (action in list("move", "click", "use", "drop")))
		agent_fail("cooldown", "wait [C.next_action - world.time] ticks")
	var/detail = ""
	switch (action)
		if ("move")
			var/d = agent_dir(req["dir"])
			if (M.stat != CONSCIOUS || !M.canmove || M.restrained() || M.buckled)
				agent_fail("cannot_move", "the character cannot move right now")
			var/turf/old = get_turf(M)
			M.Move(get_step(M, d), d)
			var/moved = get_turf(M) != old
			C.next_action = world.time + max(1, M.movement_delay())
			detail = "[dir2text(d)] [moved ? "moved" : "blocked"] from [old.x],[old.y],[old.z]"
			game_log("AGENT", "[A.name] moved [M] ([agent_ref(M)]) [detail]")
			return list("moved" = moved ? TRUE : FALSE, "self" = character_state(C))
		if ("face")
			var/d = agent_dir(req["dir"])
			M.set_dir(d)
			detail = dir2text(d)
		if ("say")
			var/message = copytext(agent_text_arg(req, "text", 256), 1, 257)
			M.say(message)
			detail = message
		if ("emote")
			var/message = copytext(agent_text_arg(req, "text", 256), 1, 257)
			M.custom_emote(1, html_encode(message))
			detail = message
		if ("click")
			var/atom/target = agent_resolve_target(req["target"])
			if (!isatom(target) || !(target in view(7, M)) && !(target in M.contents) && !(get_turf(target) in view(7, M)))
				agent_fail("out_of_view", "the target is not visible to this character")
			var/params = ""
			if (req["modifier"] in list("shift", "ctrl", "alt", "middle"))
				params = "[req["modifier"]]=1"
			M.next_click = 0
			M.ClickOn(target, params)
			C.next_action = world.time + 2
			detail = "[target] ([agent_ref(target)]) [params]"
		if ("use")
			var/obj/item/I = M.get_active_hand()
			if (!I)
				agent_fail("empty_hand", "nothing in the active hand")
			I.attack_self(M)
			C.next_action = world.time + 2
			detail = "[I]"
		if ("drop")
			M.drop_item()
			C.next_action = world.time + 2
		if ("swap_hand")
			M.swap_hand()
		if ("intent")
			var/intent = lowertext("[req["intent"]]")
			if (!(intent in list(I_HELP, I_DISARM, I_GRAB, I_HARM)))
				agent_fail("bad_args", "intent must be help, disarm, grab or harm")
			M.a_intent = intent
			detail = intent
		if ("resist")
			M.resist()
		else
			agent_fail("bad_args", "do must be move, face, say, emote, click, use, drop, swap_hand, intent or resist")
	log_admin("AGENT [A.name]: character_act [action] as [M] ([agent_ref(M)]) [detail]")
	return list("done" = action, "self" = character_state(C))

/datum/agent_control/proc/act_character_release(datum/agent_identity/A, list/req)
	var/datum/agent_character/C = character_arg(A, req)
	var/mob/living/M = C.body
	agent_characters -= M
	if (C.handover_ckey)
		if (M.client)
			to_chat(M, "<span class='notice'>The AI has handed control of your character back to you.</span>")
		audit(A, "character_release", "handed [M] back to [C.handover_ckey]")
		return list("released" = TRUE)
	var/delete = req["delete"] == TRUE || req["delete"] == 1
	audit(A, "character_release", "[M] ([agent_ref(M)])[delete ? " deleted" : ""]")
	if (delete && !M.client)
		qdel(M)
	return list("released" = TRUE, "deleted" = delete ? TRUE : FALSE)

// ---------------------------------------------------------------------------
// Player opt-in. Added to clients only while handover is enabled.

/client/proc/toggle_agent_control()
	set category = "OOC"
	set name = "Toggle AI Control"
	set desc = "Let a server AI agent play your character, or take control back."
	if (!agent_control.enabled() || !agent_control.allow_handover)
		to_chat(src, "<span class='warning'>AI control is not enabled on this server.</span>")
		return
	var/mob/living/M = mob
	if (!istype(M) || M.stat == DEAD)
		to_chat(src, "<span class='warning'>You need a living character to hand over.</span>")
		return
	var/datum/agent_character/C = agent_characters[M]
	if (C)
		if (C.owner_agent)
			to_chat(src, "<span class='warning'>This character belongs to a server agent.</span>")
			return
		agent_characters -= M
		to_chat(src, "<span class='notice'>You have taken back control of your character.</span>")
		log_admin("AGENT handover: [key_name(src)] took back control of [M].")
		return
	if (alert(src, "Let a server AI agent control [M.real_name]? It can move, talk and act as you until you use this verb again. Your own input still works.", "AI Control", "Hand over", "Cancel") != "Hand over")
		return
	if (mob != M || agent_characters[M])
		return
	C = new
	C.body = M
	C.handover_ckey = ckey
	agent_characters[M] = C
	to_chat(src, "<span class='notice'>An AI agent may now control [M.real_name]. Use Toggle AI Control again to take it back.</span>")
	log_admin("AGENT handover: [key_name(src)] handed [M] ([agent_ref(M)]) to server agents.")
	message_admins("[key_name_admin(src)] handed their character to server AI agents.")

/datum/agent_control/proc/update_handover_verbs(client/C)
	if (allow_handover && agents.len)
		C.verbs |= /client/proc/toggle_agent_control
	else
		C.verbs -= /client/proc/toggle_agent_control

/hook/startup/proc/agent_control_startup()
	agent_control.reload()
	return TRUE

#undef AGENT_CHARACTER_MESSAGES
