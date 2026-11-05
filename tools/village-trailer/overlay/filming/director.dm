// Village trailer director: the production chain and its camera.
// Every gameplay step goes through the game's own handlers (attackby,
// attack_hand, attack_self, MouseDrop_T, Life). Pre-roll staging only gives
// actors their starting clothes/tools and places the vehicles and the ready
// wheat; the camera never shows the staging.

#define TRAILER_MAP_W 100
#define TRAILER_MAP_H 20
#define TRAILER_TIMEOUT 3600
#define TRAILER_OPENING_X 8
#define TRAILER_OPENING_Y 10.5
#define TRAILER_STEP 4

var/list/trailer_living = list()
var/list/trailer_ripe = list()
var/trailer_timeline_origin = 0
var/list/trailer_timeline = list()

var/mob/living/human/intro_actor/trailer_gatherer
var/mob/living/human/intro_actor/trailer_farmer
var/mob/living/human/intro_actor/trailer_baker
var/mob/living/human/intro_actor/trailer_customer
var/mob/living/human/intro_actor/trailer_engineer
var/mob/living/simple_animal/horse/trailer_horse
var/mob/living/simple_animal/horse/trailer_horse2
var/obj/structure/vehicle/carriage/trailer_carriage
var/obj/structure/trains/locomotive/coal/trailer_locomotive
var/obj/structure/trains/transport/cabin/trailer_cabin
var/obj/item/weapon/material/kitchen/utensil/knife/trailer_knife
var/obj/item/weapon/material/scythe/trailer_scythe
var/obj/item/weapon/reagent_containers/glass/bucket/trailer_bucket

// ---------------------------------------------------------------- camera
// A pixel-precise smoothed camera rig. The rig keeps a floating-point
// position in world pixels and moves it every tick with a critically damped
// spring toward its target (a fixed point, or a followed atom plus a lead
// computed from the atom's measured velocity, so the camera travels ahead of
// a walker or vehicle instead of trailing it). The client looks through an
// invisible eye that snaps from tile to tile; the sub-tile remainder goes to
// client.pixel_x/pixel_y through a one-tick animate() so DreamSeeker
// interpolates the motion at its own frame rate. Tile crossings are
// compensated in the same animation sequence, so there is never a hard step.
/obj/trailer_camera
	name = ""
	icon = null
	invisibility = 101
	anchored = TRUE
	density = FALSE
	mouse_opacity = 0
	glide_size = 1024 // the eye jumps; the client offset carries the motion

var/obj/trailer_camera/trailer_cam
var/trailer_cam_px = TRAILER_OPENING_X * 32
var/trailer_cam_py = TRAILER_OPENING_Y * 32
var/trailer_cam_vx = 0
var/trailer_cam_vy = 0
var/trailer_cam_tx = TRAILER_OPENING_X * 32
var/trailer_cam_ty = TRAILER_OPENING_Y * 32
var/atom/trailer_cam_follow
var/trailer_cam_fox = 0
var/trailer_cam_foy = 0
var/trailer_cam_lead = 1          // fraction of the steady-state lag fed forward
var/trailer_cam_omega = 2.6       // spring stiffness (rad/s): ~1.5 s to settle
var/trailer_cam_max_speed = 320   // pixels per second
var/trailer_cam_running = FALSE
// Followed-atom motion model: last tile, when it stepped, the step interval
// and a smoothed velocity in pixels per second.
var/trailer_cam_flx = 0
var/trailer_cam_fly = 0
var/trailer_cam_flt = 0
var/trailer_cam_fdx = 0
var/trailer_cam_fdy = 0
var/trailer_cam_fperiod = 0
var/trailer_cam_fvx = 0
var/trailer_cam_fvy = 0

/proc/trailer_camera_attach(client/C)
	if (!trailer_cam)
		trailer_cam = new(locate(TRAILER_OPENING_X, round(TRAILER_OPENING_Y + 0.5), 1))
	C.perspective = EYE_PERSPECTIVE
	C.eye = trailer_cam
	if (!trailer_cam_running)
		trailer_cam_running = TRUE
		spawn(0)
			trailer_camera_loop()

/proc/trailer_clamp(v, lo, hi)
	return v < lo ? lo : (v > hi ? hi : v)

// Where the followed atom is drawn right now: its tile, pulled back along
// its last step by the part of the glide the client has not finished yet.
/proc/trailer_follow_visual(turf/T)
	var/now = world.time
	if (T.x != trailer_cam_flx || T.y != trailer_cam_fly)
		if (trailer_cam_flt)
			var/dt = max(world.tick_lag, now - trailer_cam_flt) / 10
			var/dx = T.x - trailer_cam_flx
			var/dy = T.y - trailer_cam_fly
			if (abs(dx) <= 2 && abs(dy) <= 2)
				trailer_cam_fdx = dx
				trailer_cam_fdy = dy
				trailer_cam_fperiod = dt
				trailer_cam_fvx = trailer_cam_fvx * 0.5 + (32 * dx / dt) * 0.5
				trailer_cam_fvy = trailer_cam_fvy * 0.5 + (32 * dy / dt) * 0.5
			else
				// A teleport (boarding a vehicle): no velocity from it.
				trailer_cam_fdx = 0
				trailer_cam_fdy = 0
				trailer_cam_fvx = 0
				trailer_cam_fvy = 0
		trailer_cam_flx = T.x
		trailer_cam_fly = T.y
		trailer_cam_flt = now
	var/since = (now - trailer_cam_flt) / 10
	if (trailer_cam_fperiod && since > trailer_cam_fperiod * 2.5)
		// Stopped: let the lead fade out.
		trailer_cam_fvx *= 0.85
		trailer_cam_fvy *= 0.85
	var/remaining = trailer_cam_fperiod ? max(0, 1 - since / trailer_cam_fperiod) : 0
	return list(T.x * 32 - trailer_cam_fdx * 32 * remaining, T.y * 32 - trailer_cam_fdy * 32 * remaining)

/proc/trailer_camera_target()
	var/tx = trailer_cam_tx
	var/ty = trailer_cam_ty
	if (trailer_cam_follow && !QDELETED(trailer_cam_follow))
		var/turf/T = get_turf(trailer_cam_follow)
		if (T)
			var/list/v = trailer_follow_visual(T)
			var/lead = trailer_cam_lead * 2 / trailer_cam_omega
			tx = v[1] + trailer_cam_fox * 32 + trailer_clamp(trailer_cam_fvx * lead, -96, 96)
			ty = v[2] + trailer_cam_foy * 32 + trailer_clamp(trailer_cam_fvy * lead, -96, 96)
			trailer_cam_tx = tx
			trailer_cam_ty = ty
	// Keep the 15x9 view (plus the client's one-tile margin) inside the map.
	tx = trailer_clamp(tx, 8 * 32, (TRAILER_MAP_W - 7) * 32)
	ty = trailer_clamp(ty, 5 * 32, (TRAILER_MAP_H - 4) * 32)
	return list(tx, ty)

