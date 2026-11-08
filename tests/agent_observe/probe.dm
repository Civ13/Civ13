/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 30
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/observe_failures = 0
var/observe_checks = 0
var/observe_runtime_error = FALSE
/obj/map_metadata/observe_probe/New()
	return
/proc/observe_check(condition, label)
	observe_checks++
	if (!condition)
		observe_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	observe_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		movementMachine = new
		map = new /obj/map_metadata/observe_probe
		if (!all_species.len)
			makeDatumRefLists()
		var/area/A = get_area(locate(1, 1, 1))
		A.location = AREA_OUTSIDE
		A.climate = "temperate"
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		observe_change_checks()
		observe_prompt_checks()
		observe_sound_checks()
		observe_queue_checks()
		observe_view_checks()
	catch(var/exception/e)
		observe_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("checks" = observe_checks, "failures" = observe_failures, "runtime_error" = observe_runtime_error)), "result.json")
	del(world)

/proc/observe_character(x, y, name)
	var/mob/living/human/H = new(locate(x, y, 1))
	H.name = name
	var/datum/agent_character/C = new
	C.body = H
	C.owner_agent = "probe"
	agent_characters[H] = C
	return C

/proc/observe_identity()
	var/static/datum/agent_identity/A
	if (!A)
		A = new
		A.name = "probe"
		A.scopes = list("characters")
		agent_control.reload() // no config file: queued steps look their agent up here
		agent_control.agents[A.name] = A
	return A

/proc/observe_call(proc_name, datum/agent_character/C, list/req)
	req["character"] = agent_ref(C.body)
	try
		switch (proc_name)
			if ("observe")
				return agent_control.act_character_observe(observe_identity(), req)
			if ("queue")
				return agent_control.act_character_queue(observe_identity(), req)
			if ("step")
				return agent_control.perform_step(observe_identity(), C, req, TRUE)
			if ("view")
				return agent_control.act_character_view(observe_identity(), req)
	catch(var/exception/e)
		return "[e.desc || e.name]"

/proc/observe_refs(list/rows)
	var/list/out = list()
	for (var/list/row in rows)
		out += row["ref"]
	return out

/proc/observe_change_checks()
	var/datum/agent_character/C = observe_character(10, 10, "Watcher")
	var/obj/item/weapon/material/spear/spear = new(locate(12, 10, 1))
	var/list/first = observe_call("observe", C, list())
	observe_check(islist(first) && first["rev"] && !("changes_since" in first), "a first observe is a full list with a rev")
	observe_check(islist(first) && (agent_ref(spear) in observe_refs(first["nearby"])), "the spear is listed")
	var/list/same = observe_call("observe", C, list("since_rev" = first["rev"]))
	observe_check(islist(same) && same["changes_since"] == first["rev"] && !length(same["nearby"]) && !length(same["nearby_removed"]), "nothing changed: an empty change list")
	observe_check(islist(same) && same["nearby_unchanged"] >= 1, "unchanged rows are counted ([islist(same) ? same["nearby_unchanged"] : same])")
	observe_call("step", C, list("do" = "move", "dir" = "north"))
	var/list/moved = observe_call("observe", C, list("since_rev" = same["rev"]))
	observe_check(islist(moved) && !length(moved["nearby"]), "walking does not mark everything changed ([islist(moved) ? json_encode(moved["nearby"]) : moved])")
	var/obj/item/weapon/material/spear/second = new(locate(9, 11, 1))
	qdel(spear)
	var/list/changed = observe_call("observe", C, list("since_rev" = moved["rev"]))
	observe_check(islist(changed) && observe_refs(changed["nearby"]) ~= list(agent_ref(second)), "a new object is listed as changed")
	observe_check(islist(changed) && (agent_ref(spear) in changed["nearby_removed"]), "a removed object is listed in nearby_removed")
	var/list/stale = observe_call("observe", C, list("since_rev" = first["rev"]))
	observe_check(islist(stale) && !("changes_since" in stale) && length(stale["nearby"]), "an old baseline gives the full list")
	agent_characters -= C.body
	qdel(C.body)

