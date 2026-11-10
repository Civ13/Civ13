// HUD toggles for agent characters (docs/agent-control.md#stance).
//
// Players set these with HUD buttons an agent character has no screen for:
// movement mode (run, walk, sneak, crawl), dodge or parry, combat tactic, the
// middle-click attack (kick, jump, bite), fixed facing and gun aim mode. The
// stance action sets them the way the matching button does, and
// character_state reports them.

/proc/agent_stance_row(mob/living/M)
	var/list/out = list("move" = M.m_intent, "defense" = M.defense_intent, "secondary" = M.middle_click_intent, "face_lock" = M.facing_dir ? TRUE : FALSE)
	out["tactic"] = M.tactic
	if (M.aiming)
		out["aim"] = M.aiming.active ? TRUE : FALSE
	return out

// Movement mode as /obj/screen/mov_intent cycles it: proning lies the
// character down, any other mode stands it up; legcuffs forbid running.
/proc/agent_set_move_mode(mob/living/human/H, mode)
	if (H.legcuffed && mode == "run")
		agent_fail("cannot_act", "legcuffed characters cannot run")
	H.m_intent = mode
	if (mode == "proning")
		H.prone = TRUE
		H.facing_dir = H.dir
		H.dir = prone_facing_dir(H.dir)
	else
		if (mode == "stealth" && H.facing_dir)
			H.set_face_dir()
		H.prone = FALSE
	H.update_posture_transform()
	if (H.HUDneed.Find("m_intent"))
		var/obj/screen/intent/I = H.HUDneed["m_intent"]
		I.update_icon()

/datum/agent_control/proc/agent_stance(datum/agent_character/C, list/req)
	var/mob/living/M = C.body
	if (M.stat == DEAD)
		agent_fail("cannot_act", "the character is dead")
	var/list/done = list()
	if (!isnull(req["move"]))
		if (!ishuman(M))
			agent_fail("bad_type", "only humans change movement mode")
		var/list/modes = list("run" = "run", "walk" = "walk", "sneak" = "stealth", "stealth" = "stealth", "crawl" = "proning", "prone" = "proning")
		var/mode = modes[lowertext("[req["move"]]")]
		if (!mode)
			agent_fail("bad_args", "move must be run, walk, sneak or crawl")
		agent_set_move_mode(M, mode)
		done += "move [mode]"
	if (!isnull(req["defense"]))
		var/defense = lowertext("[req["defense"]]")
		if (!(defense in list(I_DODGE, I_PARRY)))
			agent_fail("bad_args", "defense must be dodge or parry")
		M.defense_intent = defense
		done += "defense [defense]"
	if (!isnull(req["tactic"]))
		var/tactic = lowertext("[req["tactic"]]")
		if (!(tactic in list("charge", "aim", "rush", "defend")))
			agent_fail("bad_args", "tactic must be charge, aim, rush or defend")
		M.tactic = tactic
		done += "tactic [tactic]"
	if (!isnull(req["secondary"]))
		var/secondary = lowertext("[req["secondary"]]")
		if (!(secondary in list("kick", "jump", "bite")))
			agent_fail("bad_args", "secondary must be kick, jump or bite")
		M.middle_click_intent = secondary
		done += "secondary [secondary]"
	if (!isnull(req["face_lock"]))
		var/lock = req["face_lock"] == TRUE || req["face_lock"] == 1
		if (lock != (M.facing_dir ? TRUE : FALSE))
			M.set_face_dir()
		done += "face_lock [lock ? "on" : "off"]"
	if (!isnull(req["aim"]))
		var/aim = req["aim"] == TRUE || req["aim"] == 1
		if (!M.aiming)
			M.aiming = new(M)
		M.aiming.toggle_active(aim)
		done += "aim [aim ? "on" : "off"]"
	if (!done.len)
		agent_fail("bad_args", "stance takes move, defense, tactic, secondary, face_lock or aim")
	return jointext(done, ", ")

// Equip the held item into a named slot, as dragging it onto that inventory slot does.
/proc/agent_equip_slot(mob/living/human/H, obj/item/I, slot_name)
	var/slot = region_travel_slots[lowertext("[slot_name]")]
	if (isnull(slot) || slot == slot_l_hand || slot == slot_r_hand)
		agent_fail("bad_args", "slot must be one of [jointext(agent_equip_slot_names(), ", ")]")
	if (!H.equip_to_slot_if_possible(I, slot, FALSE, TRUE))
		agent_fail("no_slot", "[I] does not fit the [slot_name] slot right now")

/proc/agent_equip_slot_names()
	. = list()
	for (var/name in region_travel_slots)
		if (!(name in list("l_hand", "r_hand")))
			. += name

// What a storage container next to the character holds, as a player sees
// after opening it. Items inside can then be clicked to take them.
/proc/agent_container_contents(obj/item/weapon/storage/S, limit = 12)
	. = list()
	for (var/obj/item/I in S.contents)
		. += list(list("ref" = agent_ref(I), "name" = I.name))
		if (length(.) >= limit)
			break

// A click may reach an item inside storage the character holds, wears or
// stands next to, as a player clicks it in the opened storage window.
/proc/agent_click_reaches_container(mob/living/M, atom/target)
	var/obj/item/weapon/storage/S = istype(target, /obj/item) ? target.loc : null
	if (!istype(S))
		return FALSE
	var/atom/holder = S.loc
	for (var/depth in 1 to 3)
		if (holder == M)
			return TRUE
		if (!holder || isturf(holder))
			break
		holder = holder.loc
	return isturf(S.loc) && get_dist(M, S) <= 1
