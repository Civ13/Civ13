// Internal mechanical-copy data, never a viewer projection or UI payload.
// Machine adapters must separately validate their actor/session and real custody.
/proc/paper_document_copy_metadata_valid(list/data)
	if (!paper_document_keys(data, list("desc", "rigged", "spam_flag", "source_type")))
		return FALSE
	if ((!isnull(data["desc"]) && !istext(data["desc"])) || (istext(data["desc"]) && length(data["desc"]) > MAX_PAPER_MESSAGE_LEN))
		return FALSE
	if (!isnum(data["rigged"]) || !(data["rigged"] in list(FALSE, TRUE)) || !isnum(data["spam_flag"]) || !(data["spam_flag"] in list(FALSE, TRUE)) || !ispath(data["source_type"]))
		return FALSE
	return TRUE

/proc/paper_document_copy_metadata(obj/item/weapon/paper/P)
	if (!istype(P) || P.gc_destroyed)
		return null
	var/list/data = list("desc" = P.desc, "rigged" = P.rigged, "spam_flag" = P.spam_flag, "source_type" = P.type)
	return paper_document_copy_metadata_valid(data) ? data : null

/proc/paper_document_copy_snapshot(obj/item/weapon/paper/P)
	if (!istype(P) || P.gc_destroyed)
		return null
	var/list/legacy = paper_document_legacy_snapshot(P)
	var/list/metadata = paper_document_copy_metadata(P)
	if (!legacy || !metadata || !P.document_copy_legacy_valid(legacy))
		return null
	var/list/current = P.document_record
	var/list/record = null
	if (!isnull(current))
		// Subtype constructors/authority need their own reviewed adapter. Refuse
		// classified subtypes whole; never downgrade them to unclassified HTML.
		if (P.type != /obj/item/weapon/paper || !paper_document_record_valid(current) || json_encode(current["legacy"]) != json_encode(legacy))
			return null
		var/datum/paper_document_budget/budget = new /datum/paper_document_budget/record()
		record = paper_document_copy(current, budget)
		if (!budget.valid)
			return null
	return list("paper" = P, "paper_loc" = P.loc, "record_reference" = current, "record_json" = json_encode(current), "record" = record, "legacy" = legacy, "legacy_json" = json_encode(legacy), "metadata" = metadata, "metadata_json" = json_encode(metadata))

/proc/paper_document_copy_current(list/snapshot)
	if (!paper_document_keys(snapshot, list("paper", "paper_loc", "record_reference", "record_json", "record", "legacy", "legacy_json", "metadata", "metadata_json")))
		return FALSE
	var/obj/item/weapon/paper/P = snapshot["paper"]
	if (!istype(P) || P.gc_destroyed || P.loc != snapshot["paper_loc"])
		return FALSE
	var/list/current = snapshot["record_reference"]
	if (P.document_record != current)
		return FALSE
	if (!isnull(current) && (P.type != /obj/item/weapon/paper || !paper_document_record_valid(current)))
		return FALSE
	var/list/record = snapshot["record"]
	if (!isnull(record) && !paper_document_record_valid(record))
		return FALSE
	if (json_encode(current) != snapshot["record_json"] || json_encode(record) != snapshot["record_json"])
		return FALSE
	var/datum/paper_document_budget/budget = new()
	paper_document_copy(snapshot["legacy"], budget)
	if (!budget.valid || !P.document_copy_legacy_valid(snapshot["legacy"]) || !paper_document_copy_metadata_valid(snapshot["metadata"]))
		return FALSE
	if (json_encode(snapshot["legacy"]) != snapshot["legacy_json"] || json_encode(snapshot["metadata"]) != snapshot["metadata_json"])
		return FALSE
	var/list/legacy = paper_document_legacy_snapshot(P)
	var/list/metadata = paper_document_copy_metadata(P)
	return legacy && metadata && json_encode(legacy) == snapshot["legacy_json"] && json_encode(metadata) == snapshot["metadata_json"]

