// Nomad raids (docs/nomad-raids.md). Admin-started, default off.
//
// A party of nomad raiders spawns out of sight at the map edge nearest a
// settled group of active players, marches in, halts and demands tribute.
// Paying ends the raid; refusing or attacking starts a fight. Raiders then
// loot loose items and unlocked crates near the target and walk back to the
// edge, where they despawn with what they carried. A raider who dies drops
// everything they stole, plus their weapon and bag.
//
// Raiders are ordinary humans without a client, driven by this controller
// through the same mob procs a player's input reaches (Move, ClickOn, say),
// so range, cooldown and combat rules apply. Nothing here is saved: raiders
// and the raid end at a restart, and the controller pauses during saves.
// Cooldowns use world.realtime in data/nomad_raids.json, never world.time.

#define NOMAD_RAID_STEP 2 // deciseconds between controller passes
#define NOMAD_RAID_DECIDE (1 SECONDS) // target and loot choices
#define NOMAD_RAID_MIN_MEMBERS 2
#define NOMAD_RAID_MAX_MEMBERS 6
#define NOMAD_RAID_MIN_DEFENDERS 2 // automatic targeting skips smaller groups
#define NOMAD_RAID_GROUP_RANGE 20
#define NOMAD_RAID_PARLEY_RANGE 10
#define NOMAD_RAID_FIGHT_RANGE 12
#define NOMAD_RAID_LOOT_RANGE 8
#define NOMAD_RAID_EDGE_LIMIT 120 // farthest spawn distance from the target
#define NOMAD_RAID_EDGE_SPREAD 30
#define NOMAD_RAID_VIEW_MARGIN 12
#define NOMAD_RAID_PARLEY_TIME (90 SECONDS)
#define NOMAD_RAID_MARCH_LIMIT (10 MINUTES)
#define NOMAD_RAID_ASSAULT_LIMIT (5 MINUTES)
#define NOMAD_RAID_QUIET_LIMIT (15 SECONDS)
#define NOMAD_RAID_LOOT_LIMIT (3 MINUTES)
#define NOMAD_RAID_LEAVE_LIMIT (10 MINUTES)
#define NOMAD_RAID_TOTAL_LIMIT (30 MINUTES)
#define NOMAD_RAID_TRIBUTE_PER_RAIDER 5
#define NOMAD_RAID_GROUP_COOLDOWN 72000 // two hours of world.realtime
#define NOMAD_RAID_COOLDOWN_FILE "data/nomad_raids.json"

var/global/datum/nomad_raid/nomad_raid = null
var/global/list/nomad_raid_cooldowns = null // ckey = world.realtime of the last raid on them

/proc/nomad_raid_clans()
	return list("Wolf Clan", "Ash Riders", "Red Hand", "Bone Wanderers", "Grey Hawks", "Salt Walkers")

// ---------------------------------------------------------------------------
// Cooldowns survive restarts in real time.

/proc/nomad_raid_load_cooldowns()
	if (islist(nomad_raid_cooldowns))
		return
	nomad_raid_cooldowns = list()
	if (!fexists(NOMAD_RAID_COOLDOWN_FILE))
		return
	var/list/data
	try
		data = json_decode(file2text(NOMAD_RAID_COOLDOWN_FILE))
	catch
		data = null
	if (!islist(data))
		return
	for (var/key in data)
		if (istext(key) && isnum(data[key]))
			nomad_raid_cooldowns[key] = data[key]

/proc/nomad_raid_save_cooldowns()
	nomad_raid_load_cooldowns()
	for (var/key in nomad_raid_cooldowns.Copy())
		if (world.realtime - nomad_raid_cooldowns[key] >= NOMAD_RAID_GROUP_COOLDOWN)
			nomad_raid_cooldowns -= key
	if (fexists(NOMAD_RAID_COOLDOWN_FILE))
		fdel(NOMAD_RAID_COOLDOWN_FILE)
	text2file(json_encode(nomad_raid_cooldowns), NOMAD_RAID_COOLDOWN_FILE)

/proc/nomad_raid_on_cooldown(ckey)
	nomad_raid_load_cooldowns()
	var/last = nomad_raid_cooldowns[ckey]
	return isnum(last) && world.realtime - last < NOMAD_RAID_GROUP_COOLDOWN

