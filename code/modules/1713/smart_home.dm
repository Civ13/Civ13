// Digital Age (2026) smart home, phases 0 and 1 of the smart home plan:
// a powered hub that listens for its name and runs devices paired on its own
// electricity cable network. It is an appliance, not a character: nobody plays
// it, it cannot move, and it only touches devices its owner paired.
// Independent Civ13 implementation; no upstream station AI code or assets.
#define SMART_HUB_DEVICE_LIMIT 24
#define SMART_HUB_HEAR_RANGE 5
#define SMART_HUB_SCAN_RANGE 12
#define SMART_HUB_REPLY_GAP 20
#define SMART_HUB_TIMER_LIMIT 4
#define SMART_HUB_TIMER_MAX 36000
#define SMART_HUB_RESIDENT_LIMIT 16
#define SMART_HUB_PHONE_RANGE 80
#define SMART_GUEST 0
#define SMART_RESIDENT 1
#define SMART_OWNER 2

var/global/list/smart_hubs = list()

// Pairing state lives on the device as plain text, so a save holds no pointers.
/obj/structure/var/smart_hub_id = null
/obj/structure/var/smart_label = null
/obj/structure/var/smart_off = FALSE

// A paired light or plug the hub switched off draws no cable power.
/obj/proc/smart_power_cut()
	return FALSE

/obj/structure/smart_power_cut()
	return smart_off && smart_hub_id

// What a hub can do with this structure: "light", "lock", "plug" or null.
/obj/structure/proc/smart_kind()
	if (powerneeded <= 0)
		return null
	return "plug"

/obj/structure/lamp/smart_kind()
	if (powerneeded <= 0)
		return null
	return "light"

/obj/structure/smart_hub/smart_kind()
	return null

/obj/structure/smart_speaker/smart_kind()
	return null

/obj/structure/cable/smart_kind()
	return null

/obj/structure/simple_door/smart_kind()
	return smart_lock_fitted ? "lock" : null

/proc/smart_hub_by_id(id)
	if (!id)
		return null
	for (var/obj/structure/smart_hub/hub in smart_hubs)
		if (hub.hub_id == id && !QDELETED(hub))
			return hub
	return null

/mob/proc/smart_hub_identity()
	return ckey

// Lowercase words of letters, digits and dashes only; apostrophes vanish
// ("what's" -> "whats") and every other character separates words.
/proc/smart_clean_text(text, limit = 32)
	if (!istext(text))
		return ""
	text = lowertext(copytext(text, 1, 401))
	var/list/kept = list()
	var/word = ""
	for (var/i = 1, i <= length(text), i++)
		var/c = copytext(text, i, i + 1)
		if ((c >= "a" && c <= "z") || (c >= "0" && c <= "9") || c == "-")
			word += c
		else if (c != "'")
			if (word)
				kept += word
			word = ""
	if (word)
		kept += word
	return copytext(jointext(kept, " "), 1, limit + 1)

/obj/structure/smart_hub
	name = "smart hub"
	desc = "A cabled speaker hub. Say its name, then a command. Drag an adjacent laid cable onto it to power it."
	icon = 'icons/obj/device.dmi'
	icon_state = "radio_vintage"
	anchored = TRUE
	density = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	powerneeded = 3
	var/enabled = TRUE
	var/hub_id = null
	var/hub_name = "hub"
	var/owner_ckey = null
	var/owner_name = null
	var/list/residents = list()
	var/share_faction = FALSE
	var/owner_faction = null
	var/list/timer_names = list()
	var/list/timer_left = list()
	var/tmp/last_reply = -100

/obj/structure/smart_hub/New()
	..()
	smart_hubs |= src

/obj/structure/smart_hub/on_runtime_spawn()
	..()
	hub_id = "[world.realtime]-[rand(100000, 999999)]"

/obj/structure/smart_hub/after_load()
	..()
	smart_hubs |= src
	if (timer_left.len)
		processing_objects |= src

/obj/structure/smart_hub/Destroy()
	smart_hubs -= src
	processing_objects -= src
	return ..()

/obj/structure/smart_hub/persistence_runtime_var(var_name)
	return var_name == "last_reply" || ..()

/obj/structure/smart_hub/MouseDrop_T(atom/movable/O, mob/living/human/H)
	if (istype(O, /obj/structure/cable))
		civ_attach_cable(O, H)
		return
	return ..()

