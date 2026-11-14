// Part slots on machines (docs/material-roles.md, "Machine slots").
//
// A machine type lists its wearing slots in machine_slot_tables: the part
// each takes and the material it is built with today. A machine built the
// usual way stores nothing; its parts are the standard ones and it works at
// 100%. Installing a part writes one short text (part_key) and wear is one
// packed number (part_wear), so no machine carries a list.
//
//   part_key   "gears=bronze;shaft=steel+"   slot=material, "+" when precise
//   part_wear  six bits a slot, in table order, 0 to MACHINE_PART_WORN_OUT
//
// A machine may have at most MACHINE_MAX_SLOTS wearing slots: that is what
// the packed number holds exactly.

#define MACHINE_MAX_SLOTS 4
// Jobs a standard part lasts in its own design.
#define MACHINE_PART_BASE_LIFE 400
#define MACHINE_PART_WORN 21     // a quarter slower from here
#define MACHINE_PART_FAILING 42  // may jam from here
#define MACHINE_JAM_CHANCE 15
// A rough part someone fitted to a machine that needs precision does no better than this.
#define MACHINE_ROUGH_CAP 0.6
// A generator is charged wear now and then, not every second: on average one
// job each MACHINE_RUNNING_JOB_SECONDS of output, so a standard set lasts
// about 110 hours of running.
#define MACHINE_RUNNING_WEAR_CHANCE 1
#define MACHINE_RUNNING_JOB_SECONDS 1000

/obj/structure
	var/part_key
	var/part_wear = 0

// machine type -> list(slot = list(part type, standard material)). The nearest listed ancestor applies.
var/global/list/machine_slot_tables = list(
	/obj/structure/mill = list(
		"shaft" = list(/obj/item/machine_part/shaft, "wood"),
		"bearing" = list(/obj/item/machine_part/bearing, "wood")),
	/obj/structure/mill/large = list(
		"gears" = list(/obj/item/machine_part/gear, "wood"),
		"shaft" = list(/obj/item/machine_part/shaft, "wood"),
		"bearing" = list(/obj/item/machine_part/bearing, "wood")),
	/obj/structure/sawmill/large = list(
		"gears" = list(/obj/item/machine_part/gear, "wood"),
		"shaft" = list(/obj/item/machine_part/shaft, "wood"),
		"bearing" = list(/obj/item/machine_part/bearing, "wood")),
	/obj/structure/sawmill/powered = list(
		"gears" = list(/obj/item/machine_part/gear, "iron"),
		"shaft" = list(/obj/item/machine_part/shaft, "iron"),
		"bearing" = list(/obj/item/machine_part/bearing, "iron")),
	/obj/structure/loom = list(
		"shaft" = list(/obj/item/machine_part/shaft, "wood"),
		"bearing" = list(/obj/item/machine_part/bearing, "wood")),
	// The press screw.
	/obj/structure/printingpress = list(
		"shaft" = list(/obj/item/machine_part/shaft, "wood")),
	/obj/structure/civ_generator/waterwheel = list(
		"shaft" = list(/obj/item/machine_part/shaft, "wood"),
		"bearing" = list(/obj/item/machine_part/bearing, "wood")),
	/obj/structure/civ_generator/wind/charger = list(
		"gears" = list(/obj/item/machine_part/gear, "iron"),
		"shaft" = list(/obj/item/machine_part/shaft, "iron"),
		"bearing" = list(/obj/item/machine_part/bearing, "iron")),
	/obj/structure/civ_generator/wind/turbine = list(
		"gears" = list(/obj/item/machine_part/gear, "steel"),
		"shaft" = list(/obj/item/machine_part/shaft, "steel"),
		"bearing" = list(/obj/item/machine_part/bearing, "steel")),
)
// Machines from the Industrial era on: a rough replacement part is capped at MACHINE_ROUGH_CAP.
var/global/list/machine_precision_types = list(
	/obj/structure/sawmill/powered,
	/obj/structure/civ_generator/wind,
)
var/global/list/machine_slot_cache = list()  // type -> slot table, or 0
var/global/list/machine_key_cache = list()   // part_key -> list(slot = list(material, precise))

