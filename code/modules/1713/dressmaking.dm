// Paid fabric becomes a persistent project, then one wearable dress. Existing
// dress recipes and art remain available; this adds a deliberate design/cut/sew route.
/proc/dressmaking_cut(cut)
	switch (cut)
		if ("Layered")
			return list("base" = "customdress", "panels" = list("Sleeves" = "customdress_top", "Skirt" = "customdress_under", "Bodice" = "customdress_over"))
		if ("Buttoned")
			return list("base" = "custombuttonup_full", "panels" = list("Sleeves and skirt" = "custombuttonup_bottom", "Bodice and stripes" = "custombuttonup_lines"))
		if ("Laced")
			return list("base" = "crinoline_dress", "panels" = list("Dress" = "crinoline_dress_dress", "Underskirt" = "crinoline_dress_under"), "fixed" = "crinoline_dress_lining")
	return null

// Opaque RGB only: transparent or malformed input must never hide the garment.
/proc/dressmaking_color_valid(value)
	if (!istext(value) || length(value) != 7 || copytext(value, 1, 2) != "#")
		return FALSE
	for (var/i = 2, i <= 7, i++)
		if (!findtext("0123456789abcdef", lowertext(copytext(value, i, i + 1))))
			return FALSE
	return TRUE

/proc/dressmaking_design_valid(cut, primary, secondary, accent)
	return dressmaking_cut(cut) && dressmaking_color_valid(primary) && dressmaking_color_valid(secondary) && dressmaking_color_valid(accent)

// The same layer order and colors drive the loose item, preview, and worn dress.
/proc/dressmaking_layers(cut, primary, secondary, accent, worn = FALSE)
	var/list/design = dressmaking_cut(cut)
	if (!design || !dressmaking_design_valid(cut, primary, secondary, accent))
		return list()
	var/art = worn ? 'icons/mob/uniform.dmi' : 'icons/obj/clothing/uniforms.dmi'
	var/list/panels = design["panels"]
	var/list/colors = list(primary, secondary, accent)
	var/list/layers = list()
	var/index = 1
	for (var/panel in panels)
		var/image/layer = image(icon = art, icon_state = panels[panel])
		layer.color = colors[index++]
		layers += layer
	if (design["fixed"])
		layers += image(icon = art, icon_state = design["fixed"])
	return layers

/proc/dressmaking_preview(cut, primary, secondary, accent, direction)
	var/list/design = dressmaking_cut(cut)
	if (!design)
		return null
	var/icon/preview = icon('icons/mob/uniform.dmi', design["base"], direction)
	for (var/image/layer in dressmaking_layers(cut, primary, secondary, accent, TRUE))
		var/icon/panel = icon(layer.icon, layer.icon_state, direction)
		if (layer.color)
			panel.Blend(layer.color, ICON_MULTIPLY)
		preview.Blend(panel, ICON_OVERLAY)
	return preview

/obj/item/dressmaking_project
	name = "dressmaking project"
	desc = "Four portions of fabric set aside for a dress. Use it in hand to choose a cut and panel colors, preview, cut the fabric, then sew. Cutting locks the design."
	icon = 'icons/obj/materials.dmi'
	icon_state = "sheet-cloth"
	w_class = ITEM_SIZE_NORMAL
	flammable = TRUE
	var/dress_cut = "Layered"
	var/primary_color = "#FFFFFF"
	var/secondary_color = "#FFFFFF"
	var/accent_color = "#FFFFFF"
	// 0: editable fabric; 1: cut pieces; 2: consumed, never usable again.
	var/stage = 0
	var/tmp/dressmaking_busy = FALSE

/obj/item/dressmaking_project/persistence_runtime_var(key)
	return key == "dressmaking_busy" || ..()

/obj/item/dressmaking_project/proc/actor_ready(mob/living/human/user, turf/site, datum/save_epoch)
	return istype(user) && !QDELETED(src) && !QDELETED(user) && !gcDestroyed && loc == user && (user.l_hand == src || user.r_hand == src) && isturf(user.loc) && user.loc == site && !user.incapacitated() && user.can_use_hands() && !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required && save_epoch == persistence_admission_identity && crafting_node_allowed(user, "fine_garments")

