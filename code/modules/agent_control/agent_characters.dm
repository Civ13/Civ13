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
#define AGENT_WATCH_WINDOW 600 // ticks since an agent last listed its characters for it to count as watching
#define AGENT_CHARACTER_PROMPTS 16
#define AGENT_CHARACTER_SOUNDS 32
#define AGENT_CHARACTER_REPEAT_MAX 30
#define AGENT_QUEUE_GUARD_TTL 300 // one observed queue ticket is valid for at most 30 seconds

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
	var/queue_generation = 0 // cancellation invalidates repeats and sleeping steps
	var/queue_guard
	var/queue_guard_at = 0
	var/queue_guard_agent
	var/list/queue_request_ids = list() // bounded duplicate-id guard; consumed observation guards never replay
	var/list/queue_active // a running game proc may sleep after leaving queue
	var/awaiting_driver = FALSE // spawned by an admin verb; no autopilot has looked through its eyes yet
	var/requested_goal // what the admin asked the character to do
	var/list/prompts = list() // prompts the game raised that no step answered (docs/agent-control.md#prompts)
	var/prompt_serial = 0
	var/list/sounds = list() // sounds the character heard (docs/agent-control.md#sounds)
	var/sound_serial = 0
	var/list/seen // ref -> signature of the last observe's nearby rows, for change lists
	var/seen_rev = 0

/datum/agent_character/proc/capture(message)
	var/text = agent_plain_text(message)
	if (!length(trim(text)))
		return
	message_serial++
	messages += list(list("id" = message_serial, "time" = world.time, "text" = text))
	if (messages.len > AGENT_CHARACTER_MESSAGES)
		messages.Cut(1, 2)

// A prompt (WWinput) the character could not answer from its step: what was asked
// and what it took instead, so the agent can repeat the step with choose.
/datum/agent_character/proc/note_prompt(message, title, list/choices, kind, taken)
	prompt_serial++
	var/list/row = list("id" = prompt_serial, "time" = world.time, "title" = agent_plain_text("[title]"), "text" = copytext(agent_plain_text("[message]"), 1, 301))
	if (choices)
		var/list/names = list()
		for (var/choice in choices)
			if (names.len >= 40)
				break
			names += copytext(agent_plain_text("[choice]"), 1, 65)
		row["choices"] = names
	else if (istext(kind))
		row["kind"] = kind
	row["took"] = isnull(taken) || taken == FALSE ? null : "[taken]"
	prompts += list(row)
	if (prompts.len > AGENT_CHARACTER_PROMPTS)
		prompts.Cut(1, 2)

// A sound played near the character (playsound reaches clients only; this is
// the agent's ear). label is the sound's name or file without folder and extension.
/datum/agent_character/proc/hear_sound(turf/source, label, vol, kind)
	var/turf/here = get_turf(body)
	if (!here || !source)
		return
	sound_serial++
	var/list/row = list("id" = sound_serial, "time" = world.time, "sound" = label, "dx" = source.x - here.x, "dy" = source.y - here.y, "volume" = round(vol))
	if (findtext(label, "footstep"))
		row["footsteps"] = TRUE
	if (kind)
		row["kind"] = kind
	sounds += list(row)
	if (sounds.len > AGENT_CHARACTER_SOUNDS)
		sounds.Cut(1, 2)

// What kind of sound a file is, from its folder: gunshot, explosion, animal, voice, footsteps or null.
/proc/agent_sound_kind(requested, soundin)
	var/path = lowertext("[requested] [soundin]")
	if (findtext(path, "footstep"))
		return "footsteps"
	if (findtext(path, "guns/fire/"))
		return "gunshot"
	if (findtext(path, "explosion") || findtext(path, "explo_") || findtext(path, "artillery") || findtext(path, "new_exp_"))
		return "explosion"
	if (findtext(path, "sound/animals/"))
		return "animal"
	if (findtext(path, "sound/voice/") || findtext(path, "sound/effects/emotes/") || findtext(path, "sound/vo/"))
		return "voice"
	return null

/proc/agent_sound_label(requested, soundin)
	var/text = istext(requested) ? requested : "[soundin]"
	var/slash = findlasttext(text, "/")
	if (slash)
		text = copytext(text, slash + 1)
	var/dot = findlasttext(text, ".")
	if (dot > 1)
		text = copytext(text, 1, dot)
	return copytext(text, 1, 65)

