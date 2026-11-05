// Zombie city horde: most of a city's zombies are numbers, not mobs.
//
// The city generator registers each block with a density
// (zombie_horde_add_block). A block holds a count of zombies. Real zombies are
// only made out of sight of players and within ZOMBIE_HORDE_ACTIVE_RANGE of
// one; a zombie with no player near it for ZOMBIE_HORDE_FOLD_DELAY folds back
// into its block's count. Kills lower the count, so a cleared block stays
// cleared until the city is generated again. Gunfire (zombie_horde_noise) pulls
// nearby zombies toward the sound.
//
// Inert until a block is registered, so ordinary maps never start the loop.

#define ZOMBIE_HORDE_TICK 30
#define ZOMBIE_HORDE_ACTIVE_RANGE 20
#define ZOMBIE_HORDE_MIN_SPAWN_DIST 9
#define ZOMBIE_HORDE_FOLD_DELAY 600
#define ZOMBIE_HORDE_WORLD_CAP 60
#define ZOMBIE_HORDE_PLAYER_CAP 15
#define ZOMBIE_HORDE_SPAWNS_PER_TICK 3
#define ZOMBIE_HORDE_NOISE_MEMORY 300
#define ZOMBIE_HORDE_SCENT_RANGE 15

var/global/datum/zombie_horde/zombie_horde = null

// Zombies a block starts with, by the generator's density tag.
var/global/list/zombie_horde_density_counts = list(
	"sparse" = 2,
	"normal" = 5,
	"dense" = 10,
	"infested" = 18)

/proc/zombie_horde_add_block(block_id, turf/lo, turf/hi, density)
	if (!istype(lo) || !istype(hi) || lo.z != hi.z || isnull(block_id))
		return null
	if (!(density in zombie_horde_density_counts))
		return null
	if (!zombie_horde)
		zombie_horde = new
	return zombie_horde.add_block("[block_id]", lo, hi, density)

/proc/zombie_horde_noise(turf/T, range)
	if (!zombie_horde || !T)
		return
	zombie_horde.noise(T, range)

/datum/zombie_horde_block
	var/id
	var/x1
	var/y1
	var/x2
	var/y2
	var/z
	var/density
	var/count = 0
	var/list/live = list()

/datum/zombie_horde_block/proc/distance_to(turf/T)
	if (T.z != z)
		return INFINITY
	var/dx = T.x < x1 ? x1 - T.x : (T.x > x2 ? T.x - x2 : 0)
	var/dy = T.y < y1 ? y1 - T.y : (T.y > y2 ? T.y - y2 : 0)
	return max(dx, dy)

/datum/zombie_horde
	var/list/blocks = list() // id = block
	var/list/live = list()
	var/list/people = list() // anchors as of the last tick
	var/running = FALSE
	var/spawned_total = 0
	var/folded_total = 0
	var/killed_total = 0

/datum/zombie_horde/proc/add_block(id, turf/lo, turf/hi, density)
	var/datum/zombie_horde_block/B = blocks[id]
	if (!B)
		B = new
		B.id = id
		blocks[id] = B
	B.x1 = min(lo.x, hi.x)
	B.x2 = max(lo.x, hi.x)
	B.y1 = min(lo.y, hi.y)
	B.y2 = max(lo.y, hi.y)
	B.z = lo.z
	B.density = density
	B.count = zombie_horde_density_counts[density]
	if (!running)
		running = TRUE
		addtimer(CALLBACK(src, PROC_REF(loop_step)), ZOMBIE_HORDE_TICK, TIMER_LOOP)
	return B

/datum/zombie_horde/proc/total_virtual()
	. = 0
	for (var/id in blocks)
		var/datum/zombie_horde_block/B = blocks[id]
		. += B.count

/datum/zombie_horde/proc/loop_step()
	if (persistence_active_operation || persistence_save_in_progress)
		return
	try
		tick()
	catch (var/exception/E)
		log_debug("Zombie horde tick error: [E] [E.file]:[E.line]")

// Living humans that hold zombies in the world: players, and bodies marked
// as anchors (headless probes).
/datum/zombie_horde/proc/anchors()
	var/list/out = list()
	for (var/mob/living/human/H in human_mob_list)
		if (H.stat == DEAD || !isturf(H.loc))
			continue
		if (H.client || H.zombie_horde_anchor)
			out += H
	return out