// ---------------------------------------------------------------------------
// Targeting: groups of active players, scored by size, buildings and history.

// An active, awake player in a human body. Raiders and agent bodies have no client.
/proc/nomad_raid_defender(mob/living/human/H)
	if (!istype(H) || H.stat != CONSCIOUS || !H.client || H.client.inactivity > 5 MINUTES)
		return FALSE
	return get_turf(H) ? TRUE : FALSE

/proc/nomad_raid_defenders_near(turf/T, radius = NOMAD_RAID_GROUP_RANGE)
	var/list/found = list()
	if (!T)
		return found
	for (var/client/C in clients)
		var/mob/living/human/H = C.mob
		if (!nomad_raid_defender(H))
			continue
		var/turf/at = get_turf(H)
		if (at.z == T.z && get_dist(at, T) <= radius)
			found += H
	return found

/proc/nomad_raid_score(turf/T, defenders)
	var/built = 0
	for (var/obj/roof/R in range(7, T))
		built++
	for (var/turf/wall/W in range(7, T))
		built++
	var/score = defenders + min(10, built / 5)
	// The ecology heatmap, when an admin has it running, adds recent history.
	if (ecology_spawner && ecology_spawner.enabled && ecology_spawner.heatmap)
		var/datum/ecology_activity_heatmap/HM = ecology_spawner.heatmap
		var/pressure = HM.pressure(ecology_spawner.now_seconds(), ecology_cell_row(T), HM.epoch)
		if (isnum(pressure))
			score += pressure * 10
	return score

// Each candidate: list("turf", "ckeys", "score"). Groups with a member on cooldown are left out.
/proc/nomad_raid_candidates(min_defenders = NOMAD_RAID_MIN_DEFENDERS)
	var/list/defenders = list()
	for (var/client/C in clients)
		if (nomad_raid_defender(C.mob))
			defenders += C.mob
	var/list/claimed = list()
	var/list/out = list()
	for (var/mob/living/human/H in defenders)
		if (H in claimed)
			continue
		var/turf/T = get_turf(H)
		var/list/group = list()
		for (var/mob/living/human/O in defenders)
			var/turf/OT = get_turf(O)
			if (OT.z == T.z && get_dist(OT, T) <= NOMAD_RAID_GROUP_RANGE)
				group += O
		claimed |= group
		if (group.len < min_defenders)
			continue
		var/list/ckeys = list()
		var/cooling = FALSE
		for (var/mob/M in group)
			ckeys += M.ckey
			if (nomad_raid_on_cooldown(M.ckey))
				cooling = TRUE
		if (cooling)
			continue
		out += list(list("turf" = T, "ckeys" = ckeys, "score" = nomad_raid_score(T, group.len)))
	return out

// Weighted by score: the busiest settlement is likelier, not certain.
/proc/nomad_raid_pick(list/candidates)
	if (!candidates || !candidates.len)
		return null
	var/total = 0
	for (var/list/C in candidates)
		total += C["score"]
	var/roll = rand() * total
	for (var/list/C in candidates)
		roll -= C["score"]
		if (roll <= 0)
			return C
	return candidates[candidates.len]

// ---------------------------------------------------------------------------
// Spawning at the map edge, out of every player's sight.

/proc/nomad_raid_spawn_error(turf/T)
	if (!T || T.density || istype(T, /turf/wall) || istype(T, /turf/floor/beach/water) || istype(T, /turf/floor/lava))
		return "ground"
	var/area/A = get_area(T)
	if (!A || A.location != AREA_OUTSIDE || A.is_void_area)
		return "area"
	if (locate(/obj/roof) in T)
		return "roofed"
	for (var/atom/movable/AM in T)
		if (AM.density || isliving(AM))
			return "occupied"
	if (ecology_visible_to_players(T, NOMAD_RAID_VIEW_MARGIN))
		return "visible"
	return null