/obj/structure/smart_hub/examine(mob/user)
	..()
	to_chat(user, "Its name is \"[hub_name]\".[owner_name ? " It belongs to [owner_name]." : " Nobody has claimed it yet."]")
	if (!operational())
		to_chat(user, "Its light is off.")

/obj/structure/smart_hub/proc/operational()
	return enabled && anchored && isturf(loc) && !QDELETED(src) && draw_cable_power()

/obj/structure/smart_hub/proc/access_level(mob/M)
	if (!M)
		return SMART_GUEST
	var/identity = M.smart_hub_identity()
	if (!identity)
		return SMART_GUEST
	if (identity == owner_ckey)
		return SMART_OWNER
	if (identity in residents)
		return SMART_RESIDENT
	if (share_faction && owner_faction && ishuman(M))
		var/mob/living/human/H = M
		if (H.civilization && H.civilization != "none" && H.civilization == owner_faction)
			return SMART_RESIDENT
	return SMART_GUEST

// A device is reachable when it sits on this hub's cable network, whether or
// not it is switched off right now.
/obj/structure/smart_hub/proc/reaches(obj/structure/D)
	if (!D || QDELETED(D) || D.z != z || !D.anchored || !isturf(D.loc))
		return FALSE
	if (!powersource || !D.powersource || !(D in D.powersource.connections) || get_dist(D, D.powersource) > 1)
		return FALSE
	return powersource.component_id && D.powersource.component_id == powersource.component_id

/obj/structure/smart_hub/proc/devices()
	. = list()
	if (!hub_id)
		return
	for (var/obj/structure/S in range(SMART_HUB_SCAN_RANGE, src))
		if (S.smart_hub_id == hub_id && S.smart_label && S.smart_kind())
			. += S

/obj/structure/smart_hub/proc/pairable()
	. = list()
	for (var/obj/structure/S in range(SMART_HUB_SCAN_RANGE, src))
		if (!S.smart_kind() || (S.smart_hub_id && smart_hub_by_id(S.smart_hub_id)))
			continue
		if (reaches(S))
			. += S

/obj/structure/smart_hub/proc/device_state(obj/structure/S)
	switch (S.smart_kind())
		if ("lock")
			var/obj/structure/simple_door/D = S
			if (D.state)
				return "open"
			return D.locked ? "locked" : "unlocked"
		if ("light")
			if (S.smart_off)
				return "off"
			var/obj/structure/lamp/L = S
			return L.on ? "on" : "on, no power"
	return S.smart_off ? "off" : "on"

/obj/structure/smart_hub/proc/pair(obj/structure/S, label)
	label = smart_clean_text(label)
	if (!label || (label in list("all", "lights", "light", "doors", "door", "everything", "up")))
		return "Pick another name."
	if (!(S in pairable()))
		return "That is not on this hub's cable network."
	var/list/current = devices()
	if (current.len >= SMART_HUB_DEVICE_LIMIT)
		return "This hub already runs [SMART_HUB_DEVICE_LIMIT] devices."
	for (var/obj/structure/other in current)
		if (other.smart_label == label)
			return "Another device is already called [label]."
	S.smart_hub_id = hub_id
	S.smart_label = label
	S.smart_off = FALSE
	return "Paired [label]."

/obj/structure/smart_hub/proc/unpair(obj/structure/S)
	S.smart_hub_id = null
	S.smart_label = null
	S.smart_off = FALSE

/obj/structure/smart_hub/proc/speak(message, atom/at = src)
	var/turf/T = get_turf(at)
	if (!T || !message)
		return
	var/text = "<span class='game say'><span class='name'>[capitalize(hub_name)]</span> says, \"[message]\"</span>"
	for (var/mob/M in hearers(SMART_HUB_HEAR_RANGE + 2, T))
		if (M.client)
			to_chat(M, text)

// Returns the command after the hub's name, or null when the line is not for it.
/obj/structure/smart_hub/proc/strip_wake(text)
	var/line = smart_clean_text(text, 200)
	var/name = smart_clean_text(hub_name)
	if (!line || !name)
		return null
	for (var/prefix in list("hey ", "ok ", "okay ", ""))
		var/start = prefix + name
		if (line == start)
			return ""
		if (findtext(line, start + " ") == 1)
			return copytext(line, length(start) + 2)
	return null