// Produces an unpublished generic facsimile at null. Preserve the existing
// press/mail output type for legacy subtypes; do not invent government authority.
// Caller owns cleanup until its final machine/session/source checks commit.
/proc/paper_document_create_copy(list/snapshot)
	if (!paper_document_copy_current(snapshot))
		return null
	var/datum/paper_document_budget/budget = new()
	var/list/physical = paper_document_copy(snapshot["legacy"], budget)
	if (!budget.valid)
		return null
	var/list/record = null
	if (!isnull(snapshot["record"]))
		budget = new /datum/paper_document_budget/record()
		record = paper_document_copy(snapshot["record"], budget)
		if (!budget.valid)
			return null
	var/list/metadata = snapshot["metadata"]
	// TRUE is constructor-local only: skip a second delayed capacity debit.
	var/obj/item/weapon/paper/result = new /obj/item/weapon/paper(null, TRUE)
	if (!result || result.gc_destroyed)
		return null
	if (!paper_document_copy_current(snapshot))
		qdel(result)
		return null
	result.name = physical["name"]
	result.desc = metadata["desc"]
	result.info = physical["info"]
	result.stamps = physical["stamps"]
	result.fields = physical["fields"]
	result.free_space = physical["free_space"]
	result.stamped = physical["stamped"]
	result.ico = physical["ico"]
	result.offset_x = physical["offset_x"]
	result.offset_y = physical["offset_y"]
	result.rigged = metadata["rigged"]
	result.spam_flag = metadata["spam_flag"]
	if (!isnull(record))
		record["document_id"] = paper_document_mint_id(result)
	result.document_record = record
	// Rebuild src hrefs for this object; source info_links is never copied.
	result.updateinfolinks()
	result.update_icon()
	return result

/proc/paper_document_copy_actor_valid(mob/actor, client/expected_client, atom/machine)
	return istype(actor) && expected_client && actor.client == expected_client && expected_client.mob == actor && !actor.stat && !actor.restrained() && machine && !machine.gc_destroyed && machine.Adjacent(actor)

/obj/structure/printingpress/proc/insert_copy_paper(obj/item/weapon/paper/P, mob/actor)
	var/client/expected_client = actor ? actor.client : null
	if (src.copying || !istype(actor, /mob/living) || !paper_document_copy_actor_valid(actor, expected_client, src) || !P || P.loc != actor || actor.get_active_hand() != P || !islist(src.base) || !islist(src.copy))
		return FALSE
	var/list/snapshot = paper_document_copy_snapshot(P)
	if (!snapshot)
		return FALSE
	var/list/choices = list("Cancel")
	if (!src.base.len)
		choices += "Original"
	if (!src.copy.len)
		choices += "Copy"
	if (choices.len == 1)
		return FALSE
	var/choice = WWinput(actor, "Add to original or copy?", "Printing Press", "Cancel", choices)
	if (!(choice in list("Original", "Copy")) || !src || src.gc_destroyed || src.copying || !paper_document_copy_actor_valid(actor, expected_client, src) || !paper_document_copy_current(snapshot) || P.loc != actor || actor.get_active_hand() != P || !islist(src.base) || !islist(src.copy))
		return FALSE
	if ((choice == "Original" && src.base.len) || (choice == "Copy" && src.copy.len))
		return FALSE
	// Reserve ownership before inventory callbacks so Destroy can rescue the
	// in-flight input. Busy blocks another press operation until transfer ends.
	if (choice == "Original")
		src.base += P
	else
		src.copy += P
	src.copying = TRUE
	// Reuse the held-item transfer without staging the document on the floor.
	var/mob/living/holder = actor
	var/transferred = holder.transfer_held_item_to(P, src)
	if (!src || src.gc_destroyed)
		return FALSE
	snapshot["paper_loc"] = src
	if (!transferred || !P || P.gc_destroyed || !paper_document_copy_actor_valid(actor, expected_client, src) || P.loc != src || !paper_document_copy_current(snapshot) || !islist(src.base) || !islist(src.copy) || (choice == "Original" && (src.base.len != 1 || src.base[1] != P)) || (choice == "Copy" && (src.copy.len != 1 || src.copy[1] != P)))
		if (islist(src.base))
			src.base -= P
		if (islist(src.copy))
			src.copy -= P
		src.copying = FALSE
		if (P && !P.gc_destroyed && P.loc == src)
			P.loc = get_turf(src)
		return FALSE
	src.copying = FALSE
	return TRUE

/obj/structure/printingpress/Destroy()
	src.copying = FALSE
	var/turf/place = get_turf(src)
	// Rescue only papers actually retained by this press, including old saves
	// whose input lists refer to papers hidden at null. Book behavior is unchanged.
	var/list/papers = list()
	for (var/obj/item/weapon/paper/original in src.base)
		papers |= original
	for (var/obj/item/weapon/paper/stock in src.copy)
		papers |= stock
	for (var/obj/item/weapon/paper/P in papers)
		if (islist(src.base))
			src.base -= P
		if (islist(src.copy))
			src.copy -= P
		if (P && !P.gc_destroyed && (P.loc == src || isnull(P.loc)))
			P.loc = place
	return ..()