// Edges nearest first; on a far edge, a point NOMAD_RAID_EDGE_LIMIT tiles out on that heading.
/proc/nomad_raid_edge_site(turf/target)
	if (!target)
		return null
	var/list/edges = list("west" = target.x - 1, "east" = world.maxx - target.x, "south" = target.y - 1, "north" = world.maxy - target.y)
	while (edges.len)
		var/best = null
		for (var/edge in edges)
			if (isnull(best) || edges[edge] < edges[best])
				best = edge
		var/reach = min(edges[best] - 2, NOMAD_RAID_EDGE_LIMIT)
		edges -= best
		if (reach < NOMAD_RAID_VIEW_MARGIN)
			continue
		for (var/i = 1, i <= 30, i++)
			var/out = reach - rand(0, 4)
			var/side = rand(-NOMAD_RAID_EDGE_SPREAD, NOMAD_RAID_EDGE_SPREAD)
			var/x = target.x
			var/y = target.y
			switch (best)
				if ("west")
					x -= out
					y += side
				if ("east")
					x += out
					y += side
				if ("south")
					y -= out
					x += side
				if ("north")
					y += out
					x += side
			x = clamp(x, 2, world.maxx - 1)
			y = clamp(y, 2, world.maxy - 1)
			var/turf/T = locate(x, y, target.z)
			if (!nomad_raid_spawn_error(T))
				return list("turf" = T, "edge" = best)
	return null

/proc/nomad_raid_equip(mob/living/human/H)
	var/age = map ? map.ordinal_age : 0
	var/under = /obj/item/clothing/under/loinleather
	var/weapon = /obj/item/weapon/material/spear
	if (age >= 1)
		under = /obj/item/clothing/under/medieval/leather
		weapon = /obj/item/weapon/material/spear/iron
	if (age >= 4)
		weapon = /obj/item/weapon/material/sword/smallsword
	H.equip_to_slot_or_del(new under(H), slot_w_uniform)
	H.equip_to_slot_or_del(new /obj/item/weapon/storage/backpack/satchel(H), slot_back)
	var/obj/item/W = new weapon(get_turf(H))
	if (!H.put_in_active_hand(W))
		H.put_in_hands(W)
	return W

// What a loose item is worth to a raider; 0 means leave it.
/proc/nomad_raid_worth(obj/item/I)
	if (!istype(I) || I.anchored || !isturf(I.loc) || I.w_class > ITEM_SIZE_LARGE)
		return 0
	var/worth = max(1, I.value)
	if (istype(I, /obj/item/weapon/material) || istype(I, /obj/item/weapon/gun))
		worth += 5
	if (istype(I, /obj/item/weapon/reagent_containers/food))
		worth += 2
	return worth

// ---------------------------------------------------------------------------
// The raid.

/datum/nomad_raid
	should_save = FALSE
	var/tmp/state = "march" // march, parley, assault, loot, leave, ended
	var/tmp/clan
	var/tmp/started_by
	var/tmp/mob/living/human/leader
	var/tmp/list/members = list()
	var/tmp/initial_size = 0
	var/tmp/turf/target
	var/tmp/turf/home
	var/tmp/edge
	var/tmp/list/target_ckeys = list()
	var/tmp/started_at = 0
	var/tmp/state_at = 0
	var/tmp/last_seen_foe = 0
	var/tmp/next_decide = 0
	var/tmp/next_speech = 0
	var/tmp/tribute_demand = 0
	var/tmp/list/tribute_ignore = list() // items already at the leader's feet when parley began
	var/tmp/list/tribute_items = list()
	var/tmp/warned_short = FALSE
	var/tmp/outcome = ""
	var/tmp/list/next_step = list() // member = world.time of their next step
	var/tmp/list/last_health = list()
	var/tmp/list/weapon = list() // member = their weapon
	var/tmp/list/foe = list() // member = the mob they fight
	var/tmp/list/loot_target = list() // member = item or closet they go for
	var/tmp/list/done_looting = list()
	var/tmp/list/stolen = list() // items taken from the ground or crates
	var/tmp/list/fallen = list() // dead members already emptied
	var/tmp/escaped = 0
	var/tmp/escaped_items = 0

/datum/nomad_raid/persistence_runtime_var(key)
	return TRUE

/datum/nomad_raid/proc/log_event(text)
	log_admin("NOMAD RAID ([clan]): [text]")
	message_admins("Nomad raid ([clan]): [text]")

/datum/nomad_raid/proc/set_state(new_state, reason)
	if (state == new_state || state == "ended")
		return
	state = new_state
	state_at = world.time
	log_event("[new_state] - [reason]")

