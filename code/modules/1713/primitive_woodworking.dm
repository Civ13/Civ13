// Manual woodworking uses existing flint/knife, wooden mallet and handle art.
// One workable piece per log is a conservative abstraction, not quarter-log units.
// Reuse the water/save owner's admitted-operation identity. No second constructor.

/atom/movable
	var/tmp/datum/primitive_woodwork_action/woodwork_owner

/obj/item/stack/material/wood_piece
	name = "small wood piece"
	desc = "A workable piece of wood. Use sharpened flint or a knife harder than this wood to whittle a wooden wedge or mallet."
	icon_state = "sheet-wood"
	default_type = "wood_piece"
	value = 0
	flammable = TRUE

/obj/item/stack/material/wood_piece/update_strings()
	..()
	desc = initial(desc)

/obj/item/stack/material/crude_plank
	name = "crude plank"
	desc = "An uneven split plank. Flatten it with sharpened flint or another sharp non-wooden working material, without tool wear. It cannot substitute for finished planks."
	icon_state = "sheet-wood"
	default_type = "crude_plank"
	value = 0
	flammable = TRUE

/obj/item/stack/material/crude_plank/update_strings()
	..()
	desc = initial(desc)

/proc/woodwork_flattening_tool(obj/item/tool)
	if (QDELETED(tool) || !tool.sharp)
		return FALSE
	if (istype(tool, /obj/item/weapon/flint))
		var/obj/item/weapon/flint/F = tool
		return F.sharpened
	if (istype(tool, /obj/item/weapon/material) && tool.health <= 0)
		return FALSE
	var/material/working = woodwork_tool_material(tool)
	// get_material() describes the working head, not a wooden handle's material.
	if (working)
		return !istype(working, /material/wood)
	return woodwork_legacy_nonwood(tool)

/proc/woodwork_tool_material(obj/item/tool)
	if (QDELETED(tool))
		return null
	return tool.get_material()

/proc/woodwork_legacy_nonwood(obj/item/tool)
	// Exact reviewed types only. Recipe/working-blade evidence is recorded in
	// tests/primitive_woodworking/legacy-working-materials.json. This establishes
	// non-wood for flattening, not an instance's alloy, hardness or get_material().
	// Unknown subtypes, including future wooden variants, do not inherit approval.
	if (QDELETED(tool))
		return FALSE
	if (tool.type == /obj/item/weapon/surgery/scalpel/bronze || tool.type == /obj/item/weapon/surgery/bone_saw/bronze)
		return TRUE
	if (tool.type == /obj/item/weapon/surgery/scalpel || tool.type == /obj/item/weapon/surgery/bone_saw)
		return TRUE
	if (tool.type == /obj/item/weapon/wirecutters || tool.type == /obj/item/weapon/plough/iron)
		return TRUE
	if (tool.type == /obj/item/weapon/reagent_containers/syringe || tool.type == /obj/item/weapon/attachment/bayonet || tool.type == /obj/item/weapon/gun/projectile/ancient/firelance)
		return TRUE
	return tool.type == /obj/item/weapon/broken_bottle || tool.type == /obj/item/weapon/macuahuitl

/proc/woodwork_knife(obj/item/tool)
	return istype(tool, /obj/item/weapon/material/kitchen/utensil/knife) || istype(tool, /obj/item/weapon/material/thrown/throwing_knife) || istype(tool, /obj/item/weapon/material/thrown/throwing_knife1)

/obj/item/weapon/material/wooden_wedge
	name = "splitting wedge"
	desc = "A whittled wooden wedge. Hold it in your other hand while using a wooden hammer on logs to split planks."
	icon = 'icons/obj/old_weapons.dmi'
	icon_state = "sharpened_stick"
	item_state = "sharpened_stick"
	default_material = "wood"
	applies_material_colour = FALSE
	sharp = FALSE
	edge = FALSE
	force_divisor = 0.1

/proc/woodwork_shaping_tool(obj/item/tool, material/workpiece)
	if (QDELETED(tool) || !workpiece)
		return FALSE
	if (istype(tool, /obj/item/weapon/flint))
		var/obj/item/weapon/flint/F = tool
		return F.sharpened && F.sharp
	if (!woodwork_knife(tool) || !tool.sharp || tool.health <= 0)
		return FALSE
	var/material/blade = woodwork_tool_material(tool)
	return blade && blade.hardness > workpiece.hardness

