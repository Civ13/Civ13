// The storage window: one TGUI screen for every container a character can
// reach. "You" lists their hands, pockets and worn storages; "Nearby" lists
// storage structures, bags on the floor and a body's bags next to them, plus
// the loose things on the floor. Moving anything takes time (Project Zomboid
// style): moves wait in a queue, walking away or being stopped cancels them.
// Design by Fable (docs/storage-window.md). The window is opt-in: the classic
// HUD strip is the default, and also serves agent characters and browsers that
// can't run the window. The strip keeps the same timing and searching rules
// (storage_strip.dm).
//
// Server checks are authoritative: the window only ever names an item by the id
// of the last snapshot, and every move re-checks reach, access and room when it
// starts and again when it lands.

#define STORAGE_WINDOW_ICONS_PER_PUSH 40
#define STORAGE_WINDOW_FLOOR_LIMIT 30
#define STORAGE_WINDOW_QUEUE_LIMIT 40
// Storage window kinds: code/__defines/storage_window.dm

/client
	// Set once this client's browser could not run the storage window.
	var/tmp/storage_window_classic = FALSE
	// "icon|state" -> picture file already sent to this client ("-" = none).
	var/tmp/list/storage_icon_cache

/mob/living/human
	var/tmp/datum/storage_window/storage_window
	// The container last clicked open or shut through its strip, and when.
	var/tmp/obj/item/weapon/storage/storage_click_last
	var/tmp/storage_click_time = 0
	// Set once a double-click has opened the window, so the rest of that
	// double-click (BYOND may send a Click and a DblClick) does nothing more.
	var/tmp/storage_click_doubled = FALSE

/mob/living/human/persistence_runtime_var(key)
	return key == "storage_window" || key == "storage_click_last" || key == "storage_click_time" || key == "storage_click_doubled" || ..()

// Strip clicks: one click opens a container's strip, a click on it while the
// strip is showing closes it, and a second click within the double-click time
// opens the storage window instead. Nothing waits for the double-click: the
// first click acts at once and the second one turns it into the window.
#define STORAGE_DOUBLE_CLICK_TIME 5 // deciseconds, about the usual system double-click time
#define STORAGE_CLICK_OPEN "open"
#define STORAGE_CLICK_CLOSE "close"
#define STORAGE_CLICK_WINDOW "window"
#define STORAGE_CLICK_IGNORE "ignore"

/mob/living/human/proc/storage_click_recent(obj/item/weapon/storage/S)
	return S && storage_click_last == S && world.time - storage_click_time <= STORAGE_DOUBLE_CLICK_TIME

/mob/living/human/proc/storage_click(obj/item/weapon/storage/S)
	if (storage_click_recent(S))
		if (storage_click_doubled)
			return STORAGE_CLICK_IGNORE
		storage_click_doubled = TRUE
		// Without a window, the second click of a double-click does nothing.
		return storage_window_possible() ? STORAGE_CLICK_WINDOW : STORAGE_CLICK_IGNORE
	storage_click_last = S
	storage_click_time = world.time
	storage_click_doubled = FALSE
	return s_active == S ? STORAGE_CLICK_CLOSE : STORAGE_CLICK_OPEN

// BYOND may report the second half of a double-click only as a DblClick on the
// bag or on the structure holding it.
/mob/living/human/DblClickOn(atom/A, params)
	var/obj/item/weapon/storage/S = storage_click_last
	if (!A || !S || QDELETED(S) || (A != S && S.loc != A) || !storage_click_recent(S))
		return ..()
	if (storage_window_wanted())
		return
	if (storage_click(S) == STORAGE_CLICK_WINDOW)
		storage_window_show(src, S)

// By default a click on a bag opens its classic HUD strip, a second click closes
// it, and a quick double-click opens the storage window instead. Turning this on
// (Character Setup > Settings, or the Storage Window verb) always opens the window.
/datum/client_preference/storage_window
	description = "Bags and containers open in"
	key = "STORAGE_WINDOW"
	enabled_by_default = FALSE
	enabled_description = "Storage window"
	disabled_description = "Strip, double-click for the window"

