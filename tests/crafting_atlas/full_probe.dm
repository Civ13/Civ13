/world/New()
	OpenPort("none")
	var/mob/viewer = new
	check_atlas(crafting_atlas_reference.load_catalog(), "full production catalog load")
	check_atlas(crafting_atlas_reference.recipes.len == ATLAS_EXPECTED_RECIPES, "all current records loaded")
	var/first_page = crafting_atlas_reference.page_html(viewer)
	check_atlas(findtext(first_page, "Next"), "full catalog bounded navigation")
	var/assembly_page = crafting_atlas_reference.page_html(viewer, "Finish Flintlock pistol assembly")
	check_atlas(findtext(assembly_page, "1 matching recipes"), "exact component route searchable")
	check_atlas(findtext(assembly_page, "flint-loaded mechanism") && findtext(assembly_page, "pistol stock with barrel"), "stateful prerequisites render")
	check_atlas(constructed_items == 0, "full catalog no item constructors")
	if (!atlas_failed)
		text2file("PASS", "passed.txt")
	del(world)

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
