// Tailoring: players design their own clothes. A paid tailoring project holds
// fabric; its owner picks a garment body, colours the body and each of its
// pattern pieces, cuts the fabric (which locks the design) and sews one garment.
//
// A design is plain data: a body id and a "|"-separated list of colours (the
// body first, then each piece in catalogue order). The loose item, the worn
// sprite and the live preview are all built from the same coloured image
// overlays. BYOND shares one appearance per icon, state and colour, so no
// /icon is blended at runtime and nothing is added to the resource cache.

#define TAILORING_MAX_FABRIC 8
#define TAILORING_MAX_COLOURS 6

var/global/list/tailoring_catalogue = null

// Body id -> list(name, slot, base, item_base?, panels (label -> state, in
// draw order), fixed (uncoloured states drawn last), node, cost, covers?).
// Every state is existing greyscale art in the slot's worn and item icons.
/proc/tailoring_bodies()
	if (tailoring_catalogue)
		return tailoring_catalogue
	var/list/C = list()
	// Clothing (uniform slot).
	C["loincloth"] = list("name" = "loincloth", "slot" = "under", "base" = "customspartan", "panels" = list(), "node" = "weaving", "cost" = 1, "covers" = LOWER_TORSO)
	C["long_tunic"] = list("name" = "long tunic", "slot" = "under", "base" = "customroman", "panels" = list(), "node" = "weaving", "cost" = 4)
	C["tribal_robe"] = list("name" = "tribal robe", "slot" = "under", "base" = "tribalrobe_robe", "item_base" = "tribalrobe", "panels" = list("Robe" = "tribalrobe_robe", "Decoration" = "tribalrobe_decoration"), "fixed" = list("tribalrobe_robebelt"), "node" = "weaving", "cost" = 3)
	C["shendyt"] = list("name" = "shendyt", "slot" = "under", "base" = "customshendyt", "panels" = list(), "node" = "classical_dress", "cost" = 2, "covers" = LOWER_TORSO)
	C["celtic_trousers"] = list("name" = "celtic trousers", "slot" = "under", "base" = "customceltic", "panels" = list(), "node" = "classical_dress", "cost" = 2, "covers" = LOWER_TORSO|LEGS)
	C["toga"] = list("name" = "toga", "slot" = "under", "base" = "customtoga", "panels" = list(), "node" = "classical_dress", "cost" = 3)
	C["stola"] = list("name" = "stola", "slot" = "under", "base" = "fem_roman", "panels" = list(), "node" = "classical_dress", "cost" = 4)
	C["arabic_tunic"] = list("name" = "arabic tunic", "slot" = "under", "base" = "customarabictunic", "panels" = list(), "node" = "tailoring", "cost" = 4)
	C["haori"] = list("name" = "haori", "slot" = "under", "base" = "haori_custom", "panels" = list(), "node" = "tailoring", "cost" = 3)
	C["renaissance"] = list("name" = "renaissance outfit", "slot" = "under", "base" = "customren", "panels" = list("Top" = "customren_top", "Lining" = "customren_lining"), "node" = "tailoring", "cost" = 6)
	C["short_colonial"] = list("name" = "short colonial outfit", "slot" = "under", "base" = "custom_col_short_full", "panels" = list("Shirt" = "custom_col_short_shirt", "Trousers" = "custom_col_short_pants"), "fixed" = list("custom_belt"), "node" = "tailoring", "cost" = 4)
	C["tunic"] = list("name" = "tunic", "slot" = "under", "base" = "customtunic", "panels" = list(), "node" = "fine_garments", "cost" = 4)
	C["layered_dress"] = list("name" = "layered dress", "slot" = "under", "base" = "customdress", "panels" = list("Sleeves" = "customdress_top", "Skirt" = "customdress_under", "Bodice" = "customdress_over"), "node" = "fine_garments", "cost" = 4)
	C["buttoned_dress"] = list("name" = "buttoned dress", "slot" = "under", "base" = "custombuttonup_full", "panels" = list("Sleeves and skirt" = "custombuttonup_bottom", "Bodice and stripes" = "custombuttonup_lines"), "node" = "fine_garments", "cost" = 4)
	C["laced_dress"] = list("name" = "laced dress", "slot" = "under", "base" = "crinoline_dress", "panels" = list("Dress" = "crinoline_dress_dress", "Underskirt" = "crinoline_dress_under"), "fixed" = list("crinoline_dress_lining"), "node" = "fine_garments", "cost" = 4)
	C["pontifical"] = list("name" = "pontifical robes", "slot" = "under", "base" = "custom_pontifical", "panels" = list("Leggings" = "custompont_leggings", "Decoration" = "custompont_decore", "Cuffs" = "custompont_handdecore", "Lines" = "custompont_mclines"), "node" = "fine_garments", "cost" = 6)
	C["pyjamas"] = list("name" = "pyjamas", "slot" = "under", "base" = "custompyjamas", "panels" = list("Cloth" = "custompyjamas_base", "Stripes" = "custompyjamas_stripes"), "node" = "fine_garments", "cost" = 3)
	C["colonial"] = list("name" = "colonial outfit", "slot" = "under", "base" = "custom_col_full", "panels" = list("Shirt" = "custom_col_shirt", "Trousers" = "custom_col_pants"), "fixed" = list("custom_belt"), "node" = "fine_garments", "cost" = 4)
	C["victorian_uniform"] = list("name" = "victorian uniform", "slot" = "under", "base" = "customuni", "panels" = list("Shirt" = "customuni_shirt", "Buttons" = "customuni_buttons", "Belt" = "customuni_belt", "Buckle" = "customuni_buckle", "Trousers" = "customuni_pants"), "node" = "textile_mills", "cost" = 3)
	C["modern"] = list("name" = "modern outfit", "slot" = "under", "base" = "custom_mod_full", "panels" = list("Shirt" = "custom_mod_shirt", "Trousers" = "custom_mod_pants"), "fixed" = list("custom_belt"), "node" = "ready_made", "cost" = 4)
	C["modern_baggy"] = list("name" = "baggy modern outfit", "slot" = "under", "base" = "custom_modbaggy_full", "panels" = list("Shirt" = "custom_modbaggy_shirt", "Trousers" = "custom_modbaggy_pants"), "fixed" = list("custom_belt"), "node" = "ready_made", "cost" = 4)
	C["modern_short"] = list("name" = "short modern outfit", "slot" = "under", "base" = "custom_modshort_full", "panels" = list("Shirt" = "custom_modshort_shirt", "Trousers" = "custom_modshort_pants"), "fixed" = list("custom_belt"), "node" = "ready_made", "cost" = 4)
	// Overclothes (suit slot).
	C["poncho"] = list("name" = "poncho", "slot" = "suit", "base" = "customponcho", "panels" = list(), "node" = "tailoring", "cost" = 2)
	C["haori_jacket"] = list("name" = "haori jacket", "slot" = "suit", "base" = "haori_jacket_custom", "panels" = list(), "node" = "tailoring", "cost" = 4)
	C["colonial_jacket"] = list("name" = "colonial jacket", "slot" = "suit", "base" = "customcolonial_full", "panels" = list("Jacket" = "customcolonial_jacket", "Bandolier" = "customcolonial_cross"), "fixed" = list("customcolonial_plain"), "node" = "tailoring", "cost" = 5)
	C["colonial_coat"] = list("name" = "colonial coat", "slot" = "suit", "base" = "customcolonialcoat_full", "panels" = list("Coat" = "customcolonialcoat_top", "Decorations" = "customcolonialcoat_dec", "Lines" = "customcolonialcoat_lines"), "node" = "tailoring", "cost" = 7)
	C["cloth_jacket"] = list("name" = "cloth jacket", "slot" = "suit", "base" = "customjacket", "panels" = list(), "node" = "ready_made", "cost" = 4)
	C["blazer"] = list("name" = "blazer", "slot" = "suit", "base" = "customblazer", "panels" = list(), "node" = "ready_made", "cost" = 4)
	C["hoodie"] = list("name" = "hoodie", "slot" = "suit", "base" = "customhoodie", "panels" = list(), "node" = "ready_made", "cost" = 3)
	C["tracksuit"] = list("name" = "tracksuit jacket", "slot" = "suit", "base" = "customtracksuit", "panels" = list("Jacket" = "customtracksuit_base", "Stripes" = "customtracksuit_lines"), "node" = "synthetics", "cost" = 3)
	tailoring_catalogue = C
	return C

