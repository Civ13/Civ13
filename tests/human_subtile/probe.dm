// Full-source fixture: actual human constructors/Move/codec, isolated startup.
// Headless authority is an explicit adapter, NOT a native client simulation.
/world
	hub = ""
	hub_password = ""
	visibility = 0
	maxx = 18
	maxy = 14
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/subtile_fixture
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)
	return

/obj/map_metadata/subtile_fixture/New()
	map = src

/turf/floor/plating/subtile_fixture
	var/fixture_entries = 0

/turf/floor/plating/subtile_fixture/Entered(atom/A, atom/old)
	. = ..()
	if (istype(A, /mob/living/human/subtile_fixture))
		fixture_entries++

/obj/item/subtile_fixture_paid
	var/paid_marker = 731

/obj/item/clothing/shoes/subtile_fixture
	var/fixture_steps = 0

/obj/item/clothing/shoes/subtile_fixture/handle_movement(turf/walking, running)
	fixture_steps++
	return ..()

/mob/living/human/subtile_fixture
	var/fixture_authorized = TRUE
	var/fixture_cancel_after = 0
	var/fixture_delete_after = 0
	var/fixture_reenter = FALSE
	var/fixture_pulses = 0
	var/fixture_human_completions = 0
	var/fixture_living_completions = 0
	var/list/fixture_rows = list()
	// Stands in for the player's Toggle Tap To Step preference.
	var/fixture_tap_step = FALSE

/mob/living/human/subtile_fixture/human_subtile_authority(client/owner)
	if (client)
		return ..()
	return fixture_authorized

/mob/living/human/subtile_fixture/human_subtile_tap_step()
	return fixture_tap_step || ..()

/mob/living/human/subtile_fixture/persistence_runtime_var(key)
	return copytext(key, 1, 9) == "fixture_" || ..()

/mob/living/human/subtile_fixture/Move()
	var/owns_pulse = human_subtile_pulse && human_subtile_pulse.armed
	. = ..()
	if (owns_pulse && human_subtile_pulse)
		fixture_pulses++
		fixture_rows += list(list("at" = world.time, "x" = x, "y" = y, "sx" = step_x, "sy" = step_y, "locs" = locs.len, "native" = human_subtile_pulse.engine_return))
		if (fixture_reenter)
			fixture_reenter = FALSE
			Move(get_step(src, NORTH), NORTH)
		if (fixture_cancel_after && fixture_pulses >= fixture_cancel_after)
			fixture_authorized = FALSE
		if (fixture_delete_after && fixture_pulses >= fixture_delete_after)
			qdel(src)

/mob/living/human/subtile_fixture/human_movement_completed()
	fixture_human_completions++
	return ..()

/mob/living/human/subtile_fixture/living_movement_completed()
	fixture_living_completions++
	return ..()

var/human_subtile_fixture_checks = 0
var/list/human_subtile_fixture_rows = list()
var/list/human_subtile_fixture_client_rows = list()
var/human_subtile_fixture_phase = "initializing"

/proc/human_subtile_fixture_client_state(client/C, mob/living/human/H)
	return list("at" = world.time, "position" = H.human_subtile_snapshot(), "dir" = H.dir, "client_canmove" = C.canmove, "client_moving" = C.moving, "move_delay" = C.move_delay, "nutrition" = H.nutrition, "stamina" = H.stats["stamina"][1], "velocity" = H.velocity, "velocity_lastdir" = H.velocity_lastdir, "last_movement" = H.last_movement, "last_run_delay" = H.last_run_delay, "next_calculate_run_delay" = H.next_calculate_run_delay, "next_calculate_tally" = H.next_calculate_tally, "movement_speed_multiplier" = H.movement_speed_multiplier, "human_canmove" = H.canmove, "enabled" = H.human_subtile_enabled)

/proc/human_subtile_fixture_record_client(list/row)
	if (human_subtile_fixture_client_rows.len >= 12)
		throw EXCEPTION("Client diagnostic row bound exceeded")
	human_subtile_fixture_client_rows += list(row)
	// Append BEFORE assertions so a failing final comparison retains both rows.
	text2file(json_encode(row), "client-observations.jsonl")

/proc/human_subtile_fixture_wait(client/C)
	// Native fractional sleeps may wake before the client's exact deadline.
	while (C.move_delay > world.time)
		sleep(world.tick_lag)

/proc/human_subtile_fixture_assert(ok, label)
	human_subtile_fixture_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/human_subtile_fixture_initialize()
	config = new
	config.webhook_can_fire = FALSE
	config.ToRban = FALSE
	makeDatumRefLists()
	initialize_chemical_reagents()
	initialize_chemical_reactions()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	movementMachine = new
	map = new /obj/map_metadata/subtile_fixture
	return TRUE

var/human_subtile_fixture_deer_watched = FALSE
/mob/living/simple_animal/deer/subtile_fixture_watched/Life()
	return
/mob/living/simple_animal/deer/subtile_fixture_watched/npc_subtile_watched()
	return human_subtile_fixture_deer_watched

/proc/human_subtile_fixture_actor(tx, ty)
	var/mob/living/human/subtile_fixture/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.lastarea = get_area(H)
	H.persistence_owner_ckey = "fixture-owner"
	H.real_name = "Movement subject"
	H.name = H.real_name
	H.m_intent = "walk"
	H.equip_to_slot(new /obj/item/clothing/under/squid_contestant(H), slot_w_uniform)
	return H

