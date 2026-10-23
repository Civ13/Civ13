// Production renderer contract for grouped catalog identity and navigation.
/proc/check_variants(mob/viewer, datum/crafting_atlas_reference/reference)
	// Presentation groups keep old catalog IDs addressable without duplicate rows.
	var/list/group = reference.recipes[1]
	group["name"] = "Grouped arrow"
	group["searchable"] = "Grouped arrow wood archery"
	group["variants"] = list(list("id" = "old_global", "kind" = "Material / global", "file" = "config/crafting/global.txt", "line" = 10), list("id" = "old_camp", "kind" = "Material / camp", "file" = "config/crafting/camp.txt", "line" = 20))
	for (var/i in 1 to 3)
		var/chosen = reference.graph_html(viewer, "Grouped arrow", recipe_id = "old_camp")
		check_atlas(findtext(chosen, "1 matching recipes") && findtext(chosen, "value='old_camp' selected"), "variant grouped count and repeated old ID selection")
		check_atlas(findtext(chosen, "bgcolor='#254366'>Material / camp") && findtext(chosen, "Catalog source: <a href='https://github.com/Civ13/Civ13/blob/master/config/crafting/camp.txt#L20'"), "variant selected transformation and source")
		check_atlas(findtext(chosen, "aria-label='Transformation / catalog variant'") && findtext(chosen, "Show variant"), "variant accessible explicit selector")
	var/global_variant = reference.graph_html(viewer, "global.txt", recipe_id = "old_camp")
	check_atlas(findtext(global_variant, "1 matching recipes") && findtext(global_variant, "value='old_global' selected") && !findtext(global_variant, "old_camp"), "variant search replaces excluded catalog")
	var/new_filter = reference.graph_html(viewer, era = "4", recipe_id = "old_camp")
	check_atlas(findtext(new_filter, "Entry 2") && !findtext(new_filter, "old_camp"), "variant era change clears excluded selection")
	check_atlas(!findtext(reference.graph_html(viewer, "missing", recipe_id = "old_camp"), "Show variant"), "variant empty filter clears selector")
	var/list/unchanged = reference.matching_variants(group)
	check_atlas(group["id"] == "n1" && unchanged.len == 2, "variant rendering does not mutate catalog")
	reference.recipes = reference.recipes.Copy(1, 14)
	var/legacy_variant = reference.page_html(viewer, page = 1, recipe_id = "old_camp")
	check_atlas(findtext(legacy_variant, "13 matching recipes") && findtext(legacy_variant, "value='old_camp' selected") && findtext(legacy_variant, "name='atlas_page' value='1'"), "variant legacy count and form keep page")
	var/last_page = reference.page_html(viewer, page = 2)
	check_atlas(findtext(last_page, "Entry 13") && !findtext(last_page, "Grouped arrow") && !findtext(last_page, ">Next</a>"), "variant grouped legacy page boundary")