// The slot table for this machine, or null when it has no part slots.
/proc/machine_slots(obj/structure/M)
	if (!istype(M))
		return null
	var/cached = machine_slot_cache[M.type]
	if (isnull(cached))
		cached = 0
		var/best = 0
		for (var/listed in machine_slot_tables)
			if (istype(M, listed) && length("[listed]") > best)
				best = length("[listed]")
				cached = machine_slot_tables[listed]
		machine_slot_cache[M.type] = cached
	return cached || null

/proc/machine_needs_precision(obj/structure/M)
	for (var/listed in machine_precision_types)
		if (istype(M, listed))
			return TRUE
	return FALSE

/proc/machine_key_fills(part_key)
	if (!part_key)
		return null
	var/list/fills = machine_key_cache[part_key]
	if (!fills)
		fills = list()
		for (var/entry in splittext(part_key, ";"))
			var/list/pair = splittext(entry, "=")
			if (pair.len != 2)
				continue
			var/precise = copytext(pair[2], -1) == "+"
			fills[pair[1]] = list(precise ? copytext(pair[2], 1, -1) : pair[2], precise)
		machine_key_cache[part_key] = fills
	return fills

// list(material name, precise, fitted): fitted is FALSE for the part the machine was built with.
/proc/machine_slot_fill(obj/structure/M, slot)
	var/list/slots = machine_slots(M)
	if (!slots || !slots[slot])
		return null
	var/list/fills = machine_key_fills(M.part_key)
	var/list/fill = fills ? fills[slot] : null
	if (fill)
		return list(fill[1], fill[2], TRUE)
	return list(slots[slot][2], FALSE, FALSE)

/proc/machine_slot_wear(obj/structure/M, slot)
	var/list/slots = machine_slots(M)
	var/index = slots ? slots.Find(slot) : 0
	if (!index)
		return 0
	return round(M.part_wear / (64 ** (index - 1))) % 64

/proc/machine_set_slot_wear(obj/structure/M, slot, wear)
	var/list/slots = machine_slots(M)
	var/index = slots ? slots.Find(slot) : 0
	if (!index)
		return
	wear = max(0, min(MACHINE_PART_WORN_OUT, round(wear)))
	var/place = 64 ** (index - 1)
	M.part_wear += (wear - machine_slot_wear(M, slot)) * place

// How well one slot does its job against the part the machine is built with: 0 when worn out.
/proc/machine_slot_performance(obj/structure/M, slot)
	var/list/slots = machine_slots(M)
	var/list/fill = machine_slot_fill(M, slot)
	if (!fill)
		return 1
	var/wear = machine_slot_wear(M, slot)
	if (wear >= MACHINE_PART_WORN_OUT)
		return 0
	var/obj/item/machine_part/part = slots[slot][1]
	var/role = initial(part.part_role)
	var/standard = part_performance(role, slots[slot][2])
	var/performance = standard > 0 ? part_performance(role, fill[1]) / standard : 1
	performance = max(PART_PERFORMANCE_MIN, min(PART_PERFORMANCE_MAX, performance))
	if (fill[3] && !fill[2] && machine_needs_precision(M))
		performance = min(performance, MACHINE_ROUGH_CAP)
	if (wear >= MACHINE_PART_WORN)
		performance *= 0.75
	return performance

// The whole machine goes as fast as its weakest part. 1 for a machine with no slots.
/proc/machine_performance(obj/structure/M)
	var/list/slots = machine_slots(M)
	if (!slots)
		return 1
	. = PART_PERFORMANCE_MAX
	for (var/slot in slots)
		. = min(., machine_slot_performance(M, slot))

/proc/machine_work_time(obj/structure/M, time)
	return time / max(PART_PERFORMANCE_MIN, machine_performance(M))

// The first worn-out slot, or null.
/proc/machine_broken_slot(obj/structure/M)
	for (var/slot in machine_slots(M))
		if (machine_slot_wear(M, slot) >= MACHINE_PART_WORN_OUT)
			return slot
	return null

// TRUE when the machine cannot do this job: a part is worn out, or a failing part jammed.
/proc/machine_work_refusal(obj/structure/M, mob/user)
	var/list/slots = machine_slots(M)
	if (!slots)
		return FALSE
	var/broken = machine_broken_slot(M)
	if (broken)
		var/obj/item/machine_part/part = slots[broken][1]
		to_chat(user, "<span class='warning'>\The [M] will not run: its [initial(part.part_noun)] is worn out. Fit a new one.</span>")
		return TRUE
	for (var/slot in slots)
		if (machine_slot_wear(M, slot) >= MACHINE_PART_FAILING && prob(MACHINE_JAM_CHANCE))
			var/obj/item/machine_part/part = slots[slot][1]
			M.visible_message("<span class='warning'>\The [M] jams on its failing [initial(part.part_noun)].</span>")
			return TRUE
	return FALSE

