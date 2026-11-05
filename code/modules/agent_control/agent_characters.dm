// Characters driven by agents (docs/agent-control.md#characters).
//
// Two kinds: characters an agent spawns for the host (no ckey, owned by that
// agent) and a player's own character after the player opts in with the
// "Toggle AI Control" verb (any agent with the characters scope may drive it
// until the player turns it off). Agents act through the same mob procs a
// player's input reaches: movement, say, emote, clicks and hand actions, so
// ordinary range, cooldown and mechanic rules apply.

#define AGENT_CHARACTER_MESSAGES 100
#define AGENT_CHARACTER_QUEUE_MAX 64
#define AGENT_CHARACTER_QUEUE_BATCH 32
#define AGENT_CHARACTER_SPEECH_DELAY 10
#define AGENT_CHOICE_WINDOW 300 // ticks a step's prompt answer stays valid

/datum/agent_character
	var/mob/living/body
	var/owner_agent // spawned characters: the agent that owns them
	var/handover_ckey // opted-in characters: the player who allowed it
	var/pending_choice // answer for the next game prompt (WWinput) during one step
	var/pending_choice_until = 0 // world.time after which that answer is stale
	var/list/messages = list()
	var/message_serial = 0
	var/next_action = 0
	var/next_speech = 0
	var/list/queue = list()
	var/list/queue_results = list()
	var/queue_serial = 0
	var/queue_running = FALSE

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

// Late-join jobs open on this map, as the join menu would offer them.
/proc/agent_map_jobs()
	. = list()
	if (!job_master || !map)
		return
	for (var/datum/job/J in job_master.occupations)
		if (!J.title || !(map.ID in J.allowed_maps) || !J.spawn_location || !findtext(J.spawn_location, "JoinLate"))
			continue
		if (!map.job_enabled_specialcheck(J))
			continue
		if (J.total_positions != -1 && J.current_positions >= J.total_positions)
			continue
		. |= J.title

// A stowed item by name: pockets, then bags and belts, then other worn things (not clothing in hands).
/proc/agent_find_carried(mob/living/human/H, wanted)
	wanted = lowertext(trim("[wanted]"))
	if (!length(wanted))
		return null
	var/list/candidates = list()
	for (var/obj/item/I in list(H.l_store, H.r_store))
		candidates += I
	for (var/obj/item/weapon/storage/S in H.get_equipped_items())
		for (var/obj/item/I in S.contents)
			candidates += I
	for (var/obj/item/I in H.get_equipped_items())
		if (I != H.l_hand && I != H.r_hand)
			candidates += I
	for (var/obj/item/I in candidates)
		if (lowertext(I.name) == wanted)
			return I
	for (var/obj/item/I in candidates)
		if (findtext(lowertext(I.name), wanted))
			return I
	return null

