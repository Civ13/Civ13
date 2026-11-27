// Furniture projects reuse the tailoring workflow and dyes, but their parts
// are a wooden frame and optional, individually paid upholstery.
#define FURNITURE_PROJECT_CUT_TIME (3 SECONDS)
#define FURNITURE_PROJECT_ASSEMBLE_TIME (6 SECONDS)

/proc/furniture_project_body(shape)
	switch (shape)
		if ("Chair") return /obj/structure/bed/chair/modular
		if ("Bed") return /obj/structure/bed/wood/modular
		if ("Stool") return /obj/item/weapon/stool/wood/modular
	return null

/proc/furniture_finish_color(finish)
	switch (finish)
		if ("Natural") return "#cda775"
		if ("Honey") return "#e2b36b"
		if ("Dark") return "#906952"
	return null

/obj/structure/bed/chair/modular
	name = "crafted chair"
	desc = "A chair assembled from a furniture project."
	material = "wood"
	modular_furniture_shape = "Chair"

/obj/structure/bed/wood/modular
	name = "crafted bed"
	desc = "A bed assembled from a furniture project."
	modular_furniture_shape = "Bed"

/obj/structure/bed
	var/furniture_finish = null // a named frame finish; null on legacy furniture

/obj/item/furniture_project
	name = "furniture project"
	desc = "A bundle of wooden furniture parts. Use it in hand to design a chair, bed, or stool. Use a held cloth, woolcloth, or leather sheet on it to fit optional upholstery."
	icon = 'icons/obj/bed_chair.dmi'
	icon_state = "stool_preview"
	w_class = ITEM_SIZE_NORMAL
	var/design_shape = "Chair"
	var/design_finish = "Natural"
	var/design_part_a = null
	var/design_part_b = null
	var/cut = FALSE
	var/tmp/working = FALSE

/obj/item/furniture_project/persistence_runtime_var(key)
	return key == "working" || ..()

/obj/item/furniture_project/proc/ready(mob/living/human/H, turf/origin, datum/save_epoch)
	return istype(H) && !QDELETED(H) && !QDELETED(src) && H.loc == origin && isturf(origin) && loc == H && (H.l_hand == src || H.r_hand == src) && !H.incapacitated() && H.can_use_hands() && !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required && save_epoch == persistence_admission_identity && crafting_node_allowed(H, "basic_furniture")

/obj/item/furniture_project/proc/design_allowed(mob/living/human/H)
	return furniture_project_body(design_shape) && furniture_finish_color(design_finish) && furniture_upholstery_allowed(H, design_part_a) && (!design_part_b || (design_shape != "Stool" && furniture_upholstery_allowed(H, design_part_b)))

/obj/item/furniture_project/proc/upholstery_ready(mob/living/human/H, obj/item/W, turf/site, datum/save_epoch)
	return ready(H, site, save_epoch) && !cut && !QDELETED(W) && W.loc == H && (W == H.l_hand || W == H.r_hand)

/obj/item/furniture_project/attackby(obj/item/W, mob/user)
	var/kind = furniture_upholstery_material(W)
	if (!kind)
		return ..()
	var/mob/living/human/H = user
	var/turf/site = H?.loc
	var/datum/save_epoch = persistence_admission_identity
	if (working || !upholstery_ready(H, W, site, save_epoch))
		to_chat(user, SPAN_WARNING("Hold the uncut furniture project in your other hand."))
		return TRUE
	working = TRUE
	choose_project_upholstery(H, W, site, save_epoch, kind)
	working = FALSE
	return TRUE

/obj/item/furniture_project/proc/choose_project_upholstery(mob/living/human/H, obj/item/W, turf/site, datum/save_epoch, kind)
	var/list/slots = furniture_upholstery_slots(design_shape)
	var/choice = WWinput(H, "Which part should this sheet cover?", "Upholstery", null, slots)
	var/index = slots.Find(choice)
	if (!index || !upholstery_ready(H, W, site, save_epoch)) return
	var/previous = index == 1 ? design_part_a : design_part_b
	var/dye = null
	if (kind != "leather")
		dye = furniture_choose_dye(H, lowertext(choice), furniture_upholstery_dye(previous))
		if (!tailoring_color_valid(dye)) return
	var/record = furniture_upholstery_record(kind, dye)
	if (upholstery_ready(H, W, site, save_epoch) && furniture_upholstery_allowed(H, record))
		fit_project_upholstery(W, site, index, record)

/obj/item/furniture_project/proc/fit_project_upholstery(obj/item/stack/S, turf/site, index, record)
	if (cut || QDELETED(src) || QDELETED(S) || !isturf(site) || (index != 1 && (index != 2 || design_shape == "Stool")))
		return FALSE
	if (!furniture_upholstery_kind(record) || furniture_upholstery_material(S) != furniture_upholstery_kind(record) || !S.use(1))
		return FALSE
	var/previous = index == 1 ? design_part_a : design_part_b
	if (index == 1)
		design_part_a = record
	else
		design_part_b = record
	furniture_refund_upholstery(previous, site)
	return TRUE

/obj/item/furniture_project/proc/site_clear(mob/living/human/H, turf/T)
	if (!istype(T, /turf/floor) || T.density || is_open_water(T) || istype(T, /turf/floor/space) || istype(T, /turf/floor/lava) || vessel_building_deck_at(H) || train_deck_at(T))
		return FALSE
	for (var/obj/S in T)
		if (!QDELETED(S) && (S.density || istype(S, /obj/structure/bed) || istype(S, /obj/structure/trains)))
			return FALSE
	return TRUE