/proc/tailoring_body(body_id)
	if (!istext(body_id))
		return null
	var/list/C = tailoring_bodies()
	return C[body_id]

// The worn and loose icon files for a body's slot.
/proc/tailoring_art(list/body, worn)
	if (body["slot"] == "suit")
		return worn ? 'icons/mob/suit.dmi' : 'icons/obj/clothing/suits.dmi'
	return worn ? 'icons/mob/uniform.dmi' : 'icons/obj/clothing/uniforms.dmi'

// "Body" first, then the pattern pieces in drawing order.
/proc/tailoring_piece_labels(list/body)
	var/list/labels = list("Body")
	var/list/panels = body["panels"]
	labels += panels
	return labels

/proc/tailoring_body_allowed(mob/living/human/H, body_id)
	var/list/body = tailoring_body(body_id)
	return body && crafting_node_allowed(H, body["node"])

// Bodies this person knows how to cut, as display name -> id.
/proc/tailoring_known_bodies(mob/living/human/H)
	var/list/known = list()
	var/list/C = tailoring_bodies()
	for (var/body_id in C)
		var/list/body = C[body_id]
		if (crafting_node_allowed(H, body["node"]))
			known["[body["name"]] ([body["slot"] == "suit" ? "overclothes" : "clothing"], [body["cost"]] fabric)"] = body_id
	return known