/proc/agent_job_allowed(title)
	return title in agent_map_jobs()

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
	// A job gives the character a late joiner's kit, name and spawn point.
	var/job_title = istext(req["job"]) ? trim(req["job"]) : null
	if (job_title)
		if (!ispath(path, /mob/living/human))
			agent_fail("bad_type", "a job needs a human character")
		if (!agent_job_allowed(job_title))
			agent_fail("bad_job", "jobs on this map: [jointext(agent_map_jobs(), ", ")]")
	var/list/before = list()
	for (var/mob/living/L in T)
		before += L
	var/mob/living/M
	// Take a job slot the way AssignRole does for players; a failed join gives it back.
	var/datum/job/reserved = job_title ? job_master.GetJob(job_title) : null
	if (reserved)
		reserved.current_positions++
	try
		M = new path(T)
		// A mind holds the job's notes; without one the join path complains it is missing.
		if (!M.mind)
			var/datum/mind/agent_mind = new /datum/mind("agent_[A.name]")
			agent_mind.name = M.real_name
			agent_mind.original = M
			agent_mind.transfer_to(M)
		if (job_title && !job_master.EquipRank(M, job_title, TRUE))
			agent_fail("bad_job", "[job_title] could not be equipped")
		if (istext(req["name"]) && length(trim(req["name"])))
			var/new_name = sanitize(copytext(req["name"], 1, 33))
			M.fully_replace_character_name(M.real_name, new_name)
			// Humans pick a map identity (nomads_spawn) half a second after New.
			spawn(6)
				if (!QDELETED(M) && M.real_name != new_name)
					M.fully_replace_character_name(M.real_name, new_name)
	catch(var/exception/E)
		if (reserved)
			reserved.current_positions = max(0, reserved.current_positions - 1)
		// A runtime in New leaves a half-built, untracked body; remove it.
		for (var/mob/living/L in T)
			if (!(L in before) && istype(L, path) && !L.client)
				qdel(L)
		throw E
	var/datum/agent_character/C = new
	C.body = M
	C.owner_agent = A.name
	agent_characters[M] = C
	var/turf/at = get_turf(M)
	audit(A, "character_spawn", "[M] ([agent_ref(M)], [M.type][job_title ? ", [job_title]" : ""]) at [at.x],[at.y],[at.z]")
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
	out["busy"] = M.may_do_after ? FALSE : TRUE
	out["active_hand"] = M.hand ? "left" : "right"
	out["left_hand"] = agent_encode(M.l_hand)
	out["right_hand"] = agent_encode(M.r_hand)
	var/obj/item/stack/held_stack = M.get_active_hand()
	if (istype(held_stack))
		agent_refresh_recipes(held_stack, M)
	if (istype(held_stack) && held_stack.recipes)
		out["craftable"] = agent_stack_recipes(held_stack, TRUE)
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
		var/list/carried = list()
		for (var/obj/item/weapon/storage/S in H.get_equipped_items())
			for (var/obj/item/I in S.contents)
				if (carried.len < 24)
					carried += "[I.name] (in [S.name])"
		for (var/obj/item/I in list(H.l_store, H.r_store))
			if (carried.len < 24)
				carried += "[I.name] (pocket)"
		out["carried"] = carried
		if (H.original_job_title)
			out["job"] = H.original_job_title
		// Injuries a player would see on the health doll: bleeding first, so the agent can stop blood loss.
		var/list/wounds = list()
		for (var/obj/item/organ/external/E in H.organs)
			var/bleeding = (E.status & ORGAN_BLEEDING) ? TRUE : FALSE
			var/broken = (E.status & ORGAN_BROKEN) ? TRUE : FALSE
			if (!bleeding && !broken && E.get_damage() < 5)
				continue
			wounds += list(list("zone" = E.organ_tag, "name" = E.name, "damage" = round(E.get_damage()), "bleeding" = bleeding, "bandaged" = E.is_bandaged() ? TRUE : FALSE, "broken" = broken))
		out["wounds"] = wounds
		out["blood"] = round(H.vessel ? H.vessel.get_reagent_amount("blood") : 0)
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
			if (istype(AM, /obj/item) && !AM.anchored)
				row["item"] = TRUE
			if (istype(AM, /obj/structure/branch))
				var/obj/structure/branch/B = AM
				// A fallen branch is not an item: grab intent takes its leaves, harm intent strips a cleared one into a stick.
				row["branch"] = B.leaves ? "leafy" : (B.branched ? "cleared" : "bare")
			if (istype(AM, /obj/structure/wild) && !istype(AM, /obj/structure/wild/rock))
				var/obj/structure/wild/W = AM
				// Trees and plants say whether harm intent can break a branch off them right now.
				if (W.max_branches > 0 || istype(W, /obj/structure/wild/tree) || istype(W, /obj/structure/wild/palm) || istype(W, /obj/structure/wild/jungle))
					row["branches"] = W.branches
			if (ismob(AM))
				var/mob/other = AM
				row["mob"] = TRUE
				row["stat"] = other.stat
			if (istype(AM, /obj/roof))
				var/obj/roof/R = AM
				row["supported"] = R.is_supported() ? TRUE : FALSE // the same rule collapse_check uses
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
	// The nearest tile of each kind of terrain, so water and the like can be clicked.
	var/list/terrain = list()
	if (here)
		var/list/nearest = list()
		for (var/turf/T in view(radius, M))
			if (T == here || !T.name)
				continue
			var/d = get_dist(here, T)
			// Clean and contaminated water look alike; list the nearest of each.
			var/kind = T.name
			if (istype(T, /turf/floor/beach/water))
				var/turf/floor/beach/water/W = T
				if (W.sickness > 0)
					kind = "[T.name] (unclean)"
			var/list/best = nearest[kind]
			if (!best || d < best["d"])
				nearest[kind] = list("d" = d, "turf" = T)
		for (var/turf_name in nearest)
			if (terrain.len >= 16)
				break
			var/turf/T = nearest[turf_name]["turf"]
			var/list/row = list("ref" = "turf:[T.x],[T.y],[T.z]", "name" = T.name, "type" = "[T.type]", "dx" = T.x - here.x, "dy" = T.y - here.y)
			if (istype(T, /turf/floor/beach/water))
				var/turf/floor/beach/water/W = T
				row["sickness"] = W.sickness
				if (W.salty)
					row["salty"] = TRUE
			if (istype(T, /turf/floor/dirt/underground) && !istype(T, /turf/floor/dirt/underground/empty))
				var/turf/floor/dirt/underground/U = T
				row["safe_to_mine"] = U.mine_supported() ? TRUE : FALSE // would the opened tile stay up
			terrain += list(row)
	var/list/heard = list()
	for (var/list/message in C.messages)
		if (message["id"] > since)
			heard += list(message)
	var/queue_since = text2num("[req["queue_since"]]") || 0
	var/list/here_row = here ? list("turf" = here.name, "type" = "[here.type]") : null
	if (istype(here, /turf/floor/dirt/underground))
		var/turf/floor/dirt/underground/U = here
		var/area/HA = get_area(U)
		if (HA && HA.location == AREA_INSIDE)
			here_row["cave_supported"] = U.mine_supported() ? TRUE : FALSE
	return list("self" = character_state(C), "here" = here_row, "surroundings" = surroundings, "nearby" = nearby, "terrain" = terrain, "messages" = heard, "last_message" = C.message_serial, "queue" = C.queue_state(queue_since))

