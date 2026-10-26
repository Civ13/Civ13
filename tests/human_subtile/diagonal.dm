// Current-engine acceptance in the existing isolated, full-source fixture.
var/human_subtile_diagonal_checks = 0

/proc/human_subtile_diagonal_assert(ok, label)
	human_subtile_diagonal_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/human_subtile_fixture_diagonal()
	human_subtile_diagonal_assert(world.byond_version == 516 && world.byond_build == 1688, "diagonal_current_engine")
	for (var/direction in list(NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST))
		var/mob/living/human/subtile_fixture/H = human_subtile_fixture_actor(8, 7)
		human_subtile_diagonal_assert(!H.human_subtile_enabled && H.human_subtile_default_pending, "default_waits_for_safe_input")
		human_subtile_diagonal_assert(H.human_subtile_input_supported(direction) && H.human_subtile_eligible(direction) && !H.human_subtile_default_pending, "default_uses_safe_setter")
		var/start = world.time
		var/px = H.x * 32
		var/py = H.y * 32
		H.SelfMove(get_step(H, direction), direction, start + 4)
		var/dx = (direction & EAST) ? 2 : -2
		var/dy = (direction & NORTH) ? 2 : -2
		human_subtile_diagonal_assert(H.fixture_pulses == 16 && H.x * 32 + H.step_x - px == dx * 16 && H.y * 32 + H.step_y - py == dy * 16, "diagonal_32px_per_axis")
		var/last_x = px
		var/last_y = py
		for (var/list/row in H.fixture_rows)
			var/next_x = row["x"] * 32 + row["sx"]
			var/next_y = row["y"] * 32 + row["sy"]
			human_subtile_diagonal_assert(next_x - last_x == dx && next_y - last_y == dy, "diagonal_each_pulse_two_pixels_both_axes")
			last_x = next_x
			last_y = next_y
		human_subtile_diagonal_assert(world.time <= start + 4 + world.tick_lag && H.fixture_human_completions == 1 && H.fixture_living_completions == 1 && !H.human_subtile_transaction && !H.human_subtile_pulse, "diagonal_interval_hooks_cleanup")
		human_subtile_diagonal_assert(abs(H.glide_size - 4 * ROOT2_FAST) < 0.001 && H.human_subtile_glide_owned, "diagonal_interpolation_matches_physical_interval")
		human_subtile_fixture_rows += list(list("scene" = "diagonal_[direction]", "rows" = H.fixture_rows))
		qdel(H)

	var/mob/living/human/subtile_fixture/C = human_subtile_fixture_actor(8, 7)
	C.human_subtile_input_supported(EAST)
	C.fixture_cancel_after = 1
	C.SelfMove(get_step(C, EAST), EAST, world.time + 4)
	C.fixture_authorized = TRUE
	C.fixture_cancel_after = 0
	human_subtile_fixture_reset(C)
	C.SelfMove(get_step(C, NORTHEAST), NORTHEAST, world.time + 4)
	human_subtile_diagonal_assert(C.x == 9 && C.y == 8 && C.step_x == 2 && C.step_y == 0 && C.fixture_pulses == 16, "cardinal_offset_to_diagonal")
	human_subtile_fixture_reset(C)
	C.SelfMove(get_step(C, WEST), WEST, world.time + 4)
	human_subtile_diagonal_assert(C.x == 8 && C.y == 8 && C.step_x == 2 && C.fixture_pulses == 16, "diagonal_offset_to_cardinal")
	human_subtile_diagonal_assert(!C.set_human_subtile(FALSE), "offset_optout_refused_without_snapping")
	C.fixture_cancel_after = 1
	human_subtile_fixture_reset(C)
	C.SelfMove(get_step(C, NORTHWEST), NORTHWEST, world.time + 4)
	human_subtile_diagonal_assert(C.x == 8 && C.y == 8 && C.step_x == 0 && C.step_y == 2 && C.fixture_pulses == 1 && !C.human_subtile_transaction && !C.human_subtile_pulse, "diagonal_cancel_retains_physical_position")
	C.fixture_authorized = TRUE
	C.fixture_cancel_after = 0
	C.SelfMove(get_step(C, SOUTH), SOUTH, world.time + 4)
	// Offset remains 2px modulo a tile; use the actual capsule seam to place at
	// alignment for opt-out, just as the existing restoration fixture does.
	human_subtile_fixture_place(C, 0, 0)
	human_subtile_diagonal_assert(C.set_human_subtile(FALSE) && C.human_subtile_input_supported(NORTHEAST) && !C.human_subtile_enabled && !C.human_subtile_default_pending, "explicit_optout_survives_input")
	qdel(C)

	// Native footprint collision must stop both-axis corner penetration. A
	// partial native slide is permitted, but cannot continue as a tile fallback.
	for (var/wall_direction in list(NORTH, EAST, NORTHEAST))
		var/mob/living/human/subtile_fixture/W = human_subtile_fixture_actor(8, 7)
		W.human_subtile_input_supported(NORTHEAST)
		var/turf/wall = get_step(W, wall_direction)
		wall.density = TRUE
		W.SelfMove(get_step(W, NORTHEAST), NORTHEAST, world.time + 4)
		human_subtile_diagonal_assert(W.x == 8 && W.y == 7 && W.step_x <= 2 && W.step_y <= 2 && W.fixture_pulses == 1 && !W.human_subtile_transaction && !W.human_subtile_pulse, "corner_native_collision_no_tile_fallback")
		wall.density = FALSE
		qdel(W)

	var/mob/living/human/subtile_fixture/G = human_subtile_fixture_actor(8, 7)
	G.stat = DEAD
	G.human_subtile_input_supported(NORTHEAST)
	human_subtile_diagonal_assert(!G.human_subtile_enabled && G.human_subtile_default_pending, "dead_body_not_default_enabled")
	G.stat = CONSCIOUS
	G.canmove = TRUE
	human_subtile_diagonal_assert(G.human_subtile_input_supported(NORTHEAST) && G.human_subtile_enabled, "revived_body_default_on_first_safe_input")
	qdel(G)
	var/mob/living/human/subtile_fixture/L = human_subtile_fixture_actor(8, 7)
	human_subtile_fixture_place(L, 4, 4)
	var/savefile/F = new("diagonal-roundtrip.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, L, 1)
	F.cd = map_storage.entry_path(F, ref)
	human_subtile_diagonal_assert(!("human_subtile_default_pending" in F.dir), "default_initialization_is_runtime_only")
	F.Flush()
	F = null
	qdel(L)
	F = new("diagonal-roundtrip.sav")
	map_storage.clear_bookkeeping()
	var/mob/living/human/subtile_fixture/loaded = map_storage.Load_Entry(F, ref, starting_loc = locate(8, 7, 1))
	loaded.after_load()
	human_subtile_diagonal_assert(!loaded.human_subtile_enabled && loaded.human_subtile_default_pending && loaded.step_x == 4 && loaded.step_y == 4 && !loaded.human_subtile_transaction, "diagonal_codec_restores_both_axes_without_worker")
	human_subtile_diagonal_assert(loaded.human_subtile_input_supported(SOUTHWEST) && loaded.human_subtile_enabled && loaded.step_x == 4 && loaded.step_y == 4, "owned_restore_default_without_snap")
	qdel(loaded)
	var/mob/living/human/subtile_fixture/O = human_subtile_fixture_actor(8, 7)
	O.bound_width = 16
	O.human_subtile_input_supported(NORTHEAST)
	human_subtile_diagonal_assert(!O.human_subtile_enabled && O.human_subtile_default_pending, "ineligible_geometry_keeps_legacy")
	O.bound_width = 32
	O.human_subtile_transaction = new
	human_subtile_diagonal_assert(!O.human_subtile_initialize_default(NORTHEAST) && O.human_subtile_default_pending, "default_cannot_bypass_busy_setter")
	O.human_subtile_transaction = null
	human_subtile_diagonal_assert(O.human_subtile_deadline(104, 100, TRUE) == 100 + 4 * ROOT2_FAST && O.human_subtile_deadline(104, 100, FALSE) == 104, "diagonal_legacy_ordinal_cooldown")
	qdel(O)
	return TRUE
