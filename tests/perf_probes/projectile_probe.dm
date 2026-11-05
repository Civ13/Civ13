// Headless projectile measurement probe (CM-SS13 adoption plan, step 10).
// Test-only: native_probe.py appends it to a temporary copy of civ13.dme. The
// production projectile code runs unchanged. The probe clears a square on the
// surface, fires waves of bullets from one shooter at a fan of targets, and
// records per-bullet outcomes, tick usage and the 500-projectile cap.
// Developer evidence only; it decides whether step 11 (ammo flyweight and
// elapsed-tick movement) is worth building.
var/global/datum/projectile_probe/projectile_probe = new

/mob/living/human/projectile_probe_actor
/mob/living/human/projectile_probe_actor/ssd_check()
	return FALSE
/mob/living/human/projectile_probe_actor/bullet_act(var/obj/item/projectile/P, var/def_zone)
	if (projectile_probe)
		projectile_probe.record_hit(P, src)
	return FALSE // no damage: targets must survive every wave

/obj/item/projectile/bullet/projectile_probe
	damage = 0
	nodamage = TRUE
	embed = FALSE
	var/tmp/mob/probe_target
	var/tmp/probe_distance = 0
	var/tmp/probe_wave = 0
	var/tmp/probe_hit = null
	var/tmp/probe_recorded = FALSE
	var/tmp/list/probe_path = list()

/obj/item/projectile/bullet/projectile_probe/before_move()
	probe_path |= get_turf(src)
	return ..()

/obj/item/projectile/bullet/projectile_probe/Destroy()
	if (projectile_probe && !probe_recorded)
		probe_recorded = TRUE
		projectile_probe.record_bullet(src)
	return ..()

/datum/projectile_probe
	var/started_tod = 0
	var/list/result = list("passed" = FALSE, "failure" = null)
	var/list/outcomes = list()
	var/list/wave_rows = list()
	var/peak_projectiles = 0
	var/sampling = FALSE
	var/list/tick_samples = list()
	var/mob/living/human/projectile_probe_actor/shooter
	var/obj/item/weapon/gun/projectile/gun
	var/list/targets = list()

