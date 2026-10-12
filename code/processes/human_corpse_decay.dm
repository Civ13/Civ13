// Only human bodies and remains created by their retirement opt in.
#define CORPSE_DECAY_BATCH 32
#define CORPSE_GEAR_LIMIT 256
// Optional listeners observe physical retirement, never an account credit.
/hook/corpse_retired

var/global/list/corpse_decay_candidates = list()
var/global/corpse_decay_cursor = 1

/atom/movable
	// Durable elapsed exposure, independent of world.time and season counter epochs.
	var/corpse_decay_age = 0
	var/corpse_decay_seasons = 0
	var/corpse_decay_seasonal = null
	var/corpse_decay_warned = FALSE
	var/tmp/datum/corpse_decay_record/corpse_decay_record = null

/atom/movable/proc/reset_corpse_decay_age()
	corpse_decay_age = 0
	corpse_decay_seasons = 0
	corpse_decay_seasonal = null
	corpse_decay_warned = FALSE
	if (corpse_decay_record)
		corpse_decay_record.reset_clock()

/atom/movable/proc/register_corpse_decay()
	if (gcDestroyed || corpse_decay_record)
		return
	if (!istype(src, /mob/living/human) && !istype(src, /obj/structure/religious/remains/decaying))
		return
	corpse_decay_record = new(src)

/atom/movable/proc/unregister_corpse_decay()
	if (corpse_decay_record)
		var/datum/corpse_decay_record/R = corpse_decay_record
		corpse_decay_record = null
		qdel(R)

/atom/movable/persistence_runtime_var(key)
	if (key == "corpse_decay_record")
		return TRUE
	return ..()

/atom/movable/before_save()
	if (corpse_decay_record)
		corpse_decay_record.update_age(world.time)
	return ..()

/datum/corpse_decay_record
	var/tmp/atom/movable/body
	var/tmp/index = 0
	var/tmp/last_time = 0
	var/tmp/last_season = 0
	var/tmp/location_ref
	var/tmp/retiring = FALSE

/datum/corpse_decay_record/New(atom/movable/target)
	body = target
	corpse_decay_candidates += src
	index = corpse_decay_candidates.len
	reset_clock()

/datum/corpse_decay_record/proc/reset_clock()
	last_time = world.time
	last_season = abandonment_season_changes
	location_ref = body ? "\ref[body.loc]" : null

/datum/corpse_decay_record/Destroy()
	if (index)
		var/datum/corpse_decay_record/last = corpse_decay_candidates[corpse_decay_candidates.len]
		corpse_decay_candidates[index] = last
		last.index = index
		corpse_decay_candidates.Cut(corpse_decay_candidates.len, corpse_decay_candidates.len+1)
		index = 0
	if (body && body.corpse_decay_record == src)
		body.corpse_decay_record = null
	body = null
	location_ref = null
	return ..()

/datum/corpse_decay_record/proc/protected()
	if (!body || body.gcDestroyed || !isturf(body.loc) || body.pulledby || body.throwing)
		return TRUE
	if (istype(body, /mob/living/human))
		var/mob/living/human/H = body
		return H.stat != DEAD || H.buckled
	return body.contents.len > 0

/datum/corpse_decay_record/proc/update_age(now)
	if (!body || body.gcDestroyed)
		return FALSE
	var/seasonal = map && map.abandonment_uses_seasons()
	if (protected() || location_ref != "\ref[body.loc]" || (!isnull(body.corpse_decay_seasonal) && body.corpse_decay_seasonal != seasonal))
		body.reset_corpse_decay_age()
		return FALSE
	body.corpse_decay_seasonal = seasonal
	// Counter rollback/restart never grants negative or offline exposure.
	body.corpse_decay_age += max(0, now - last_time)
	body.corpse_decay_seasons += max(0, abandonment_season_changes - last_season)
	last_time = now
	last_season = abandonment_season_changes
	return TRUE

/datum/corpse_decay_record/proc/check(now)
	if (!body || body.gcDestroyed)
		qdel(src)
		return
	if (istype(body, /mob/living/human))
		var/mob/living/human/H = body
		if (H.stat != DEAD)
			H.unregister_corpse_decay()
			H.reset_corpse_decay_age()
			H.start_to_rot = FALSE
			return
	if (retiring || !update_age(now))
		return
	var/age = body.corpse_decay_seasonal ? body.corpse_decay_seasons : body.corpse_decay_age
	var/warning = body.corpse_decay_seasonal ? ABANDONED_ITEM_SEASON_WARNING : ABANDONED_ITEM_WARNING
	var/expiry = body.corpse_decay_seasonal ? ABANDONED_ITEM_SEASON_LIFETIME : ABANDONED_ITEM_LIFETIME
	if (age >= warning && !body.corpse_decay_warned)
		body.corpse_decay_warned = TRUE
		if (istype(body, /mob/living/human))
			var/mob/living/human/H = body
			H.rotting_stage = 1
			H.visible_message("[H]'s body starts to rot.")
			H.update_icons()
		else
			body.visible_message("[body] are badly weathered and will soon crumble away.")
	if (age < expiry)
		return
	if (istype(body, /mob/living/human))
		var/mob/living/human/H = body
		H.retire_corpse()
	else if (!protected())
		qdel(body)

