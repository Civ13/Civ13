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

	// A shutter fitted from the inside shuts the slit: opaque, nothing passes.
	castle_defences_assert(W.slit_inside_user(H) && !W.slit_inside_user(D), "shutter_from_inside_only")
	var/obj/item/stack/material/wood/planks = new(locate(8, 7, 1), 5)
	castle_defences_assert(W.fit_slit_shutter(planks, D) && !W.slit_shutter, "shutter_refused_outside")
	qdel(planks)
	W.slit_shutter = TRUE
	castle_defences_assert(W.set_slit_shut(TRUE) && W.opacity, "shut_slit_opaque")
	var/list/shut_out = castle_defences_tally(W, locate(8, 7, 1), 90, 50)
	castle_defences_assert(shut_out["2"] == 50, "shut_slit_blocks_out")
	castle_defences_assert(W.set_slit_shut(FALSE) && !W.opacity, "opened_slit_clear")
	W.set_slit_shut(TRUE)
	W.fill_slit()
	castle_defences_assert(!W.slit && !W.slit_shutter && !W.slit_shut && W.opacity && W.maxhealth == full_health, "filled_slit_restores")
	castle_defences_assert(locate(/obj/item/stack/material/wood) in locate(8, 7, 1), "shutter_planks_returned")

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
	castle_defences_pour_checks()
	castle_defences_parapet_checks()
	castle_defences_trap_checks()

/proc/castle_defences_bucket(turf/T, id, amount, hot = FALSE)
	var/obj/item/weapon/reagent_containers/glass/bucket/B = new(T)
	B.reagents.add_reagent(id, amount)
	if (hot)
		B.heated_until = world.time + 600
	return B

