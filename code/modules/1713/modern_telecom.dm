// Independent Civ13 implementation. No upstream telecom source or assets copied.
#define CIV_TELECOM_LIMIT 128
var/global/list/civ_telecom_devices = list()
var/global/civ_telecom_cursor = 1

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
	if (!istype(O, /obj/structure/cable) || !H || H.stat != CONSCIOUS || !H.can_use_hands() || get_dist(H, src) > 1 || get_dist(H, O) > 1 || get_dist(src, O) > 1 || !anchored || !isturf(loc))
		return
	if (powersource)
		powersource.update_power(-powerneeded, 1, src)
		powersource.connections -= src
	powersource = O
	powersource.connections |= src

/obj/structure/telecom/attack_hand(mob/living/human/H)
	if (!istype(H) || H.stat != CONSCIOUS || !H.can_use_hands() || get_dist(H, src) > 1)
		return
	var/choice = input(H, "Tune or switch. Drag an adjacent laid cable onto the equipment to power it.", name) in list("Power", "Frequency", "Program", "Cancel")
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
			to_chat(H, "You prepare the [program] course. Six lessons air ten seconds apart, with a five-minute interval between courses.")

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
		if (!A.retired && A.anchored && isturf(A.loc) && A.z == z)
			return TRUE
	return FALSE

/obj/structure/telecom/station/proc/transmit_lesson()
	if (world.time < next_broadcast)
		return
	next_broadcast = world.time + 100
	if (!prepared || !operational() || !has_antenna())
		program_line = 0
		return
	if (!(program in list("crafting", "farming", "medical")))
		return
	program_line++
	var/line = program_line
	var/list/delivered = list()
	for (var/obj/structure/telecom/R in civ_telecom_devices)
		if (istype(R, /obj/structure/telecom/station) || istype(R, /obj/structure/telecom/antenna) || R.television != television || R.frequency != frequency || R.z != z || get_dist(R, src) > 60 || !R.operational())
			continue
		for (var/mob/living/human/H in view(3, R))
			if (delivered.len >= 32)
				break
			if (H in delivered)
				continue
			delivered |= H
			if (H.client && H.stat == CONSCIOUS)
				to_chat(H, "[R]: [program] workshop, lesson [line] of 6. [telecom_lesson_text(program)]")
				H.learn_broadcast(program, line)
	if (program_line >= 6)
		program_line = 0
		next_broadcast = world.time + 3000

/proc/telecom_lesson_text(skill)
	if (skill == "crafting")
		return "Measure before cutting, select the correct workbench, and connect power before operating equipment."
	if (skill == "farming")
		return "Inspect water and nutrition; freshwater channels irrigate, while salt can spoil connected channels."
	return "Inspect injuries before treatment; medicines require the correct feedstock and clean equipment."

/mob/living/human
	// Fixed 18-entry curriculum, durable on the actual human save graph.
	var/list/broadcast_lessons = list()

/mob/living/human/proc/learn_broadcast(skill, line)
	if (!client || stat != CONSCIOUS || !(skill in list("crafting", "farming", "medical")) || line != round(line) || line < 1 || line > 6)
		return FALSE
	var/list/values = stats[skill]
	if (!islist(values) || values.len < 2 || values[1] < 10 || values[1] >= 100)
		return FALSE
	var/key = "[skill]:[line]"
	if (key in broadcast_lessons)
		return FALSE
	broadcast_lessons |= key
	// One percent per unique lesson; preserve the existing practice formulas.
	var/divisor = skill == "crafting" ? 500 : (skill == "farming" ? 200 : 100)
	adaptStat(skill, divisor * 0.01)
	values[1] = min(values[1], 100)
	values[2] = min(values[2], 100)
	return TRUE

/process/civ_telecom/setup()
	name = "bounded civilian telecom"
	schedule_interval = 1 SECOND
	start_delay = 1 SECOND
	priority = PROCESS_PRIORITY_LOW
	fires_at_gamestates = list(GAME_STATE_PLAYING)
	processes.civ_telecom = src

/process/civ_telecom/fire()
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
