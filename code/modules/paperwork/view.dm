// Read-only integration. No authoring action, language choice or model migration
// is exposed here. Every classic paper payload uses this server-owned boundary.
/proc/paper_document_route_access(obj/item/weapon/paper/P, mob/reader, route, atom/owner)
	if (!P || P.gc_destroyed || !reader)
		return FALSE
	if (route == "paper")
		// Existing direct examine admission, including its observer case.
		return in_range(reader, P) || isghost(reader)
	if (route == "editor")
		// Existing legacy editor admission. Pen/mutation checks remain in Topic.
		return !reader.stat && !reader.restrained() && (P.loc == reader || P.Adjacent(reader) || ((istype(P.loc, /obj/item/weapon/clipboard) || istype(P.loc, /obj/item/weapon/folder)) && (P.loc.loc == reader || P.loc.Adjacent(reader))))
	if (!owner || owner.gc_destroyed || P.loc != owner)
		return FALSE
	if (route == "clipboard")
		return istype(owner, /obj/item/weapon/clipboard) && owner.loc == reader && !reader.stat && !reader.restrained()
	if (route == "folder")
		return istype(owner, /obj/item/weapon/folder) && owner.loc == reader && !reader.stat && !reader.restrained()
	if (route == "noticeboard")
		return istype(owner, /obj/structure/noticeboard) && owner.Adjacent(reader)
	if (route == "bundle")
		var/obj/item/weapon/paper_bundle/B = owner
		if (!istype(B) || !islist(B.pages) || !isnum(B.page) || B.page != round(B.page) || B.page < 1 || B.page > B.pages.len || B.pages[B.page] != P)
			return FALSE
		if (istype(B.loc, /obj/item/weapon/folder))
			var/obj/item/weapon/folder/F = B.loc
			return !F.gc_destroyed && F.loc == reader
		return B.loc == reader || in_range(reader, B) || isghost(reader)
	return FALSE

// Legacy prompts bind the actual body, control session and pen. No classified
// field/EOF write may silently rebase new text as legacy_unclassified.
/proc/paper_document_legacy_edit_allowed(obj/item/weapon/paper/P, mob/actor, client/expected_client, obj/item/weapon/pen/pen)
	if (!P || P.gc_destroyed || !isnull(P.document_record) || !actor || !expected_client || actor.client != expected_client || expected_client.mob != actor || actor.stat || actor.restrained())
		return FALSE
	if (!istype(pen) || pen.gc_destroyed || pen.loc != actor || actor.get_active_hand() != pen)
		return FALSE
	if (P.loc == actor)
		return TRUE
	if (isturf(P.loc))
		return P.Adjacent(actor)
	var/obj/item/container = P.loc
	if (!container || container.gc_destroyed)
		return FALSE
	if (istype(container, /obj/item/weapon/clipboard) || istype(container, /obj/item/weapon/folder))
		return container.loc == actor || (isturf(container.loc) && container.Adjacent(actor))
	if (istype(container, /obj/item/weapon/storage/envelope))
		// Knifing sets opened even when the historical seal flag remains set.
		var/obj/item/weapon/storage/envelope/E = container
		return E.opened && (E.loc == actor || (isturf(E.loc) && E.Adjacent(actor)))
	if (istype(container, /obj/item/weapon/paper_bundle))
		var/obj/item/weapon/paper_bundle/B = container
		if (!islist(B.pages) || !isnum(B.page) || B.page != round(B.page) || B.page < 1 || B.page > B.pages.len || B.pages[B.page] != P)
			return FALSE
		if (istype(B.loc, /obj/item/weapon/folder))
			var/obj/item/weapon/folder/F = B.loc
			return !F.gc_destroyed && (F.loc == actor || (isturf(F.loc) && F.Adjacent(actor)))
		return B.loc == actor || (isturf(B.loc) && B.Adjacent(actor))
	return FALSE

/datum/paper_document_reader
	parent_type = /datum/paper_document_service
	var/read_route
	var/atom/read_owner

