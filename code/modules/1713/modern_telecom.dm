// Independent Civ13 implementation. No upstream telecom source or assets copied.
#define CIV_TELECOM_LIMIT 128
#define CIV_BROADCAST_SKILL_CAP 125
// _map_metadata.dm:set_ordinal_age() maps 2013 (Modern) to ordinal 8.
#define CIV_TELECOM_MODERN_AGE 8
#define CIV_BROADCAST_CYCLE 6000
var/global/list/civ_telecom_devices = list()
var/global/civ_telecom_cursor = 1

/proc/civ_broadcast_time()
	return world.time

// Authoritative running-server time, not wall time or per-device timers.
// Each course occupies one minute in a repeating ten-minute schedule.
/proc/civ_broadcast_slot(skill, now)
	if (!map || map.ordinal_age < CIV_TELECOM_MODERN_AGE || !isnum(now) || now < 0)
		return 0
	var/start
	var/list/allowed_seasons
	switch (skill)
		if ("crafting")
			start = 600
			allowed_seasons = list("FALL", "WINTER")
		if ("farming")
			start = 1800
			allowed_seasons = list("SPRING", "SUMMER")
		if ("medical")
			start = 3000
			allowed_seasons = list("SPRING", "SUMMER", "FALL", "WINTER")
		else
			return 0
	// Use the existing map cycle declaration without recording or aging debris.
	// Fixed-season and disabled-cycle maps have an explicit evergreen schedule.
	if (map.abandonment_uses_seasons() && !(season in allowed_seasons))
		return 0
	var/phase = now % CIV_BROADCAST_CYCLE
	if (phase < start || phase >= start + 600)
		return 0
	return round((phase - start) / 100) + 1

/obj/structure/telecom
	name = "broadcast receiver"
	desc = "A cable-powered receiver. Tune it to a station on the same level."
	icon = 'icons/obj/device.dmi'
	icon_state = "radio_vintage"
	anchored = TRUE
	density = FALSE
	powerneeded = 5
	var/frequency = 200
	var/enabled = FALSE
	var/television = FALSE
	var/program = "crafting"
	var/announcement = ""
	var/prepared = FALSE
	var/tmp/next_broadcast = 0
	var/tmp/program_line = 0
	var/tmp/retired = FALSE

/obj/structure/telecom/New()
	..()
	if (civ_telecom_devices.len < CIV_TELECOM_LIMIT)
		civ_telecom_devices |= src

/obj/structure/telecom/Destroy()
	retired = TRUE
	civ_telecom_devices -= src
	return ..()

/obj/structure/telecom/Del()
	civ_telecom_devices -= src
	..()

/obj/structure/telecom/persistence_runtime_var(var_name)
	if (var_name in list("next_broadcast", "program_line", "retired"))
		return TRUE
	return ..()

/obj/structure/telecom/proc/operational()
	return !retired && (src in civ_telecom_devices) && enabled && anchored && isturf(loc) && draw_cable_power()

/obj/structure/telecom/MouseDrop_T(atom/movable/O, mob/living/human/H)
	civ_attach_cable(O, H)

/obj/proc/civ_attach_cable(atom/movable/O, mob/living/human/H)
	if (!istype(O, /obj/structure/cable) || !H || H.stat != CONSCIOUS || !H.can_use_hands() || H.z != z || O.z != z || get_dist(H, src) > 1 || get_dist(H, O) > 1 || get_dist(src, O) > 1 || !anchored || !isturf(loc))
		return
	if (powersource)
		powersource.update_power(-powerneeded, 1, src)
		powersource.connections -= src
	powersource = O
	powersource.connections |= src

