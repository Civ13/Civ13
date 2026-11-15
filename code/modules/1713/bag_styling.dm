// Restyling finished bags, quivers, bandoliers and shoulder belts.
//
// A tailor holds the bag in one hand and an uncut tailoring project in the
// other, uses the bag on the project and picks a dye for its fabric, a dye
// for its straps and a trim. The work takes one sheet from the project.
//
// Styling is looks only. The bag stays the same item of the same type, so
// its storage, pouches and attachment points cannot change: the style is one
// text var and a few coloured overlays drawn over the unchanged sprite. The
// overlay masks come from tests/sprites/create_bag_styles.py.

#define BAG_STYLE_TIME 40
#define BAG_STYLE_UNSET "-"

// Exact type -> list(mask id, zone labels in drawing order). Subtypes are
// other bags with their own art, so they are not styled by their parent's row.
var/global/list/bag_style_kinds = list(
	"/obj/item/weapon/storage/backpack" = list("backpack", list("Fabric", "Straps", "Trim")),
	"/obj/item/weapon/storage/backpack/satchel" = list("satchel", list("Fabric", "Straps", "Trim")),
	"/obj/item/weapon/storage/backpack/duffel" = list("duffel", list("Fabric", "Straps", "Trim")),
	"/obj/item/weapon/storage/backpack/rucksack" = list("rucksack", list("Fabric", "Straps", "Trim")),
	"/obj/item/weapon/storage/backpack/quiver" = list("quiver", list("Fabric", "Straps", "Trim")),
	"/obj/item/weapon/storage/backpack/sling_bag" = list("sling_bag", list("Fabric", "Straps", "Trim")),
	"/obj/item/clothing/accessory/storage/webbing" = list("bandolier", list("Straps", "Trim")),
	"/obj/item/clothing/accessory/storage/baldric" = list("baldric", list("Straps", "Trim")))

/obj/item
	// A tailor's restyling: one colour per zone of bag_style_kinds, "|" joined,
	// "-" where that part was left as made. Null on anything never restyled.
	var/bag_style = null
	var/tmp/list/bag_style_overlays = null

/obj/item/persistence_runtime_var(key)
	return key == "bag_style_overlays" || ..()

/proc/bag_style_kind(obj/item/I)
	return istype(I) ? bag_style_kinds["[I.type]"] : null

// One entry per zone: a colour, or null where the bag is as it was made.
/proc/bag_style_colors(obj/item/I, style_text)
	var/list/kind = bag_style_kind(I)
	if (!kind)
		return null
	var/list/zones = kind[2]
	var/list/given = istext(style_text) && length(style_text) ? splittext(style_text, "|") : list()
	var/list/colors = list()
	for (var/i = 1, i <= zones.len, i++)
		var/value = i <= given.len ? given[i] : null
		colors += tailoring_color_valid(value) ? lowertext(value) : null
	return colors

/proc/bag_style_text(list/colors)
	var/list/parts = list()
	var/any = FALSE
	for (var/value in colors)
		parts += value ? value : BAG_STYLE_UNSET
		any = any || value
	return any ? jointext(parts, "|") : null

// The coloured overlays of a style, for the loose item or the worn sprite.
/proc/bag_style_layers(obj/item/I, worn = FALSE)
	var/list/layers = list()
	var/list/kind = (istype(I) && I.bag_style) ? bag_style_kind(I) : null
	if (!kind)
		return layers
	var/list/zones = kind[2]
	var/list/colors = bag_style_colors(I, I.bag_style)
	for (var/i = 1, i <= zones.len, i++)
		if (!colors[i])
			continue
		var/image/zone
		if (worn)
			zone = image(icon = 'icons/mob/bag_styles.dmi', icon_state = "[kind[1]]_[lowertext(zones[i])]")
		else
			zone = image(icon = 'icons/obj/clothing/bag_styles.dmi', icon_state = "[kind[1]]_[lowertext(zones[i])]")
		zone.color = colors[i]
		layers += zone
	return layers

