// Headless Train Raid round-flow probe. Test-only: native_probe.py appends it
// to a temporary copy of civ13.dme with maps/EFT/train_raid.dmm selected. The
// production mode code runs unchanged; the probe drives a round through
// boarding, departure, recall, a lift balloon, a bed claim, a death with
// lives, and the line collapse, and records what happened.
var/global/datum/train_raid_probe/train_raid_probe = new

/mob/living/human/train_raid_probe_actor
/mob/living/human/train_raid_probe_actor/ssd_check()
	return FALSE

/datum/train_raid_probe
	var/list/checks = list()
	var/phase = "startup"
	var/started_tod = 0

/datum/train_raid_probe/New()
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

/datum/train_raid_probe/proc/mark(name)
	phase = name
	fdel("phase.json")
	text2file(json_encode(list("phase" = name, "world_time" = world.time)), "phase.json")

/datum/train_raid_probe/proc/pass(name, list/details = null)
	checks += list(list("check" = name, "passed" = TRUE, "details" = details))

/datum/train_raid_probe/proc/require(condition, message)
	if (!condition)
		throw EXCEPTION(message)

/datum/train_raid_probe/proc/wait_for(datum/target, proc_name, deadline_ds, message)
	var/until = world.time + deadline_ds
	while (!call(target, proc_name)())
		if (world.time > until)
			throw EXCEPTION(message)
		sleep(5)

/datum/train_raid_probe/proc/game_playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/train_raid_probe/proc/scheduler_ready()
	return ticker && processScheduler && processes && ticker.current_state >= GAME_STATE_PREGAME

/datum/train_raid_probe/proc/round_started()
	var/obj/map_metadata/train_raid/M = map
	return istype(M) && M.round_started

/datum/train_raid_probe/proc/bridges_of(crew, dense)
	var/count = 0
	for (var/obj/structure/train_raid_bridge/B in train_raid_bridges)
		if (B.crew == crew && B.density == dense) count++
	return count

/datum/train_raid_probe/proc/spawn_raider(crew, key)
	var/datum/train_raid_crew/C = map:crew(crew)
	var/list/spawns = latejoin_turfs["JoinLateTrain[C.title]"]
	var/mob/living/human/train_raid_probe_actor/H = new(pick(spawns))
	H.mind = new /datum/mind(key)
	H.mind.current = H
	var/datum/job/J = job_master.GetJob("[C.title] shuttle raider")
	require(J, "job [C.title] shuttle raider missing")
	J.equip(H)
	return H

/datum/train_raid_probe/proc/count_of(list/L)
	return islist(L) ? L.len : 0