// Called by playsound() after it reached the clients in range.
/proc/agent_hear_sound(turf/source, requested, soundin, vol, extrarange, list/excluded)
	if (!source || !vol || vol <= 0)
		return
	var/label = agent_sound_label(requested, soundin)
	var/kind = agent_sound_kind(requested, soundin)
	for (var/mob/living/M in agent_characters)
		if (M.ear_deaf > 0 || (excluded && excluded.Find(M)))
			continue
		var/turf/T = get_turf(M)
		if (!T || T.z != source.z || get_dist(T, source) > (7 * 3) + extrarange)
			continue
		var/datum/agent_character/C = agent_characters[M]
		C.hear_sound(source, label, vol, kind)

// Queue step "until": stop repeating once this holds.
/datum/agent_character/proc/until_met(list/step)
	var/list/until = step["until"]
	if (!islist(until))
		return FALSE
	if (istext(until["message"]))
		for (var/list/message in messages)
			if (message["id"] > step["message_from"] && findtext(message["text"], until["message"]))
				return TRUE
	var/obj/item/held = body.get_active_hand()
	if (istext(until["holding"]) && held && findtext(held.name, until["holding"]))
		return TRUE
	if (isnum(until["amount"]) && istype(held, /obj/item/stack))
		var/obj/item/stack/S = held
		if (S.amount >= until["amount"])
			return TRUE
	return FALSE

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
		// "stay": keep the job's kit but start at the target rather than the job's spawn point.
		if (job_title && req["stay"] && get_turf(M) != T)
			M.forceMove(T)
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
		if (C.awaiting_driver)
			row["waiting"] = TRUE
			row["goal"] = C.requested_goal
		out += list(row)
	last_watch[A.name] = world.time
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
	var/obj/structure/vehicle/riding = agent_vehicle_of(M)
	if (riding)
		out["vehicle"] = agent_vehicle_row(riding, M)
		out["can_steer"] = (riding.driver == M && M.stat == CONSCIOUS && !agent_vehicle_stalled(riding)) ? TRUE : FALSE
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
		// Stack counts and container contents for what she holds and carries (recipes and tanning need amounts).
		var/list/details = list()
		for (var/obj/item/I in list(H.l_hand, H.r_hand, H.l_store, H.r_store))
			details += agent_item_detail(I)
		for (var/obj/item/weapon/storage/S in H.get_equipped_items())
			for (var/obj/item/I in S.contents)
				if (details.len < 24)
					details += agent_item_detail(I)
		out["items"] = details
		if (H.original_job_title)
			out["job"] = H.original_job_title
		// Injuries a player would see on the health doll: bleeding first, so the agent can stop blood loss.
		var/list/wounds = agent_wound_rows(H)
		out["wounds"] = wounds
		// A serious illness kills within about 20 minutes unless a medicine course (herbs, antibiotics) runs.
		if (H.disease && H.disease_type && H.disease_type != "none")
			var/list/illness = list("type" = H.disease_type, "severe" = H.is_severe_disease() ? TRUE : FALSE, "progression" = H.disease_progression, "course" = round(H.disease_course))
			if (H.is_severe_disease())
				illness["stage"] = H.disease_progression >= 900 ? "critical" : (H.disease_progression >= 180 ? "worsening" : "early")
				illness["treated"] = H.disease_course > 0 ? TRUE : FALSE
			if (H.ingested)
				illness["remedy"] = round(H.ingested.get_reagent_amount("herbal_remedy"), 0.1)
			out["illness"] = illness
		// Verbs a player has in the right-click menu and verb panels (lie down, give, point, an item's own verbs).
		out["verbs"] = agent_verb_names(H)
		out["item_verbs"] = agent_item_verbs(H)
		out["blood"] = round(H.vessel ? H.vessel.get_reagent_amount("blood") : 0)
	return out