/obj/item/proc/bag_style_refresh()
	if (bag_style_overlays)
		overlays -= bag_style_overlays
	bag_style_overlays = bag_style_layers(src, FALSE)
	if (bag_style_overlays.len)
		overlays += bag_style_overlays
	else
		bag_style_overlays = null
	if (ismob(loc))
		var/mob/M = loc
		M.update_inv_back()

// An attached bandolier draws from cached images; rebuild them with the style.
/obj/item/clothing/accessory/bag_style_refresh()
	inv_overlay = null
	mob_overlay = null
	..()

// Saved overlays are derived: clear them and draw the style once.
/obj/item/proc/bag_style_rebuild_after_load()
	if (!bag_style || !bag_style_kind(src))
		return
	overlays.Cut()
	bag_style_overlays = null
	bag_style_refresh()
	if (blood_DNA && blood_DNA.len && blood_overlay)
		overlays += blood_overlay

/obj/item/weapon/storage/backpack/after_load()
	..()
	bag_style_rebuild_after_load()

/obj/item/clothing/accessory/storage/after_load()
	..()
	bag_style_rebuild_after_load()

/proc/bag_style_describe(obj/item/I)
	var/list/kind = I.bag_style ? bag_style_kind(I) : null
	if (!kind)
		return null
	var/list/zones = kind[2]
	var/list/colors = bag_style_colors(I, I.bag_style)
	var/list/parts = list()
	for (var/i = 1, i <= zones.len, i++)
		if (!colors[i])
			continue
		var/dye = tailoring_dye_name(colors[i])
		parts += "[dye ? dye : "dyed"] [lowertext(zones[i])]"
	return parts.len ? "A tailor has restyled it: [english_list(parts)]." : null

/obj/item/weapon/storage/backpack/examine(mob/user)
	..()
	var/styled = bag_style_describe(src)
	if (styled)
		to_chat(user, styled)

/obj/item/clothing/accessory/storage/examine(mob/user)
	..()
	var/styled = bag_style_describe(src)
	if (styled)
		to_chat(user, styled)

// The bag must stay in the tailor's other hand for the whole job.
/obj/item/tailoring_project/proc/alteration_ready(mob/living/human/user, turf/site, datum/save_epoch, obj/item/target)
	return actor_ready(user, site, save_epoch) && stage == 0 && fabric >= 1 && istype(target) && !QDELETED(target) && target.loc == user && (user.l_hand == target || user.r_hand == target)

// A dye this person knows, null to cancel, or BAG_STYLE_UNSET to undo the part.
/obj/item/tailoring_project/proc/choose_style_dye(mob/living/human/user, zone, current)
	var/list/dyes = tailoring_known_dyes(user)
	if (!dyes)
		var/how = WWinput(user, "Dye the [lowertext(zone)], or leave it as it was made?", zone, "Dye", list("Dye", "As it was made", "Cancel"))
		if (how == "As it was made")
			return BAG_STYLE_UNSET
		if (how != "Dye")
			return null
		return WWinput(user, "Choose the [lowertext(zone)] colour.", "Colour", current ? current : "#ffffff", "color")
	var/list/menu = list("As it was made" = BAG_STYLE_UNSET)
	for (var/dye in dyes)
		menu["[dye][dyes[dye] == current ? " (current)" : ""]"] = dyes[dye]
	var/picked = WWinput(user, "Choose a dye for the [lowertext(zone)]. Learning more tailoring brings more dyes.", "Dye", null, menu)
	return (picked in menu) ? menu[picked] : null

// Every dye in a style must be one this person can make.
/proc/bag_style_allowed(mob/living/human/H, list/colors)
	if (!tailoring_known_dyes(H)) // null: this person can mix any colour
		return TRUE
	for (var/value in colors)
		if (value && !crafting_node_allowed(H, tailoring_dye_node(value)))
			return FALSE
	return TRUE