// Preview uses the same frame and cushion sprites/tints as the finished item.
/obj/item/furniture_project/proc/preview_tiles(client/C)
	var/list/tiles = list()
	if (!C)
		return tiles
	if (!furniture_project_body(design_shape))
		return tiles
	var/list/layers = furniture_design_layers(design_shape, design_finish, design_part_a, design_part_b)
	for (var/direction in list(SOUTH, NORTH, EAST, WEST))
		var/obj/screen/tailoring_preview/T = new()
		T.dir = direction
		T.screen_loc = "WEST+[2 * tiles.len + 1],NORTH-1"
		T.transform = matrix(2, 0, 0, 0, 2, 0)
		T.overlays += layers
		tiles += T
	C.screen += tiles
	return tiles

/obj/item/furniture_project/attack_self(mob/living/human/H)
	var/turf/origin = H?.loc
	var/datum/save_epoch = persistence_admission_identity
	if (working || !istype(H) || !crafting_node_allowed_or_warn(H, "basic_furniture") || !ready(H, origin, save_epoch))
		return
	working = TRUE
	design_menu(H, origin, save_epoch)
	working = FALSE

/obj/item/furniture_project/proc/design_menu(mob/living/human/H, turf/origin, datum/save_epoch)
	while (ready(H, origin, save_epoch))
		var/client/viewer = H.client
		var/list/preview = preview_tiles(viewer)
		var/list/options = cut ? list("Assemble", "Close") : list("Frame", "Wood finish", "Cut parts", "Close")
		var/list/slots = furniture_upholstery_slots(design_shape)
		if (!cut && (design_part_a || design_part_b))
			options.Insert(3, "Remove upholstery")
		var/cover = "[slots[1]]: [furniture_upholstery_description(design_part_a)]"
		if (slots.len > 1)
			cover += "; [slots[2]]: [furniture_upholstery_description(design_part_b)]"
		var/answer = WWinput(H, "[design_shape], [design_finish] finish. [cover]. [cut ? "Parts cut." : "Design not yet cut."]", "Furniture project", "Close", options)
		if (viewer)
			viewer.screen -= preview
		for (var/obj/screen/T in preview)
			qdel(T)
		if (!ready(H, origin, save_epoch) || !(answer in options) || answer == "Close")
			return
		switch (answer)
			if ("Frame")
				var/shape = WWinput(H, "Which frame do you want to make?", "Frame", design_shape, list("Chair", "Bed", "Stool"))
				if (ready(H, origin, save_epoch) && furniture_project_body(shape))
					if (shape == "Stool" && design_part_b && furniture_refund_upholstery(design_part_b, origin))
						design_part_b = null
					design_shape = shape
			if ("Wood finish")
				var/finish = WWinput(H, "Choose a finish for the frame.", "Wood finish", design_finish, list("Natural", "Honey", "Dark"))
				if (ready(H, origin, save_epoch) && furniture_finish_color(finish))
					design_finish = finish
			if ("Remove upholstery")
				var/part = WWinput(H, "Which part should be left bare?", "Remove upholstery", null, slots)
				var/index = slots.Find(part)
				if (index && !cut && ready(H, origin, save_epoch))
					var/previous = index == 1 ? design_part_a : design_part_b
					if (furniture_refund_upholstery(previous, origin))
						if (index == 1)
							design_part_a = null
						else
							design_part_b = null
			if ("Cut parts")
				if (WWinput(H, "Cutting locks this design. Cut the parts?", "Cut parts", "Keep designing", list("Keep designing", "Cut parts")) == "Cut parts")
					cut_parts(H, origin, save_epoch)
			if ("Assemble")
				if (!site_clear(H, origin))
					to_chat(H, SPAN_WARNING("Stand on clear, solid ground to assemble the furniture."))
					return
				assemble(H, origin, save_epoch)
				return

/obj/item/furniture_project/proc/wait_for_furniture(mob/living/human/H, delay)
	return do_after(H, delay, src)

/obj/item/furniture_project/proc/cut_parts(mob/living/human/H, turf/origin, datum/save_epoch)
	if (cut || !ready(H, origin, save_epoch) || !design_allowed(H))
		return FALSE
	if (!wait_for_furniture(H, FURNITURE_PROJECT_CUT_TIME) || cut || !ready(H, origin, save_epoch) || !design_allowed(H))
		return FALSE
	cut = TRUE
	return TRUE

/obj/item/furniture_project/proc/assemble(mob/living/human/H, turf/origin, datum/save_epoch)
	if (!cut || !ready(H, origin, save_epoch) || !design_allowed(H) || !site_clear(H, origin))
		return null
	if (!wait_for_furniture(H, FURNITURE_PROJECT_ASSEMBLE_TIME) || !ready(H, origin, save_epoch) || !design_allowed(H) || !site_clear(H, origin))
		return null
	var/result_type = furniture_project_body(design_shape)
	var/obj/F = new result_type(origin, "wood")
	if (QDELETED(F) || F.loc != origin)
		if (!QDELETED(F))
			qdel(F)
		return null
	if (design_shape == "Stool")
		var/obj/item/weapon/stool/wood/modular/S = F
		S.furniture_finish = design_finish
		S.furniture_upholstery_a = design_part_a
		S.update_icon()
	else
		var/obj/structure/bed/B = F
		B.furniture_finish = design_finish
		B.furniture_upholstery_a = design_part_a
		B.furniture_upholstery_b = design_part_b
		B.update_icon()
	H.remove_from_mob(src)
	qdel(src)
	return F

#undef FURNITURE_PROJECT_CUT_TIME
#undef FURNITURE_PROJECT_ASSEMBLE_TIME
