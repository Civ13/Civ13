// Runtime constructor readiness is never durable document data.
/obj/item/weapon/paper
	var/document_capacity_ready = FALSE

/obj/item/weapon/paper/persistence_runtime_var(key)
	return key == "document_capacity_ready" || ..()

// Disabled internal editor contract. No player route constructs this service.
// A lease complements actual actor/client/pen/custody checks; it is not authority.
/datum/paper_document_authoring
	parent_type = /datum/paper_document_service
	var/obj/item/weapon/pen/writing_pen
	var/datum/paper_document_reader/projection_reader
	var/session_lease
	var/session_closed = TRUE
	var/list/expected_record
	var/expected_record_json
	var/expected_legacy_json
	var/atom/context_owner
	var/atom/context_parent

/datum/paper_document_authoring/New(obj/item/weapon/paper/P, mob/new_controller, obj/item/weapon/pen/pen)
	..(P, new_controller)
	writing_pen = pen
	projection_reader = new(P, new_controller, "editor", null)

/datum/paper_document_authoring/persistence_runtime_var(key)
	return (key in list("writing_pen", "projection_reader", "session_lease", "session_closed", "expected_record", "expected_record_json", "expected_legacy_json", "context_owner", "context_parent")) || ..()

/datum/paper_document_authoring/proc/capture_state()
	if (!paper || paper.gc_destroyed || !paper.document_capacity_ready || paper.type != /obj/item/weapon/paper)
		return FALSE
	var/list/legacy = paper_document_legacy_snapshot(paper)
	if (!legacy || !paper.document_copy_legacy_valid(legacy))
		return FALSE
	var/list/current = paper.document_record
	if (!isnull(current) && (!paper_document_record_valid(current) || json_encode(current["legacy"]) != json_encode(legacy)))
		return FALSE
	expected_record = current
	expected_record_json = json_encode(current)
	expected_legacy_json = json_encode(legacy)
	context_owner = paper.loc
	context_parent = null
	if (istype(context_owner, /obj/item/weapon/clipboard) || istype(context_owner, /obj/item/weapon/folder))
		context_parent = context_owner.loc
	return TRUE

/datum/paper_document_authoring/proc/state_current()
	if (session_closed || !paper || paper.gc_destroyed || !paper.document_capacity_ready || paper.type != /obj/item/weapon/paper || paper.document_record != expected_record)
		return FALSE
	if (!isnull(expected_record) && !paper_document_record_valid(expected_record))
		return FALSE
	return json_encode(paper.document_record) == expected_record_json && json_encode(paper_document_legacy_snapshot(paper)) == expected_legacy_json

/datum/paper_document_authoring/has_access(mob/actor, writing = FALSE)
	if (session_closed || !paper || paper.loc != context_owner)
		return FALSE
	if ((istype(context_owner, /obj/item/weapon/clipboard) || istype(context_owner, /obj/item/weapon/folder)) && context_owner.loc != context_parent)
		return FALSE
	return ..(actor, writing)

/datum/paper_document_authoring/can_mutate(mob/actor, obj/item/weapon/pen/pen)
	return pen == writing_pen && state_current() && ..(actor, pen)

/datum/paper_document_authoring/proc/begin(mob/actor)
	if (!session_closed || !isnull(session_lease) || !capture_state())
		return FALSE
	session_closed = FALSE
	if (!can_mutate(actor, writing_pen) || !length(paper_written_language_choices(actor)))
		retire()
		return FALSE
	session_lease = paper_document_mint_id(paper)
	return TRUE

// Closing a stale view needs no continuing custody, but cannot close another
// controller's session. Server lifecycle cleanup uses retire() directly.
/datum/paper_document_authoring/proc/cancel(mob/actor, lease)
	if (session_closed || !lease || lease != session_lease || actor != controller || !control_client || actor.client != control_client || control_client.mob != actor)
		return FALSE
	retire()
	return TRUE

/datum/paper_document_authoring/proc/retire()
	session_closed = TRUE
	session_lease = null
	expected_record = null
	expected_record_json = null
	expected_legacy_json = null
	context_owner = null
	context_parent = null
	projection_reader = null
	writing_pen = null
	paper = null
	controller = null
	control_client = null