/datum/client_preference/storage_window/toggled(mob/preference_mob, enabled)
	var/mob/living/human/H = preference_mob
	if (istype(H) && H.s_active)
		H.s_active.close(H)
	if (preference_mob)
		to_chat(preference_mob, SPAN_NOTICE(enabled ? "Bags and containers now open the storage window." : "Bags and containers now open the classic storage strip. Click one again to close it, or double-click it to open the storage window."))

/client/verb/toggle_storage_window()
	set name = "Storage Window"
	set category = "OOC"
	set desc = "Switch between always opening the storage window and the strip (double-click for the window)."
	if (!prefs)
		return
	set_preference("STORAGE_WINDOW", !is_preference_enabled("STORAGE_WINDOW"))

// The window can run for this player at all (agents and failed browsers can't).
/mob/living/human/proc/storage_window_possible()
	return client && !client.storage_window_classic && !client.modern_ui_failed

/mob/living/human/proc/storage_window_wanted()
	return storage_window_possible() && client.is_preference_enabled("STORAGE_WINDOW")

// Called first by /obj/item/weapon/storage/open(). TRUE when the window (or a
// strip click) took it, FALSE to show the classic strip.
/proc/storage_window_open(mob/user, obj/item/weapon/storage/S)
	var/mob/living/human/H = user
	if (!istype(H))
		return FALSE
	if (H.storage_window_wanted())
		return storage_window_show(H, S)
	if (!S || !H.client)
		return FALSE
	switch (H.storage_click(S))
		if (STORAGE_CLICK_CLOSE)
			S.close(H)
			return TRUE
		if (STORAGE_CLICK_WINDOW)
			return storage_window_show(H, S)
		if (STORAGE_CLICK_IGNORE)
			return TRUE
	return FALSE

// Right-click > Open Storage Window: the window for one container, whatever
// the player's setting, without the double-click.
/proc/storage_window_verb_open(mob/user, obj/item/weapon/storage/S)
	var/mob/living/human/H = user
	if (!istype(H) || !S || H.incapacitated())
		return
	if (!H.storage_window_possible())
		to_chat(H, SPAN_WARNING("The storage window can't open here; use the strip instead."))
		return
	if (!storage_window_show(H, S))
		to_chat(H, SPAN_WARNING("You can't reach \the [S]."))

/obj/item/weapon/storage/verb/open_storage_window()
	set name = "Open Storage Window"
	set category = null
	set src in view(1)
	storage_window_verb_open(usr, src)

/obj/structure/storage_container/verb/open_storage_window()
	set name = "Open Storage Window"
	set category = null
	set src in view(1)
	if (!usr || !usr.Adjacent(src) || !storage_access_allowed(usr))
		return
	ensure_storage()
	storage_window_verb_open(usr, storage)

// IC > Open Storage Window Here: the window with no bag in focus, for the
// hands, pockets, worn gear, containers nearby and the loose things on the floor.
/mob/living/human/verb/open_storage_window_here()
	set name = "Open Storage Window Here"
	set category = "IC"
	if (incapacitated())
		return
	if (!storage_window_possible())
		to_chat(src, SPAN_WARNING("The storage window can't open here; use the strip instead."))
		return
	storage_window_show(src, null)

// S may be null: the window then opens with nothing in focus.
/proc/storage_window_show(mob/living/human/H, obj/item/weapon/storage/S)
	var/datum/storage_window/W = H.storage_window
	if (!W)
		W = new /datum/storage_window(H)
		H.storage_window = W
	if (S && !W.lists_holder(S))
		return FALSE
	if (H.s_active)
		H.s_active.close(H)
	W.focus = S
	W.focus_seq++
	for (var/list/entry in W.holders())
		if (S && entry[2] == S && !storage_window_kind_known(entry[1]))
			W.begin_search(S)
			break
	W.ui_interact(H)
	return TRUE

/////////////////////////////////////////////////////////////// the window

