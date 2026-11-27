// Furniture projects reuse the tailoring workflow and dyes, but their parts
// are a wooden frame and an optional, separately paid cloth cover.
#define FURNITURE_PROJECT_CUT_TIME (3 SECONDS)
#define FURNITURE_PROJECT_ASSEMBLE_TIME (6 SECONDS)

/proc/furniture_project_body(shape)
	switch (shape)
		if ("Chair") return /obj/structure/bed/chair/modular
		if ("Bed") return /obj/structure/bed/wood/modular
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

/obj/structure/bed/wood/modular
	name = "crafted bed"
	desc = "A bed assembled from a furniture project."

/obj/structure/bed
	var/furniture_finish = null // a named frame finish; null on legacy furniture

/obj/item/furniture_project
	name = "furniture project"
	desc = "A bundle of wooden furniture parts. Use it in hand to design a chair or bed. Use a held cloth sheet on it to add optional upholstery."
	icon = 'icons/obj/bed_chair.dmi'
	icon_state = "stool_preview"
	w_class = ITEM_SIZE_NORMAL
	var/design_shape = "Chair"
	var/design_finish = "Natural"
	var/design_dye = null
	var/has_cloth = FALSE
	var/cut = FALSE
	var/tmp/working = FALSE

/obj/item/furniture_project/persistence_runtime_var(key)
	return key == "working" || ..()

/obj/item/furniture_project/proc/ready(mob/living/human/H, turf/origin, datum/save_epoch)
	return istype(H) && !QDELETED(H) && !QDELETED(src) && H.loc == origin && isturf(origin) && loc == H && (H.l_hand == src || H.r_hand == src) && !H.incapacitated() && H.can_use_hands() && !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required && save_epoch == persistence_admission_identity && crafting_node_allowed(H, "basic_furniture")

/obj/item/furniture_project/proc/design_allowed(mob/living/human/H)
	return furniture_project_body(design_shape) && furniture_finish_color(design_finish) && (!has_cloth || !design_dye || (tailoring_color_valid(design_dye) && crafting_node_allowed(H, tailoring_dye_node(design_dye))))

/obj/item/furniture_project/attackby(obj/item/W, mob/user)
	if (!istype(W, /obj/item/stack/material/cloth))
		return ..()
	var/mob/living/human/H = user
	var/obj/item/stack/material/cloth/C = W
	if (working || cut || has_cloth || !ready(H, H?.loc, persistence_admission_identity) || C.loc != H || !(C == H.l_hand || C == H.r_hand))
		to_chat(user, SPAN_WARNING("Hold an uncut, unupholstered project in your other hand."))
		return TRUE
	if (C.use(1))
		has_cloth = TRUE
		to_chat(user, SPAN_NOTICE("You put one cloth sheet aside for the upholstery."))
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
	var/body = furniture_project_body(design_shape)
	if (!body)
		return tiles
	var/base = initial(body:base_icon)
	var/frame_color = furniture_finish_color(design_finish)
	for (var/direction in list(SOUTH, NORTH, EAST, WEST))
		var/obj/screen/tailoring_preview/T = new()
		T.dir = direction
		T.screen_loc = "WEST+[2 * tiles.len + 1],NORTH-1"
		T.transform = matrix(2, 0, 0, 0, 2, 0)
		var/image/frame = image('icons/obj/bed_chair.dmi', base)
		frame.color = frame_color
		T.overlays += frame
		if (has_cloth)
			var/image/cover = image('icons/obj/bed_chair.dmi', "[base]_padding")
			var/material/cloth = get_material_by_name("cloth")
			cover.color = design_dye || cloth?.icon_colour
			T.overlays += cover
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
		if (!cut && has_cloth)
			options.Insert(3, "Upholstery colour", "Remove cloth")
		var/cover = has_cloth ? (fabric_dye_label(design_dye) || "undyed cloth") : "bare"
		var/answer = WWinput(H, "[design_shape], [design_finish] finish, [cover]. [cut ? "Parts cut." : "Design not yet cut."]", "Furniture project", "Close", options)
		if (viewer)
			viewer.screen -= preview
		for (var/obj/screen/T in preview)
			qdel(T)
		if (!ready(H, origin, save_epoch) || !(answer in options) || answer == "Close")
			return
		switch (answer)
			if ("Frame")
				var/shape = WWinput(H, "Which frame do you want to make?", "Frame", design_shape, list("Chair", "Bed"))
				if (ready(H, origin, save_epoch) && furniture_project_body(shape))
					design_shape = shape
			if ("Wood finish")
				var/finish = WWinput(H, "Choose a finish for the frame.", "Wood finish", design_finish, list("Natural", "Honey", "Dark"))
				if (ready(H, origin, save_epoch) && furniture_finish_color(finish))
					design_finish = finish
			if ("Upholstery colour")
				var/colour = furniture_choose_dye(H, "the upholstery", design_dye)
				if (ready(H, origin, save_epoch) && tailoring_color_valid(colour) && crafting_node_allowed(H, tailoring_dye_node(colour)))
					design_dye = lowertext(colour) == "#ffffff" ? null : lowertext(colour)
			if ("Remove cloth")
				has_cloth = FALSE
				design_dye = null
				new /obj/item/stack/material/cloth(origin)
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
	var/obj/structure/bed/F = new result_type(origin, "wood", has_cloth ? "cloth" : null)
	if (QDELETED(F) || F.loc != origin)
		if (!QDELETED(F))
			qdel(F)
		return null
	F.furniture_finish = design_finish
	F.padding_color = has_cloth ? design_dye : null
	F.update_icon()
	H.remove_from_mob(src)
	qdel(src)
	return F

#undef FURNITURE_PROJECT_CUT_TIME
#undef FURNITURE_PROJECT_ASSEMBLE_TIME