// Opaque RGB only: transparent or malformed input must never hide the garment.
/proc/tailoring_color_valid(value)
	if (!istext(value) || length(value) != 7 || copytext(value, 1, 2) != "#")
		return FALSE
	for (var/i = 2, i <= 7, i++)
		if (!findtext("0123456789abcdef", lowertext(copytext(value, i, i + 1))))
			return FALSE
	return TRUE

// The design's colours fitted to the body: one per label, white where unset.
/proc/tailoring_colors(body_id, colors_text)
	var/list/body = tailoring_body(body_id)
	if (!body)
		return null
	var/list/given = istext(colors_text) && length(colors_text) ? splittext(colors_text, "|") : list()
	var/list/colors = list()
	var/count = length(tailoring_piece_labels(body))
	for (var/i = 1, i <= count, i++)
		var/value = i <= given.len ? given[i] : "#ffffff"
		colors += tailoring_color_valid(value) ? lowertext(value) : "#ffffff"
	return colors

/proc/tailoring_design_valid(body_id, colors_text)
	var/list/body = tailoring_body(body_id)
	if (!body)
		return FALSE
	var/list/labels = tailoring_piece_labels(body)
	if (labels.len > TAILORING_MAX_COLOURS)
		return FALSE
	var/list/given = istext(colors_text) && length(colors_text) ? splittext(colors_text, "|") : list()
	if (given.len > labels.len)
		return FALSE
	for (var/value in given)
		if (!tailoring_color_valid(value))
			return FALSE
	return TRUE

