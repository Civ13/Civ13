/////////////////////////////// Item piles ///////////////////////////////
// BYOND's native menu shares its hit-testing with left click. Collapse only
// identical, superimposed appearances: putting a duplicate out of the menu
// must not remove a visible click target beside the representative.

// The item is hidden under an identical one on its tile; pile_opacity holds
// the mouse_opacity it had. Both save with the item so a loaded pile stays
// consistent (mouse_opacity itself is saved when it differs from the default).
/obj/item/var/pile_hidden = FALSE
/obj/item/var/pile_opacity = 1

var/global/list/item_pile_dirty_turfs = list()
var/global/item_pile_flush_pending = FALSE

#define ITEM_PILE_BATCH 500

/proc/item_pile_mark(turf/T)
	if (!isturf(T))
		return
	item_pile_dirty_turfs[T] = TRUE
	if (item_pile_flush_pending)
		return
	item_pile_flush_pending = TRUE
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(item_pile_flush)), 1)

// Refreshes marked tiles a batch at a time (map loading marks thousands).
/proc/item_pile_flush(limit = ITEM_PILE_BATCH)
	item_pile_flush_pending = FALSE
	var/done = 0
	while (item_pile_dirty_turfs.len && (!limit || done < limit))
		var/turf/T = item_pile_dirty_turfs[item_pile_dirty_turfs.len]
		item_pile_dirty_turfs.len--
		item_pile_refresh(T)
		done++
	if (item_pile_dirty_turfs.len && !item_pile_flush_pending)
		item_pile_flush_pending = TRUE
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(item_pile_flush)), 1)

/proc/item_pile_key(obj/item/I)
	return "[I.type]|[I.name]|[I.invisibility]|[I.step_x]|[I.step_y]|[I.pixel_x]|[I.pixel_y]"

// Only merge candidates with precisely the same BYOND appearance, including
// direction, transforms, overlays, layer, plane and original mouse mask.
// Split obvious spatial differences by key first. If any remaining aspect
// differs, conservatively leave every item in that bucket clickable.
/proc/item_pile_refresh(turf/T)
	if (!isturf(T))
		return
	var/list/top = list()
	var/list/appearances = list()
	var/list/mixed = list()
	var/mutable_appearance/scratch
	for (var/obj/item/I in T)
		if (QDELETED(I))
			continue
		if ((!I.pile_hidden && !I.mouse_opacity) || !I.alpha || I.screen_loc)
			I.pile_reveal()
			continue
		var/key = item_pile_key(I)
		if (mixed[key])
			continue
		var/appearance = I.appearance
		if (I.pile_hidden)
			if (!scratch)
				scratch = new
			scratch.appearance = appearance
			scratch.mouse_opacity = I.pile_opacity
			appearance = scratch.appearance
		if (!top[key])
			appearances[key] = appearance
		else if (appearances[key] != appearance)
			mixed[key] = TRUE
		top[key] = I
	for (var/obj/item/I in T)
		if (QDELETED(I) || (!I.pile_hidden && !I.mouse_opacity) || !I.alpha || I.screen_loc)
			continue
		var/key = item_pile_key(I)
		if (mixed[key] || top[key] == I)
			I.pile_reveal()
		else
			I.pile_hide()

/obj/item/proc/pile_hide()
	if (pile_hidden)
		return
	pile_opacity = mouse_opacity
	pile_hidden = TRUE
	mouse_opacity = 0

/obj/item/proc/pile_reveal()
	if (!pile_hidden)
		return
	pile_hidden = FALSE
	mouse_opacity = pile_opacity || 1
	pile_opacity = initial(pile_opacity)

/obj/item/New()
	..()
	if (isturf(loc))
		item_pile_mark(loc)

/turf/Entered(atom/movable/AM, atom/old_loc)
	. = ..()
	if (istype(AM, /obj/item))
		item_pile_mark(src)

/turf/Exited(atom/movable/AM, atom/new_loc)
	. = ..()
	if (istype(AM, /obj/item))
		var/obj/item/I = AM
		I.pile_reveal() // clickable at once in a hand, bag or another tile
		item_pile_mark(src)

/proc/item_pile_moved(atom/movable/AM, atom/origin, atom/destination)
	if (!istype(AM, /obj/item) || !(isturf(origin) || isturf(destination)))
		return
	var/obj/item/I = AM
	I.pile_reveal() // raw turf-to-turf moves also need an immediate hitbox
	item_pile_mark(origin)
	item_pile_mark(destination)

// Other raw loc changes (legacy teleports) skip Exited too.
/obj/item/pickup(mob/user)
	pile_reveal()
	..()

