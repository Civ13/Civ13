// Trusted physical handlers only, not player edit/pen/language authorization.
// The public item label is metadata; language-tagged written titles stay intact.
/proc/paper_document_set_name(obj/item/weapon/paper/P, value, list/edit = null)
	if (!P || P.gc_destroyed || !istext(value) || !length(value))
		return FALSE
	if (isnull(P.document_record))
		if (!isnull(edit))
			return FALSE
		P.name = value
		paper_authoring_notify(P, "physical")
		return TRUE
	// Callers capture before a prompt; never silently rebase a stale label edit.
	if (!edit)
		return FALSE
	var/list/next = edit["record"]
	if (!paper_document_record_valid(next))
		return FALSE
	var/list/legacy = next["legacy"]
	legacy["name"] = value
	next["revision"]++
	return paper_document_commit_edit(P, edit)

// Damage once per invocation; later readers/copies never reroll that damage.
/proc/paper_document_crumple(obj/item/weapon/paper/P)
	if (!P || P.gc_destroyed)
		return FALSE
	if (isnull(P.document_record))
		P.info = stars(P.info, 85)
		paper_authoring_notify(P, "physical")
		return TRUE
	var/list/edit = paper_document_prepare_edit(P)
	if (!edit)
		return FALSE
	var/list/next = edit["record"]
	var/list/legacy = next["legacy"]
	legacy["info"] = stars(legacy["info"], 85)
	var/list/sections = next["sections"]
	for (var/list/section in sections)
		var/damaged = stars(section["text"], 85)
		if (damaged != section["text"])
			section["text"] = damaged
			// Changed text must not inherit future study reveals of its old version.
			section["version"]++
	next["revision"]++
	return paper_document_commit_edit(P, edit)
