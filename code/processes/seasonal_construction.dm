// Draft balance: fractions of the design's initial health per counted season.
#define CONSTRUCTION_FIBRE_SEASONS 16
#define CONSTRUCTION_EARTH_SEASONS 32
#define CONSTRUCTION_TIMBER_SEASONS 64
#define CONSTRUCTION_DECAY_BATCH 64

// Process-local clock. before_save folds unserviced transitions into each
// candidate's durable debt; after_load rebases its runtime observation clock.
var/global/construction_season_changes = 0
var/global/list/seasonal_construction = list()
var/global/seasonal_construction_cursor = 1

/obj/map_metadata
	var/tmp/construction_last_season = null

/obj/map_metadata/proc/record_construction_season_change(advance_decay)
	if (src != map || construction_last_season == season)
		return
	// Remember age-preserving forced changes too. Repeated phase callbacks
	// for the same season cannot manufacture another counted transition.
	construction_last_season = season
	if (advance_decay && persistence && !persistence_save_in_progress)
		construction_season_changes++

/obj
	var/seasonal_construction_due = 0 // Counted seasons not yet applied to health.
	var/tmp/seasonal_construction_last = 0
	var/tmp/seasonal_construction_index = 0

/obj/proc/seasonal_construction_lifetime()
	// Exact designs only, never an inherited Wood/material or world-year rule.
	// Automatic paired slabs use generic wood roofs even under modern floors.
	if (istype(src, /obj/roof))
		var/obj/roof/R = src
		if (R.building_pair_id)
			return 0
	switch (type)
		if (/obj/covers/straw_wall, /obj/roof/thatch, /obj/roof/palm)
			return CONSTRUCTION_FIBRE_SEASONS
		if (/obj/covers/dirt_wall)
			return CONSTRUCTION_EARTH_SEASONS
		if (/obj/covers/wood_wall, /obj/covers/wood_wall/bamboo, /obj/covers/wood_wall/log, /obj/roof/wood)
			return CONSTRUCTION_TIMBER_SEASONS
	return 0

/obj/proc/register_seasonal_construction()
	if (gc_destroyed || gcDestroyed || seasonal_construction_index || !seasonal_construction_lifetime())
		return
	seasonal_construction += src
	seasonal_construction_index = seasonal_construction.len
	seasonal_construction_last = construction_season_changes

/obj/proc/unregister_seasonal_construction()
	var/index = seasonal_construction_index
	if (!index)
		return
	var/obj/last = seasonal_construction[seasonal_construction.len]
	seasonal_construction[index] = last
	last.seasonal_construction_index = index
	seasonal_construction.Cut(seasonal_construction.len, seasonal_construction.len + 1)
	seasonal_construction_index = 0

/obj/proc/seasonal_construction_exposed()
	return anchored && isturf(loc) && !gc_destroyed && !gcDestroyed

/obj/covers/seasonal_construction_exposed()
	return wall && !incomplete && ..()

/obj/proc/accrue_seasonal_construction()
	// Only this mode's transitions increment the clock. No hourly fallback.
	var/elapsed = max(0, construction_season_changes - seasonal_construction_last)
	seasonal_construction_last = construction_season_changes
	if (map && seasonal_construction_lifetime() && seasonal_construction_exposed())
		seasonal_construction_due += elapsed

/obj/proc/seasonal_construction_health()
	return 0

/obj/covers/seasonal_construction_health()
	return health

/obj/roof/seasonal_construction_health()
	return health

/obj/proc/seasonal_construction_design_health()
	return 0

/obj/covers/seasonal_construction_design_health()
	return initial(health)

/obj/roof/seasonal_construction_design_health()
	return initial(health)

/obj/proc/damage_seasonal_construction(damage)
	return

/obj/covers/damage_seasonal_construction(damage)
	health -= damage
	if (health <= 0)
		visible_message(SPAN_WARNING("The [name] falls apart from seasonal weathering!"))
		qdel(src)

/obj/roof/damage_seasonal_construction(damage)
	health -= damage
	if (health <= 0)
		visible_message(SPAN_WARNING("The [name] falls apart from seasonal weathering!"))
		qdel(src)

/obj/proc/check_seasonal_construction()
	if (persistence_save_in_progress)
		return
	if (gc_destroyed || gcDestroyed)
		unregister_seasonal_construction()
		return
	accrue_seasonal_construction()
	if (!map || !map.persistence || !seasonal_construction_exposed())
		return
	var/lifetime = seasonal_construction_lifetime()
	if (!lifetime)
		unregister_seasonal_construction()
		return
	if (seasonal_construction_due <= 0)
		return
	var/damage = seasonal_construction_design_health() * seasonal_construction_due / lifetime
	// Occupants/items do not postpone seasonal collapse; normal destruction
	// owns contained atoms and any support-loss consequences.
	// Debit debt before normal qdel hooks; no sleep or direct Destroy call.
	seasonal_construction_due = 0
	damage_seasonal_construction(damage)

/obj/persistence_runtime_var(key)
	if (key == "seasonal_construction_last" || key == "seasonal_construction_index")
		return TRUE
	return ..()

/obj/covers/before_save()
	if (seasonal_construction_index)
		accrue_seasonal_construction()
	return ..()

/obj/roof/before_save()
	if (seasonal_construction_index)
		accrue_seasonal_construction()
	return ..()

/obj/covers/after_load()
	..()
	unregister_seasonal_construction()
	register_seasonal_construction()

/obj/roof/after_load()
	..()
	unregister_seasonal_construction()
	register_seasonal_construction()

/process/seasonal_construction/setup()
	name = "seasonal construction deterioration"
	schedule_interval = 10 SECONDS
	start_delay = 10 SECONDS
	priority = PROCESS_PRIORITY_LOW
	fires_at_gamestates = list(GAME_STATE_PLAYING)
	processes.seasonal_construction = src

/process/seasonal_construction/fire()
	if (persistence_save_in_progress || !map || !map.persistence)
		return
	var/checks = min(CONSTRUCTION_DECAY_BATCH, seasonal_construction.len)
	while (checks-- > 0 && seasonal_construction.len)
		if (seasonal_construction_cursor > seasonal_construction.len)
			seasonal_construction_cursor = 1
		var/obj/O = seasonal_construction[seasonal_construction_cursor]
		var/index = seasonal_construction_cursor
		O.check_seasonal_construction()
		if (O && O.seasonal_construction_index == index)
			seasonal_construction_cursor++
		if (world.tick_usage >= 20)
			return

/process/seasonal_construction/reset_current_list()
	return // Registry cursor only; no world scans, snapshots or object timers.
