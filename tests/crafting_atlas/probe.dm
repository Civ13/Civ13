var/constructed_items = 0
var/atlas_failed = FALSE
/obj/item/New()
	constructed_items++
	..()
/obj/item/weapon/paper
	icon = PAPER_ICON
	icon_state = "paper"
/proc/to_chat(mob/viewer, message)
	return
/proc/check_atlas(condition, message)
	if (!condition)
		atlas_failed = TRUE
		world.log << "ATLAS FAIL: [message]"
		text2file(message, "failed.txt")
/world/New()
	OpenPort("none")
	check_atlas(!world.port && !OpenPort(12345), "fixture refuses listening ports")
	text2file("closed", "port-closed.txt")
	var/datum/crafting_atlas_reference/cold_reference = new
	check_atlas(cold_reference.resource_exists("fixture"), "cold resource navigation loads catalog")
	check_atlas(!cold_reference.resource_exists("absent"), "unknown resource rejected")
	cold_reference.resources = null
	check_atlas(!cold_reference.resource_exists("fixture"), "invalid catalog resource lookup fails closed")
	var/mob/viewer = new
	check_navigation(viewer)
	check_atlas(crafting_atlas_reference.load_catalog(), "catalog load")
	var/first_page = crafting_atlas_reference.page_html(viewer)
	check_atlas(findtext(first_page, "12 matching recipes") == 0, "fixture contains thirteen records")
	check_atlas(findtext(first_page, "Recipe 12") && !findtext(first_page, "Recipe 13"), "twelve-entry bound")
	check_atlas(findtext(first_page, "Next"), "next page navigation")
	var/second_page = crafting_atlas_reference.page_html(viewer, "", 2)
	check_atlas(findtext(second_page, "Recipe 13") && !findtext(second_page, "Recipe 12"), "second page")
	var/search_page = crafting_atlas_reference.page_html(viewer, "Needle")
	check_atlas(findtext(search_page, "1 matching recipes") && findtext(search_page, "Recipe 13"), "ingredient search")
	check_atlas(!findtext(first_page, "<script>alert"), "HTML escaping")
	check_atlas(findtext(first_page, "&lt;script&gt;"), "escaped label appears")
	check_atlas(findtext(first_page, ".png") && findtext(first_page, "Source symbol"), "genuine fallback sprite")
	check_atlas(findtext(first_page, "Paper variant") && findtext(first_page, "Inherited default"), "validated state variant sprite")
	check_atlas(findtext(first_page, "atlas_resource="), "resource acquisition navigation")
	check_atlas(findtext(crafting_atlas_reference.acquisition_html("missing"), "No reviewed gathering instructions"), "missing guidance is explicit")
	var/list/routes = list()
	for (var/i in 1 to 13)
		routes += list(list("name" = "Route [i]", "steps" = list("Use shovel", "Collect clay"), "tools" = "<script>shovel</script>", "conditions" = "Map clay terrain", "status" = "Conditional"))
	crafting_atlas_reference.catalog["acquisition"] = list("sample" = routes)
	var/guidance = crafting_atlas_reference.acquisition_html("sample")
	check_atlas(findtext(guidance, "Use shovel") && findtext(guidance, "Map clay terrain"), "structured route instructions and gates")
	check_atlas(!findtext(guidance, "<script>") && findtext(guidance, "&lt;script&gt;"), "acquisition text escaping")
	check_atlas(findtext(guidance, "Route 12") && !findtext(guidance, "Route 13"), "twelve acquisition route bound")
	check_atlas(constructed_items == 0, "viewer must not construct item prototypes")
	check_atlas(findtext(crafting_atlas_reference.page_html(viewer, "not-present"), "0 matching recipes"), "empty search")
	crafting_atlas_reference.recipes = null
	check_atlas(!crafting_atlas_reference.load_catalog(), "invalid cached catalog fails closed")
	if (!atlas_failed)
		text2file("PASS", "passed.txt")
	del(world)

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
