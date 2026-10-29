// Fallback elapsed server time for maps without an active seasonal cycle.
#define ABANDONED_ITEM_WARNING (6 * 60 * 60 * 10)
#define ABANDONED_ITEM_LIFETIME (12 * 60 * 60 * 10)
#define ABANDONED_ITEM_SEASON_WARNING 2
#define ABANDONED_ITEM_SEASON_LIFETIME 4
#define ABANDONED_ITEM_BATCH 256

var/global/abandonment_season_changes = 0

/obj/map_metadata
	var/abandonment_season_cycle = FALSE
	var/abandonment_season_autonomous = FALSE

/obj/map_metadata/proc/abandonment_uses_seasons()
	if (!abandonment_season_cycle)
		return FALSE
	if (abandonment_season_autonomous)
		return TRUE
	return config && config.seasons_on && (season == "SPRING" || season == "SUMMER" || season == "FALL" || season == "WINTER")

/proc/season_decay_requested(force, advance_decay)
	// Natural cycles age debris. Forced calls preserve it unless explicitly opted in.
	return isnull(advance_decay) ? !force : advance_decay

/obj/map_metadata/proc/record_abandonment_season_change(advance_decay = TRUE)
	if (advance_decay && src == map)
		abandonment_season_changes++
	record_construction_season_change(advance_decay)

/obj/item/proc/abandonment_uses_seasons()
	if (!map)
		return FALSE
	return map.abandonment_uses_seasons()

var/global/list/abandoned_items = list()
var/global/abandoned_item_cursor = 1

/obj/item
	// Explicit opt-in. Do not enable at the item root or broad useful-gear parents.
	var/abandonment_decay = FALSE
	var/tmp/abandonment_season_since = null
	var/tmp/abandonment_seasonal = FALSE
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
	abandonment_season_since = null
	abandonment_seasonal = FALSE
	abandonment_location = null

/obj/item/proc/reset_abandonment()
	abandonment_since = null
	abandonment_season_since = null
	abandonment_seasonal = FALSE
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
	// Constructor/Life-owned UI graphs must not be overwritten by the null
	// references used for unsaved /datum/action entries, including legacy saves.
	if (key == "actions" || key == "action")
		return TRUE
	if (key == "abandonment_index" || key == "abandonment_since" || key == "abandonment_location" || key == "abandonment_season_since" || key == "abandonment_seasonal")
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
		else if (istype(src, /obj/item/ammo_casing) && (istype(container, /obj/item/ammo_magazine) || istype(container, /obj/item/weapon/gun)))
			protected = TRUE // Native ammunition storage/chambers preserve spent cases.
		else if (istype(container, /obj/structure/closet))
			var/obj/structure/closet/C = container
			if (!C.opened)
				protected = TRUE
		// Arbitrary objects and fake containers do not confer storage.
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
	var/seasonal = abandonment_uses_seasons()
	var/location_key = "\ref[loc]"
	if (isnull(abandonment_since) || abandonment_location != location_key || now < abandonment_since || seasonal != abandonment_seasonal || (seasonal && abandonment_season_changes < abandonment_season_since))
		abandonment_seasonal = seasonal
		abandonment_season_since = abandonment_season_changes
		abandonment_since = now
		abandonment_location = location_key
		return FALSE
	if (seasonal ? abandonment_season_changes - abandonment_season_since >= ABANDONED_ITEM_SEASON_LIFETIME : now - abandonment_since >= ABANDONED_ITEM_LIFETIME)
		// No sleep between final eligibility check and qdel. Never delete children.
		qdel(src)
		return TRUE
	return FALSE

/obj/item/proc/abandonment_notice()
	if (isnull(abandonment_since) || abandonment_location != "\ref[loc]" || !is_abandonment_waste() || abandonment_protected() || abandonment_seasonal != abandonment_uses_seasons())
		return ""
	if (abandonment_seasonal)
		if (abandonment_season_changes - abandonment_season_since >= ABANDONED_ITEM_SEASON_WARNING)
			return " It is badly weathered and will crumble away after four season changes of abandonment. Pick it up or store it to preserve it."
	else if (world.time - abandonment_since >= ABANDONED_ITEM_WARNING)
		return " It is badly weathered and will crumble away after 12 hours of abandonment. Pick it up or store it to preserve it."
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