/obj/item/equipped(var/mob/user, var/slot)
	pile_reveal()
	..()

/obj/item/on_enter_storage(obj/item/weapon/storage/S as obj)
	pile_reveal()
	..()

// Safety net for a pile whose top item left by a raw loc change: clicking the
// tile (all its items hidden, so the click lands on the turf) re-checks it.
/turf/Click(var/location, var/control, var/params)
	item_pile_mark(src)
	return ..()

/////////////////////////////// Item selection /////////////////////////////
// This is an ordinary BYOND choice prompt, not a second interaction path.
// Show no contents of containers and no objects hidden except by pile grouping.
#define ITEM_PILE_PICK_LIMIT 100

/client/var/tmp/item_pile_prompt_open = FALSE

/mob/living/human/proc/item_pile_can_choose(turf/site)
	return client && !client.item_pile_prompt_open && client.mob == src && client.eye == src && isturf(loc) && site && z == site.z && site.Adjacent(src) && !stat && !paralysis && !stunned && !weakened && !restrained() && !in_throw_mode && !using_object && canClick()

/proc/item_pile_selectable(mob/living/human/H, turf/site, obj/item/I, datum/los_context/context = null, datum/los_snapshot/snapshot = null)
	if (!(I && !QDELETED(I) && I.loc == site && I.name && I.alpha && I.invisibility <= H.see_invisible && (I.mouse_opacity || (I.pile_hidden && I.pile_opacity)) && !is_type_in_list(I, H.shouldnt_see) && I.Adjacent(H)))
		return FALSE
	return context ? context.decision_snapshot(I, snapshot, "click") != LOS_DENY : los_read_allowed(H, I, "click")

/proc/item_pile_options(mob/living/human/H, turf/site)
	var/list/options = list()
	var/datum/los_context/context = null
	var/datum/los_snapshot/snapshot = null
	var/datum/los_context/current = H.client?.los_context
	if (CIV13_GEOMETRIC_LOS_CORE && current?.eligible())
		if (current.body != H || current.owner != H.client)
			return options
		// Every candidate is a direct item on this one tile. Reuse one raw
		// capture only while building the list; the answer takes fresh sight.
		context = current
		snapshot = current.capture(FALSE, site)
		if (!snapshot)
			return options
	var/scanned = 0
	for (var/obj/item/I in site)
		if (++scanned > ITEM_PILE_PICK_LIMIT)
			break
		if (!item_pile_selectable(H, site, I, context, snapshot))
			continue
		// Native input is plain text. Prefix a number so identical names are
		// still separate choices, without inspecting writing or contents.
		var/display_name = I.name
		if (istype(I, /obj/item/stack) && I.amount > 1)
			display_name = "[display_name] ([I.amount] units)"
		options["[options.len + 1]. [display_name]"] = I
	return options

/proc/item_pile_has_choice(list/options)
	if (options.len > 1)
		return TRUE
	if (!options.len)
		return FALSE
	// Its normal representative may be out of sight. Selection is still
	// useful when the sole eligible item cannot be clicked directly.
	var/obj/item/only_item = options[options[1]]
	return only_item?.pile_hidden

/mob/living/human/proc/item_pile_choose(turf/site, list/options)
	var/client/chooser = client
	if (chooser.item_pile_prompt_open)
		return null
	var/atom/origin = loc
	var/obj/item/held = get_active_hand()
	var/original_hand = hand
	var/original_intent = a_intent
	var/original_click = next_click
	chooser.item_pile_prompt_open = TRUE
	var/label = player_input(src, "Pick up an item, or use your held item on it.", "Items on this tile", null, "anything", options, TRUE)
	if (chooser)
		chooser.item_pile_prompt_open = FALSE
	if (!label || QDELETED(src) || client != chooser || loc != origin || hand != original_hand || held != get_active_hand() || a_intent != original_intent || !item_pile_can_choose(site))
		return null
	// A separate click made while the chooser was open still owns its clock.
	if (next_click != original_click && world.time <= next_click)
		return null
	var/obj/item/selected = options[label]
	if (!item_pile_selectable(src, site, selected) || (travel_holds && travel_hold_refuses(src, selected)))
		return null
	next_click = world.time + 1
	return selected

#undef ITEM_PILE_PICK_LIMIT

/////////////////////////////// Loose piles ///////////////////////////////
// Plain items that are not /obj/item/stack (roofing, bricks, clay blocks) can
// still gather into one counted pile: one inventory item and one menu entry.
// loose_pile_max above 0 turns it on; amount is the count and the name shows
// it. Code that used to qdel() one piece calls loose_pile_use() instead.