// Actions a character can take, directly or from its queue.
/proc/agent_character_actions()
	return list("move", "face", "say", "emote", "click", "use", "craft", "equip", "take", "examine", "drop", "swap_hand", "intent", "resist")

// Ticks until the character may take this action: the agent pacing plus the
// mob's own click cooldown (next_move/next_click) and a speech spacing.
/datum/agent_character/proc/wait_for(action)
	var/ready = world.time
	if (action in list("move", "click", "use", "craft", "equip", "take", "drop"))
		ready = max(ready, next_action)
		// Timed work (do_after) in progress: acting now would cancel it.
		if (!body.may_do_after)
			ready = max(ready, world.time + 2)
	if (action in list("click", "use", "craft"))
		ready = max(ready, body.next_move, body.next_click + 1)
	if (action in list("say", "emote"))
		ready = max(ready, next_speech)
	return max(0, ready - world.time)

/datum/agent_control/proc/act_character_act(datum/agent_identity/A, list/req)
	var/datum/agent_character/C = character_arg(A, req)
	var/action = lowertext("[req["do"]]")
	var/wait = (action in agent_character_actions()) ? C.wait_for(action) : 0
	if (wait)
		agent_fail("cooldown", "wait [wait] ticks")
	return perform_step(A, C, req)

// One character action. Callers check wait_for() first. Clicks, use and
// crafting can start timed work (do_after); a Topic reply must not sleep, so
// direct calls run them in the background and the queue runs them in place.
/datum/agent_control/proc/perform_step(datum/agent_identity/A, datum/agent_character/C, list/req, from_queue = FALSE)
	var/mob/living/M = C.body
	// Topic calls have no usr; click, pull and emote paths read it as the actor.
	usr = M
	var/action = lowertext("[req["do"]]")
	var/detail = ""
	// A step may carry the answer to a prompt it raises (a shovel asks what to dig).
	C.pending_choice = req["choose"] ? copytext(agent_text_arg(req, "choose", 64), 1, 65) : null
	C.pending_choice_until = world.time + AGENT_CHOICE_WINDOW
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
			C.next_speech = world.time + AGENT_CHARACTER_SPEECH_DELAY
			detail = message
		if ("emote")
			var/message = copytext(agent_text_arg(req, "text", 256), 1, 257)
			M.custom_emote(1, html_encode(message))
			C.next_speech = world.time + AGENT_CHARACTER_SPEECH_DELAY
			detail = message
		if ("click")
			var/atom/target = agent_resolve_target(req["target"])
			if (!isatom(target) || !(target in view(7, M)) && !(target in M.contents) && !(get_turf(target) in view(7, M)))
				agent_fail("out_of_view", "the target is not visible to this character")
			var/params = ""
			if (req["modifier"] in list("shift", "ctrl", "alt", "middle"))
				params = "[req["modifier"]]=1"
			// The body part a click aims at (the zone selector): bandages and attacks use it.
			if (req["zone"] in list("head", "eyes", "mouth", "chest", "groin", "l_arm", "r_arm", "l_hand", "r_hand", "l_leg", "r_leg", "l_foot", "r_foot"))
				M.targeted_organ = req["zone"]
			C.next_action = world.time + 2
			detail = "[target] ([agent_ref(target)]) [params]"
			if (from_queue)
				M.ClickOn(target, params)
			else
				spawn(0)
					usr = M
					M.ClickOn(target, params)
		if ("use")
			var/obj/item/I = M.get_active_hand()
			if (!I)
				agent_fail("empty_hand", "nothing in the active hand")
			C.next_action = world.time + 2
			detail = "[I]"
			if (from_queue)
				I.attack_self(M)
			else
				spawn(0)
					usr = M
					I.attack_self(M)
		if ("craft")
			var/obj/item/stack/S = M.get_active_hand()
			if (istype(S))
				agent_refresh_recipes(S, M)
			if (!istype(S) || !S.recipes)
				agent_fail("bad_args", "hold a stack of material to craft from it")
			var/wanted = agent_text_arg(req, "recipe", 128)
			var/list/found = agent_find_recipe(S, wanted)
			if (!found)
				agent_fail("not_found", "no recipe [wanted] for [S]; see craftable in character_observe")
			var/datum/stack_recipe/R = found["recipe"]
			var/amount = clamp(round(text2num("[req["amount"]]") || 1), 1, max(1, round(S.amount / max(1, R.req_amount))))
			var/list/href = list("make" = "[found["index"]]", "multiplier" = "[amount]")
			if (found["sublist"])
				href["sublist"] = "[found["sublist"]]"
			C.next_action = world.time + 5
			detail = "[R.title] x[amount] from [S]"
			if (from_queue)
				S.Topic("", href)
			else
				spawn(0)
					usr = M
					S.Topic("", href)
		if ("equip")
			var/obj/item/I = M.get_active_hand()
			if (!I)
				agent_fail("empty_hand", "nothing in the active hand")
			if (!ishuman(M))
				agent_fail("bad_type", "only humans can equip items")
			var/mob/living/human/H = M
			H.quick_equip()
			C.next_action = world.time + 2
			if (I.loc == M && (I == M.l_hand || I == M.r_hand))
				agent_fail("no_slot", "there is nowhere free to put [I]")
			detail = "[I]"
		if ("examine")
			var/atom/target = agent_resolve_target(req["target"])
			if (!isatom(target) || !(target in view(7, M)) && !(target in M.contents) && !(get_turf(target) in view(7, M)))
				agent_fail("out_of_view", "the target is not visible to this character")
			M.examinate(target)
			detail = "[target]"
		if ("take")
			// Take a stowed item (pocket, belt, bag) back into the empty active hand.
			if (!ishuman(M))
				agent_fail("bad_type", "only humans carry items")
			var/mob/living/human/H = M
			if (H.get_active_hand())
				agent_fail("hands_full", "the active hand must be empty to take something")
			var/obj/item/I = agent_find_carried(H, req["item"])
			if (!I)
				agent_fail("not_carried", "no carried item called [req["item"]]")
			if (istype(I.loc, /obj/item/weapon/storage))
				var/obj/item/weapon/storage/S = I.loc
				S.remove_from_storage(I, get_turf(H))
			else if (!H.unEquip(I))
				agent_fail("stuck", "[I] cannot be taken off")
			if (!H.put_in_active_hand(I))
				agent_fail("hands_full", "[I] could not be put in the hand")
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
			agent_fail("bad_args", "do must be one of [jointext(agent_character_actions(), ", ")]")
	log_admin("AGENT [A.name]: character_act [action] as [M] ([agent_ref(M)]) [detail]")
	return list("done" = action, "self" = character_state(C))