/proc/observe_prompt_checks()
	var/datum/agent_character/C = observe_character(20, 20, "Asked")
	var/answer = WWinput(C.body, "Dig what?", "Shovel", "Pit", list("Tunnel", "Pit"))
	observe_check(answer == "Pit", "an unanswered prompt takes the default ([answer])")
	var/list/seen = observe_call("observe", C, list())
	var/list/prompts = islist(seen) ? seen["prompts"] : null
	observe_check(length(prompts) == 1 && prompts[1]["choices"] ~= list("Tunnel", "Pit") && prompts[1]["took"] == "Pit" && prompts[1]["text"] == "Dig what?", "observe lists the prompt, its choices and what was taken ([json_encode(prompts)])")
	C.pending_choice = "Tunnel"
	C.pending_choice_until = world.time + 10
	answer = WWinput(C.body, "Dig what?", "Shovel", "Pit", list("Tunnel", "Pit"))
	var/list/after = observe_call("observe", C, list("prompt_since" = seen["last_prompt"]))
	observe_check(answer == "Tunnel" && islist(after) && !length(after["prompts"]), "a prompt the step answered is not listed")
	WWinput(C.body, "How many?", "Count", null, "num")
	after = observe_call("observe", C, list("prompt_since" = after["last_prompt"]))
	observe_check(islist(after) && length(after["prompts"]) == 1 && after["prompts"][1]["kind"] == "num" && isnull(after["prompts"][1]["took"]), "a number prompt without a default records its kind and no answer")
	agent_characters -= C.body
	qdel(C.body)

/proc/observe_sound_checks()
	var/datum/agent_character/C = observe_character(5, 25, "Listener")
	var/mob/living/human/H = C.body
	playsound(locate(8, 25, 1), 'sound/effects/Explosion1.ogg', 80)
	playsound(locate(6, 25, 1), "grassfootsteps", 40)
	var/list/heard = observe_call("observe", C, list())
	var/list/sounds = islist(heard) ? heard["sounds"] : null
	observe_check(length(sounds) == 1 && lowertext(sounds[1]["sound"]) == "explosion1" && sounds[1]["dx"] == 3 && sounds[1]["dy"] == 0 && sounds[1]["volume"] == 80 && sounds[1]["kind"] == "explosion", "a nearby sound is heard with its offset and kind ([json_encode(sounds)])")
	var/list/steps = observe_call("observe", C, list("footsteps" = TRUE))
	observe_check(islist(steps) && length(steps["sounds"]) == 2 && steps["sounds"][2]["footsteps"] && steps["sounds"][2]["kind"] == "footsteps", "footsteps are listed only when asked")
	playsound(locate(5, 25, 1), 'sound/effects/Explosion1.ogg', 80)
	var/list/later = observe_call("observe", C, list("sound_since" = heard["last_sound"]))
	observe_check(islist(later) && length(later["sounds"]) == 1, "sound_since returns only newer sounds")
	H.ear_deaf = 5
	playsound(locate(6, 25, 1), 'sound/effects/Explosion1.ogg', 80)
	var/list/deaf = observe_call("observe", C, list("sound_since" = later["last_sound"]))
	observe_check(islist(deaf) && !length(deaf["sounds"]), "a deafened character hears nothing")
	agent_characters -= C.body
	qdel(C.body)