// Builds the party at an edge site. Returns null on success, else why it could not start.
/datum/nomad_raid/proc/setup(turf/_target, list/ckeys, size, by)
	target = _target
	target_ckeys = ckeys ? ckeys.Copy() : list()
	started_by = by
	clan = pick(nomad_raid_clans())
	var/list/site = nomad_raid_edge_site(target)
	if (!site)
		return "no open, unseen ground near a map edge on that level"
	home = site["turf"]
	edge = site["edge"]
	// The chieftain stands nearest the target so followers never block the march.
	var/list/spots = list()
	for (var/turf/T in range(2, home))
		if (T == home || !nomad_raid_spawn_error(T))
			var/i = 1
			while (i <= spots.len && get_dist(spots[i], target) <= get_dist(T, target))
				i++
			spots.Insert(i, T)
	size = clamp(round(size), NOMAD_RAID_MIN_MEMBERS, NOMAD_RAID_MAX_MEMBERS)
	for (var/i = 1, i <= size, i++)
		var/turf/at = spots[((i - 1) % spots.len) + 1]
		add_member(at, i == 1)
	initial_size = members.len
	if (!leader)
		return "the raiders could not be created"
	started_at = world.time
	state_at = world.time
	tribute_demand = max(8, NOMAD_RAID_TRIBUTE_PER_RAIDER * members.len)
	return null

/datum/nomad_raid/proc/add_member(turf/T, is_leader)
	var/mob/living/human/H = new /mob/living/human(T)
	H.should_save = FALSE
	// Inactive mind: some paths expect one; it never takes a key.
	if (!H.mind)
		var/datum/mind/M = new /datum/mind("nomad_raid")
		M.name = H.real_name
		M.original = H
		M.transfer_to(H)
	weapon[H] = nomad_raid_equip(H)
	H.a_intent = I_HARM
	var/wanted = is_leader ? "[clan] chieftain" : "[clan] raider"
	H.fully_replace_character_name(H.real_name, wanted)
	// Humans pick a map identity half a second after New; rename after it.
	spawn(6)
		if (!QDELETED(H) && H.real_name != wanted)
			H.fully_replace_character_name(H.real_name, wanted)
	members += H
	last_health[H] = H.health
	if (is_leader)
		leader = H
	return H

/datum/nomad_raid/proc/begin()
	log_event("started by [started_by]: [members.len] raiders from the [edge] edge at [home.x],[home.y],[home.z] toward [target.x],[target.y],[target.z] ([target_ckeys.len ? jointext(target_ckeys, ", ") : "no named players"])")
	for (var/ckey in target_ckeys)
		nomad_raid_cooldowns[ckey] = world.realtime
	nomad_raid_save_cooldowns()
	for (var/mob/living/human/H in nomad_raid_defenders_near(target))
		to_chat(H, SPAN_DANGER("War horns sound in the distance to the [edge]. Someone is coming."))
	spawn(0)
		run_loop()

/datum/nomad_raid/proc/run_loop()
	while (state != "ended")
		if (!persistence_active_operation && !persistence_save_in_progress)
			try
				tick()
			catch (var/exception/E)
				log_event("stopped by an error: [E] [E.file]:[E.line]")
				remove_all("error")
		sleep(NOMAD_RAID_STEP)

/datum/nomad_raid/proc/alive_members()
	var/list/out = list()
	for (var/mob/living/human/H in members)
		if (!QDELETED(H) && H.stat != DEAD)
			out += H
	return out

/datum/nomad_raid/proc/speak(text, emote = null, force = FALSE)
	if (!leader || QDELETED(leader) || leader.stat != CONSCIOUS)
		return
	if (!force && world.time < next_speech)
		return
	next_speech = world.time + 3 SECONDS
	usr = leader
	leader.say(text)
	// Raiders may not share a language with the players; a gesture always reads.
	if (emote)
		leader.custom_emote(1, emote)

