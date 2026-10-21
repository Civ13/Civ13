// Uncalibrated allocation throttle, not a byte limit or an OOM guarantee.
// Each new z allocates the full native world plane, including unused sky.
#define NEW_Z_CELL_CEILING 1400000
#define NEW_Z_ROOF_CEILING 1

var/datum/world_z_budget/world_z_budget = new

/proc/new_z_integer(value, maximum)
	return isnum(value) && value >= 0 && value <= maximum && value == round(value)

// Pure prospective check: large-map cases need no native grid allocation.
/proc/new_z_grid_error(width, height, current_z, base_z, target_z, purpose, cell_limit, roof_limit, instance_reserve, safehouse_reserve, instance_used = 0, safehouse_used = 0)
	if (!new_z_integer(width, NEW_Z_CELL_CEILING) || !width || !new_z_integer(height, NEW_Z_CELL_CEILING) || !height || !new_z_integer(current_z, BUILDING_MAX_Z) || !current_z || !new_z_integer(base_z, BUILDING_MAX_Z) || !base_z || base_z > current_z || !new_z_integer(target_z, BUILDING_MAX_Z) || target_z < current_z)
		return "Invalid or unsupported world dimensions; no level was allocated."
	if (!(purpose in list("roof", "restore", "instance", "safehouse")))
		return "Unknown level purpose; no level was allocated."
	if (!new_z_integer(cell_limit, NEW_Z_CELL_CEILING) || !new_z_integer(roof_limit, NEW_Z_ROOF_CEILING) || !new_z_integer(instance_reserve, BUILDING_EXTRA_LEVELS) || !new_z_integer(safehouse_reserve, BUILDING_EXTRA_LEVELS) || !new_z_integer(instance_used, instance_reserve) || !new_z_integer(safehouse_used, safehouse_reserve))
		return "Invalid level budget configuration; no level was allocated."
	if (target_z == current_z)
		return null // Existing worlds need no growth admission or truncation.
	if (target_z > base_z + BUILDING_EXTRA_LEVELS)
		return "The world has reached its added-level ceiling; no level was allocated."
	if (purpose == "roof" && target_z > base_z + roof_limit)
		return "This map permits at most [roof_limit] roof-added level(s); no level was allocated."
	var/added = target_z - current_z
	if (purpose == "instance" && added > instance_reserve - instance_used)
		return "No configured instance reservation covers these [added] whole level(s)."
	if (purpose == "safehouse" && added > safehouse_reserve - safehouse_used)
		return "No configured safehouse reservation covers these [added] whole level(s)."
	var/pending_instance = instance_reserve - instance_used - (purpose == "instance" ? added : 0)
	var/pending_safehouse = safehouse_reserve - safehouse_used - (purpose == "safehouse" ? added : 0)
	var/charged_levels = target_z + pending_instance + pending_safehouse
	if (charged_levels > BUILDING_MAX_Z || charged_levels > base_z + BUILDING_EXTRA_LEVELS)
		return "Requested and reserved whole levels exceed the structural level ceiling."
	// Bound the plane before multiplying (at most 1400000, exactly representable).
	// Compare levels using one division rather than two rounded divisions.
	var/exceeds_budget = !cell_limit || width > cell_limit / height
	if (!exceeds_budget)
		exceeds_budget = charged_levels > cell_limit / (width * height)
	if (exceeds_budget)
		return "Level budget refused: [width] x [height] x [target_z] requested, plus [pending_instance + pending_safehouse] reserved level(s); ceiling [cell_limit] total cells. Preserve existing saves; a reviewed recovery/profile change is required."
	return null

/proc/new_z_dimension_variable(key)
	return istext(key) && (lowertext(key) in list("maxx", "maxy", "maxz"))

/datum/new_z_reservation
	should_save = FALSE
	var/purpose
	var/start_z
	var/target_z
	var/next_z
	var/width
	var/height
	var/started = FALSE
	var/failed = FALSE

/datum/world_z_budget
	should_save = FALSE
	var/cell_limit = NEW_Z_CELL_CEILING
	var/roof_limit = NEW_Z_ROOF_CEILING
	var/instance_reserve = 0
	var/safehouse_reserve = 0
	var/instance_used = 0
	var/safehouse_used = 0
	var/base_width = 0
	var/base_height = 0
	var/base_z = 0
	var/datum/new_z_reservation/active
	var/last_error

/datum/world_z_budget/proc/record_compiled_dimensions()
	if (!base_z)
		base_width = world.maxx
		base_height = world.maxy
		base_z = building_base_maxz()

