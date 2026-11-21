// Full-source probe for whole-body motion: the posture handshake, the eased
// fall and stand-up, hit recoil, priorities, the config level and channel
// ownership. Real humans; world.time stays at 0, so the probe moves the
// motion clock itself.
/world
	hub = ""
	visibility = 0
	maxx = 12
	maxy = 12
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/body_motion_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/body_motion_probe/New()
	map = src

/turf/floor/plating/body_motion_probe

/mob/living/human/body_motion_probe
	var/probe_watched = TRUE

/mob/living/human/body_motion_probe/body_motion_watched()
	return probe_watched

var/body_motion_probe_checks = 0

/proc/body_motion_probe_assert(ok, label)
	body_motion_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/body_motion_probe_point(matrix/M, x, y)
	return list(M.a * x + M.b * y + M.c, M.d * x + M.e * y + M.f)

// Clears the running motion as if its time had passed.
/proc/body_motion_probe_idle(mob/living/human/H)
	H.body_motion_until = -100
	H.body_motion_started = -100
	H.body_motion_priority = 0

/proc/body_motion_probe_run()
	config = new
	config.webhook_can_fire = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	movementMachine = new
	map = new /obj/map_metadata/body_motion_probe
	map.ordinal_age = 0

	var/mob/living/human/body_motion_probe/H = new(locate(5, 5, 1))
	H.stat = CONSCIOUS
	var/mob/living/human/body_motion_probe/A = new(locate(4, 5, 1))
	A.stat = CONSCIOUS
	body_motion_probe_assert(config.body_motion == BODY_MOTION_FULL, "default_level_full")

	// --- matrices: rotation pivots at the feet ---------------------------------
	var/matrix/rest = H.posture_transform()
	var/list/feet = body_motion_probe_point(body_motion_matrix(rest, 3, 0, 8), 0, -16)
	body_motion_probe_assert(abs(feet[1] - 3) < 0.01 && abs(feet[2] + 16) < 0.01, "feet_stay_put_in_a_lean")
	var/list/head = body_motion_probe_point(body_motion_matrix(rest, 0, 0, 8), 0, 16)
	body_motion_probe_assert(head[1] > 3, "positive_turn_leans_head_east")
	body_motion_probe_assert(body_motion_matrix_same(body_motion_matrix(rest), rest), "empty_key_is_rest")

	// --- first draw snaps; no motion is claimed --------------------------------
	H.body_motion_drawn_turned = null
	H.update_posture_transform()
	body_motion_probe_assert(H.body_motion_until == 0 && body_motion_matrix_same(H.transform, rest), "first_draw_snaps")

	// --- eased fall ------------------------------------------------------------
	H.lying = TRUE
	var/matrix/lying_rest = H.posture_transform()
	H.update_posture_transform()
	body_motion_probe_assert(H.body_motion_until == world.time + 4 && H.body_motion_priority == BODY_MOTION_PRIORITY_POSTURE, "fall_claims_4ds")
	body_motion_probe_assert(body_motion_matrix_same(H.transform, lying_rest), "fall_ends_lying")
	// A redraw mid-fall leaves the running motion alone.
	H.update_icons()
	body_motion_probe_assert(H.body_motion_until == world.time + 4 && body_motion_matrix_same(H.transform, lying_rest), "redraw_keeps_fall")

	// --- recoil while lying only shifts ----------------------------------------
	body_motion_probe_idle(H)
	body_motion_probe_assert(H.body_motion_recoil(A) && body_motion_matrix_same(H.transform, lying_rest), "lying_recoil_returns_to_rest")

	// --- eased stand-up --------------------------------------------------------
	body_motion_probe_idle(H)
	H.lying = FALSE
	H.update_posture_transform()
	body_motion_probe_assert(H.body_motion_until == world.time + 6 && body_motion_matrix_same(H.transform, rest), "stand_up_claims_6ds")
	// A posture change during a stand-up re-aims it at once.
	H.lying = TRUE
	H.update_posture_transform()
	body_motion_probe_assert(H.body_motion_until == world.time + 4 && body_motion_matrix_same(H.transform, lying_rest), "fall_interrupts_stand")
	H.lying = FALSE
	H.update_posture_transform()
	body_motion_probe_idle(H)

	// --- hit recoil ------------------------------------------------------------
	body_motion_probe_assert(H.body_motion_recoil(A), "recoil_plays")
	body_motion_probe_assert(H.body_motion_until == world.time + 3 && H.body_motion_priority == BODY_MOTION_PRIORITY_COMBAT, "recoil_claims_3ds")
	body_motion_probe_assert(body_motion_matrix_same(H.transform, rest), "recoil_ends_at_rest")
	body_motion_probe_assert(!H.body_motion_recoil(H), "no_recoil_from_self")
	// A lower priority motion waits; posture still plays over combat.
	H.body_motion_priority = BODY_MOTION_PRIORITY_POSTURE
	body_motion_probe_assert(!H.body_motion_recoil(A), "recoil_waits_for_posture")
	body_motion_probe_idle(H)
	// The gap between two starts.
	H.body_motion_until = world.time - 1
	H.body_motion_started = world.time - 1
	body_motion_probe_assert(!H.body_motion_recoil(A), "min_gap_between_motions")
	body_motion_probe_idle(H)

	// --- lying down on purpose lowers slowly ------------------------------------
	H.resting = TRUE
	H.lying = TRUE
	H.update_posture_transform()
	body_motion_probe_assert(H.body_motion_until == world.time + 6 && body_motion_matrix_same(H.transform, H.posture_transform()), "rest_lies_down_6ds")
	body_motion_probe_idle(H)
	H.resting = FALSE
	H.lying = FALSE
	H.update_posture_transform()
	body_motion_probe_idle(H)

	// --- work strikes on the tool tick ----------------------------------------------
	var/turf/east_turf = locate(6, 5, 1)
	body_motion_probe_assert(H.body_motion_work(east_turf) && H.body_motion_until == world.time + 5 && H.body_motion_priority == BODY_MOTION_PRIORITY_LOW, "work_strike_5ds")
	body_motion_probe_assert(body_motion_matrix_same(H.transform, rest), "work_ends_at_rest")
	// The next tick, 5 ds later, starts the next strike.
	H.body_motion_started = world.time - 5
	H.body_motion_until = world.time
	body_motion_probe_assert(H.body_motion_work(east_turf), "work_repeats_each_tick")
	// A hit cuts in over work; work never cuts in over a hit.
	H.body_motion_started = -100
	body_motion_probe_assert(H.body_motion_recoil(A), "recoil_over_work")
	H.body_motion_started = -100
	body_motion_probe_assert(!H.body_motion_work(east_turf), "work_waits_for_recoil")
	body_motion_probe_idle(H)

	// --- sitting and emotes -----------------------------------------------------
	body_motion_probe_assert(H.body_motion_settle() && H.body_motion_until == world.time + 3, "seat_settle_3ds")
	body_motion_probe_idle(H)
	var/list/emote_times = list("nod" = 4, "shake" = 4, "bow" = 6, "shrug" = 4, "wave" = 5, "salute" = 6)
	for (var/act in emote_times)
		body_motion_probe_assert(H.body_motion_emote(act) && H.body_motion_until == world.time + emote_times[act], "emote_[act]")
		body_motion_probe_assert(body_motion_matrix_same(H.transform, rest), "emote_[act]_ends_at_rest")
		body_motion_probe_idle(H)
	body_motion_probe_assert(!H.body_motion_emote("smile"), "text_emotes_stay_still")
	H.lying = TRUE
	H.update_posture_transform()
	body_motion_probe_idle(H)
	body_motion_probe_assert(!H.body_motion_emote("nod") && !H.body_motion_work(east_turf), "no_gestures_lying")
	H.lying = FALSE
	H.update_posture_transform()
	body_motion_probe_idle(H)

	// --- swings, parries and reflexes -------------------------------------------
	var/obj/item/weapon/material/sword/arabsword/blade = new(H.loc)
	var/obj/item/weapon/material/hatchet/club_like = new(H.loc)
	club_like.edge = FALSE
	club_like.sharp = FALSE
	club_like.force = 10
	var/obj/item/weapon/material/hatchet/pointy = new(H.loc)
	pointy.edge = FALSE
	pointy.sharp = TRUE
	body_motion_probe_assert(H.body_motion_swing(east_turf, blade) && H.body_motion_until == world.time + 4 && H.body_motion_priority == BODY_MOTION_PRIORITY_COMBAT, "edged_swing_rolls_4ds")
	body_motion_probe_assert(body_motion_matrix_same(H.transform, rest), "swing_ends_at_rest")
	body_motion_probe_idle(H)
	body_motion_probe_assert(H.body_motion_swing(east_turf, club_like) && H.body_motion_until == world.time + 4, "blunt_swing_4ds")
	body_motion_probe_idle(H)
	body_motion_probe_assert(body_motion_blunt(club_like) && !body_motion_blunt(blade) && !body_motion_blunt(pointy), "blunt_classes")
	body_motion_probe_assert(H.body_motion_recoil(A, 1) && H.body_motion_until == world.time + 4 && body_motion_matrix_same(H.transform, rest), "blunt_recoil_waits_1ds")
	body_motion_probe_idle(H)
	body_motion_probe_assert(!H.body_motion_swing(east_turf, pointy), "thrust_keeps_plain_lunge")
	body_motion_probe_assert(!H.body_motion_swing(locate(5, 6, 1), blade), "north_swing_no_roll")
	body_motion_probe_assert(!H.body_motion_swing(east_turf, null), "unarmed_keeps_plain_lunge")
	body_motion_probe_assert(H.body_motion_parry(A) && H.body_motion_until == world.time + 3, "parry_3ds")
	body_motion_probe_idle(H)
	body_motion_probe_assert(H.body_motion_slip(A) && H.body_motion_until == world.time + 3, "slip_3ds")
	body_motion_probe_idle(H)
	body_motion_probe_assert(H.body_motion_sprawl(A) && H.body_motion_until == world.time + 4, "sprawl_4ds")
	body_motion_probe_idle(H)
	body_motion_probe_assert(H.body_motion_stance_set() && H.body_motion_until == world.time + 3, "stance_set_3ds")
	body_motion_probe_idle(H)
	qdel(blade)
	qdel(club_like)
	qdel(pointy)

	// --- unwatched bodies snap -------------------------------------------------
	H.probe_watched = FALSE
	body_motion_probe_assert(!H.body_motion_recoil(A), "unwatched_no_recoil")
	H.lying = TRUE
	H.update_posture_transform()
	body_motion_probe_assert(H.body_motion_until <= 0 && body_motion_matrix_same(H.transform, H.posture_transform()), "unwatched_fall_snaps")
	H.lying = FALSE
	H.update_posture_transform()
	H.probe_watched = TRUE

	// --- config levels ---------------------------------------------------------
	config.body_motion = BODY_MOTION_REDUCED
	body_motion_probe_assert(H.body_motion_recoil(A), "reduced_keeps_recoil")
	body_motion_probe_idle(H)
	body_motion_probe_assert(!H.body_motion_work(locate(6, 5, 1)) && !H.body_motion_emote("nod") && !H.body_motion_settle(), "reduced_drops_work_emotes_seats")
	body_motion_probe_assert(!H.body_motion_stance_set(), "reduced_drops_stance_set")
	body_motion_probe_assert(H.body_motion_parry(A), "reduced_keeps_parry")
	body_motion_probe_idle(H)
	config.body_motion = BODY_MOTION_OFF
	body_motion_probe_assert(!H.body_motion_recoil(A), "off_no_recoil")
	H.lying = TRUE
	H.update_posture_transform()
	body_motion_probe_assert(H.body_motion_until <= 0 && body_motion_matrix_same(H.transform, H.posture_transform()), "off_fall_snaps")
	H.lying = FALSE
	H.update_posture_transform()
	config.body_motion = BODY_MOTION_FULL

	// --- dead bodies don't recoil ----------------------------------------------
	H.stat = DEAD
	body_motion_probe_assert(!H.body_motion_recoil(A), "dead_no_recoil")
	H.stat = CONSCIOUS

	// --- channel ownership -----------------------------------------------------
	body_motion_probe_assert(!H.pixel_x && !H.pixel_y && !H.pixel_w && !H.pixel_z, "pixel_channels_untouched")

