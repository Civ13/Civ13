// Profiles are explicitly audited; unknown descendants remain unsupported.
/obj/map_metadata
	var/tmp/datum/durable_timer_queue/durable_callbacks
	var/tmp/research_clock_offset = 0

/obj/map_metadata/proc/uses_durable_metadata()
	return type in durable_nomads_profiles()

/obj/map_metadata/proc/durable_callback_names()
	return list("wind" = "wind", "religion" = "religious_timer", "tips" = "tip_process", "pollution" = "pollution", "autoresearch" = "durable_autoresearch_step", "season_loop" = "durable_season_loop", "season_phase_1" = "durable_season_phase_1", "season_phase_2" = "durable_season_phase_2", "season_phase_3" = "durable_season_phase_3", "season_phase_4" = "durable_season_phase_4", "season_phase_5" = "durable_season_phase_5", "season_phase_6" = "durable_season_phase_6", "season_phase_7" = "durable_season_phase_7", "season_phase_8" = "durable_season_phase_8", "season_phase_9" = "durable_season_phase_9")

/obj/map_metadata/proc/durable_timer_queue()
	if(!durable_callbacks)
		var/list/callbacks = durable_callback_names()
		callbacks += durable_nomads_callbacks()
		durable_callbacks = new(src, callbacks)
	return durable_callbacks

// TRUE means this profile owns the callback, including an already scheduled
// singleton. Callers must not fall back to spawning another sleeper then.
/obj/map_metadata/proc/durable_schedule(key, delay)
	if(!uses_durable_metadata()) return FALSE
	var/datum/durable_timer_queue/Q = durable_timer_queue()
	Q.schedule(key, delay)
	return TRUE

/obj/map_metadata/proc/durable_pending(key)
	return durable_callbacks && durable_callbacks.pending[key]

/obj/map_metadata/durable_callback_blocked()
	return nomads_event_busy || nomads_active_event || nomads_recovery_required || season_busy || (persistence_restart && persistence_restart.startup_hold)

/obj/map_metadata/proc/durable_cancel_season_phases()
	if(!durable_callbacks) return
	for(var/i = 1, i <= 9, i++)
		durable_callbacks.cancel("season_phase_[i]")

/obj/map_metadata/proc/durable_season_loop()
	season_loop_scheduled = FALSE
	if(!season_retired && map == src) seasons()

// Retain the existing serialized season worker rather than running terrain
// phases concurrently with another yielding transition.
/obj/map_metadata/proc/durable_enqueue_season_phase(phase)
	if(!season_worker_valid(season_epoch)) return
	season_queue += list(phase, season_epoch, FALSE, FALSE)
	season_run_queue()

/obj/map_metadata/proc/durable_season_phase_1()
	durable_enqueue_season_phase("season_phase_1")
/obj/map_metadata/proc/durable_season_phase_2()
	durable_enqueue_season_phase("season_phase_2")
/obj/map_metadata/proc/durable_season_phase_3()
	durable_enqueue_season_phase("season_phase_3")
/obj/map_metadata/proc/durable_season_phase_4()
	durable_enqueue_season_phase("season_phase_4")
/obj/map_metadata/proc/durable_season_phase_5()
	durable_enqueue_season_phase("season_phase_5")
/obj/map_metadata/proc/durable_season_phase_6()
	durable_enqueue_season_phase("season_phase_6")
/obj/map_metadata/proc/durable_season_phase_7()
	durable_enqueue_season_phase("season_phase_7")
/obj/map_metadata/proc/durable_season_phase_8()
	durable_enqueue_season_phase("season_phase_8")
/obj/map_metadata/proc/durable_season_phase_9()
	durable_enqueue_season_phase("season_phase_9")

/obj/map_metadata/proc/durable_autoresearch_step()
	if(!autoresearch || default_research >= LEGACY_RESEARCH_MAX) return
	autoresearch_step()

/obj/map_metadata/proc/research_time()
	return world.time + research_clock_offset