// Grid arithmetic is not a measurement of free heap or save/player headroom.
// There is no calibrated production profile yet, and no config opt-out.
// A future positive implementation requires separately reviewed evidence.
/datum/world_z_budget/proc/memory_admission_error(target_z, purpose)
	return "UNMEASURED: new levels are disabled until this map has a validated memory/headroom profile. Existing planes remain usable. Preserve saves and request a reviewed profile; no level was allocated."

// Config values are decimal integers and can lower, never raise, the ceiling.
// While an admitted interval is initializing, its policy is immutable.
/datum/world_z_budget/proc/configure(name, value)
	if (active || !istext(value) || !length(value) || length(value) > 12)
		return FALSE
	for (var/i = 1 to length(value))
		var/c = text2ascii(value, i)
		if (c < 48 || c > 57)
			return FALSE
	var/amount = text2num(value)
	if (name == "new_z_cell_budget" && new_z_integer(amount, NEW_Z_CELL_CEILING))
		cell_limit = amount
	else if (name == "new_z_roof_levels" && new_z_integer(amount, NEW_Z_ROOF_CEILING))
		roof_limit = amount
	else if (name == "new_z_instance_reserve" && new_z_integer(amount, BUILDING_EXTRA_LEVELS) && amount >= instance_used)
		instance_reserve = amount
	else if (name == "new_z_safehouse_reserve" && new_z_integer(amount, BUILDING_EXTRA_LEVELS) && amount >= safehouse_used)
		safehouse_reserve = amount
	else
		return FALSE
	return TRUE

/datum/world_z_budget/proc/error(target_z, purpose, datum/new_z_reservation/owner)
	if (active && active != owner)
		return "Another level request owns allocation; try again shortly."
	var/owns_recovery = owner && owner == active && map_storage && map_storage.dimension_bootstrap_busy && map_storage.dimension_reservation == owner && purpose == "restore"
	if (building_allocating_z || (map_storage && (map_storage.dimension_budget_hold || (map_storage.dimension_recovery_required && !owns_recovery))) || (persistence_save_in_progress && purpose != "restore"))
		return "Level allocation is unavailable during saving or incomplete recovery."
	if (purpose == "restore" && !persistence_save_in_progress)
		return "Saved levels require an admitted persistence operation."
	record_compiled_dimensions()
	if (base_width != world.maxx || base_height != world.maxy)
		return "World geometry changed after startup; restart from the original map."
	var/in_progress = owner && owner == active ? world.maxz - owner.start_z : 0
	var/charged_instance = instance_used + (purpose == "instance" ? in_progress : 0)
	var/charged_safehouse = safehouse_used + (purpose == "safehouse" ? in_progress : 0)
	var/grid_error = new_z_grid_error(world.maxx, world.maxy, world.maxz, base_z, target_z, purpose, cell_limit, roof_limit, instance_reserve, safehouse_reserve, charged_instance, charged_safehouse)
	if (grid_error || target_z == world.maxz)
		return grid_error
	return memory_admission_error(target_z, purpose)

// No sleeps, input, callbacks or tick checks between admission and publication.
/datum/world_z_budget/proc/reserve(target_z, purpose)
	last_error = error(target_z, purpose)
	if (last_error || target_z <= world.maxz)
		return null
	var/datum/new_z_reservation/R = new
	R.purpose = purpose
	R.start_z = world.maxz
	R.next_z = world.maxz + 1
	R.target_z = target_z
	R.width = world.maxx
	R.height = world.maxy
	active = R
	return R

// Recheck the whole target after any prospective-save validation yields.
// The caller sets its busy flag and resizes immediately after this returns.
/datum/world_z_budget/proc/claim_level(datum/new_z_reservation/R, target_z)
	if (!R || active != R || R.failed || R.next_z != target_z || target_z != world.maxz + 1 || target_z > R.target_z || R.width != world.maxx || R.height != world.maxy)
		last_error = "Level reservation is stale; no level was allocated."
		return FALSE
	last_error = error(R.target_z, R.purpose, R)
	if (last_error)
		return FALSE
	R.started = TRUE
	R.next_z++
	return TRUE

/datum/world_z_budget/proc/finish(datum/new_z_reservation/R, success)
	if (!R || active != R)
		return FALSE
	if (success && !R.failed && world.maxz == R.target_z && R.next_z == R.target_z + 1)
		if (R.purpose == "instance")
			instance_used += R.target_z - R.start_z
		if (R.purpose == "safehouse")
			safehouse_used += R.target_z - R.start_z
		active = null
		return TRUE
	if (R.started)
		R.failed = TRUE // Native growth cannot be safely undone; restart required.
	else
		active = null
	return FALSE