// Charge wear for work done. A part lasts as long as its material does against the standard one.
/proc/machine_wear(obj/structure/M, jobs = 1)
	var/list/slots = machine_slots(M)
	for (var/slot in slots)
		var/list/fill = machine_slot_fill(M, slot)
		var/obj/item/machine_part/part = slots[slot][1]
		var/role = initial(part.part_role)
		var/list/standard = part_rating(role, slots[slot][2])
		var/list/rated = part_rating(role, fill[1])
		var/life = (standard && rated && standard[2] > 0) ? rated[2] / standard[2] : 1
		var/expected = jobs * MACHINE_PART_WORN_OUT / (MACHINE_PART_BASE_LIFE * max(0.05, life))
		var/add = round(expected)
		if (prob((expected - add) * 100))
			add++
		if (add > 0)
			machine_set_slot_wear(M, slot, machine_slot_wear(M, slot) + add)

/proc/machine_wear_word(wear)
	if (wear >= MACHINE_PART_WORN_OUT)
		return "worn out"
	if (wear >= MACHINE_PART_FAILING)
		return "failing"
	if (wear >= MACHINE_PART_WORN)
		return "worn"
	return "sound"

/proc/machine_examine_parts(obj/structure/M, mob/user)
	var/list/slots = machine_slots(M)
	if (!slots)
		return
	var/list/lines = list()
	for (var/slot in slots)
		var/list/fill = machine_slot_fill(M, slot)
		var/obj/item/machine_part/part = slots[slot][1]
		var/material/mat = get_material_by_name(fill[1])
		lines += "[fill[2] ? "precise " : ""][mat ? mat.display_name : fill[1]] [initial(part.part_noun)] ([machine_wear_word(machine_slot_wear(M, slot))])"
	to_chat(user, "Its parts: [english_list(lines)]. It works at [round(machine_performance(M) * 100)]% of its usual rate. Use a gear set, shaft or bearing on it to fit a replacement.")

// Fit a part item into the slot it belongs to. TRUE when the item was handled.
/proc/machine_install_part(obj/structure/M, obj/item/machine_part/P, mob/living/human/H)
	var/list/slots = machine_slots(M)
	if (!slots || !istype(P) || !istype(H))
		return FALSE
	var/target = null
	for (var/slot in slots)
		if (slots[slot][1] == P.type)
			target = slot
	if (!target)
		to_chat(H, "<span class='warning'>\The [M] has no place for \a [P].</span>")
		return TRUE
	if (!P.rating())
		to_chat(H, "<span class='warning'>\The [P] is useless: [part_refusal(P.part_role, P.part_material)].</span>")
		return TRUE
	if (P.wear >= MACHINE_PART_WORN_OUT)
		to_chat(H, "<span class='warning'>\The [P] is worn out.</span>")
		return TRUE
	H.visible_message("<span class='notice'>[H] starts fitting \a [P] to \the [M].</span>")
	if (!do_after(H, 40, M) || QDELETED(M) || QDELETED(P) || P.loc != H)
		return TRUE
	var/list/old = machine_slot_fill(M, target)
	var/old_wear = machine_slot_wear(M, target)
	var/list/fills = machine_key_fills(M.part_key)
	var/list/entries = list()
	for (var/slot in slots)
		if (slot == target)
			entries += "[slot]=[P.part_material][P.precise ? "+" : ""]"
		else if (fills && fills[slot])
			entries += "[slot]=[fills[slot][1]][fills[slot][2] ? "+" : ""]"
	M.part_key = jointext(entries, ";")
	machine_set_slot_wear(M, target, P.wear)
	// Only a part someone fitted comes back out; the one a machine was built with is scrap.
	if (old[3])
		var/part_type = slots[target][1]
		var/obj/item/machine_part/out = new part_type(get_turf(M), old[1])
		out.precise = old[2]
		out.wear = old_wear
		out.apply_part_material()
	to_chat(H, "<span class='notice'>You fit \the [P] to \the [M].</span>")
	H.drop_from_inventory(P)
	qdel(P)
	return TRUE

