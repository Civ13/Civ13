// Before the loader guard (#3570), limbs first built through another limb's
// saved field deleted themselves during import while still listed in `organs`.
// Bodies saved after such a load keep those entries as nulls or as deleted,
// unplaced limbs. Ordinary amputation removes the limb from `organs` and leaves
// a stump or a parent wound, so such an entry identifies only that import
// damage. Drop the dead entries and rebuild the missing limbs.
/mob/living/human/after_load()
	. = ..()
	repair_import_lost_limbs()

/mob/living/human/proc/repair_import_lost_limbs()
	if (!islist(organs))
		return 0
	var/list/dead = list()
	for (var/i = 1, i <= organs.len, i++)
		var/obj/item/organ/external/E = organs[i]
		if (!E || QDELETED(E) || E.loc != src)
			dead += i
	if (!dead.len)
		return 0
	for (var/i = dead.len, i >= 1, i--)
		var/obj/item/organ/external/E = organs[dead[i]]
		organs.Cut(dead[i], dead[i] + 1)
		if (E && islist(organs_by_name) && organs_by_name[E.limb_name] == E)
			organs_by_name[E.limb_name] = null
		if (E && E.parent && islist(E.parent.children))
			E.parent.children -= E
	if (!species || !islist(species.has_limbs) || !islist(organs_by_name))
		return 0
	var/rebuilt = 0
	// Species tables list each parent before its children.
	for (var/limb_tag in species.has_limbs)
		var/obj/item/organ/external/current = organs_by_name[limb_tag]
		if (current && !QDELETED(current))
			continue
		var/list/organ_data = species.has_limbs[limb_tag]
		var/limb_path = organ_data["path"]
		if (!ispath(limb_path, /obj/item/organ/external))
			continue
		var/obj/item/organ/external/limb_type = limb_path
		var/required_parent = initial(limb_type.parent_organ)
		if (required_parent)
			var/obj/item/organ/external/parent_limb = organs_by_name[required_parent]
			if (!parent_limb || QDELETED(parent_limb))
				continue
		var/obj/item/organ/external/E = new limb_path(src)
		if (QDELETED(E) || organs_by_name[limb_tag] != E)
			continue
		for (var/obj/item/organ/O in internal_organs)
			if (O.parent_organ == limb_tag)
				if (!E.internal_organs)
					E.internal_organs = list()
				E.internal_organs |= O
		if (istype(E, /obj/item/organ/external/head) && species.teeth_type)
			var/obj/item/organ/external/head/H = E
			H.teeth_list.Cut()
			var/obj/item/stack/teeth/T = new species.teeth_type(H)
			H.max_teeth = T.max_amount
			T.amount = T.max_amount
			H.teeth_list += T
		rebuilt++
	if (rebuilt)
		regenerate_appearance()
	return rebuilt
