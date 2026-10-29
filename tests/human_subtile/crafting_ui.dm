// Prepared native integration cases. Not included/launched by the CI walker.
// Existing human fixture authority is headless; this does not test browser focus.
var/crafting_ui_movement_checks = 0

/obj/item/stack/subtile_crafting_fixture
	amount = 5
	recipes = list()

/proc/crafting_ui_movement_assert(ok, label)
	crafting_ui_movement_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/crafting_ui_movement_fixture()
	var/mob/living/human/subtile_fixture/H = human_subtile_fixture_actor(3, 3)
	var/obj/item/stack/subtile_crafting_fixture/S = new(H)
	crafting_ui_movement_assert(H.put_in_active_hand(S) && H.set_human_subtile(TRUE), "crafting_held_source_admitted")
	H.set_using_object(S)
	crafting_ui_movement_assert(H.human_subtile_eligible(EAST) && S.allows_smooth_movement_ui(H), "crafting_passive_view_keeps_eligibility")
	crafting_ui_movement_assert(H.SelfMove(get_step(H, EAST), EAST, world.time + 4) && H.x == 4 && !H.step_x && H.fixture_pulses == 16 && H.using_object == S, "crafting_full_physical_intent")
	H.unset_using_object()
	human_subtile_fixture_reset(H)
	spawn(1)
		H.set_using_object(S)
	crafting_ui_movement_assert(H.SelfMove(get_step(H, EAST), EAST, world.time + 4), "crafting_open_during_intent_admitted")
	crafting_ui_movement_assert(H.x == 5 && !H.step_x && H.fixture_pulses == 16 && H.using_object == S, "crafting_open_during_intent_does_not_interrupt")
	var/obj/item/generic = new(H)
	H.set_using_object(generic)
	crafting_ui_movement_assert(H.human_subtile_eligible(EAST) && !generic.allows_smooth_movement_ui(H), "crafting_nonstack_view_keeps_eligibility")
	H.set_using_object(S)
	human_subtile_fixture_reset(H)
	H.fixture_cancel_after = 1
	crafting_ui_movement_assert(H.SelfMove(get_step(H, EAST), EAST, world.time + 4), "crafting_partial_intent_admitted")
	crafting_ui_movement_assert(H.step_x == 2 && H.human_subtile_offset_owned, "crafting_partial_is_physical")
	crafting_ui_movement_assert(H.drop_from_inventory(S), "crafting_drop_actual_inventory_path")
	H.human_subtile_prepare_ui_movement()
	crafting_ui_movement_assert(!H.using_object && H.step_x == 2, "crafting_stale_view_closes_without_snap")
	H.fixture_authorized = TRUE
	H.fixture_cancel_after = 0
	human_subtile_fixture_reset(H)
	crafting_ui_movement_assert(H.SelfMove(get_step(H, WEST), WEST, world.time + 4), "crafting_reverse_recovery_admitted")
	crafting_ui_movement_assert(H.x == 5 && !H.step_x && H.fixture_pulses == 1, "crafting_reverse_recovers_without_admin_placement")
	human_subtile_fixture_reset(H)
	H.fixture_cancel_after = 1
	var/atom/anchor = H.loc
	spawn(1)
		H.SelfMove(get_step(H, EAST), EAST, world.time + 4)
	var/waited = do_after(H, 3, needhand = FALSE, progress = FALSE)
	crafting_ui_movement_assert(!waited && H.loc == anchor && H.step_x == 2, "crafting_stationary_wait_cancels_within_tile")
	sleep(5)
	H.fixture_authorized = TRUE
	human_subtile_fixture_reset(H)
	spawn(1)
		H.SelfMove(get_step(H, WEST), WEST, world.time + 4)
	waited = do_after(H, 3, needhand = FALSE, progress = FALSE, can_move = TRUE)
	crafting_ui_movement_assert(waited && !H.step_x, "crafting_explicit_moving_wait_unchanged")
	sleep(5)
	qdel(H)
	qdel(S)
	qdel(generic)