// Material stacks pick their recipe list for the user when the menu opens
// (era, faction, race); do the same before reading or using it.
/proc/agent_refresh_recipes(obj/item/stack/S, mob/M)
	var/obj/item/stack/material/MS = S
	if (istype(MS) && MS.material && ishuman(M))
		MS.recipes = MS.material.get_recipes_civs(M)

// Recipes a held stack offers, as "title" or "group/title".
/proc/agent_stack_recipes(obj/item/stack/S, buildable_only = FALSE)
	. = list()
	for (var/E in S.recipes)
		if (istype(E, /datum/stack_recipe))
			var/datum/stack_recipe/R = E
			if (!buildable_only || S.amount >= R.req_amount)
				. += "[R.title] ([R.req_amount])"
		else if (istype(E, /datum/stack_recipe_list))
			var/datum/stack_recipe_list/L = E
			for (var/datum/stack_recipe/R in L.recipes)
				if (!buildable_only || S.amount >= R.req_amount)
					. += "[L.title]/[R.title] ([R.req_amount])"
		if (length(.) >= 60)
			break

// Matches "title", "group/title" or either with the "(n)" cost suffix.
/proc/agent_find_recipe(obj/item/stack/S, wanted)
	wanted = lowertext(trim(wanted))
	var/paren = findtext(wanted, " (")
	if (paren)
		wanted = copytext(wanted, 1, paren)
	var/group = null
	var/slash = findtext(wanted, "/")
	if (slash)
		group = copytext(wanted, 1, slash)
		wanted = copytext(wanted, slash + 1)
	for (var/i in 1 to S.recipes.len)
		var/E = S.recipes[i]
		if (istype(E, /datum/stack_recipe) && !group)
			var/datum/stack_recipe/R = E
			if (lowertext(R.title) == wanted)
				return list("recipe" = R, "index" = i)
		else if (istype(E, /datum/stack_recipe_list))
			var/datum/stack_recipe_list/L = E
			if (group && lowertext(L.title) != group)
				continue
			for (var/j in 1 to L.recipes.len)
				var/datum/stack_recipe/R = L.recipes[j]
				if (istype(R) && lowertext(R.title) == wanted)
					return list("recipe" = R, "index" = j, "sublist" = i)
	return null

