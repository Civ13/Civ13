/world
	hub = ""
	hub_password = ""
	maxx = 4
	maxy = 4
	maxz = 1
	turf = /turf
	area = /area

/obj/map_metadata/corpse_ci/New()
	map = src

/obj/item/corpse_ci
	var/drop_count = 0
	var/stable_id = "issued-node-123"
	var/found_in_raid = TRUE
	var/insured = TRUE
/obj/item/corpse_ci/dropped(mob/user)
	drop_count++
	..()

/obj/item/corpse_ci/revive_on_drop/dropped(mob/user)
	..()
	var/mob/living/human/H = user
	H.revive()
/obj/item/corpse_ci/reentrant_drop/dropped(mob/user)
	..()
	var/mob/living/human/H = user
	corpse_assert(!H.retire_corpse(), "reentrant retirement blocked")

/obj/item/corpse_ci/relocate_on_drop/dropped(mob/user)
	..()
	user.forceMove(locate(3,3,1))

/obj/item/clothing/under/corpse_ci
	var/drop_count = 0
/obj/item/clothing/under/corpse_ci/dropped(mob/user)
	drop_count++
	..()

var/corpse_death_hooks = 0
/hook/death/proc/corpse_ci(mob/living/human/H, gibbed)
	corpse_death_hooks++
	return TRUE

var/corpse_hook_calls = 0
var/corpse_hook_slots_clear = FALSE
/hook/corpse_retired/proc/corpse_ci(mob/living/human/H, turf/site)
	corpse_hook_calls++
	corpse_hook_slots_clear = !H.r_hand && !H.back && !H.w_uniform && !H.l_store && !H.r_store && !H.belt && !H.wear_id
	return TRUE

var/corpse_assertions = 0
/proc/corpse_assert(ok, message)
	corpse_assertions++
	if (!ok)
		throw EXCEPTION(message)

/proc/corpse_expire(atom/movable/B)
	B.corpse_decay_age = ABANDONED_ITEM_LIFETIME
	B.corpse_decay_seasons = ABANDONED_ITEM_SEASON_LIFETIME
	B.corpse_decay_record.check(world.time)

/proc/corpse_clear_bones()
	for (var/obj/structure/religious/remains/decaying/B)
		qdel(B)

