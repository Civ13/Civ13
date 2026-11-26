// Full-source probe: trapdoors and hatches between levels (trapdoors.dm).
// A kit is laid into an opening beside you; shut, the trapdoor is floor
// (nothing falls through, the ladder and stairs under it lead nowhere); it
// has above and below as its sides for bars, latches and its hinges; it is
// worked from below through the ladder or stairs under it; open, things on it
// drop through and the way between levels works again.
/world
	hub = ""
	visibility = 0
	maxx = 12
	maxy = 12
	maxz = 2
	fps = 20
	turf = /turf/floor/plating/trapdoors_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/trapdoors_probe/New()
	map = src

/turf/floor/plating/trapdoors_probe

var/trapdoors_probe_checks = 0
var/trapdoors_runtime = null

/world/Error(exception/e)
	if (!trapdoors_runtime)
		trapdoors_runtime = "runtime [e] ([e.file]:[e.line])"

/proc/trapdoors_assert(ok, label)
	trapdoors_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/trapdoors_actor(tx, ty, tz, name)
	var/mob/living/human/H = new(locate(tx, ty, tz))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.real_name = name
	H.name = name
	H.hand = 0
	H.a_intent = I_HELP
	return H

/proc/trapdoors_hands(mob/living/human/H, obj/item/active, obj/item/other)
	H.drop_l_hand()
	H.drop_r_hand()
	if (active)
		H.put_in_r_hand(active)
	if (other)
		H.put_in_l_hand(other)

