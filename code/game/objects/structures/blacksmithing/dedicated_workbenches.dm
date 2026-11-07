// Dedicated recipe benches built on the tool assembly workbench: each is set to
// one recipe at a time, and choosing another recipe returns whatever is stored.
// Inputs are the same parts hand crafting uses, so costs are unchanged.

// Weapon heads from the anvil plus a handle. Keeps head material, quality and
// wear the same way the tool bench does.
/obj/structure/component_workbench/weapon
	name = "weapon assembly workbench"
	desc = "Select a weapon, insert its head and a handle, then assemble it. Inputs and finished weapons can be retrieved."
	color = "#c8a27a"
	selected_tool = "Spear"

/obj/structure/component_workbench/weapon/tool_recipes()
	return list("Spear" = /obj/item/weapon/material/spear, "Battle axe" = /obj/item/weapon/material/hatchet/battleaxe, "Throwing axe" = /obj/item/weapon/material/thrown/throwing_axe)

/obj/structure/component_workbench/weapon/after_load()
	..()
	if (!(selected_tool in tool_recipes())) selected_tool = "Spear"

/obj/structure/component_workbench/weapon/accepts_head(obj/item/weapon/material/part/P)
	var/list/recipes = tool_recipes()
	for (var/choice in recipes)
		if (recipes[choice] == P.result) return TRUE
	return FALSE

#define FLETCHING_MAX_SHAFTS 20
#define FLETCHING_TICKS_PER_SHAFT 5

// Arrow or bolt shafts plus arrowheads (or sharpened flint). One action fits
// every loaded shaft that has a head; finished ammunition drops on the bench's
// tile, so the bench can be reloaded and worked again without retrieving.
/obj/structure/component_workbench/fletching
	name = "fletcher's bench"
	desc = "Select arrows or crossbow bolts, load shafts and arrowheads or sharpened flint, then fletch them all at once. Finished ammunition is left beside the bench."
	color = "#a7b88a"
	selected_tool = "Arrows"
	assembly_time = FLETCHING_TICKS_PER_SHAFT

/obj/structure/component_workbench/fletching/tool_recipes()
	return list("Arrows" = /obj/item/ammo_casing/arrow, "Crossbow bolts" = /obj/item/ammo_casing/bolt)

/obj/structure/component_workbench/fletching/after_load()
	..()
	if (!(selected_tool in tool_recipes())) selected_tool = "Arrows"

/obj/structure/component_workbench/fletching/can_use(mob/living/human/H)
	return !QDELETED(src) && ..() && !QDELETED(H) && anchored && !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required

// Finished ammunition for one shaft of shaft_type fitted with head, or null.
// Mirrors the hand route in _ammo_casing.dm.
/obj/structure/component_workbench/fletching/proc/fletched_type(obj/item/head, shaft_type)
	if (QDELETED(head)) return null
	var/suffix
	if (istype(head, /obj/item/weapon/flint))
		var/obj/item/weapon/flint/F = head
		if (!(head.type in list(/obj/item/weapon/flint, /obj/item/weapon/flint/sharpened)) || !F.sharpened) return null
		suffix = "flint"
	else
		var/list/heads = list(/obj/item/stack/arrowhead/stone = "stone", /obj/item/stack/arrowhead/copper = "copper", /obj/item/stack/arrowhead/iron = "iron", /obj/item/stack/arrowhead/bronze = "bronze", /obj/item/stack/arrowhead/steel = "steel", /obj/item/stack/arrowhead/vial = "vial")
		suffix = heads[head.type]
		if (!suffix) return null
		var/obj/item/stack/S = head
		if (S.amount < 1) return null
	return text2path("[shaft_type]/[suffix]")

/obj/structure/component_workbench/fletching/proc/shaft_type()
	return tool_recipes()[selected_tool]

/obj/structure/component_workbench/fletching/proc/is_shaft(obj/item/I)
	return I && !QDELETED(I) && I.type == shaft_type()

/obj/structure/component_workbench/fletching/proc/stored_shafts()
	var/list/result = list()
	for (var/obj/item/I in contents)
		if (is_shaft(I)) result += I
	return result

// Heads in fitting order. Only one kind is stored at a time.
/obj/structure/component_workbench/fletching/proc/stored_heads()
	var/list/result = list()
	for (var/obj/item/I in contents)
		if (!is_shaft(I) && fletched_type(I, shaft_type())) result += I
	return result

/obj/structure/component_workbench/fletching/proc/head_units(list/heads)
	var/total = 0
	for (var/obj/item/I in heads)
		total += istype(I, /obj/item/stack) ? I:amount : 1
	return total

/obj/structure/component_workbench/fletching/proc/ready_count()
	return min(stored_shafts().len, head_units(stored_heads()))

/obj/structure/component_workbench/fletching/proc/head_fits(obj/item/I)
	if (!fletched_type(I, shaft_type())) return FALSE
	for (var/obj/item/stored in stored_heads())
		if (istype(I, /obj/item/stack) || !istype(stored, /obj/item/weapon/flint)) return FALSE
	return TRUE

