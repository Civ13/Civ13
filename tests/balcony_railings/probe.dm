// Full-source probe: railings players build along the edge of a floor
// (code/game/objects/structures/railing_built.dm).
/world
	hub = ""
	visibility = 0
	maxx = 16
	maxy = 16
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/balcony_railings_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/balcony_railings_probe/New()
	map = src

/turf/floor/plating/balcony_railings_probe

var/balcony_railings_probe_checks = 0
var/balcony_railings_runtime = null

/world/Error(exception/e)
	if (!balcony_railings_runtime)
		balcony_railings_runtime = "runtime [e] ([e.file]:[e.line])"

/proc/balcony_railings_assert(ok, label)
	balcony_railings_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

// A shot from turf `from` flying at `angle` degrees (0 east, 90 north).
/proc/balcony_railings_shot(turf/from, angle)
	var/obj/item/projectile/P = new /obj/item/projectile(from)
	P.starting = from
	P.angle = angle
	return P

/proc/balcony_railings_tally(atom/A, turf/from, angle, tries = 400)
	var/obj/item/projectile/P = balcony_railings_shot(from, angle)
	var/list/counts = list("0" = 0, "1" = 0, "2" = 0)
	for (var/i in 1 to tries)
		counts["[directional_cover_verdict(A, P)]"]++
	qdel(P)
	return counts

/proc/balcony_railings_probe_run()
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
	map = new /obj/map_metadata/balcony_railings_probe
	// The recipe rows that price a railing's refund (material_recipes_global.txt).
	craftlist_lists = list("global" = list(
		list("/material/wood/soft/", "wooden railing", "/obj/structure/railing/built", "2", "40", "0", "1", "railings", "10", "0", "0", "8", "null"),
		list("/material/stone/", "stone balustrade", "/obj/structure/railing/built/stone", "3", "80", "0", "1", "railings", "20", "0", "0", "8", "null")))

	// Every kind is fixed down and drawn from its own state.
	for (var/path in typesof(/obj/structure/railing/built))
		var/obj/structure/railing/built/K = new path(locate(1, 1, 1))
		balcony_railings_assert(K.anchored && K.density, "built_anchored_[K.railing_style]")
		balcony_railings_assert(K.icon == 'icons/obj/railings_built.dmi' && (K.icon_state in icon_states(K.icon)), "has_sprite_[K.railing_style]")
		balcony_railings_assert(K.falls_with_floor() && is_structure_impact_part(K), "building_part_[K.railing_style]")
		qdel(K)

	// A wooden railing along the north edge of (8, 8).
	var/turf/deck = locate(8, 8, 1)
	var/obj/structure/railing/built/R = new(deck)
	R.set_dir(NORTH)
	var/mob/living/human/H = new(deck)
	balcony_railings_assert(!R.CheckExit(H, locate(8, 9, 1)), "cannot_walk_off_the_edge")
	balcony_railings_assert(R.CheckExit(H, locate(9, 8, 1)), "walks_along_the_edge")
	balcony_railings_assert(!H.Move(locate(8, 9, 1), NORTH) && H.loc == deck, "move_blocked")
	balcony_railings_assert(H.Move(locate(9, 8, 1), EAST) && H.loc == locate(9, 8, 1), "move_sideways")
	H.forceMove(deck)

	// One railing a side: a corner is fine, a second along the same side is not.
	balcony_railings_assert(railing_build_refusal(deck, /obj/structure/railing/built, NORTH), "same_side_refused")
	balcony_railings_assert(railing_build_refusal(deck, /obj/structure/railing/built/stone, NORTH), "same_side_any_kind_refused")
	balcony_railings_assert(!railing_build_refusal(deck, /obj/structure/railing/built, EAST), "corner_allowed")
	balcony_railings_assert(railing_build_refusal(deck, /obj/structure/railing/built, NORTHEAST), "diagonal_refused")
	balcony_railings_assert(!railing_build_refusal(deck, /obj/structure/closet, NORTH), "other_types_unaffected")
	var/obj/structure/window/barrier/rock/parapet/PP = new(locate(4, 4, 1))
	PP.set_dir(SOUTH)
	balcony_railings_assert(railing_build_refusal(locate(4, 4, 1), /obj/structure/railing/built, SOUTH), "parapet_side_taken")

	// Shots fly over a wooden railing both ways.
	var/list/wood_in = balcony_railings_tally(R, locate(8, 10, 1), 270, 100)
	balcony_railings_assert(wood_in["1"] == 100, "wood_shots_pass_in")
	var/list/wood_out = balcony_railings_tally(R, deck, 90, 100)
	balcony_railings_assert(wood_out["1"] == 100, "wood_shots_pass_out")

	// A stone balustrade covers someone lying behind it from about 30%.
	var/turf/terrace = locate(12, 8, 1)
	var/obj/structure/railing/built/stone/S = new(terrace)
	S.set_dir(NORTH)
	var/list/standing = balcony_railings_tally(S, locate(12, 10, 1), 270, 100)
	balcony_railings_assert(standing["1"] == 100, "stone_standing_not_covered")
	var/mob/living/human/L = new(terrace)
	L.lying = TRUE
	var/list/lying = balcony_railings_tally(S, locate(12, 10, 1), 270, 600)
	balcony_railings_assert(lying["2"] >= 120 && lying["2"] <= 240 && lying["1"] + lying["2"] == 600, "stone_lying_partly_covered")
	var/list/outgoing = balcony_railings_tally(S, terrace, 90, 100)
	balcony_railings_assert(outgoing["1"] == 100, "stone_shoots_out")
	balcony_railings_assert(S.structure_impact_material() == "stone" && S.structure_impact_resistance() > 1, "stone_resists")

	// A hammer gives back what it cost; a blow hard enough breaks it.
	var/obj/item/stack/refund = R.railing_dismantle_refund()
	balcony_railings_assert(istype(refund, /obj/item/stack/material/woodplank) && refund.amount == 2, "wood_refund_two_planks")
	var/obj/item/stack/stone_refund = S.railing_dismantle_refund()
	balcony_railings_assert(istype(stone_refund, /obj/item/stack/material/stone) && stone_refund.amount == 3, "stone_refund_three")
	var/obj/structure/railing/built/brick/B = new(locate(2, 8, 1))
	balcony_railings_assert(istype(B.railing_dismantle_refund(), /obj/item/weapon/clay/advclaybricks/fired), "brick_refund_bricks")
	var/obj/structure/railing/built/glass/G = new(locate(3, 8, 1))
	G.structure_impact(1000, IMPACT_CRUSH)
	balcony_railings_assert(QDELETED(G), "impact_breaks")
	R.take_damage(500)
	balcony_railings_assert(QDELETED(R), "damage_breaks")

/world/New()
	OpenPort("none")
	var/error = null
	try
		balcony_railings_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	if (!error && balcony_railings_runtime)
		error = balcony_railings_runtime
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = balcony_railings_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