/obj/structure/smart_hub/hear_talk(mob/M, text, verb, datum/language/speaking)
	heard(M, text, src)

/obj/structure/smart_hub/proc/heard(mob/M, text, atom/voice_point)
	if (!ishuman(M) || M.stat != CONSCIOUS || !voice_point || get_dist(M, voice_point) > SMART_HUB_HEAR_RANGE)
		return FALSE
	var/command = strip_wake(text)
	if (isnull(command) || !operational() || world.time < last_reply + SMART_HUB_REPLY_GAP)
		return FALSE
	last_reply = world.time
	speak(run_command(M, command), voice_point)
	return TRUE

/obj/structure/smart_hub/proc/help_text()
	return "Say \"[hub_name]\" then: status, devices, time, lights on or off, a device name with on or off, lock or unlock a door, lock up, timer 5 minutes, timers, cancel timers."

// Fixed commands only: phase 1 has no language model. Anything else gets a
// pointer to the help list.
/obj/structure/smart_hub/proc/run_command(mob/M, command)
	var/level = access_level(M)
	var/list/words = splittext(smart_clean_text(command, 200), " ")
	var/list/kept = list()
	for (var/word in words)
		if (!(word in list("please", "the", "my", "a", "an", "can", "could", "would", "you", "to", "for", "me", "set", "turn", "switch", "of", "in")))
			kept += word
	var/phrase = jointext(kept, " ")
	if (!phrase || phrase == "help" || phrase == "commands" || phrase == "what do" || phrase == "what")
		return help_text()
	if ((phrase in list("time", "what time is it", "what time is", "whats time", "what time")) || (findtext(phrase, "time") && !findtext(phrase, "timer")))
		return "It is [lowertext(time_of_day)]."
	if (phrase == "status" || phrase == "report")
		return status_report(level)
	if (phrase == "devices" || phrase == "list devices" || phrase == "what devices")
		if (level < SMART_RESIDENT)
			return "Only residents can hear the device list."
		return device_list()
	if (findtext(phrase, "timer"))
		if (level < SMART_RESIDENT)
			return "Only residents can set timers."
		return timer_command(kept)
	if (kept.len && (kept[1] == "lock" || kept[1] == "unlock"))
		if (level < SMART_RESIDENT)
			return "Only residents can use the locks."
		return lock_command(kept[1] == "lock", jointext(kept.Copy(2), " "))
	if (kept.len && kept[1] == "toggle")
		if (level < SMART_RESIDENT)
			return "Only residents can switch devices."
		return toggle_command(jointext(kept.Copy(2), " "))
	var/on_index = kept.Find("on")
	var/off_index = kept.Find("off")
	if (on_index || off_index)
		if (level < SMART_RESIDENT)
			return "Only residents can switch devices."
		var/list/target_words = kept.Copy()
		target_words -= "on"
		target_words -= "off"
		return switch_command(!off_index, jointext(target_words, " "))
	return "I don't know that one. Say \"[hub_name], help\" for the list."

/obj/structure/smart_hub/proc/match_devices(target, kind)
	. = list()
	var/list/candidates = list()
	for (var/obj/structure/S in devices())
		if (!kind || S.smart_kind() == kind)
			candidates += S
	if (!target || target == "all" || (kind == "light" && (target in list("lights", "light", "all lights"))) || (kind == "lock" && (target in list("doors", "door", "all doors", "up", "everything"))))
		if (!target && candidates.len > 1)
			return list()
		return candidates
	var/singular = target
	if (length(target) > 1 && copytext(target, length(target)) == "s")
		singular = copytext(target, 1, length(target))
	for (var/obj/structure/S in candidates)
		if (S.smart_label == target || S.smart_label == singular)
			return list(S)
	for (var/obj/structure/S in candidates)
		if (findtext(S.smart_label, singular))
			. += S
	if (!length(.))
		for (var/obj/structure/S in candidates)
			if (findtext(target, S.smart_label))
				. += S

