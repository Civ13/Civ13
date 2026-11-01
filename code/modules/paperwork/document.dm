// Civ13 original implementation. No upstream code, dependency or asset copied.
// Typed authoring stays unwired; physical erasure shares its data transaction.
/obj/item/weapon/paper
	// Ordinary item persistence enumerates changed vars; this scalar/list record
	// is durable. Existing paper fields remain authoritative and unchanged.
	var/list/document_record = null

/datum/paper_document_budget
	should_save = FALSE
	var/valid = TRUE
	var/nodes_left = 1024
	var/units_left = 131072

// Whole records also contain up to 128 section maps. Keep the legacy snapshot
// limit unchanged while allowing that documented section capacity to fit.
/datum/paper_document_budget/record
	nodes_left = 4096

// Bounded deep copy preserves null, paths and list associations. Refuse runtime
// objects/cycles/oversized input without changing the original legacy paper.
/proc/paper_document_copy(value, datum/paper_document_budget/budget, depth = 0)
	if (!budget || depth > 16 || budget.nodes_left <= 0)
		if (budget)
			budget.valid = FALSE
		return null
	budget.nodes_left--
	if (isnull(value) || isnum(value) || ispath(value))
		return value
	if (istext(value))
		budget.units_left -= length(value)
		if (budget.units_left < 0)
			budget.valid = FALSE
			return null
		return value
	if (!islist(value))
		budget.valid = FALSE
		return null
	var/list/source = value
	var/list/result = list()
	for (var/index = 1, index <= source.len, index++)
		var/key = source[index]
		var/copied_key = paper_document_copy(key, budget, depth + 1)
		if (!budget.valid)
			return null
		result += list(copied_key)
		if (!isnum(key) && !isnull(key))
			result[copied_key] = paper_document_copy(source[key], budget, depth + 1)
			if (!budget.valid)
				return null
	return result

/proc/paper_document_legacy_snapshot(obj/item/weapon/paper/P)
	if (!P)
		return null
	// info_links contains runtime src hrefs, not authored content. Leave that
	// original legacy field untouched; new views must never use it as authority.
	var/list/snapshot = list("name" = P.name, "info" = P.info, "stamps" = P.stamps, "fields" = P.fields, "free_space" = P.free_space, "stamped" = P.stamped, "ico" = P.ico, "offset_x" = P.offset_x, "offset_y" = P.offset_y)
	var/datum/paper_document_budget/budget = new()
	var/list/copy = paper_document_copy(snapshot, budget)
	return budget.valid ? copy : null

/proc/paper_document_keys(list/value, list/keys)
	if (!islist(value) || value.len != keys.len)
		return FALSE
	for (var/key in keys)
		if (!(key in value))
			return FALSE
	return TRUE

/proc/paper_document_ink(value)
	if (!istext(value))
		return FALSE
	value = lowertext(value)
	if (value in list("black", "blue", "red", "white", "yellow", "lime", "pink", "orange", "cyan", "grey", "gray", "green", "purple", "brown"))
		return TRUE
	if (length(value) != 7 || copytext(value, 1, 2) != "#")
		return FALSE
	for (var/index = 2, index <= 7, index++)
		var/code = text2ascii(value, index)
		if (!((code >= 48 && code <= 57) || (code >= 97 && code <= 102)))
			return FALSE
	return TRUE

/proc/paper_document_section_valid(list/section)
	if (!paper_document_keys(section, list("id", "lineage", "version", "kind", "language_id", "text", "ink", "tool")))
		return FALSE
	if (!istext(section["id"]) || !length(section["id"]) || length(section["id"]) > 64 || !istext(section["lineage"]) || length(section["lineage"]) != 32)
		return FALSE
	if (!isnum(section["version"]) || section["version"] < 1 || section["version"] > 1048575 || section["version"] != round(section["version"]))
		return FALSE
	if (!(section["kind"] in list("body", "title", "field_label", "field_answer", "signature")) || !paper_written_language(section["language_id"]))
		return FALSE
	if (!istext(section["text"]) || length(section["text"]) > MAX_PAPER_MESSAGE_LEN || !paper_document_ink(section["ink"]) || !(section["tool"] in list("pen", "crayon")))
		return FALSE
	return TRUE