// One controller pass: bookkeeping, then the state's behaviour.
/datum/nomad_raid/proc/tick()
	var/hurt = FALSE
	for (var/mob/living/human/H in members.Copy())
		if (QDELETED(H))
			members -= H
			continue
		if (H.stat == DEAD)
			drop_loot(H)
			continue
		if (H.health < last_health[H])
			hurt = TRUE
		last_health[H] = H.health
	var/list/alive = alive_members()
	if (!alive.len)
		finish("every raider fell")
		return
	if (world.time - started_at > NOMAD_RAID_TOTAL_LIMIT)
		remove_all("time limit")
		return
	var/decide = world.time >= next_decide
	if (decide)
		next_decide = world.time + NOMAD_RAID_DECIDE
	var/leader_down = !leader || QDELETED(leader) || leader.stat != CONSCIOUS
	if (state != "leave" && (leader_down || alive.len * 2 <= initial_size))
		speak("Fall back! Back to the wilds!", force = TRUE)
		set_state("leave", leader_down ? "the chieftain is down" : "half the party is down")
	switch (state)
		if ("march")
			tick_march(alive, hurt, decide)
		if ("parley")
			tick_parley(alive, hurt, decide)
		if ("assault")
			tick_assault(alive, decide)
		if ("loot")
			tick_loot(alive, decide)
		if ("leave")
			tick_leave(alive)

/datum/nomad_raid/proc/tick_march(list/alive, hurt, decide)
	if (hurt)
		speak("They strike first! Kill them!", force = TRUE)
		set_state("assault", "attacked on the march")
		return
	if (world.time - state_at > NOMAD_RAID_MARCH_LIMIT)
		set_state("leave", "the march took too long")
		return
	if (decide)
		var/list/near = nomad_raid_defenders_near(get_turf(leader), NOMAD_RAID_PARLEY_RANGE)
		if (near.len)
			begin_parley()
			return
		if (get_dist(leader, target) <= 3 && !nomad_raid_defenders_near(target).len)
			set_state("leave", "nobody was home")
			return
	step_toward(leader, target, 2)
	for (var/mob/living/human/H in alive)
		if (H != leader)
			step_toward(H, leader, 2)

/datum/nomad_raid/proc/begin_parley()
	set_state("parley", "defenders in sight")
	warned_short = FALSE
	tribute_ignore = list()
	for (var/obj/item/I in range(1, leader))
		tribute_ignore += I
	speak("We are the [clan]. Lay tribute at my feet - tools, metal, food - and we walk away. Refuse, and we take everything.", "points at the ground at their feet, then at your stores, and raises their weapon.", TRUE)

/datum/nomad_raid/proc/tribute_value()
	var/total = 0
	tribute_items = list()
	for (var/obj/item/I in range(1, leader))
		if (I in tribute_ignore)
			continue
		var/worth = nomad_raid_worth(I)
		if (worth)
			total += worth
			tribute_items += I
	return total

/datum/nomad_raid/proc/tick_parley(list/alive, hurt, decide)
	if (hurt)
		speak("So be it! Take them!", force = TRUE)
		set_state("assault", "attacked during parley")
		return
	for (var/mob/living/human/H in alive)
		if (H != leader)
			step_toward(H, leader, 2)
	if (!decide)
		return
	if (tribute_value() >= tribute_demand)
		speak("Wise. The [clan] remembers its friends.", force = TRUE)
		outcome = "tribute paid"
		set_state("loot", "tribute paid")
		return
	var/elapsed = world.time - state_at
	if (!warned_short && elapsed > NOMAD_RAID_PARLEY_TIME - 30 SECONDS)
		warned_short = TRUE
		speak("Not enough. Your time runs short.", "counts on their fingers and glares.", TRUE)
	if (elapsed > NOMAD_RAID_PARLEY_TIME)
		speak("Then we take it! Kill them!", force = TRUE)
		set_state("assault", "tribute refused")

/datum/nomad_raid/proc/is_member(mob/M)
	return M in members

// The nearest awake human that is not a raider. Downed people are left alone.
/datum/nomad_raid/proc/pick_foe(mob/living/human/H)
	var/mob/living/best
	var/best_d = 1e9
	for (var/mob/living/human/M in range(NOMAD_RAID_FIGHT_RANGE, H))
		if (M.stat != CONSCIOUS || is_member(M))
			continue
		var/d = get_dist(H, M)
		if (d < best_d)
			best = M
			best_d = d
	return best

