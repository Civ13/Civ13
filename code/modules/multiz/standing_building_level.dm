// A map with building_level_standing keeps its open-air building level from
// the start of every round instead of growing it with the first roof. Aircraft
// fly on it, and no isolated instance can take the level above the surface.
// The level is the same sparse, lazily lit plane a roof would add (about 1 MB
// and a quarter of a second since #3898), so an empty one costs almost nothing.
//
// It is added only once the startup import has settled: a restore compares
// the saved level count with world.maxz, so adding a level while an older
// save is still waiting to load would refuse that save. A failed import is
// left alone for the same reason, so an admin can still load a backup.
/obj/map_metadata/var/building_level_standing = FALSE

#define BUILDING_STANDING_POLL (5 SECONDS)

var/global/building_standing_watch = FALSE

/proc/building_standing_wanted()
	return map && map.building_level_standing && map.building_levels && !dug_underground_supported()

// TRUE once the level exists; FALSE while waiting or after a refusal.
/proc/building_standing_present()
	return world.maxz > building_base_maxz()

/proc/building_standing_ready()
	if (!ticker || persistence_save_in_progress || building_allocating_z)
		return FALSE
	if (persistence_restart && persistence_restart.startup_hold)
		return FALSE
	// "pending" = the startup import is still running; "unresolved" = it failed.
	if (persistence_startup_recovery_status)
		return FALSE
	return (map_storage && map_storage.round_restored) || ticker.current_state == GAME_STATE_PLAYING

/proc/building_standing_try()
	if (!map)
		return FALSE // Map metadata is not chosen yet.
	if (!building_standing_wanted() || building_standing_present())
		return TRUE
	if (!building_standing_ready())
		return FALSE
	if (building_allocate_level(world.maxz + 1))
		world.log << "Standing building level [world.maxz] added above the surface."
		return TRUE
	world.log << "Standing building level refused: [world_z_budget.last_error]"
	return TRUE // A refusal is final for this round; roofs keep the old path.

/proc/building_standing_watch_loop()
	set waitfor = FALSE
	if (building_standing_watch)
		return
	building_standing_watch = TRUE
	while (!building_standing_try())
		sleep(BUILDING_STANDING_POLL)
	building_standing_watch = FALSE

/hook/startup/proc/building_standing_level()
	building_standing_watch_loop()
	return TRUE

#undef BUILDING_STANDING_POLL
