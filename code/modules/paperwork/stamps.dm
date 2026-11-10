// Ink stamps and wax seals on paper.
//
// Each impression adds the stamp's look (its icon_state text) to `stamped` and
// a plain image marker to `stamps`. Both are ordinary saved paper fields that
// copies and canonical records already carry, so nothing here is runtime-only
// except the overlay images rebuilt from `stamped`. Readers are sent the image
// files just before a page opens; the stored marker never holds a \ref.
// Old saves may hold stamp type paths in `stamped` (forensics reports); those
// are kept untouched and simply have no image.

#define PAPER_STAMP_LIMIT 12

/obj/item/weapon/paper
	var/list/stamp_overlay_images = null

/obj/item/weapon/paper/persistence_runtime_var(key)
	return key == "stamp_overlay_images" || ..()

var/global/list/paper_stamp_icon_cache = null

// The large reader image for a stamp look: ink stamps, then wax seals, then
// the small sheet overlay as a last resort. Unknown looks have no image.
/proc/paper_stamp_reader_icon(state)
	if (!istext(state) || !length(state) || length(state) > 64)
		return null
	if (!paper_stamp_icon_cache)
		paper_stamp_icon_cache = list(
			"stamps" = icon_states('icons/stamps/dmi/stamps.dmi'),
			"seals" = icon_states('icons/stamps/dmi/seals.dmi'),
			"sheet" = icon_states('icons/obj/bureaucracy.dmi'))
	if (state in paper_stamp_icon_cache["stamps"])
		return icon('icons/stamps/dmi/stamps.dmi', state)
	if (state in paper_stamp_icon_cache["seals"])
		return icon('icons/stamps/dmi/seals.dmi', state)
	// The NKVD stamp's large image lives with the seals.
	if (state == "stamp-nkvd")
		return icon('icons/stamps/dmi/seals.dmi', "seal-nkvd")
	var/sheet_state = paper_stamp_sheet_state(state)
	if (sheet_state)
		return icon('icons/obj/bureaucracy.dmi', sheet_state)
	return null

// The small impression drawn on the sheet itself, if the look has one.
/proc/paper_stamp_sheet_state(state)
	if (!istext(state) || !length(state))
		return null
	if (!paper_stamp_icon_cache)
		paper_stamp_reader_icon(state)
	var/list/sheet = paper_stamp_icon_cache["sheet"]
	if ("paper_[state]" in sheet)
		return "paper_[state]"
	// Looks whose sheet impression has another name in bureaucracy.dmi (the
	// latin one is misspelled there; the plain envelope seal leaves a ring).
	var/alias = list("stamp-latin" = "paper_stam-latin", "stamp-deny" = "paper_stamp-denied", "stamp-nkvd" = "paper_seal-cccp", "stamp-blank" = "paper_stamp-circle")[state]
	if (alias && (alias in sheet))
		return alias
	return null

/proc/paper_stamp_resource_name(state)
	return "paperstamp_[state].png"

// Stored marker for one impression. The alt text names the stamp so text-only
// readers (the editor page, screen readers) still say what was stamped.
/proc/paper_stamp_marker(obj/item/weapon/stamp/S)
	return "<img src=\"[paper_stamp_resource_name(S.icon_state)]\" alt=\"[html_encode(S.name)]\" title=\"[html_encode(S.name)]\" style=\"margin:4px\">"

// Send the image files a reader needs for this page's stamps.
/proc/paper_stamp_send_assets(mob/reader, obj/item/weapon/paper/P)
	if (!reader || !reader.client || !P || !islist(P.stamped))
		return
	for (var/state in P.stamped)
		if (!istext(state))
			continue
		var/icon/I = paper_stamp_reader_icon(state)
		if (I)
			reader << browse_rsc(I, paper_stamp_resource_name(state))

// Rebuild the sheet overlays from the saved stamp list. Offsets come from the
// impression's position, so a reload or a copy looks the same every time.
/proc/paper_stamp_refresh_overlays(obj/item/weapon/paper/P)
	if (!P || P.gc_destroyed)
		return
	if (islist(P.stamp_overlay_images))
		for (var/image/old in P.stamp_overlay_images)
			P.overlays -= old
	P.stamp_overlay_images = null
	if (!islist(P.stamped) || !P.stamped.len)
		return
	var/list/added = list()
	var/index = 0
	for (var/state in P.stamped)
		index++
		if (!istext(state))
			continue
		var/sheet_state = paper_stamp_sheet_state(state)
		if (!sheet_state)
			continue
		var/image/impression = image('icons/obj/bureaucracy.dmi', icon_state = sheet_state)
		impression.pixel_x = ((index * 7) % 5) - 2
		impression.pixel_y = ((index * 5) % 6) - 3
		P.overlays += impression
		added += impression
	if (added.len)
		P.stamp_overlay_images = added

/proc/paper_stamp_can_reach(obj/item/weapon/paper/P, mob/user, obj/item/weapon/stamp/S)
	if (!P || P.gc_destroyed || !user || user.stat || user.restrained() || !S || S.gc_destroyed || user.get_active_hand() != S)
		return FALSE
	if (P.loc == user || P.Adjacent(user))
		return TRUE
	var/atom/holder = P.loc
	if (istype(holder, /obj/item/weapon/clipboard) || istype(holder, /obj/item/weapon/folder) || istype(holder, /obj/item/weapon/paper_bundle))
		return holder.loc == user || holder.Adjacent(user)
	return FALSE

/proc/paper_stamp_list_with(list/current, state)
	var/list/result = islist(current) ? current.Copy() : list()
	result += state
	return result

// The first impression starts on its own line below the writing.
/proc/paper_stamp_join(current, marker)
	if (!length(current))
		return "<BR>[marker]"
	return "[current][marker]"

// Records one impression and returns "stamped", "crumpled", "full" or
// "failed". A written (canonical) document takes the stamp through the same
// prepare/commit transaction as every other change, so its legacy mirror and
// record stay in step and any open editor sees a new revision.
/proc/paper_document_apply_stamp(obj/item/weapon/paper/P, obj/item/weapon/stamp/S, mob/user)
	if (!paper_stamp_can_reach(P, user, S) || !istext(S.icon_state) || !length(S.icon_state) || length(S.icon_state) > 64)
		return "failed"
	if (P.icon_state == "scrap" || findtext(P.icon_state, "_scrap"))
		return "crumpled"
	if (islist(P.stamped) && length(P.stamped) >= PAPER_STAMP_LIMIT)
		return "full"
	var/marker = paper_stamp_marker(S)
	if (isnull(P.document_record))
		var/list/next_stamped = paper_stamp_list_with(P.stamped, S.icon_state)
		P.stamps = paper_stamp_join(P.stamps, marker)
		P.stamped = next_stamped
		paper_authoring_notify(P, "physical")
	else
		var/list/edit = paper_document_prepare_edit(P)
		if (!edit)
			return "failed"
		var/list/next = edit["record"]
		var/list/legacy = next["legacy"]
		legacy["stamped"] = paper_stamp_list_with(legacy["stamped"], S.icon_state)
		legacy["stamps"] = paper_stamp_join(legacy["stamps"], marker)
		next["revision"]++
		if (!paper_document_commit_edit(P, edit))
			return "failed"
	paper_stamp_refresh_overlays(P)
	return "stamped"

/obj/item/weapon/paper/after_load()
	..()
	paper_stamp_refresh_overlays(src)

#undef PAPER_STAMP_LIMIT