/proc/trailer_camera_loop()
	while (!intro_stopping)
		var/dt = world.tick_lag / 10
		var/list/t = trailer_camera_target()
		var/w = trailer_cam_omega
		trailer_cam_vx += (w * w * (t[1] - trailer_cam_px) - 2 * w * trailer_cam_vx) * dt
		trailer_cam_vy += (w * w * (t[2] - trailer_cam_py) - 2 * w * trailer_cam_vy) * dt
		var/speed = sqrt(trailer_cam_vx * trailer_cam_vx + trailer_cam_vy * trailer_cam_vy)
		if (speed > trailer_cam_max_speed)
			trailer_cam_vx *= trailer_cam_max_speed / speed
			trailer_cam_vy *= trailer_cam_max_speed / speed
		trailer_cam_px += trailer_cam_vx * dt
		trailer_cam_py += trailer_cam_vy * dt
		trailer_camera_apply()
		sleep(world.tick_lag)

var/trailer_cam_shown_x = 0
var/trailer_cam_shown_y = 0

// Put the eye on the nearest tile and animate the client's pixel offset to
// the remainder. On a tile change the sequence first re-expresses the
// previous offset relative to the new tile (instantly, together with the eye
// move), then eases to the new offset over the tick.
/proc/trailer_camera_apply(snap = FALSE)
	var/ax = round(trailer_cam_px / 32 + 0.5)
	var/ay = round(trailer_cam_py / 32 + 0.5)
	var/turf/T = locate(ax, ay, 1)
	if (!T || !trailer_cam)
		return
	var/client/C = intro_observer_client
	var/ox = trailer_cam_px - ax * 32
	var/oy = trailer_cam_py - ay * 32
	if (C && C.eye != trailer_cam)
		C.eye = trailer_cam
	if (snap || !C)
		trailer_cam.loc = T
		if (C)
			animate(C, pixel_x = ox, pixel_y = oy, time = 0)
	else if (trailer_cam.loc != T)
		var/turf/old = trailer_cam.loc
		trailer_cam.loc = T
		var/prev_x = old ? trailer_cam_shown_x - (T.x - old.x) * 32 : ox
		var/prev_y = old ? trailer_cam_shown_y - (T.y - old.y) * 32 : oy
		animate(C, pixel_x = prev_x, pixel_y = prev_y, time = 0)
		animate(pixel_x = ox, pixel_y = oy, time = world.tick_lag)
	else
		animate(C, pixel_x = ox, pixel_y = oy, time = world.tick_lag)
	trailer_cam_shown_x = ox
	trailer_cam_shown_y = oy

/proc/trailer_camera_reset_follow()
	trailer_cam_flx = 0
	trailer_cam_fly = 0
	trailer_cam_flt = 0
	trailer_cam_fdx = 0
	trailer_cam_fdy = 0
	trailer_cam_fperiod = 0
	trailer_cam_fvx = 0
	trailer_cam_fvy = 0

// Snap (only used before frame zero).
/proc/trailer_camera_cut(tx, ty)
	trailer_cam_follow = null
	trailer_cam_tx = tx * 32
	trailer_cam_ty = ty * 32
	trailer_cam_px = tx * 32
	trailer_cam_py = ty * 32
	trailer_cam_vx = 0
	trailer_cam_vy = 0
	if (!trailer_cam)
		trailer_cam = new(locate(round(tx + 0.5), round(ty + 0.5), 1))
	trailer_camera_apply(TRUE)
	if (!trailer_cam_running)
		trailer_cam_running = TRUE
		spawn(0)
			trailer_camera_loop()

// Ease toward a fixed point (tile coordinates, fractions allowed) at up to
// tiles_per_second; optionally wait until the camera has settled.
/proc/trailer_camera_pan(tx, ty, tiles_per_second = 5, wait = TRUE)
	trailer_cam_follow = null
	trailer_cam_tx = tx * 32
	trailer_cam_ty = ty * 32
	trailer_cam_max_speed = tiles_per_second * 32
	if (!wait)
		return
	var/deadline = world.time + 150
	while (world.time < deadline)
		var/list/t = trailer_camera_target()
		if (abs(t[1] - trailer_cam_px) < 3 && abs(t[2] - trailer_cam_py) < 3)
			break
		sleep(world.tick_lag)

/proc/trailer_camera_settled(tolerance = 3)
	var/list/t = trailer_camera_target()
	return abs(t[1] - trailer_cam_px) < tolerance && abs(t[2] - trailer_cam_py) < tolerance

// Ease onto a moving atom and keep tracking it, framed ox,oy tiles off its
// position and leading it by `lead` times the spring's steady-state lag.
/proc/trailer_follow(atom/A, ox = 0, oy = 0, max_tiles_per_second = 10, lead = 1)
	if (trailer_cam_follow != A)
		trailer_camera_reset_follow()
	trailer_cam_follow = A
	trailer_cam_fox = ox
	trailer_cam_foy = oy
	trailer_cam_lead = lead
	trailer_cam_max_speed = max_tiles_per_second * 32

/proc/trailer_cam_right_edge()
	return trailer_cam_px + 7.5 * 32

/proc/trailer_cam_left_edge()
	return trailer_cam_px - 7.5 * 32

// ---------------------------------------------------------------- timeline
/proc/trailer_beat(label)
	var/elapsed = world.time - trailer_timeline_origin
	trailer_timeline += list(list("t" = elapsed / 10, "beat" = label))
	trailer_log("beat [label] at [elapsed / 10]s (camera [trailer_cam_px / 32],[trailer_cam_py / 32])")
	fdel("trailer-timeline.json")
	text2file(json_encode(trailer_timeline), "trailer-timeline.json")

