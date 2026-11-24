// Hands-on curriculum for the dedicated Tutorial region. Fixtures share the
// workshop slot's existing bounds and teardown, never the live fallback.
/datum/practice_session/proc/setup_practice_paper(turf/supply, turf/worksite)
	if (props["practice_press"] || !owns_workshop(supply) || !owns_workshop(worksite) || !tutorial_workshop_access(body, worksite))
		return "This workshop is not available right now."
	var/obj/structure/printingpress/press = new(worksite)
	press.should_save = FALSE
	press.not_movable = TRUE
	props["practice_press"] = press
	new /obj/item/weapon/pen(supply)
	for (var/sheet in 1 to 8)
		new /obj/item/weapon/paper(supply)
	return "Use the quill on a blank sheet to write a short notice. Hold it in your active hand and click the press, then choose Original. Load a second sheet as Copy. With an empty hand, click the press and stay beside it until both papers come out. There are eight sheets to practise with. Leave and reopen a room to start over."

// Called after the normal press publishes its result. Do not count inspecting
// the press, copying blank stock, a canceled wait, or a different room's press.
/proc/tutorial_note_paper_copy(mob/actor, obj/structure/printingpress/press, obj/item/weapon/paper/original, obj/item/weapon/paper/result)
	var/mob/living/human/practice/H = actor
	if (!istype(H) || !H.practice || H.practice.props["practice_press"] != press || H.practice.props["practice_paper_done"])
		return
	if (!tutorial_workshop_access(H, press) || !H.practice.owns_workshop(original) || !H.practice.owns_workshop(result))
		return
	if (original == result || !tutorial_paper_has_writing(original))
		return
	H.practice.props["practice_paper_done"] = TRUE
	to_chat(H, SPAN_NOTICE("Practice complete: you wrote and printed a document. The original and copy are both beside the press. You can print again while your blank sheets last."))

// Both the simple paper editor and classified authoring write ordinary paper.
// Its physical text may be blank when the canonical sections own the writing.
/proc/tutorial_paper_has_writing(obj/item/weapon/paper/P)
	if (length(P.info))
		return TRUE
	if (!islist(P.document_record))
		return FALSE
	var/list/sections = P.document_record["sections"]
	if (!islist(sections))
		return FALSE
	for (var/list/section in sections)
		if (section["kind"] == "body" && length(section["text"]))
			return TRUE
	return FALSE
