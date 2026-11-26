// Minor alterations to finished tailored clothing, hats, gloves, footwear and belts.
//
// A tailor holds the finished garment in one hand and an uncut tailoring
// project of the same material in the other, and uses the garment on the
// project. One job re-dyes or swaps up to TAILORING_ALTER_MAX parts for one
// sheet. It is never a redesign: the garment keeps its body, its name and its
// designer, a swapped-in piece may not need extra fabric, and what the garment
// covers may not change. Bags and bandoliers are restyled in bag_styling.dm.

#define TAILORING_ALTER_MAX 2
#define TAILORING_ALTER_TIME 40

// Menu labels mapped to their full colour indices. Body and panels are
// always drawn; an optional piece only draws when its selected state exists.
/proc/tailoring_alteration_dye_slots(body_id, pieces_text)
	var/list/visible = list()
	var/list/body = tailoring_body(body_id)
	if (!body)
		return visible
	var/list/labels = tailoring_piece_labels(body)
	var/list/options = body["options"]
	var/list/chosen = tailoring_pieces(body_id, pieces_text)
	for (var/i = 1, i <= labels.len, i++)
		var/label = labels[i]
		var/list/variants = options ? options[label] : null
		if (!variants || variants[chosen[label]])
			visible[label] = i
	return visible

// Keep the stored colour of any piece the altered garment will not draw.
/proc/tailoring_alteration_colors(body_id, old_colors, new_colors, new_pieces)
	var/list/colors = tailoring_colors(body_id, old_colors)
	var/list/proposed = tailoring_colors(body_id, new_colors)
	var/list/visible = tailoring_alteration_dye_slots(body_id, new_pieces)
	for (var/label in visible)
		var/i = visible[label]
		colors[i] = proposed[i]
	return jointext(colors, "|")

// How many parts differ: each changed dye visible in the new design and
// each swapped piece counts once.
/proc/tailoring_alteration_changes(body_id, old_colors, old_pieces, new_colors, new_pieces)
	var/list/before = tailoring_colors(body_id, old_colors)
	var/list/after = tailoring_colors(body_id, new_colors)
	if (!before || !after)
		return 0
	var/changes = 0
	var/list/visible = tailoring_alteration_dye_slots(body_id, new_pieces)
	for (var/label in visible)
		var/i = visible[label]
		if (before[i] != after[i])
			changes++
	var/list/had = tailoring_pieces(body_id, old_pieces)
	var/list/has = tailoring_pieces(body_id, new_pieces)
	for (var/label in had)
		if (had[label] != has[label])
			changes++
	return changes

// What a design covers as a number: a body that leaves cover to its item has none.
/proc/tailoring_alteration_covers(body_id, pieces_text)
	var/covers = tailoring_design_covers(body_id, pieces_text)
	return covers ? covers : 0

// Why this change is more than a minor alteration, or null when it is one.
/proc/tailoring_alteration_problem(mob/living/human/H, obj/item/clothing/G, new_colors, new_pieces)
	var/list/body = istype(G) ? tailoring_body(G.design_body) : null
	if (!body || !tailoring_design_valid(G.design_body, G.design_colors, G.design_pieces))
		return "That is not tailored clothing."
	if (!tailoring_design_valid(G.design_body, new_colors, new_pieces))
		return "That design cannot be sewn."
	var/changes = tailoring_alteration_changes(G.design_body, G.design_colors, G.design_pieces, new_colors, new_pieces)
	if (!changes)
		return "Nothing would change."
	if (changes > TAILORING_ALTER_MAX)
		return "That is more than a minor alteration. Change at most [TAILORING_ALTER_MAX] parts in one job."
	var/list/options = body["options"]
	var/list/had = tailoring_pieces(G.design_body, G.design_pieces)
	var/list/has = tailoring_pieces(G.design_body, new_pieces)
	for (var/label in options)
		if (had[label] == has[label])
			continue
		var/list/variants = options[label]
		var/state = variants[has[label]]
		var/list/info = state ? tailoring_piece_info[state] : null
		if (info && info[2])
			return "A [lowertext(has[label])] [lowertext(label)] needs more fabric than an alteration allows."
		if (!tailoring_variant_allowed(H, body, state))
			return "You don't know how to make that [lowertext(label)]."
	if (tailoring_alteration_covers(G.design_body, new_pieces) != tailoring_alteration_covers(G.design_body, G.design_pieces))
		return "An alteration cannot change what the garment covers."
	// Only a newly chosen, visible dye must be known.
	var/list/before = tailoring_colors(G.design_body, G.design_colors)
	var/list/after = tailoring_colors(G.design_body, new_colors)
	if (tailoring_known_dyes(H)) // null: this person can mix any colour
		var/list/visible = tailoring_alteration_dye_slots(G.design_body, new_pieces)
		for (var/label in visible)
			var/i = visible[label]
			if (before[i] != after[i] && !crafting_node_allowed(H, tailoring_dye_node(after[i])))
				return "You don't know how to make that dye."
	return null