/datum/nomad_raid/proc/tick_assault(list/alive, decide)
	if (world.time - state_at > NOMAD_RAID_ASSAULT_LIMIT)
		set_state("loot", "the fight ran long")
		return
	var/any = FALSE
	for (var/mob/living/human/H in alive)
		var/mob/living/M = foe[H]
		if (decide || !M || QDELETED(M) || M.stat != CONSCIOUS)
			M = pick_foe(H)
			foe[H] = M
		if (M)
			any = TRUE
			fight(H, M)
		else
			step_toward(H, target, 3)
	if (any)
		last_seen_foe = world.time
	else if (world.time - max(last_seen_foe, state_at) > NOMAD_RAID_QUIET_LIMIT)
		speak("Grab what you can carry!", force = TRUE)
		set_state("loot", "no defenders left standing")

/datum/nomad_raid/proc/arm(mob/living/human/H)
	var/obj/item/W = weapon[H]
	if (!W || QDELETED(W) || H.get_active_hand() == W)
		return
	if (H.get_inactive_hand() == W)
		H.swap_hand()

/datum/nomad_raid/proc/fight(mob/living/human/H, mob/living/M)
	if (get_dist(H, M) > 1)
		step_toward(H, M, 1)
		return
	arm(H)
	H.a_intent = I_HARM
	H.set_dir(get_dir(H, M))
	spawn(0)
		usr = H
		H.ClickOn(M)

// Loot: the tribute if it was paid, else the best loose item or an unlocked crate near the target.
/datum/nomad_raid/proc/pick_loot(mob/living/human/H)
	if (outcome == "tribute paid")
		for (var/obj/item/I in tribute_items)
			if (!QDELETED(I) && isturf(I.loc) && !(I in loot_target))
				return I
		return null
	var/atom/best
	var/best_worth = 0
	var/list/claimed = list()
	for (var/mob/M in loot_target)
		claimed += loot_target[M]
	for (var/obj/item/I in range(NOMAD_RAID_LOOT_RANGE, target))
		if (I in claimed)
			continue
		var/worth = nomad_raid_worth(I) * 10 - get_dist(H, I)
		if (worth > best_worth)
			best = I
			best_worth = worth
	if (best)
		return best
	for (var/obj/structure/closet/C in range(NOMAD_RAID_LOOT_RANGE, target))
		if (!C.opened && !C.locked && !C.welded && !(C in claimed))
			return C
	return null

// Into the bag, else a free hand. FALSE when nothing fits.
/datum/nomad_raid/proc/carry(mob/living/human/H, obj/item/I)
	usr = H
	var/obj/item/weapon/storage/S = H.back
	if (istype(S) && S.can_be_inserted(I, TRUE) && S.handle_item_insertion(I, TRUE))
		return TRUE
	if (!H.get_inactive_hand() && H.put_in_inactive_hand(I))
		return TRUE
	return FALSE

/datum/nomad_raid/proc/tick_loot(list/alive, decide)
	if (world.time - state_at > NOMAD_RAID_LOOT_LIMIT)
		set_state("leave", "looting ran long")
		return
	var/working = FALSE
	for (var/mob/living/human/H in alive)
		if (H in done_looting)
			continue
		// Fight back if someone is on them.
		var/mob/living/M = H.lastattacker
		if (istype(M) && M.stat == CONSCIOUS && get_dist(H, M) <= 1 && !is_member(M))
			fight(H, M)
			working = TRUE
			continue
		var/atom/goal = loot_target[H]
		if (!goal || QDELETED(goal) || (istype(goal, /obj/item) && !isturf(goal.loc)))
			goal = decide ? pick_loot(H) : null
			loot_target[H] = goal
			if (!goal)
				if (decide)
					done_looting += H
				continue
		working = TRUE
		if (get_dist(H, goal) > 1)
			step_toward(H, goal, 1)
			continue
		if (istype(goal, /obj/structure/closet))
			var/obj/structure/closet/C = goal
			C.open()
			loot_target[H] = null
		else if (carry(H, goal))
			stolen += goal
			loot_target[H] = null
		else
			done_looting += H
	if (!working)
		if (outcome != "tribute paid")
			speak("We have what we came for.", force = TRUE)
		set_state("leave", "looting done")