// The coloured body, then each coloured piece, then uncoloured fixed parts.
// The same list drives the loose item, the worn sprite and the preview.
/proc/tailoring_layers(body_id, colors_text, worn = FALSE)
	if (!tailoring_design_valid(body_id, colors_text))
		return list()
	var/list/body = tailoring_body(body_id)
	var/art = tailoring_art(body, worn)
	var/list/colors = tailoring_colors(body_id, colors_text)
	var/list/layers = list()
	var/image/main = image(icon = art, icon_state = (!worn && body["item_base"]) ? body["item_base"] : body["base"])
	main.color = colors[1]
	layers += main
	var/list/panels = body["panels"]
	var/index = 1
	for (var/label in panels)
		var/image/piece = image(icon = art, icon_state = panels[label])
		piece.color = colors[++index]
		layers += piece
	var/list/fixed = body["fixed"]
	for (var/state in fixed)
		layers += image(icon = art, icon_state = state)
	return layers

/proc/tailoring_set_color(body_id, colors_text, index, value)
	var/list/colors = tailoring_colors(body_id, colors_text)
	if (!colors || index < 1 || index > colors.len || !tailoring_color_valid(value))
		return colors_text
	colors[index] = lowertext(value)
	return jointext(colors, "|")

// Clothing carries the design itself, so any slot can be tailored later.
/obj/item/clothing
	var/design_body = null
	var/design_colors = null
	var/tmp/list/tailoring_overlays = null

/obj/item/clothing/persistence_runtime_var(key)
	return key == "tailoring_overlays" || ..()

/obj/item/clothing/proc/tailoring_refresh()
	var/list/body = tailoring_body(design_body)
	if (!body || !tailoring_design_valid(design_body, design_colors))
		return FALSE
	name = body["name"]
	icon_state = body["item_base"] ? body["item_base"] : body["base"]
	item_state = body["base"]
	if (body["slot"] == "under")
		if (!item_state_slots)
			item_state_slots = list()
		item_state_slots[slot_w_uniform_str] = body["base"]
	if (body["covers"])
		body_parts_covered = body["covers"]
		cold_protection = body["covers"]
		heat_protection = body["covers"]
	if (tailoring_overlays)
		overlays -= tailoring_overlays
	tailoring_overlays = tailoring_layers(design_body, design_colors)
	overlays += tailoring_overlays
	update_clothing_icon()
	return TRUE

/obj/item/clothing/proc/worn_design_layers()
	if (!design_body)
		return null
	return tailoring_layers(design_body, design_colors, TRUE)

// Saved overlays are derived. Rebuild in normal attachment order: design,
// then accessories, then any existing stains.
/obj/item/clothing/proc/tailoring_rebuild_after_load()
	overlays.Cut()
	tailoring_overlays = null
	tailoring_refresh()
	for (var/obj/item/clothing/accessory/accessory in accessories)
		overlays += accessory.get_inv_overlay()
	if (blood_DNA && blood_DNA.len && blood_overlay)
		overlays += blood_overlay
	if (shit_overlay)
		overlays += shit_overlay
	if (piss_overlay)
		overlays += piss_overlay

/obj/item/clothing/under/tailored
	name = "tailored clothing"
	desc = "Clothing sewn to its owner's own design, with every panel coloured by hand. Ordinary accessories can be added."
	icon_state = "customtunic"
	item_state = "customtunic"
	design_body = "tunic"
	design_colors = "#ffffff"

/obj/item/clothing/under/tailored/on_runtime_spawn()
	..()
	tailoring_refresh()

/obj/item/clothing/under/tailored/after_load()
	..()
	tailoring_rebuild_after_load()

/obj/item/clothing/suit/storage/jacket/tailored
	name = "tailored overclothes"
	desc = "Overclothes sewn to their owner's own design, with every panel coloured by hand. Ordinary accessories can be added."
	icon_state = "customponcho"
	item_state = "customponcho"
	design_body = "poncho"
	design_colors = "#ffffff"

/obj/item/clothing/suit/storage/jacket/tailored/on_runtime_spawn()
	..()
	tailoring_refresh()