// Injured limbs of a human, as an agent sees them (zone is the zone selector's name,
// limb_name; organ_tag is "limb" for every external organ): on itself from the health doll, on
// someone next to it from what examining them shows (bleeding, breaks, bandages).
/proc/agent_wound_rows(mob/living/human/H)
	var/list/wounds = list()
	for (var/obj/item/organ/external/E in H.organs)
		var/bleeding = (E.status & ORGAN_BLEEDING) ? TRUE : FALSE
		var/broken = (E.status & ORGAN_BROKEN) ? TRUE : FALSE
		var/artery = (E.status & ORGAN_ARTERY_CUT) ? TRUE : FALSE
		if (!bleeding && !broken && !artery && !E.tourniquet && E.get_damage() < 5)
			continue
		var/list/row = list("zone" = E.limb_name || E.organ_tag, "name" = E.name, "damage" = round(E.get_damage()), "bleeding" = bleeding, "bandaged" = E.is_bandaged() ? TRUE : FALSE, "broken" = broken)
		// Field-care state: a cut artery wants a bandage tied as a tourniquet
		// (the first bandage click does it), a break wants a splint.
		if (artery)
			row["artery_cut"] = TRUE
		if (E.tourniquet)
			row["tourniquet"] = TRUE
		if (E.status & ORGAN_SPLINTED)
			row["splinted"] = TRUE
		if (E.has_infected_wound() || E.germ_level >= INFECTION_LEVEL_ONE)
			row["infected"] = TRUE
		wounds += list(row)
	return wounds

/datum/agent_control/proc/act_character_observe(datum/agent_identity/A, list/req)
	var/datum/agent_character/C = character_arg(A, req)
	var/mob/living/M = C.body
	var/radius = clamp(round(text2num("[req["radius"]]") || 5), 1, 7)
	var/since = text2num("[req["since"]]") || 0
	var/list/signatures = list()
	C.awaiting_driver = FALSE // an autopilot is driving it now
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
				// Someone hurt nearby: what a player sees on them, so the agent can offer first aid.
				if (ishuman(other) && other.stat != DEAD)
					var/list/hurt = agent_wound_rows(other)
					if (hurt.len)
						row["wounds"] = hurt
			if (istype(AM, /obj/item/stack))
				var/obj/item/stack/ST = AM
				row["amount"] = ST.amount
			if (istype(AM, /obj/structure/converter/tanning))
				// What the rack holds: wet hides are still drying, dry hides are ready to take off by hand.
				var/obj/item/stack/material/rack_hide = locate(/obj/item/stack/material) in AM.contents
				row["holds"] = rack_hide ? "[rack_hide.name] x[rack_hide.amount]" : "nothing"
			if (istype(AM, /obj/structure/vehicle))
				// Boats: seats, cargo, fuel and engine, so one can be boarded, supplied or refuelled.
				var/list/boat_row = agent_vehicle_row(AM, M)
				for (var/key in boat_row)
					if (!(key in list("ref", "name", "type", "x", "y", "z")))
						row[key] = boat_row[key]
			if (istype(AM, /obj/structure/oven))
				// Cooking and stone-boiling need a lit fire with fuel left.
				var/obj/structure/oven/O = AM
				row["lit"] = O.on ? TRUE : FALSE
				row["fuel"] = round(O.fuel, 0.1)
			if (istype(AM, /obj/structure/sink))
				// Puddles and dirty wells carry cholera; a clean well does not.
				var/obj/structure/sink/SK = AM
				row["sickness"] = (istype(SK, /obj/structure/sink/puddle) || SK.dirty) ? 1 : 0
			if (!ismob(AM) && get_dist(M, AM) <= 1)
				var/list/near_verbs = agent_verb_names(AM, 8)
				if (near_verbs.len)
					row["verbs"] = near_verbs
			if (istype(AM, /obj/roof))
				var/obj/roof/R = AM
				row["supported"] = R.is_supported() ? TRUE : FALSE // the same rule collapse_check uses
			// Change lists compare what is there, not where it is relative to the character.
			var/list/signature = row.Copy()
			signature -= "dx"
			signature -= "dy"
			signatures[row["ref"]] = "[json_encode(signature)]@[T.x],[T.y],[T.z]"
			nearby += list(row)
	var/list/surroundings = list()
	var/obj/structure/vehicle/steering = null
	var/lifejacket = FALSE
	if (ishuman(M))
		var/mob/living/human/HM = M
		steering = HM.driver ? HM.driver_vehicle : null
		lifejacket = istype(HM.wear_suit, /obj/item/clothing/suit/lifejacket)
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
			var/deep = agent_deep_water(T)
			if (steering)
				// Driving: open water is the way on, and land stops the boat.
				blocked = blocked || !(istype(T, /turf/floor/beach/water) || istype(T, /turf/floor/trench/flooded))
			else if (deep && !lifejacket)
				blocked = TRUE // deep water stops a walker; it needs a boat
			var/list/side = list("turf" = T.name, "type" = "[T.type]", "blocked" = blocked ? TRUE : FALSE)
			if (deep)
				side["deep_water"] = TRUE
			surroundings[dir2text(d)] = side
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
	C.queue_guard = md5("[world.realtime]-[world.time]-[rand(1, 1000000000)]-[agent_ref(C)]-[C.seen_rev]")
	C.queue_guard_at = world.time
	C.queue_guard_agent = A.name
	var/list/out = list("self" = character_state(C), "here" = here_row, "surroundings" = surroundings, "nearby" = nearby, "terrain" = terrain, "messages" = heard, "last_message" = C.message_serial, "queue" = C.queue_state(queue_since))
	// since_rev: only nearby rows that appeared or changed since that observe, and the refs that left.
	var/since_rev = text2num("[req["since_rev"]]")
	if (isnum(since_rev) && since_rev > 0 && since_rev == C.seen_rev && islist(C.seen))
		var/list/changed = list()
		for (var/list/row in nearby)
			if (C.seen[row["ref"]] != signatures[row["ref"]])
				changed += list(row)
		var/list/gone = list()
		for (var/ref in C.seen)
			if (!(ref in signatures))
				gone += ref
		out["nearby"] = changed
		out["nearby_removed"] = gone
		out["nearby_unchanged"] = nearby.len - changed.len
		out["changes_since"] = since_rev
	C.seen = signatures
	out["rev"] = ++C.seen_rev
	var/prompt_since = text2num("[req["prompt_since"]]") || 0
	var/list/prompts = list()
	for (var/list/prompt in C.prompts)
		if (prompt["id"] > prompt_since)
			prompts += list(prompt)
	out["prompts"] = prompts
	out["last_prompt"] = C.prompt_serial
	var/sound_since = text2num("[req["sound_since"]]") || 0
	var/footsteps = req["footsteps"] == TRUE || req["footsteps"] == 1
	var/list/heard_sounds = list()
	for (var/list/sound_row in C.sounds)
		if (sound_row["id"] > sound_since && (footsteps || !sound_row["footsteps"]))
			heard_sounds += list(sound_row)
	out["sounds"] = heard_sounds
	out["last_sound"] = C.sound_serial
	// Menu windows the character was shown (docs/agent-control.md#windows).
	out["windows"] = C.window_rows(text2num("[req["window_since"]]") || 0)
	out["last_window"] = C.window_serial
	return out

