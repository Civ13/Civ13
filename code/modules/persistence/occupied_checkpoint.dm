// Four-hour checkpoint for occupied persistent worlds (Val, 2026-11-21):
// "We want to save at least once every 4 hours to prevent losing progress,
// even when players are on." Design: docs/occupied-region-checkpoints.md.
//
// The age comes from the last completed save's stamp (last_save_status.dm), so
// a restart or handover never makes an old save look fresh, and any completed
// save (manual, vote, idle or empty catch-up) resets the deadline. A failed or
// refused checkpoint backs off without moving the deadline. Save only: this
// never restarts or updates the world.

#define PERSISTENCE_CHECKPOINT_TARGET 144000 // four hours, in deciseconds
#define PERSISTENCE_CHECKPOINT_LEAD 12000 // start at least 20 minutes before the target
#define PERSISTENCE_CHECKPOINT_STAGGER 600 // plus 0-9 minutes per region (by port)
#define PERSISTENCE_CHECKPOINT_WARNING 1200 // two minutes' warning in chat
#define PERSISTENCE_CHECKPOINT_BACKOFF 9000 // 15 minutes after a failed or refused attempt

var/global/list/persistence_checkpoint_baseline = null
var/global/persistence_checkpoint_retry_at = 0
var/global/persistence_checkpoint_running = FALSE
var/global/persistence_checkpoint_overdue_reported = FALSE

// Age at which this region starts its checkpoint. A stable per-port offset keeps
// regions that saved together from all starting at once.
/proc/persistence_checkpoint_due(port = world.port)
	return PERSISTENCE_CHECKPOINT_TARGET - PERSISTENCE_CHECKPOINT_LEAD - (max(0, round(port)) % 10) * PERSISTENCE_CHECKPOINT_STAGGER

// Wall-clock age of the last completed save. A world with no stamped save counts
// from the first time the checkpoint looked, which is the first playable loop.
/proc/persistence_checkpoint_age(now_timeofday = world.timeofday, now_realtime = world.realtime)
	persistence_last_save_refresh()
	var/list/stamp = persistence_last_save ? persistence_last_save["stamp"] : null
	if(valid_persistence_save_stamp(stamp))
		return wall_clock_elapsed(stamp["timeofday"], stamp["realtime"], now_timeofday, now_realtime)
	if(!persistence_checkpoint_baseline)
		persistence_checkpoint_baseline = list("timeofday" = now_timeofday, "realtime" = now_realtime)
	return wall_clock_elapsed(persistence_checkpoint_baseline["timeofday"], persistence_checkpoint_baseline["realtime"], now_timeofday, now_realtime)

// Why a checkpoint cannot start now, or null.
/proc/persistence_checkpoint_block_reason()
	if(config.skip_persistence_saving) return "saving is disabled"
	if(!map || !map.persistence) return "not a persistent world"
	if(!ticker || ticker.current_state < GAME_STATE_PLAYING) return "the round is not playing"
	if(persistence_restart.startup_hold || persistence_restart.busy) return "a restart or handover is in progress"
	if(persistence_reboot_scheduled) return "a maintenance reboot is scheduled"
	if(persistence_admission_blocked() || persistence_save_active()) return "another save or load is running"
	return null

// Called by the persistence loop (world.dm) every 30 seconds while players are online.
/proc/persistence_occupied_checkpoint()
	if(persistence_checkpoint_running || world.time < persistence_checkpoint_retry_at) return FALSE
	if(persistence_checkpoint_block_reason()) return FALSE
	var/age = persistence_checkpoint_age()
	if(age < persistence_checkpoint_due()) return FALSE
	if(age >= PERSISTENCE_CHECKPOINT_TARGET && !persistence_checkpoint_overdue_reported)
		persistence_checkpoint_overdue_reported = TRUE
		message_admins("The last completed world save is over four hours old; a checkpoint save is starting.")
	persistence_checkpoint_running = TRUE
	persistence_run_checkpoint()
	return TRUE

/proc/persistence_run_checkpoint()
	set waitfor = FALSE // the loop carries on while the warning and save run
	to_chat(world, "<font color='yellow' size=4><b>The world will be saved in about two minutes to keep everyone's progress safe. The game may pause briefly while it saves.</b></font>")
	sleep(PERSISTENCE_CHECKPOINT_WARNING)
	if(!persistence_checkpoint_block_reason() && persistence_checkpoint_age() >= persistence_checkpoint_due())
		persistence_wait_for_safe_vehicle_state()
	var/saved = FALSE
	var/block = persistence_checkpoint_block_reason()
	if(!block && persistence_checkpoint_age() < persistence_checkpoint_due())
		// Another save finished during the warning; the deadline already moved.
		to_chat(world, "<font color='yellow'><b>The world was already saved; the checkpoint save is not needed.</b></font>")
		persistence_checkpoint_retry_at = 0
		persistence_checkpoint_running = FALSE
		return
	if(!block)
		log_game("Four-hour checkpoint save started with players online.")
		saved = ticker.savemap()
	if(saved)
		nextsave = world.realtime + 216000
		persistence_checkpoint_overdue_reported = FALSE
		persistence_checkpoint_retry_at = 0
	else
		persistence_checkpoint_retry_at = world.time + PERSISTENCE_CHECKPOINT_BACKOFF
		message_admins("The four-hour checkpoint save did not complete ([block ? block : "the save failed"]). It is tried again in 15 minutes.")
		to_chat(world, "<font color='yellow'><b>The checkpoint save did not go through. It will be tried again shortly.</b></font>")
	persistence_checkpoint_running = FALSE

#undef PERSISTENCE_CHECKPOINT_TARGET
#undef PERSISTENCE_CHECKPOINT_LEAD
#undef PERSISTENCE_CHECKPOINT_STAGGER
#undef PERSISTENCE_CHECKPOINT_WARNING
#undef PERSISTENCE_CHECKPOINT_BACKOFF