// The project must be the garment's own material.
/obj/item/tailoring_project/proc/alteration_material_fits(obj/item/clothing/G)
	return G.design_fabric ? G.design_fabric == fabric_kind : tailoring_body_fits(G.design_body, fabric_kind)

/obj/item/tailoring_project/proc/alter_garment(mob/living/human/user, obj/item/clothing/G)
	var/turf/site = get_turf(user)
	var/datum/save_epoch = persistence_admission_identity
	var/list/body = tailoring_body(G.design_body)
	if (!body || tailoring_busy)
		return
	if (stage != 0)
		to_chat(user, SPAN_WARNING("This fabric is already cut for a garment. An alteration needs an uncut tailoring project."))
		return
	if (!crafting_node_allowed_or_warn(user, "weaving"))
		return
	if (!alteration_material_fits(G))
		var/list/material = tailoring_fabric(G.design_fabric)
		to_chat(user, SPAN_WARNING("\The [G] is [G.design_fabric ? material["name"] : tailoring_body_fabric_names(G.design_body)]. Alter it with a tailoring project of the same material."))
		return
	if (!alteration_ready(user, site, save_epoch, G))
		to_chat(user, SPAN_WARNING("Hold \the [G] in one hand and the tailoring project in the other."))
		return
	tailoring_busy = TRUE
	alter_garment_menu(user, site, save_epoch, G)
	if (user.client)
		user.client.hide_tailoring_preview()
	if (!QDELETED(src))
		tailoring_busy = FALSE

/obj/item/tailoring_project/proc/alter_garment_menu(mob/living/human/user, turf/site, datum/save_epoch, obj/item/clothing/G)
	var/body_id = G.design_body
	var/list/body = tailoring_body(body_id)
	var/new_colors = jointext(tailoring_colors(body_id, G.design_colors), "|")
	var/new_pieces = G.design_pieces
	while (alteration_ready(user, site, save_epoch, G) && G.design_body == body_id)
		if (user.client)
			user.client.show_tailoring_preview(body_id, new_colors, new_pieces, G.design_fabric)
		var/changes = tailoring_alteration_changes(body_id, G.design_colors, G.design_pieces, new_colors, new_pieces)
		var/list/menu = list("Colours")
		if (length(body["options"]))
			menu += "Pieces"
		menu += list("Sew the changes (1 sheet)", "Start again", "Close")
		var/choice = WWinput(user, "Alter \the [G]: re-dye or swap up to [TAILORING_ALTER_MAX] parts. The garment itself, its name and what it covers stay the same. [changes] part\s changed so far. The work uses one sheet from the project.", "Alteration", "Close", menu)
		if (!alteration_ready(user, site, save_epoch, G) || !choice || choice == "Close")
			return
		switch (choice)
			if ("Start again")
				new_colors = jointext(tailoring_colors(body_id, G.design_colors), "|")
				new_pieces = G.design_pieces
			if ("Colours")
				var/list/visible = tailoring_alteration_dye_slots(body_id, new_pieces)
				var/piece = WWinput(user, "Choose a piece to re-dye.", "Pieces", null, visible)
				if (!alteration_ready(user, site, save_epoch, G) || !(piece in visible))
					continue
				var/index = visible[piece]
				var/list/colors = tailoring_colors(body_id, new_colors)
				var/selected = choose_dye(user, piece, colors[index])
				if (alteration_ready(user, site, save_epoch, G) && tailoring_color_valid(selected))
					new_colors = tailoring_set_color(body_id, new_colors, index, selected)
			if ("Pieces")
				new_pieces = choose_alteration_piece(user, site, save_epoch, G, new_pieces)
			if ("Sew the changes (1 sheet)")
				sew_alteration(user, site, save_epoch, G, new_colors, new_pieces)
				return

