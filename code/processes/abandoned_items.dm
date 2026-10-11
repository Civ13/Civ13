// Active server elapsed time in deciseconds, unrelated to day/night or seasons.
#define ABANDONED_ITEM_WARNING (5 * 24 * 60 * 60 * 10)
#define ABANDONED_ITEM_LIFETIME (7 * 24 * 60 * 60 * 10)
#define ABANDONED_ITEM_BATCH 256

var/global/list/abandoned_items = list()
var/global/abandoned_item_cursor = 1

/obj/item
	// Explicit opt-in. Do not enable at the item root or broad useful-gear parents.
	var/abandonment_decay = FALSE
	var/tmp/abandonment_index = 0
	var/tmp/abandonment_since = null
	var/tmp/abandonment_location = null // ref text, never a retained location datum

/obj/item/trash
	abandonment_decay = TRUE
/obj/item/trash/money
	abandonment_decay = FALSE
/obj/item/trash/tray
	abandonment_decay = FALSE
/obj/item/trash/candle
	abandonment_decay = FALSE

/obj/item/ammo_casing
	abandonment_decay = TRUE

/obj/item/ammo_casing/is_abandonment_waste()
	// Arrows/bolts/balls are recoverable ammunition, even without a loaded BB.
	return abandonment_decay && spent_icon && !BB

/obj/item/proc/is_abandonment_waste()
	return abandonment_decay

/obj/item/proc/register_abandoned_item()
	if (!is_abandonment_waste() || gcDestroyed || abandonment_index)
		return
	abandoned_items += src
	abandonment_index = abandoned_items.len
	reset_abandonment()

/obj/item/proc/unregister_abandoned_item()
	var/index = abandonment_index
	if (!index)
		return
	var/obj/item/last = abandoned_items[abandoned_items.len]
	abandoned_items[index] = last
	last.abandonment_index = index
	abandoned_items.Cut(abandoned_items.len, abandoned_items.len + 1)
	abandonment_index = 0
	abandonment_since = null
	abandonment_location = null

/obj/item/proc/reset_abandonment()
	abandonment_since = null
	abandonment_location = null

/obj/item/Del()
	unregister_abandoned_item()
	return ..()

/obj/item/Move()
	. = ..()
	if (.)
		reset_abandonment()

/obj/item/forceMove(atom/destination, special_event)
	. = ..()
	if (.)
		reset_abandonment()

/obj/item/persistence_runtime_var(key)
	if (key == "abandonment_index" || key == "abandonment_since" || key == "abandonment_location")
		return TRUE
	return ..()

/obj/item/after_load()
	..()
	// A restored item always gets a fresh recovery window. No prior world.time
	// or scheduler slot is meaningful in this runtime.
	reset_abandonment()
	register_abandoned_item()

/obj/item/proc/abandonment_protected()
	if (anchored || nodrop || abstract || contents.len || pulledby || throwing)
		return TRUE
	var/atom/container = loc
	var/protected = FALSE
	for (var/depth = 1, depth <= 64, depth++)
		if (!container || container.gcDestroyed)
			return TRUE // nullspace/pending deletion is never a disposal target
		if (ismob(container))
			return TRUE // direct, nested and equipped inventories, including corpses
		if (isturf(container))
			return protected
		if (istype(container, /obj/item/weapon/storage))
			protected = TRUE
		else if (istype(container, /obj/structure/closet))
			var/obj/structure/closet/C = container
			if (!C.opened)
				protected = TRUE
		// Arbitrary objects, magazines and fake containers do not confer storage.
		container = container.loc
	return TRUE // pathological containment depth: conservative, bounded traversal

/obj/item/proc/check_abandonment(now)
	if (gcDestroyed)
		unregister_abandoned_item()
		return FALSE
	if (!is_abandonment_waste())
		unregister_abandoned_item()
		return FALSE
	if (abandonment_protected())
		reset_abandonment()
		return FALSE
	var/location_key = "\ref[loc]"
	if (isnull(abandonment_since) || abandonment_location != location_key || now < abandonment_since)
		abandonment_since = now
		abandonment_location = location_key
		return FALSE
	if (now - abandonment_since >= ABANDONED_ITEM_LIFETIME)
		// No sleep between final eligibility check and qdel. Never delete children.
		qdel(src)
		return TRUE
	return FALSE

/obj/item/proc/abandonment_notice()
	if (!isnull(abandonment_since) && abandonment_location == "\ref[loc]" && is_abandonment_waste() && !abandonment_protected() && world.time - abandonment_since >= ABANDONED_ITEM_WARNING)
		return " It is badly weathered and will crumble away after seven days of abandonment. Pick it up or store it to preserve it."
	return ""

/process/abandoned_items/setup()
	name = "abandoned item decay"
	schedule_interval = 30 SECONDS
	start_delay = 10 SECONDS
	priority = PROCESS_PRIORITY_LOW
	fires_at_gamestates = list(GAME_STATE_PLAYING)
	processes.abandoned_items = src

/process/abandoned_items/fire()
	var/checks = min(ABANDONED_ITEM_BATCH, abandoned_items.len)
	while (checks-- > 0 && abandoned_items.len)
		if (abandoned_item_cursor > abandoned_items.len)
			abandoned_item_cursor = 1
		var/obj/item/I = abandoned_items[abandoned_item_cursor]
		var/index = abandoned_item_cursor
		I.check_abandonment(world.time)
		if (I && I.abandonment_index == index)
			abandoned_item_cursor++

/process/abandoned_items/reset_current_list()
	return // Never copy or retain a second candidate list.