// Actions a character can take, directly or from its queue.
/proc/agent_character_actions()
	return list("move", "face", "say", "emote", "click", "use", "craft", "equip", "take", "examine", "drop", "swap_hand", "intent", "resist", "board", "disembark", "drag", "verb", "throw", "ooc", "bug_report", "topic", "close_window")

// Ticks until the character may take this action: the agent pacing plus the
// mob's own click cooldown (next_move/next_click) and a speech spacing.
/datum/agent_character/proc/wait_for(action)
	var/ready = world.time
	if (action in list("move", "click", "use", "craft", "equip", "take", "drop", "board", "disembark", "drag", "verb", "throw", "topic"))
		ready = max(ready, next_action)
		// Timed work (do_after) in progress: acting now would cancel it.
		if (!body.may_do_after)
			ready = max(ready, world.time + 2)
	if (action in list("click", "use", "craft", "verb", "throw", "topic"))
		ready = max(ready, body.next_move, body.next_click + 1)
	if (action in list("say", "emote", "ooc", "bug_report"))
		ready = max(ready, next_speech)
	return max(0, ready - world.time)

/datum/agent_control/proc/act_character_act(datum/agent_identity/A, list/req)
	var/datum/agent_character/C = character_arg(A, req)
	var/action = lowertext("[req["do"]]")
	var/wait = (action in agent_character_actions()) ? C.wait_for(action) : 0
	if (wait)
		agent_fail("cooldown", "wait [wait] ticks")
	C.queue_guard = null // manual actions invalidate an earlier autopilot observation
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
	if (!(action in agent_character_actions()))
		agent_fail("bad_args", "unknown character action")
	// expect_name: refuse when the ref now names something else (a recycled ref or a swapped object).
	if (istext(req["expect_name"]) && length(req["expect_name"]) && !isnull(req["target"]))
		var/atom/expected = agent_resolve_target(req["target"])
		var/actual = isatom(expected) ? expected.name : "[expected]"
		if (!findtext(actual, req["expect_name"]))
			agent_fail("target_changed", "the target is now [actual], not [req["expect_name"]]")
	// A step may carry the answer to a prompt it raises (a shovel asks what to dig).
	C.pending_choice = req["choose"] ? copytext(agent_text_arg(req, "choose", 64), 1, 65) : null
	C.pending_choice_until = world.time + AGENT_CHOICE_WINDOW
	switch (action)
		if ("move")
			var/d = agent_dir(req["dir"])
			// Driving a boat: the move steers it (docs/agent-control.md#boats).
			if (ishuman(M))
				var/mob/living/human/driving = M
				if (driving.driver && driving.driver_vehicle)
					return agent_drive_step(A, C, driving.driver_vehicle, d)
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
		if ("ooc")
			// Reaches every player, the other regions and Discord, so it needs its own scope.
			if (!A.has_scope("ooc"))
				agent_fail("forbidden", "Requires scope ooc.")
			var/message = copytext(agent_text_arg(req, "text", 256), 1, 257)
			if (!agent_ooc_say("[M.real_name] (AI)", "agent-[A.name]", message))
				agent_fail("ooc_closed", "OOC is muted or the line was empty")
			C.next_speech = world.time + AGENT_CHARACTER_SPEECH_DELAY
			detail = message
		if ("bug_report")
			// Goes into the in-game bug report queue (code/modules/bug_reports) as
			// "<character> (AI)". An admin still approves it before anything reaches GitHub.
			if (!A.has_scope("bug_report"))
				agent_fail("forbidden", "Requires scope bug_report.")
			var/key = ckey("agent-[A.name]")
			var/why = bug_reports.refusal_for(key)
			if (why)
				agent_fail("bug_report_refused", why)
			var/datum/bug_report/R = bug_reports.add_from(key, "[M.real_name] (AI)", "[M.real_name] (AI, agent [A.name])", M, null,
				agent_text_arg(req, "title", 80), agent_text_arg(req, "what", 2000), "[req["steps"]]", "[req["expected"]]")
			C.next_speech = world.time + AGENT_CHARACTER_SPEECH_DELAY
			game_log("AGENT", "[A.name] filed bug report #[R.id] as [M] ([agent_ref(M)]): [R.title]")
			return list("report" = R.id, "title" = R.title, "self" = character_state(C))
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
		if ("board")
			detail = agent_board(C, req, from_queue)
		if ("disembark")
			detail = agent_disembark(C, from_queue)
		if ("drag")
			detail = agent_drag(C, req, from_queue)
		if ("verb")
			detail = agent_run_verb(C, req, from_queue)
		if ("throw")
			detail = agent_throw(C, req, from_queue)
		if ("topic")
			detail = agent_window_topic(C, req, from_queue)
		if ("close_window")
			detail = agent_window_close(C, req)
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
	var/clear = req["clear"] == TRUE || req["clear"] == 1
	var/cancel_id = req["cancel_request_id"]
	if (!isnull(cancel_id) && (!clear || !istext(cancel_id) || !length(cancel_id) || length(cancel_id) > 64))
		agent_fail("bad_args", "cancel_request_id requires clear and a request id")
	if (!isnull(steps) && !islist(steps))
		agent_fail("bad_args", "actions must be a list")
	if (!isnull(req["clear"]) && req["clear"] != TRUE && req["clear"] != FALSE)
		agent_fail("bad_args", "clear must be a boolean")
	if (!isnull(req["stop_on_failure"]) && req["stop_on_failure"] != TRUE && req["stop_on_failure"] != FALSE)
		agent_fail("bad_args", "stop_on_failure must be a boolean")
	// Guarded autopilot calls consume one recent observation, never a replay.
	if (!isnull(req["guard"]))
		if (!istext(req["_request_id"]) || !length(req["_request_id"]) || length(req["_request_id"]) > 64)
			agent_fail("bad_args", "guarded actions need a request_id")
		if (!istext(req["guard"]) || !C.queue_guard || req["guard"] != C.queue_guard || C.queue_guard_agent != A.name || world.time < C.queue_guard_at || world.time - C.queue_guard_at > AGENT_QUEUE_GUARD_TTL)
			agent_fail("stale_action", "Observe again; this queue guard is stale or already consumed.")
		if (req["_request_id"] in C.queue_request_ids)
			agent_fail("duplicate_action", "This request id was already accepted.")
		if (clear && steps && steps.len)
			agent_fail("bad_args", "guarded cancellation cannot include a replacement plan")
		if (!clear && (C.queue_running || C.queue.len || !C.body.may_do_after))
			agent_fail("action_pending", "Wait for the current action to finish before submitting another.")
	var/list/checked = list()
	if (steps && steps.len)
		if (steps.len > AGENT_CHARACTER_QUEUE_BATCH)
			agent_fail("bad_args", "at most [AGENT_CHARACTER_QUEUE_BATCH] actions per request")
		if ((!clear ? C.queue.len : 0) + steps.len > AGENT_CHARACTER_QUEUE_MAX)
			agent_fail("queue_full", "the queue holds at most [AGENT_CHARACTER_QUEUE_MAX] steps; [C.queue.len] are pending")
		for (var/list/step in steps)
			checked += list(check_step(step))
		if (checked.len != steps.len)
			agent_fail("bad_args", "each action must be an object")
	// No mutations, including clear, take place until the whole replacement validates.
	C.queue_guard = null
	if (!isnull(req["guard"]))
		C.queue_request_ids += req["_request_id"]
		if (C.queue_request_ids.len > AGENT_CHARACTER_QUEUE_MAX)
			C.queue_request_ids.Cut(1, 2)
	if (clear)
		log_admin("AGENT [A.name]: character_queue cleared [C.queue.len] steps for [C.body] ([agent_ref(C.body)])")
		C.cancel_queue("cancelled: queue cleared", cancel_id)
	var/list/added = list()
	var/stop_on_failure = req["stop_on_failure"] != FALSE && req["stop_on_failure"] != 0
	for (var/list/step in checked)
		step["id"] = ++C.queue_serial
		step["agent"] = A.name
		step["identity"] = A // any config replacement invalidates accepted old authority
		step["request_id"] = req["_request_id"]
		step["stop_on_failure"] = stop_on_failure
		C.queue += list(step)
		added += step["id"]
	if (added.len)
		log_admin("AGENT [A.name]: character_queue [added.len] steps for [C.body] ([agent_ref(C.body)])")
		if (!C.queue_running)
			spawn(0)
				run_queue(C)
	return list("state" = "accepted", "request_id" = req["_request_id"], "queued" = added, "queue" = C.queue_state())

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
	if (action in list("say", "emote", "ooc"))
		agent_text_arg(step, "text", 256)
	if (action == "bug_report")
		agent_text_arg(step, "title", 80)
		agent_text_arg(step, "what", 2000)
	if (action in list("click", "examine", "board", "drag", "throw"))
		agent_resolve_target(step["target"])
	if (action == "verb")
		agent_text_arg(step, "name", 64)
		if (!isnull(step["target"]))
			agent_resolve_target(step["target"])
		if (!isnull(step["onto"]))
			agent_resolve_target(step["onto"])
	if (action == "drag")
		agent_resolve_target(step["onto"])
	if (action == "craft")
		agent_text_arg(step, "recipe", 128)
	if (action == "take")
		agent_text_arg(step, "item", 64)
	if (action in list("topic", "close_window"))
		agent_text_arg(step, "window", 64)
	if (action == "topic" && isnull(step["link"]) && isnull(step["label"]))
		agent_fail("bad_args", "topic needs link (a number) or label")
	if (action == "intent" && !(step["intent"] in list(I_HELP, I_DISARM, I_GRAB, I_HARM)))
		agent_fail("bad_args", "intent must be help, disarm, grab or harm")
	if (!isnull(step["choose"]))
		agent_text_arg(step, "choose", 64)
	if (!isnull(step["expect_name"]))
		agent_text_arg(step, "expect_name", 64)
	if (!isnull(step["repeat"]))
		var/repeat = text2num("[step["repeat"]]")
		if (!isnum(repeat) || repeat < 1 || repeat > AGENT_CHARACTER_REPEAT_MAX)
			agent_fail("bad_args", "repeat must be 1-[AGENT_CHARACTER_REPEAT_MAX]")
		out["repeat"] = round(repeat)
	if (!isnull(step["until"]))
		var/list/until = step["until"]
		if (!islist(until) || !until.len)
			agent_fail("bad_args", "until must be an object with message, holding or amount")
		var/list/kept_until = list()
		for (var/key in until)
			if (key in list("message", "holding"))
				kept_until[key] = copytext(agent_text_arg(until, key, 64), 1, 65)
			else if (key == "amount")
				var/amount = text2num("[until[key]]")
				if (!isnum(amount) || amount < 1)
					agent_fail("bad_args", "until amount must be a positive number")
				kept_until[key] = round(amount)
			else
				agent_fail("bad_args", "until takes message, holding or amount")
		out["until"] = kept_until
	for (var/key in list("dir", "text", "target", "onto", "modifier", "intent", "recipe", "amount", "item", "choose", "zone", "name", "expect_name", "window", "link", "label"))
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
	return list("pending" = pending, "running" = queue_running ? TRUE : FALSE, "results" = done, "guard" = queue_guard)