// Offers only swaps an alteration allows: known pieces that need no extra
// fabric and leave the garment covering what it covers now.
/obj/item/tailoring_project/proc/choose_alteration_piece(mob/living/human/user, turf/site, datum/save_epoch, obj/item/clothing/G, pieces_text)
	var/body_id = G.design_body
	var/list/body = tailoring_body(body_id)
	var/list/options = body["options"]
	var/list/chosen = tailoring_pieces(body_id, pieces_text)
	var/list/menu = list()
	for (var/label in options)
		menu["[label]: [lowertext(chosen[label])]"] = label
	var/picked = WWinput(user, "Choose a piece to swap.", "Pieces", null, menu)
	if (!alteration_ready(user, site, save_epoch, G) || !(picked in menu))
		return pieces_text
	var/label = menu[picked]
	var/list/variants = options[label]
	var/covers = tailoring_alteration_covers(body_id, G.design_pieces)
	var/list/allowed = list()
	for (var/variant in variants)
		var/state = variants[variant]
		var/list/info = state ? tailoring_piece_info[state] : null
		if (!tailoring_variant_allowed(user, body, state) || (info && info[2]))
			continue
		if (tailoring_alteration_covers(body_id, tailoring_set_piece(body_id, pieces_text, label, variant)) != covers)
			continue
		allowed += variant
	if (!allowed.len)
		to_chat(user, SPAN_WARNING("No other [lowertext(label)] is a small enough change for an alteration."))
		return pieces_text
	var/selected = WWinput(user, "Choose the [lowertext(label)]. Bigger changes need a new garment.", label, null, allowed)
	if (!alteration_ready(user, site, save_epoch, G) || !(selected in allowed))
		return pieces_text
	return tailoring_set_piece(body_id, pieces_text, label, selected)

// Pays one sheet and the time, then puts the altered design on the garment.
/obj/item/tailoring_project/proc/sew_alteration(mob/living/human/user, turf/site, datum/save_epoch, obj/item/clothing/G, new_colors, new_pieces)
	if (!alteration_ready(user, site, save_epoch, G) || !istype(G) || !alteration_material_fits(G))
		return FALSE
	var/problem = tailoring_alteration_problem(user, G, new_colors, new_pieces)
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	var/body_id = G.design_body
	var/old_colors = G.design_colors
	var/old_pieces = G.design_pieces
	to_chat(user, SPAN_NOTICE("You start altering \the [G]."))
	// The garment must still be the one the tailor looked at when the work ends.
	if (!wait_for_tailoring(user, TAILORING_ALTER_TIME) || !alteration_ready(user, site, save_epoch, G) || G.design_body != body_id || G.design_colors != old_colors || G.design_pieces != old_pieces || tailoring_alteration_problem(user, G, new_colors, new_pieces))
		return FALSE
	if (!spend_alteration_sheet(user, site))
		return FALSE
	G.design_colors = tailoring_alteration_colors(body_id, old_colors, new_colors, new_pieces)
	G.design_pieces = length(body_options(body_id)) ? tailoring_pieces_text(tailoring_pieces(body_id, new_pieces)) : null
	G.tailoring_refresh()
	user.update_inv_l_hand()
	user.update_inv_r_hand()
	to_chat(user, SPAN_NOTICE("You finish altering \the [G]."))
	return TRUE

/obj/item/tailoring_project/proc/body_options(body_id)
	var/list/body = tailoring_body(body_id)
	return body ? body["options"] : null