/datum/nomad_raid/proc/tick_leave(list/alive)
	if (world.time - state_at > NOMAD_RAID_LEAVE_LIMIT)
		remove_all("the walk home ran long")
		return
	for (var/mob/living/human/H in alive)
		var/turf/at = get_turf(H)
		var/home_free = get_dist(at, home) <= 3
		var/far = get_dist(at, target) > 40
		if ((home_free || far) && !ecology_visible_to_players(at, NOMAD_RAID_VIEW_MARGIN))
			escape(H)
			continue
		step_toward(H, home, 0)
	if (!alive_members().len)
		finish(outcome ? outcome : "the raiders left")

// Leaves the map with what they carry.
/datum/nomad_raid/proc/escape(mob/living/human/H)
	var/carried = 0
	for (var/obj/item/I in stolen)
		if (!QDELETED(I) && nomad_raid_holder(I) == H)
			carried++
	escaped++
	escaped_items += carried
	members -= H
	qdel(H)

// A fallen raider drops what they stole, their weapon and their bag.
/datum/nomad_raid/proc/drop_loot(mob/living/human/H)
	if (H in fallen)
		return
	fallen += H
	var/turf/T = get_turf(H)
	if (!T)
		return
	for (var/obj/item/I in stolen)
		if (!QDELETED(I) && nomad_raid_holder(I) == H)
			if (istype(I.loc, /obj/item/weapon/storage))
				var/obj/item/weapon/storage/S = I.loc
				S.remove_from_storage(I, T)
			else
				H.unEquip(I)
				I.forceMove(T)
	var/obj/item/W = weapon[H]
	if (W && !QDELETED(W) && nomad_raid_holder(W) == H)
		H.unEquip(W)
		W.forceMove(T)
	if (H.back)
		var/obj/item/B = H.back
		H.unEquip(B)
		B.forceMove(T)

/datum/nomad_raid/proc/step_toward(mob/living/human/H, atom/dest, reach = 1)
	if (!H || !dest || world.time < (next_step[H] || 0))
		return FALSE
	if (H.stat != CONSCIOUS || !H.canmove || H.restrained() || H.buckled)
		return FALSE
	var/turf/here = get_turf(H)
	var/turf/there = get_turf(dest)
	if (!here || !there || here.z != there.z || get_dist(here, there) <= reach)
		return FALSE
	// Cardinal steps only: a diagonal Move splits into two steps and can
	// slide sideways when one is blocked. The longer axis goes first.
	var/turf/next = get_step_to(H, there)
	var/d = next ? get_dir(here, next) : get_dir(here, there)
	var/list/dirs
	if (d & (d - 1))
		var/h = d & (EAST|WEST)
		var/v = d & (NORTH|SOUTH)
		dirs = abs(there.x - here.x) >= abs(there.y - here.y) ? list(h, v) : list(v, h)
	else
		dirs = list(d, pick(turn(d, 90), turn(d, -90)))
	usr = H
	for (var/dir in dirs)
		H.Move(get_step(H, dir), dir)
		if (get_turf(H) != here)
			break
	next_step[H] = world.time + max(1, H.movement_delay())
	return get_turf(H) != here

// Ends with everyone gone: survivors drop their loot first, so nothing is lost.
/datum/nomad_raid/proc/remove_all(reason)
	for (var/mob/living/human/H in members.Copy())
		if (!QDELETED(H))
			drop_loot(H)
			qdel(H)
	members.Cut()
	finish(reason)

/datum/nomad_raid/proc/send_home(reason)
	if (state == "ended")
		return
	speak("Enough. We go.", force = TRUE)
	set_state("leave", reason)

/datum/nomad_raid/proc/finish(reason)
	if (state == "ended")
		return
	state = "ended"
	log_event("ended - [reason]. [escaped] of [initial_size] raiders escaped with [escaped_items] stolen items; [fallen.len] fell.")
	if (nomad_raid == src)
		nomad_raid = null

/datum/nomad_raid/proc/status_text()
	var/list/alive = alive_members()
	return "[clan]: [state] for [round((world.time - state_at) / 10)] s, [alive.len] of [initial_size] raiders standing, [stolen.len] items taken, target [target.x],[target.y],[target.z], home [home.x],[home.y],[home.z][tribute_demand ? ", tribute demand [tribute_demand]" : ""]."

