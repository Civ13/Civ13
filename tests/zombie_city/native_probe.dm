// Headless zombie city probe. Test-only: native_probe.py appends it to a
// temporary copy of civ13.dme with maps/EFT/crossroads_mall.dmm selected.
// It registers one horde block around a clientless anchor body and checks
// spawning out of sight, pursuit, kills, folding back, noise and every loot
// table at three research ages.
var/global/datum/zombie_city_probe/zombie_city_probe = new

/mob/living/human/zombie_city_probe_actor
/mob/living/human/zombie_city_probe_actor/ssd_check()
	return FALSE

/datum/zombie_city_probe
	var/list/checks = list()
	var/phase = "startup"
	var/started_tod = 0
	var/mob/living/human/zombie_city_probe_actor/anchor

/datum/zombie_city_probe/New()
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

/datum/zombie_city_probe/proc/mark(name)
	phase = name
	fdel("phase.json")
	text2file(json_encode(list("phase" = name, "world_time" = world.time)), "phase.json")

/datum/zombie_city_probe/proc/pass(name, list/details = null)
	checks += list(list("check" = name, "passed" = TRUE, "details" = details))

/datum/zombie_city_probe/proc/require(condition, message)
	if (!condition)
		throw EXCEPTION(message)

/datum/zombie_city_probe/proc/wait_for(datum/target, proc_name, deadline_ds, message)
	var/until = world.time + deadline_ds
	while (!call(target, proc_name)())
		if (world.time > until)
			throw EXCEPTION(message)
		sleep(5)

/datum/zombie_city_probe/proc/game_playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/zombie_city_probe/proc/scheduler_ready()
	return ticker && processScheduler && processes && ticker.current_state >= GAME_STATE_PREGAME

/datum/zombie_city_probe/proc/some_live()
	return zombie_horde && zombie_horde.live.len >= 3

/datum/zombie_city_probe/proc/none_live()
	return zombie_horde && !zombie_horde.live.len

/datum/zombie_city_probe/proc/anchor_hurt()
	return anchor && anchor.getBruteLoss() > 0

/datum/zombie_city_probe/proc/open_turf_with_room()
	for (var/i in 1 to 4000)
		var/turf/T = locate(rand(30, world.maxx - 30), rand(30, world.maxy - 30), 1)
		if (!T || T.density || istype(T, /turf/wall))
			continue
		var/open = 0
		for (var/turf/N in range(12, T))
			if (!N.density)
				open++
		if (open >= 450)
			return T
	return null

/datum/zombie_city_probe/proc/live_total()
	return zombie_horde.live.len + zombie_horde.total_virtual()

/datum/zombie_city_probe/proc/check_loot()
	var/saved_age = map.ordinal_age
	var/turf/T = locate(5, 5, 1)
	var/list/per_age = list()
	for (var/age in list(0, 5, 9))
		map.ordinal_age = age
		var/guns = 0
		var/items = 0
		for (var/table in zombie_city_loot_tables)
			for (var/tier in 1 to 3)
				var/list/allowed = zombie_city_loot_choices(table, tier, age)
				for (var/n in 1 to 4)
					var/list/made = zombie_city_roll_loot(T, table, tier)
					for (var/obj/item/I in made)
						items++
						if (istype(I, /obj/item/weapon/gun))
							guns++
						if (!istype(I, /obj/item/ammo_magazine))
							require(allowed[I.type], "[table] tier [tier] age [age] made [I.type], not allowed")
						require(!I.should_save, "loot [I.type] would be saved")
						qdel(I)
		require(items > 0, "no loot at age [age]")
		if (age == 0)
			require(!guns, "age 0 loot made [guns] guns")
		per_age["[age]"] = list("items" = items, "guns" = guns)
	require(per_age["9"]["guns"] > 0, "age 9 never rolled a gun")
	require(!zombie_city_roll_loot(T, "no such table", 1).len, "unknown table made loot")
	map.ordinal_age = saved_age
	pass("loot_tables", per_age)