/obj/item/clothing/suit/storage/jacket/tailored/after_load()
	..()
	tailoring_rebuild_after_load()

/proc/tailoring_garment_type(list/body)
	return body["slot"] == "suit" ? /obj/item/clothing/suit/storage/jacket/tailored : /obj/item/clothing/under/tailored

// Live preview: four HUD tiles, one per facing, drawn from the same overlays
// as the worn garment. They belong to the client and are never saved.
/client/var/list/tailoring_preview = null

/obj/screen/tailoring_preview
	name = "design preview"
	icon = 'icons/mob/screen/1713Style.dmi'
	icon_state = "block"
	layer = 20
	mouse_opacity = 0

/client/proc/hide_tailoring_preview()
	if (!tailoring_preview)
		return
	screen -= tailoring_preview
	for (var/obj/screen/tailoring_preview/T in tailoring_preview)
		qdel(T)
	tailoring_preview = null

/client/proc/show_tailoring_preview(body_id, colors_text)
	hide_tailoring_preview()
	var/list/body = tailoring_body(body_id)
	if (!body || !tailoring_design_valid(body_id, colors_text))
		return FALSE
	var/list/tiles = list()
	var/list/facings = list(SOUTH, NORTH, EAST, WEST)
	var/list/layers = tailoring_layers(body_id, colors_text, TRUE)
	for (var/i = 1, i <= facings.len, i++)
		var/obj/screen/tailoring_preview/T = new()
		if (prefs && prefs.UI_file)
			T.icon = prefs.UI_file
		T.dir = facings[i]
		T.screen_loc = "WEST+[i * 2 - 1],NORTH-1"
		T.transform = matrix(2, 0, 0, 0, 2, 0)
		T.overlays += layers
		tiles += T
	tailoring_preview = tiles
	screen += tiles
	return TRUE

/obj/item/tailoring_project
	name = "tailoring project"
	desc = "Fabric set aside for one garment. Use it in hand to choose what to make and colour each piece, then cut and sew it. Add cloth or woolcloth sheets to it for larger garments. Cutting locks the design."
	icon = 'icons/obj/materials.dmi'
	icon_state = "sheet-cloth"
	w_class = ITEM_SIZE_NORMAL
	flammable = TRUE
	var/design_body = "long_tunic"
	var/design_colors = "#ffffff"
	// Sheets of fabric held, including the one the project was made from.
	var/fabric = 1
	// 0: editable fabric; 1: cut pieces; 2: consumed, never usable again.
	var/stage = 0
	var/tmp/tailoring_busy = FALSE

/obj/item/tailoring_project/persistence_runtime_var(key)
	return key == "tailoring_busy" || ..()

/obj/item/tailoring_project/proc/actor_ready(mob/living/human/user, turf/site, datum/save_epoch)
	return istype(user) && !QDELETED(src) && !QDELETED(user) && !gcDestroyed && loc == user && (user.l_hand == src || user.r_hand == src) && isturf(user.loc) && user.loc == site && !user.incapacitated() && user.can_use_hands() && !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required && save_epoch == persistence_admission_identity && crafting_node_allowed(user, "weaving")

/obj/item/tailoring_project/proc/wait_for_tailoring(mob/living/human/user, delay)
	return do_after(user, delay, src)

/obj/item/tailoring_project/proc/body_cost()
	var/list/body = tailoring_body(design_body)
	return body ? body["cost"] : TAILORING_MAX_FABRIC + 1

/obj/item/tailoring_project/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/material/cloth) || istype(W, /obj/item/stack/material/woolcloth))
		var/obj/item/stack/material/S = W
		if (stage != 0)
			to_chat(user, SPAN_WARNING("The fabric is already cut."))
			return
		if (fabric >= TAILORING_MAX_FABRIC)
			to_chat(user, SPAN_WARNING("\The [src] already holds as much fabric as any garment needs."))
			return
		if (!S.use(1))
			return
		fabric++
		to_chat(user, SPAN_NOTICE("You add a sheet of fabric. \The [src] now holds [fabric]."))
		return
	return ..()