/datum/zombie_horde/proc/tick()
	var/list/people = anchors()
	src.people = people
	// Fold back zombies far from everyone.
	for (var/mob/living/simple_animal/hostile/human/zombie/horde/Z in live.Copy())
		if (QDELETED(Z) || Z.stat == DEAD)
			live -= Z
			continue
		var/near = FALSE
		for (var/mob/living/human/H in people)
			if (H.z == Z.z && get_dist(H, Z) <= ZOMBIE_HORDE_ACTIVE_RANGE)
				near = TRUE
				break
		if (near)
			Z.horde_alone_since = 0
		else if (!Z.horde_alone_since)
			Z.horde_alone_since = world.time
		else if (world.time - Z.horde_alone_since >= ZOMBIE_HORDE_FOLD_DELAY)
			fold(Z)
	if (!people.len)
		return
	// Bring zombies in around players, out of sight.
	var/made = 0
	for (var/mob/living/human/H in shuffle(people))
		if (made >= ZOMBIE_HORDE_SPAWNS_PER_TICK || live.len >= ZOMBIE_HORDE_WORLD_CAP)
			break
		var/nearby = 0
		for (var/mob/living/simple_animal/hostile/human/zombie/horde/Z in live)
			if (Z.z == H.z && get_dist(Z, H) <= ZOMBIE_HORDE_ACTIVE_RANGE)
				nearby++
		if (nearby >= ZOMBIE_HORDE_PLAYER_CAP)
			continue
		var/datum/zombie_horde_block/B = pick_block_near(get_turf(H))
		if (!B)
			continue
		var/turf/T = spawn_turf(B, H, people)
		if (!T)
			continue
		if (materialize(B, T))
			made++

/datum/zombie_horde/proc/pick_block_near(turf/center)
	var/list/weights = list()
	for (var/id in blocks)
		var/datum/zombie_horde_block/B = blocks[id]
		if (B.count <= 0)
			continue
		if (B.distance_to(center) > ZOMBIE_HORDE_ACTIVE_RANGE)
			continue
		weights[B] = B.count
	if (!weights.len)
		return null
	return pickweight(weights)

/datum/zombie_horde/proc/spawn_turf(datum/zombie_horde_block/B, mob/living/human/H, list/people)
	for (var/i in 1 to 8)
		var/turf/T = locate(rand(B.x1, B.x2), rand(B.y1, B.y2), B.z)
		if (!T || T.density)
			continue
		var/d = get_dist(T, H)
		if (d < ZOMBIE_HORDE_MIN_SPAWN_DIST || d > ZOMBIE_HORDE_ACTIVE_RANGE)
			continue
		var/blocked = FALSE
		for (var/atom/movable/A in T)
			if (A.density)
				blocked = TRUE
				break
		if (blocked)
			continue
		var/seen = FALSE
		for (var/mob/living/human/P in people)
			if (P.z == T.z && get_dist(P, T) < ZOMBIE_HORDE_MIN_SPAWN_DIST)
				seen = TRUE
				break
		if (!seen)
			return T
	return null

/datum/zombie_horde/proc/materialize(datum/zombie_horde_block/B, turf/T)
	if (B.count <= 0)
		return null
	B.count--
	var/mob/living/simple_animal/hostile/human/zombie/horde/Z = new(T)
	Z.horde_block = B
	B.live += Z
	live += Z
	spawned_total++
	return Z

/datum/zombie_horde/proc/fold(mob/living/simple_animal/hostile/human/zombie/horde/Z)
	var/datum/zombie_horde_block/B = Z.horde_block
	if (B)
		B.count++
		B.live -= Z
	live -= Z
	folded_total++
	Z.horde_block = null
	qdel(Z)

/datum/zombie_horde/proc/on_death(mob/living/simple_animal/hostile/human/zombie/horde/Z)
	var/datum/zombie_horde_block/B = Z.horde_block
	if (B)
		B.live -= Z
	live -= Z
	killed_total++

/datum/zombie_horde/proc/noise(turf/T, range)
	for (var/mob/living/simple_animal/hostile/human/zombie/horde/Z in live)
		if (Z.z == T.z && Z.stat == CONSCIOUS && !Z.target_mob && get_dist(Z, T) <= range)
			Z.hear_noise(T)