/proc/castle_defences_pour_checks()
	var/turf/up = locate(2, 14, 1)
	// What leads in a container.
	castle_defences_assert(pour_liquid_of(castle_defences_bucket(up, "water", 20)) == "water", "water_is_water")
	castle_defences_assert(pour_liquid_of(castle_defences_bucket(up, "olive_oil", 20)) == "oil", "olive_oil_is_oil")
	var/obj/item/weapon/reagent_containers/glass/bucket/mix = castle_defences_bucket(up, "water", 40)
	mix.reagents.add_reagent("pitch", 5)
	castle_defences_assert(pour_liquid_of(mix) == "pitch", "pitch_leads")
	castle_defences_assert(pour_burn_damage("water", FALSE) == 0, "cold_water_harmless")
	var/hot_water = pour_burn_damage("water", TRUE)
	castle_defences_assert(hot_water >= 8 && hot_water <= 12, "boiling_water_scalds")
	var/lead = pour_burn_damage("lead", TRUE)
	castle_defences_assert(lead >= 35 && lead <= 45, "molten_lead_worst")

	// A murder hole on one level pours onto the tile it faces.
	var/obj/structure/murder_hole/MH = new(locate(12, 4, 1))
	MH.set_dir(SOUTH)
	castle_defences_assert(MH.pour_target() == locate(12, 3, 1), "murder_hole_target")
	var/mob/living/human/pourer = new(locate(12, 5, 1))
	pourer.a_intent = I_HELP
	var/mob/living/human/under = new(locate(12, 3, 1))
	var/mob/living/human/beside = new(locate(13, 3, 1))
	var/before = under.getBurnLoss()
	var/beside_before = beside.getBurnLoss()
	var/obj/item/weapon/reagent_containers/glass/bucket/oil = castle_defences_bucket(locate(12, 5, 1), "olive_oil", 30, TRUE)
	castle_defences_assert(castle_pour(MH, oil, pourer, MH.pour_target()), "hot_oil_poured")
	castle_defences_assert(under.getBurnLoss() > before, "hot_oil_burns_below")
	castle_defences_assert(beside.getBurnLoss() == beside_before, "small_pour_one_tile")
	castle_defences_assert(locate(/obj/effect/castle_slick) in locate(12, 3, 1), "oil_leaves_slick")
	castle_defences_assert(!oil.reagents.total_volume && !oil.is_hot(), "pour_empties_and_cools")

	// A big pour splashes the tiles around at half strength.
	beside_before = beside.getBurnLoss()
	var/obj/item/weapon/reagent_containers/glass/bucket/big = castle_defences_bucket(locate(12, 5, 1), "water", 80, TRUE)
	castle_pour(MH, big, pourer, MH.pour_target())
	castle_defences_assert(beside.getBurnLoss() > beside_before, "big_pour_splashes_beside")

	// Solid lead won't pour; quicklime blinds; hot pitch sets people alight.
	var/obj/item/weapon/reagent_containers/glass/bucket/cold_lead = castle_defences_bucket(locate(12, 5, 1), "lead", 10)
	castle_defences_assert(!castle_pour(MH, cold_lead, pourer, MH.pour_target()) && cold_lead.reagents.total_volume == 10, "cold_lead_refused")
	castle_pour(MH, castle_defences_bucket(locate(12, 5, 1), "quicklime_powder", 10), pourer, MH.pour_target())
	castle_defences_assert(under.eye_blind >= 5, "quicklime_blinds")
	castle_pour(MH, castle_defences_bucket(locate(12, 5, 1), "pitch", 20, TRUE), pourer, MH.pour_target())
	castle_defences_assert(under.on_fire, "hot_pitch_ignites")

	// A stone dropped from above hits the head.
	var/mob/living/human/target = new(locate(14, 9, 1))
	var/brute = target.getBruteLoss()
	var/obj/item/stack/material/stone/rock = new(locate(14, 9, 1))
	falling_item_strike(rock, locate(14, 9, 1))
	castle_defences_assert(target.getBruteLoss() > brute, "falling_stone_hurts")
	castle_defences_assert(falling_item_damage(rock) >= 15, "stone_heavy")

	// A machicolation drops onto the tile in front of it on one level.
	var/obj/structure/castle_overhang/M = new(locate(3, 9, 1))
	M.set_dir(WEST)
	castle_defences_assert(M.pour_target() == locate(2, 9, 1), "machicolation_target")
	var/obj/structure/castle_overhang/hoarding/HO = new(locate(3, 7, 1))
	HO.catch_fire()
	castle_defences_assert(HO.burning && HO.icon_state == "hoarding_burning", "hoarding_burns")

	// A tar kiln turns a load of wood into pitch.
	var/obj/structure/tar_kiln/K = new(locate(6, 2, 1))
	K.burning = TRUE
	K.burn_left = 50
	K.kiln_tick()
	castle_defences_assert(K.pitch == 40 && !K.burning, "kiln_makes_pitch")
	var/obj/item/weapon/reagent_containers/glass/bucket/tar = new(locate(6, 3, 1))
	var/mob/living/human/tarrer = new(locate(6, 3, 1))
	K.attackby(tar, tarrer)
	castle_defences_assert(tar.reagents.get_reagent_amount("pitch") > 0, "draw_pitch")

	// A brazier heats only when lit.
	var/obj/structure/brazier/BR = new(locate(9, 2, 1))
	castle_defences_assert(!pour_heat_source_lit(BR), "cold_brazier")
	BR.on = TRUE
	castle_defences_assert(pour_heat_source_lit(BR), "lit_brazier")

