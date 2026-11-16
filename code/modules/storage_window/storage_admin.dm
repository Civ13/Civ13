// Admin > View Storage (storage overhaul PR 7, docs/storage-window.md): shows
// everything inside a container, a closet, a structure's store or a mob, nested
// bags included, with who has already searched each thing and which faction
// filled it. Read-only; it marks nothing as seen.

/client/proc/admin_view_storage(atom/movable/O as obj|mob in range(7))
	set category = "Admin"
	set name = "View Storage"
	if (!holder || !check_rights(R_ADMIN|R_MOD))
		return
	log_admin("[key_name(usr)] viewed the storage of [O] at ([O.x],[O.y],[O.z])")
	var/list/lines = list()
	var/count = storage_admin_list(O, lines, 0)
	var/html = "<h3>[html_encode("[O]")] ([O.x], [O.y], [O.z])</h3><p>[count] thing\s inside.</p>"
	if (lines.len)
		html += "<table border='1' cellpadding='3' style='border-collapse:collapse'><tr><th>Thing</th><th>Size</th><th>Searched by</th><th>Filled by faction</th></tr>[jointext(lines, "")]</table>"
	show_browse(src, html, "window=admin_view_storage;size=620x520")

// Adds a table row per thing inside A, depth first; returns how many it listed.
/proc/storage_admin_list(atom/A, list/lines, depth)
	if (depth > 5)
		return 0
	var/count = 0
	for (var/atom/movable/M in A.contents)
		var/obj/item/I = M
		if ((!istype(I) && !ismob(M)) || istype(M, /obj/item/organ))
			continue
		var/is_holder = istype(M, /obj/item/weapon/storage/internal)
		if (!is_holder)
			count++
			var/seen = istype(I) && I.storage_seen_by ? jointext(I.storage_seen_by, ", ") : "-"
			var/faction = istype(I) && I.storage_filled_by_faction ? I.storage_filled_by_faction : "-"
			var/size = istype(I) ? "[I.w_class]" : "mob"
			lines += "<tr><td style='padding-left:[4 + depth * 16]px'>[html_encode("[M]")]</td><td>[size]</td><td>[html_encode(seen)]</td><td>[html_encode(faction)]</td></tr>"
		if (length(M.contents))
			count += storage_admin_list(M, lines, is_holder ? depth : depth + 1)
	return count