/obj/structure/smart_hub/proc/switch_command(on, target)
	var/list/found = list()
	if (target in list("lights", "light", "all lights", "all light"))
		found = match_devices("lights", "light")
	else
		for (var/obj/structure/S in match_devices(target, null))
			if (S.smart_kind() == "light" || S.smart_kind() == "plug")
				found += S
		if (!found.len && findtext(target, "light"))
			found = match_devices(trim(replacetext(replacetext(target, "lights", ""), "light", "")), "light")
	if (!found.len)
		return "I can't find [target ? target : "that"]."
	for (var/obj/structure/S in found)
		S.smart_off = !on
	if (found.len == 1)
		var/obj/structure/one = found[1]
		return "[capitalize(one.smart_label)] [on ? "on" : "off"]."
	return "[found.len] devices [on ? "on" : "off"]."

/obj/structure/smart_hub/proc/toggle_command(target)
	var/list/found = match_devices(target, null)
	if (found.len != 1)
		return "I can't find [target ? target : "that"]."
	var/obj/structure/S = found[1]
	if (S.smart_kind() == "lock")
		var/obj/structure/simple_door/D = S
		return lock_command(!D.locked, S.smart_label)
	return switch_command(S.smart_off, S.smart_label)

/obj/structure/smart_hub/proc/lock_command(lock, target)
	var/list/found = match_devices(target, "lock")
	if (!found.len)
		return "I can't find a lock called [target ? target : "that"]."
	var/done = 0
	var/list/problems = list()
	for (var/obj/structure/simple_door/D in found)
		if (!D.draw_cable_power())
			problems += "[D.smart_label] has no power"
			continue
		if (lock)
			if (D.state || D.isSwitchingStates)
				problems += "[D.smart_label] is open"
				continue
			D.locked = TRUE
		else
			D.locked = FALSE
		playsound(get_turf(D), 'sound/machines/click.ogg', 40, TRUE)
		done++
	var/obj/structure/first = found[1]
	var/reply = done == 1 && found.len == 1 ? "[capitalize(first.smart_label)] [lock ? "locked" : "unlocked"]." : "[done] door[done == 1 ? "" : "s"] [lock ? "locked" : "unlocked"]."
	if (problems.len)
		reply += " [capitalize(jointext(problems, ", "))]."
	return reply

/obj/structure/smart_hub/proc/timer_command(list/kept)
	if (("cancel" in kept) || ("stop" in kept) || ("clear" in kept))
		var/count = timer_left.len
		timer_names = list()
		timer_left = list()
		processing_objects -= src
		return count ? "Cancelled [count] timer[count == 1 ? "" : "s"]." : "No timers are running."
	var/amount = 0
	var/unit = 0
	for (var/word in kept)
		var/n = text2num(word)
		if (isnum(n) && n > 0)
			amount = n
		else if (word in list("one", "two", "three", "four", "five", "ten", "fifteen", "twenty", "thirty"))
			amount = list("one" = 1, "two" = 2, "three" = 3, "four" = 4, "five" = 5, "ten" = 10, "fifteen" = 15, "twenty" = 20, "thirty" = 30)[word]
		else if (word in list("second", "seconds", "sec", "secs"))
			unit = 10
		else if (word in list("minute", "minutes", "min", "mins"))
			unit = 600
		else if (word in list("hour", "hours"))
			unit = 36000
	if (!amount)
		if (!timer_left.len)
			return "No timers are running."
		var/list/parts = list()
		for (var/i = 1, i <= timer_left.len, i++)
			parts += "[timer_names[i]] with [smart_duration(timer_left[i])] left"
		return "Timers: [jointext(parts, ", ")]."
	if (!unit)
		unit = 600
	var/length = round(amount * unit)
	if (length < 10 || length > SMART_HUB_TIMER_MAX)
		return "Timers run from 1 second to 1 hour."
	if (timer_left.len >= SMART_HUB_TIMER_LIMIT)
		return "I can only run [SMART_HUB_TIMER_LIMIT] timers."
	timer_names += smart_duration(length)
	timer_left += length
	processing_objects |= src
	return "Timer set for [smart_duration(length)]."

/proc/smart_duration(deciseconds)
	var/seconds = max(0, round(deciseconds / 10))
	if (seconds >= 60)
		var/minutes = round(seconds / 60)
		seconds -= minutes * 60
		return "[minutes] minute[minutes == 1 ? "" : "s"][seconds ? " [seconds] second[seconds == 1 ? "" : "s"]" : ""]"
	return "[seconds] second[seconds == 1 ? "" : "s"]"