// Gateway traps (castle_traps.dm), in the free corner x 13-16, y 11-16.
/proc/castle_defences_trap_checks()
	// A trapdoor goes only over an open pit (or open air with a level below).
	castle_defences_assert(trapdoor_site_refusal(locate(13, 11, 1)), "trapdoor_needs_hole")
	var/obj/structure/stone_age_trap/pit/pit = new(locate(13, 12, 1))
	pit.staked = TRUE
	castle_defences_assert(!trapdoor_site_refusal(pit.loc), "trapdoor_fits_open_pit")
	var/obj/structure/castle_trapdoor/D = new(pit.loc)
	castle_defences_assert(trapdoor_site_refusal(pit.loc), "one_trapdoor_per_tile")
	var/mob/living/human/victim = new(pit.loc)
	var/brute = victim.getBruteLoss()
	var/obj/structure/castle_trap_lever/lever = new(locate(15, 12, 1))
	castle_defences_assert(D in lever.trapdoors(), "lever_reaches_trapdoor")
	castle_defences_assert(!(D in new /obj/structure/castle_trap_lever(locate(16, 16, 1)).trapdoors()), "lever_range_limited")
	lever.work(TRUE)
	castle_defences_assert(D.open && D.icon_state == "trapdoor_open" && lever.pulled, "lever_drops_trapdoor")
	castle_defences_assert(pit.buckled_mob == victim && victim.getBruteLoss() > brute, "victim_falls_on_stakes")
	var/mob/living/human/second = new(locate(13, 13, 1))
	second.Move(pit.loc)
	castle_defences_assert(pit.buckled_mob == victim && second.loc == pit.loc, "second_faller_not_rebuckled")
	lever.work(FALSE)
	castle_defences_assert(!D.open && !lever.pulled, "lever_shuts_trapdoor")
	castle_defences_assert(castle_trapdoor_holds(pit.loc, second) && castle_trapdoor_holds(locate(16, 11, 1), D), "shut_trapdoor_holds")
	D.open = TRUE
	castle_defences_assert(!castle_trapdoor_holds(pit.loc, second), "open_trapdoor_drops")

	// Pits belong to the digger's side on a team map too.
	var/mob/living/human/redcoat = new(locate(14, 16, 1))
	redcoat.faction_text = "RED"
	var/mob/living/human/bluecoat = new(locate(14, 16, 1))
	bluecoat.faction_text = "BLUE"
	var/obj/structure/stone_age_trap/pit/side_pit = new(locate(16, 13, 1))
	side_pit.dug_by(redcoat)
	castle_defences_assert(side_pit.tribe == "RED" && side_pit.knows_pit(redcoat) && !side_pit.knows_pit(bluecoat), "pit_keyed_to_side")

	// A portcullis dropped on someone crushes and pins them.
	var/obj/structure/castle_gate/portcullis/PC = new(locate(14, 14, 1))
	PC.open = TRUE
	PC.update_state()
	var/mob/living/human/under = new(PC.loc)
	brute = under.getBruteLoss()
	PC.set_open(FALSE)
	castle_defences_assert(under.getBruteLoss() >= brute + 10 && under.weakened, "portcullis_crushes")

	// Caltrops wound a bare foot and lame a horse.
	var/obj/item/weapon/caltrops/C = new(locate(15, 15, 1))
	var/mob/living/human/walker = new(locate(15, 16, 1))
	brute = walker.getBruteLoss()
	castle_defences_assert(C.caltrop_step(walker) && walker.getBruteLoss() > brute, "caltrops_hurt_feet")
	var/mob/living/simple_animal/horse/H = new(locate(16, 15, 1))
	castle_defences_assert(C.caltrop_step(H) && H.lamed_until > world.time, "caltrops_lame_horse")

	// A ladder fork pushes a deployed siege ladder off the wall.
	castle_defences_assert(ladder_pusher(new /obj/item/weapon/ladder_fork(locate(16, 11, 1))), "fork_pushes")

// A parapet on the north edge of (11, 15): its tile (11, 15) is behind it.
/proc/castle_defences_parapet_checks()
	var/obj/structure/window/barrier/rock/parapet/PP = new(locate(11, 15, 1))
	PP.set_dir(NORTH)
	var/list/out = castle_defences_tally(PP, locate(11, 15, 1), 90, 100)
	castle_defences_assert(out["1"] == 100, "parapet_out_passes")
	var/list/back_shot = castle_defences_tally(PP, locate(11, 12, 1), 90, 100)
	castle_defences_assert(back_shot["1"] == 100, "parapet_shot_from_further_back_passes")
	var/list/inbound = castle_defences_tally(PP, locate(11, 16, 1), 270, 400)
	castle_defences_assert(inbound["2"] >= 300 && inbound["1"] >= 20, "parapet_in_mostly_blocked")
	var/list/side = castle_defences_tally(PP, locate(10, 15, 1), 0, 50)
	castle_defences_assert(side["0"] == 50, "parapet_side_default")
	var/mob/living/human/croucher = new(locate(11, 15, 1))
	croucher.lying = TRUE
	var/list/crouched = castle_defences_tally(PP, locate(11, 16, 1), 270, 100)
	castle_defences_assert(crouched["2"] == 100, "parapet_crouch_full_cover")
	var/obj/item/projectile/stray = castle_defences_shot(locate(10, 15, 1), 0)
	castle_defences_assert(PP.CanPass(stray, locate(12, 15, 1)) && PP.CanPassOut(stray), "parapet_lets_side_shots_by")
	qdel(stray)
	var/obj/structure/window/barrier/sandstone/parapet/SP = new(locate(12, 15, 1))
	SP.set_dir(NORTH)
	castle_defences_assert(directional_cover_verdict(SP, castle_defences_shot(locate(12, 15, 1), 90)) == DIRECTIONAL_COVER_PASS, "sandstone_parapet_shared_rule")
	castle_defences_assert(!PP.climbable && !SP.climbable, "parapet_not_vaulted")

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