/proc/woodwork_wooden_hammer(obj/item/tool)
	return !QDELETED(tool) && (tool.type == /obj/item/weapon/hammer || tool.type == /obj/item/weapon/hammer/tribalhammer)

/proc/woodwork_wedge(obj/item/tool)
	if (!istype(tool, /obj/item/weapon/material/wooden_wedge) || QDELETED(tool) || tool.health <= 0)
		return FALSE
	var/material/wood = tool.get_material()
	return wood && wood.name == "wood"

/proc/woodwork_spec(mode)
	switch(mode)
		if ("pieces")
			return list("cost" = 1, "count" = 1, "delay" = 120, "output" = /obj/item/stack/material/wood_piece, "bark" = 1)
		if ("wedge")
			return list("cost" = 1, "count" = 1, "delay" = 120, "output" = /obj/item/weapon/material/wooden_wedge, "bark" = 0)
		if ("mallet")
			return list("cost" = 5, "count" = 1, "delay" = 240, "output" = /obj/item/weapon/hammer/tribalhammer, "bark" = 0)
		if ("plank")
			return list("cost" = 2, "count" = 1, "delay" = 240, "output" = /obj/item/stack/material/crude_plank, "bark" = 2)
		if ("flatten")
			return list("cost" = 1, "count" = 1, "delay" = 80, "output" = /obj/item/stack/material/woodplank, "bark" = 0)
	return null

/proc/woodwork_begin(obj/item/stack/material/source, mob/living/human/user, obj/item/tool, mode)
	if (!istype(user) || QDELETED(source) || QDELETED(user) || QDELETED(tool) || source.woodwork_owner || user.woodwork_owner || tool.woodwork_owner)
		return FALSE
	var/datum/primitive_woodwork_action/action = new(source, user, tool, mode)
	if (!action.valid())
		qdel(action)
		return FALSE
	return action.perform()

/datum/primitive_woodwork_action
	should_save = FALSE
	var/obj/item/stack/material/source
	var/mob/living/human/user
	var/obj/item/tool
	var/obj/item/wedge
	var/mode
	var/list/spec
	var/atom/source_loc
	var/turf/site
	var/turf/user_site
	var/source_count
	var/tool_health
	var/wedge_health
	var/material/workpiece
	var/material/blade
	var/workpiece_hardness
	var/blade_hardness
	var/datum/save_epoch
	var/claimed = FALSE
	var/committed = FALSE

/datum/primitive_woodwork_action/New(obj/item/stack/material/S, mob/living/human/H, obj/item/T, action_mode)
	..()
	source = S
	user = H
	tool = T
	mode = action_mode
	spec = woodwork_spec(mode)
	source_loc = S.loc
	site = get_turf(S)
	user_site = get_turf(H)
	source_count = S.amount
	tool_health = T.health
	workpiece = S.get_material()
	if (workpiece)
		workpiece_hardness = workpiece.hardness
	blade = woodwork_tool_material(T)
	if (blade)
		blade_hardness = blade.hardness
	if (mode == "plank")
		wedge = H.l_hand == T ? H.r_hand : H.l_hand
		if (wedge)
			wedge_health = wedge.health
	save_epoch = persistence_admission_identity

/datum/primitive_woodwork_action/proc/valid()
	if (committed || !spec || QDELETED(source) || QDELETED(user) || QDELETED(tool))
		return FALSE
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required || save_epoch != persistence_admission_identity)
		return FALSE
	if (!hide_worker_can_reach(user, source) || user.incapacitated() || get_turf(user) != user_site || user.get_active_hand() != tool || tool.loc != user || tool.health != tool_health)
		return FALSE
	if (source.loc != source_loc || get_turf(source) != site || source.amount != source_count || source.amount < spec["cost"] || source.get_material() != workpiece || !workpiece || workpiece.hardness != workpiece_hardness)
		return FALSE
	// Small bounded integer stack counts keep every paid debit exact in DM numbers.
	if (source_count != round(source_count) || source_count > source.max_amount)
		return FALSE
	if (claimed)
		if (source.woodwork_owner != src || user.woodwork_owner != src || tool.woodwork_owner != src)
			return FALSE
	else if (source.woodwork_owner || user.woodwork_owner || tool.woodwork_owner)
		return FALSE
	if (mode == "pieces" || mode == "plank")
		if (!istype(source, /obj/item/stack/material/wood) || workpiece.name != "wood" || source:onfire || source:splitting_in_progress)
			return FALSE
	else if (mode == "flatten")
		if (!istype(source, /obj/item/stack/material/crude_plank))
			return FALSE
	else if (!istype(source, /obj/item/stack/material/wood_piece))
		return FALSE
	if (mode == "plank")
		if (!woodwork_wooden_hammer(tool) || !woodwork_wedge(wedge) || wedge.loc != user || !user.item_is_in_hands(wedge) || wedge.health != wedge_health)
			return FALSE
		return claimed ? wedge.woodwork_owner == src : !wedge.woodwork_owner
	if (mode == "flatten")
		return woodwork_flattening_tool(tool) && woodwork_tool_material(tool) == blade && (!blade || blade.hardness == blade_hardness)
	return woodwork_shaping_tool(tool, workpiece) && woodwork_tool_material(tool) == blade && (!blade || blade.hardness == blade_hardness)