/proc/paper_document_record_valid(list/record)
	if (!paper_document_keys(record, list("schema_version", "revision", "document_id", "legacy_policy", "legacy", "sections", "next_section")))
		return FALSE
	if (record["schema_version"] != 1 || !isnum(record["revision"]) || record["revision"] < 1 || record["revision"] > 1048575 || record["revision"] != round(record["revision"]) || record["legacy_policy"] != "legacy_unclassified")
		return FALSE
	if (!istext(record["document_id"]) || length(record["document_id"]) != 32 || !isnum(record["next_section"]) || record["next_section"] < 1 || record["next_section"] > 1048575 || record["next_section"] != round(record["next_section"]))
		return FALSE
	if (!paper_document_keys(record["legacy"], list("name", "info", "stamps", "fields", "free_space", "stamped", "ico", "offset_x", "offset_y")))
		return FALSE
	var/list/sections = record["sections"]
	if (!islist(sections) || sections.len > 128)
		return FALSE
	var/datum/paper_document_budget/budget = new /datum/paper_document_budget/record()
	paper_document_copy(record, budget)
	if (!budget.valid)
		return FALSE
	var/list/ids = list()
	var/units = 0
	for (var/index = 1, index <= sections.len, index++)
		var/list/section = sections[index]
		if (!paper_document_section_valid(section) || (section["id"] in ids))
			return FALSE
		ids += section["id"]
		units += length(section["text"])
		if (units > MAX_PAPER_MESSAGE_LEN)
			return FALSE
	return TRUE

var/global/paper_document_sequence = 0
/proc/paper_document_mint_id(obj/item/weapon/paper/P)
	paper_document_sequence++
	// Identity only, never author authenticity or invented historical provenance.
	return md5("\ref[P]:[world.realtime]:[paper_document_sequence]")

// Internal transaction data only, never a UI/copy payload or persisted field.
// Callers retain their own actor/tool or trusted physical-event admission.
/proc/paper_document_prepare_edit(obj/item/weapon/paper/P)
	if (!P || P.gc_destroyed || !paper_document_record_valid(P.document_record))
		return null
	var/list/current = P.document_record
	var/list/legacy = paper_document_legacy_snapshot(P)
	if (!legacy || json_encode(legacy) != json_encode(current["legacy"]))
		return null
	var/datum/paper_document_budget/budget = new /datum/paper_document_budget/record()
	var/list/next = paper_document_copy(current, budget)
	if (!budget.valid)
		return null
	return list("original" = current, "revision" = current["revision"], "document_id" = current["document_id"], "legacy_json" = json_encode(legacy), "canonical_json" = json_encode(current), "record" = next)

/proc/paper_document_commit_edit(obj/item/weapon/paper/P, list/edit)
	if (!P || P.gc_destroyed || !paper_document_keys(edit, list("original", "revision", "document_id", "legacy_json", "canonical_json", "record")))
		return FALSE
	var/list/current = edit["original"]
	var/list/next = edit["record"]
	if (P.document_record != current || !paper_document_record_valid(current) || !paper_document_record_valid(next))
		return FALSE
	if (current["revision"] != edit["revision"] || current["document_id"] != edit["document_id"] || json_encode(current) != edit["canonical_json"])
		return FALSE
	if (next["revision"] != edit["revision"] + 1 || next["document_id"] != edit["document_id"] || next["next_section"] < current["next_section"])
		return FALSE
	var/list/legacy = paper_document_legacy_snapshot(P)
	if (!legacy || json_encode(legacy) != edit["legacy_json"])
		return FALSE
	// Canonical state must not alias the caller's candidate or physical lists.
	var/datum/paper_document_budget/budget = new /datum/paper_document_budget/record()
	var/list/committed = paper_document_copy(next, budget)
	if (!budget.valid)
		return FALSE
	budget = new()
	var/list/physical = paper_document_copy(committed["legacy"], budget)
	if (!budget.valid)
		return FALSE
	// No yield, callback, prompt, projection or effect between guard and commit.
	P.name = physical["name"]
	P.info = physical["info"]
	P.stamps = physical["stamps"]
	P.fields = physical["fields"]
	P.free_space = physical["free_space"]
	P.stamped = physical["stamped"]
	P.ico = physical["ico"]
	P.offset_x = physical["offset_x"]
	P.offset_y = physical["offset_y"]
	P.document_record = committed
	return TRUE

/datum/paper_document_service
	should_save = FALSE
	var/obj/item/weapon/paper/paper
	var/mob/controller
	var/client/control_client

/datum/paper_document_service/New(obj/item/weapon/paper/P, mob/new_controller)
	..()
	paper = P
	controller = new_controller
	control_client = new_controller ? new_controller.client : null

/datum/paper_document_service/persistence_runtime_var(key)
	return (key in list("paper", "controller", "control_client")) || ..()

// No client-provided physical parent or pen claims. Other containers are denied
// until their actual page/seal access adapters are reviewed in the next slice.
/datum/paper_document_service/proc/has_access(mob/actor, writing = FALSE)
	if (!paper || paper.gc_destroyed || !istype(actor) || actor != controller || !control_client || actor.client != control_client || control_client.mob != actor)
		return FALSE
	if (writing && (actor.stat || actor.restrained()))
		return FALSE
	if (paper.loc == actor)
		return TRUE
	if (isturf(paper.loc))
		return paper.Adjacent(actor)
	var/obj/item/container = paper.loc
	if (istype(container, /obj/item/weapon/clipboard) || istype(container, /obj/item/weapon/folder))
		return !container.gc_destroyed && container.loc == actor
	return FALSE