// Remaining time counts down by the process interval, so a save holds no
// world.time stamp and a restart resumes the count.
/obj/structure/smart_hub/process_interval(configured_seconds)
	return advance_timers(configured_seconds * 10)

/obj/structure/smart_hub/proc/advance_timers(deciseconds)
	if (!timer_left.len)
		return PROCESS_KILL
	if (!operational())
		return
	for (var/i = timer_left.len, i >= 1, i--)
		timer_left[i] = timer_left[i] - deciseconds
		if (timer_left[i] <= 0)
			var/label = timer_names[i]
			timer_left.Cut(i, i + 1)
			timer_names.Cut(i, i + 1)
			playsound(get_turf(src), 'sound/machines/ping.ogg', 60)
			speak("Your [label] timer is done.")
	if (!timer_left.len)
		return PROCESS_KILL

/obj/structure/smart_hub/proc/device_list()
	var/list/current = devices()
	if (!current.len)
		return "No devices are paired."
	var/list/parts = list()
	for (var/obj/structure/S in current)
		parts += "[S.smart_label] [device_state(S)]"
	return "[jointext(parts, ", ")]."

/obj/structure/smart_hub/proc/status_report(level)
	if (level < SMART_RESIDENT)
		return "[capitalize(hub_name)] is online."
	var/list/current = devices()
	var/lights_on = 0
	var/lights = 0
	var/locks = 0
	var/locked = 0
	var/plugs = 0
	var/unreached = 0
	for (var/obj/structure/S in current)
		if (!reaches(S))
			unreached++
		switch (S.smart_kind())
			if ("light")
				lights++
				if (!S.smart_off)
					lights_on++
			if ("lock")
				locks++
				var/obj/structure/simple_door/D = S
				if (D.locked && !D.state)
					locked++
			else
				plugs++
	var/list/parts = list()
	if (lights)
		parts += "[lights_on] of [lights] light[lights == 1 ? "" : "s"] on"
	if (locks)
		parts += "[locked] of [locks] door[locks == 1 ? "" : "s"] locked"
	if (plugs)
		parts += "[plugs] plug[plugs == 1 ? "" : "s"]"
	if (unreached)
		parts += "[unreached] off the network"
	if (timer_left.len)
		parts += "[timer_left.len] timer[timer_left.len == 1 ? "" : "s"] running"
	if (!parts.len)
		return "All quiet. No devices are paired."
	return "[capitalize(jointext(parts, ", "))]."

