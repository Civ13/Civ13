// Two fitted parts per modular frame. Each record owns one paid sheet.
#define FURNITURE_REFIT_TIME (4 SECONDS)

/proc/furniture_upholstery_material(obj/item/W)
	if (istype(W, /obj/item/stack/material/cloth)) return "cloth"
	if (istype(W, /obj/item/stack/material/woolcloth)) return "woolcloth"
	if (istype(W, /obj/item/stack/material/leather) && W.type == /obj/item/stack/material/leather) return "leather"
	return null

/proc/furniture_upholstery_stack(kind)
	switch (kind)
		if ("cloth") return /obj/item/stack/material/cloth
		if ("woolcloth") return /obj/item/stack/material/woolcloth
		if ("leather") return /obj/item/stack/material/leather
	return null

/proc/furniture_upholstery_kind(record)
	if (!istext(record)) return null
	var/list/parts = splittext(record, "|")
	if (parts.len == 2 && furniture_upholstery_stack(parts[1]))
		return parts[1]
	return null

/proc/furniture_upholstery_dye(record)
	var/kind = furniture_upholstery_kind(record)
	if (!kind || kind == "leather") return null
	var/list/parts = splittext(record, "|")
	return tailoring_color_valid(parts[2]) ? lowertext(parts[2]) : null

/proc/furniture_upholstery_record(kind, dye = null)
	if (!furniture_upholstery_stack(kind))
		return null
	return "[kind]|[kind != "leather" && tailoring_color_valid(dye) ? lowertext(dye) : "-"]"

/proc/furniture_upholstery_description(record)
	var/kind = furniture_upholstery_kind(record)
	if (!kind) return "bare"
	var/color = fabric_dye_label(furniture_upholstery_dye(record))
	return color ? "[kind] ([color])" : kind

/proc/furniture_upholstery_allowed(mob/living/human/H, record)
	var/dye = furniture_upholstery_dye(record)
	return !record || (furniture_upholstery_kind(record) && (!dye || crafting_node_allowed(H, tailoring_dye_node(dye))))

/proc/furniture_upholstery_slots(shape)
	switch (shape)
		if ("Bed") return list("Mattress", "Cover")
		if ("Stool") return list("Seat")
	return list("Seat", "Back")

/proc/furniture_upholstery_color(record)
	var/kind = furniture_upholstery_kind(record)
	if (!kind) return null
	var/dye = furniture_upholstery_dye(record)
	if (dye)
		return kind == "woolcloth" ? tailoring_tint(dye, "#e6dccb") : dye
	var/material/M = get_material_by_name(kind)
	return kind == "woolcloth" ? "#e6dccb" : M?.icon_colour

/proc/furniture_refund_upholstery(record, turf/site)
	var/path = furniture_upholstery_stack(furniture_upholstery_kind(record))
	if (!path || !site) return FALSE
	new path(site)
	return TRUE

// Preview and finished structure both use these same directional layers.
/proc/furniture_design_layers(shape, finish, part_a, part_b)
	var/list/layers = list()
	var/is_bed = shape == "Bed"
	var/is_stool = shape == "Stool"
	var/frame_state = is_stool ? "stool_base" : (is_bed ? "bed" : "chair")
	var/image/frame = image('icons/obj/bed_chair.dmi', frame_state)
	frame.color = furniture_finish_color(finish) || furniture_finish_color("Natural")
	layers += frame
	var/first = furniture_upholstery_color(part_a)
	if (first)
		var/image/A
		if (is_stool)
			A = image('icons/obj/bed_chair.dmi', "stool_padding")
		else
			A = image('icons/obj/furniture_upholstery.dmi', is_bed ? "bed_mattress" : "chair_seat")
		A.color = first
		layers += A
	var/second = furniture_upholstery_color(part_b)
	if (second && !is_stool)
		var/image/B = image('icons/obj/furniture_upholstery.dmi', is_bed ? "bed_cover" : "chair_back")
		B.color = second
		layers += B
	return layers

/obj/structure/bed
	var/modular_furniture_shape = null
	var/furniture_upholstery_a = null
	var/furniture_upholstery_b = null
	var/tmp/furniture_refit_busy = FALSE

/obj/structure/bed/persistence_runtime_var(key)
	return key == "furniture_refit_busy" || ..()

