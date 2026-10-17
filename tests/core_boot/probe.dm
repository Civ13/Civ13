// Full production-source boot and base-system exercise, without clients or a listening port.
// Included after the production sources; only the overrides below adapt startup.
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/world/New()
	OpenPort("none")
	if (config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
		config.skip_persistence_saving = TRUE
	..()
	if (config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
		config.skip_persistence_saving = TRUE
	spawn(10)
		core_boot_probe.exercise()

/world/Error(exception/error)
	core_boot_probe.runtime_errors++
	text2file("CORE BOOT runtime error: [error] at [error.file]:[error.line]", "core-boot-runtime-error.txt")
	return ..()

/world/Reboot(reason)
	core_boot_probe.fail("Unexpected reboot: [reason]")

/mob/living/human/core_boot_actor
	var/probe_lives = 0

/mob/living/human/core_boot_actor/ssd_check()
	return FALSE

/mob/living/human/core_boot_actor/Life()
	probe_lives++
	return ..()

var/global/datum/core_boot_probe/core_boot_probe = new

/datum/core_boot_probe
	var/runtime_errors = 0
	var/finished = FALSE
	var/list/checks = list()
	var/list/timings = list()
	var/list/tick_samples = list()

/datum/core_boot_probe/proc/mark(name)
	timings[name] = world.timeofday
	text2file(json_encode(list("phase" = name)), "phase.json")

/datum/core_boot_probe/proc/check(condition, message)
	if (!condition)
		throw EXCEPTION(message)
	checks += message
	world.log << "CORE BOOT PASS: [message]"

/datum/core_boot_probe/proc/fail(message)
	if (finished)
		return
	finished = TRUE
	text2file("FAIL: [message]", "result.txt")
	shutdown()

// Waits on real elapsed time, sampling tick usage, so wall-clock deadlines hold
// even when the server falls behind.
/datum/core_boot_probe/proc/wait_until(datum/target, condition_proc, seconds, message)
	var/deadline = world.timeofday + seconds * 10
	while (!call(target, condition_proc)())
		if (world.timeofday > deadline)
			throw EXCEPTION("Deadline: [message][waiting_processes.len ? " (waiting: [jointext(waiting_processes, ", ")])" : ""]")
		tick_samples += world.tick_usage
		sleep(5)

/datum/core_boot_probe/var/list/waiting_processes = list()
/datum/core_boot_probe/var/list/baseline_ticks = list()

// Every enabled process scheduled for the current state must fire after the
// baseline was taken, proving the scheduler services it in this state.
/datum/core_boot_probe/proc/scheduler_ready()
	if (!processScheduler || !processScheduler.isRunning || !ticker)
		return FALSE
	waiting_processes = list()
	for (var/process/P in processScheduler.processes)
		if (P.disabled || P.paused || !(ticker.current_state in P.fires_at_gamestates))
			continue
		if (P.ticks <= (baseline_ticks[P.name] || 0))
			waiting_processes += P.name
	return !waiting_processes.len

/datum/core_boot_probe/proc/take_baseline()
	baseline_ticks = list()
	for (var/process/P in processScheduler.processes)
		baseline_ticks[P.name] = P.ticks

/datum/core_boot_probe/proc/round_playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/core_boot_probe/proc/process_rows()
	var/list/rows = list()
	for (var/process/P in processScheduler.processes)
		rows[P.name] = list("ticks" = P.ticks, "hung" = P.hung, "killed" = P.killed, "times_killed" = P.times_killed, "exceptions" = P.exceptions.len, "run_failures" = P.run_failures, "disabled" = P.disabled)
	return rows

/datum/core_boot_probe/proc/check_processes(stage)
	for (var/process/P in processScheduler.processes)
		check(!P.hung && !P.killed && !P.times_killed, "[stage]: [P.name] never hung or was killed")
		check(!P.exceptions.len && !P.run_failures, "[stage]: [P.name] recorded no exceptions")

/datum/core_boot_probe/var/mob/living/human/core_boot_actor/actor
/datum/core_boot_probe/var/obj/item/weapon/reagent_containers/glass/beaker/large/beaker

/datum/core_boot_probe/proc/actor_lived()
	return actor && actor.probe_lives >= 3

// Reactions run once when queued; the chemistry process must then retire the
// settled holder from its active list.
/datum/core_boot_probe/proc/reaction_done()
	return beaker && beaker.reagents.get_reagent_amount("butylrubber") == 5 && !(beaker.reagents in processes.chemistry.active_holders)

/datum/core_boot_probe/proc/exercise()
	try
		mark("startup")
#ifdef CORE_BOOT_LIGHTING_RESTART
		if (fexists("map_saves/save_complete.txt"))
			restart_load_phase()
			finished = TRUE
			text2file("PASS: restart import lighting", "result.txt")
			shutdown()
			return
#endif
		wait_until(src, /datum/core_boot_probe/proc/scheduler_ready, 300, "every scheduled process fires after startup")
		mark("scheduler_ready")
		check(runtime_errors == 0, "startup reported zero world errors")
		check_processes("startup")

		// Start the round exactly as the admin Start Now verb does.
		round_progressing = TRUE
		ticker.pregame_timeleft = 1
		ticker.admin_started = TRUE
		wait_until(src, /datum/core_boot_probe/proc/round_playing, 120, "the round starts")
		mark("round_started")
		take_baseline()
		waiting_processes = list()
		wait_until(src, /datum/core_boot_probe/proc/scheduler_ready, 300, "every scheduled process fires during the round")
		mark("round_scheduler_ready")
		check(runtime_errors == 0, "round start reported zero world errors")
		check_processes("round start")

		var/turf/site = locate(round(world.maxx / 2), round(world.maxy / 2), 1)
		check(istype(site), "map loaded a central turf")

		// Mob lifecycle through the ordinary mob process.
		actor = new(site)
		wait_until(src, /datum/core_boot_probe/proc/actor_lived, 60, "a headless human receives natural Life")
		check(actor.stat != DEAD, "a fresh human survives its first Life ticks")
		actor.adjustBruteLoss(20)
		actor.updatehealth()
		check(actor.health < actor.maxHealth, "damage applies to a live human")
		actor.death()
		check(actor.stat == DEAD, "a human can die")
		qdel(actor)
		actor = null
		mark("mob_lifecycle")

		// Chemistry through the ordinary chemistry process.
		beaker = new(site)
		beaker.reagents.add_reagent("isobutylene", 10)
		beaker.reagents.add_reagent("aluminumchloride", 1)
		wait_until(src, /datum/core_boot_probe/proc/reaction_done, 30, "the chemistry process completes a queued reaction")
		qdel(beaker)
		beaker = null
		mark("chemistry")

		// Object churn through construction, movement and deletion.
		var/list/paths = list(/obj/item/stack/material/wood, /obj/item/weapon/reagent_containers/food/snacks/dough, /obj/item/weapon/reagent_containers/glass/bucket, /obj/structure/oven, /obj/item/stack/material/bone)
		for (var/i in 1 to 40)
			for (var/path in paths)
				var/atom/movable/A = new path(site)
				A.loc = get_step(site, pick(cardinal))
				qdel(A)
		mark("object_churn")

#ifdef CORE_BOOT_LIGHTING_LOAD
		load_cycle_lighting()
		mark("lighting_load")
#endif
#ifdef CORE_BOOT_LIGHTING_RESTART
		restart_save_phase()
		finished = TRUE
		text2file("PASS: restart save phase", "result.txt")
		shutdown()
		return
#endif

		// Let every process keep running after the exercise.
		sleep(200)
		mark("steady_state")
		check(runtime_errors == 0, "base-system exercise reported zero world errors")
		check_processes("steady state")

		var/list/sorted = tick_samples.Copy()
		var/peak = 0
		for (var/sample in sorted)
			peak = max(peak, sample)
		text2file(json_encode(list("checks" = checks, "timings_ds" = timings, "processes" = process_rows(), "tick_usage_peak" = peak, "tick_usage_samples" = tick_samples.len, "map" = map ? map.ID : null, "dimensions" = list(world.maxx, world.maxy, world.maxz), "byond_build" = world.byond_build)), "result.json")
		finished = TRUE
		text2file("PASS: boot, round start, scheduler, mob, chemistry and object lifecycle without world errors", "result.txt")
	catch (var/exception/E)
		world.log << "CORE BOOT exception: [E] at [E.file]:[E.line]"
		if (!finished)
			finished = TRUE
			text2file(json_encode(list("checks" = checks, "timings_ds" = timings)), "partial.json")
			text2file("FAIL: [E.name]", "result.txt")
	shutdown()