/world/New()
	text2file(json_encode(list("commit" = world.params["tested_commit"], "byond" = "[world.byond_version].[world.byond_build]", "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz)), "metadata.json")
	try
		config = new
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
		movementMachine = new
		var/process/garbage/G = new
		G.setup()
		var/obj/map_metadata/corpse_ci/M = new
		var/turf/T = locate(2,2,1)
		var/mob/living/human/H = new(T)
		H.stat = DEAD
		H.do_rotting()
		var/datum/corpse_decay_record/R = H.corpse_decay_record
		H.do_rotting()
		corpse_assert(R && H.corpse_decay_record == R && corpse_decay_candidates.len == 1, "idempotent dead registration")
		var/obj/item/corpse_ci/I = new(H)
		H.r_hand = I
		H.corpse_decay_age = 1234
		H.forceMove(T)
		corpse_assert(H.corpse_decay_age == 1234, "noop movement retains exposure")
		H.forceMove(locate(3,2,1))
		corpse_assert(!H.corpse_decay_age, "actual movement resets exposure")
		H.forceMove(T)
		H.corpse_decay_age = 1234
		H.after_load()
		corpse_assert(H.corpse_decay_age == 1234 && H.corpse_decay_record != R, "restart retains exposure")
		R = H.corpse_decay_record
		I.nodrop = TRUE
		corpse_expire(H)
		corpse_assert(H && !H.gcDestroyed && I.loc == H && H.r_hand == I && !I.drop_count, "nodrop gear blocks retirement")
		I.nodrop = FALSE
		var/obj/item/corpse_ci/bag = new(H)
		var/obj/item/corpse_ci/child = new(bag)
		var/obj/item/corpse_ci/attachment = new(child)
		H.back = bag
		corpse_expire(H)
		corpse_assert(!H && I.loc == T && bag.loc == T && child.loc == bag && attachment.loc == child, "actual nested roots dropped before retirement")
		corpse_assert(corpse_hook_slots_clear && corpse_hook_calls == 1 && I.drop_count == 1 && bag.drop_count == 1 && !child.drop_count && !attachment.drop_count, "slots cleared and roots released exactly once")
		corpse_assert(I.stable_id == "issued-node-123" && I.found_in_raid && I.insured && child.stable_id == "issued-node-123", "identity and raid metadata preserved")
		var/obj/structure/religious/remains/decaying/B = locate() in T
		corpse_assert(B && !B.corpse_decay_age && !B.corpse_decay_seasons, "bones have fresh phase")
		B.corpse_decay_age = ABANDONED_ITEM_WARNING
		B.corpse_decay_record.check(world.time)
		corpse_assert(B.corpse_decay_warned && !B.gcDestroyed, "bones warning before retirement")
		corpse_expire(B)
		corpse_assert(B.gcDestroyed && !I.gcDestroyed && !bag.gcDestroyed && child.loc == bag, "bones expire without useful gear loss")
		qdel(I)
		qdel(bag)
		// Native uniform removal cascades pockets, belt and ID. Each root drops once.
		H = new(T)
		var/obj/item/clothing/under/corpse_ci/uniform = new(H)
		H.equip_to_slot(uniform, slot_w_uniform)
		var/list/equipment = list()
		for (var/slot in list(slot_l_store, slot_r_store, slot_belt, slot_wear_id))
			var/obj/item/corpse_ci/gear = new(H)
			H.equip_to_slot(gear, slot)
			equipment += gear
		corpse_assert(H.w_uniform == uniform && H.l_store && H.r_store && H.belt && H.wear_id, "native worn and dependent slots equipped")
		H.stat = DEAD
		H.do_rotting()
		corpse_expire(H)
		corpse_assert(!H && uniform.loc == T && uniform.drop_count == 1 && corpse_hook_slots_clear, "native uniform cascade clears worn slots")
		for (var/obj/item/corpse_ci/gear in equipment)
			corpse_assert(gear.loc == T && gear.drop_count == 1 && !gear.gcDestroyed, "cascade root drops exactly once")
			qdel(gear)
		qdel(uniform)
		corpse_clear_bones()
		H = new(T)
		H.do_rotting()
		corpse_assert(!H.corpse_decay_record, "living does not register")
		H.stat = UNCONSCIOUS
		H.do_rotting()
		corpse_assert(!H.corpse_decay_record, "unconscious does not register")
		H.stat = DEAD
		H.do_rotting()
		H.revive()
		corpse_assert(H.stat != DEAD && !H.corpse_decay_record && !H.start_to_rot && !H.corpse_decay_age, "native revival cancels decay")
		H.death()
		corpse_assert(H.stat == DEAD && H.corpse_decay_record && H.start_to_rot, "native second death registers fresh phase")
		H.rejuvenate()
		corpse_assert(H.stat != DEAD && !H.corpse_decay_record && !H.start_to_rot, "direct native rejuvenation cancels decay")
		H.death()
		var/obj/structure/morgue/storage = new(T)
		H.forceMove(storage)
		corpse_expire(H)
		corpse_assert(!H.gcDestroyed && !H.corpse_decay_age, "morgue protects corpse")
		H.forceMove(T)
		H.pulledby = new /mob(T)
		corpse_expire(H)
		corpse_assert(!H.gcDestroyed, "pulling protects corpse")
		qdel(H.pulledby)
		H.pulledby = null
		H.buckled = new /obj/structure/bed(T)
		corpse_expire(H)
		corpse_assert(!H.gcDestroyed, "buckled body protected")
		H.buckled = null
		H.corpse_decay_age = ABANDONED_ITEM_WARNING
		H.corpse_decay_record.check(world.time)
		corpse_assert(H.rotting_stage == 1 && !H.gcDestroyed, "six-hour warning retains revival window")
		qdel(H)
		qdel(storage)
		H = new(T)
		H.stat = DEAD
		H.do_rotting()
		I = new(H)
		I.anchored = TRUE
		corpse_expire(H)
		corpse_assert(H && I.loc == H && !I.drop_count, "anchored gear blocks retirement")
		qdel(H)
		H = new(T)
		H.stat = DEAD
		H.do_rotting()
		var/obj/item/corpse_ci/revive_on_drop/revival_item = new(H)
		corpse_expire(H)
		corpse_assert(H && H.stat != DEAD && !H.corpse_decay_record && revival_item.loc == T && revival_item.drop_count == 1 && !locate(/obj/structure/religious/remains/decaying) in T, "revival during native drop cancels retirement")
		qdel(H)
		qdel(revival_item)
		H = new(T)
		H.stat = DEAD
		H.do_rotting()
		var/obj/item/corpse_ci/relocate_on_drop/moving_item = new(H)
		corpse_expire(H)
		corpse_assert(H && H.loc == locate(3,3,1) && moving_item.loc == T && !H.corpse_decay_age && !locate(/obj/structure/religious/remains/decaying) in T, "relocation during drop cancels retirement")
		qdel(H)
		qdel(moving_item)
		H = new(T)
		H.stat = DEAD
		H.do_rotting()
		var/mob/passenger = new(H)
		corpse_expire(H)
		corpse_assert(H && passenger && passenger.loc == H, "nongear passenger blocks retirement")
		passenger.forceMove(T)
		qdel(H)
		qdel(passenger)
		B = new(T)
		I = new(B)
		corpse_expire(B)
		corpse_assert(B && !B.gcDestroyed && I.loc == B, "occupied bones protect nested gear")
		I.forceMove(T)
		corpse_expire(B)
		corpse_assert(B.gcDestroyed && I.loc == T, "empty bones retire without their removed gear")
		qdel(I)
		var/obj/structure/religious/remains/decorative = new(T)
		corpse_assert(!decorative.corpse_decay_record, "decorative map bones do not opt in")
		qdel(decorative)
		H = new(T)
		H.stat = DEAD
		H.do_rotting()
		del(H)
		corpse_assert(!corpse_decay_candidates.len, "native Del unregisters body")
		H = new(T)
		H.stat = DEAD
		H.do_rotting()
		var/obj/item/corpse_ci/reentrant_drop/reentrant = new(H)
		corpse_expire(H)
		corpse_assert(!H && reentrant.loc == T && reentrant.drop_count == 1, "reentrant native callback does not duplicate gear")
		qdel(reentrant)
		corpse_clear_bones()
		var/mob/living/human/corpse/map_body = new(T)
		// Native map-corpse setup schedules its death after equipment initialization.
		for (var/attempt = 1, attempt <= 20 && map_body.stat != DEAD, attempt++)
			sleep(1)
		corpse_assert(map_body.stat == DEAD && map_body.corpse_decay_record, "native map corpse registers")
		corpse_expire(map_body)
		corpse_assert(!map_body && locate(/obj/structure/religious/remains/decaying) in T, "native map corpse becomes bones")
		corpse_clear_bones()
		H = new(T)
		H.stat = DEAD
		H.do_rotting()
		for (var/n = 1, n <= CORPSE_GEAR_LIMIT, n++)
			new /obj/item/corpse_ci(H)
		corpse_expire(H)
		corpse_assert(H && H.contents.len > CORPSE_GEAR_LIMIT, "oversized body remains intact within drop budget")
		for (var/obj/item/corpse_ci/gear in H)
			corpse_assert(!gear.drop_count, "oversized roots never partially dropped")
		qdel(H)
		M.abandonment_season_cycle = TRUE
		M.abandonment_season_autonomous = TRUE
		H = new(T)
		H.stat = DEAD
		H.do_rotting()
		R = H.corpse_decay_record
		R.check(world.time)
		abandonment_season_changes += 2
		R.check(world.time)
		corpse_assert(H.rotting_stage == 1 && !H.gcDestroyed, "two-season warning")
		R.check(world.time + ABANDONED_ITEM_LIFETIME * 2)
		corpse_assert(!H.gcDestroyed, "seasonal body has no hour deadline")
		abandonment_season_changes += 2
		R.check(world.time)
		corpse_assert(!H, "four-season corpse retirement")
		B = locate() in T
		corpse_assert(B && !B.corpse_decay_seasons, "seasonal bones fresh phase")
		corpse_expire(B)
		corpse_assert(B.gcDestroyed, "four-season bones retirement")
		// Production native serializer and loader, not a hand-copied clock.
		H = new(T)
		H.stat = DEAD
		H.do_rotting()
		H.adjustBruteLoss(70)
		var/saved_damage = H.getBruteLoss()
		var/death_hooks_before = corpse_death_hooks
		H.corpse_decay_age = 3456
		H.corpse_decay_seasons = 3
		H.corpse_decay_seasonal = TRUE
		bag = new(H)
		child = new(bag)
		H.back = bag
		var/savefile/F = new("isolated-corpses.sav")
		F["/format_version"] << 2
		map_storage.saving_z = 1
		var/body_ref = map_storage.BuildVarDirectory(F, H, 1)
		F.cd = map_storage.entry_path(F, body_ref)
		corpse_assert(!("corpse_decay_record" in F.dir), "serializer excludes runtime record")
		var/saved_age = H.corpse_decay_age
		map_storage.clear_bookkeeping()
		var/mob/living/human/restored = map_storage.Load_Entry(F, body_ref, null, T)
		for (var/datum/loaded in map_storage.all_loaded)
			loaded.after_load()
		corpse_assert(restored && restored != H && restored.stat == DEAD && restored.corpse_decay_record && restored.corpse_decay_age == saved_age && restored.corpse_decay_seasons == 3, "native body roundtrip retains elapsed exposure")
		corpse_assert((restored in dead_mob_list) && !(restored in living_mob_list) && restored.lying && !restored.canmove, "restored corpse has native dead-list and movement state")
		corpse_assert(restored.getBruteLoss() == saved_damage && corpse_death_hooks == death_hooks_before, "native dead restore preserves damage without death-hook replay")
		corpse_assert(restored.back && restored.back.loc == restored && restored.back.contents.len == 1, "native body roundtrip retains nested gear graph")
		var/obj/item/corpse_ci/restored_child = restored.back.contents[1]
		corpse_assert(restored_child.stable_id == child.stable_id && restored_child.found_in_raid && restored_child.insured, "restored gear metadata retained")
		// A valid live save retains the established rejuvenate behavior.
		var/mob/living/human/live_source = new(T)
		live_source.adjustBruteLoss(40)
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 1
		var/savefile/live_file = new("isolated-live-human.sav")
		live_file["/format_version"] << 2
		var/live_ref = map_storage.BuildVarDirectory(live_file, live_source, 1)
		map_storage.clear_bookkeeping()
		var/mob/living/human/live_restored = map_storage.Load_Entry(live_file, live_ref, null, T)
		for (var/datum/loaded in map_storage.all_loaded)
			loaded.after_load()
		corpse_assert(live_restored && live_restored.stat != DEAD && !live_restored.getBruteLoss() && !live_restored.corpse_decay_record, "live save retains rejuvenation")
		qdel(live_source)
		qdel(live_restored)
		// Missing or corrupt dead state never creates death/retirement from age alone.
		for (var/state_control in list("missing", "corrupt"))
			F.cd = map_storage.entry_path(F, body_ref)
			if (state_control == "missing")
				F.dir.Remove("stat")
			else
				F["stat"] << list("kind" = "value", "value" = "invalid-dead-state")
			map_storage.clear_bookkeeping()
			var/mob/living/human/state_restored = map_storage.Load_Entry(F, body_ref, null, T)
			for (var/datum/loaded in map_storage.all_loaded)
				loaded.after_load()
			corpse_assert(state_restored && state_restored.stat != DEAD && !state_restored.corpse_decay_record && !state_restored.corpse_decay_age && corpse_death_hooks == death_hooks_before, "missing/corrupt state remains live without death hooks")
			qdel(state_restored)
		map_storage.clear_bookkeeping()
		qdel(H)
		qdel(restored)
		B = new(T)
		B.corpse_decay_age = 4321
		B.corpse_decay_seasons = 3
		B.corpse_decay_seasonal = TRUE
		map_storage.saving_z = 1
		var/savefile/bone_file = new("isolated-bones.sav")
		bone_file["/format_version"] << 2
		var/bone_ref = map_storage.BuildVarDirectory(bone_file, B, 1)
		saved_age = B.corpse_decay_age
		map_storage.clear_bookkeeping()
		var/obj/structure/religious/remains/decaying/restored_bones = map_storage.Load_Entry(bone_file, bone_ref, null, T)
		for (var/datum/loaded in map_storage.all_loaded)
			loaded.after_load()
		corpse_assert(restored_bones && restored_bones != B && restored_bones.corpse_decay_record && restored_bones.corpse_decay_age == saved_age && restored_bones.corpse_decay_seasons == 3, "native bones roundtrip retains elapsed exposure")
		map_storage.clear_bookkeeping()
		qdel(B)
		qdel(restored_bones)
		// Headed zombie maps retain the previous special outcome.
		M.is_zombie = TRUE
		H = new(T)
		H.stat = DEAD
		H.do_rotting()
		corpse_expire(H)
		var/mob/living/simple_animal/hostile/human/zombie/Z = locate() in T
		corpse_assert(!H && Z && !locate(/obj/structure/religious/remains/decaying) in T, "headed zombie-map corpse reanimates")
		qdel(Z)
		M.is_zombie = FALSE
		for (var/state = 1, state <= 6, state++)
			fcopy(icon('icons/misc/tribal.dmi', "remains[state]"), "remains[state].png")
		corpse_clear_bones()
		var/process/human_corpse_decay/P = new
		P.setup()
		for (var/cycle = 1, cycle <= 20, cycle++)
			for (var/n = 1, n <= 128, n++)
				B = new(T)
				B.corpse_decay_age = ABANDONED_ITEM_LIFETIME
				B.corpse_decay_seasons = ABANDONED_ITEM_SEASON_LIFETIME
			var/before = corpse_decay_candidates.len
			P.fire()
			corpse_assert(before - corpse_decay_candidates.len == CORPSE_DECAY_BATCH, "batch cap")
			for (var/batch = 1, batch <= 3, batch++)
				P.fire()
			corpse_assert(!corpse_decay_candidates.len, "all swapped candidates visited")
			for (var/id in G.destroyed)
				var/datum/D = locate(id)
				if (D) D.gcDestroyed = world.time - 301
				G.destroyed[id] = world.time - 301
			while (G.destroyed.len)
				G.fire()
			sleep(1)
			var/count = 0
			for (var/datum/corpse_decay_record/remaining)
				count++
			corpse_assert(!count, "no retained records after GC")
			text2file(json_encode(list("cycle" = cycle, "registry" = corpse_decay_candidates.len, "records" = count)), "cycles.jsonl")
		text2file("PASS: [corpse_assertions] assertions; native corpse, inventory, revival and 20 x128 GC cycles", "result.txt")
	catch (var/exception/E)
		text2file("FAIL: [E] at [E.file]:[E.line]", "result.txt")
	del(world)
