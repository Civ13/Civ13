// Nomad visits (docs/nomad-raids.md): raiding parties and trader caravans.
// Admin-started, default off.
//
// A party of nomads spawns out of sight at the map edge nearest a settled
// group of active players and walks in. Raiders demand tribute, fight if
// refused or attacked, loot loose items and unlocked crates, and walk back
// off the map. Traders set up a stall, sell goods for payment laid at their
// feet and leave; stealing from them turns them hostile.
//
// Party members are human NPCs (simple_animal/hostile/human), so fights use
// the existing NPC combat AI: target choice, cover, retreat, calls for backup
// and pathfinding. The party controller (nomad_visit.dm) only gives orders:
// where to walk, when to turn hostile, whom to focus, when to loot or leave.
// An agent-control coordinator (an LLM) may voice the leader and pick
// tactics through the same orders, inside limits the controller enforces.
//
// Nothing here is saved: a restart ends a visit, and the controller pauses
// during saves. Cooldowns use world.realtime in data/nomad_raids.json.

#define NOMAD_RAID_STEP 2 // deciseconds between controller passes
#define NOMAD_RAID_DECIDE (1 SECONDS) // target and loot choices
#define NOMAD_RAID_MIN_MEMBERS 2
#define NOMAD_RAID_MAX_MEMBERS 6
#define NOMAD_RAID_MIN_DEFENDERS 2 // automatic targeting skips smaller groups
#define NOMAD_RAID_GROUP_RANGE 20
#define NOMAD_RAID_PARLEY_RANGE 10
#define NOMAD_RAID_SIGHTED_RANGE 6 // the party halts only once a player is this close and can see it coming
#define NOMAD_RAID_FIGHT_RANGE 12
#define NOMAD_RAID_LOOT_RANGE 8
#define NOMAD_RAID_EDGE_LIMIT 120 // farthest spawn distance from the target
#define NOMAD_RAID_EDGE_SPREAD 30
#define NOMAD_RAID_ROUTE_LEG 10 // route tiles per walking leg; the NPC pathfinder plans short hops well
#define NOMAD_RAID_ROUTE_REACH 3 // the planned walk ends this close to the target, as a boat landing does
#define NOMAD_RAID_RETARGET (5 SECONDS) // how often a march checks where its target players went
#define NOMAD_RAID_CUFF_CHANCE 35 // percent of raiders who carry restraints (nomad_capture.dm)
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
#define NOMAD_RAID_FACTION "Nomad Raiders"
#define NOMAD_RAID_CARRY 12 // total w_class a party member carries
#define NOMAD_RAID_EARLY_ASSAULT (30 SECONDS) // shortest parley before a coordinator may attack
#define NOMAD_RAID_VOICE_GRACE (8 SECONDS) // a cue the coordinator does not voice in time is said as written
#define NOMAD_RAID_VOICE_SEEN (10 SECONDS) // a coordinator counts as attached this long after its last status read
#define NOMAD_RAID_LOG_MAX 40
#define NOMAD_TRADE_TIME (12 MINUTES)
#define NOMAD_TRADE_WAIT (25 MINUTES) // longest a caravan waits at its stall for the players it came for
#define NOMAD_TRADE_TOTAL_LIMIT (45 MINUTES)
#define NOMAD_TRADE_THEFT_GRACE (15 SECONDS)
#define NOMAD_TRADE_GOODS 6

var/global/datum/nomad_raid/nomad_raid = null // the one running visit, raid or trade
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
		// March on the middle of the group, not on whichever member was found first.
		var/sx = 0
		var/sy = 0
		for (var/mob/M in group)
			sx += M.x
			sy += M.y
		var/turf/mid = locate(round(sx / group.len), round(sy / group.len), T.z)
		if (!mid || mid.density || istype(mid, /turf/floor/beach/water/deep))
			mid = T
		out += list(list("turf" = mid, "ckeys" = ckeys, "score" = nomad_raid_score(mid, group.len)))
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
	var/error = nomad_raid_ground_error(T)
	if (error)
		return error
	if (ecology_visible_to_players(T, NOMAD_RAID_VIEW_MARGIN))
		return "visible"
	return null

// Open, outdoor, unroofed, unoccupied ground.
/proc/nomad_raid_ground_error(turf/T)
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

// What a loose item is worth to a raider; 0 means leave it.
/proc/nomad_raid_worth(obj/item/I, held = FALSE)
	if (!istype(I) || I.anchored || (!held && !isturf(I.loc)) || I.w_class > ITEM_SIZE_LARGE)
		return 0
	var/base = I.value
	if (istype(I, /obj/item/stack))
		var/obj/item/stack/S = I
		base = I.value * max(1, S.amount)
	var/worth = max(1, round(base))
	if (istype(I, /obj/item/weapon/material) || istype(I, /obj/item/weapon/gun))
		worth += 5
	if (istype(I, /obj/item/weapon/reagent_containers/food))
		worth += 2
	return worth

// The mob carrying an item, through bags and pockets.
/proc/nomad_raid_holder(atom/movable/A)
	var/atom/at = A ? A.loc : null
	while (at && !isturf(at))
		if (ismob(at))
			return at
		at = at.loc
	return null

// The turf dist tiles from T toward dir, kept on the map.
/proc/nomad_raid_offset(turf/T, dir, dist)
	if (!T)
		return null
	var/x = T.x
	var/y = T.y
	if (dir & NORTH)
		y += dist
	if (dir & SOUTH)
		y -= dist
	if (dir & EAST)
		x += dist
	if (dir & WEST)
		x -= dist
	return locate(clamp(x, 1, world.maxx), clamp(y, 1, world.maxy), T.z)