// ---------------------------------------------------------------------------
// Action queue. An agent submits a plan of steps; the server runs them in
// order, waiting for each step's cooldown, so the agent need not poll per step.

/datum/agent_control/proc/act_character_queue(datum/agent_identity/A, list/req)
	var/datum/agent_character/C = character_arg(A, req)
	var/list/steps = req["actions"]
	if (!isnull(steps) && !islist(steps))
		agent_fail("bad_args", "actions must be a list")
	if (req["clear"] == TRUE || req["clear"] == 1)
		if (C.queue.len)
			log_admin("AGENT [A.name]: character_queue cleared [C.queue.len] steps for [C.body] ([agent_ref(C.body)])")
		C.queue.Cut()
	var/list/added = list()
	if (steps && steps.len)
		if (steps.len > AGENT_CHARACTER_QUEUE_BATCH)
			agent_fail("bad_args", "at most [AGENT_CHARACTER_QUEUE_BATCH] actions per request")
		if (C.queue.len + steps.len > AGENT_CHARACTER_QUEUE_MAX)
			agent_fail("queue_full", "the queue holds at most [AGENT_CHARACTER_QUEUE_MAX] steps; [C.queue.len] are pending")
		var/list/checked = list()
		for (var/list/step in steps)
			checked += list(check_step(step))
		if (checked.len != steps.len)
			agent_fail("bad_args", "each action must be an object")
		var/stop_on_failure = req["stop_on_failure"] != FALSE && req["stop_on_failure"] != 0
		for (var/list/step in checked)
			step["id"] = ++C.queue_serial
			step["agent"] = A.name
			step["stop_on_failure"] = stop_on_failure
			C.queue += list(step)
			added += step["id"]
		log_admin("AGENT [A.name]: character_queue [added.len] steps for [C.body] ([agent_ref(C.body)])")
		if (!C.queue_running)
			spawn(0)
				run_queue(C)
	return list("queued" = added, "queue" = C.queue_state())