/obj/structure/smart_hub/attack_hand(mob/living/human/H)
	if (!istype(H) || H.stat != CONSCIOUS || !H.can_use_hands() || get_dist(H, src) > 1)
		return
	var/level = access_level(H)
	var/list/choices = list("Status", "Commands")
	if (!owner_ckey)
		choices += "Claim this hub"
	if (level >= SMART_RESIDENT)
		choices += "Devices"
	if (level == SMART_OWNER)
		choices += list("Pair device", "Unpair device", "Rename hub", "Add resident", "Remove resident", "Share with my faction: [share_faction ? "on" : "off"]", "Power: [enabled ? "on" : "off"]")
	choices += "Cancel"
	var/choice = input(H, "Smart hub \"[hub_name]\". Drag an adjacent laid cable onto it to power it.", name) in choices
	if (!H || H.stat != CONSCIOUS || !H.can_use_hands() || get_dist(H, src) > 1 || QDELETED(src))
		return
	level = access_level(H)
	switch (choice)
		if ("Status")
			to_chat(H, operational() ? status_report(level) : "The hub has no power.")
		if ("Commands")
			to_chat(H, help_text())
		if ("Devices")
			if (level >= SMART_RESIDENT)
				to_chat(H, device_list())
		if ("Claim this hub")
			if (!owner_ckey && H.smart_hub_identity())
				owner_ckey = H.smart_hub_identity()
				owner_name = H.real_name
				owner_faction = H.civilization
				to_chat(H, "<span class='notice'>The hub is now yours. Pair devices on its cable network from this panel.</span>")
		if ("Pair device")
			if (level < SMART_OWNER)
				return
			var/list/options = list()
			for (var/obj/structure/S in pairable())
				options["[S.name] ([dir2text(get_dir(src, S)) ? dir2text(get_dir(src, S)) : "here"], [get_dist(src, S)] tiles)"] = S
			if (!options.len)
				to_chat(H, "No unpaired lights, smart locks or powered machines are on this hub's cable network within [SMART_HUB_SCAN_RANGE] tiles.")
				return
			var/picked = input(H, "Pair which device?", name) as null|anything in options
			if (!picked || get_dist(H, src) > 1)
				return
			var/label = input(H, "Name it, for example \"kitchen light\" or \"front door\".", name) as text|null
			if (label && get_dist(H, src) <= 1 && access_level(H) == SMART_OWNER)
				to_chat(H, pair(options[picked], label))
		if ("Unpair device")
			if (level < SMART_OWNER)
				return
			var/list/options = list()
			for (var/obj/structure/S in devices())
				options[S.smart_label] = S
			var/picked = input(H, "Unpair which device?", name) as null|anything in options
			if (picked && get_dist(H, src) <= 1 && access_level(H) == SMART_OWNER)
				unpair(options[picked])
				to_chat(H, "Unpaired [picked].")
		if ("Rename hub")
			if (level < SMART_OWNER)
				return
			var/value = smart_clean_text(input(H, "What should the hub answer to? One or two words.", name, hub_name) as text|null, 20)
			if (value && get_dist(H, src) <= 1 && access_level(H) == SMART_OWNER)
				hub_name = value
				to_chat(H, "The hub now answers to \"[hub_name]\".")
		if ("Add resident")
			if (level < SMART_OWNER)
				return
			if (residents.len >= SMART_HUB_RESIDENT_LIMIT)
				to_chat(H, "The hub already knows [SMART_HUB_RESIDENT_LIMIT] residents.")
				return
			var/list/options = list()
			for (var/mob/living/human/other in view(7, src))
				var/identity = other.smart_hub_identity()
				if (other != H && identity && identity != owner_ckey && !(identity in residents))
					options[other.real_name] = other
			var/picked = input(H, "Who lives here? They must be in sight of the hub.", name) as null|anything in options
			var/mob/living/human/chosen = options[picked]
			if (chosen && get_dist(H, src) <= 1 && access_level(H) == SMART_OWNER && chosen.smart_hub_identity())
				residents[chosen.smart_hub_identity()] = chosen.real_name
				to_chat(H, "[chosen.real_name] can now use the hub's devices.")
		if ("Remove resident")
			if (level < SMART_OWNER)
				return
			var/list/options = list()
			for (var/identity in residents)
				options["[residents[identity]]"] = identity
			var/picked = input(H, "Remove which resident?", name) as null|anything in options
			if (picked && get_dist(H, src) <= 1 && access_level(H) == SMART_OWNER)
				residents -= options[picked]
				to_chat(H, "Removed [picked].")
		if ("Cancel")
			return
		else
			if (level < SMART_OWNER)
				return
			if (findtext(choice, "Share with my faction") == 1)
				share_faction = !share_faction
				owner_faction = H.civilization
				to_chat(H, share_faction ? "Everyone in [owner_faction] can now use the hub's devices." : "Only listed residents can use the hub's devices now.")
			else if (findtext(choice, "Power") == 1)
				enabled = !enabled
				if (!enabled && powersource)
					powersource.update_power(-powerneeded, 1, src)
				to_chat(H, "You switch the hub [enabled ? "on" : "off"].")

// A small speaker that carries the hub's hearing to another room on the same
// cable network. Replies come out of the speaker that heard the command.
/obj/structure/smart_speaker
	name = "smart speaker"
	desc = "A small cabled speaker. It hears its hub's name for any smart hub on the same cable network."
	icon = 'icons/obj/device.dmi'
	icon_state = "radio_vintage"
	anchored = TRUE
	density = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	powerneeded = 0.5

/obj/structure/smart_speaker/MouseDrop_T(atom/movable/O, mob/living/human/H)
	if (istype(O, /obj/structure/cable))
		civ_attach_cable(O, H)
		return
	return ..()

/obj/structure/smart_speaker/hear_talk(mob/M, text, verb, datum/language/speaking)
	if (!anchored || !isturf(loc) || !draw_cable_power())
		return
	for (var/obj/structure/smart_hub/hub in smart_hubs)
		if (hub.z == z && hub.reaches(src) && hub.heard(M, text, src))
			return