/obj/item/tailoring_project/attack_self(mob/living/human/user)
	var/turf/site = get_turf(user)
	var/datum/save_epoch = persistence_admission_identity
	if (tailoring_busy || stage >= 2)
		return
	// Say which knowledge is missing: a project can be handed to someone untrained.
	if (!crafting_node_allowed_or_warn(user, "weaving") || !actor_ready(user, site, save_epoch))
		return
	tailoring_busy = TRUE
	design_menu(user, site, save_epoch)
	if (user.client)
		user.client.hide_tailoring_preview()
	tailoring_busy = FALSE

/obj/item/tailoring_project/proc/design_menu(mob/living/human/user, turf/site, datum/save_epoch)
	while (actor_ready(user, site, save_epoch) && (stage == 0 || stage == 1))
		var/list/body = tailoring_body(design_body)
		if (user.client)
			user.client.show_tailoring_preview(design_body, design_colors)
		var/garment = body ? body["name"] : "garment"
		var/list/options = stage == 0 ? list("Choose garment", "Colours", "Cut fabric", "Close") : list("Sew", "Close")
		var/status = stage == 0 ? "Designing a [garment]: it needs [body_cost()] fabric and the project holds [fabric]." : "The [garment] is cut and ready to sew."
		var/choice = WWinput(user, status, "Tailoring", "Close", options)
		if (!actor_ready(user, site, save_epoch) || !choice || choice == "Close")
			return
		switch (choice)
			if ("Choose garment")
				if (stage != 0)
					return
				var/list/known = tailoring_known_bodies(user)
				if (!known.len)
					return
				var/selected = WWinput(user, "Choose the garment to make. The list grows as you learn more tailoring.", "Garment", null, known)
				if (actor_ready(user, site, save_epoch) && stage == 0 && (selected in known) && tailoring_body_allowed(user, known[selected]))
					design_body = known[selected]
					design_colors = jointext(tailoring_colors(design_body, design_colors), "|")
			if ("Colours")
				if (stage != 0 || !body)
					return
				var/list/labels = tailoring_piece_labels(body)
				var/piece = WWinput(user, "Choose a piece to colour. Body colours everything the other pieces leave uncovered.", "Pieces", null, labels)
				if (!actor_ready(user, site, save_epoch) || stage != 0 || !piece || !(piece in labels))
					continue
				var/index = labels.Find(piece)
				var/list/colors = tailoring_colors(design_body, design_colors)
				var/selected_color = WWinput(user, "Choose the [lowertext(piece)] colour.", "Colour", colors[index], "color")
				if (!actor_ready(user, site, save_epoch) || stage != 0 || !tailoring_color_valid(selected_color))
					continue
				design_colors = tailoring_set_color(design_body, design_colors, index, selected_color)
			if ("Cut fabric")
				if (fabric < body_cost())
					to_chat(user, SPAN_WARNING("A [garment] needs [body_cost()] fabric. Add cloth or woolcloth sheets to the project first."))
					continue
				var/confirm = WWinput(user, "Cut this design? You can no longer change the garment or colours afterward.", "Cut fabric", "Keep designing", list("Keep designing", "Cut fabric"))
				if (confirm == "Cut fabric")
					cut_fabric(user, site, save_epoch)
			if ("Sew")
				sew_garment(user, site, save_epoch)
				return