/datum/storage_window
	var/mob/living/human/viewer
	var/obj/item/weapon/storage/focus
	var/focus_seq = 0
	// The last snapshot's ids: item id -> item, group id -> list(kind, holder, quick).
	var/list/served_items = list()
	var/list/served_groups = list()
	// Moves waiting: each a list("item", "kind", "holder", "time", "name", "image", "to").
	var/list/queue = list()
	var/list/current
	var/current_started = 0
	var/turf/start_turf
	var/timer_id

/datum/storage_window/New(mob/living/human/H)
	viewer = H

/datum/storage_window/Destroy()
	cancel_all(FALSE)
	stop_search()
	if (viewer && viewer.storage_window == src)
		viewer.storage_window = null
	viewer = null
	focus = null
	served_items = null
	served_groups = null
	return ..()

/datum/storage_window/proc/closed()
	// The queue keeps running after the window closes; the snapshot and the search do not.
	stop_search()
	focus = null
	served_items = list()
	served_groups = list()

/datum/storage_window/proc/still_valid(mob/user)
	return user && user == viewer && !QDELETED(viewer) && viewer.client

// A body: someone who can't stop you going through their things.
/proc/storage_window_body(mob/living/human/M)
	return istype(M) && (M.stat != CONSCIOUS || M.restrained())

// Every container the window lists, in order: list(kind, holder, name, quick, owner).
/datum/storage_window/proc/holders()
	. = list()
	var/mob/living/human/H = viewer
	. += list(list(STORAGE_WINDOW_KIND_HANDS, H, "Hands", TRUE, null))
	for (var/obj/item/weapon/storage/S in H.worn_storage_group("all"))
		. += list(list(STORAGE_WINDOW_KIND_WORN, S, S.name, (H.belt && (S == H.belt || (S in H.belt))) ? TRUE : FALSE, null))
	. += list(list(STORAGE_WINDOW_KIND_POCKETS, H, "pockets", TRUE, null))
	var/turf/here = get_turf(H)
	if (!here)
		return
	for (var/turf/T in range(1, here))
		for (var/atom/movable/A in T)
			if (A == H)
				continue
			if (istype(A, /obj/structure))
				var/obj/item/weapon/storage/internal/IS = storage_window_structure_holder(A)
				if (IS)
					. += list(list(STORAGE_WINDOW_KIND_NEAR, IS, A.name, FALSE, null))
			else if (istype(A, /obj/item/weapon/storage) && isturf(A.loc))
				. += list(list(STORAGE_WINDOW_KIND_NEAR, A, A.name, FALSE, null))
			else if (storage_window_body(A))
				var/mob/living/human/M = A
				for (var/obj/item/weapon/storage/S in M.worn_storage_group("all"))
					. += list(list(STORAGE_WINDOW_KIND_BODY, S, S.name, FALSE, M))

// The internal storage a structure keeps its things in, when it has one.
/proc/storage_window_structure_holder(obj/structure/O)
	// An open crate or closet holds its things itself (closet_storage.dm).
	if (istype(O, /obj/structure/closet))
		var/obj/structure/closet/C = O
		return (C.item_window && C.opened) ? C : null
	if (!("storage" in O.vars))
		return null
	if (istype(O, /obj/structure/storage_container))
		var/obj/structure/storage_container/C = O
		C.ensure_storage()
	var/obj/item/weapon/storage/internal/IS = O.vars["storage"]
	if (!istype(IS) || IS.loc != O)
		return null
	return IS

/datum/storage_window/proc/lists_holder(obj/item/weapon/storage/S)
	for (var/list/entry in holders())
		if (entry[2] == S)
			return TRUE
	return FALSE

// The structure (or null) whose rules guard a holder.
/proc/storage_window_owner_structure(obj/item/weapon/storage/S)
	if (istype(S, /obj/structure/closet))
		return S
	if (istype(S, /obj/item/weapon/storage/internal) && istype(S.loc, /obj/structure))
		return S.loc
	return null

