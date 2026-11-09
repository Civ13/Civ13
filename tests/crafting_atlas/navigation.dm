// Execute production rendering and routing with a small, independently specified catalog.
/proc/check_navigation(mob/viewer)
	var/datum/crafting_atlas_reference/reference = new
	reference.load_attempted = TRUE
	reference.resources = list()
	reference.catalog = list()
	reference.recipes = list()
	for (var/i in 1 to 160)
		var/list/entry = list("id" = "n[i]", "name" = "Entry [i]", "kind" = "Fixture", "searchable" = "Entry [i]", "inputs" = list(list("id" = "log", "name" = "<script>log</script>", "quantity" = "1")), "outputs" = list(list("id" = "plank", "name" = "Planks", "quantity" = "4 nominal")), "conditions" = "Power <required>", "unlock_eras" = list(0), "era_label" = "0: Stone Age", "era_basis" = "Fixture tier")
		if (i == 2)
			entry["unlock_eras"] = list(3, 4)
			entry["era_label"] = "3 / 4"
			entry["processor"] = "sawmill"
		if (i == 3)
			entry["unlock_eras"] = list()
			entry["era_label"] = "Unknown / context dependent"
		reference.recipes += list(entry)
	var/default_view = reference.render_html(viewer)
	check_atlas(findtext(default_view, "class='dependency'") && !findtext(default_view, "Page 1."), "navigation default is dependency atlas")
	check_atlas(findtext(default_view, "Entry 150") && !findtext(default_view, "Entry 151"), "navigation index bounded at 150")
	check_atlas(findtext(default_view, "4 nominal") && findtext(default_view, "Outputs"), "navigation output quantity rendered")
	check_atlas(!findtext(default_view, "<script>") && findtext(default_view, "&lt;script&gt;"), "navigation resource escaping")
	check_atlas(findtext(default_view, "Legacy paginated list"), "navigation deliberate legacy link")
	check_atlas(findtext(default_view, "action='byond://?'") && findtext(default_view, "name='src'") && findtext(default_view, "name='atlas_open'"), "navigation form uses explicit BYOND Topic route")
	check_atlas(findtext(reference.render_html(viewer, legacy = TRUE), "Page 1."), "navigation explicit legacy route")
	var/filtered = reference.graph_html(viewer, era = "4")
	check_atlas(findtext(filtered, "1 matching recipes") && findtext(filtered, "Entry 2") && !findtext(filtered, "Entry 1</a>"), "navigation era membership filter")
	check_atlas(findtext(reference.graph_html(viewer, era = "multiple"), "1 matching recipes"), "navigation multiple era filter")
	check_atlas(findtext(reference.graph_html(viewer, era = "unknown"), "1 matching recipes"), "navigation unknown era filter")
	check_atlas(findtext(reference.graph_html(viewer, era = "invalid"), "0 matching recipes"), "navigation invalid era is not Stone Age")
	check_atlas(findtext(reference.graph_html(viewer, processor = "sawmill"), "1 matching recipes"), "navigation processor filter")
	check_atlas(findtext(reference.graph_html(viewer, processor = "invalid"), "0 matching recipes"), "navigation invalid processor empty")
	check_atlas(findtext(reference.graph_html(viewer, "Entry 160"), "Entry 160"), "navigation search reaches beyond index bound")
	check_atlas(findtext(reference.graph_html(viewer, "missing"), "No matching recipes"), "navigation empty search")
	var/unsafe_query = reference.graph_html(viewer, "'><script>")
	check_atlas(!findtext(unsafe_query, "'><script>") && findtext(unsafe_query, "&#39;"), "navigation query attribute escaping")
	check_variants(viewer, reference)
	check_resource_search(viewer)
	check_manual_presentation(viewer, reference)

/datum/crafting_atlas_presenter/manual_fixture
	var/mob/known_viewer

/datum/crafting_atlas_presenter/manual_fixture/manual_hint(mob/viewer, list/recipe)
	return viewer == known_viewer ? "" : "Needs the <Woodworking> manual"

/proc/check_manual_presentation(mob/viewer, datum/crafting_atlas_reference/reference)
	var/datum/crafting_atlas_presenter/original = crafting_atlas_presenter
	var/datum/crafting_atlas_presenter/manual_fixture/presenter = new
	crafting_atlas_presenter = presenter
	var/before = json_encode(reference.recipes)
	check_atlas(findtext(reference.graph_html(viewer), "Needs the &lt;Woodworking&gt; manual"), "manual hint graph escaping")
	check_atlas(findtext(reference.page_html(viewer), "Needs the &lt;Woodworking&gt; manual"), "manual hint pages visible")
	presenter.known_viewer = viewer
	check_atlas(!findtext(reference.graph_html(viewer), "Needs the"), "manual learning refresh")
	var/mob/other = new
	check_atlas(findtext(reference.graph_html(other), "Needs the"), "manual viewer isolation")
	check_atlas(!findtext(reference.page_html(viewer), "Needs the"), "manual repeated navigation")
	check_atlas(json_encode(reference.recipes) == before, "manual does not mutate shared catalog")
	crafting_atlas_presenter = original