/obj/item/tailoring_project/proc/cut_fabric(mob/living/human/user, turf/site, datum/save_epoch)
	if (!actor_ready(user, site, save_epoch) || stage != 0 || !tailoring_design_valid(design_body, design_colors) || !tailoring_body_allowed(user, design_body) || fabric < body_cost())
		return FALSE
	to_chat(user, SPAN_NOTICE("You start cutting the pattern pieces."))
	if (!wait_for_tailoring(user, 30) || !actor_ready(user, site, save_epoch) || stage != 0 || fabric < body_cost())
		return FALSE
	var/spare = fabric - body_cost()
	stage = 1
	fabric = body_cost()
	var/list/body = tailoring_body(design_body)
	name = "cut [body["name"]] pieces"
	if (spare > 0)
		new /obj/item/stack/material/cloth(site, spare)
	to_chat(user, SPAN_NOTICE("The pieces are cut[spare > 0 ? " and you set aside [spare] spare sheet\s" : ""]. Use the project in hand to sew them together."))
	return TRUE

/obj/item/tailoring_project/proc/sew_garment(mob/living/human/user, turf/site, datum/save_epoch)
	if (!actor_ready(user, site, save_epoch) || stage != 1 || !tailoring_design_valid(design_body, design_colors) || !tailoring_body_allowed(user, design_body))
		return FALSE
	to_chat(user, SPAN_NOTICE("You start sewing the pieces together."))
	if (!wait_for_tailoring(user, 60) || !actor_ready(user, site, save_epoch) || stage != 1)
		return FALSE
	// Clear the actual inventory slot before replacing the paid project. There
	// are no yields from retirement through output, so competing finishers fail.
	if (!user.transfer_held_item_to(src, site))
		return FALSE
	stage = 2
	var/garment_type = tailoring_garment_type(tailoring_body(design_body))
	var/obj/item/clothing/garment = new garment_type(site)
	garment.design_body = design_body
	garment.design_colors = design_colors
	garment.tailoring_refresh()
	qdel(src)
	user.put_in_any_hand_if_possible(garment)
	to_chat(user, SPAN_NOTICE("You finish sewing the [garment.name]."))
	return TRUE

/obj/item/tailoring_project/examine(mob/user)
	..()
	var/list/body = tailoring_body(design_body)
	if (!body)
		return
	if (stage == 0)
		to_chat(user, "Design: [body["name"]]. It needs [body["cost"]] fabric and holds [fabric].")
	else
		to_chat(user, "Design: [body["name"]]. The cut pieces are ready to sew.")

// Projects and dresses from the earlier dress-only version restore as tailoring.
/proc/tailoring_legacy_dress(cut, primary, secondary, accent)
	var/list/ids = list("Layered" = "layered_dress", "Buttoned" = "buttoned_dress", "Laced" = "laced_dress")
	var/body_id = ids[cut]
	if (!body_id)
		return null
	var/list/colors = list("#ffffff", primary, secondary, accent)
	var/list/body = tailoring_body(body_id)
	colors.len = length(tailoring_piece_labels(body))
	for (var/i = 1, i <= colors.len, i++)
		if (!tailoring_color_valid(colors[i]))
			colors[i] = "#ffffff"
	return list(body_id, lowertext(jointext(colors, "|")))

/obj/item/dressmaking_project
	parent_type = /obj/item/tailoring_project
	var/dress_cut = null
	var/primary_color = null
	var/secondary_color = null
	var/accent_color = null

/obj/item/dressmaking_project/after_load()
	..()
	var/list/converted = tailoring_legacy_dress(dress_cut, primary_color, secondary_color, accent_color)
	if (converted)
		design_body = converted[1]
		design_colors = converted[2]
		fabric = max(fabric, body_cost())
		dress_cut = null

/obj/item/clothing/under/tailored_dress
	parent_type = /obj/item/clothing/under/tailored
	var/dress_cut = null
	var/primary_color = null
	var/secondary_color = null
	var/accent_color = null

/obj/item/clothing/under/tailored_dress/after_load()
	var/list/converted = tailoring_legacy_dress(dress_cut, primary_color, secondary_color, accent_color)
	if (converted)
		design_body = converted[1]
		design_colors = converted[2]
		dress_cut = null
	..()

#undef TAILORING_MAX_FABRIC
#undef TAILORING_MAX_COLOURS