/proc/storage_window_access(mob/user, obj/item/weapon/storage/S)
	if (istype(S, /obj/structure/closet))
		return closet_window_access(user, S)
	if (!S || !S.storage_contents_accessible())
		return FALSE
	var/obj/structure/storage_container/C = storage_window_owner_structure(S)
	if (istype(C) && !C.storage_access_allowed(user))
		return FALSE
	return TRUE

// Things lying loose on the viewer's tile and the tiles around it.
/datum/storage_window/proc/floor_items()
	. = list()
	var/turf/here = get_turf(viewer)
	if (!here)
		return
	for (var/turf/T in range(1, here))
		for (var/obj/item/I in T)
			if (I.anchored || istype(I, /obj/item/weapon/storage))
				continue
			. += I
			if (length(.) >= STORAGE_WINDOW_FLOOR_LIMIT)
				return

// Is this item somewhere the viewer may take it from right now?
/datum/storage_window/proc/reachable(obj/item/I)
	if (!I || QDELETED(I) || I.anchored)
		return FALSE
	var/mob/living/human/H = viewer
	var/atom/A = I.loc
	if (A == H)
		return TRUE
	if (isturf(A))
		return get_dist(A, H) <= 1 && A.z == H.z
	if (istype(A, /obj/item/weapon/storage) || istype(A, /obj/structure/closet))
		if (!storage_window_access(H, A))
			return FALSE
		return lists_holder(A)
	return FALSE

/////////////////////////////////////////////////////////////// snapshot

/datum/storage_window/proc/picture(obj/item/I, list/budget)
	var/client/C = viewer.client
	if (!C || !I || !I.icon || !istext(I.icon_state))
		return ""
	if (!islist(C.storage_icon_cache))
		C.storage_icon_cache = list()
	var/key = "[I.icon]|[I.icon_state]"
	var/known = C.storage_icon_cache[key]
	if (known)
		return known == "-" ? "" : known
	if (budget[1] <= 0)
		budget[2] = TRUE
		return ""
	budget[1]--
	var/icon/pic = icon(I.icon, I.icon_state, SOUTH, 1)
	if (!pic)
		C.storage_icon_cache[key] = "-"
		return ""
	var/filename = "stor_[md5(key)].png"
	C << browse_rsc(pic, filename)
	C.storage_icon_cache[key] = filename
	return filename

/proc/storage_window_size_name(w_class)
	switch (w_class)
		if (ITEM_SIZE_TINY)
			return "tiny"
		if (ITEM_SIZE_SMALL)
			return "small"
		if (ITEM_SIZE_NORMAL)
			return "normal"
		if (ITEM_SIZE_LARGE)
			return "large"
	return "bulky"

/datum/storage_window/proc/item_row(obj/item/I, list/budget)
	// Ids stay the same across snapshots so a selection survives a refresh.
	var/id = "i[ref(I)]"
	served_items[id] = I
	var/count = 0
	if (istype(I, /obj/item/stack))
		var/obj/item/stack/ST = I
		count = ST.amount
	var/list/row = list("id" = id, "name" = html_encode(I.name), "size" = storage_window_size_name(I.w_class), "size_class" = I.w_class, "cost" = I.get_storage_cost(), "image" = picture(I, budget))
	if (count > 1)
		row["count"] = count
	for (var/list/job in queue)
		if (job["item"] == I)
			row["queued"] = 1
	if (current && current["item"] == I)
		row["moving"] = 1
	return row

/datum/storage_window/proc/group_id(kind, atom/holder, quick)
	var/id = "[kind]:[ref(holder)]"
	served_groups[id] = list(kind, holder, quick)
	return id

