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
		var/list/heads = list(/obj/item/stack/arrowhead/stone = "stone", /obj/item/stack/arrowhead/copper = "copper", /obj/item/stack/arrowhead/iron = "iron", /obj/item/stack/arrowhead/bronze = "bronze", /obj/item/stack/arrowhead/steel = "steel", /obj/item/stack/arrowhead/vial = "vial", /obj/item/stack/arrowhead/flint = "flint")
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
		if (!crafting_recipe_allowed(H, "[result_type]")) break
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
	var/list/heads = stored_heads()
	if (!heads.len || !crafting_recipe_allowed(H, "[fletched_type(heads[1], shaft_type())]")) return 0
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

#define TOOLSMITH_MAX_BATCH 5

// Streamlined route: smelted metal and soft wood straight into finished tools,
// skipping the separate head and handle steps. Ores must be smelted first.
// Each tool costs the anvil head's metal plus one wood for the handle, takes
// longer than the two hand steps, and needs an anchored anvil beside the bench
// whose accepted metals limit what can be worked, so anvil tiers still gate
// steel. Smithing admission mirrors /obj/structure/anvil/attackby.
/obj/structure/component_workbench/toolsmith
	name = "toolsmith's bench"
	desc = "Select a tool, load smelted metal and soft wood, and work beside an anvil to make finished tools in one step. Slower than smithing a head and fitting a handle; finished tools are left beside the bench."
	color = "#9aa3ad"
	selected_tool = "Hatchet"
	assembly_time = 100 // per tool, plus 15 per metal sheet

/obj/structure/component_workbench/toolsmith/proc/toolsmith_recipes()
	return list(
		"Hatchet" = list("result" = /obj/item/weapon/material/hatchet, "metal" = 3, "max_age" = 8),
		"Pickaxe" = list("result" = /obj/item/weapon/material/pickaxe, "metal" = 3, "max_age" = 8),
		"Shovel" = list("result" = /obj/item/weapon/material/shovel, "metal" = 2, "max_age" = 8),
		"Spear" = list("result" = /obj/item/weapon/material/spear, "metal" = 3, "max_age" = 8),
		"Throwing axe" = list("result" = /obj/item/weapon/material/thrown/throwing_axe, "metal" = 3, "max_age" = 8),
		"Battle axe" = list("result" = /obj/item/weapon/material/hatchet/battleaxe, "metal" = 8, "max_age" = 3))

/obj/structure/component_workbench/toolsmith/tool_recipes()
	return toolsmith_recipes()

/obj/structure/component_workbench/toolsmith/after_load()
	..()
	if (!(selected_tool in toolsmith_recipes())) selected_tool = "Hatchet"

/obj/structure/component_workbench/toolsmith/can_use(mob/living/human/H)
	return !QDELETED(src) && ..() && !QDELETED(H) && anchored && !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required

/obj/structure/component_workbench/toolsmith/proc/metal_types()
	return list(/obj/item/stack/material/copper = "copper", /obj/item/stack/material/bronze = "bronze", /obj/item/stack/material/iron = "iron", /obj/item/stack/material/steel = "steel")

/obj/structure/component_workbench/toolsmith/proc/find_anvil()
	for (var/obj/structure/anvil/A in range(1, src))
		if (A.anchored && !QDELETED(A)) return A

// Exact smelted sheet types only; relabelled subtypes and ores are refused.
/obj/structure/component_workbench/toolsmith/proc/metal_name(obj/item/I)
	if (!istype(I, /obj/item/stack/material) || QDELETED(I)) return null
	var/name_for_type = metal_types()[I.type]
	var/obj/item/stack/material/S = I
	var/material/M = S.get_material()
	return (name_for_type && M && M.name == name_for_type && S.amount == round(S.amount) && S.amount > 0) ? name_for_type : null

/obj/structure/component_workbench/toolsmith/proc/is_wood(obj/item/I)
	if (!I || QDELETED(I) || I.type != /obj/item/stack/material/wood) return FALSE
	var/obj/item/stack/material/S = I
	var/material/M = S.get_material()
	return M && M.name == "wood" && S.amount == round(S.amount) && S.amount > 0

/obj/structure/component_workbench/toolsmith/proc/stored_metal()
	for (var/obj/item/stack/material/S in contents)
		if (metal_name(S)) return S