/proc/trapdoors_probe_run()
	config = new
	config.webhook_can_fire = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.global_listen_count = list()
	GLOB.event_sources_count = list()
	GLOB.event_listen_count = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	movementMachine = new
	map = new /obj/map_metadata/trapdoors_probe

	// The upper level is floor except two openings: one over a wooden ladder,
	// one over a flight of stairs.
	var/turf/well = locate(5, 5, 2)
	var/turf/stairwell = locate(8, 5, 2)
	new /turf/sky/building(well)
	new /turf/sky/building(stairwell)
	well = locate(5, 5, 2)
	stairwell = locate(8, 5, 2)
	var/obj/structure/multiz/ladder/up/placed/bottom = new(locate(5, 5, 1))
	var/obj/structure/multiz/ladder/placed/top = new(well)
	bottom.target = top
	top.target = bottom
	var/mob/living/human/above = trapdoors_actor(4, 5, 2, "Above")
	var/mob/living/human/below = trapdoors_actor(4, 5, 1, "Below")

	// Laying the kit into the opening beside you.
	var/obj/item/trapdoor_kit/kit = new
	trapdoors_hands(above, kit, null)
	kit.resolve_attackby(well, above)
	sleep(10)
	var/obj/structure/simple_door/key_door/anyone/trapdoor/TD = trapdoor_at(well)
	trapdoors_assert(istype(TD) && QDELETED(kit), "kit_laid")
	trapdoors_assert(!TD.state && !TD.density && !TD.opacity && TD.name == "wooden trapdoor", "laid_shut_flat")
	TD.inner_dir = UP
	trapdoors_assert(trapdoor_fit_refusal(well, above), "one_per_opening")
	trapdoors_assert(trapdoor_fit_refusal(locate(3, 5, 2), above), "not_on_floor")

	// Shut, it is floor.
	trapdoors_assert(!edge_open_air(well) && ledge_landing_clear(well), "shut_is_floor")
	trapdoors_assert(TD.door_side_of(above) == UP && TD.door_side_of(below) == DOWN && TD.trapdoor_within_reach(below), "above_and_below")
	trapdoors_assert(TD.door_opposite_side(UP) == DOWN, "opposite_sides")

	// Nobody climbs down a ladder through it, or up.
	top.attack_hand(above)
	sleep(15)
	trapdoors_assert(above.z == 2, "ladder_shut_from_above")

	// It won't open under someone standing on it.
	var/mob/living/human/stander = trapdoors_actor(5, 5, 2, "Stander")
	trapdoors_assert(!TD.canOpen(above), "not_under_someone")
	qdel(stander)
	trapdoors_assert(TD.canOpen(above) && TD.canOpen(below), "opens_either_side")

	// Barred from above, it can't be pushed open from below.
	var/obj/item/weapon/hammer/hammer = new
	var/obj/item/door_brackets/brackets = new
	trapdoors_hands(above, brackets, hammer)
	TD.attackby(brackets, above)
	trapdoors_assert(TD.door_has_brackets(UP), "brackets_above")
	var/obj/item/door_bar/bar = new
	trapdoors_hands(above, bar, null)
	TD.attackby(bar, above)
	trapdoors_assert(TD.door_bar_on(UP) == "wood" && TD.door_barred(), "barred_above")
	trapdoors_assert(!TD.canOpen(below), "barred_against_below")
	trapdoors_assert(TD.fitting_images && TD.fitting_images.len, "bar_overlay")
	bottom.attack_hand(below)
	sleep(15)
	trapdoors_assert(below.z == 1 && !TD.state, "pushed_from_below_stays_shut")
	trapdoors_hands(above, null, null)
	TD.lift_door_bar(above, UP)
	trapdoors_assert(!TD.door_barred(), "bar_lifted")

	// A latch fitted from below, through the ladder: below is its outside.
	var/obj/item/weapon/screwdriver/driver = new
	var/obj/item/fitted_lock/latch/latch = new
	trapdoors_hands(below, latch, driver)
	bottom.attackby(latch, below)
	trapdoors_assert(TD.door_lock && TD.door_lock.kind == "latch" && TD.door_lock.side == DOWN, "latch_from_below")
	TD.Open()
	sleep(12)
	trapdoors_assert(TD.state && edge_open_air(well), "open_is_opening")
	TD.Close()
	sleep(12)
	trapdoors_assert(TD.door_lock.locked && TD.door_lock_engaged(), "latch_catches")
	trapdoors_assert(!TD.canOpen(below) && TD.canOpen(above), "latched_against_below")

	// Open, the ladder climbs through.
	TD.Open()
	sleep(12)
	trapdoors_hands(below, null, null)
	bottom.attack_hand(below)
	sleep(15)
	trapdoors_assert(below.z == 2, "climbed_through_open")
	below.forceMove(locate(4, 5, 1))

	// An iron hatch over the stairs: shut, the stairs lead nowhere and things
	// lie on it; open, they drop through and the stairs climb.
	var/obj/structure/simple_door/key_door/anyone/trapdoor/iron/H = new(stairwell)
	sleep(10)
	trapdoors_assert(H.name == "iron hatch" && H.health == 250, "iron_hatch")
	var/obj/covers/wood/stairs/S = new(locate(8, 5, 1))
	S.dir = NORTH
	var/mob/living/human/climber = trapdoors_actor(8, 4, 1, "Climber")
	var/list/why = list()
	trapdoors_assert(!stairs_destination(climber, S, why) && findtext(why[1], "trapdoor"), "stairs_shut")
	var/obj/item/weapon/crowbar/bit = new(locate(7, 5, 2))
	bit.forceMove(stairwell)
	trapdoors_assert(bit.z == 2, "things_lie_on_it")
	var/obj/structure/closet/crate/loose_crate = new(locate(7, 5, 2))
	var/obj/structure/closet/crate/fixed_crate = new(locate(7, 5, 2))
	loose_crate.anchored = FALSE
	fixed_crate.anchored = TRUE
	loose_crate.forceMove(stairwell)
	fixed_crate.forceMove(stairwell)
	trapdoors_assert(loose_crate.loc == stairwell && fixed_crate.loc == stairwell, "both_crates_rest_on_shut_hatch")
	H.Open()
	sleep(12)
	trapdoors_assert(bit.z == 1, "things_drop_through")
	trapdoors_assert(loose_crate.loc == locate(8, 5, 1), "loose_crate_falls_on_opening")
	trapdoors_assert(fixed_crate.loc == stairwell, "anchored_crate_stays_when_opened")
	fixed_crate.forceMove(locate(7, 5, 2))
	trapdoors_assert(stairs_destination(climber, S) == locate(8, 6, 2), "stairs_climb_open")
	H.Close()
	sleep(12)

	// Its hinges are below: it comes out from below, through the stairs, with
	// a wrench, back into a kit.
	H.inner_dir = DOWN
	var/obj/item/weapon/wrench/wrench = new
	trapdoors_hands(above, wrench, null)
	H.attackby(wrench, above)
	trapdoors_assert(!QDELETED(H), "hinges_below_refuse_above")
	trapdoors_hands(above, null, null)
	trapdoors_hands(climber, wrench, null)
	bit.forceMove(stairwell)
	fixed_crate.forceMove(stairwell)
	trapdoors_assert(bit.loc == stairwell && get_turf(climber) != stairwell, "removal_starts_with_cargo_on_shut_hatch_at_a_different_turf")
	S.attackby(wrench, climber)
	trapdoors_assert(QDELETED(H) && (locate(/obj/item/trapdoor_kit/iron) in get_turf(climber)), "taken_out_from_below")
	trapdoors_assert(bit.loc == locate(8, 5, 1), "loose_item_falls_on_wrench_removal")
	trapdoors_assert(fixed_crate.loc == stairwell, "anchored_crate_stays_when_removed")

	// Agents see which side they are on and what holds it; with no client, an
	// agent character still opens it by hand.
	var/list/row = agent_door_row(TD, above)
	trapdoors_assert(row["kind"] == "trapdoor" && row["open"] && row["inside"] == "your side", "agent_row_open")
	TD.Close()
	sleep(12)
	row = agent_door_row(TD, above)
	trapdoors_assert(!row["open"] && row["passable"] && islist(row["lock"]) && row["lock"]["keyhole"] == "far side", "agent_row_shut")
	var/list/below_row = agent_door_row(TD, below)
	trapdoors_assert(!below_row["passable"], "agent_row_latched_below")
	agent_characters[above] = new /datum/agent_character
	above.last_bumped = 0
	TD.TryToSwitchState(above)
	sleep(12)
	trapdoors_assert(TD.state, "agent_opens_without_client")
	agent_characters -= above

	// Door-only fittings are refused.
	var/obj/item/door_fitting/spring_closer/closer = new
	trapdoors_hands(above, closer, driver)
	TD.attackby(closer, above)
	trapdoors_assert(!TD.door_closer && !QDELETED(closer), "closer_refused")

/world/New()
	OpenPort("none")
	var/error = null
	try
		trapdoors_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	if (!error && trapdoors_runtime)
		error = trapdoors_runtime
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = trapdoors_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