/datum/primitive_woodwork_action/proc/release()
	if (!QDELETED(source) && source.woodwork_owner == src)
		source.woodwork_owner = null
	if (!QDELETED(user) && user.woodwork_owner == src)
		user.woodwork_owner = null
	if (!QDELETED(tool) && tool.woodwork_owner == src)
		tool.woodwork_owner = null
	if (!QDELETED(wedge) && wedge.woodwork_owner == src)
		wedge.woodwork_owner = null

/datum/primitive_woodwork_action/proc/commit()
	if (!claimed || !valid())
		return FALSE
	var/cost = spec["cost"]
	if (!source.can_use(cost) || !source.use(cost)) // No human argument: no religion discount.
		return FALSE
	// The material stack use() may delete an exhausted input. Keep final counts local.
	var/remaining = QDELETED(source) ? 0 : source.amount
	if (remaining != source_count - cost)
		return FALSE
	committed = TRUE
	var/output_type = spec["output"]
	if (ispath(output_type, /obj/item/stack))
		new output_type(site, spec["count"])
	else
		new output_type(site)
	if (spec["bark"])
		new /obj/item/stack/bark(site, spec["bark"])
	// Flint has no material-tool wear contract. Material knives/wedges use tool wear.
	if (mode != "flatten" && istype(tool, /obj/item/weapon/material))
		var/obj/item/weapon/material/M = tool
		M.health -= 0.25
		M.check_health()
	if (mode == "plank" && !QDELETED(wedge))
		var/obj/item/weapon/material/W = wedge
		W.health -= 0.25
		W.check_health()
	return TRUE

/datum/primitive_woodwork_action/proc/perform()
	if (!valid() || user.getStatCoeff("strength") <= 0)
		qdel(src)
		return FALSE
	claimed = TRUE
	source.woodwork_owner = src
	user.woodwork_owner = src
	tool.woodwork_owner = src
	if (wedge)
		wedge.woodwork_owner = src
	to_chat(user, SPAN_NOTICE("You begin working the wood ([mode]). Keep the materials and tools in place."))
	var/completed = do_after(user, spec["delay"] / user.getStatCoeff("strength"), source)
	var/success = completed && commit()
	release()
	if (success)
		to_chat(user, SPAN_NOTICE("You finish working the wood."))
	qdel(src)
	return success

/obj/item/stack/material/wood_piece/attackby(obj/item/T, mob/living/human/H)
	if (!istype(H) || !woodwork_shaping_tool(T, get_material()))
		return ..()
	var/choice = WWinput(H, "Whittle which tool? Wedge: 1 piece. Wooden mallet: 5 pieces.", "Whittling", "Cancel", list("Wooden wedge", "Wooden mallet", "Cancel"))
	if (choice == "Wooden wedge")
		woodwork_begin(src, H, T, "wedge")
	else if (choice == "Wooden mallet")
		woodwork_begin(src, H, T, "mallet")
	return TRUE

/obj/item/stack/material/wood/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("Use sharpened flint or a harder-material knife to cut a small wood piece. A wooden hammer and held wooden wedge split crude planks without an axe. Flatten crude planks with a sharp non-wooden tool, including sharpened flint, before using them as finished planks."))

/obj/item/stack/material/crude_plank/attackby(obj/item/T, mob/living/human/H)
	if (woodwork_flattening_tool(T))
		woodwork_begin(src, H, T, "flatten")
		return TRUE
	return ..()