/obj/item/tailoring_project/proc/style_bag(mob/living/human/user, obj/item/bag)
	var/turf/site = get_turf(user)
	var/datum/save_epoch = persistence_admission_identity
	var/list/kind = bag_style_kind(bag)
	if (!kind || tailoring_busy)
		return
	if (stage != 0)
		to_chat(user, SPAN_WARNING("This fabric is already cut for a garment. Restyling needs an uncut tailoring project."))
		return
	if (!crafting_node_allowed_or_warn(user, "weaving"))
		return
	if (!alteration_ready(user, site, save_epoch, bag))
		to_chat(user, SPAN_WARNING("Hold \the [bag] in one hand and the tailoring project in the other."))
		return
	tailoring_busy = TRUE
	style_bag_menu(user, site, save_epoch, bag, kind)
	if (!QDELETED(src))
		tailoring_busy = FALSE

/obj/item/tailoring_project/proc/style_bag_menu(mob/living/human/user, turf/site, datum/save_epoch, obj/item/bag, list/kind)
	var/list/zones = kind[2]
	var/list/colors = bag_style_colors(bag, bag.bag_style)
	while (alteration_ready(user, site, save_epoch, bag))
		var/list/menu = list()
		for (var/i = 1, i <= zones.len, i++)
			var/dye = colors[i] ? tailoring_dye_name(colors[i]) : null
			menu["[zones[i]]: [colors[i] ? (dye ? dye : colors[i]) : "as made"]"] = i
		menu["Sew the changes (1 sheet)"] = "sew"
		menu["Close"] = "close"
		var/picked = WWinput(user, "Restyle \the [bag]. This changes its looks only: what it holds and how it is worn stay the same. The work uses one sheet from the project.", "Restyle", "Close", menu)
		if (!alteration_ready(user, site, save_epoch, bag) || !(picked in menu) || menu[picked] == "close")
			return
		if (menu[picked] == "sew")
			break
		var/index = menu[picked]
		var/selected = choose_style_dye(user, zones[index], colors[index])
		if (selected == BAG_STYLE_UNSET)
			colors[index] = null
		else if (tailoring_color_valid(selected))
			colors[index] = lowertext(selected)
	sew_bag_style(user, site, save_epoch, bag, colors)

// Pays one sheet and the time, then puts the chosen colours on the bag.
/obj/item/tailoring_project/proc/sew_bag_style(mob/living/human/user, turf/site, datum/save_epoch, obj/item/bag, list/colors)
	var/list/kind = bag_style_kind(bag)
	if (!kind || !islist(colors) || colors.len != length(kind[2]) || !alteration_ready(user, site, save_epoch, bag))
		return FALSE
	for (var/value in colors)
		if (value && !tailoring_color_valid(value))
			return FALSE
	var/new_style = bag_style_text(colors)
	if (new_style == bag.bag_style)
		to_chat(user, SPAN_NOTICE("\The [bag] already looks like that."))
		return FALSE
	if (!bag_style_allowed(user, colors))
		to_chat(user, SPAN_WARNING("You don't know how to make one of those dyes."))
		return FALSE
	to_chat(user, SPAN_NOTICE("You start restyling \the [bag]."))
	if (!wait_for_tailoring(user, BAG_STYLE_TIME) || !alteration_ready(user, site, save_epoch, bag) || !bag_style_allowed(user, colors))
		return FALSE
	if (!spend_alteration_sheet(user, site))
		return FALSE
	bag.bag_style = new_style
	bag.bag_style_refresh()
	user.update_inv_l_hand()
	user.update_inv_r_hand()
	to_chat(user, SPAN_NOTICE("You finish restyling \the [bag]."))
	return TRUE

// One sheet per job. A project down to its last sheet is used up.
/obj/item/tailoring_project/proc/spend_alteration_sheet(mob/living/human/user, turf/site)
	if (stage != 0 || fabric < 1)
		return FALSE
	if (fabric > 1)
		fabric--
		return TRUE
	if (!user.transfer_held_item_to(src, site))
		return FALSE
	stage = 2
	fabric = 0
	qdel(src)
	return TRUE