/mob/living/human/proc/retire_corpse()
	var/datum/corpse_decay_record/R = corpse_decay_record
	if (!R || R.retiring)
		return FALSE
	R.retiring = TRUE
	. = try_retire_corpse()
	if (R && corpse_decay_record == R)
		R.retiring = FALSE

/mob/living/human/proc/try_retire_corpse()
	var/datum/corpse_decay_record/R = corpse_decay_record
	if (!R || R.protected() || contents.len > CORPSE_GEAR_LIMIT)
		return FALSE
	var/turf/site = loc
	// Snapshot only this bounded body's roots. Nested gear moves with its root.
	var/list/roots = contents.Copy()
	for (var/atom/movable/A in roots)
		if (A.loc != src || (A in organs) || (A in internal_organs))
			continue
		if (!istype(A, /obj/item) || istype(A, /obj/item/organ))
			return FALSE
		var/obj/item/I = A
		if (I.nodrop || I.anchored || I.nodrop_special_check())
			return FALSE
	// Preflight before any release; native callbacks may still cancel retirement.
	for (var/obj/item/I in roots)
		if (I.loc != src || (I in organs) || (I in internal_organs))
			continue
		drop_from_inventory(I, site)
		if (gcDestroyed || stat != DEAD || !R || corpse_decay_record != R || loc != site || R.protected() || (I && I.loc == src))
			return FALSE
	for (var/atom/movable/A in contents)
		if (!(A in organs) && !(A in internal_organs))
			return FALSE
	var/head_found = FALSE
	for (var/obj/item/organ/external/head/H in organs)
		head_found = TRUE
		break
	if (map && map.is_zombie && head_found && !istype(get_area(src), /area/caribbean/admin))
		var/mob/living/simple_animal/hostile/human/zombie/Z = new(site)
		Z.name = "[real_name]'s zombie"
	else
		var/obj/structure/religious/remains/decaying/B = new(site)
		B.name = "[src]'s remains"
	callHook("corpse_retired", list(src, site))
	qdel(src) // Normal ghost, anatomy and GC bookkeeping; gear is already outside.
	return TRUE

/mob/living/human/rejuvenate()
	unregister_corpse_decay()
	reset_corpse_decay_age()
	start_to_rot = FALSE
	rotting_stage = 0
	return ..()

/mob/living/human/forceMove(atom/destination, special_event)
	var/atom/previous = loc
	. = ..()
	if (loc != previous)
		reset_corpse_decay_age()

/mob/living/human/Del()
	unregister_corpse_decay()
	return ..()

/mob/living/human/after_load()
	..()
	// Restore durable age; bind fresh runtime epochs after native graph loading.
	unregister_corpse_decay()
	if (stat == DEAD)
		living_mob_list -= src
		dead_mob_list |= src
		update_canmove()
		update_icons()
		do_rotting()
	else
		reset_corpse_decay_age()
		start_to_rot = FALSE
		rotting_stage = 0

/obj/structure/religious/remains/decaying/New()
	..()
	register_corpse_decay()

/obj/structure/religious/remains/decaying/Destroy()
	unregister_corpse_decay()
	return ..()

/obj/structure/religious/remains/decaying/Del()
	unregister_corpse_decay()
	return ..()

/obj/structure/religious/remains/decaying/Move()
	var/atom/previous = loc
	. = ..()
	if (loc != previous)
		reset_corpse_decay_age()

/obj/structure/religious/remains/decaying/forceMove(atom/destination, special_event)
	var/atom/previous = loc
	. = ..()
	if (loc != previous)
		reset_corpse_decay_age()

/obj/structure/religious/remains/decaying/after_load()
	..()
	unregister_corpse_decay()
	register_corpse_decay()

/process/human_corpse_decay/setup()
	name = "human corpse decay"
	schedule_interval = 30 SECONDS
	start_delay = 10 SECONDS
	priority = PROCESS_PRIORITY_LOW
	fires_at_gamestates = list(GAME_STATE_PLAYING)
	processes.human_corpse_decay = src

/process/human_corpse_decay/fire()
	var/checks = min(CORPSE_DECAY_BATCH, corpse_decay_candidates.len)
	while (checks-- > 0 && corpse_decay_candidates.len)
		if (corpse_decay_cursor > corpse_decay_candidates.len)
			corpse_decay_cursor = 1
		var/datum/corpse_decay_record/R = corpse_decay_candidates[corpse_decay_cursor]
		var/slot = corpse_decay_cursor
		R.check(world.time)
		if (R && R.index == slot)
			corpse_decay_cursor++

/process/human_corpse_decay/reset_current_list()
	return // No world scans or second candidate list.