/datum/storage_window/proc/build_data()
	served_items = list()
	served_groups = list()
	var/list/budget = list(STORAGE_WINDOW_ICONS_PER_PUSH, FALSE)
	var/mob/living/human/H = viewer
	var/list/you = list()
	var/list/near = list()
	var/list/hands = list()
	var/hands_id = group_id(STORAGE_WINDOW_KIND_HANDS, H, TRUE)
	for (var/side in list("left", "right"))
		var/obj/item/held = side == "left" ? H.l_hand : H.r_hand
		var/list/slot = list("side" = side)
		slot["active"] = ((side == "left" && H.hand) || (side == "right" && !H.hand)) ? 1 : 0
		if (held)
			slot["item"] = item_row(held, budget)
		hands += list(slot)
	for (var/list/entry in holders())
		var/kind = entry[1]
		if (kind == STORAGE_WINDOW_KIND_HANDS)
			continue
		if (kind == STORAGE_WINDOW_KIND_POCKETS)
			var/list/pocket_items = list()
			var/pocket_id = group_id(kind, H, TRUE)
			for (var/obj/item/P in list(H.l_store, H.r_store))
				pocket_items += list(item_row(P, budget))
			you += list(list("id" = pocket_id, "kind" = kind, "name" = "pockets", "slots" = 2, "used" = pocket_items.len, "items" = pocket_items, "can_dump" = 1, "unit" = "slots"))
			continue
		var/obj/item/weapon/storage/S = entry[2]
		var/list/G = list("id" = group_id(kind, S, entry[4]), "kind" = kind, "name" = html_encode(entry[3]))
		var/obj/structure/owner = storage_window_owner_structure(S)
		G["image"] = owner ? picture_of_atom(owner, budget) : picture(S, budget)
		if (S == focus || owner && focus == S)
			G["focus"] = focus_seq
		if (!storage_window_access(H, S))
			G["locked"] = 1
			G["items"] = list()
		else
			var/list/items = list()
			var/list/unseen = list()
			var/used = 0
			for (var/obj/item/I in S.contents)
				used += I.get_storage_cost()
				if (knows(I, kind))
					items += list(item_row(I, budget))
				else if (I != search_item)
					unseen += I.w_class
			G["items"] = items
			if (istype(S, /obj/structure/closet/crate))
				// Crates count things, not space.
				var/obj/structure/closet/crate/CR = S
				G["used"] = items.len + unseen.len + (search_holder == S && search_item ? 1 : 0)
				G["slots"] = CR.storagecap
				G["unit"] = "things"
			else if (!istype(S, /obj/structure/closet))
				G["used"] = used
				G["space"] = S.max_storage_space
				G["slots"] = S.storage_slots
				G["max_size"] = S.max_w_class
			G["total"] = S.shown_contents_count()
			if (unseen.len)
				G["unseen"] = unseen
			if (search_holder == S && search_item)
				G["search"] = list("size_class" = search_item.w_class, "time" = storage_search_time(search_item), "done" = world.time - search_started)
			// Nothing is tipped out before it has been looked at.
			G["can_dump"] = (unseen.len || G["search"]) ? 0 : 1
			G["can_take"] = kind != STORAGE_WINDOW_KIND_WORN ? 1 : 0
		if (kind == STORAGE_WINDOW_KIND_BODY)
			var/mob/M = entry[5]
			G["owner"] = html_encode("Body of [M.real_name ? M.real_name : M.name]")
		if (kind == STORAGE_WINDOW_KIND_WORN)
			you += list(G)
		else
			near += list(G)
	var/list/floor = list()
	for (var/obj/item/I in floor_items())
		floor += list(item_row(I, budget))
	var/floor_id = group_id(STORAGE_WINDOW_KIND_FLOOR, get_turf(H), FALSE)
	near += list(list("id" = floor_id, "kind" = STORAGE_WINDOW_KIND_FLOOR, "name" = "Floor", "items" = floor, "can_take" = floor.len ? 1 : 0))
	var/list/jobs = list()
	if (current)
		jobs += list(job_row(current, world.time - current_started))
	for (var/list/job in queue)
		jobs += list(job_row(job, 0))
	return list(
		"hands_id" = hands_id,
		"hands" = hands,
		"you" = you,
		"near" = near,
		"queue" = jobs,
		"more_images" = budget[2] ? 1 : 0)