// Exports a dressed body and the motion keys for tests/body_motion/render.py.
/proc/body_motion_probe_flat(mob/living/human/H, direction)
	var/icon/flat = icon(H.stand_icon, dir = direction)
	for (var/image/I in H.overlays_standing)
		if (!I || !I.icon)
			continue
		var/icon/O = icon(I.icon, I.icon_state, direction)
		flat.Blend(O, ICON_OVERLAY, 1 + I.pixel_x, 1 + I.pixel_y)
		for (var/image/sub in I.overlays)
			if (sub.icon)
				flat.Blend(icon(sub.icon, sub.icon_state, direction), ICON_OVERLAY)
	return flat

/proc/body_motion_probe_keys(matrix/M)
	return list(M.a, M.b, M.c, M.d, M.e, M.f)

/proc/body_motion_probe_render()
	var/mob/living/human/body_motion_probe/D = new(locate(8, 8, 1))
	D.stat = CONSCIOUS
	D.h_style = "Short Hair"
	D.equip_to_slot_or_del(new /obj/item/clothing/under/medieval(D), slot_w_uniform)
	D.equip_to_slot_or_del(new /obj/item/clothing/shoes/medieval(D), slot_shoes)
	D.equip_to_slot_or_del(new /obj/item/clothing/head/helmet/medieval/coif_helmet(D), slot_head)
	D.equip_to_slot_or_del(new /obj/item/weapon/material/sword/arabsword(D), slot_r_hand)
	D.update_hair(0)
	D.regenerate_icons()
	for (var/direction in list(SOUTH, NORTH, EAST, WEST))
		fcopy(body_motion_probe_flat(D, direction), "render_[direction].png")
	var/obj/item/weapon/material/hatchet/axe = new(D.loc)
	fcopy(icon(axe.icon, axe.icon_state, SOUTH), "render_tool.png")
	var/obj/structure/wild/rock/stone = new(locate(9, 9, 1))
	fcopy(icon(stone.icon, stone.icon_state, SOUTH), "render_rock.png")
	var/matrix/stand = D.posture_transform()
	D.lying = TRUE
	var/matrix/lie = D.posture_transform()
	D.lying = FALSE
	var/list/keys = list(
		"stand" = body_motion_probe_keys(stand),
		"lying" = body_motion_probe_keys(lie),
		"fall_settle" = body_motion_probe_keys(body_motion_matrix(lie, 0, -1)),
		"fall_lean" = body_motion_probe_keys(body_motion_matrix(stand, 0, 0, 45)),
		"stand_lean" = body_motion_probe_keys(body_motion_matrix(stand, 0, 0, 45)),
		"recoil_east" = body_motion_probe_keys(body_motion_matrix(stand, 3, 0, 8)),
		"recoil_south" = body_motion_probe_keys(body_motion_matrix(stand, 0, -3)))
	text2file(json_encode(keys), "keys.json")

/world/New()
	OpenPort("none")
	var/error = null
	try
		body_motion_probe_run()
		if (fexists("render.flag"))
			body_motion_probe_render()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = body_motion_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