/obj/structure/printingpress/proc/copy_paper_document(mob/actor)
	var/client/expected_client = actor ? actor.client : null
	if (src.copying || !paper_document_copy_actor_valid(actor, expected_client, src) || !islist(src.base) || !islist(src.copy) || src.base.len != 1 || src.copy.len != 1)
		return FALSE
	var/obj/item/weapon/paper/original = src.base[1]
	var/obj/item/weapon/paper/stock = src.copy[1]
	if (!istype(original) || !istype(stock) || original == stock || original.type != stock.type || (!isnull(original.loc) && original.loc != src) || (!isnull(stock.loc) && stock.loc != src))
		return FALSE
	var/list/source_snapshot = paper_document_copy_snapshot(original)
	var/list/stock_snapshot = paper_document_copy_snapshot(stock)
	if (!source_snapshot || !stock_snapshot)
		return FALSE
	src.copying = TRUE
	src.icon_state = "printingpress1"
	src.visible_message("The printing press starts copying the paper.")
	var/completed = do_after(actor, 90, src)
	if (!src || src.gc_destroyed)
		return FALSE
	if (!completed || !paper_document_copy_actor_valid(actor, expected_client, src) || !islist(src.base) || !islist(src.copy) || src.base.len != 1 || src.copy.len != 1 || src.base[1] != original || src.copy[1] != stock || !paper_document_copy_current(source_snapshot) || !paper_document_copy_current(stock_snapshot))
		src.copying = FALSE
		src.icon_state = "printingpress0"
		return FALSE
	var/obj/item/weapon/paper/result = paper_document_create_copy(source_snapshot)
	if (!src || src.gc_destroyed)
		if (result && !result.gc_destroyed)
			qdel(result)
		return FALSE
	if (!result)
		src.copying = FALSE
		src.icon_state = "printingpress0"
		return FALSE
	// Construction is not an authorization grant. Recheck before publishing or
	// consuming anything; output remains private at null until this boundary.
	if (!paper_document_copy_actor_valid(actor, expected_client, src) || !islist(src.base) || !islist(src.copy) || src.base.len != 1 || src.copy.len != 1 || src.base[1] != original || src.copy[1] != stock || !paper_document_copy_current(source_snapshot) || !paper_document_copy_current(stock_snapshot))
		qdel(result)
		src.copying = FALSE
		src.icon_state = "printingpress0"
		return FALSE
	var/turf/place = get_turf(src)
	if (!isturf(place))
		qdel(result)
		src.copying = FALSE
		src.icon_state = "printingpress0"
		return FALSE
	src.base -= original
	src.copy -= stock
	src.copying = FALSE
	src.icon_state = "printingpress0"
	original.loc = place
	result.loc = place
	qdel(stock)
	if (src && !src.gc_destroyed)
		src.visible_message("The printing press finishes copying.")
	return TRUE

// Mail retains the existing faction fanout and generic facsimile output type.
// Prepare every output first; a failed receiver/source check retains the letter.
/obj/structure/mailbox/proc/copy_paper_delivery(obj/item/weapon/paper/original, mob/actor)
	var/client/expected_client = actor ? actor.client : null
	if (src.receive_only || !paper_document_copy_actor_valid(actor, expected_client, src) || !original || original.loc != actor)
		return FALSE
	var/list/snapshot = paper_document_copy_snapshot(original)
	if (!snapshot)
		return FALSE
	var/faction = src.faction
	var/list/receivers = list()
	var/list/places = list()
	var/list/outputs = list()
	for (var/obj/structure/mailbox/received/receiver in world)
		if (!receiver.gc_destroyed && receiver.faction == faction && isturf(receiver.loc))
			receivers += list(receiver)
			places += list(receiver.loc)
	if (!receivers.len)
		return FALSE
	var/valid = TRUE
	for (var/create_index = 1, create_index <= receivers.len, create_index++)
		var/obj/item/weapon/paper/result = paper_document_create_copy(snapshot)
		if (!result)
			valid = FALSE
			break
		outputs += list(result)
	if (!valid || !src || src.gc_destroyed || src.receive_only || src.faction != faction || !paper_document_copy_actor_valid(actor, expected_client, src) || !original || original.gc_destroyed || original.loc != actor || !paper_document_copy_current(snapshot))
		valid = FALSE
	for (var/check_index = 1, check_index <= receivers.len, check_index++)
		var/obj/structure/mailbox/received/checked_receiver = receivers[check_index]
		if (!checked_receiver || checked_receiver.gc_destroyed || checked_receiver.faction != faction || checked_receiver.loc != places[check_index])
			valid = FALSE
	if (!valid)
		for (var/obj/item/weapon/paper/failed_output in outputs)
			qdel(failed_output)
		return FALSE
	for (var/publish_index = 1, publish_index <= outputs.len, publish_index++)
		var/obj/item/weapon/paper/published_output = outputs[publish_index]
		published_output.loc = places[publish_index]
	qdel(original)
	return TRUE
