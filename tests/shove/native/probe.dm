// Full production source with existing startup-neutralized human fixture.
// Placement is fixture setup only. Assertions invoke the real shove helper.
var/shove_fixture_checks = 0

/proc/shove_check(condition, label)
	shove_fixture_checks++
	if (!condition)
		throw EXCEPTION(label)

/proc/shove_actor(tx, ty)
	var/mob/living/human/subtile_fixture/H = human_subtile_fixture_actor(tx, ty)
	H.stats["stamina"][1] = 100
	H.set_human_subtile(TRUE)
	H.a_intent = I_HELP
	return H

/proc/shove_dispose(mob/living/H)
	if (H)
		H.loc = null
		qdel(H)

/proc/shove_fixture()
	shove_check(world.byond_version == 516 && world.byond_build == 1688, "shove_engine")
	for (var/direction in list(EAST, WEST, NORTH, SOUTH))
		for (var/offset in list(-14, 0, 14))
			var/mob/living/human/subtile_fixture/T = shove_actor(8, 7)
			var/turf/start = get_step(T, turn(direction, 180))
			var/mob/living/human/subtile_fixture/U = shove_actor(start.x, start.y)
			T.step_x = offset
			U.step_x = offset
			T.human_subtile_offset_owned = !!offset
			U.human_subtile_offset_owned = !!offset
			var/px = T.x * 32 + T.step_x
			var/py = T.y * 32 + T.step_y
			var/moved = T.try_deliberate_shove(U)
			var/dx = direction == EAST ? 32 : direction == WEST ? -32 : 0
			var/dy = direction == NORTH ? 32 : direction == SOUTH ? -32 : 0
			shove_check(moved && T.x * 32 + T.step_x == px + dx && T.y * 32 + T.step_y == py + dy, "shove_cardinal_[direction]_offset_[offset]")
			shove_check(T.fixture_pulses == 16 && T.fixture_human_completions == 1 && T.fixture_living_completions == 1 && !T.human_subtile_transaction && !T.human_subtile_pulse, "shove_pulse_ownership_[direction]_[offset]")
			shove_check(U.stats["stamina"][1] == 90 && U.next_deliberate_shove == world.time + 20 && U.next_move >= world.time + 20 && T.shove_recovery_until == world.time + 30 && !T.weakened, "shove_cost_recovery_[direction]_[offset]")
			shove_dispose(U)
			shove_dispose(T)
	var/mob/living/human/subtile_fixture/T = shove_actor(4, 4)
	var/mob/living/human/subtile_fixture/U = shove_actor(3, 4)
	var/turf/wall = locate(5, 4, 1)
	wall.density = TRUE
	shove_check(!T.try_deliberate_shove(U) && T.x == 4 && !T.step_x && !T.weakened && !T.shove_recovery_until, "shove_wall_no_stun")
	wall.density = FALSE
	U.next_deliberate_shove = 0
	var/mob/living/human/subtile_fixture/B = shove_actor(5, 4)
	shove_check(!T.try_deliberate_shove(U) && T.x == 4 && !T.step_x && B.x == 5 && !B.step_x, "shove_help_body_blocks")
	shove_dispose(B)
	U.next_deliberate_shove = 0
	T.anchored = TRUE
	shove_check(!T.try_deliberate_shove(U) && T.x == 4, "shove_anchored")
	T.anchored = FALSE
	U.next_deliberate_shove = 0
	T.set_human_subtile(FALSE)
	shove_check(!T.try_deliberate_shove(U) && !T.step_x && !T.human_subtile_enabled, "shove_legacy_not_stranded")
	T.set_human_subtile(TRUE)
	U.next_deliberate_shove = 0
	U.stats["stamina"][1] = 9
	shove_check(!T.try_deliberate_shove(U) && U.stats["stamina"][1] == 9 && !U.next_deliberate_shove, "shove_exhaustion")
	U.stats["stamina"][1] = 100
	U.loc = locate(1, 4, 1)
	shove_check(!T.try_deliberate_shove(U) && U.stats["stamina"][1] == 100, "shove_out_of_range")
	U.loc = locate(3, 4, 1)
	T.pulling = U
	U.pulledby = T
	shove_check(T.try_deliberate_shove(U) && !T.pulling && !U.pulledby && T.x == 4 && !T.step_x, "shove_break_grip_only")
	U.next_deliberate_shove = 0
	T.shove_recovery_until = world.time + 30
	var/stamina = U.stats["stamina"][1]
	shove_check(!T.try_deliberate_shove(U) && U.stats["stamina"][1] == stamina, "shove_anti_chain")
	T.shove_recovery_until = 0
	T.mob_size = U.mob_size + 1
	shove_check(!T.try_deliberate_shove(U) && T.x == 4, "shove_larger_body")
	shove_dispose(T)
	shove_dispose(U)