/datum/paper_document_authoring/Destroy()
	retire()
	return ..()

// Never expose eager legacy classification or canonical copies through an editor.
/datum/paper_document_authoring/initialize(mob/actor, obj/item/weapon/pen/pen)
	return FALSE

/datum/paper_document_authoring/canonical_copy(mob/actor)
	return null

/datum/paper_document_authoring/proc/snapshot(mob/actor)
	if (!can_mutate(actor, writing_pen))
		return null
	var/list/view = projection_reader.project(actor)
	var/list/languages = paper_written_language_choices(actor)
	var/default_language_id = paper_written_default_language(actor)
	if (!view || view["error"] || !length(languages) || !can_mutate(actor, writing_pen))
		return null
	var/document_id = isnull(expected_record) ? null : expected_record["document_id"]
	var/revision = isnull(expected_record) ? 0 : expected_record["revision"]
	return list("lease" = session_lease, "document_id" = document_id, "revision" = revision, "free_space" = max(0, paper.free_space), "languages" = languages, "default_language_id" = default_language_id, "view" = view)

/datum/paper_document_authoring/append(mob/actor, obj/item/weapon/pen/pen, document_id, revision, language_id, kind, value, expected_lease = null)
	if (!expected_lease || expected_lease != session_lease || !isnum(revision) || revision != round(revision) || !can_mutate(actor, pen) || !paper_knows_written_language(actor, language_id))
		return FALSE
	if (!(kind in list("body", "title", "signature")))
		return FALSE
	if (isnull(expected_record))
		if (!isnull(document_id) || revision != 0)
			return FALSE
	else
		if (expected_record["document_id"] != document_id || expected_record["revision"] != revision)
			return FALSE
	if (kind == "signature")
		value = pen.get_signature(actor)
	// Recheck after the actual pen getter, before any paper dereference.
	if (!can_mutate(actor, pen) || !paper_knows_written_language(actor, language_id) || !istext(value) || !length(value) || length(value) > paper.free_space)
		return FALSE
	var/list/edit = null
	var/list/next = null
	if (isnull(expected_record))
		var/list/legacy = paper_document_legacy_snapshot(paper)
		if (!legacy || !paper.document_copy_legacy_valid(legacy))
			return FALSE
		next = list("schema_version" = 1, "revision" = 1, "document_id" = paper_document_mint_id(paper), "legacy_policy" = "legacy_unclassified", "legacy" = legacy, "sections" = list(), "next_section" = 1)
	else
		edit = paper_document_prepare_edit(paper)
		if (!edit)
			return FALSE
		next = edit["record"]
		next["revision"]++
	var/list/sections = next["sections"]
	var/list/section = list("id" = "section-[next["next_section"]]", "lineage" = paper_document_mint_id(paper), "version" = 1, "kind" = kind, "language_id" = language_id, "text" = value, "ink" = pen.colour, "tool" = istype(pen, /obj/item/weapon/pen/crayon) ? "crayon" : "pen")
	sections += list(section)
	next["next_section"]++
	var/list/next_legacy = next["legacy"]
	next_legacy["free_space"] -= length(value)
	if (!paper_document_record_valid(next) || !can_mutate(actor, pen) || !paper_knows_written_language(actor, language_id) || expected_lease != session_lease)
		return FALSE
	if (isnull(expected_record))
		// No yield or callback after the final state/authority checks. The first
		// accepted text and legacy classification are one mutation, never open().
		paper.free_space = next_legacy["free_space"]
		paper.document_record = next
	else
		if (!paper_document_commit_edit(paper, edit))
			return FALSE
	// A committed write remains success even if future capture cannot continue.
	if (!capture_state())
		retire()
		return TRUE
	session_lease = paper_document_mint_id(paper)
	return TRUE

// Future UI data is available only through the guarded snapshot boundary.
/datum/paper_document_authoring/project(mob/reader, forceshow = FALSE)
	return null