/datum/storage_window/proc/picture_of_atom(atom/A, list/budget)
	var/client/C = viewer.client
	if (!C || !A.icon || !istext(A.icon_state))
		return ""
	if (!islist(C.storage_icon_cache))
		C.storage_icon_cache = list()
	var/key = "[A.icon]|[A.icon_state]"
	var/known = C.storage_icon_cache[key]
	if (known)
		return known == "-" ? "" : known
	if (budget[1] <= 0)
		budget[2] = TRUE
		return ""
	budget[1]--
	var/filename = "stor_[md5(key)].png"
	C << browse_rsc(icon(A.icon, A.icon_state, SOUTH, 1), filename)
	C.storage_icon_cache[key] = filename
	return filename

/datum/storage_window/proc/job_row(list/job, done)
	return list("name" = job["name"], "image" = job["image"], "to" = job["to"], "time" = job["time"], "done" = done)

/////////////////////////////////////////////////////////////// window plumbing

/datum/topic_state/storage_window/can_use_topic(var/datum/storage_window/W, var/mob/user)
	if (!istype(W) || !W.still_valid(user))
		return STATUS_CLOSE
	if (user.stat || user.restrained())
		return STATUS_DISABLED
	return STATUS_INTERACTIVE

/datum/nanoui/tgui/storage_window/close()
	var/datum/storage_window/W = src_object
	. = ..()
	if (istype(W))
		W.closed()

// A browser that cannot run the window gets the old strip for this connection.
/datum/nanoui/tgui/storage_window/show_plain_page()
	var/datum/storage_window/W = src_object
	var/mob/living/human/H = user
	var/obj/item/weapon/storage/S = istype(W) ? W.focus : null
	if (H && H.client)
		H.client.storage_window_classic = TRUE
	close()
	if (istype(H) && S && !QDELETED(S))
		S.open(H)

/datum/storage_window/ui_actions(ui_key)
	return list("move", "take_all", "dump", "cancel", "images", "search")

/datum/storage_window/ui_action_fields(ui_key, action)
	if (action == "move")
		return list("to")
	return ..()

/datum/storage_window/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE, var/datum/nanoui/master_ui = null, var/datum/topic_state/state = null)
	if (!still_valid(user))
		return
	var/list/data = build_data()
	ui = GLOB.nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		var/datum/topic_state/storage_window/window_state = new()
		ui = new /datum/nanoui/tgui/storage_window(user, src, ui_key, "storage_window.tmpl", "Storage", 760, 600, _state = window_state)
		ui.set_initial_data(data)
		ui.open()
		ui.set_auto_update(TRUE)

/datum/storage_window/proc/refresh()
	if (viewer && viewer.client)
		GLOB.nanomanager.update_uis(src)

/datum/storage_window/ui_act(action, list/params, mob/user, datum/nanoui/ui)
	if (!still_valid(user) || viewer.stat || viewer.restrained())
		return TRUE
	switch (action)
		if ("images")
			return TRUE
		if ("cancel")
			cancel_all(TRUE)
			return TRUE
		if ("search")
			var/list/group = served_groups["[params["value"]]"]
			if (group && !storage_window_kind_known(group[1]))
				begin_search(group[2])
			return TRUE
		if ("move")
			var/list/ids = splittext("[params["value"]]", ",")
			var/list/target = served_groups["[params["to"]]"]
			if (!target || ids.len > STORAGE_WINDOW_QUEUE_LIMIT)
				return TRUE
			for (var/id in ids)
				var/obj/item/I = served_items[id]
				if (I)
					enqueue(I, target[1], target[2], target[3])
			return TRUE
		if ("take_all", "dump")
			var/list/source = served_groups["[params["value"]]"]
			if (!source)
				return TRUE
			for (var/id in served_items)
				var/obj/item/I = served_items[id]
				if (!I || !storage_window_in_group(I, source, viewer))
					continue
				if (action == "dump")
					enqueue(I, STORAGE_WINDOW_KIND_FLOOR, get_turf(viewer), FALSE)
				else
					enqueue(I, "auto", null, TRUE)
			return TRUE
	return FALSE