// ---------------------------------------------------------------- actors
/proc/trailer_actor(tx, ty, actor_name, uniform_type, face = SOUTH)
	var/mob/living/human/intro_actor/H = new(locate(tx, ty, 1))
	H.real_name = actor_name
	H.name = actor_name
	H.lastarea = get_area(H)
	H.m_intent = "walk"
	H.a_intent = I_HELP
	H.dir = face
	H.equip_to_slot(new uniform_type(H), slot_w_uniform)
	H.equip_to_slot(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	intro_check(!H.client && !H.ckey && H.stat == CONSCIOUS, "fixture-owned human")
	trailer_living += H
	return H

/proc/trailer_pickup(mob/living/human/H, obj/item/I)
	intro_check(I && I.Adjacent(H), "pickup reach: [I]")
	if (H.get_active_hand())
		H.swap_hand()
	intro_check(!H.get_active_hand(), "free hand for [I]")
	I.attack_hand(H)
	intro_check(H.get_active_hand() == I, "picked up [I]")

/proc/trailer_hold(mob/living/human/H, obj/item/I)
	if (H.get_active_hand() != I)
		H.swap_hand()
	intro_check(H.get_active_hand() == I, "[H] holds [I] in active hand")

// Walk one tile at a time through the native movement handlers, cardinal
// steps only (closing the longer axis first, sidestepping around blockers).
/proc/trailer_walk(mob/living/human/H, tx, ty, delay = TRAILER_STEP, token = 0)
	var/guard = 200
	while ((H.x != tx || H.y != ty) && guard-- > 0)
		if (token)
			trailer_job_yield(H, token)
		var/dx = tx - H.x
		var/dy = ty - H.y
		var/hdir = dx > 0 ? EAST : (dx < 0 ? WEST : 0)
		var/vdir = dy > 0 ? NORTH : (dy < 0 ? SOUTH : 0)
		var/list/options = abs(dx) >= abs(dy) ? list(hdir, vdir) : list(vdir, hdir)
		H.glide_size = 32 / max(1, delay / world.tick_lag)
		var/moved = FALSE
		for (var/d in options)
			if (!d)
				continue
			var/turf/before = H.loc
			step(H, d)
			if (H.loc != before)
				moved = TRUE
				break
		if (!moved)
			trailer_log("[H] blocked at [H.x],[H.y] heading [tx],[ty]")
		sleep(max(1, delay))
	intro_check(H.x == tx && H.y == ty, "[H] reached [tx],[ty] (at [H.x],[H.y])")

/proc/trailer_face(mob/living/human/H, atom/A)
	H.dir = get_dir(H, A)

// ---------------------------------------------------------------- staging
/proc/trailer_prepare()
	trailer_log("prepare")
	// Seed gatherer with a knife in the meadow, beside the bush nearest the field.
	trailer_gatherer = trailer_actor(9, 10, "Gatherer", /obj/item/clothing/under/civ1, EAST)
	trailer_knife = new(trailer_gatherer.loc)
	trailer_pickup(trailer_gatherer, trailer_knife)
	// Farmer with a scythe beside the mature wheat.
	trailer_farmer = trailer_actor(19, 10, "Farmer", /obj/item/clothing/under/civ4, NORTH)
	trailer_scythe = new(trailer_farmer.loc)
	trailer_pickup(trailer_farmer, trailer_scythe)
	for (var/obj/structure/farming/plant/wheat/P in world)
		// Explicit initial-state staging: authored crops start ready to harvest.
		P.stage = P.readyStageMin
		var/sprite_name = P.sprite_plant ? P.sprite_plant : P.plant
		P.icon_state = "[sprite_name]-harvest"
		P.name = "ready [P.plant] plant"
		P.desc = "A ready to harvest [P.plant] plant."
		trailer_ripe += P
	// Baker behind the counter; oven fuelled from the bakery's wood store.
	trailer_baker = trailer_actor(34, 11, "Baker", /obj/item/clothing/under/civ4, SOUTH)
	var/obj/structure/oven/oven = trailer_oven()
	var/obj/item/stack/material/wood/W = new(locate(35, 12, 1))
	W.amount = 8
	trailer_walk(trailer_baker, 35, 12, 1)
	trailer_pickup(trailer_baker, W)
	oven.attackby(W, trailer_baker)
	intro_check(oven.fuel >= 1, "oven fuelled through the normal handler")
	if (trailer_baker.get_active_hand())
		trailer_baker.drop_item()
	trailer_bucket = new(locate(36, 10, 1))
	trailer_bucket.reagents.add_reagent("water", 60)
	trailer_walk(trailer_baker, 33, 10, 1)
	trailer_baker.dir = SOUTH
	// The customer browses the market until the bread is in the oven;
	// carriage, horses and train wait outside.
	trailer_customer = trailer_errand_actor(40, 9, "Traveller", /obj/item/clothing/under/civ1, list(
		list("face", EAST), list("wait", 30), list("chat", 15), list("face", SOUTH), list("wait", 20),
		list("face", EAST), list("wait", 25)))
	trailer_carriage = new(locate(43, 6, 1))
	trailer_carriage.dir = EAST
	trailer_horse = new(locate(42, 5, 1))
	trailer_horse2 = new(locate(42, 7, 1))
	trailer_living += trailer_horse
	trailer_living += trailer_horse2
	// The team is harnessed before the take (hitching snaps each horse onto
	// the shafts, which reads as a teleport on camera).
	var/mob/living/human/intro_actor/groom = trailer_actor(41, 6, "Groom", /obj/item/clothing/under/civ4, EAST)
	trailer_carriage.MouseDrop_T(trailer_horse, groom)
	trailer_carriage.MouseDrop_T(trailer_horse2, groom)
	intro_check(trailer_carriage.buckled_animal_propulsion >= 4, "two horses hitched")
	trailer_living -= groom
	qdel(groom)
	trailer_locomotive = new(locate(73, 3, 1))
	trailer_locomotive.dir = EAST
	trailer_stage_train()
	trailer_locomotive.fuel = trailer_locomotive.max_fuel
	trailer_engineer = trailer_actor(74, 4, "Engineer", /obj/item/clothing/under/civ4, SOUTH)
	trailer_stage_life()
	trailer_log("prepare done: [trailer_errands.len] villagers going about their day")

/proc/trailer_oven()
	var/obj/structure/oven/oven = locate(/obj/structure/oven) in locate(35, 13, 1)
	intro_check(oven, "authored oven")
	return oven

/proc/trailer_mill()
	var/obj/structure/mill/large/M = locate(/obj/structure/mill/large) in locate(32, 12, 1)
	intro_check(M, "authored mill")
	return M

// ---------------------------------------------------------------- jobs
// Every villager runs their own job loop for the whole take, so work carries
// on while the camera is elsewhere. Scenes only move the camera and wait for
// the jobs to reach the next step of the chain; a scene that needs to script
// an actor directly takes them off their job first.
var/list/trailer_job_token = list()
var/list/trailer_job_active = list()
var/trailer_job_serial = 0

var/trailer_seeds_gathered = 0
var/trailer_gatherer_planting = FALSE
var/trailer_seeds_planted = 0
var/trailer_wheat_harvested = 0
var/trailer_farmer_batch = 0
var/trailer_farmer_delivering = FALSE
var/trailer_wheat_milled = 0
var/trailer_oven_lit = 0
var/trailer_bread_served = 0
var/list/trailer_counter_bread = list()
var/trailer_baker_idle_spot = 0
var/trailer_engineer_spot = 0
var/trailer_customer_waiting = FALSE
var/trailer_passenger_boarded = FALSE

#define TRAILER_FARMER_BATCH 5

/proc/trailer_job_live(mob/H, token)
	return !intro_stopping && trailer_job_token[H] == token

/proc/trailer_job_yield(mob/H, token)
	if (!trailer_job_live(H, token))
		throw EXCEPTION("job yielded")

/proc/trailer_start_job(mob/H, job)
	var/token = ++trailer_job_serial
	trailer_job_token[H] = token
	spawn(0)
		trailer_job_runner(H, job, token)

/proc/trailer_job_runner(mob/H, job, token)
	trailer_job_active[H] = token
	while (trailer_job_live(H, token))
		try
			if (!call(job)(H, token))
				sleep(10)
		catch (var/exception/job_error)
			if (trailer_job_live(H, token))
				trailer_log("[H] job: [job_error.name] at [job_error.line]")
				sleep(20)
		sleep(1)
	if (trailer_job_active[H] == token)
		trailer_job_active[H] = 0

// Take an actor off their job, waiting for the current step to finish.
/proc/trailer_take(mob/H)
	trailer_job_token[H] = 0
	var/deadline = world.time + 150
	while (trailer_job_active[H] && world.time < deadline)
		sleep(1)

/proc/trailer_wait_for(name, minimum, timeout, label)
	var/deadline = world.time + timeout
	while (global.vars[name] < minimum && world.time < deadline)
		sleep(1)
	intro_check(global.vars[name] >= minimum, label)

/proc/trailer_held(mob/living/human/H, type)
	if (istype(H.l_hand, type))
		return H.l_hand
	if (istype(H.r_hand, type))
		return H.r_hand
	return null

/proc/trailer_open(turf/T)
	if (!T || T.density)
		return FALSE
	for (var/atom/movable/A in T)
		if (A.density)
			return FALSE
	return TRUE

/proc/trailer_nearest(atom/from, list/candidates)
	var/best
	var/best_dist = 1000
	for (var/atom/A in candidates)
		var/d = get_dist(from, A)
		if (d < best_dist)
			best = A
			best_dist = d
	return best

// The gatherer cuts seeds from the meadow bushes and sows the empty rows.
/proc/trailer_job_gatherer(mob/living/human/H, token)
	var/obj/item/stack/farming/seeds/carry = trailer_held(H, /obj/item/stack/farming/seeds)
	if (carry)
		var/list/plots = list()
		for (var/tx in 15 to 26)
			for (var/ty in 8 to 9)
				var/turf/T = locate(tx, ty, 1)
				if (istype(T, /turf/floor/dirt/ploughed) && !(locate(/obj/structure/farming/plant) in T))
					plots += T
		var/turf/plot = trailer_nearest(H, plots)
		if (!plot)
			return FALSE
		trailer_gatherer_planting = TRUE
		trailer_walk(H, plot.x, plot.y + 1, TRAILER_STEP, token)
		trailer_face(H, plot)
		trailer_hold(H, carry)
		plot.attackby(carry, H)
		if (locate(/obj/structure/farming/plant) in plot)
			trailer_seeds_planted++
		sleep(8)
		return TRUE
	var/list/bushes = list()
	for (var/obj/structure/wild/smallbush/B in range(12, locate(8, 11, 1)))
		if (B.seedtimer == 1 && B.x < 14)
			bushes += B
	var/obj/structure/wild/smallbush/B = trailer_nearest(H, bushes)
	if (!B)
		return FALSE
	var/turf/stand
	for (var/d in list(EAST, SOUTH, WEST, NORTH))
		var/turf/T = get_step(B, d)
		if (trailer_open(T))
			stand = T
			break
	intro_check(stand, "open tile beside [B] at [B.x],[B.y]")
	trailer_walk(H, stand.x, stand.y, TRAILER_STEP, token)
	trailer_face(H, B)
	var/obj/item/weapon/material/kitchen/utensil/knife/knife = trailer_held(H, /obj/item/weapon/material/kitchen/utensil/knife)
	intro_check(knife, "gatherer has the knife")
	trailer_hold(H, knife)
	var/list/before = list()
	for (var/obj/item/stack/farming/seeds/S in H.loc)
		before += S
	B.attackby(knife, H)
	sleep(6)
	for (var/obj/item/stack/farming/seeds/S in H.loc)
		if (!(S in before))
			trailer_seeds_gathered++
			trailer_pickup(H, S)
			break
	sleep(4)
	return TRUE

// The farmer scythes the ripe wheat a few plants at a time, then carries each
// sheaf to the mill.
/proc/trailer_job_farmer(mob/living/human/H, token)
	var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/sheaf = trailer_held(H, /obj/item/weapon/reagent_containers/food/snacks/grown/wheat)
	if (sheaf)
		var/obj/structure/mill/large/M = trailer_mill()
		trailer_farmer_delivering = TRUE
		if (H.x < 28)
			trailer_walk(H, 27, 9, TRAILER_STEP, token)
		trailer_walk(H, 32, 8, TRAILER_STEP, token)
		trailer_walk(H, 32, 11, TRAILER_STEP, token)
		var/deadline = world.time + 200
		while (M.current_work && world.time < deadline)
			trailer_job_yield(H, token)
			sleep(2)
		trailer_face(H, M)
		trailer_hold(H, sheaf)
		M.attackby(sheaf, H)
		intro_check(M.current_material == sheaf, "mill accepted the harvested wheat")
		trailer_wheat_milled++
		trailer_farmer_delivering = FALSE
		sleep(5)
		trailer_walk(H, 32, 8, TRAILER_STEP, token)
		trailer_walk(H, 27, 9, TRAILER_STEP, token)
		return TRUE
	var/list/ripe = list()
	for (var/obj/structure/farming/plant/wheat/P in trailer_ripe)
		if (!QDELETED(P))
			ripe += P
	var/list/loose = list()
	for (var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/G in range(8, locate(20, 11, 1)))
		if (isturf(G.loc))
			loose += G
	if (loose.len && (trailer_farmer_batch >= TRAILER_FARMER_BATCH || !ripe.len))
		var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/G = trailer_nearest(H, loose)
		trailer_walk(H, G.x, G.y, TRAILER_STEP, token)
		if (H.l_hand && H.r_hand)
			H.drop_item()
		trailer_pickup(H, G)
		if (loose.len == 1)
			trailer_farmer_batch = 0
		sleep(4)
		return TRUE
	if (!ripe.len)
		return FALSE
	var/obj/item/weapon/material/scythe/scythe = trailer_held(H, /obj/item/weapon/material/scythe)
	if (!scythe)
		intro_check(isturf(trailer_scythe.loc), "scythe within reach")
		trailer_walk(H, trailer_scythe.x, trailer_scythe.y, TRAILER_STEP, token)
		trailer_pickup(H, trailer_scythe)
		scythe = trailer_scythe
	// Work the nearest row first, so each plant is reached from a cleared tile.
	var/low = 100
	for (var/obj/structure/farming/plant/wheat/P in ripe)
		low = min(low, P.y)
	var/list/row = list()
	for (var/obj/structure/farming/plant/wheat/P in ripe)
		if (P.y == low)
			row += P
	var/obj/structure/farming/plant/wheat/P = trailer_nearest(H, row)
	trailer_walk(H, P.x, P.y - 1, TRAILER_STEP, token)
	H.dir = NORTH
	trailer_hold(H, scythe)
	P.attackby(scythe, H)
	if (QDELETED(P))
		trailer_wheat_harvested++
		trailer_farmer_batch++
	sleep(15)
	return TRUE

// The baker turns any flour into dough, bakes it and sets the bread out on
// the counter; between batches they tend the shop.
/proc/trailer_job_baker(mob/living/human/H, token)
	var/obj/structure/oven/oven = trailer_oven()
	for (var/obj/item/weapon/reagent_containers/food/snacks/flatbread/B in oven.loc)
		trailer_walk(H, 35, 12, TRAILER_STEP, token)
		trailer_pickup(H, B)
		var/obj/structure/table/counter
		for (var/tx in list(34, 35, 33, 36))
			var/obj/structure/table/T = locate(/obj/structure/table) in locate(tx, 9, 1)
			if (T && !(locate(/obj/item/weapon/reagent_containers/food/snacks/flatbread) in T.loc))
				counter = T
				break
		if (!counter)
			counter = locate(/obj/structure/table) in locate(35, 9, 1)
		trailer_walk(H, counter.x, 10, TRAILER_STEP, token)
		H.dir = SOUTH
		trailer_hold(H, B)
		counter.attackby(B, H, "icon-x=16;icon-y=16")
		intro_check(B.loc == counter.loc, "bread placed on the counter")
		trailer_counter_bread += B
		trailer_bread_served++
		sleep(8)
		return TRUE
	var/obj/item/weapon/reagent_containers/food/condiment/flour/F
	if (!oven.on && oven.fuel > 0 && trailer_bucket.reagents.has_reagent("water", 5))
		var/list/flour = list()
		for (var/obj/item/weapon/reagent_containers/food/condiment/flour/S in range(6, locate(34, 11, 1)))
			if (isturf(S.loc) && S.reagents.has_reagent("flour", 5))
				flour += S
		F = trailer_nearest(H, flour)
	if (!F)
		// Tend the shop between batches.
		trailer_baker_idle_spot = !trailer_baker_idle_spot
		trailer_walk(H, trailer_baker_idle_spot ? 36 : 34, 11, 6, token)
		H.dir = SOUTH
		sleep(15)
		return TRUE
	var/obj/structure/mill/large/M = trailer_mill()
	if (F.loc == M.loc)
		trailer_walk(H, 33, 11, TRAILER_STEP, token)
	else
		trailer_walk(H, F.x, F.y, TRAILER_STEP, token)
	trailer_face(H, F)
	trailer_pickup(H, F)
	trailer_walk(H, 35, 10, TRAILER_STEP, token)
	if (!trailer_bucket.Adjacent(H))
		trailer_walk(H, trailer_bucket.x, trailer_bucket.y, TRAILER_STEP, token)
	H.dir = EAST
	trailer_pickup(H, trailer_bucket)
	trailer_hold(H, F)
	var/list/old_dough = list()
	for (var/obj/item/weapon/reagent_containers/food/snacks/dough/D in H.loc)
		old_dough += D
	F.attack_self(H)
	var/obj/item/weapon/reagent_containers/food/snacks/dough/D
	for (var/obj/item/weapon/reagent_containers/food/snacks/dough/ND in H.loc)
		if (!(ND in old_dough))
			D = ND
	intro_check(D, "dough recipe produced dough")
	sleep(5)
	trailer_hold(H, trailer_bucket)
	H.drop_item()
	// An emptied sack may be used up by the recipe; set down whatever is left.
	for (var/obj/item/I in list(H.l_hand, H.r_hand))
		trailer_hold(H, I)
		H.drop_item()
	trailer_pickup(H, D)
	trailer_walk(H, 35, 12, TRAILER_STEP, token)
	H.dir = NORTH
	oven.attackby(D, H)
	intro_check(D.loc == oven, "oven loaded with dough")
	oven.attack_hand(H)
	intro_check(oven.on, "oven lit through the normal handler")
	trailer_oven_lit++
	sleep(10)
	return TRUE

// The engineer walks the platform until the train is due out.
/proc/trailer_job_engineer(mob/living/human/H, token)
	trailer_engineer_spot = !trailer_engineer_spot
	trailer_walk(H, trailer_engineer_spot ? 77 : 74, 4, 6, token)
	H.dir = SOUTH
	sleep(20)
	return TRUE

// ---------------------------------------------------------------- ride glides
// Vehicles step everything aboard with forceMove/Move on their own timers and
// leave each atom's glide at whatever it last was, so the rider, horses and
// carriage (or train cars) slide at different rates and snap together every
// tile. Give the whole group one glide matched to the vehicle's step period.
/proc/trailer_glide_group(list/atoms, period)
	// Steps land on server ticks: a spawn() of a fractional delay fires on
	// the next whole tick, so round the period up.
	period = max(1, -round(-period / world.tick_lag)) * world.tick_lag
	var/glide = 32 * world.tick_lag / period
	for (var/atom/movable/A in atoms)
		A.glide_size = glide

/proc/trailer_carriage_glide()
	var/obj/structure/vehicle/carriage/C = trailer_carriage
	while (!intro_stopping && C.driver)
		var/list/group = list(C) + C.ontop + C.ontop_o
		trailer_glide_group(group, C.vehicle_m_delay + 1)
		sleep(world.tick_lag)

/proc/trailer_train_glide()
	var/obj/structure/trains/locomotive/L = trailer_locomotive
	while (!intro_stopping && L.automovement)
		var/list/group = list()
		for (var/obj/structure/trains/car in list(L) + trailer_extra_cars)
			group |= car
			for (var/atom/movable/A in car.loc)
				group |= A
		trailer_glide_group(group, L.train_speed)
		sleep(world.tick_lag)

// ---------------------------------------------------------------- village life
// Background villagers each loop through a little routine of errands built
// from the same native actions as the production chain: walking, picking
// things up, setting them on tables, sitting, working at a tool, chatting.
var/list/trailer_errands = list()
var/list/trailer_errand_step = list()
var/list/trailer_extra_cars = list()
var/mob/living/human/intro_actor/trailer_passenger
var/obj/structure/trains/transport/cabin/trailer_cabin2

/proc/trailer_errand_actor(tx, ty, actor_name, uniform_type, list/routine, list/tools = null)
	var/mob/living/human/intro_actor/H = trailer_actor(tx, ty, actor_name, uniform_type)
	for (var/tool_type in tools)
		var/obj/item/I = new tool_type(H.loc)
		trailer_pickup(H, I)
	trailer_errands[H] = routine
	trailer_errand_step[H] = 1
	return H

/proc/trailer_bubble(mob/living/human/H, ticks)
	var/image/I = image('icons/mob/talk.dmi', H, "typing", MOB_LAYER + 1)
	H.overlays += I
	sleep(ticks)
	H.overlays -= I

/proc/trailer_table_at(tx, ty)
	return locate(/obj/structure/table) in locate(tx, ty, 1)

/proc/trailer_job_errand(mob/living/human/H, token)
	var/list/routine = trailer_errands[H]
	var/i = trailer_errand_step[H]
	if (i > routine.len)
		i = 1
	trailer_errand_step[H] = i + 1
	var/list/step = routine[i]
	switch (step[1])
		if ("walk")
			var/delay = step.len >= 4 ? step[4] : TRAILER_STEP
			if (H.buckled)
				H.buckled.user_unbuckle_mob(H)
			trailer_walk(H, step[2], step[3], delay, token)
		if ("face")
			H.dir = step[2]
		if ("wait")
			sleep(step[2])
		if ("chat")
			if (step.len >= 3)
				sleep(step[3])
			trailer_bubble(H, step[2])
		if ("work")
			// Swing whatever is in hand at a nearby object, step[4] times.
			var/turf/T = locate(step[2], step[3], 1)
			trailer_face(H, T)
			var/atom/target = T
			for (var/obj/O in T)
				target = O
				break
			for (var/k in 1 to step[4])
				H.do_attack_animation(target)
				sleep(7)
		if ("take")
			// Pick up an item of a type lying on or beside a tile.
			var/turf/T = locate(step[2], step[3], 1)
			var/obj/item/I
			for (var/obj/item/C in T)
				if (istype(C, step[4]) && !C.anchored)
					I = C
					break
			if (I && I.Adjacent(H) && (!H.l_hand || !H.r_hand))
				trailer_face(H, T)
				trailer_pickup(H, I)
		if ("put")
			// Set the carried item of a type on the table at a tile.
			var/obj/item/I = trailer_held(H, step[4])
			var/obj/structure/table/T = trailer_table_at(step[2], step[3])
			if (I && T && T.Adjacent(H))
				trailer_face(H, T)
				trailer_hold(H, I)
				T.attackby(I, H, "icon-x=[rand(10, 22)];icon-y=[rand(12, 20)]")
		if ("sit")
			var/obj/structure/bed/chair/C = locate(/obj/structure/bed/chair) in locate(step[2], step[3], 1)
			if (C && H.loc == C.loc && !H.buckled)
				C.user_buckle_mob(H, H)
				if (step.len >= 4)
					H.dir = step[4]
	sleep(1)
	return TRUE

/proc/trailer_stage_life()
	// Decorative crops show as ready for harvest, like the wheat.
	for (var/obj/structure/farming/plant/P in world)
		if (istype(P, /obj/structure/farming/plant/wheat))
			continue
		P.stage = P.readyStageMin
		var/sprite_name = P.sprite_plant ? P.sprite_plant : P.plant
		P.icon_state = "[sprite_name]-harvest"
	// Livestock in the pasture.
	for (var/list/spec in list(
		list(/mob/living/simple_animal/cattle/cow, 4, 17), list(/mob/living/simple_animal/cattle/cow, 8, 16),
		list(/mob/living/simple_animal/goat/female, 10, 18), list(/mob/living/simple_animal/chicken, 5, 16),
		list(/mob/living/simple_animal/chicken, 6, 18), list(/mob/living/simple_animal/chicken, 9, 17),
		list(/mob/living/simple_animal/horse, 41, 2)))
		var/animal_type = spec[1]
		var/mob/living/simple_animal/A = new animal_type(locate(spec[2], spec[3], 1))
		trailer_living += A
	// Produce for the market and a drink for the tavern.
	for (var/k in 1 to 12)
		new /obj/item/weapon/reagent_containers/food/snacks/grown/apple(locate(46, 12, 1))
		new /obj/item/weapon/reagent_containers/food/snacks/grown/pumpkin(locate(42, 12, 1))
	new /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood(locate(43, 18, 1))
	new /obj/item/weapon/reagent_containers/food/drinks/bottle/wine(locate(42, 18, 1))
	var/apple = /obj/item/weapon/reagent_containers/food/snacks/grown/apple
	var/pumpkin = /obj/item/weapon/reagent_containers/food/snacks/grown/pumpkin
	var/glass = /obj/item/weapon/reagent_containers/food/drinks/drinkingglass/wood
	// Market: the stallholder restocks the stalls, two neighbours come shopping.
	trailer_errand_actor(44, 12, "Stallholder", /obj/item/clothing/under/civf1, list(
		list("walk", 45, 12), list("take", 46, 12, apple), list("walk", 44, 12), list("put", 44, 11, apple),
		list("chat", 15), list("walk", 43, 12), list("take", 42, 12, pumpkin), list("put", 42, 11, pumpkin),
		list("walk", 45, 12), list("put", 46, 11, apple), list("wait", 20)))
	trailer_errand_actor(53, 9, "Neighbour", /obj/item/clothing/under/civ2, list(
		list("walk", 46, 10), list("face", NORTH), list("chat", 15), list("take", 46, 11, apple),
		list("walk", 49, 9), list("walk", 53, 9), list("face", NORTH), list("wait", 30),
		list("walk", 44, 10), list("face", NORTH), list("chat", 12), list("take", 44, 11, apple),
		list("walk", 53, 9), list("wait", 25)))
	trailer_errand_actor(42, 9, "Neighbour", /obj/item/clothing/under/civf2, list(
		list("wait", 20), list("walk", 42, 10), list("face", NORTH), list("chat", 12, 5),
		list("take", 42, 11, pumpkin), list("walk", 48, 10), list("walk", 48, 8), list("face", EAST),
		list("wait", 30), list("walk", 48, 10), list("walk", 42, 9), list("wait", 15)))
	// Two friends meet between the north cottages for a chat (rows 6 and 7
	// are the carriage's lane and its collision rows, so they stay on y 8).
	trailer_errand_actor(51, 8, "Villager", /obj/item/clothing/under/civ3, list(
		list("walk", 54, 8), list("face", EAST), list("chat", 20), list("wait", 20), list("chat", 15),
		list("wait", 10), list("walk", 51, 8), list("face", NORTH), list("wait", 40)))
	trailer_errand_actor(61, 9, "Villager", /obj/item/clothing/under/civf3, list(
		list("walk", 55, 8), list("face", WEST), list("wait", 20), list("chat", 20), list("wait", 15),
		list("chat", 10), list("walk", 61, 9), list("face", NORTH), list("wait", 40)))
	// Children playing tag around the meadow.
	var/list/loop = list(list("walk", 2, 7, 2), list("walk", 12, 7, 2), list("walk", 12, 14, 2), list("walk", 2, 14, 2))
	trailer_errand_actor(2, 14, "Child", /obj/item/clothing/under/civ5, loop)
	var/mob/living/human/kid = trailer_errand_actor(12, 7, "Child", /obj/item/clothing/under/civf1, loop)
	trailer_errand_step[kid] = 3
	// The smith at the anvil, the woodcutter splitting logs.
	trailer_errand_actor(32, 3, "Smith", /obj/item/clothing/under/medieval/leather, list(
		list("walk", 32, 3), list("work", 31, 3, 8), list("walk", 32, 4), list("walk", 34, 4), list("walk", 34, 3),
		list("work", 35, 2, 3), list("walk", 34, 4), list("walk", 32, 4), list("walk", 32, 3), list("work", 31, 3, 6),
		list("face", NORTH), list("wait", 15)),
		list(/obj/item/weapon/hammer))
	trailer_errand_actor(53, 3, "Woodcutter", /obj/item/clothing/under/farmer_outfit, list(
		list("walk", 53, 3), list("work", 53, 2, 6), list("walk", 54, 3), list("work", 54, 2, 5),
		list("walk", 52, 3), list("work", 52, 2, 5), list("wait", 10)),
		list(/obj/item/weapon/material/hatchet))
	// The gardener waters the vegetable patch from the water barrels.
	trailer_errand_actor(24, 3, "Gardener", /obj/item/clothing/under/civ6, list(
		list("walk", 24, 3), list("work", 25, 3, 2), list("walk", 24, 5), list("walk", 16, 5), list("walk", 13, 4),
		list("work", 13, 3, 3), list("walk", 11, 4), list("work", 11, 3, 3), list("walk", 16, 5), list("walk", 24, 5),
		list("wait", 10)),
		list(/obj/item/weapon/reagent_containers/glass/bucket))
	// Tavern: the keeper serves a drink, two regulars chat at their tables.
	trailer_errand_actor(43, 17, "Tavern keeper", /obj/item/clothing/under/civ4, list(
		list("walk", 43, 17), list("take", 43, 18, glass), list("walk", 46, 16), list("put", 47, 16, glass),
		list("chat", 15), list("walk", 44, 16), list("wait", 30), list("walk", 46, 16), list("take", 47, 16, glass),
		list("walk", 43, 17), list("put", 43, 18, glass), list("work", 42, 18, 3), list("wait", 20)))
	trailer_errand_actor(42, 17, "Regular", /obj/item/clothing/under/civ2, list(
		list("sit", 42, 17, NORTH), list("chat", 20, 10), list("wait", 30)))
	trailer_errand_actor(48, 16, "Regular", /obj/item/clothing/under/civ6, list(
		list("sit", 48, 16, WEST), list("wait", 25), list("chat", 20), list("wait", 15)))
	// Chapel: the priest tends the altar, two people at prayer.
	trailer_errand_actor(56, 17, "Priest", /obj/item/clothing/under/medieval/blue, list(
		list("walk", 56, 17), list("face", NORTH), list("work", 56, 18, 2), list("wait", 30),
		list("walk", 56, 16), list("face", SOUTH), list("chat", 25), list("wait", 20)))
	trailer_errand_actor(54, 16, "Worshipper", /obj/item/clothing/under/civf2, list(list("sit", 54, 16, NORTH), list("wait", 60)))
	trailer_errand_actor(58, 17, "Worshipper", /obj/item/clothing/under/civ1, list(list("sit", 58, 17, NORTH), list("wait", 60)))
	// Station: travellers waiting on the platform benches.
	trailer_errand_actor(80, 5, "Traveller", /obj/item/clothing/under/civf3, list(
		list("sit", 80, 5, SOUTH), list("wait", 40), list("chat", 15)))
	trailer_passenger = trailer_errand_actor(68, 5, "Passenger", /obj/item/clothing/under/civ3, list(
		list("sit", 68, 5, SOUTH), list("wait", 30), list("chat", 15)))

// A longer train: tender, two passenger cabins, wagons and a loaded flatbed.
/proc/trailer_stage_train()
	var/obj/structure/trains/prev = trailer_locomotive
	var/list/cars = list(
		/obj/structure/trains/storage/tender, /obj/structure/trains/transport/cabin,
		/obj/structure/trains/transport/cabin, /obj/structure/trains/storage/closed,
		/obj/structure/trains/transport/flatbed, /obj/structure/trains/storage/closed)
	var/tx = trailer_locomotive.x - 1
	for (var/car_type in cars)
		var/obj/structure/trains/car = new car_type(locate(tx, 3, 1))
		car.dir = EAST
		prev.connected = car
		prev = car
		trailer_extra_cars += car
		tx--
	trailer_cabin = trailer_extra_cars[2]
	trailer_cabin2 = trailer_extra_cars[3]
	var/obj/structure/trains/transport/flatbed/F = trailer_extra_cars[5]
	for (var/crate_type in list(/obj/structure/closet/crate/empty))
		var/obj/structure/closet/crate/C = new crate_type(F.loc)
		C.anchored = TRUE
		F.transporting += C

/proc/trailer_start_errands()
	for (var/mob/living/human/H in trailer_errands)
		trailer_start_job(H, /proc/trailer_job_errand)

// ---------------------------------------------------------------- the take
/proc/trailer_run()
	trailer_start_job(trailer_baker, /proc/trailer_job_baker)
	trailer_start_job(trailer_engineer, /proc/trailer_job_engineer)
	trailer_start_errands()
	trailer_scene_seeds()
	trailer_scene_harvest()
	trailer_scene_bakery()
	trailer_scene_carriage()
	trailer_scene_train()

// 1. A villager gathers wild seeds and plants them in the farm.
/proc/trailer_scene_seeds()
	trailer_beat("seeds")
	// Open on the gatherer at the bush, drifting gently toward the field.
	trailer_follow(trailer_gatherer, 1.5, 0, 3, 1)
	sleep(10)
	trailer_start_job(trailer_gatherer, /proc/trailer_job_gatherer)
	trailer_wait_for("trailer_gatherer_planting", 1, 400, "gatherer heads to the field")
	// The farmer starts cutting now, so the harvest is under way when the
	// camera gets there.
	trailer_start_job(trailer_farmer, /proc/trailer_job_farmer)
	sleep(15)
	trailer_beat("plant")
	trailer_wait_for("trailer_seeds_planted", 1, 400, "seeds planted through the ploughed-field handler")
	trailer_log("gathered [trailer_seeds_gathered], planted [trailer_seeds_planted]")
	// Keep drifting toward the field rather than turning back with the
	// gatherer, so the move into the harvest is one continuous pan.
	trailer_camera_pan(trailer_gatherer.x + 3, 10, 1, FALSE)
	sleep(12)

// 2. The farmer harvests ready wheat and carries it to the mill.
/proc/trailer_scene_harvest()
	trailer_beat("harvest")
	trailer_follow(trailer_farmer, 0.5, 0.5, 6, 1)
	// Show a couple of plants coming down before the walk to the mill.
	var/until = trailer_wheat_harvested + 2
	var/deadline = world.time + 100
	while (trailer_wheat_harvested < until && trailer_farmer_batch < TRAILER_FARMER_BATCH && world.time < deadline)
		sleep(1)
	trailer_wait_for("trailer_farmer_delivering", 1, 600, "farmer carries wheat to the mill")
	trailer_log("harvested [trailer_wheat_harvested] wheat")
	trailer_beat("deliver")
	trailer_follow(trailer_farmer, 1, 0.5, 6, 1.2)
	trailer_wait_for("trailer_wheat_milled", 1, 400, "mill accepted the harvested wheat")

// 3. The mill grinds flour, the baker bakes bread and serves the customer.
/proc/trailer_scene_bakery()
	trailer_beat("bakery")
	// Settle on the bakery, then creep across it while the batch is made.
	trailer_camera_pan(34, 10.5, 3, FALSE)
	spawn(30)
		trailer_camera_pan(35.5, 10.8, 0.12, FALSE)
	trailer_wait_for("trailer_oven_lit", 1, 400, "baker lit the oven")
	trailer_beat("bake")
	// The customer leaves the market and comes to the counter for the bread.
	spawn(0)
		trailer_take(trailer_customer)
		sleep(10)
		trailer_walk(trailer_customer, 37, 8)
		trailer_walk(trailer_customer, 34, 8)
		trailer_customer.dir = NORTH
		trailer_customer_waiting = TRUE
	trailer_wait_for("trailer_bread_served", 1, 300, "bread on the counter")
	trailer_wait_for("trailer_customer_waiting", 1, 150, "customer reached the counter")
	trailer_beat("serve")
	var/obj/item/weapon/reagent_containers/food/snacks/flatbread/bread = trailer_counter_bread[1]
	if (trailer_customer.x != bread.x || trailer_customer.y != 8)
		trailer_walk(trailer_customer, bread.x, 8)
	trailer_customer.dir = NORTH
	sleep(6)
	trailer_pickup(trailer_customer, bread)
	sleep(8)

// 4. The customer rides the horse carriage to the station.
/proc/trailer_scene_carriage()
	trailer_beat("carriage")
	// Walk out to the carriage; the camera drifts after the customer and
	// arrives on the team while they climb up.
	trailer_follow(trailer_customer, 2.5, 0, 3, 1.5)
	trailer_walk(trailer_customer, 41, 6)
	trailer_face(trailer_customer, trailer_carriage)
	var/hand_bread = trailer_customer.get_active_hand()
	if (hand_bread)
		trailer_customer.swap_hand()
	trailer_follow(trailer_carriage, 1.5, 1, 3, 1)
	trailer_carriage.MouseDrop_T(trailer_customer, trailer_customer)
	intro_check(trailer_carriage.driver == trailer_customer, "customer took the reins")
	// Ride with the carriage's own glide: the walking pace trailer_walk set
	// would leave the rider trailing the horses and snapping forward each tile.
	spawn(0)
		trailer_carriage_glide()
	var/obj/item/vehicleparts/wheel/rope/reins = trailer_customer.get_active_hand()
	intro_check(istype(reins), "reins in hand")
	trailer_customer.dir = EAST
	sleep(8)
	reins.attack_self(trailer_customer)
	// Lead the team so it stays framed at full gallop.
	trailer_follow(trailer_carriage, 1.5, 1, 12, 1.1)
	sleep(10)
	reins.attack_self(trailer_customer)
	sleep(10)
	reins.attack_self(trailer_customer)
	var/deadline = world.time + 400
	while (trailer_carriage.x < 60 && world.time < deadline)
		sleep(1)
	trailer_log("carriage at [trailer_carriage.x],[trailer_carriage.y] speed [trailer_carriage.axis.currentspeed]")
	while (trailer_carriage.axis.currentspeed > 0 && world.time < deadline)
		reins.secondary_attack_self(trailer_customer)
		sleep(4)
	intro_check(trailer_carriage.axis.currentspeed == 0, "carriage stopped at the station")
	// While the traveller climbs down, ease on to reveal the platform.
	trailer_camera_pan(trailer_carriage.x + 5, 5.5, 2, FALSE)
	trailer_carriage.attack_hand(trailer_customer)
	intro_check(trailer_carriage.driver != trailer_customer, "customer left the carriage")
	trailer_log("customer off at [trailer_customer.x],[trailer_customer.y]")

/proc/trailer_board_passenger()
	trailer_take(trailer_passenger)
	if (trailer_passenger.buckled)
		trailer_passenger.buckled.user_unbuckle_mob(trailer_passenger)
	trailer_walk(trailer_passenger, trailer_cabin2.x, trailer_cabin2.y + 1)
	trailer_passenger.dir = SOUTH
	trailer_cabin2.MouseDrop_T(trailer_passenger, trailer_passenger)
	if (trailer_passenger.loc == trailer_cabin2.loc)
		trailer_cabin2.MouseDrop_T(trailer_passenger, trailer_passenger)
		trailer_passenger.dir = EAST
	else
		trailer_log("passenger could not board the second cabin")
	trailer_passenger_boarded = TRUE

/proc/trailer_engineer_to_footplate()
	trailer_take(trailer_engineer)
	trailer_walk(trailer_engineer, 74, 4, TRAILER_STEP)
	trailer_engineer.dir = SOUTH

// 5. The customer boards the train and it steams off east.
/proc/trailer_scene_train()
	trailer_beat("station")
	// The other traveller and the engineer get moving at the same time.
	spawn(0)
		trailer_board_passenger()
	spawn(0)
		trailer_engineer_to_footplate()
	// Ease along the platform ahead of the traveller, framed on the rails.
	trailer_follow(trailer_customer, 2.5, 0.5, 4, 1.3)
	var/turf/board = locate(trailer_cabin.x, trailer_cabin.y + 1, 1)
	trailer_walk(trailer_customer, board.x, board.y)
	trailer_customer.dir = SOUTH
	trailer_beat("board")
	// Settle on the train while the traveller climbs in.
	trailer_camera_pan(trailer_locomotive.x + 1.5, 5.5, 1.5, FALSE)
	trailer_cabin.MouseDrop_T(trailer_customer, trailer_customer)
	intro_check(trailer_customer.loc == trailer_cabin.loc, "customer climbed into the cabin")
	trailer_cabin.MouseDrop_T(trailer_customer, trailer_customer)
	trailer_customer.dir = EAST
	// Wait for the other traveller, the engineer at the footplate and the
	// camera to settle.
	var/deadline = world.time + 100
	while ((!trailer_passenger_boarded || trailer_engineer.x != 74 || trailer_engineer.y != 4 || !trailer_camera_settled(8)) && world.time < deadline)
		sleep(1)
	sleep(5)
	trailer_locomotive.attack_hand(trailer_engineer)
	intro_check(trailer_locomotive.on, "engineer started the locomotive")
	trailer_beat("depart")
	spawn(0)
		trailer_train_glide()
	// Ride along with the train as it pulls out, then let it go: the camera
	// eases back toward the station while the train steams out of shot.
	trailer_follow(trailer_locomotive, 1, 1.5, 3, 1)
	sleep(40)
	trailer_camera_pan(75, 5.5, 1.2, FALSE)
	var/obj/structure/trains/last_car = trailer_extra_cars[trailer_extra_cars.len]
	deadline = world.time + 250
	while (trailer_locomotive.automovement && (last_car.x - 0.5) * 32 <= trailer_cam_right_edge() + 32 && world.time < deadline)
		sleep(1)
	trailer_log("train at [trailer_locomotive.x], customer at [trailer_customer.x]; milled [trailer_wheat_milled], baked [trailer_bread_served], planted [trailer_seeds_planted]")
	trailer_beat("gone")
	sleep(15)