// Loose pile size: code/__defines/item_piles.dm

/obj/item/var/loose_pile_max = 0

/obj/item/proc/loose_pile_update()
	if (!loose_pile_max)
		return
	amount = clamp(round(amount), 1, loose_pile_max)
	var/new_name = amount > 1 ? "[initial(name)] ([amount])" : initial(name)
	if (new_name != name)
		name = new_name
		if (isturf(loc))
			item_pile_mark(loc)

/obj/item/proc/loose_pile_can_join(obj/item/other)
	return loose_pile_max && istype(other) && other != src && other.type == type && !QDELETED(src) && !QDELETED(other) && amount < loose_pile_max

// Moves as much of other into this pile as fits; returns the number moved.
/obj/item/proc/loose_pile_add(obj/item/other)
	if (!loose_pile_can_join(other))
		return 0
	var/moved = min(other.amount, loose_pile_max - amount)
	amount += moved
	other.amount -= moved
	loose_pile_update()
	if (other.amount <= 0)
		if (ismob(other.loc))
			var/mob/M = other.loc
			M.remove_from_mob(other)
		qdel(other)
	else
		other.loose_pile_update()
	return moved

// Uses count pieces (default one) and returns how many were used; the last
// piece deletes the item. A plain item without a pile is simply used up.
/obj/item/proc/loose_pile_use(count = 1)
	if (QDELETED(src) || count <= 0)
		return 0
	if (!loose_pile_max || amount <= count)
		. = loose_pile_max ? amount : 1
		if (ismob(loc))
			var/mob/M = loc
			M.remove_from_mob(src)
		qdel(src)
		return .
	amount -= count
	loose_pile_update()
	return count

// Dropped on a pile of the same kind, it joins that pile.
/obj/item/proc/loose_pile_join_here()
	if (!loose_pile_max || !isturf(loc) || QDELETED(src) || throwing)
		return
	for (var/obj/item/I in loc)
		if (I.loose_pile_add(src) && QDELETED(src))
			return

/obj/item/proc/loose_pile_dropped()
	if (loose_pile_max)
		addtimer(CALLBACK(src, PROC_REF(loose_pile_join_here)), 1) // after it lands

// A held pile used on more of the same gathers it, and the rest of that tile's
// pile with it. Returns TRUE when it handled the click.
/obj/item/proc/loose_pile_gather(obj/item/held, mob/user)
	if (!loose_pile_max || !istype(held) || held.type != type)
		return FALSE
	var/moved = held.loose_pile_add(src)
	if (isturf(loc))
		for (var/obj/item/I in loc)
			if (I.type == type)
				moved += held.loose_pile_add(I)
	if (!moved)
		to_chat(user, SPAN_WARNING("You can't carry more than [loose_pile_max] [initial(name)] in one pile."))
	else
		to_chat(user, SPAN_NOTICE("You gather \the [initial(name)]. You now hold [held.amount]."))
	return TRUE

// A pile in the other hand: take one piece off it. Returns TRUE when handled.
/obj/item/proc/loose_pile_take_one(mob/user)
	if (!loose_pile_max || amount <= 1 || !user || user.get_inactive_hand() != src)
		return FALSE
	var/obj/item/one = new type(get_turf(user))
	amount--
	loose_pile_update()
	user.put_in_hands(one)
	to_chat(user, SPAN_NOTICE("You take one [initial(name)] from the pile."))
	return TRUE

/obj/item/proc/loose_pile_examine(mob/user)
	if (loose_pile_max && amount > 1)
		to_chat(user, "There are [amount] in the pile. Use one pile on another to gather them, or click a pile in your other hand to take one.")

// Puts count new items of path at where, filling piles already there first.
// Returns the last pile touched.
/proc/loose_pile_spawn(path, atom/where, count = 1)
	if (!ispath(path, /obj/item) || count <= 0)
		return null
	var/obj/item/proto = path
	var/max = initial(proto.loose_pile_max)
	if (!max)
		var/obj/item/last
		for (var/i in 1 to count)
			last = new path(where)
		return last
	. = null
	for (var/obj/item/I in where)
		if (count <= 0)
			break
		if (I.type != path || QDELETED(I) || I.amount >= max)
			continue
		var/add = min(count, max - I.amount)
		I.amount += add
		I.loose_pile_update()
		count -= add
		. = I
	while (count > 0)
		var/obj/item/P = new path(where)
		P.amount = min(count, max)
		P.loose_pile_update()
		count -= P.amount
		. = P