/datum/zombie_city_probe/proc/drive()
	var/failure = null
	var/failed_phase = null
	try
		mark("startup")
		wait_for(src, "scheduler_ready", 9000, "Scheduler/ticker never became ready")
		ticker.admin_started = TRUE
		if (ticker.pregame_timeleft > 1)
			ticker.pregame_timeleft = 1
		wait_for(src, "game_playing", 3000, "Round did not reach PLAYING")
		mark("loot")
		check_loot()

		mark("inert")
		require(!zombie_horde, "horde exists before any block")
		require(isnull(zombie_horde_add_block("bad", locate(1,1,1), locate(5,5,1), "swarming")), "unknown density accepted")
		require(!zombie_horde, "rejected block started the horde")
		pass("inert_until_block")

		mark("spawn")
		var/turf/center = open_turf_with_room()
		require(center, "no open probe area")
		anchor = new(center)
		anchor.zombie_horde_anchor = TRUE
		anchor.status_flags |= GODMODE
		zombie_horde_add_block("probe", locate(center.x - 22, center.y - 22, 1), locate(center.x + 22, center.y + 22, 1), "infested")
		require(live_total() == 18, "infested block holds [live_total()]")
		wait_for(src, "some_live", 600, "no zombies spawned near the anchor")
		var/list/spawn_dist = list()
		// Spawns land 9-20 tiles out; zombies may already have wandered a step or two.
		for (var/mob/living/simple_animal/hostile/human/zombie/horde/Z in zombie_horde.live)
			spawn_dist += get_dist(Z, anchor)
			require(get_dist(Z, anchor) <= 23, "zombie spawned [get_dist(Z, anchor)] tiles away")
			require(!Z.should_save, "horde zombie would be saved")
		require(live_total() == 18, "spawning changed the total to [live_total()]")
		sleep(100)
		require(zombie_horde.live.len <= 15, "per-player cap exceeded: [zombie_horde.live.len]")
		pass("spawn_near_anchor", list("live" = zombie_horde.live.len, "first_distances" = spawn_dist))

		mark("pursuit")
		anchor.status_flags &= ~GODMODE
		wait_for(src, "anchor_hurt", 1200, "no zombie reached and bit the anchor")
		anchor.status_flags |= GODMODE
		anchor.revive()
		pass("pursuit_and_bite")

		mark("kill")
		var/before = live_total()
		var/mob/living/simple_animal/hostile/human/zombie/horde/victim = zombie_horde.live[1]
		victim.health = 0
		victim.death()
		require(victim.stat == DEAD, "victim did not die")
		require(live_total() == before - 1, "kill did not lower the total ([before] -> [live_total()])")
		require(zombie_horde.killed_total == 1, "killed_total [zombie_horde.killed_total]")
		pass("kill_lowers_count")

		mark("noise")
		var/turf/far = locate(center.x + 15, center.y, 1)
		var/listeners = 0
		for (var/mob/living/simple_animal/hostile/human/zombie/horde/Z in zombie_horde.live)
			Z.target_mob = null
			listeners++
		zombie_horde_noise(far, 40)
		var/heard = 0
		for (var/mob/living/simple_animal/hostile/human/zombie/horde/Z in zombie_horde.live)
			if (Z.horde_noise_turf == far)
				heard++
		require(listeners && heard == listeners, "noise reached [heard] of [listeners]")
		pass("noise_attracts", list("heard" = heard))

		mark("fold")
		var/total = live_total()
		anchor.zombie_horde_anchor = FALSE
		wait_for(src, "none_live", 1200, "zombies did not fold back without players")
		require(live_total() == total, "folding changed the total ([total] -> [live_total()])")
		require(zombie_horde.blocks["probe"].count == total, "block count [zombie_horde.blocks["probe"].count], expected [total]")
		pass("fold_back", list("folded" = zombie_horde.folded_total))
	catch (var/exception/e)
		failure = "[e.name] ([e.file]:[e.line])"
		failed_phase = phase
	mark("finished")
	var/list/result = list("passed" = isnull(failure), "failure" = failure, "failed_phase" = failed_phase, "checks" = checks, "status" = zombie_horde ? zombie_horde.status() : null, "wall_ds" = world.timeofday - started_tod)
	text2file(json_encode(result), "result.json")
	world.log << (failure ? "FAIL: zombie city probe: [failure]" : "PASS: zombie city probe")
	sleep(5)
	del(world)