/obj/structure/component_workbench/toolsmith/proc/stored_wood()
	for (var/obj/item/stack/material/S in contents)
		if (is_wood(S)) return S

// Mirrors the anvil's crafting-skill and job admission so the bench is not a
// way around who may smith. Returns a refusal message, or null when allowed.
/obj/structure/component_workbench/toolsmith/proc/smith_refusal(mob/living/human/H)
	var/crafting_coefficient = H.getStatCoeff("crafting")
	if (crafting_coefficient < 1.2)
		return "Smithing tools requires an effective Crafting coefficient of at least 1.20x; yours is [num2text(crafting_coefficient, 9)]x. Check IC > Skill Progress for Crafting progress; mood and traits affect the effective coefficient."
	if (map && !map.civilizations && map.ID != MAP_TRIBES && map.ID != MAP_THREE_TRIBES && map.ID != MAP_FOUR_KINGDOMS && map.ID != MAP_GULAG13 && !(H.original_job_title in list("Blacksmith", "Pioneer Blacksmith", "Town Blacksmith", "Ferreiro", "Ferrero", "Grofsmid", "Forgeron", "British Blacksmith", "Marooned Pirate Crew", "Schmied")))
		return "Your job is not permitted to smith on this map. Ask a blacksmith."
	if (map && (map.ID == MAP_TRIBES || map.ID == MAP_THREE_TRIBES || map.ID == MAP_FOUR_KINGDOMS) && (H.gorillaman || H.ant || H.wolfman || H.lizard || H.crab))
		return "You don't know how to use this."
	return null

/obj/structure/component_workbench/toolsmith/proc/recipe_research_allowed(mob/living/human/H, choice)
	var/list/R = toolsmith_recipes()[choice]
	return R && crafting_recipe_allowed(H, "[R["result"]]")

/obj/structure/component_workbench/toolsmith/proc/recipe_available(choice)
	var/list/R = toolsmith_recipes()[choice]
	return R && recipe_age_allowed(R["max_age"])

// Tools the current stock covers for choice, up to one batch. Zero without an
// anvil that accepts the loaded metal.
/obj/structure/component_workbench/toolsmith/proc/ready_count(choice)
	var/list/R = toolsmith_recipes()[choice]
	var/obj/item/stack/material/metal = stored_metal()
	var/obj/item/stack/material/wood = stored_wood()
	var/obj/structure/anvil/A = find_anvil()
	if (!R || !metal || !wood || !A || !(metal_name(metal) in A.accepted_materials)) return 0
	return min(TOOLSMITH_MAX_BATCH, round(metal.amount / R["metal"]), wood.amount)

/obj/structure/component_workbench/toolsmith/insert(obj/item/I, mob/living/human/H)
	if (busy || !can_use(H) || QDELETED(I) || I.loc != H || !H.item_is_in_hands(I)) return FALSE
	if (metal_name(I))
		if (stored_metal()) return FALSE
	else if (is_wood(I))
		if (stored_wood()) return FALSE
	else
		return FALSE
	// No floor staging: stack Crossed hooks could merge away a loaded stack.
	return H.transfer_held_item_to(I, src) && I.loc == src

/obj/structure/component_workbench/toolsmith/attackby(obj/item/I, mob/living/human/H)
	if (insert(I, H)) to_chat(H, "You load [I] onto [src].")
	else to_chat(H, "Hold smelted copper, bronze, iron or steel, or soft wood planks. The bench takes one stack of metal and one of wood.")

// Pays for and makes one tool. No sleeps from validation to output.
/obj/structure/component_workbench/toolsmith/proc/commit_tool(mob/living/human/H, choice, turf/site, datum/epoch, metal_kind)
	if (!busy || cancelled || assembler != H || !can_use(H) || loc != site || selected_tool != choice || epoch != persistence_admission_identity || !recipe_available(choice) || !recipe_research_allowed(H, choice) || smith_refusal(H)) return null
	if (ready_count(choice) < 1) return null
	var/list/R = toolsmith_recipes()[choice]
	var/obj/item/stack/material/metal = stored_metal()
	var/obj/item/stack/material/wood = stored_wood()
	if (metal_name(metal) != metal_kind) return null
	if (!metal.can_use(R["metal"]) || !wood.can_use(1)) return null
	metal.use(R["metal"])
	wood.use(1)
	var/result_type = R["result"]
	return new result_type(get_turf(src), metal_kind)