// Whether an item sits in the group a snapshot named.
/proc/storage_window_in_group(obj/item/I, list/group, mob/living/human/H)
	switch (group[1])
		if (STORAGE_WINDOW_KIND_HANDS)
			return I == H.l_hand || I == H.r_hand
		if (STORAGE_WINDOW_KIND_POCKETS)
			return I == H.l_store || I == H.r_store
		if (STORAGE_WINDOW_KIND_FLOOR)
			return isturf(I.loc) && get_dist(I, H) <= 1
	return I.loc == group[2]

/////////////////////////////////////////////////////////////// timed moves

// Deciseconds a move takes: 0.3 s plus 0.2 s per size class, half as long to or
// from your hands, pockets and belt, half again as long out of a body's gear.
/proc/storage_window_move_time(obj/item/I, from_quick, to_quick, from_body)
	. = 3 + 2 * clamp(I.w_class, 1, 5)
	if (from_quick || to_quick)
		. *= 0.5
	if (from_body)
		. *= 1.5
	. = max(2, round(., 1))

/datum/storage_window/proc/source_flags(obj/item/I)
	var/mob/living/human/H = viewer
	var/quick = FALSE
	var/body = FALSE
	if (I.loc == H)
		quick = (I == H.l_hand || I == H.r_hand || I == H.l_store || I == H.r_store || I == H.belt)
	else if (H.belt && (I.loc == H.belt || (I.loc in H.belt)))
		quick = TRUE
	else if (istype(I.loc, /obj/item/weapon/storage) && ismob(I.loc.loc) && I.loc.loc != H)
		body = TRUE
	return list(quick, body)

/datum/storage_window/proc/enqueue(obj/item/I, kind, atom/holder, to_quick)
	if (queue.len >= STORAGE_WINDOW_QUEUE_LIMIT || !reachable(I))
		return FALSE
	if (current && current["item"] == I)
		return FALSE
	for (var/list/job in queue)
		if (job["item"] == I)
			return FALSE
	if (kind != "auto" && kind != STORAGE_WINDOW_KIND_FLOOR && storage_window_in_group(I, list(kind, holder), viewer))
		return FALSE
	var/list/flags = source_flags(I)
	var/to_name = "the floor"
	switch (kind)
		if (STORAGE_WINDOW_KIND_HANDS)
			to_name = "your hands"
		if (STORAGE_WINDOW_KIND_POCKETS)
			to_name = "your pockets"
		if ("auto")
			to_name = "your things"
		if (STORAGE_WINDOW_KIND_FLOOR)
			to_name = "the floor"
		else
			var/obj/structure/owner = storage_window_owner_structure(holder)
			to_name = html_encode(owner ? owner.name : holder.name)
	var/list/budget = list(1, FALSE)
	queue += list(list("item" = I, "kind" = kind, "holder" = holder, "time" = storage_window_move_time(I, flags[1], to_quick, flags[2]), "name" = html_encode(I.name), "image" = picture(I, budget), "to" = to_name))
	if (!current)
		next_move()
	return TRUE

/datum/storage_window/proc/next_move()
	current = null
	if (!queue.len || !viewer || QDELETED(viewer))
		refresh()
		return
	current = queue[1]
	queue.Cut(1, 2)
	current_started = world.time
	start_turf = get_turf(viewer)
	timer_id = addtimer(CALLBACK(src, PROC_REF(finish_move)), current["time"], TIMER_STOPPABLE)
	refresh()

/datum/storage_window/proc/cancel_all(tell = TRUE)
	if (timer_id)
		deltimer(timer_id)
		timer_id = null
	var/had = (current || queue.len)
	current = null
	queue = list()
	if (tell && had && viewer)
		to_chat(viewer, SPAN_NOTICE("You stop moving things."))
	refresh()

/datum/storage_window/proc/finish_move()
	timer_id = null
	var/mob/living/human/H = viewer
	if (!H || QDELETED(H) || !current)
		return
	if (get_turf(H) != start_turf || H.stat || H.restrained() || H.incapacitated())
		cancel_all(TRUE)
		return
	usr = H // storage procs report to usr
	var/list/job = current
	if (!perform_move(job["item"], job["kind"], job["holder"]))
		to_chat(H, SPAN_WARNING("You couldn't move \the [job["item"]] to [job["to"]]."))
	next_move()

