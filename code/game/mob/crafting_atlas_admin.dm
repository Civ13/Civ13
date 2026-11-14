// Admin-only section of the Crafting Atlas: things staff deliberately leave
// out of every public reference (the generated UI/crafting-atlas.json, the
// published web atlas and the wiki). Entries are built at runtime from the type
// itself, so nothing listed here is ever written to a generated or published file.
// scripts/atlas/admin_only.py reads this list and fails the atlas build if any
// listed type, or a subtype of one, reaches the public catalog.
//
// Add a type here on purpose, with a short note for other staff. Keep the
// note about why it stays out of the public atlas, not how to find or use it.
var/global/list/crafting_atlas_admin_only = list(
	/obj/item/weapon/book/divine = "A god's own book. Hidden divine mechanic; only an admin verb writes the original.",
	/obj/item/cursedtreasure = "Cursed loot. Its effect is a discovery for players.",
	/obj/item/weapon/moldy_ritual = "Event summoning scroll. Its effect is a discovery for players.")

/proc/crafting_atlas_admin_reader(mob/viewer)
	return viewer && viewer.client && check_rights(R_ADMIN, FALSE, viewer)

// The listed type a reader may open; null for every non-admin reader or unknown id.
/proc/crafting_atlas_admin_type(mob/viewer, resource_id)
	if (!istext(resource_id) || !crafting_atlas_admin_reader(viewer))
		return null
	var/typepath = text2path(resource_id)
	if (!typepath || !(typepath in crafting_atlas_admin_only))
		return null
	return typepath

/datum/crafting_atlas_presenter/tgui/proc/admin_view(mob/viewer, typepath)
	var/atom/prototype = typepath
	var/id = "[typepath]"
	var/image_file = ""
	var/icon_file = initial(prototype.icon)
	var/state = initial(prototype.icon_state)
	if (icon_file && (state in icon_states(icon_file)))
		image_file = "atlas_[md5(id)].png"
		viewer << browse_rsc(icon(icon_file, state, SOUTH, 1), image_file)
	var/name = initial(prototype.name)
	return list("id" = id, "name" = html_encode(name ? "[name]" : id), "image" = image_file, "note" = html_encode("[crafting_atlas_admin_only[typepath]]"))

// Listed entries matching every search word; all of them for an empty search.
/datum/crafting_atlas_presenter/tgui/proc/admin_entries(datum/crafting_atlas_reference/reference, mob/viewer, list/words)
	var/list/rows = list()
	if (!crafting_atlas_admin_reader(viewer))
		return rows
	for (var/typepath in crafting_atlas_admin_only)
		var/atom/prototype = typepath
		if (words.len && !all_words(reference.search_text("[initial(prototype.name)] [typepath]"), words))
			continue
		rows += list(admin_view(viewer, typepath))
	return rows

// The page of one listed type: its own name, examine text and the staff note.
/datum/crafting_atlas_presenter/tgui/proc/admin_resource_model(mob/viewer, list/data, typepath)
	var/atom/prototype = typepath
	var/list/view = admin_view(viewer, typepath)
	var/desc = initial(prototype.desc)
	data["guidance"] = list("id" = view["id"], "name" = view["name"], "image" = view["image"], "admin_note" = view["note"], "admin_only" = TRUE,
		"kind" = "Admin only", "desc" = html_encode(desc ? "[desc]" : ""), "stats" = list(), "entity" = FALSE, "heading" = "Staff note on", "routes" = list(), "more" = FALSE,
		"found_in" = list(), "made_by" = list(), "used_in" = list(), "made_here" = list(), "made_by_count" = 0, "used_in_count" = 0, "made_here_count" = 0)
	data["query"] = ""
	return data