// The smart lock: fitted to a plain door, cabled like any other device.
/obj/item/weapon/smart_lock
	name = "smart lock"
	desc = "A powered door lock for a smart hub. Fit it to a plain door with no other lock, then drag an adjacent laid cable onto the door."
	icon = 'icons/obj/doors/locks.dmi'
	icon_state = "keypad"
	flags = CONDUCT
	w_class = ITEM_SIZE_SMALL

/obj/structure/simple_door/var/smart_lock_fitted = FALSE

/obj/structure/simple_door/proc/fit_smart_lock(obj/item/weapon/smart_lock/lock, mob/user)
	if (smart_lock_fitted || haslock || istype(src, /obj/structure/simple_door/key_door))
		to_chat(user, "<span class='warning'>This door already has a lock.</span>")
		return FALSE
	if (!user.unEquip(lock))
		return FALSE
	qdel(lock)
	smart_lock_fitted = TRUE
	powerneeded = 0.2
	locked = FALSE
	to_chat(user, "<span class='notice'>You fit the smart lock. Drag an adjacent laid cable onto the door, then pair it at a smart hub.</span>")
	playsound(src, 'sound/machines/click.ogg', 60)
	return TRUE

// Residents of the paired hub open a locked smart door by hand, like a
// fingerprint reader. Everyone else has to break it or ask a resident.
/obj/structure/simple_door/proc/smart_lock_admits(mob/user)
	if (!smart_lock_fitted || !smart_hub_id || !user)
		return FALSE
	var/obj/structure/smart_hub/hub = smart_hub_by_id(smart_hub_id)
	if (!hub || !hub.operational() || hub.access_level(user) < SMART_RESIDENT || !hub.reaches(src))
		return FALSE
	return draw_cable_power()

/obj/structure/simple_door/MouseDrop_T(atom/movable/O, mob/user)
	if (smart_lock_fitted && istype(O, /obj/structure/cable))
		civ_attach_cable(O, user)
		return
	return ..()

/// Smartphone app: the same fixed commands, answered privately on the screen.
/obj/item/weapon/telephone/mobile/smartphone/verb/smart_hub_app()
	set name = "Smart Hub App"
	set category = null
	set src in usr
	var/mob/living/human/H = usr
	if (!istype(H) || H.stat != CONSCIOUS || !H.can_use_hands() || loc != H)
		return
	var/list/hubs = list()
	for (var/obj/structure/smart_hub/hub in smart_hubs)
		if (hub.z == H.z && get_dist(hub, H) <= SMART_HUB_PHONE_RANGE && hub.access_level(H) >= SMART_RESIDENT)
			hubs["[hub.hub_name] ([hub.owner_name ? hub.owner_name : "unclaimed"])"] = hub
	if (!hubs.len)
		to_chat(H, "No smart hub you live at is in range.")
		return
	var/picked_hub = hubs.len == 1 ? hubs[1] : input(H, "Which hub?", "Smart Hub App") as null|anything in hubs
	var/obj/structure/smart_hub/hub = hubs[picked_hub]
	if (!hub || QDELETED(hub) || loc != H)
		return
	if (!hub.operational())
		to_chat(H, "<b>[capitalize(hub.hub_name)]</b> is offline.")
		return
	var/list/options = list("Status")
	for (var/obj/structure/S in hub.devices())
		options["[S.smart_label] ([hub.device_state(S)])"] = "toggle [S.smart_label]"
	options["Lock up"] = "lock up"
	options["Lights off"] = "lights off"
	options["Lights on"] = "lights on"
	var/picked = input(H, "Tap a device to switch it.", "[capitalize(hub.hub_name)]") as null|anything in options
	if (!picked || loc != H || H.stat != CONSCIOUS || !hub.operational())
		return
	var/command = picked == "Status" ? "status" : options[picked]
	to_chat(H, "<b>[capitalize(hub.hub_name)]:</b> [hub.run_command(H, command)]")

#undef SMART_HUB_DEVICE_LIMIT
#undef SMART_HUB_HEAR_RANGE
#undef SMART_HUB_SCAN_RANGE
#undef SMART_HUB_REPLY_GAP
#undef SMART_HUB_TIMER_LIMIT
#undef SMART_HUB_TIMER_MAX
#undef SMART_HUB_RESIDENT_LIMIT
#undef SMART_HUB_PHONE_RANGE