/datum/zombie_horde/proc/status()
	return list("blocks" = blocks.len, "virtual" = total_virtual(), "live" = live.len, "spawned" = spawned_total, "folded" = folded_total, "killed" = killed_total)

/mob/living/human/var/tmp/zombie_horde_anchor = FALSE

/mob/living/simple_animal/hostile/human/zombie/horde
	name = "\improper zombie"
	starves = FALSE
	wander = FALSE
	stop_automated_movement = TRUE
	var/tmp/datum/zombie_horde_block/horde_block
	var/tmp/horde_alone_since = 0
	var/tmp/horde_next_think = 0
	var/tmp/horde_next_bite = 0
	var/tmp/horde_noise_until = 0
	var/tmp/turf/horde_noise_turf

/mob/living/simple_animal/hostile/human/zombie/horde/New()
	..()
	should_save = FALSE

/mob/living/simple_animal/hostile/human/zombie/horde/do_human_behaviour()
	return

/mob/living/simple_animal/hostile/human/zombie/horde/proc/hear_noise(turf/T)
	horde_noise_turf = T
	horde_noise_until = world.time + ZOMBIE_HORDE_NOISE_MEMORY
	horde_next_think = 0

/mob/living/simple_animal/hostile/human/zombie/horde/proc/find_prey()
	var/mob/living/human/best
	var/best_d = 8
	// hearers() ignores darkness: zombies find prey at night too, still not through walls.
	for (var/mob/living/human/H in hearers(7, src))
		if (H.stat == DEAD)
			continue
		var/d = get_dist(src, H)
		if (d < best_d)
			best = H
			best_d = d
	return best

/mob/living/simple_animal/hostile/human/zombie/horde/handle_ai()
	if (stat != CONSCIOUS || !isturf(loc) || world.time < horde_next_think)
		return
	horde_next_think = world.time + 10
	var/mob/living/human/prey = find_prey()
	target_mob = prey
	if (prey)
		stance = HOSTILE_STANCE_ATTACK
		horde_noise_turf = null
		if (Adjacent(prey))
			walk(src, 0)
			if (world.time >= horde_next_bite)
				horde_next_bite = world.time + 12
				AttackingTarget()
		else
			walk_to(src, prey, 1, move_to_delay)
		return
	stance = HOSTILE_STANCE_IDLE
	if (horde_noise_turf && world.time < horde_noise_until)
		if (get_dist(src, horde_noise_turf) <= 1)
			horde_noise_turf = null
			walk(src, 0)
		else
			walk_to(src, horde_noise_turf, 1, move_to_delay + 2)
		return
	horde_noise_turf = null
	// Out of sight, a zombie still shambles toward the nearest living person it
	// can smell, so a block's zombies close in on players rather than idle.
	var/mob/living/human/scent = find_scent()
	if (scent)
		walk_to(src, scent, 1, move_to_delay + 4)
		return
	walk(src, 0)
	if (prob(15))
		step(src, pick(cardinal))

/mob/living/simple_animal/hostile/human/zombie/horde/proc/find_scent()
	if (!zombie_horde)
		return null
	var/mob/living/human/best
	var/best_d = ZOMBIE_HORDE_SCENT_RANGE + 1
	for (var/mob/living/human/H in zombie_horde.people)
		if (QDELETED(H) || H.stat == DEAD || H.z != z)
			continue
		var/d = get_dist(src, H)
		if (d < best_d)
			best = H
			best_d = d
	return best

/mob/living/simple_animal/hostile/human/zombie/horde/death()
	if (stat == DEAD)
		return
	walk(src, 0)
	target_mob = null
	horde_noise_turf = null
	..()
	if (zombie_horde)
		zombie_horde.on_death(src)
	// The city is never saved; clear corpses so a long cycle does not pile them up.
	addtimer(CALLBACK(src, PROC_REF(clear_corpse)), 3000)

/mob/living/simple_animal/hostile/human/zombie/horde/proc/clear_corpse()
	if (!QDELETED(src) && stat == DEAD)
		qdel(src)

/mob/living/simple_animal/hostile/human/zombie/horde/Destroy()
	walk(src, 0)
	if (zombie_horde && (src in zombie_horde.live))
		zombie_horde.on_death(src)
	horde_block = null
	horde_noise_turf = null
	target_mob = null
	return ..()

#undef ZOMBIE_HORDE_NOISE_MEMORY
#undef ZOMBIE_HORDE_SCENT_RANGE
