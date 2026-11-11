// Full-game adapter: the standalone Atlas renderer has no gameplay type tree.
// Only exact public identities are linked; never guess a parent/sibling page.
/atom/proc/atlas_resource_id()
	// Do not expose a disguised or renamed object's underlying type through a URL.
	if (name != initial(name))
		return null
	return "[type]"

/obj/item/stack/material/atlas_resource_id()
	// Stack instances can carry a different material from their default subtype.
	// get_material() reads the existing datum; it does not create or consume stock.
	var/material/actual = get_material()
	return actual ? "[actual.type]" : null

/datum/crafting_atlas_reference/proc/examine_link(mob/viewer, atom/target)
	if (!viewer || !viewer.client || !target || QDELETED(target))
		return
	var/resource_id = target.atlas_resource_id()
	if (!resource_id || !resource_exists(resource_id))
		return
	// Existing Topic validates the ID and opens modern or classic presentation.
	// No live target reference, contents, ownership or knowledge state is exported.
	to_chat(viewer, "<a href='?src=\ref[src];atlas_resource=[url_encode(resource_id)]'>View in Crafting Atlas</a>")