// The move itself, re-checked now: reach, access, room. Nothing is dropped on
// the floor unless the floor was asked for.
/datum/storage_window/proc/perform_move(obj/item/I, kind, atom/holder)
	var/mob/living/human/H = viewer
	if (!reachable(I))
		return FALSE
	if (kind == "auto")
		var/list/target = auto_target(I)
		if (!target)
			return FALSE
		kind = target[1]
		holder = target[2]
	switch (kind)
		if (STORAGE_WINDOW_KIND_FLOOR)
			if (!detach(I))
				return FALSE
			return I.persistence_set_loc(get_turf(H))
		if (STORAGE_WINDOW_KIND_HANDS)
			if (H.l_hand && H.r_hand)
				return FALSE
			if (!detach(I))
				return FALSE
			if (!H.put_in_hands(I))
				return FALSE
			return TRUE
		if (STORAGE_WINDOW_KIND_POCKETS)
			var/slot = pocket_slot_for(I)
			if (!slot || !detach(I))
				return FALSE
			return H.equip_to_slot_if_possible(I, slot, FALSE, TRUE)
	if (istype(holder, /obj/structure/closet))
		var/obj/structure/closet/C = holder
		if (QDELETED(C) || !lists_holder(C) || !storage_window_access(H, C) || !closet_has_room(C, I, H))
			return FALSE
		if (!detach(I))
			return FALSE
		I.forceMove(C)
		storage_note_inserted(I, H)
		return TRUE
	var/obj/item/weapon/storage/S = holder
	if (!istype(S) || QDELETED(S) || !lists_holder(S) || !storage_window_access(H, S))
		return FALSE
	if (!S.can_be_inserted(I, TRUE))
		// No room for the whole stack: still top up the stacks inside.
		if (S.stack_merge_room(I, H) > 0)
			S.merge_stack_in(I, H)
			return TRUE
		S.can_be_inserted(I, FALSE) // says why
		return FALSE
	if (!detach(I))
		return FALSE
	return S.handle_item_insertion(I, TRUE)

/datum/storage_window/proc/pocket_slot_for(obj/item/I)
	var/mob/living/human/H = viewer
	if (!H.l_store && I.mob_can_equip(H, slot_l_store, TRUE))
		return slot_l_store
	if (!H.r_store && I.mob_can_equip(H, slot_r_store, TRUE))
		return slot_r_store
	return 0

// Take All puts things away: the first worn bag with room, then pockets, then hands.
/datum/storage_window/proc/auto_target(obj/item/I)
	var/mob/living/human/H = viewer
	for (var/obj/item/weapon/storage/S in H.worn_storage_group("all"))
		if (S != I && S.loc != I && S.can_be_inserted(I, TRUE))
			return list(STORAGE_WINDOW_KIND_WORN, S)
	if (pocket_slot_for(I))
		return list(STORAGE_WINDOW_KIND_POCKETS, H)
	if (!H.l_hand || !H.r_hand)
		return list(STORAGE_WINDOW_KIND_HANDS, H)
	return null

// Free an item from wherever it is, leaving it on the viewer's tile.
/datum/storage_window/proc/detach(obj/item/I)
	var/mob/living/human/H = viewer
	var/atom/A = I.loc
	if (A == H)
		return H.remove_from_mob(I)
	if (istype(A, /obj/item/weapon/storage))
		var/obj/item/weapon/storage/S = A
		return S.remove_from_storage(I, get_turf(H))
	if (istype(A, /obj/structure/closet))
		I.forceMove(get_turf(H))
		return TRUE
	return isturf(A)

#undef STORAGE_WINDOW_ICONS_PER_PUSH
#undef STORAGE_WINDOW_FLOOR_LIMIT
#undef STORAGE_WINDOW_QUEUE_LIMIT