/datum/agent_character/proc/record(list/step, ok, detail)
	var/list/receipt = list("state" = "completed", "request_id" = step["request_id"], "id" = step["id"], "do" = step["do"], "ok" = ok ? TRUE : FALSE, "detail" = detail, "time" = world.time)
	// A cancelled suffix may finish before the running step returns. Keep id order.
	var/at = queue_results.len + 1
	for (var/i = 1, i <= queue_results.len, i++)
		var/list/previous = queue_results[i]
		if (previous["id"] >= step["id"])
			at = i
			break
	queue_results.Insert(at, list(receipt))
	if (queue_results.len > AGENT_CHARACTER_QUEUE_MAX)
		queue_results.Cut(1, 2)

// Pending steps receive terminal receipts. A running game proc is not rolled back;
// its result is cancelled after it returns, and it cannot repeat or revive a plan.
/datum/agent_character/proc/cancel_queue(detail, request_id)
	if (!request_id || (queue_active && queue_active["request_id"] == request_id))
		queue_generation++
		pending_choice = null
		pending_choice_until = 0
	queue_guard = null
	var/list/kept = list()
	for (var/list/rest in queue)
		if (!request_id || rest["request_id"] == request_id)
			record(rest, FALSE, detail)
		else
			kept += list(rest)
	queue = kept