/obj/structure/telecom/attack_hand(mob/living/human/H)
	if (!istype(H) || H.stat != CONSCIOUS || !H.can_use_hands() || get_dist(H, src) > 1)
		return
	var/choice = input(H, "Tune or switch. Drag an adjacent laid cable onto the equipment to power it.", name) in list("Power", "Frequency", "Program", "Announcement", "Cancel")
	if (!H || H.stat != CONSCIOUS || get_dist(H, src) > 1 || !H.can_use_hands())
		return
	if (choice == "Power")
		enabled = !enabled
		if (!enabled && powersource)
			powersource.update_power(-powerneeded, 1, src)
	if (choice == "Frequency")
		var/value = input(H, "Frequency (150-300)", name, frequency) as num|null
		if (!isnull(value) && H && get_dist(H, src) <= 1 && H.stat == CONSCIOUS && H.can_use_hands())
			frequency = sanitize_integer(value, 150, 300, 200)
	if (choice == "Program" && istype(src, /obj/structure/telecom/station))
		var/value = input(H, "Educational program", name) in list("crafting", "farming", "medical")
		if (H && get_dist(H, src) <= 1 && H.stat == CONSCIOUS && H.can_use_hands() && H.stats[value][1] >= 100)
			program = value
			prepared = TRUE
			program_line = 0
			to_chat(H, "You prepare the [program] course. Check the station schedule; six lessons air ten seconds apart during its one-minute window.")
	if (choice == "Announcement" && istype(src, /obj/structure/telecom/station))
		var/value = input(H, "Station announcement (maximum 200 characters)", name) as text|null
		if (H && get_dist(H, src) <= 1 && H.stat == CONSCIOUS && H.can_use_hands())
			announcement = sanitize(value, 200)

/obj/structure/telecom/tv
	name = "educational television receiver"
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "TV"
	television = TRUE
	powerneeded = 10
	density = TRUE

/obj/structure/telecom/station
	name = "radio program desk"
	desc = "Powered station and program production desk. An adjacent antenna reaches 60 tiles. Prepare courses with a raw skill of at least 100."
	icon_state = "radio_vintage"
	powerneeded = 20

/obj/structure/telecom/station/tv
	name = "television program desk"
	television = TRUE
	powerneeded = 30

/obj/structure/telecom/antenna
	name = "broadcast antenna"
	desc = "A passive station antenna. Place within one tile of the program desk."
	icon = 'icons/obj/obj32x64.dmi'
	icon_state = "radio_powered"
	powerneeded = 0

/obj/structure/telecom/station/proc/has_antenna()
	for (var/obj/structure/telecom/antenna/A in range(1, src))
		if (!A.retired && (A in civ_telecom_devices) && A.anchored && isturf(A.loc) && A.z == z)
			return TRUE
	return FALSE

/obj/structure/telecom/station/examine(mob/user)
	. = ..()
	to_chat(user, "Educational schedule repeats every ten running-server minutes: crafting 1:00-1:59 (Fall/Winter), farming 3:00-3:59 (Spring/Summer), medical 5:00-5:59 (all seasons). Fixed/no-cycle maps use all courses in every season. Modern only; six unique lessons per course, once per character.")

/obj/structure/telecom/station/proc/transmit_lesson()
	var/now = civ_broadcast_time()
	if (now < next_broadcast)
		return
	next_broadcast = now - (now % 100) + 100
	var/line = civ_broadcast_slot(program, now)
	if (!prepared || !line || !operational() || !has_antenna())
		program_line = 0
		return
	program_line = line
	var/list/delivered = list()
	for (var/obj/structure/telecom/R in civ_telecom_devices)
		if (istype(R, /obj/structure/telecom/station) || istype(R, /obj/structure/telecom/antenna) || istype(R, /obj/structure/telecom/terminal) || R.television != television || R.frequency != frequency || R.z != z || get_dist(R, src) > 60 || !R.operational())
			continue
		for (var/mob/living/human/H in view(3, R))
			if (delivered.len >= 32)
				break
			if (H in delivered)
				continue
			delivered |= H
			if (H.broadcast_online() && H.stat == CONSCIOUS)
				if (announcement)
					to_chat(H, "[R]: [announcement]")
				to_chat(H, "[R]: [program] workshop, lesson [line] of 6. [telecom_lesson_text(program, line)]")
				H.learn_broadcast(program, line)