/obj/structure/component_workbench/toolsmith/assemble(mob/living/human/H)
	if (busy || !can_use(H) || !recipe_available(selected_tool) || !recipe_research_allowed(H, selected_tool)) return 0
	var/refusal = smith_refusal(H)
	if (refusal)
		to_chat(H, refusal)
		return 0
	var/count = ready_count(selected_tool)
	if (count <= 0) return 0
	var/choice = selected_tool
	var/turf/site = loc
	var/datum/epoch = persistence_admission_identity
	var/metal_kind = metal_name(stored_metal())
	var/list/R = toolsmith_recipes()[choice]
	busy = TRUE
	cancelled = FALSE
	assembler = H
	var/made = 0
	// One wait per tool: cancelling keeps the tools already finished.
	for (var/i in 1 to count)
		if (!do_after(H, assembly_time + 15 * R["metal"], src)) break
		if (!commit_tool(H, choice, site, epoch, metal_kind)) break
		made++
	busy = FALSE
	assembler = null
	cancelled = FALSE
	if (made) to_chat(H, "You make [made] [metal_kind] [lowertext(choice)][made > 1 ? "s" : ""]. They are beside [src].")
	return made

/obj/structure/component_workbench/toolsmith/proc/recipe_status()
	var/list/R = toolsmith_recipes()[selected_tool]
	var/obj/item/stack/material/metal = stored_metal()
	var/obj/item/stack/material/wood = stored_wood()
	var/obj/structure/anvil/A = find_anvil()
	return "[selected_tool]: [R["metal"]] metal and 1 wood each. Loaded: [metal ? "[metal.amount] [metal_name(metal)]" : "no metal"], [wood ? wood.amount : 0] wood. [A ? "Anvil: [A.name]." : "Needs an anchored anvil beside the bench."] [ready_count(selected_tool)] ready. [busy ? "Working" : "Idle"]. Retrieve returns stored items and cancels work."

/obj/structure/component_workbench/toolsmith/attack_hand(mob/living/human/H)
	if (!can_use(H)) return
	var/list/options = list("Status", "Retrieve / cancel")
	if (!busy) options += "Select recipe"
	if (!busy && recipe_available(selected_tool) && ready_count(selected_tool)) options += "Make tools"
	var/action = input(H, recipe_status(), name) as null|anything in options
	if (!can_use(H)) return
	switch (action)
		if ("Retrieve / cancel") retrieve(H)
		if ("Status") to_chat(H, recipe_status())
		if ("Select recipe") recipe_prompt(H)
		if ("Make tools") assemble(H)

#undef TOOLSMITH_MAX_BATCH

#define FOUNDRY_MAX_BATCH 10
#define FOUNDRY_MIN_AGE 4

// Industrial casting: pour molten copper, bronze, iron or steel from a fired
// blacksmith pot or jug (melted in a kiln) into the selected tool cast, fit a
// wooden handle and repeat. Same metal and wood per tool as the toolsmith's
// bench, but faster and in bigger batches, with no anvil and no smithing skill.
// Needs the industrial age and Machined Tools research.
/obj/structure/component_workbench/toolsmith/foundry
	name = "casting foundry"
	desc = "Select a tool, set down a pot or jug of molten metal and load soft wood, then cast finished tools in batches. Finished tools are left beside the foundry."
	icon = 'icons/obj/metallurgy.dmi'
	icon_state = "blast_furnace"
	assembly_time = 30 // per tool, plus 15 per unit of metal

/obj/structure/component_workbench/toolsmith/foundry/proc/is_pot(obj/item/I)
	return istype(I, /obj/item/weapon/clay/mold/claypot/fired) || istype(I, /obj/item/weapon/clay/mold/clayjug/fired)

/obj/structure/component_workbench/toolsmith/foundry/metal_name(obj/item/I)
	if (!is_pot(I) || QDELETED(I)) return null
	var/obj/item/weapon/clay/mold/pot = I
	if (!pot.fired || pot.capacity < 1 || pot.capacity != round(pot.capacity)) return null
	for (var/sheet in metal_types())
		if (metal_types()[sheet] == pot.current_material) return pot.current_material
	return null

