// Pacing for seasonal weathering: shelter and foundations slow it, one
// service never takes a building through more than one warning band, worn
// walls show cracks and a wall at the end of its life stands on as a ruin
// that holds nothing up before it crumbles away.
// Nothing here is saved: bands, cracks and ruins are derived from health.

/obj
	var/tmp/seasonal_construction_paced_at = -1 // Season step of the last band entered.
	var/tmp/seasonal_construction_ruin_told = FALSE

/obj/persistence_runtime_var(key)
	if (key == "seasonal_construction_paced_at" || key == "seasonal_construction_ruin_told")
		return TRUE
	return ..()

// Share of the plain weathering rate this building takes.
/obj/proc/seasonal_construction_rate()
	return 1

// A wall under the eaves of a roof and a wall on a foundation each weather a
// quarter slower.
/obj/covers/seasonal_construction_rate()
	var/rate = 1
	if (locate(/obj/roof) in range(1, src))
		rate -= 0.25
	if (building_founded(src))
		rate -= 0.25
	return rate

// Counted seasons a sound building of this kind lasts where it stands.
/obj/proc/seasonal_construction_span()
	var/lifetime = seasonal_construction_lifetime()
	var/rate = seasonal_construction_rate()
	return lifetime && rate > 0 ? lifetime / rate : 0

// Seasons of health left, before any unpaid debt. Negative for a ruin.
/obj/proc/seasonal_construction_reserve()
	var/span = seasonal_construction_span()
	var/design = seasonal_construction_design_health()
	if (!span || design <= 0)
		return null
	return seasonal_construction_health() * span / design

// The lowest reserve of the warning band that holds this reserve: sound,
// last year, last season, ruin.
/obj/proc/seasonal_construction_band_floor(reserve)
	if (reserve > CONSTRUCTION_WARNING_SEASONS + 0.001)
		return CONSTRUCTION_WARNING_SEASONS
	if (reserve > 1.001)
		return 1
	if (reserve > 0.001)
		return 0
	return -CONSTRUCTION_RUIN_SEASONS

// Turns the plain damage of a service into what this building takes now. A
// service that would pass a band boundary stops on it and keeps the rest as
// debt, and a second boundary waits for the next season step, so a backlog
// after a long absence still gives both warnings before anything falls.
/obj/proc/seasonal_construction_paced(damage)
	var/lifetime = seasonal_construction_lifetime()
	var/design = seasonal_construction_design_health()
	var/reserve = seasonal_construction_reserve()
	if (!lifetime || design <= 0 || isnull(reserve))
		return damage
	var/seasons = damage * lifetime / design
	var/span = seasonal_construction_span()
	var/floor = seasonal_construction_band_floor(reserve)
	if (seasons < reserve - floor - 0.001)
		return seasons * design / span
	if (seasonal_construction_paced_at == construction_season_changes)
		seasonal_construction_due += seasons
		return 0
	seasonal_construction_paced_at = construction_season_changes
	seasonal_construction_due += max(0, seasons - (reserve - floor))
	// Land exactly on the boundary, so a last season always ends at zero.
	return seasonal_construction_health() - floor * design / span

/obj/proc/seasonal_construction_ruined()
	return FALSE

/obj/covers/seasonal_construction_ruined()
	return wall && health <= 0 && seasonal_construction_lifetime() > 0

// A wall at the end of its life. TRUE while the ruin still stands.
/obj/covers/proc/seasonal_construction_ruin()
	var/reserve = seasonal_construction_reserve()
	if (isnull(reserve) || reserve <= 0.001 - CONSTRUCTION_RUIN_SEASONS)
		return FALSE
	if (!seasonal_construction_ruin_told)
		seasonal_construction_ruin_told = TRUE
		visible_message(SPAN_DANGER("\The [src] crumbles into a ruin. It holds nothing up any more."))
		seasonal_construction_stage()
		// What it carried sags first and falls only if nobody props it up.
		for (var/obj/roof/R in range(2, src))
			R.collapse_check(TRUE)
	return TRUE

// Cracks follow health: half worn, three quarters worn, last year. Reuses
// the wall crack overlays; a ruin keeps the deepest cracks and says so.
/obj/covers/proc/seasonal_construction_stage()
	if (!wall || !seasonal_construction_lifetime())
		return
	var/design = seasonal_construction_design_health()
	var/reserve = seasonal_construction_reserve()
	if (design <= 0 || isnull(reserve))
		return
	var/stage = 0
	if (reserve <= CONSTRUCTION_WARNING_SEASONS + 0.001)
		stage = 3
	else if (health <= design * 0.25)
		stage = 2
	else if (health <= design * 0.5)
		stage = 1
	var/ruin_name = "ruined [initial(name)]"
	if (seasonal_construction_ruined())
		if (name == initial(name))
			name = ruin_name
	else
		seasonal_construction_ruin_told = FALSE
		if (name == ruin_name)
			name = initial(name)
	if (cracked != stage)
		cracked = stage
		update_icon()

/obj/covers/seasonal_construction_warn(damage)
	..()
	seasonal_construction_stage()