/datum/train_raid_probe/proc/drive()
	var/failure = null
	var/failed_phase = null
	try
		mark("startup")
		wait_for(src, "scheduler_ready", 9000, "Scheduler/ticker never became ready")
		var/obj/map_metadata/train_raid/M = map
		require(istype(M), "map is [map ? map.type : "null"], not train_raid")
		ticker.admin_started = TRUE
		if (ticker.pregame_timeleft > 1)
			ticker.pregame_timeleft = 1
		wait_for(src, "game_playing", 3000, "Round did not reach PLAYING")
		mark("map")
		require(count_of(latejoin_turfs["JoinLateTrainWest"]) == 8 && count_of(latejoin_turfs["JoinLateTrainEast"]) == 8, "crew spawn landmarks: [count_of(latejoin_turfs["JoinLateTrainWest"])]/[count_of(latejoin_turfs["JoinLateTrainEast"])]")
		require(count_of(latejoin_turfs["TrainStoresWest"]) == 5 && count_of(latejoin_turfs["TrainStoresEast"]) == 5, "store landmarks missing")
		require(train_raid_bridges.len == 72, "bridge gates: [train_raid_bridges.len]")
		require(train_raid_helms.len == 2, "helms: [train_raid_helms.len]")
		require(train_raid_loot_pads.len == 236, "loot pads: [train_raid_loot_pads.len]")
		var/rolled = 0
		var/loot_items = 0
		for (var/obj/effect/train_raid_loot/P in train_raid_loot_pads)
			if (P.rolled) rolled++
			for (var/obj/item/I in P.loc) loot_items++
			var/obj/structure/closet/C = locate() in P.loc
			if (C)
				for (var/obj/item/I in C) loot_items++
		require(rolled == 236, "rolled pads: [rolled]")
		require(loot_items > 40, "loot items spawned: [loot_items]")
		var/crew_doors = 0
		for (var/obj/structure/simple_door/train_raid_crew/D in world) crew_doors++
		require(crew_doors == 4, "crew doors: [crew_doors]")
		pass("map_objects", list("loot_items" = loot_items, "bridges" = train_raid_bridges.len))
		mark("boarding")
		wait_for(src, "round_started", 600, "mode never started its round")
		var/datum/train_raid_crew/west = M.crew("west")
		var/datum/train_raid_crew/east = M.crew("east")
		require(west.state == "docked" && east.state == "docked", "crews not docked at start")
		require(bridges_of("west", FALSE) == 36 && bridges_of("east", FALSE) == 36, "bridges not extended at start")
		var/mob/living/human/H = spawn_raider("west", "probe_west")
		require(H.train_raid_crew == "west", "raider not bound to west crew")
		var/key = M.raider_key(H)
		require(key == "probewest", "raider key: [key]")
		require(west.lives_of(key) == 3, "lives not initialised")
		require(locate(/obj/item/train_raid_beacon) in H.contents, "beacon not issued")
		var/balloons = 0
		for (var/obj/item/train_raid_balloon/B in H.get_contents()) balloons++
		require(balloons == 2, "balloons issued: [balloons]")
		pass("raider_kit")
		// The crew door opens for its crew and rattles for anyone else.
		var/obj/structure/simple_door/train_raid_crew/door
		for (var/obj/structure/simple_door/train_raid_crew/D in world)
			if (D.crew == "west")
				door = D
				break
		var/mob/living/human/stranger = spawn_raider("east", "probe_east")
		require(door.canOpen(H) && !door.canOpen(stranger), "crew door authorization wrong")
		door.Open()
		sleep(15)
		require(door.state, "crew door did not open")
		door.Close()
		sleep(15)
		require(!door.state, "crew door did not close")
		door.ex_act(1)
		require(!QDELETED(door), "crew door destroyed by explosion")
		pass("crew_door")
		mark("departure")
		var/obj/structure/train_raid_helm/helm
		for (var/obj/structure/train_raid_helm/T in train_raid_helms)
			if (T.crew == "west") helm = T
		require(helm, "west helm missing")
		require(west.depart_now(H), "helm departure refused")
		require(west.state == "away", "west not away after departure")
		require(bridges_of("west", TRUE) == 36, "west bridges not retracted")
		require(bridges_of("east", FALSE) == 36, "east bridges changed by west departure")
		pass("departure")
		mark("recall")
		var/turf/hauler_turf
		for (var/turf/T in get_area_turfs(/area/train_raid/hauler/coaches))
			if (!T.density && !(locate(/obj/structure) in T))
				hauler_turf = T
				break
		require(hauler_turf, "no free coach turf")
		H.forceMove(hauler_turf)
		require(!west.recall(H), "recall accepted during cooldown")
		west.next_recall = 0
		require(west.recall(H), "recall refused after cooldown")
		require(west.state == "inbound", "west not inbound")
		west.state_until = world.time
		west.tick()
		require(west.state == "docked" && bridges_of("west", FALSE) == 36, "west did not dock on arrival")
		require(west.state_until > world.time, "docking window not scheduled")
		west.state_until = world.time
		west.tick()
		require(west.state == "away" && bridges_of("west", TRUE) == 36, "west did not depart after its window")
		pass("recall_cycle")
		mark("balloon")
		var/obj/structure/closet/crate/crate = new(hauler_turf)
		var/obj/item/weapon/storage/eft/medical/kit = new(crate)
		var/obj/item/train_raid_balloon/balloon = locate() in H.get_contents()
		var/before = count_of(west.store_turfs())
		H.forceMove(get_step(hauler_turf, NORTH))
		require(H.Adjacent(crate) && H.may_do_after && !H.incapacitated(), "raider cannot act on the crate")
		balloon.afterattack(crate, H, TRUE)
		require(QDELETED(balloon), "balloon not consumed")
		require(west.aboard(crate) && kit.loc == crate, "crate not delivered to west stores (at [crate.loc])")
		require(west.secured_value() >= kit.value, "secured value did not count the lifted kit")
		pass("lift_balloon", list("stores" = before, "value" = west.secured_value()))
		mark("lives")
		var/obj/structure/bed/train_raid/bed
		for (var/obj/structure/bed/train_raid/B in world)
			if (istype(get_area(B), /area/train_raid/hauler/coaches))
				bed = B
				break
		require(bed, "no coach bed")
		require(west.claim_bed(H, bed), "bed claim refused")
		require(!east.claim_bed(stranger, bed), "second raider could claim a taken bed")
		require(west.bed_turf(key), "no return turf beside the bed")
		H.death()
		require(west.lives_of(key) == 2, "lives after death: [west.lives_of(key)]")
		var/mob/living/human/again = spawn_raider("west", "probe_west")
		require(again.job_spawn_location == "TrainRaidBed_west_probewest", "respawn not pointed at the bed: [again.job_spawn_location]")
		require(count_of(latejoin_turfs[again.job_spawn_location]) == 1, "bed spawn turf not registered")
		qdel(bed)
		require(!west.bed_turf(key), "destroyed bed still claimed")
		again.death()
		var/mob/living/human/third = spawn_raider("west", "probe_west")
		require(!third.job_spawn_location, "respawn still pointed at the destroyed bed")
		third.death()
		var/mob/living/human/last = spawn_raider("west", "probe_west")
		require(west.lives_of(key) == 0 && !last.job_spawn_location, "out-of-lives raider not sent to the shuttle")
		pass("lives_and_beds")
		mark("collapse")
		var/mob/living/human/left = spawn_raider("east", "probe_left")
		left.forceMove(get_step(hauler_turf, SOUTH))
		var/obj/item/stray = new /obj/item/weapon/storage/eft/medical(hauler_turf)
		M.round_deadline = world.time - 1
		M.tick()
		require(M.game_over && ticker.finished, "collapse did not end the round")
		require(left.stat == DEAD, "raider left on the Hauler survived the collapse")
		require(QDELETED(stray), "stray Hauler item survived the collapse")
		require(!QDELETED(kit) && kit.loc == crate, "secured item lost at collapse")
		pass("line_collapse")
	catch (var/exception/e)
		failure = "[e.name] ([e.file]:[e.line])"
		failed_phase = phase
	mark("finished")
	var/list/result = list("passed" = isnull(failure), "failure" = failure, "failed_phase" = failed_phase, "checks" = checks, "wall_ds" = world.timeofday - started_tod)
	text2file(json_encode(result), "result.json")
	world.log << (failure ? "FAIL: train raid probe: [failure]" : "PASS: train raid probe")
	sleep(5)
	del(world)