/proc/telecom_lesson_text(skill, line)
	var/list/lessons
	if (skill == "crafting")
		lessons = list("Check the recipe and count your materials before starting.", "Use the workbench specified by the recipe.", "Research unlocks and personal skill requirements are separate.", "Connect powered equipment to a working cable network.", "Keep the required tools and ingredients within reach during assembly.", "Inspect the finished item and maintain it through use.")
	else if (skill == "farming")
		lessons = list("Choose a crop suited to the local climate.", "Inspect your crop before adding water or nutrients.", "Use freshwater for irrigation.", "Connected channels carry irrigation water between fields.", "Saltwater can spoil connected irrigation channels.", "Keep seed stock for the next planting.")
	else if (skill == "medical")
		lessons = list("Examine the patient's condition before selecting a treatment.", "Check the game's medicine ingredients before mixing.", "Different medicines require different feedstocks.", "Keep your treatment tools accessible.", "Observe the patient after administering medicine.", "Use medical books and ordinary practice to continue training.")
	return lessons && line >= 1 && line <= lessons.len ? lessons[line] : ""

/mob/living/human
	// Fixed 18-entry curriculum, durable on the actual human save graph.
	var/list/broadcast_lessons = list()

/mob/living/human/proc/learn_broadcast(skill, line)
	if (!broadcast_online() || stat != CONSCIOUS || (sdisabilities & DEAF) || ear_deaf || find_trait("Deaf") || !(skill in list("crafting", "farming", "medical")) || line != round(line) || line < 1 || line > 6 || line != civ_broadcast_slot(skill, civ_broadcast_time()))
		return FALSE
	var/list/values = stats[skill]
	if (!islist(values) || values.len < 2 || values[1] < 10 || values[1] >= CIV_BROADCAST_SKILL_CAP || values[2] >= CIV_BROADCAST_SKILL_CAP)
		return FALSE
	var/key = "[skill]:[line]"
	if (key in broadcast_lessons)
		return FALSE
	broadcast_lessons |= key
	// Novices gain 1%; intermediate learners gain 0.5%. Existing practice
	// formulas remain unchanged, and advanced training requires practice/books.
	var/divisor = skill == "crafting" ? 500 : (skill == "farming" ? 200 : 100)
	var/rate = values[2] < 100 ? 0.01 : 0.005
	adaptStat(skill, divisor * rate)
	values[1] = min(values[1], CIV_BROADCAST_SKILL_CAP)
	values[2] = min(CIV_BROADCAST_SKILL_CAP, max(values[1], values[2]))
	return TRUE

/mob/living/human/proc/broadcast_online()
	return !!client

/mob/living/human/proc/practice_level(skill)
	var/list/value = stats[skill]
	if (!islist(value) || value.len < 2)
		return 0
	var/list/thresholds = list(20, 40, 60, 80, 100, 125, 150, 180, 215, 250)
	var/level = 0
	var/trained = skill == "magic" ? value[2] * 2.5 : value[2]
	for (var/threshold in thresholds)
		if (trained >= threshold)
			level++
	return level

/mob/living/human/verb/show_practice_progress()
	set name = "Skill Progress"
	set category = "IC"
	to_chat(src, "Practice levels reflect your existing trained maximum; mood and injuries still affect current effectiveness. Books retain their existing training rewards.")
	for (var/skill in stats)
		to_chat(src, "[skill]: level [practice_level(skill)]/10, trained [round(stats[skill][2], 0.1)], current [round(stats[skill][1], 0.1)].")
	to_chat(src, "Educational lessons credited: [broadcast_lessons.len]/18. Courses teach crafting, farming and medicine below 125 trained skill. Unique lessons grant 1% below 100, then 0.5%, once per character. Practice and books train beyond that limit.")

/process/civ_telecom/setup()
	name = "bounded civilian telecom"
	schedule_interval = 1 SECOND
	start_delay = 1 SECOND
	priority = PROCESS_PRIORITY_LOW
	fires_at_gamestates = list(GAME_STATE_PLAYING)
	processes.civ_telecom = src

/process/civ_telecom/fire()
	civ_check_landlines()
	var/checks = min(16, civ_telecom_devices.len)
	while (checks-- > 0 && civ_telecom_devices.len)
		if (civ_telecom_cursor > civ_telecom_devices.len)
			civ_telecom_cursor = 1
		var/obj/structure/telecom/O = civ_telecom_devices[civ_telecom_cursor++]
		if (istype(O, /obj/structure/telecom/station))
			var/obj/structure/telecom/station/S = O
			S.transmit_lesson()

/process/civ_telecom/reset_current_list()
	return