/obj/structure/component_workbench/fletching/insert(obj/item/I, mob/living/human/H)
	if (busy || !can_use(H) || QDELETED(I) || I.loc != H || !H.item_is_in_hands(I)) return FALSE
	if (is_shaft(I))
		if (stored_shafts().len >= FLETCHING_MAX_SHAFTS) return FALSE
	else if (!head_fits(I))
		return FALSE
	else if (!istype(I, /obj/item/stack) && head_units(stored_heads()) >= FLETCHING_MAX_SHAFTS)
		return FALSE
	// No floor staging: stack Crossed hooks could merge away a loaded stack.
	return H.transfer_held_item_to(I, src) && I.loc == src

/obj/structure/component_workbench/fletching/attackby(obj/item/I, mob/living/human/H)
	if (insert(I, H)) to_chat(H, "You load [I] into [src].")
	else to_chat(H, "Hold a bare [selected_tool == "Arrows" ? "arrow" : "bolt"] shaft, one stack of arrowheads or sharpened flint. The bench takes [FLETCHING_MAX_SHAFTS] shafts and one kind of head at a time.")

// Gathers loose bare shafts from the bench's tile and the user's tile.
/obj/structure/component_workbench/fletching/proc/load_from_floor(mob/living/human/H)
	if (busy || !can_use(H)) return 0
	var/loaded = 0
	var/room = FLETCHING_MAX_SHAFTS - stored_shafts().len
	for (var/turf/T in list(get_turf(src), get_turf(H)))
		for (var/obj/item/I in T)
			if (room <= 0) break
			if (!is_shaft(I) || I.anchored) continue
			I.forceMove(src)
			if (I.loc == src)
				loaded++
				room--
	return loaded

/obj/structure/component_workbench/fletching/proc/commit_fletching(mob/living/human/H, choice, count, turf/site, datum/epoch)
	if (!busy || cancelled || assembler != H || !can_use(H) || loc != site || selected_tool != choice || epoch != persistence_admission_identity) return 0
	var/list/shafts = stored_shafts()
	var/list/heads = stored_heads()
	count = min(count, shafts.len, head_units(heads))
	if (count <= 0) return 0
	// Claim completion before payment. No sleeps from validation to output.
	cancelled = TRUE
	var/turf/T = get_turf(src)
	var/made = 0
	for (var/obj/item/shaft in shafts)
		if (made >= count) break
		var/obj/item/head = null
		for (var/obj/item/candidate in heads)
			if (fletched_type(candidate, shaft.type))
				head = candidate
				break
		if (!head) break
		var/result_type = fletched_type(head, shaft.type)
		if (istype(head, /obj/item/stack))
			var/obj/item/stack/S = head
			if (!S.use(1)) break
			if (QDELETED(S)) heads -= S
		else
			heads -= head
			qdel(head)
		qdel(shaft)
		new result_type(T)
		made++
	return made

/obj/structure/component_workbench/fletching/assemble(mob/living/human/H)
	if (busy || !can_use(H)) return 0
	var/count = ready_count()
	if (count <= 0) return 0
	var/choice = selected_tool
	var/turf/site = loc
	var/datum/epoch = persistence_admission_identity
	busy = TRUE
	cancelled = FALSE
	assembler = H
	var/made = 0
	if (do_after(H, assembly_time * count, src)) made = commit_fletching(H, choice, count, site, epoch)
	busy = FALSE
	assembler = null
	cancelled = FALSE
	if (made) to_chat(H, "You fletch [made] [lowertext(selected_tool)]. They are beside [src].")
	return made

/obj/structure/component_workbench/fletching/proc/recipe_status()
	var/list/heads = stored_heads()
	var/obj/item/head = heads.len ? heads[1] : null
	return "[selected_tool]: [stored_shafts().len]/[FLETCHING_MAX_SHAFTS] shafts, [head_units(heads)] [head ? head.name : "heads"]. [ready_count()] ready to fletch. [busy ? "Working" : "Idle"]. Retrieve returns stored items and cancels work."

/obj/structure/component_workbench/fletching/attack_hand(mob/living/human/H)
	if (!can_use(H)) return
	var/list/options = list("Status", "Retrieve / cancel")
	if (!busy) options += list("Select recipe", "Load shafts from floor")
	if (!busy && ready_count()) options += "Fletch"
	var/action = input(H, recipe_status(), name) as null|anything in options
	if (!can_use(H)) return
	switch (action)
		if ("Retrieve / cancel") retrieve(H)
		if ("Status") to_chat(H, recipe_status())
		if ("Select recipe") recipe_prompt(H)
		if ("Load shafts from floor") to_chat(H, "You load [load_from_floor(H)] shafts into [src].")
		if ("Fletch") assemble(H)

#undef FLETCHING_MAX_SHAFTS
#undef FLETCHING_TICKS_PER_SHAFT