/obj/item/dressmaking_project/proc/wait_for_dressmaking(mob/living/human/user, delay)
	return do_after(user, delay, src)

/obj/item/dressmaking_project/attack_self(mob/living/human/user)
	var/turf/site = get_turf(user)
	var/datum/save_epoch = persistence_admission_identity
	if (dressmaking_busy || !actor_ready(user, site, save_epoch) || stage >= 2)
		return
	dressmaking_busy = TRUE
	design_menu(user, site, save_epoch)
	dressmaking_busy = FALSE

/obj/item/dressmaking_project/proc/design_menu(mob/living/human/user, turf/site, datum/save_epoch)
	while (actor_ready(user, site, save_epoch) && (stage == 0 || stage == 1))
		var/list/options = stage == 0 ? list("Choose cut", "Panel colors", "Preview", "Cut fabric", "Close") : list("Preview", "Sew dress", "Close")
		var/choice = WWinput(user, "[dress_cut] dress: [stage == 0 ? "designing" : "cut and ready to sew"].", "Dressmaking", "Close", options)
		if (!actor_ready(user, site, save_epoch) || !choice || choice == "Close")
			return
		switch (choice)
			if ("Choose cut")
				if (stage != 0)
					return
				var/selected_cut = WWinput(user, "Choose the dress cut. Laced dresses keep their gold trim.", "Dress cut", dress_cut, list("Layered", "Buttoned", "Laced"))
				if (actor_ready(user, site, save_epoch) && stage == 0 && dressmaking_cut(selected_cut))
					dress_cut = selected_cut
			if ("Panel colors")
				if (stage != 0)
					return
				var/list/design = dressmaking_cut(dress_cut)
				if (!design)
					return
				var/list/panels = design["panels"]
				var/panel = WWinput(user, "Choose a fabric panel to color.", "Dress panels", null, panels)
				if (!actor_ready(user, site, save_epoch) || stage != 0 || !panel || !(panel in panels))
					continue
				var/index = panels.Find(panel)
				var/list/colors = list(primary_color, secondary_color, accent_color)
				var/selected_color = WWinput(user, "Choose the [panel] color.", "Panel color", colors[index], "color")
				if (!actor_ready(user, site, save_epoch) || stage != 0 || !dressmaking_color_valid(selected_color))
					continue
				switch (index)
					if (1)
						primary_color = selected_color
					if (2)
						secondary_color = selected_color
					if (3)
						accent_color = selected_color
			if ("Preview")
				show_design(user)
				return
			if ("Cut fabric")
				var/confirm = WWinput(user, "Cut this design? You can no longer change the cut or colors afterward. No extra fabric is needed.", "Cut fabric", "Keep designing", list("Keep designing", "Cut fabric"))
				if (confirm == "Cut fabric")
					cut_fabric(user, site, save_epoch)
			if ("Sew dress")
				sew_dress(user, site, save_epoch)
				return

/obj/item/dressmaking_project/proc/show_design(mob/user)
	if (!user || !user.client || !dressmaking_design_valid(dress_cut, primary_color, secondary_color, accent_color))
		return
	var/icon/front = dressmaking_preview(dress_cut, primary_color, secondary_color, accent_color, SOUTH)
	var/icon/back = dressmaking_preview(dress_cut, primary_color, secondary_color, accent_color, NORTH)
	// Content-derived names prevent a browser's cached image showing an old design.
	var/key = md5("[dress_cut]|[primary_color]|[secondary_color]|[accent_color]")
	send_rsc(user, front, "dress_[key]_front.png")
	send_rsc(user, back, "dress_[key]_back.png")
	var/page = "<html><body style='background:#28252c;color:#f4eee2;font-family:Verdana;text-align:center'><h2>[html_encode(dress_cut)] dress</h2>"
	page += "<p>Front and back garment preview (without a wearer)</p><img src='dress_[key]_front.png' width='160' height='160' alt='Front'><img src='dress_[key]_back.png' width='160' height='160' alt='Back'>"
	page += "<p>Use the Dressmaking menu to keep designing or continue cutting and sewing.</p><p>Laced trim is gold. Finished dresses accept the usual clothing accessories.</p></body></html>"
	show_browse(user, page, "window=dressmaking_preview;size=430x360")