/proc/observe_queue_checks()
	var/datum/agent_character/C = observe_character(25, 5, "Worker")
	var/mob/living/human/H = C.body
	var/list/queued = observe_call("queue", C, list("actions" = list(list("do" = "face", "dir" = "north", "repeat" = 3))))
	observe_check(islist(queued), "a repeat step is queued ([islist(queued) ? "ok" : queued])")
	sleep(10)
	var/list/seen = observe_call("observe", C, list())
	var/list/results = islist(seen) ? seen["queue"]["results"] : null
	observe_check(length(results) == 1 && results[1]["detail"] == "done x3", "a repeated step runs three times and is recorded once ([json_encode(results)])")
	var/obj/item/stack/material/wood/wood = new(get_turf(H))
	H.put_in_inactive_hand(wood)
	observe_call("queue", C, list("actions" = list(list("do" = "swap_hand", "repeat" = 5, "until" = list("holding" = "wood")))))
	sleep(10)
	seen = observe_call("observe", C, list("queue_since" = results[1]["id"]))
	results = islist(seen) ? seen["queue"]["results"] : null
	observe_check(length(results) == 1 && results[1]["detail"] == "done x1 (until met)" && H.get_active_hand() == wood, "until stops the repeats once it holds ([json_encode(results)])")
	var/bad = observe_call("queue", C, list("actions" = list(list("do" = "swap_hand", "repeat" = 31))))
	observe_check(istext(bad) && findtext(bad, "repeat must be"), "repeat is bounded ([bad])")
	bad = observe_call("queue", C, list("actions" = list(list("do" = "swap_hand", "until" = list("hunger" = 1)))))
	observe_check(istext(bad) && findtext(bad, "until takes"), "unknown until keys are refused ([bad])")
	var/obj/item/weapon/material/spear/spear = new(locate(26, 5, 1))
	var/result = observe_call("step", C, list("do" = "examine", "target" = agent_ref(spear), "expect_name" = "spear"))
	observe_check(islist(result), "expect_name passes when the name matches ([islist(result) ? "ok" : result])")
	result = observe_call("step", C, list("do" = "examine", "target" = agent_ref(spear), "expect_name" = "wolf"))
	observe_check(istext(result) && findtext(result, "target_changed"), "expect_name refuses a different object ([result])")
	agent_characters -= C.body
	qdel(C.body)

/proc/observe_view_checks()
	var/datum/agent_character/C = observe_character(15, 15, "Looker")
	var/obj/item/weapon/material/spear/spear = new(locate(16, 15, 1))
	// A runtime icon (as human bodies are): it travels as base64 DMI bytes.
	var/obj/tinted = new(locate(14, 15, 1))
	var/icon/I = new(spear.icon, spear.icon_state)
	I.Blend("#ff0000", ICON_MULTIPLY)
	tinted.icon = I
	var/list/head = observe_call("view", C, list("radius" = 3))
	observe_check(islist(head) && head["part"] == 1 && head["parts"] >= 1 && head["view"] == C.view_id, "a view starts with part 1 of parts ([islist(head) ? "[head["parts"]] parts, [head["bytes"]] bytes" : head])")
	if (!islist(head))
		return
	var/text = head["text"]
	for (var/n in 2 to head["parts"])
		var/list/part = observe_call("view", C, list("view" = head["view"], "part" = n))
		text += islist(part) ? part["text"] : ""
	observe_check(length(text) == head["bytes"], "the parts join into the whole dump")
	var/list/dump = json_decode(text)
	observe_check(dump["region"] ~= list(12, 12, 18, 18, 1) && dump["center"] ~= list(15, 15), "the region is the radius around the character")
	observe_check(length(dump["cells"]) == 49 && length(dump["appearances"]) > 3, "every seen tile has a cell ([length(dump["cells"])] cells, [length(dump["appearances"])] appearances)")
	var/named = 0
	var/inline = 0
	for (var/list/icon in dump["icons"])
		if (icon["source"])
			named++
		if (icon["base64"])
			inline++
	observe_check(named > 0 && inline > 0, "source icons are named by path, runtime icons sent inline ([named] named, [inline] inline)")
	var/found = FALSE
	for (var/list/cell in dump["cells"])
		for (var/list/movable in cell[5])
			if (movable[4] == "[C.body.type]")
				found = TRUE
	observe_check(found, "the character is in its own view")
	text2file(text, "view.json")
	var/stale = observe_call("view", C, list("view" = head["view"] - 1, "part" = 1 + 1))
	observe_check(istext(stale) && findtext(stale, "view_gone"), "an old view id is refused ([stale])")
	agent_characters -= C.body
	qdel(C.body)