/datum/agent_control/proc/run_queue(datum/agent_character/C)
	if (C.queue_running)
		return
	C.queue_running = TRUE
	while (C.queue.len)
		var/mob/living/M = C.body
		if (QDELETED(M) || agent_characters[M] != C)
			C.cancel_queue("cancelled: character released or gone")
			break
		var/list/step = C.queue[1]
		C.queue_active = step
		var/generation = C.queue_generation
		var/action = step["do"]
		reload()
		var/datum/agent_identity/A = agents[step["agent"]]
		if (!A || A != step["identity"] || !A.has_scope("characters") || !C.can_drive(A))
			C.cancel_queue("forbidden: the agent no longer controls this character")
			break
		if (action == "wait")
			C.queue.Cut(1, 2)
			sleep(step["ticks"])
			reload()
			A = agents[step["agent"]]
			if (!A || A != step["identity"] || !A.has_scope("characters") || !C.can_drive(A))
				C.cancel_queue("forbidden: the agent no longer controls this character")
			if (generation != C.queue_generation || agent_characters[M] != C)
				C.record(step, FALSE, "cancelled: wait interrupted")
			else
				C.record(step, TRUE, "waited [step["ticks"]] ticks")
			continue
		var/wait = C.wait_for(action)
		if (wait)
			sleep(wait)
			continue
		C.queue.Cut(1, 2)
		try
			if (isnull(step["message_from"]))
				step["message_from"] = C.message_serial
			var/list/result = perform_step(A, C, step, TRUE)
			if (generation != C.queue_generation || agent_characters[M] != C)
				C.record(step, FALSE, "cancelled: running action returned; effects may already have happened")
				continue
			var/count = (step["count"] || 0) + 1
			step["count"] = count
			var/repeat = step["repeat"] || 1
			var/stopped = C.until_met(step)
			if (result["moved"] == FALSE)
				C.record(step, TRUE, repeat > 1 ? "blocked after [count]" : "blocked")
				if (step["stop_on_failure"])
					for (var/list/rest in C.queue)
						C.record(rest, FALSE, "skipped: an earlier move was blocked")
					C.queue.Cut()
					break
			else if (count < repeat && !stopped)
				C.queue.Insert(1, list(step)) // repeats run when the cooldown allows, one per tick
			else
				C.record(step, TRUE, repeat > 1 || step["until"] ? "done x[count][stopped ? " (until met)" : ""]" : "done")
		catch(var/exception/E)
			var/detail = E.name == "agent_control_error" ? E.desc : "runtime_error:[E.name] ([E.file]:[E.line])"
			C.record(step, FALSE, detail)
			if (step["stop_on_failure"] && generation == C.queue_generation)
				for (var/list/rest in C.queue)
					C.record(rest, FALSE, "skipped: an earlier step failed")
				C.queue.Cut()
				break
		// At most one queued step per tick for each character.
		sleep(1)
	C.queue_active = null
	C.queue_running = FALSE

