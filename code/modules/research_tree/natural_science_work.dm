// ============================================================
// Research Tree - Natural Science from mining, smelting and firing
// (player request relayed by Val, 2026-11-18)
// ------------------------------------------------------------
// Natural Science had no field work before its late subjects: foraging and
// butchering fed Agriculture, but striking ore, smelting it and firing clay
// and glass taught nothing. These count as field work (field_work.dm) for the
// Natural Science subjects that are about them, credited at a bench once per
// book like any other field work.
//   mining    an ore vein struck while mining (floor_attackby.dm)
//   smelting  each ore or metal in a bloomery, blast furnace or kiln firing
//             someone lights, and each iron sand in a tatara they light
//   firing    each unfired clay piece or load of glass sand in an oven firing
//             someone lights
// Counting happens when the fire is lit, with what is in it. An oven counts
// each piece once, so putting out a fireplace and lighting it again counts
// nothing more.
// ============================================================

// Ore and metal a bloomery or blast furnace firing smelts.
/obj/structure/furnace/proc/smelt_charge()
	return max(0, iron)

// A kiln melts the metal in its filled vessels.
/obj/structure/furnace/kiln/smelt_charge()
	. = 0
	for (var/obj/item/weapon/clay/mold/M in contents)
		if (!M.fired || M.capacity != 0 || !islist(M.contents_materials))
			continue
		for (var/metal in M.contents_materials)
			var/amount = M.contents_materials[metal]
			if (isnum(amount) && amount > 0)
				. += amount

// Lime burning is not smelting.
/obj/structure/furnace/lime_kiln/smelt_charge()
	return 0

/proc/note_smelting(mob/user, obj/structure/furnace/F)
	if (!istype(F))
		return FALSE
	var/amount = F.smelt_charge()
	return amount > 0 ? note_field_work(user, "smelting", amount) : FALSE

/obj/structure/oven
	var/tmp/list/firing_counted = null // \ref text of pieces already counted as firing

// Unfired clay and glass sand an oven firing will bake and that no earlier
// lighting counted. Marks them counted.
/obj/structure/oven/proc/firing_charge()
	. = 0
	var/list/kept = list()
	for (var/obj/item/I in contents)
		var/counts = istype(I, /obj/item/stack/ore/glass)
		if (istype(I, /obj/item/weapon/clay))
			var/obj/item/weapon/clay/C = I
			counts = C.result != C.type && !stone_mold_type(C.type)
		if (!counts)
			continue
		var/ref = "\ref[I]"
		kept += ref
		if (!islist(firing_counted) || !(ref in firing_counted))
			.++
	firing_counted = kept.len ? kept : null

/proc/note_firing(mob/user, obj/structure/oven/O)
	if (!istype(O))
		return FALSE
	var/amount = O.firing_charge()
	return amount > 0 ? note_field_work(user, "firing", amount) : FALSE