/datum/paper_document_reader/New(obj/item/weapon/paper/P, mob/reader, route, atom/owner)
	..(P, reader)
	read_route = route
	read_owner = owner

/datum/paper_document_reader/persistence_runtime_var(key)
	return (key in list("read_route", "read_owner")) || ..()

/datum/paper_document_reader/has_access(mob/reader, writing = FALSE)
	// This request context can never authorize a mutation through inherited APIs.
	if (writing || !paper || paper.gc_destroyed || !istype(reader) || reader != controller || !control_client || reader.client != control_client || control_client.mob != reader)
		return FALSE
	return paper_document_route_access(paper, reader, read_route, read_owner)

/datum/paper_document_reader/project(mob/reader, forceshow = FALSE)
	if (!has_access(reader))
		return null
	var/list/result
	if (isnull(paper.document_record))
		// Reading never initializes or persists an old document. Its bytes have
		// no invented language. Keep the original route's legacy comprehension.
		var/full_legacy = read_route == "noticeboard" || read_route == "editor" || istype(reader, /mob/living/human) || (isghost(reader) && !forceshow)
		var/legacy_body = full_legacy ? paper.info : stars(paper.info)
		result = list("legacy_name" = paper.name, "legacy_body_html" = "[legacy_body][paper.stamps]", "sections" = list())
	else
		// Exact foundation validation, stale-legacy rejection and per-section
		// language/literacy projection apply before any payload is constructed.
		result = ..()
	if (result && !result["error"])
		if (read_route == "noticeboard")
			// Boards historically show unclassified legacy ink in TT, no stamps.
			// This does not grant comprehension of any language-tagged section.
			result["legacy_body_html"] = paper.info
			result["legacy_monospace"] = TRUE
		if (read_route == "editor")
			// Existing write links are only an unclassified legacy cache. Never
			// use it as a fallback for classified/unsupported/stale records.
			result["legacy_body_html"] = isnull(paper.document_record) ? "[paper.info_links][paper.stamps]" : "[paper.info][paper.stamps]"
	return result

/proc/paper_document_view_body(list/data, obj/item/weapon/paper/P)
	if (!data || data["error"])
		return "<b>Unable to read this document.</b>"
	var/result = data["legacy_body_html"]
	if (data["legacy_monospace"])
		result = "<TT>" + result + "</TT>"
	var/list/sections = data["sections"]
	for (var/list/section in sections)
		if (!paper_document_ink(section["ink"]))
			return "<b>Unable to read this document.</b>"
		var/font = section["tool"] == "crayon" ? P.crayonfont : P.deffont
		var/text = html_encode(section["text"])
		if (section["kind"] == "signature")
			font = P.signfont
			text = "<i>" + text + "</i>"
		if (section["tool"] == "crayon")
			text = "<b>" + text + "</b>"
		text = replacetext(text, "\n", "<BR>")
		result += "<BR><font face=\"" + html_encode(font) + "\" color=\"" + html_encode(section["ink"]) + "\">" + text + "</font>"
	return result

/proc/paper_document_view_title(value)
	// sanitizeSafe already encodes renamed labels. Decode once, then escape for
	// the title context; preserve literal entities without allowing HTML breakout.
	return html_encode(html_decode(value))

/obj/item/weapon/paper/proc/document_classic_html(mob/reader, forceshow = FALSE, route = "paper", atom/owner = null)
	var/datum/paper_document_reader/request = new(src, reader, route, owner)
	var/list/data = request.project(reader, forceshow)
	if (!data)
		return null
	var/body = paper_document_view_body(data, src)
	return "<HTML><HEAD><TITLE>" + paper_document_view_title(name) + "</TITLE></HEAD><BODY style=\"background:#FFFFFF;color:#000000\">" + body + "</BODY></HTML>"

/obj/item/weapon/paper/proc/show_document(mob/reader, forceshow = FALSE, route = "paper", atom/owner = null)
	var/html = document_classic_html(reader, forceshow, route, owner)
	if (isnull(html))
		return FALSE
	reader << browse(html, "window=[name]")
	onclose(reader, "[name]")
	return TRUE