// Taking a machine apart hands back the parts someone fitted, with their wear.
// The parts it was built with are scrap, and so is a worn-out one.
/proc/machine_drop_fitted_parts(obj/structure/M)
	var/list/slots = machine_slots(M)
	if (!slots || !M.part_key)
		return
	var/turf/T = get_turf(M)
	for (var/slot in slots)
		var/list/fill = machine_slot_fill(M, slot)
		var/wear = machine_slot_wear(M, slot)
		if (!T || !fill[3] || wear >= MACHINE_PART_WORN_OUT)
			continue
		var/part_type = slots[slot][1]
		var/obj/item/machine_part/out = new part_type(T, fill[1])
		out.precise = fill[2]
		out.wear = wear
		out.apply_part_material()
	M.part_key = null
	M.part_wear = 0

// --- The first machines with slots. Each wraps its own procs; the bodies in
// code/modules/1713/production.dm are untouched apart from the speed hooks.

/obj/structure/mill/examine(mob/user, distance)
	..(user, distance)
	machine_examine_parts(src, user)

/obj/structure/mill/attackby(obj/item/W, mob/living/human/H)
	if (istype(W, /obj/item/machine_part) && machine_install_part(src, W, H))
		return
	..(W, H)

/obj/structure/mill/produce(obj/item/weapon/reagent_containers/W, mob/living/human/H, obj/item/weapon/reagent_containers/P)
	if (machine_work_refusal(src, H))
		return
	..(W, H, P)

/obj/structure/mill/finish_work()
	if (current_work)
		machine_wear(src)
	..()

/obj/structure/sawmill/examine(mob/user, distance)
	..(user, distance)
	machine_examine_parts(src, user)

/obj/structure/sawmill/attackby(obj/item/stack/W, mob/living/human/H, obj/item/I)
	if (istype(W, /obj/item/machine_part) && machine_install_part(src, W, H))
		return
	..(W, H, I)

/obj/structure/sawmill/produce(obj/item/stack/W, mob/living/human/H, obj/item/stack/P)
	if (machine_work_refusal(src, H))
		return
	..(W, H, P)

/obj/structure/sawmill/finish_work()
	if (current_work)
		machine_wear(src)
	..()

/obj/structure/loom/examine(mob/user, distance)
	..(user, distance)
	machine_examine_parts(src, user)

/obj/structure/loom/attackby(obj/item/W, mob/living/human/H)
	if (istype(W, /obj/item/machine_part) && machine_install_part(src, W, H))
		return
	..(W, H)

/obj/structure/loom/produce(obj/item/stack/W, mob/living/human/H, obj/item/stack/P)
	if (machine_work_refusal(src, H))
		return
	..(W, H, P)

/obj/structure/loom/finish_work()
	if (current_work)
		machine_wear(src)
	..()


// The press: its screw wears with every finished run. The bodies in
// production.dm and research_tree/ are untouched apart from the speed hooks.
/obj/structure/printingpress/examine(mob/user, distance = -1)
	. = ..(user, distance)
	machine_examine_parts(src, user)

/obj/structure/printingpress/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/machine_part) && machine_install_part(src, W, user))
		return
	return ..(W, user)

/obj/structure/printingpress/attack_hand(var/mob/living/human/H)
	if (copying)
		return ..(H)
	var/loaded = length(base) && length(copy)
	if (loaded && machine_work_refusal(src, H))
		return
	var/started = world.time
	. = ..(H)
	// A run that took its time and used up the blank stock was a print.
	if (loaded && !QDELETED(src) && !length(copy) && world.time - started >= 50)
		machine_wear(src)

// Generators: output follows the weakest part, and running wears the set slowly.
/obj/structure/civ_generator/examine(mob/user)
	..(user)
	machine_examine_parts(src, user)

/obj/structure/civ_generator/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/machine_part) && machine_install_part(src, W, user))
		return
	..(W, user)

/obj/structure/civ_generator/settle_generation()
	..()
	if (output_power > 0 && prob(MACHINE_RUNNING_WEAR_CHANCE))
		machine_wear(src, 100 / (MACHINE_RUNNING_WEAR_CHANCE * MACHINE_RUNNING_JOB_SECONDS))

/obj/structure/civ_generator/wind/rated_output()
	return round(..() * machine_performance(src), 0.1)

/obj/structure/civ_generator/waterwheel/rated_output()
	return round(..() * machine_performance(src), 0.1)