// Starts a raid on a turf. Returns null on success, else why not.
/proc/start_nomad_raid(turf/target, list/ckeys, size, by)
	if (nomad_raid)
		return "a raid is already running"
	if (!target)
		return "no target"
	if (persistence_active_operation || persistence_save_in_progress)
		return "a world save is running"
	nomad_raid_load_cooldowns()
	var/datum/nomad_raid/R = new
	var/error = R.setup(target, ckeys, size, by)
	if (error)
		R.remove_all("could not start: [error]")
		qdel(R)
		return error
	nomad_raid = R
	R.begin()
	return null

// ---------------------------------------------------------------------------
// Admin verbs (Fun). Added to the fun verb list at startup.

/hook/startup/proc/nomad_raid_admin_verbs()
	admin_verbs_fun |= list(/client/proc/start_nomad_raid_verb, /client/proc/end_nomad_raid_verb, /client/proc/nomad_raid_status_verb)
	return TRUE

/client/proc/start_nomad_raid_verb()
	set category = "Fun"
	set name = "Start Nomad Raid"
	if (!check_rights(R_FUN))
		return
	if (nomad_raid)
		to_chat(src, SPAN_WARNING("A nomad raid is already running: [nomad_raid.status_text()]"))
		return
	var/how = input(src, "Who should the raiders go for?", "Nomad raid") as null|anything in list("Busiest settlement", "A player", "My location")
	if (!how)
		return
	var/turf/T
	var/list/ckeys = list()
	switch (how)
		if ("Busiest settlement")
			var/list/picked = nomad_raid_pick(nomad_raid_candidates())
			if (!picked)
				to_chat(src, SPAN_WARNING("No group of [NOMAD_RAID_MIN_DEFENDERS] or more active players is off cooldown."))
				return
			T = picked["turf"]
			ckeys = picked["ckeys"]
		if ("A player")
			var/list/choices = list()
			for (var/client/C in clients)
				if (nomad_raid_defender(C.mob))
					choices["[C.mob.real_name] ([C.ckey])"] = C.mob
			var/choice = input(src, "Target player", "Nomad raid") as null|anything in choices
			if (!choice)
				return
			var/mob/M = choices[choice]
			T = get_turf(M)
			for (var/mob/living/human/H in nomad_raid_defenders_near(T))
				ckeys += H.ckey
		if ("My location")
			T = get_turf(mob)
			for (var/mob/living/human/H in nomad_raid_defenders_near(T))
				ckeys += H.ckey
	var/size = input(src, "Raiders, including the chieftain ([NOMAD_RAID_MIN_MEMBERS] to [NOMAD_RAID_MAX_MEMBERS])", "Nomad raid", 4) as null|num
	if (isnull(size))
		return
	var/error = start_nomad_raid(T, ckeys, size, key_name(src))
	if (error)
		to_chat(src, SPAN_WARNING("The raid could not start: [error]."))
	else
		to_chat(src, SPAN_NOTICE("Nomad raid started. [nomad_raid.status_text()]"))

/client/proc/end_nomad_raid_verb()
	set category = "Fun"
	set name = "End Nomad Raid"
	if (!check_rights(R_FUN))
		return
	if (!nomad_raid)
		to_chat(src, SPAN_NOTICE("No nomad raid is running."))
		return
	var/how = input(src, "End the raid how?", "Nomad raid") as null|anything in list("Send them home", "Remove them now")
	if (!how || !nomad_raid)
		return
	if (how == "Send them home")
		nomad_raid.send_home("sent home by [key_name(src)]")
	else
		nomad_raid.remove_all("removed by [key_name(src)]")

/client/proc/nomad_raid_status_verb()
	set category = "Fun"
	set name = "Nomad Raid Status"
	if (!check_rights(R_FUN))
		return
	to_chat(src, SPAN_NOTICE(nomad_raid ? nomad_raid.status_text() : "No nomad raid is running."))

// The mob carrying an item, through bags and pockets.
/proc/nomad_raid_holder(atom/movable/A)
	var/atom/at = A ? A.loc : null
	while (at && !isturf(at))
		if (ismob(at))
			return at
		at = at.loc
	return null
