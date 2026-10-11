#define DECAL_DECAY_BATCH 256
var/global/list/timed_cleanables = list()
var/global/timed_cleanable_cursor = 1

/process/decal_decay/setup()
	name = "timed decal decay"
	schedule_interval = 1 SECOND
	start_delay = 1 SECOND
	priority = PROCESS_PRIORITY_LOW
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	processes.decal_decay = src

/process/decal_decay/fire()
	var/checks = min(DECAL_DECAY_BATCH, timed_cleanables.len)
	while (checks-- > 0 && timed_cleanables.len)
		if (timed_cleanable_cursor > timed_cleanables.len)
			timed_cleanable_cursor = 1
		var/obj/effect/decal/cleanable/C = timed_cleanables[timed_cleanable_cursor]
		var/index = timed_cleanable_cursor
		if (C.gcDestroyed)
			C.unregister_decay()
		else if (!isnull(C.decay_deadline) && world.time >= C.decay_deadline)
			qdel(C)
		if (C && C.decay_index == index)
			timed_cleanable_cursor++

/process/decal_decay/reset_current_list()
	return // No copied candidate list or per-decal sleeping callback.