// Validates a queued step up front so a typo fails the request, not step 7.
/datum/agent_control/proc/check_step(list/step)
	if (!islist(step))
		agent_fail("bad_args", "each action must be an object")
	var/action = lowertext("[step["do"]]")
	var/list/out = list("do" = action)
	if (action == "wait")
		var/ticks = text2num("[step["ticks"]]")
		if (!isnum(ticks) || ticks < 1 || ticks > 600)
			agent_fail("bad_args", "wait needs ticks 1-600 (deciseconds)")
		out["ticks"] = round(ticks)
		return out
	if (!(action in agent_character_actions()))
		agent_fail("bad_args", "do must be wait or one of [jointext(agent_character_actions(), ", ")]")
	if (action in list("move", "face"))
		agent_dir(step["dir"])
	if (action in list("say", "emote"))
		agent_text_arg(step, "text", 256)
	if (action in list("click", "examine"))
		agent_resolve_target(step["target"])
	if (action == "craft")
		agent_text_arg(step, "recipe", 128)
	if (action == "take")
		agent_text_arg(step, "item", 64)
	if (!isnull(step["choose"]))
		agent_text_arg(step, "choose", 64)
	for (var/key in list("dir", "text", "target", "modifier", "intent", "recipe", "amount", "item", "choose", "zone"))
		if (!isnull(step[key]))
			out[key] = step[key]
	return out

/datum/agent_character/proc/queue_state(since = 0)
	var/list/pending = list()
	for (var/list/step in queue)
		pending += list(list("id" = step["id"], "do" = step["do"]))
	var/list/done = list()
	for (var/list/result in queue_results)
		if (result["id"] > since)
			done += list(result)
	return list("pending" = pending, "running" = queue_running ? TRUE : FALSE, "results" = done)

/datum/agent_character/proc/record(list/step, ok, detail)
	queue_results += list(list("id" = step["id"], "do" = step["do"], "ok" = ok ? TRUE : FALSE, "detail" = detail, "time" = world.time))
	if (queue_results.len > AGENT_CHARACTER_QUEUE_MAX)
		queue_results.Cut(1, 2)

/datum/agent_control/proc/run_queue(datum/agent_character/C)
	if (C.queue_running)
		return
	C.queue_running = TRUE
	while (C.queue.len)
		var/mob/living/M = C.body
		if (QDELETED(M) || agent_characters[M] != C)
			C.queue.Cut()
			break
		var/list/step = C.queue[1]
		var/action = step["do"]
		if (action == "wait")
			C.queue.Cut(1, 2)
			sleep(step["ticks"])
			C.record(step, TRUE, "waited [step["ticks"]] ticks")
			continue
		var/wait = C.wait_for(action)
		if (wait)
			sleep(wait)
			continue
		C.queue.Cut(1, 2)
		reload() // a removed or changed agent stops its queued steps too
		var/datum/agent_identity/A = agents[step["agent"]]
		if (!A || !C.can_drive(A))
			C.record(step, FALSE, "forbidden: the agent no longer controls this character")
			C.queue.Cut()
			break
		try
			var/list/result = perform_step(A, C, step, TRUE)
			C.record(step, TRUE, result["moved"] == FALSE ? "blocked" : "done")
		catch(var/exception/E)
			var/detail = E.name == "agent_control_error" ? E.desc : "runtime_error:[E.name] ([E.file]:[E.line])"
			C.record(step, FALSE, detail)
			if (step["stop_on_failure"])
				for (var/list/rest in C.queue)
					C.record(rest, FALSE, "skipped: an earlier step failed")
				C.queue.Cut()
				break
		// At most one queued step per tick for each character.
		sleep(1)
	C.queue_running = FALSE

/datum/agent_control/proc/act_character_release(datum/agent_identity/A, list/req)
	var/datum/agent_character/C = character_arg(A, req)
	var/mob/living/M = C.body
	agent_characters -= M
	C.queue.Cut()
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