/obj/structure/bed/proc/render_modular_furniture()
	if (!modular_furniture_shape) return FALSE
	var/list/slots = furniture_upholstery_slots(modular_furniture_shape)
	desc = "[initial(desc)] [slots[1]]: [furniture_upholstery_description(furniture_upholstery_a)]; [slots[2]]: [furniture_upholstery_description(furniture_upholstery_b)]."
	icon_state = ""
	overlays.Cut()
	overlays += furniture_design_layers(modular_furniture_shape, furniture_finish, furniture_upholstery_a, furniture_upholstery_b)
	if (modular_furniture_shape == "Chair" && buckled_mob && furniture_upholstery_a)
		var/image/armrest = image('icons/obj/bed_chair.dmi', "chair_armrest")
		armrest.layer = MOB_LAYER + 0.1
		armrest.color = furniture_upholstery_color(furniture_upholstery_a)
		overlays += armrest
	return TRUE

/obj/structure/bed/proc/strip_modular_upholstery()
	if (!modular_furniture_shape) return
	var/turf/site = get_turf(src)
	furniture_refund_upholstery(furniture_upholstery_a, site)
	furniture_refund_upholstery(furniture_upholstery_b, site)
	furniture_upholstery_a = null
	furniture_upholstery_b = null

/obj/structure/bed/proc/modular_refit_ready(mob/living/human/H, obj/item/W, turf/site, datum/save_epoch)
	return !buckled_mob && furniture_refit_ready(src, H, W, site, save_epoch)

/proc/furniture_refit_ready(atom/movable/F, mob/living/human/H, obj/item/W, turf/site, datum/save_epoch)
	return isturf(site) && !QDELETED(F) && !QDELETED(H) && !QDELETED(W) && F.loc == site && H.Adjacent(F) && W.loc == H && (W == H.l_hand || W == H.r_hand) && !H.incapacitated() && H.can_use_hands() && !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required && save_epoch == persistence_admission_identity && crafting_node_allowed(H, "basic_furniture")

/obj/structure/bed/proc/modular_upholstery_click(obj/item/W, mob/user)
	if (!modular_furniture_shape) return FALSE
	var/kind = furniture_upholstery_material(W)
	var/removing = is_tool(W, TOOL_WIRECUTTER)
	if (!kind && !removing)
		if (!istype(W, /obj/item/stack)) return FALSE
		to_chat(user, SPAN_WARNING("Use cloth, woolcloth or leather for these upholstery parts."))
		return TRUE
	if (!ishuman(user)) return TRUE
	var/mob/living/human/H = user
	var/turf/site = loc
	var/datum/save_epoch = persistence_admission_identity
	if (furniture_refit_busy || !isturf(site) || !modular_refit_ready(H, W, site, save_epoch))
		to_chat(H, SPAN_WARNING("Hold your materials or cutters beside the unoccupied furniture. You need Basic Furniture knowledge."))
		return TRUE
	furniture_refit_busy = TRUE
	refit_modular_upholstery(H, W, site, save_epoch, kind)
	furniture_refit_busy = FALSE
	return TRUE

/obj/structure/bed/proc/refit_modular_upholstery(mob/living/human/H, obj/item/W, turf/site, datum/save_epoch, kind)
	var/list/slots = furniture_upholstery_slots(modular_furniture_shape)
	var/choice = WWinput(H, "Which part do you want to work on?", "Upholstery", null, slots)
	var/index = slots.Find(choice)
	if (!index || !modular_refit_ready(H, W, site, save_epoch)) return
	var/previous = index == 1 ? furniture_upholstery_a : furniture_upholstery_b
	if (!kind && !previous)
		to_chat(H, SPAN_NOTICE("That part is already bare."))
		return
	var/dye = null
	if (kind && kind != "leather")
		dye = furniture_choose_dye(H, lowertext(choice), furniture_upholstery_dye(previous))
		if (!tailoring_color_valid(dye)) return
	var/record = furniture_upholstery_record(kind, dye)
	if (!modular_refit_ready(H, W, site, save_epoch) || !furniture_upholstery_allowed(H, record))
		return
	if (!do_after(H, FURNITURE_REFIT_TIME, src) || !modular_refit_ready(H, W, site, save_epoch) || !furniture_upholstery_allowed(H, record))
		return
	commit_modular_upholstery(W, site, index, previous, kind, record)

