#define SOIL_RECOVERY_BATCH 512
// Dirt turfs whose soil nutrition is below the maximum. Full turfs are not
// registered, so the registry stays small; see /turf/floor/dirt in
// code/game/turfs/flooring/flooring_premade.dm for registration.
var/global/list/soil_recovery_pending = list()
var/global/soil_recovery_cursor = 1

/process/soil_recovery/setup()
	name = "soil nutrition recovery"
	schedule_interval = 5 SECONDS
	start_delay = 5 SECONDS
	priority = PROCESS_PRIORITY_LOW
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	processes.soil_recovery = src

/process/soil_recovery/fire()
	var/checks = min(SOIL_RECOVERY_BATCH, soil_recovery_pending.len)
	while (checks-- > 0 && soil_recovery_pending.len)
		if (soil_recovery_cursor > soil_recovery_pending.len)
			soil_recovery_cursor = 1
		var/index = soil_recovery_cursor
		var/turf/floor/dirt/D = soil_recovery_pending[index]
		if (!istype(D))
			soil_recovery_pending.Cut(index, index + 1)
			continue
		if (!isnull(D.soil_recovery_deadline) && world.time >= D.soil_recovery_deadline)
			D.soil_nutrition_recover()
		if (D.soil_recovery_index == index)
			soil_recovery_cursor++

/process/soil_recovery/reset_current_list()
	return // No copied candidate list or per-turf sleeping callback.