/datum/paper_document_service/proc/can_mutate(mob/actor, obj/item/weapon/pen/pen)
	return has_access(actor, TRUE) && istype(pen) && !pen.gc_destroyed && actor.get_active_hand() == pen && pen.loc == actor

/datum/paper_document_service/proc/initialize(mob/actor, obj/item/weapon/pen/pen)
	if (!can_mutate(actor, pen) || !isnull(paper.document_record))
		return FALSE
	var/list/legacy = paper_document_legacy_snapshot(paper)
	if (!legacy)
		return FALSE
	var/list/record = list("schema_version" = 1, "revision" = 1, "document_id" = paper_document_mint_id(paper), "legacy_policy" = "legacy_unclassified", "legacy" = legacy, "sections" = list(), "next_section" = 1)
	if (!paper_document_record_valid(record))
		return FALSE
	paper.document_record = record
	return TRUE

// Plain-text foundation operation only, not a new pencode/Markdown dialect.
// Legacy editing and forms are not routed here until every view uses project().
/datum/paper_document_service/proc/append(mob/actor, obj/item/weapon/pen/pen, document_id, revision, language_id, kind, value)
	if (!can_mutate(actor, pen) || !paper_knows_written_language(actor, language_id))
		return FALSE
	var/list/current = paper.document_record
	if (!paper_document_record_valid(current) || current["document_id"] != document_id || current["revision"] != revision)
		return FALSE
	var/list/legacy = paper_document_legacy_snapshot(paper)
	if (!legacy || json_encode(legacy) != json_encode(current["legacy"]))
		return FALSE
	if (!(kind in list("body", "title", "signature")))
		return FALSE
	if (kind == "signature")
		value = pen.get_signature(actor)
	if (!istext(value) || !length(value) || !isnum(paper.free_space) || length(value) > paper.free_space)
		return FALSE
	var/list/edit = paper_document_prepare_edit(paper)
	if (!edit)
		return FALSE
	var/list/next = edit["record"]
	var/list/sections = next["sections"]
	var/list/section = list("id" = "section-[next["next_section"]]", "lineage" = paper_document_mint_id(paper), "version" = 1, "kind" = kind, "language_id" = language_id, "text" = value, "ink" = pen.colour, "tool" = istype(pen, /obj/item/weapon/pen/crayon) ? "crayon" : "pen")
	sections += list(section)
	next["next_section"]++
	next["revision"]++
	var/list/next_legacy = next["legacy"]
	next_legacy["free_space"] -= length(value)
	if (!paper_document_record_valid(next) || !can_mutate(actor, pen) || !paper_knows_written_language(actor, language_id) || paper.document_record != current || current["revision"] != revision || current["document_id"] != document_id)
		return FALSE
	if (json_encode(paper_document_legacy_snapshot(paper)) != json_encode(legacy))
		return FALSE
	return paper_document_commit_edit(paper, edit)

// Sole future UI data boundary. Never send the canonical record or copy payload.
// Every text-bearing kind, including title/labels/answers/signature, is projected
// identically. No hidden original, partial-language roll, XP or ghost/admin bypass.
/datum/paper_document_service/proc/project(mob/reader, forceshow = FALSE)
	if (!has_access(reader))
		return null
	var/list/current = paper.document_record
	if (!paper_document_record_valid(current))
		return list("error" = "Unsupported document format")
	var/list/legacy = paper_document_legacy_snapshot(paper)
	if (!legacy || json_encode(legacy) != json_encode(current["legacy"]))
		return list("error" = "Legacy document changed")
	var/full_legacy = istype(reader, /mob/living/human) || (isghost(reader) && !forceshow)
	var/legacy_body = full_legacy ? paper.info : stars(paper.info)
	var/list/visible = list()
	var/list/sections = current["sections"]
	for (var/list/section in sections)
		var/understood = full_legacy && paper_knows_written_language(reader, section["language_id"])
		visible += list(list("id" = section["id"], "kind" = section["kind"], "language_id" = section["language_id"], "text" = understood ? section["text"] : "\[Unintelligible writing\]", "ink" = section["ink"], "tool" = section["tool"]))
	return list("revision" = current["revision"], "legacy_policy" = "legacy_unclassified", "legacy_name" = paper.name, "legacy_body_html" = "[legacy_body][paper.stamps]", "sections" = visible)

// Internal canonical copy only; future item-copy code must give the physical
// document a new document_id while preserving faithful section lineage/version.
// This never copies character study progress and must never be sent to a UI.
/datum/paper_document_service/proc/canonical_copy(mob/actor)
	if (!has_access(actor) || !paper_document_record_valid(paper.document_record))
		return null
	var/list/legacy = paper_document_legacy_snapshot(paper)
	if (!legacy || json_encode(legacy) != json_encode(paper.document_record["legacy"]))
		return null
	var/datum/paper_document_budget/budget = new /datum/paper_document_budget/record()
	var/list/result = paper_document_copy(paper.document_record, budget)
	return budget.valid ? result : null