/obj/structure/bed/proc/commit_modular_upholstery(obj/item/W, turf/site, index, previous, kind, record)
	if (!modular_furniture_shape || (index != 1 && index != 2) || loc != site || !isturf(site))
		return FALSE
	if (previous != (index == 1 ? furniture_upholstery_a : furniture_upholstery_b))
		return FALSE
	if (!furniture_upholstery_pay(W, previous, kind, record))
		return FALSE
	if (index == 1)
		furniture_upholstery_a = record
	else
		furniture_upholstery_b = record
	furniture_refund_upholstery(previous, site)
	update_icon()
	return TRUE

/proc/furniture_upholstery_pay(obj/item/W, previous, kind, record)
	if (kind)
		var/obj/item/stack/S = W
		return furniture_upholstery_material(S) == kind && furniture_upholstery_kind(record) == kind && S.use(1)
	return !record && previous && is_tool(W, TOOL_WIRECUTTER)

/obj/item/weapon/stool/wood/modular
	name = "crafted stool"
	desc = "A portable stool assembled from a furniture project."
	var/furniture_finish = "Natural"
	var/furniture_upholstery_a = null
	var/tmp/furniture_refit_busy = FALSE

/obj/item/weapon/stool/wood/modular/persistence_runtime_var(key)
	return key == "furniture_refit_busy" || ..()

/obj/item/weapon/stool/wood/modular/update_icon()
	desc = "[initial(desc)] Seat: [furniture_upholstery_description(furniture_upholstery_a)]."
	icon_state = ""
	overlays.Cut()
	overlays += furniture_design_layers("Stool", furniture_finish, furniture_upholstery_a, null)

/obj/item/weapon/stool/wood/modular/after_load()
	..()
	update_icon()

/obj/item/weapon/stool/wood/modular/dismantle()
	var/turf/site = get_turf(src)
	furniture_refund_upholstery(furniture_upholstery_a, site)
	furniture_upholstery_a = null
	..()

/obj/item/weapon/stool/wood/modular/attackby(obj/item/weapon/W, mob/user)
	var/kind = furniture_upholstery_material(W)
	if (!kind && !is_tool(W, TOOL_WIRECUTTER))
		if (istype(W, /obj/item/stack))
			to_chat(user, SPAN_WARNING("Use cloth, woolcloth or leather to cover the seat."))
			return TRUE
		return ..()
	if (!ishuman(user))
		return TRUE
	var/mob/living/human/H = user
	var/turf/site = loc
	var/datum/save_epoch = persistence_admission_identity
	if (furniture_refit_busy || !furniture_refit_ready(src, H, W, site, save_epoch))
		to_chat(H, SPAN_WARNING("Set the stool down and hold your materials or cutters. You need Basic Furniture knowledge."))
		return TRUE
	furniture_refit_busy = TRUE
	refit_modular_seat(H, W, site, save_epoch, kind)
	furniture_refit_busy = FALSE
	return TRUE

/obj/item/weapon/stool/wood/modular/proc/refit_modular_seat(mob/living/human/H, obj/item/W, turf/site, datum/save_epoch, kind)
	var/previous = furniture_upholstery_a
	if (!kind && !previous)
		to_chat(H, SPAN_NOTICE("The seat is already bare."))
		return
	var/dye = null
	if (kind && kind != "leather")
		dye = furniture_choose_dye(H, "seat", furniture_upholstery_dye(previous))
		if (!tailoring_color_valid(dye)) return
	var/record = furniture_upholstery_record(kind, dye)
	if (!furniture_refit_ready(src, H, W, site, save_epoch) || !furniture_upholstery_allowed(H, record))
		return
	if (!do_after(H, FURNITURE_REFIT_TIME, src) || !furniture_refit_ready(src, H, W, site, save_epoch) || !furniture_upholstery_allowed(H, record))
		return
	commit_modular_seat(W, site, previous, kind, record)

/obj/item/weapon/stool/wood/modular/proc/commit_modular_seat(obj/item/W, turf/site, previous, kind, record)
	if (!isturf(site) || loc != site || furniture_upholstery_a != previous || !furniture_upholstery_pay(W, previous, kind, record))
		return FALSE
	furniture_upholstery_a = record
	furniture_refund_upholstery(previous, site)
	update_icon()
	return TRUE

#undef FURNITURE_REFIT_TIME
