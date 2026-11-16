// Full-source probe: arrow slits, gun loops and battlements (castle_defences.dm).
// A slit lets shots out from the tile right behind it and stops most shots
// from outside; a player-built battlement covers one side and fully covers
// someone crouching behind it; mapped crenelated walls keep the old rules.
/world
	hub = ""
	visibility = 0
	maxx = 16
	maxy = 16
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/castle_defences_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/castle_defences_probe/New()
	map = src

/turf/floor/plating/castle_defences_probe

var/castle_defences_probe_checks = 0
var/castle_defences_runtime = null

/world/Error(exception/e)
	if (!castle_defences_runtime)
		castle_defences_runtime = "runtime [e] ([e.file]:[e.line])"

/proc/castle_defences_assert(ok, label)
	castle_defences_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

// A shot from turf `from` flying at `angle` degrees (0 east, 90 north).
/proc/castle_defences_shot(turf/from, angle)
	var/obj/item/projectile/P = new /obj/item/projectile(from)
	P.starting = from
	P.angle = angle
	return P

// How many of `tries` shots get each verdict.
/proc/castle_defences_tally(atom/A, turf/from, angle, tries = 400)
	var/obj/item/projectile/P = castle_defences_shot(from, angle)
	var/list/counts = list("0" = 0, "1" = 0, "2" = 0)
	for (var/i in 1 to tries)
		counts["[directional_cover_verdict(A, P)]"]++
	qdel(P)
	return counts

/proc/castle_defences_probe_run()
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
	map = new /obj/map_metadata/castle_defences_probe

	// A stone wall at (8,8) with an arrow slit opening north: inside is (8,7).
	var/obj/covers/stone_wall/W = new(locate(8, 8, 1))
	sleep(2)
	castle_defences_assert(W.can_take_slit(), "stone_wall_takes_slit")
	var/full_health = W.maxhealth
	castle_defences_assert(W.opacity, "wall_opaque_before")
	castle_defences_assert(directional_cover_verdict(W, castle_defences_shot(locate(8, 7, 1), 90)) == DIRECTIONAL_COVER_DEFAULT, "plain_wall_default")

	var/mob/living/human/H = new(locate(8, 7, 1))
	castle_defences_assert(!W.slit_cut_refusal(H), "inside_square_on_may_cut")
	var/mob/living/human/D = new(locate(9, 7, 1))
	castle_defences_assert(W.slit_cut_refusal(D), "diagonal_may_not_cut")

	W.cut_slit(SLIT_ARROW, get_dir(H, W))
	castle_defences_assert(W.slit == SLIT_ARROW && W.slit_dir == NORTH, "slit_faces_away_from_cutter")
	castle_defences_assert(!W.opacity && W.density, "slit_seen_through_but_solid")
	castle_defences_assert(W.maxhealth == full_health - round(full_health * 0.2), "slit_weakens_wall")
	castle_defences_assert(W.overlays.len >= 1, "slit_drawn")
	castle_defences_assert(W.slit_cut_refusal(H), "no_second_slit")

	// Out from the tile right behind it: about 95% pass, even 45 degrees off.
	var/list/out_straight = castle_defences_tally(W, locate(8, 7, 1), 90)
	castle_defences_assert(out_straight["1"] >= 360 && out_straight["0"] == 0, "out_from_behind_passes")
	var/list/out_angled = castle_defences_tally(W, locate(8, 7, 1), 45)
	castle_defences_assert(out_angled["1"] >= 360, "out_within_arc_passes")
	// Out from further back: ordinary wall rules.
	castle_defences_assert(directional_cover_verdict(W, castle_defences_shot(locate(8, 5, 1), 90)) == DIRECTIONAL_COVER_DEFAULT, "out_from_back_ordinary")
	// In from outside: about 95% hit stone.
	var/list/in_straight = castle_defences_tally(W, locate(8, 12, 1), 270)
	castle_defences_assert(in_straight["2"] >= 360 && in_straight["1"] >= 1, "in_mostly_blocked")
	// Sideways along the wall: ordinary rules.
	castle_defences_assert(directional_cover_verdict(W, castle_defences_shot(locate(4, 8, 1), 0)) == DIRECTIONAL_COVER_DEFAULT, "sideways_ordinary")

	W.fill_slit()
	castle_defences_assert(!W.slit && W.opacity && W.maxhealth == full_health, "filled_slit_restores")

	// Gun loop works the same way.
	W.cut_slit(SLIT_GUN, EAST)
	castle_defences_assert(W.slit_name() == "gun loop", "gun_loop_named")
	var/list/gun_out = castle_defences_tally(W, locate(7, 8, 1), 0)
	castle_defences_assert(gun_out["1"] >= 360, "gun_loop_out_passes")

	// Straw walls and archways take no slit.
	var/obj/covers/straw_wall/straw = new(locate(3, 3, 1))
	castle_defences_assert(!straw.can_take_slit(), "straw_refused")

	// A player-built battlement facing south: inside is north of it.
	var/obj/structure/barricade/stone_h/crenelated/B = new(locate(5, 12, 1))
	castle_defences_assert(directional_cover_verdict(B, castle_defences_shot(locate(5, 9, 1), 90)) == DIRECTIONAL_COVER_DEFAULT, "mapped_battlement_two_way")
	var/mob/living/human/builder = new(locate(5, 12, 1))
	builder.dir = SOUTH
	battlement_after_build(B, builder)
	castle_defences_assert(B.outward_dir == SOUTH, "battlement_faces_builder_dir")
	var/list/bat_out = castle_defences_tally(B, locate(5, 13, 1), 270)
	castle_defences_assert(bat_out["1"] == 400, "battlement_out_free")
	var/list/bat_in = castle_defences_tally(B, locate(5, 8, 1), 90)
	castle_defences_assert(bat_in["2"] >= 300 && bat_in["1"] >= 20, "battlement_in_mostly_blocked")
	var/mob/living/human/crouch = new(locate(5, 13, 1))
	crouch.lying = TRUE
	var/list/bat_crouch = castle_defences_tally(B, locate(5, 8, 1), 90)
	castle_defences_assert(bat_crouch["2"] == 400, "crouching_fully_covered")
	var/obj/structure/barricade/stone_h/plain = new(locate(10, 12, 1))
	battlement_after_build(plain, builder)
	castle_defences_assert(!plain.outward_dir, "plain_barricade_not_battlement")

/world/New()
	OpenPort("none")
	var/error = null
	try
		castle_defences_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	if (!error && castle_defences_runtime)
		error = castle_defences_runtime
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = castle_defences_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