/datum/agent_control/proc/act_character_release(datum/agent_identity/A, list/req)
	var/datum/agent_character/C = character_arg(A, req)
	var/mob/living/M = C.body
	agent_characters -= M
	C.cancel_queue("cancelled: character released")
	C.queue.Cut() // explicit empty queue before returning control
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
		C.cancel_queue("cancelled: player took back control")
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
	admin_verbs_fun |= /client/proc/spawn_ai_character
	return TRUE

// ---------------------------------------------------------------------------
// Admin verb: spawn a character for an AI agent (such as Ada) to play. The
// character is spawned exactly as the agent's own character_spawn would, then
// waits until an autopilot started with --watch for that agent picks it up.

/client/proc/spawn_ai_character()
	set category = "Fun"
	set name = "Spawn AI Character"
	set desc = "Spawn a character for a server AI agent, such as Ada, to play."
	if (!check_rights(R_FUN))
		return
	agent_control.reload()
	var/list/choices = list()
	for (var/agent_name in agent_control.agents)
		var/datum/agent_identity/A = agent_control.agents[agent_name]
		if (A.has_scope("characters"))
			choices += agent_name
	if (!choices.len)
		to_chat(src, SPAN_WARNING("No agent in config/agent-control.txt has the characters scope."))
		return
	var/agent_name = choices.len == 1 ? choices[1] : input(src, "Which agent plays the character?", "AI character") as null|anything in choices
	if (!agent_name)
		return
	var/name = input(src, "Character name", "AI character", "Ada") as null|text
	if (isnull(name))
		return
	var/goal = input(src, "What should the character try to do?", "AI character", "Survive, explore, gather food and be friendly to other players.") as null|text
	if (isnull(goal))
		return
	var/turf/T = get_turf(mob)
	if (!T)
		to_chat(src, SPAN_WARNING("You need to be on the map to place a character."))
		return
	var/list/req = list("target" = "turf:[T.x],[T.y],[T.z]", "name" = name)
	var/list/jobs = agent_map_jobs()
	if (jobs.len)
		var/job = ("Nomad" in jobs) ? "Nomad" : input(src, "Join as which job?", "AI character") as null|anything in jobs
		if (!job)
			return
		req["job"] = job
		var/where = input(src, "Where should [name] start?", "AI character") as null|anything in list("My location", "The job's spawn point")
		if (!where)
			return
		if (where == "My location")
			req["stay"] = TRUE
	var/datum/agent_identity/A = agent_control.agents[agent_name]
	if (!A)
		return
	var/list/state
	try
		state = agent_control.act_character_spawn(A, req)
	catch(var/exception/E)
		to_chat(src, SPAN_WARNING("The character could not be spawned: [istype(E) && E.name == "agent_control_error" ? E.desc : "[E]"]"))
		return
	var/mob/living/M = locate(state["ref"])
	var/datum/agent_character/C = agent_characters[M]
	if (!C)
		return
	C.awaiting_driver = TRUE
	// Plain text: the autopilot hands it to the model as written. Encode it only for the log.
	C.requested_goal = copytext(trim(replacetext(replacetext(replacetext(goal, ascii2text(13), " "), "\n", " "), "\t", " ")), 1, 257)
	log_admin("[key_name(src)] spawned AI character [M] ([agent_ref(M)]) for agent [agent_name]: [html_encode(C.requested_goal)]")
	message_admins("[key_name_admin(src)] spawned AI character [M] for agent [agent_name].")
	var/last = agent_control.last_watch[agent_name]
	if (isnull(last) || world.time - last > AGENT_WATCH_WINDOW)
		to_chat(src, SPAN_WARNING("[M] is in play, but no autopilot is watching agent [agent_name], so [M] will stand still until the host runs autopilot.py --watch for that agent (docs/agent-control.md)."))
	else
		to_chat(src, SPAN_NOTICE("[M] is in play. The autopilot watching agent [agent_name] will take over within a few seconds."))

#undef AGENT_CHARACTER_MESSAGES
#undef AGENT_WATCH_WINDOW

/proc/agent_item_detail(obj/item/I)
	if (!istype(I))
		return list()
	var/list/row = list("name" = I.name)
	if (istype(I, /obj/item/stack))
		var/obj/item/stack/ST = I
		row["amount"] = ST.amount
	if (I.reagents && I.is_open_container())
		var/list/liquids = list()
		for (var/datum/reagent/R in I.reagents.reagent_list)
			liquids[R.id] = round(R.volume, 0.1)
		row["liquids"] = liquids
		row["volume"] = I.reagents.maximum_volume
	return list(row)