/obj/item/dressmaking_project/proc/cut_fabric(mob/living/human/user, turf/site, datum/save_epoch)
	if (!actor_ready(user, site, save_epoch) || stage != 0 || !dressmaking_design_valid(dress_cut, primary_color, secondary_color, accent_color))
		return FALSE
	to_chat(user, SPAN_NOTICE("You start cutting the dress panels."))
	if (!wait_for_dressmaking(user, 30) || !actor_ready(user, site, save_epoch) || stage != 0)
		return FALSE
	stage = 1
	name = "cut dress pieces"
	to_chat(user, SPAN_NOTICE("The panels are cut. Use the project in hand to sew them together."))
	return TRUE

/obj/item/dressmaking_project/proc/sew_dress(mob/living/human/user, turf/site, datum/save_epoch)
	if (!actor_ready(user, site, save_epoch) || stage != 1 || !dressmaking_design_valid(dress_cut, primary_color, secondary_color, accent_color))
		return FALSE
	to_chat(user, SPAN_NOTICE("You start sewing the dress panels together."))
	if (!wait_for_dressmaking(user, 60) || !actor_ready(user, site, save_epoch) || stage != 1)
		return FALSE
	// Clear the actual inventory slot before replacing the paid project. There
	// are no yields from retirement through output, so competing finishers fail.
	if (!user.transfer_held_item_to(src, site))
		return FALSE
	stage = 2
	var/obj/item/clothing/under/tailored_dress/dress = new(site)
	dress.dress_cut = dress_cut
	dress.primary_color = primary_color
	dress.secondary_color = secondary_color
	dress.accent_color = accent_color
	dress.refresh_design()
	qdel(src)
	user.put_in_any_hand_if_possible(dress)
	to_chat(user, SPAN_NOTICE("You finish sewing the [dress.name]."))
	return TRUE

/obj/item/dressmaking_project/examine(mob/user)
	..()
	to_chat(user, "Design: [dress_cut]. [stage == 0 ? "The fabric is not cut yet." : "The cut panels are ready to sew."]")

/obj/item/clothing/under/tailored_dress
	name = "tailored dress"
	desc = "A dress sewn from individually colored fabric panels. Add ordinary clothing accessories for decoration."
	icon_state = "customdress"
	item_state = "customdress"
	var/dress_cut = "Layered"
	var/primary_color = "#FFFFFF"
	var/secondary_color = "#FFFFFF"
	var/accent_color = "#FFFFFF"
	var/tmp/list/dressmaking_overlays = null

/obj/item/clothing/under/tailored_dress/persistence_runtime_var(key)
	return key == "dressmaking_overlays" || ..()

/obj/item/clothing/under/tailored_dress/on_runtime_spawn()
	..()
	refresh_design()

/obj/item/clothing/under/tailored_dress/after_load()
	..()
	// Saved appearance layers are derived. Rebuild in normal attachment order:
	// dress panels, then accessories, then any existing blood stain.
	overlays.Cut()
	dressmaking_overlays = null
	refresh_design()
	for (var/obj/item/clothing/accessory/accessory in accessories)
		overlays += accessory.get_inv_overlay()
	if (blood_DNA && blood_DNA.len && blood_overlay)
		overlays += blood_overlay

/obj/item/clothing/under/tailored_dress/proc/refresh_design()
	if (!dressmaking_design_valid(dress_cut, primary_color, secondary_color, accent_color))
		return FALSE
	var/list/design = dressmaking_cut(dress_cut)
	name = "tailored [lowertext(dress_cut)] dress"
	icon_state = design["base"]
	item_state = icon_state
	item_state_slots[slot_w_uniform_str] = icon_state
	if (dressmaking_overlays)
		overlays -= dressmaking_overlays
	dressmaking_overlays = dressmaking_layers(dress_cut, primary_color, secondary_color, accent_color)
	overlays += dressmaking_overlays
	update_clothing_icon()
	return TRUE

/obj/item/clothing/under/tailored_dress/proc/worn_design_layers()
	return dressmaking_layers(dress_cut, primary_color, secondary_color, accent_color, TRUE)