/obj/structure/component_workbench/toolsmith/foundry/stored_metal()
	for (var/obj/item/weapon/clay/mold/pot in contents)
		if (metal_name(pot)) return pot

/obj/structure/component_workbench/toolsmith/foundry/proc/stored_pot()
	for (var/obj/item/weapon/clay/mold/pot in contents)
		if (is_pot(pot)) return pot

/obj/structure/component_workbench/toolsmith/foundry/smith_refusal(mob/living/human/H)
	if (!map || map.ordinal_age < FOUNDRY_MIN_AGE)
		return "Casting tools needs the industrial age."
	if (!crafting_node_allowed(H, "machined_tools"))
		return "Casting tools needs Machined Tools research."
	return null

/obj/structure/component_workbench/toolsmith/foundry/ready_count(choice)
	var/list/R = toolsmith_recipes()[choice]
	var/obj/item/weapon/clay/mold/pot = stored_metal()
	var/obj/item/stack/material/wood = stored_wood()
	if (!R || !pot || !wood) return 0
	return min(FOUNDRY_MAX_BATCH, round(pot.capacity / R["metal"]), wood.amount)

/obj/structure/component_workbench/toolsmith/foundry/insert(obj/item/I, mob/living/human/H)
	if (busy || !can_use(H) || QDELETED(I) || I.loc != H || !H.item_is_in_hands(I)) return FALSE
	if (metal_name(I))
		if (stored_pot()) return FALSE
	else if (is_wood(I))
		if (stored_wood()) return FALSE
	else
		return FALSE
	return H.transfer_held_item_to(I, src) && I.loc == src

/obj/structure/component_workbench/toolsmith/foundry/attackby(obj/item/I, mob/living/human/H)
	if (insert(I, H)) to_chat(H, "You set [I] in [src].")
	else to_chat(H, "Hold a pot or jug of molten copper, bronze, iron or steel from a kiln, or soft wood planks. The foundry takes one vessel and one stack of wood.")

// Pours and makes one tool. No sleeps from validation to output.
/obj/structure/component_workbench/toolsmith/foundry/commit_tool(mob/living/human/H, choice, turf/site, datum/epoch, metal_kind)
	if (!busy || cancelled || assembler != H || !can_use(H) || loc != site || selected_tool != choice || epoch != persistence_admission_identity || !recipe_available(choice) || !recipe_research_allowed(H, choice) || smith_refusal(H)) return null
	if (ready_count(choice) < 1) return null
	var/list/R = toolsmith_recipes()[choice]
	var/obj/item/weapon/clay/mold/pot = stored_metal()
	var/obj/item/stack/material/wood = stored_wood()
	if (metal_name(pot) != metal_kind || pot.capacity < R["metal"] || !wood.can_use(1)) return null
	pot.capacity -= R["metal"]
	if (pot.capacity <= 0)
		pot.capacity = 0
		pot.current_material = null
	pot.update_icon()
	wood.use(1)
	var/result_type = R["result"]
	return new result_type(get_turf(src), metal_kind)

/obj/structure/component_workbench/toolsmith/foundry/recipe_status()
	var/list/R = toolsmith_recipes()[selected_tool]
	var/obj/item/weapon/clay/mold/pot = stored_pot()
	var/obj/item/stack/material/wood = stored_wood()
	return "[selected_tool]: [R["metal"]] units of molten metal and 1 wood each. Loaded: [pot ? "[pot.name] with [pot.capacity] [pot.current_material ? pot.current_material : "empty"]" : "no metal vessel"], [wood ? wood.amount : 0] wood. Needs the industrial age and Machined Tools. [ready_count(selected_tool)] ready. [busy ? "Working" : "Idle"]. Retrieve returns stored items and cancels work."

#undef FOUNDRY_MAX_BATCH
#undef FOUNDRY_MIN_AGE

/obj/structure/component_workbench/toolsmith/foundry/recipe_manual_hint(mob/living/human/H, choice)
	var/hint = ..()
	var/foundry_hint = crafting_node_manual_hint(H, "machined_tools")
	return hint && foundry_hint ? "[hint]; [foundry_hint]" : "[hint][foundry_hint]"