/datum/projectile_probe/New()
	if (!all_species || !all_species.len)
		makeDatumRefLists()
	if (!config)
		load_configuration()
		initialize_chemical_reagents()
		initialize_chemical_reactions()
	if (config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	started_tod = world.timeofday
	spawn(10)
		drive()

/datum/projectile_probe/proc/scheduler_ready()
	return ticker && processScheduler && processes && ticker.current_state >= GAME_STATE_PREGAME

/datum/projectile_probe/proc/game_playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/projectile_probe/proc/wait_for(proc_name, deadline_ds)
	var/until = world.time + deadline_ds
	while (!call(src, proc_name)())
		if (world.time > until)
			throw EXCEPTION("timed out waiting for [proc_name]")
		sleep(10)

/datum/projectile_probe/proc/record_hit(obj/item/projectile/P, mob/M)
	var/obj/item/projectile/bullet/projectile_probe/B = P
	if (istype(B) && isnull(B.probe_hit))
		B.probe_hit = (M == B.probe_target) ? "target" : "other"

/datum/projectile_probe/proc/record_bullet(obj/item/projectile/bullet/projectile_probe/B)
	var/turf/target_turf = B.probe_target ? get_turf(B.probe_target) : null
	var/travelled = B.starting && B.loc ? get_dist(B.starting, B.loc) : 0
	var/reached = target_turf && ((target_turf in B.permutated) || (target_turf in B.probe_path))
	var/outcome
	if (B.probe_hit == "target")
		outcome = "hit"
	else if (B.probe_hit == "other")
		outcome = "hit_other"
	else if (!B.trajectory)
		outcome = "never_moved" // deleted before its first process(): the cap or a launch refusal
	else if (reached)
		outcome = "passed_target" // reached the target's tile and missed (hit roll)
	else if (B.kill_count < 1 && B.probe_distance > travelled)
		outcome = "out_of_range"
	else if (target_turf && travelled >= B.probe_distance)
		outcome = "skipped_target" // flew past the target distance without visiting its tile
	else
		outcome = "stopped_early"
	outcomes += list(list("wave" = B.probe_wave, "distance" = B.probe_distance, "outcome" = outcome, "travelled" = travelled))

/datum/projectile_probe/proc/sample_ticks()
	set waitfor = FALSE
	while (sampling)
		tick_samples += world.tick_usage
		if (projectile_list.len > peak_projectiles)
			peak_projectiles = projectile_list.len
		sleep(world.tick_lag)

/datum/projectile_probe/proc/prepare_field()
	var/z = world.maxz
	var/cx = round(world.maxx / 2)
	var/cy = round(world.maxy / 2)
	var/half = 38
	var/list/field = block(locate(cx - half, cy - half, z), locate(cx + half, cy + half, z))
	for (var/turf/T in field)
		for (var/atom/movable/AM in T)
			if (istype(AM, /mob/living) || istype(AM, /obj/structure) || istype(AM, /obj/covers) || istype(AM, /obj/item))
				qdel(AM)
		if (T.density || !istype(T, /turf/floor) || istype(T, /turf/floor/beach/water))
			T.ChangeTurf(/turf/floor/grass)
	var/turf/origin = locate(cx - half + 2, cy, z)
	shooter = new /mob/living/human/projectile_probe_actor(origin)
	gun = new /obj/item/weapon/gun/projectile/boltaction/mosin(origin)
	// A fan of 30 targets, 5 to 34 tiles away (inside the default kill_count of
	// 35) and 0 to 58 degrees off the shooter's facing, so diagonal paths count.
	for (var/i = 0 to 29)
		var/distance = 5 + i
		var/angle = (i * 2) % 60
		var/turf/spot = locate(origin.x + round(distance * cos(angle)), origin.y + round(distance * sin(angle)), z)
		var/mob/living/human/projectile_probe_actor/target = new(spot)
		targets += target
	return field.len

/datum/projectile_probe/proc/fire_wave(wave, per_target)
	var/before = projectile_list.len
	var/fired = 0
	var/started = world.timeofday
	for (var/mob/living/human/projectile_probe_actor/target in targets)
		for (var/n = 1 to per_target)
			var/obj/item/projectile/bullet/projectile_probe/B = new(shooter.loc)
			B.probe_target = target
			B.probe_distance = get_dist(shooter, target)
			B.probe_wave = wave
			if (!B.launch(target, shooter, gun, "chest"))
				fired++
	wave_rows += list(list("wave" = wave, "fired" = fired, "list_before" = before, "list_after" = projectile_list.len, "launch_ds" = world.timeofday - started))

/datum/projectile_probe/proc/drive()
	try
		wait_for("scheduler_ready", 9000)
		if (ticker)
			ticker.admin_started = TRUE
			if (ticker.pregame_timeleft > 1)
				ticker.pregame_timeleft = 1
		wait_for("game_playing", 9000)
		sleep(100)
		var/cleared = prepare_field()
		sleep(50)
		result["world_fps"] = world.fps
		result["field_turfs"] = cleared
		world.Profile(PROFILE_CLEAR)
		world.Profile(PROFILE_START)
		var/cpu_start = world.cpu
		var/time_start = world.time
		sampling = TRUE
		sample_ticks()
		sleep(30)
		result["baseline_ticks"] = summarize(tick_samples.Copy())
		tick_samples.Cut()
		// Ten ordinary waves: 30 bullets each, two seconds apart (300 bullets).
		for (var/wave = 1 to 10)
			fire_wave(wave, 1)
			sleep(20)
		sleep(30)
		var/list/ordinary_ticks = tick_samples.Copy()
		tick_samples.Cut()
		// One stress wave: 20 bullets per target (600 at once) to find the cap.
		fire_wave(11, 20)
		sleep(60)
		sampling = FALSE
		var/list/stress_ticks = tick_samples.Copy()
		result["cpu_avg_during_run"] = world.cpu
		result["cpu_start"] = cpu_start
		result["game_seconds"] = (world.time - time_start) / 10
		result["profile"] = world.Profile(PROFILE_REFRESH, null, "json")
		world.Profile(PROFILE_STOP)
		result["ordinary_ticks"] = summarize(ordinary_ticks)
		result["stress_ticks"] = summarize(stress_ticks)
		result["peak_projectiles"] = peak_projectiles
		result["waves"] = wave_rows
		var/list/counts = list()
		for (var/list/row in outcomes)
			var/key = "[row["wave"] <= 10 ? "ordinary" : "stress"]:[row["outcome"]]"
			counts[key] = (counts[key] || 0) + 1
		result["outcome_counts"] = counts
		result["bullets"] = outcomes
		result["passed"] = TRUE
	catch (var/exception/e)
		result["failure"] = "[e.name] ([e.file]:[e.line])"
	text2file(json_encode(result), "result.json")
	sleep(5)
	del(world)

/datum/projectile_probe/proc/summarize(list/samples)
	if (!samples.len)
		return list("ticks" = 0)
	var/total = 0
	var/peak = 0
	var/over = 0
	for (var/v in samples)
		total += v
		peak = max(peak, v)
		if (v > 100)
			over++
	return list("ticks" = samples.len, "mean_tick_usage" = round(total / samples.len, 0.1), "max_tick_usage" = peak, "overrun_ticks" = over)