/proc/human_subtile_fixture_reset(mob/living/human/subtile_fixture/H)
	H.fixture_pulses = 0
	H.fixture_rows = list()
	H.fixture_human_completions = 0
	H.fixture_living_completions = 0

/proc/human_subtile_fixture_place(mob/living/human/subtile_fixture/H, sx, sy)
	H.human_subtile_position = list("x" = H.x, "y" = H.y, "z" = H.z, "sx" = sx, "sy" = sy)
	H.human_subtile_import_owned = TRUE
	H.after_load()
	human_subtile_fixture_reset(H)

// Walks a body to an absolute pixel column on its row, as free pulses do,
// without the restore path (which refuses a body that is pulling).
/proc/human_subtile_fixture_glide(mob/living/human/subtile_fixture/H, px)
	if (H.x != round(px / 32))
		H.loc = locate(round(px / 32), H.y, H.z)
	H.step_x = px % 32

/proc/human_subtile_fixture_headless()
	human_subtile_fixture_assert(world.byond_version == 516 && world.byond_build == 1688, "pinned_native_engine")
	human_subtile_fixture_phase = "headless normal"
	var/mob/living/human/subtile_fixture/H = human_subtile_fixture_actor(2, 2)
	human_subtile_fixture_assert(!H.human_subtile_enabled, "optin_default_disabled")
	human_subtile_fixture_assert(H.set_human_subtile(TRUE), "optin_enabled")
	var/obj/item/clothing/shoes/subtile_fixture/shoes = new(H)
	H.equip_to_slot(shoes, slot_shoes)
	var/turf/floor/plating/subtile_fixture/next = locate(3, 2, 1)
	var/entries = next.fixture_entries
	var/start = world.time
	H.SelfMove(get_step(H, EAST), EAST, start + 4)
	human_subtile_fixture_assert(H.x == 3 && H.step_x == 0 && H.fixture_pulses == 16, "actual_human_sixteen_pulses_32px")
	human_subtile_fixture_assert(world.time - start <= 4 + world.tick_lag, "absolute_schedule_tick_bound")
	human_subtile_fixture_assert(next.fixture_entries - entries == 1, "native_turf_entry_once")
	human_subtile_fixture_assert(shoes.fixture_steps == 1 && H.next_footstep_sound_at_movement_tick > 0, "production_shoe_step_and_footstep_gate_once")
	var/list/first = H.fixture_rows[1]
	human_subtile_fixture_assert(first["sx"] == 2 && first["locs"] == 2 && first["native"] == 2, "actual_human_physical_offset_and_overlap")
	human_subtile_fixture_assert(H.fixture_human_completions == 1 && H.fixture_living_completions == 1, "completion_once_per_logical_admission")
	human_subtile_fixture_assert(!H.human_subtile_pulse && !H.human_subtile_transaction, "success_releases_context")
	human_subtile_fixture_rows += list(list("scene" = "normal", "elapsed" = world.time - start, "rows" = H.fixture_rows))

	var/mob/living/human/subtile_fixture/W = human_subtile_fixture_actor(3, 5)
	W.set_human_subtile(TRUE)
	var/turf/wall = locate(4, 5, 1)
	wall.density = TRUE
	W.SelfMove(get_step(W, EAST), EAST, world.time + 4)
	human_subtile_fixture_assert(W.x == 3 && W.step_x == 0 && W.fixture_pulses == 1 && !W.fixture_human_completions && !W.fixture_living_completions, "blocked_zero_has_no_completion")
	wall.density = FALSE
	var/mob/living/human/subtile_fixture/P = human_subtile_fixture_actor(6, 5)
	P.dir = WEST
	human_subtile_fixture_place(P, 30, 0)
	human_subtile_fixture_assert(P.dir == WEST, "offset_restore_preserves_facing")
	P.set_human_subtile(TRUE)
	var/turf/partial_wall = locate(8, 5, 1)
	partial_wall.density = TRUE
	P.SelfMove(get_step(P, EAST), EAST, world.time + 4)
	human_subtile_fixture_assert(P.fixture_rows.len == 1, "partial_reaches_next_alignment")
	var/list/partial = P.fixture_rows[1]
	human_subtile_fixture_assert(P.x == 7 && P.step_x == 0 && partial["native"] == 2 && P.fixture_pulses == 1, "actual_human_partial_two_pixels")
	human_subtile_fixture_assert(P.fixture_human_completions == 1 && P.fixture_living_completions == 1, "partial_completion_once")
	partial_wall.density = FALSE

	var/mob/living/human/subtile_fixture/C = human_subtile_fixture_actor(2, 8)
	C.set_human_subtile(TRUE)
	C.fixture_cancel_after = 1
	C.SelfMove(get_step(C, EAST), EAST, world.time + 4)
	human_subtile_fixture_assert(C.step_x == 2 && C.fixture_pulses == 1 && C.fixture_human_completions == 1 && C.fixture_living_completions == 1, "cancel_after_displacement_completes_once")
	human_subtile_fixture_assert(!C.human_subtile_transaction && !C.human_subtile_pulse, "cancel_releases_context")
	var/list/cancelled_position = C.human_subtile_snapshot()
	C.crouching = TRUE
	human_subtile_fixture_assert(!C.set_human_subtile(FALSE) && !C.human_subtile_input_supported(NORTHEAST) && human_subtile_same(cancelled_position, C.human_subtile_snapshot()), "unsupported_handoff_retains_position")
	C.crouching = FALSE
	var/mob/living/human/subtile_fixture/R = human_subtile_fixture_actor(5, 8)
	R.set_human_subtile(TRUE)
	R.fixture_reenter = TRUE
	R.SelfMove(get_step(R, EAST), EAST, world.time + 4)
	human_subtile_fixture_assert(R.step_x == 2 && R.y == 8 && R.fixture_pulses == 1 && !R.human_subtile_transaction, "reentrant_context_cannot_move_or_fallback")
	var/mob/living/human/subtile_fixture/D = human_subtile_fixture_actor(8, 8)
	D.set_human_subtile(TRUE)
	D.fixture_delete_after = 1
	D.SelfMove(get_step(D, EAST), EAST, world.time + 4)
	human_subtile_fixture_assert(!D || (isDeleted(D) && !D.human_subtile_transaction && !D.human_subtile_pulse), "deleted_actor_has_no_continuation")
	var/mob/living/human/subtile_fixture/G = human_subtile_fixture_actor(11, 8)
	G.set_human_subtile(TRUE)
	for (var/key in list("transforming", "using_drone", "prone", "crouching"))
		G.vars[key] = TRUE
		human_subtile_fixture_assert(!G.human_subtile_eligible(EAST), "restricted_[key]")
		G.vars[key] = FALSE
	G.canmove = FALSE
	human_subtile_fixture_assert(!G.SelfMove(get_step(G, EAST), EAST, world.time + 4) && !G.fixture_pulses, "actual_canmove_gate")
	G.canmove = TRUE

	// The actual graph codec, not the standalone five-scalar savefile.
	C.fixture_authorized = TRUE
	C.fixture_cancel_after = 0
	C.dir = SOUTH
	var/obj/item/subtile_fixture_paid/I = new(C)
	var/obj/item/subtile_fixture_paid/child = new(I)
	child.paid_marker = 913
	var/savefile/F = new("human-subtile-owned.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, C, 1)
	F.cd = map_storage.entry_path(F, ref)
	human_subtile_fixture_assert(!("human_subtile_position" in F.dir) && !("step_x" in F.dir) && !("human_subtile_transaction" in F.dir) && !("human_subtile_enabled" in F.dir), "tile_only_export_excludes_offset_and_runtime")
	// Historical raw fields must be ignored based on entry ownership, not order.
	var/entry = map_storage.entry_path(F, ref)
	F["[entry]/step_x"] << list("kind" = "value", "value" = 31)
	F["[entry]/step_y"] << list("kind" = "value", "value" = 31)
	F.Flush()
	F = null
	C.forceMove(locate(15, 12, 1))
	F = new("human-subtile-owned.sav")
	map_storage.clear_bookkeeping()
	var/mob/living/human/subtile_fixture/L = map_storage.Load_Entry(F, ref, starting_loc = locate(2, 8, 1))
	L.after_load()
	human_subtile_fixture_assert(L.x == 2 && L.y == 8 && L.step_x == 0 && L.step_y == 0 && L.dir == SOUTH, "actual_codec_tile_anchor_facing_roundtrip")
	human_subtile_fixture_assert(!L.human_subtile_enabled && !L.human_subtile_transaction && !L.human_subtile_pulse && L.human_subtile_default_pending, "import_never_replays_worker_or_snaps_offset")
	var/obj/item/subtile_fixture_paid/LI = locate() in L.contents
	var/obj/item/subtile_fixture_paid/LC
	if (LI)
		LC = locate() in LI.contents
	human_subtile_fixture_assert(LI && LI != I && LC && LC.paid_marker == 913, "paid_nested_contents_survive_actual_codec")
	L.forceMove(locate(15, 10, 1))
	var/mob/living/human/subtile_fixture/B = human_subtile_fixture_actor(2, 8)
	B.next_move = world.time + 100
	B.next_click = world.time + 100
	var/clock = B.next_move
	var/turf/blocked = locate(3, 8, 1)
	blocked.density = TRUE
	map_storage.clear_bookkeeping()
	var/rejected = FALSE
	try
		map_storage.Load_Entry(F, ref, replacement = B)
		B.after_load()
	catch
		rejected = TRUE
	human_subtile_fixture_assert(!rejected && B.x == 2 && B.y == 8 && B.step_x == 0 && B.next_move == clock && B.next_click == clock, "tile_restore_ignores_blocked_neighbour_and_keeps_clocks")
	blocked.density = FALSE
	B.human_subtile_position = list("x" = 2, "y" = 8, "z" = 1, "sx" = "4", "sy" = 0)
	// A historical capsule entry owns the import; tile-only saves never write one.
	B.human_subtile_import_owned = TRUE
	rejected = FALSE
	try
		B.after_load()
	catch (var/exception/malformed_error)
		rejected = malformed_error.name == "Malformed sub-tile position field"
	human_subtile_fixture_assert(rejected && B.step_x == 0, "malformed_capsule_rejected_without_placement")
	B.human_subtile_position = list("x" = 3, "y" = 8, "z" = 1, "sx" = 4, "sy" = 0)
	B.human_subtile_import_owned = TRUE
	rejected = FALSE
	try
		B.after_load()
	catch (var/exception/anchor_error)
		rejected = anchor_error.name == "Sub-tile anchor or destination rejected"
	human_subtile_fixture_assert(rejected && B.x == 2 && B.step_x == 0, "mismatched_anchor_rejected")
	var/savefile/legacy = new("human-subtile-legacy.sav")
	legacy["/entries/1/type"] << /mob/living/human/subtile_fixture
	legacy["/entries/1/step_x"] << 4
	map_storage.clear_bookkeeping()
	var/mob/living/human/subtile_fixture/old = map_storage.Load_Entry(legacy, 1, starting_loc = locate(11, 11, 1))
	old.after_load()
	human_subtile_fixture_assert(old.step_x == 0 && !old.human_subtile_import_owned && !old.human_subtile_offset_owned, "legacy_raw_offset_not_restored")
	var/savefile/null_owned = new("human-subtile-null.sav")
	null_owned["/format_version"] << 2
	null_owned["/entries/0/1/type"] << /mob/living/human/subtile_fixture
	null_owned["/entries/0/1/human_subtile_position"] << list("kind" = "value", "value" = null)
	null_owned["/entries/0/1/step_x"] << list("kind" = "value", "value" = 31)
	map_storage.clear_bookkeeping()
	var/mob/living/human/subtile_fixture/N = map_storage.Load_Entry(null_owned, 1, starting_loc = locate(13, 3, 1))
	rejected = FALSE
	try
		N.after_load()
	catch (var/exception/null_capsule_error)
		rejected = null_capsule_error.name == "Malformed sub-tile position capsule"
	human_subtile_fixture_assert(rejected && N.step_x == 0, "owned_null_capsule_never_uses_legacy_raw_offset")
	var/obj/structure/bed/bed = new(C.loc)
	C.buckled = bed
	rejected = FALSE
	try
		C.before_save()
	catch
		rejected = TRUE
	human_subtile_fixture_assert(!rejected && isnull(C.human_subtile_position), "buckled_offset_saves_tile_only")
	C.buckled = null
	qdel(bed)
	// Saves are tile-only: no capsule or raw offset is written, whether or not
	// the body overlaps a dense object, and the live offset is left alone.
	var/list/prior_position = C.human_subtile_position
	var/obj/structure/closing = new(C.loc)
	closing.density = TRUE
	C.before_save()
	human_subtile_fixture_assert(isnull(C.human_subtile_position) && !C.human_subtile_save_aligned && C.persistence_runtime_var("step_x") && C.persistence_runtime_var("step_y") && C.step_x, "obstructed_offset_saves_tile_only")
	closing.density = FALSE
	C.before_save()
	human_subtile_fixture_assert(isnull(C.human_subtile_position) && !C.human_subtile_save_aligned && C.step_x, "clear_offset_saves_tile_only")
	qdel(closing)
	C.human_subtile_position = prior_position
	// Actual target.Adjacent(user) direction used by the click gate.
	var/mob/living/human/subtile_fixture/J = human_subtile_fixture_actor(11, 2)
	var/obj/item/near = new(locate(12, 2, 1))
	var/obj/item/far = new(locate(13, 2, 1))
	for (var/offset in list(0, 4, 28))
		human_subtile_fixture_place(J, offset, 0)
		// Past halfway the body stands on the next tile (human_subtile_anchor),
		// so it reaches one tile further.
		human_subtile_fixture_assert(near.Adjacent(J) && !far.Adjacent(J) == (offset < 16), "clicked_target_reach_at_[offset]")
		human_subtile_fixture_assert(!!J.Adjacent(far) == !!offset, "reverse_adjacency_has_overlap_semantics_[offset]")
	J.set_human_subtile(TRUE)
	J.SelfMove(get_step(J, EAST), EAST, world.time + 4)
	human_subtile_fixture_assert(J.x == 12 && far.Adjacent(J), "clicked_target_reach_after_anchor_cross")
	// Held Alt+direction slide: a whole tile's distance on the admitted interval
	// from an offset (crossing the alignment), then a release stops it early.
	human_subtile_fixture_phase = "headless held fine slide"
	var/mob/living/human/subtile_fixture/S = human_subtile_fixture_actor(2, 12)
	S.set_human_subtile(TRUE)
	human_subtile_fixture_place(S, 6, 0)
	human_subtile_fixture_assert(S.human_subtile_remaining_fraction(EAST) == 26 / 32 && S.human_subtile_remaining_fraction(WEST) == 6 / 32 && S.human_subtile_remaining_fraction(NORTH) == 1, "remaining_fraction_from_offset")
	S.movement_fine = TRUE
	S.movement_eastwest = EAST
	var/slide_start = world.time
	S.SelfMove(get_step(S, EAST), EAST, world.time + 4, FINE_STEP_HELD)
	human_subtile_fixture_assert(S.x == 3 && S.step_x == 6 && !S.step_y && world.time - slide_start <= 4, "held_fine_slides_a_tile_from_offset")
	human_subtile_fixture_assert(S.human_subtile_fine_released_at != world.time, "held_fine_not_released_while_held")
	spawn(2)
		S.movement_eastwest = null
	slide_start = world.time
	S.SelfMove(get_step(S, EAST), EAST, world.time + 4, FINE_STEP_HELD)
	var/slid = (S.x - 3) * 32 + S.step_x - 6
	human_subtile_fixture_assert(slid > 0 && slid < 32 && S.human_subtile_fine_released_at == world.time && world.time - slide_start < 4, "held_fine_stops_on_release")
	// Tap to step: a released key finishes the tile, from an offset or aligned.
	S.fixture_tap_step = TRUE
	var/tap_target = ceil((S.x * 32 + S.step_x) / 32)
	spawn(1)
		S.movement_eastwest = null
	S.movement_eastwest = EAST
	S.SelfMove(get_step(S, EAST), EAST, world.time + 4, FINE_STEP_HELD)
	var/tap_from_offset = S.x == tap_target && !S.step_x && S.human_subtile_fine_released_at != world.time
	spawn(1)
		S.movement_eastwest = null
	S.movement_eastwest = EAST
	S.SelfMove(get_step(S, EAST), EAST, world.time + 4, FINE_STEP_HELD)
	human_subtile_fixture_assert(tap_from_offset && S.x == tap_target + 1 && !S.step_x && !S.step_y, "tap_step_finishes_the_tile")
	S.fixture_tap_step = FALSE
	S.movement_fine = FALSE
	// Graal-style sliding: a straight slide clipping a corner slips sideways
	// into the opening ahead, and a diagonal into a wall runs along it.
	human_subtile_fixture_phase = "headless corner slide"
	var/turf/corner = locate(3, 11, 1)
	corner.density = TRUE
	var/mob/living/human/subtile_fixture/K = human_subtile_fixture_actor(2, 10)
	K.set_human_subtile(TRUE)
	human_subtile_fixture_place(K, 6, 0)
	K.movement_northsouth = NORTH
	K.SelfMove(get_step(K, NORTH), NORTH, world.time + 4, FINE_STEP_HELD)
	human_subtile_fixture_assert(K.step_x == 0 && K.x == 2 && (K.y - 10) * 32 + K.step_y == 26, "corner_slide_into_opening")
	K.movement_northsouth = null
	corner.density = FALSE
	human_subtile_fixture_phase = "headless wall slide"
	var/list/slide_wall = list(locate(6, 11, 1), locate(7, 11, 1), locate(8, 11, 1))
	for (var/turf/WS in slide_wall)
		WS.density = TRUE
	var/mob/living/human/subtile_fixture/D2 = human_subtile_fixture_actor(6, 10)
	D2.set_human_subtile(TRUE)
	D2.movement_northsouth = NORTH
	D2.movement_eastwest = EAST
	D2.SelfMove(get_step(D2, NORTHEAST), NORTHEAST, world.time + 4, FINE_STEP_HELD)
	human_subtile_fixture_assert(D2.y == 10 && !D2.step_y && (D2.x - 6) * 32 + D2.step_x == 32, "diagonal_wall_slide")
	D2.movement_northsouth = null
	D2.movement_eastwest = null
	for (var/turf/WS in slide_wall)
		WS.density = FALSE
	// Free movement pulling works like a rope: the pulled thing slides in
	// pixels after the body, snags on walls, and the pull ends when too far.
	human_subtile_fixture_phase = "headless pull rope"
	var/mob/living/human/subtile_fixture/PF = human_subtile_fixture_actor(16, 6)
	PF.set_human_subtile(TRUE)
	var/obj/structure/pull_crate = new(locate(15, 6, 1))
	pull_crate.anchored = FALSE
	pull_crate.density = TRUE
	PF.pulling = pull_crate
	pull_crate.pulledby = PF
	human_subtile_fixture_assert(!PF.human_subtile_pull_follow() && pull_crate.loc == locate(15, 6, 1) && !pull_crate.step_x, "pull_waits_while_touching")
	human_subtile_fixture_place(PF, 8, 0)
	PF.pulling = pull_crate
	pull_crate.pulledby = PF
	var/rope_first = PF.human_subtile_pull_follow() && pull_crate.x == 15 && pull_crate.step_x == 4 && !pull_crate.step_y
	PF.human_subtile_pull_follow()
	human_subtile_fixture_assert(rope_first && pull_crate.x == 15 && pull_crate.step_x == 6 && !PF.human_subtile_pull_follow() && PF.pulling == pull_crate, "pull_rope_trails_in_pixels")
	// Moving up past it (here: it sits half a tile lower), the rope tugs it along at once rather than waiting
	// until the body has cleared it and then catching up a whole tile, but only
	// 1px a pulse while beside the body, so it drops back behind.
	pull_crate.Move(locate(15, 5, 1), SOUTH, 6, 16)
	human_subtile_fixture_assert(PF.human_subtile_pull_follow() && pull_crate.x == 15 && pull_crate.y == 5 && pull_crate.step_x == 6 && pull_crate.step_y == 17, "pull_rope_tugs_sideways")
	// Pulling straight into a wall snags: no free axis or corner to slide round.
	var/turf/rope_wall = locate(17, 10, 1)
	rope_wall.density = TRUE
	var/mob/living/human/subtile_fixture/PS = human_subtile_fixture_actor(17, 11)
	PS.set_human_subtile(TRUE)
	var/obj/structure/snag_crate = new(locate(17, 9, 1))
	snag_crate.anchored = FALSE
	snag_crate.density = TRUE
	PS.pulling = snag_crate
	snag_crate.pulledby = PS
	var/snagged = !PS.human_subtile_pull_follow() && snag_crate.loc == locate(17, 9, 1) && !snag_crate.step_x && !snag_crate.step_y
	human_subtile_fixture_assert(snagged, "pull_snags_on_walls")
	human_subtile_fixture_assert(!PS.pulling && !snag_crate.pulledby, "pull_breaks_when_too_far")
	rope_wall.density = FALSE
	PF.pulling = null
	pull_crate.pulledby = null
	qdel(pull_crate)
	// Walking east with the crate beside it (south), the crate falls in behind
	// the body within a few tiles instead of riding alongside.
	human_subtile_fixture_phase = "headless pull falls in behind"
	var/mob/living/human/subtile_fixture/PB = human_subtile_fixture_actor(8, 4)
	PB.set_human_subtile(TRUE)
	var/obj/structure/side_crate = new(locate(8, 3, 1))
	side_crate.anchored = FALSE
	side_crate.density = TRUE
	var/body_px = 8 * 32
	var/behind = FALSE
	for (var/pulse in 1 to 112)
		body_px += 2
		human_subtile_fixture_glide(PB, body_px)
		PB.pulling = side_crate
		side_crate.pulledby = PB
		PB.human_subtile_pull_follow()
		if (PB.pulling != side_crate)
			break
		var/crate_px = side_crate.x * 32 + side_crate.step_x
		if (side_crate.y == 4 && !side_crate.step_y && crate_px <= body_px - 32)
			behind = TRUE
			break
	human_subtile_fixture_assert(behind && PB.pulling == side_crate && body_px <= 12 * 32, "pull_falls_in_behind")
	PB.pulling = null
	side_crate.pulledby = null
	qdel(side_crate)
	// Swapping places keeps each body's exact position: the swapped body takes
	// the other's pixel offset instead of carrying its own into a wall.
	human_subtile_fixture_phase = "headless exact swap"
	var/mob/living/human/subtile_fixture/SA = human_subtile_fixture_actor(13, 12)
	var/mob/living/human/subtile_fixture/SB = human_subtile_fixture_actor(14, 12)
	SA.set_human_subtile(TRUE)
	SB.set_human_subtile(TRUE)
	human_subtile_fixture_place(SB, 0, 16)
	var/turf/swap_wall = locate(13, 13, 1)
	swap_wall.density = TRUE
	SA.swap_exact_positions(SB)
	// At 16px north the body stands on the tile above (human_subtile_anchor).
	human_subtile_fixture_assert(SA.loc == locate(14, 13, 1) && SA.step_x == 0 && SA.step_y == -16 && SB.loc == locate(13, 12, 1) && !SB.step_x && !SB.step_y && SA.human_subtile_offset_owned && !SB.human_subtile_offset_owned, "swap_keeps_exact_positions")
	swap_wall.density = FALSE
	// Free movement swaps only head-on: grazing, diagonal and sliding bumps block.
	var/datum/human_subtile_transaction/swap_tx = new
	swap_tx.fine_step = FINE_STEP_HELD
	var/datum/human_subtile_pulse/swap_pulse = new
	swap_pulse.direction = WEST
	SA.human_subtile_transaction = swap_tx
	SA.human_subtile_pulse = swap_pulse
	var/swap_graze = SA.human_subtile_swap_allowed(SB)
	SA.human_subtile_pulse = null
	SA.human_subtile_transaction = null
	// Back onto row 12, level with SB (the swap left SA filed on row 13).
	SA.loc = locate(14, 12, 1)
	SA.step_x = 0
	SA.step_y = 0
	human_subtile_fixture_place(SA, 0, 0)
	SA.human_subtile_transaction = swap_tx
	SA.human_subtile_pulse = swap_pulse
	var/swap_head_on = SA.human_subtile_swap_allowed(SB)
	swap_pulse.direction = NORTHWEST
	var/swap_diagonal = SA.human_subtile_swap_allowed(SB)
	swap_pulse.direction = WEST
	swap_pulse.slide = TRUE
	var/swap_slide = SA.human_subtile_swap_allowed(SB)
	SA.human_subtile_pulse = null
	SA.human_subtile_transaction = null
	human_subtile_fixture_assert(!swap_graze && swap_head_on && !swap_diagonal && !swap_slide, "free_swap_only_head_on")
	// Mobs that could swap walk through each other and may share a tile.
	SA.a_intent = I_HELP
	SB.a_intent = I_HELP
	var/pass_help = SB.Cross(SA) && SB.CanPass(SA, SA.loc, TRUE, FALSE)
	SA.a_intent = I_HARM
	var/pass_harm = SB.Cross(SA) || SB.CanPass(SA, SA.loc, TRUE, FALSE)
	SA.a_intent = I_HELP
	var/turf/pass_target = SB.loc
	SA.Move(pass_target, get_dir(SA, pass_target))
	human_subtile_fixture_assert(pass_help && !pass_harm && SA.loc == pass_target && SB.loc == pass_target, "help_intent_walks_through")
	// Passing someone eases sideways: away from them, or to the right when centred.
	SA.loc = locate(12, 12, 1)
	human_subtile_fixture_place(SA, 30, 0)
	human_subtile_fixture_place(SB, 0, 4)
	var/list/nudge_away = SA.human_subtile_pass_nudge(EAST)
	human_subtile_fixture_place(SB, 0, 0)
	var/list/nudge_right = SA.human_subtile_pass_nudge(EAST)
	var/list/nudge_diagonal = SA.human_subtile_pass_nudge(NORTHEAST)
	SA.a_intent = I_HARM
	var/list/nudge_harm = SA.human_subtile_pass_nudge(EAST)
	SA.a_intent = I_HELP
	human_subtile_fixture_assert(nudge_away && nudge_away[1] == 0 && nudge_away[2] == -2 && nudge_right && nudge_right[2] == -2 && !nudge_diagonal && !nudge_harm, "passing_eases_sideways")
	// Three bodies sharing one tile, two of them between tiles, save and load
	// through the real codec onto that same tile without refusing anything.
	var/turf/shared = locate(9, 12, 1)
	var/list/stacked = list()
	for (var/list/offset in list(list(0, 0), list(10, 0), list(0, 12)))
		var/mob/living/human/subtile_fixture/SK = human_subtile_fixture_actor(9, 12)
		SK.set_human_subtile(TRUE)
		human_subtile_fixture_place(SK, offset[1], offset[2])
		stacked += SK
	var/stack_ok = TRUE
	var/savefile/stack_file = new("human-subtile-stacked.sav")
	stack_file["/format_version"] << 2
	var/list/stack_refs = list()
	for (var/mob/living/human/subtile_fixture/SK in stacked)
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 1
		try
			SK.before_save()
			stack_refs += map_storage.BuildVarDirectory(stack_file, SK, 1)
		catch
			stack_ok = FALSE
	stack_file.Flush()
	for (var/mob/living/human/subtile_fixture/SK in stacked)
		SK.forceMove(locate(15, 2, 1))
	var/list/restored = list()
	for (var/stack_ref in stack_refs)
		map_storage.clear_bookkeeping()
		try
			var/mob/living/human/subtile_fixture/SR = map_storage.Load_Entry(stack_file, stack_ref, starting_loc = shared)
			SR.after_load()
			restored += SR
		catch
			stack_ok = FALSE
	for (var/mob/living/human/subtile_fixture/SR in restored)
		if (SR.loc != shared || SR.step_x || SR.step_y)
			stack_ok = FALSE
	human_subtile_fixture_assert(stack_ok && stack_refs.len == 3 && restored.len == 3, "stacked_bodies_save_and_load")
	// Riding moves freely: the mount keeps the rider's exact spot, and a
	// ridden mount saves tile-only like its rider.
	var/mob/living/human/subtile_fixture/RD = human_subtile_fixture_actor(15, 14)
	RD.set_human_subtile(TRUE)
	human_subtile_fixture_place(RD, 6, 0)
	var/mob/living/simple_animal/horse/mount = new(locate(15, 14, 1))
	mount.stop_automated_movement = TRUE
	mount.ride = TRUE
	mount.rider = RD
	RD.riding = TRUE
	RD.riding_mob = mount
	RD.human_subtile_mount_follow()
	RD.movement_eastwest = EAST
	RD.SelfMove(get_step(RD, EAST), EAST, world.time + 4, FINE_STEP_HELD)
	RD.movement_eastwest = null
	human_subtile_fixture_assert(RD.x == 16 && RD.step_x == 6 && !RD.step_y && mount.loc == RD.loc && mount.step_x == 6 && !mount.step_y, "riding_moves_freely")
	mount.before_save()
	human_subtile_fixture_assert(isnull(mount.npc_subtile_position), "ridden_mount_saves_tile_only")
	// Animals move freely only while a player can see them, in 8px pulses.
	var/mob/living/simple_animal/deer/subtile_fixture_watched/WD = new(locate(2, 14, 1))
	WD.stop_automated_movement = TRUE
	human_subtile_fixture_deer_watched = TRUE
	var/step_ok = WD.ai_step(get_step(WD, EAST), 4)
	var/first_offset = WD.step_x
	sleep(6)
	human_subtile_fixture_assert(step_ok && first_offset == 8 && WD.x == 3 && !WD.step_x && WD.npc_subtile_auto_owned && WD.npc_subtile_enabled && WD.persistence_runtime_var("npc_subtile_enabled"), "watched_animal_moves_freely")
	human_subtile_fixture_deer_watched = FALSE
	WD.npc_subtile_watch_checked = -INFINITY
	WD.ai_step(get_step(WD, EAST), 4)
	human_subtile_fixture_assert(WD.x == 4 && !WD.step_x && !WD.npc_subtile_enabled && !WD.npc_subtile_auto_owned && !WD.npc_subtile_transaction, "unwatched_animal_takes_tile_steps")
	human_subtile_fixture_phase = "headless complete"
	return TRUE

// Called only with root's separately admitted real showcase client. This tests
// client.Move, not OS key delivery or the movementMachine polling scheduler.
/proc/human_subtile_fixture_client(client/C)
	var/mob/living/human/subtile_fixture/H = C.mob
	human_subtile_fixture_assert(istype(H) && H.client == C && !H.step_x && !H.step_y, "real_client_fixture_actor")
	var/list/rows = list()
	var/list/cases = list(list("name" = "ordinary", "traits" = list(), "slow" = 0, "intent" = "walk"), list("name" = "slowfloor", "traits" = list(), "slow" = 3, "intent" = "walk"), list("name" = "agile", "traits" = list("Agile"), "slow" = 0, "intent" = "walk"), list("name" = "slowness_gigantism", "traits" = list("Slowness", "Gigantism"), "slow" = 0, "intent" = "walk"), list("name" = "running", "traits" = list(), "slow" = 0, "intent" = "run"))
	for (var/list/test_case in cases)
		var/list/baseline = null
		for (var/enabled in list(FALSE, TRUE))
			human_subtile_fixture_phase = "[test_case["name"]] [enabled ? "4px" : "baseline"]"
			H.set_human_subtile(enabled)
			H.traits = test_case["traits"]
			H.traits_dirty = TRUE
			H.m_intent = test_case["intent"]
			H.velocity = 0
			H.velocity_lastdir = -1
			H.last_run_delay = -1
			H.next_calculate_run_delay = -1
			H.next_calculate_tally = -1
			for (var/turf/floor/T in world)
				T.move_delay = test_case["slow"]
			human_subtile_fixture_wait(C)
			var/start = world.time
			var/start_x = H.x
			var/nutrition_before = H.nutrition
			var/stamina_before = H.stats["stamina"][1]
			var/list/admission_state = human_subtile_fixture_client_state(C, H)
			var/list/intervals = list()
			for (var/i = 1, i <= 3, i++)
				human_subtile_fixture_wait(C)
				C.canmove = TRUE
				var/admission = world.time
				var/direction = enabled ? WEST : EAST
				C.Move(get_step(H, direction), direction, FALSE)
				intervals += C.move_delay - admission
				human_subtile_fixture_wait(C)
			var/list/row = list("case" = test_case["name"], "enabled" = enabled, "elapsed" = world.time - start, "pixels" = abs(H.x - start_x) * 32, "intervals" = intervals, "nutrition_cost" = nutrition_before - H.nutrition, "stamina_cost" = stamina_before - H.stats["stamina"][1])
			rows += list(row)
			row["admission_state"] = admission_state
			row["end_state"] = human_subtile_fixture_client_state(C, H)
			human_subtile_fixture_record_client(row)
			human_subtile_fixture_assert(row["pixels"] == 96 && !H.step_x && !H.step_y, "real_client_three_admitted_tiles")
			if (!enabled)
				baseline = row
			else
				human_subtile_fixture_assert(abs(row["elapsed"] - baseline["elapsed"]) <= world.tick_lag && abs(row["nutrition_cost"] - baseline["nutrition_cost"]) < 0.001, "real_client_sustained_interval_and_single_cost")
				human_subtile_fixture_assert(row["stamina_cost"] == baseline["stamina_cost"], "real_client_stamina_cost_once")
				var/list/old_intervals = baseline["intervals"]
				for (var/j = 1, j <= 3, j++)
					human_subtile_fixture_assert(abs(intervals[j] - old_intervals[j]) < 0.01, "real_client_final_cooldown_parity")
	H.m_intent = "walk"
	H.traits = list()
	H.traits_dirty = TRUE
	var/turf/blocked = get_step(H, EAST)
	blocked.density = TRUE
	var/list/blocked_baseline
	for (var/enabled_blocked in list(FALSE, TRUE))
		human_subtile_fixture_phase = "blocked [enabled_blocked ? "4px" : "baseline"]"
		H.set_human_subtile(enabled_blocked)
		human_subtile_fixture_wait(C)
		var/list/before = H.human_subtile_snapshot()
		var/food = H.nutrition
		var/at = world.time
		var/list/blocked_admission_state = human_subtile_fixture_client_state(C, H)
		C.Move(blocked, EAST, FALSE)
		var/list/row = list("case" = "blocked", "enabled" = enabled_blocked, "interval" = C.move_delay - at, "nutrition_cost" = food - H.nutrition)
		rows += list(row)
		row["admission_state"] = blocked_admission_state
		row["end_state"] = human_subtile_fixture_client_state(C, H)
		human_subtile_fixture_record_client(row)
		human_subtile_fixture_assert(human_subtile_same(before, H.human_subtile_snapshot()), "real_client_blocked_position_preserved")
		if (!enabled_blocked)
			blocked_baseline = row
		else
			human_subtile_fixture_assert(abs(row["nutrition_cost"] - blocked_baseline["nutrition_cost"]) < 0.001 && abs(row["interval"] - blocked_baseline["interval"]) < 0.01, "real_client_failed_attempt_cost_and_cooldown_parity")
	blocked.density = FALSE
	human_subtile_fixture_phase = "client exercise complete"
	return rows

/world/New()
	var/initial_native_port = port
	OpenPort("none")
	if (port)
		return
	text2file("closed", "port-closed.txt")
	var/error = null
	try
		if (OpenPort(0) || port || OpenPort(59474) || port)
			throw EXCEPTION("fixture_port_reopened")
		human_subtile_fixture_initialize()
		if (world.params["mining_integration"])
			human_subtile_fixture_mining()
		else
			human_subtile_fixture_headless()
	catch (var/exception/fixture_error)
		error = fixture_error.name
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("head" = world.params["tested_commit"], "byond_version" = byond_version, "byond_build" = byond_build, "initial_native_port" = initial_native_port, "port" = port, "checks" = human_subtile_fixture_checks, "error" = error, "rows" = human_subtile_fixture_rows, "mining_checks" = human_subtile_mining_checks, "mining_rows" = human_subtile_mining_rows, "scope" = "actual human/codec; headless authority adapter")), "receipt.json")
	del(world)
	return
