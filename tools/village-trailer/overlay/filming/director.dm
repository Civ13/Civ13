// Village trailer director: the production chain and its camera.
// Every gameplay step goes through the game's own handlers (attackby,
// attack_hand, attack_self, MouseDrop_T, Life). Pre-roll staging only gives
// actors their starting clothes/tools and places the vehicles and the ready
// wheat; the camera never shows the staging.

#define TRAILER_MAP_W 100
#define TRAILER_MAP_H 20
#define TRAILER_TIMEOUT 3600
#define TRAILER_OPENING_X 8
#define TRAILER_OPENING_Y 11
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
// A smoothed camera rig. The client looks through an invisible anchor; each
// tick a critically damped spring moves the rig's pixel position toward its
// target (a fixed point or a followed atom); the anchor steps one tile at a
// time with a glide_size matched to the spring's speed, so the client's own
// glide interpolation eases pans in and out with no hard steps.
/obj/trailer_camera
	name = ""
	icon = null
	invisibility = 101
	anchored = TRUE
	density = FALSE
	mouse_opacity = 0

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
var/trailer_cam_omega = 3.2       // spring stiffness (rad/s): ~1.2 s to settle
var/trailer_cam_max_speed = 320   // pixels per second
var/trailer_cam_running = FALSE

/proc/trailer_camera_attach(client/C)
	if (!trailer_cam)
		trailer_cam = new(locate(TRAILER_OPENING_X, TRAILER_OPENING_Y, 1))
	C.perspective = EYE_PERSPECTIVE
	C.eye = trailer_cam
	if (!trailer_cam_running)
		trailer_cam_running = TRUE
		spawn(0)
			trailer_camera_loop()

/proc/trailer_clamp(v, lo, hi)
	return v < lo ? lo : (v > hi ? hi : v)

/proc/trailer_camera_target()
	var/tx = trailer_cam_tx
	var/ty = trailer_cam_ty
	if (trailer_cam_follow && !QDELETED(trailer_cam_follow))
		var/turf/T = get_turf(trailer_cam_follow)
		if (T)
			tx = (T.x + trailer_cam_fox) * 32
			ty = (T.y + trailer_cam_foy) * 32
			trailer_cam_tx = tx
			trailer_cam_ty = ty
	// Keep the 15x9 view inside the authored map.
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

var/trailer_cam_next_step = 0

// Move the eye anchor one tile at a time with a glide matched to the rig's
// speed, so DreamSeeker interpolates the motion smoothly at its own frame rate.
/proc/trailer_camera_apply(snap = FALSE)
	var/ax = round(trailer_cam_px / 32 + 0.5)
	var/ay = round(trailer_cam_py / 32 + 0.5)
	var/turf/T = locate(ax, ay, 1)
	if (!T || !trailer_cam)
		return
	if (snap)
		trailer_cam.loc = null
		trailer_cam.loc = T
		trailer_cam_next_step = world.time
	else if (trailer_cam.loc != T && world.time >= trailer_cam_next_step)
		var/speed = sqrt(trailer_cam_vx * trailer_cam_vx + trailer_cam_vy * trailer_cam_vy)
		var/glide = trailer_clamp(speed * world.tick_lag / 10, 1, 32)
		var/turf/next = get_step(trailer_cam, get_dir(trailer_cam, T))
		trailer_cam.glide_size = glide
		trailer_cam.loc = next
		trailer_cam_next_step = world.time + (32 / glide) * world.tick_lag - 0.01
	if (intro_observer_client && intro_observer_client.eye != trailer_cam)
		intro_observer_client.eye = trailer_cam

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
		trailer_cam = new(locate(tx, ty, 1))
	trailer_camera_apply(TRUE)
	if (!trailer_cam_running)
		trailer_cam_running = TRUE
		spawn(0)
			trailer_camera_loop()

// Ease toward a fixed point; optionally wait until the camera has settled.
/proc/trailer_camera_pan(tx, ty, ticks_per_tile = 4, wait = TRUE)
	trailer_cam_follow = null
	trailer_cam_tx = tx * 32
	trailer_cam_ty = ty * 32
	trailer_cam_max_speed = 32 / max(1, ticks_per_tile * world.tick_lag / 10)
	if (!wait)
		return
	var/deadline = world.time + 150
	while (world.time < deadline)
		var/list/t = trailer_camera_target()
		if (abs(t[1] - trailer_cam_px) < 6 && abs(t[2] - trailer_cam_py) < 6)
			break
		sleep(world.tick_lag)

// Ease onto a moving atom and keep tracking it.
/proc/trailer_follow(atom/A, ox = 0, oy = 0, max_tiles_per_second = 10)
	trailer_cam_follow = A
	trailer_cam_fox = ox
	trailer_cam_foy = oy
	trailer_cam_max_speed = max_tiles_per_second * 32

// ---------------------------------------------------------------- timeline
/proc/trailer_beat(label)
	var/elapsed = world.time - trailer_timeline_origin
	trailer_timeline += list(list("t" = elapsed / 10, "beat" = label))
	trailer_log("beat [label] at [elapsed / 10]s")
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
	// Seed gatherer with a knife in the meadow.
	trailer_gatherer = trailer_actor(7, 10, "Gatherer", /obj/item/clothing/under/civ1, EAST)
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
	// Customer waits at the counter; carriage, horse and train wait outside.
	trailer_customer = trailer_actor(34, 7, "Traveller", /obj/item/clothing/under/civ1, NORTH)
	trailer_carriage = new(locate(43, 6, 1))
	trailer_carriage.dir = EAST
	trailer_horse = new(locate(42, 5, 1))
	trailer_horse2 = new(locate(42, 7, 1))
	trailer_living += trailer_horse
	trailer_living += trailer_horse2
	trailer_locomotive = new(locate(73, 3, 1))
	trailer_locomotive.dir = EAST
	trailer_cabin = new(locate(72, 3, 1))
	trailer_cabin.dir = EAST
	trailer_locomotive.connected = trailer_cabin
	trailer_locomotive.fuel = trailer_locomotive.max_fuel
	trailer_engineer = trailer_actor(74, 4, "Engineer", /obj/item/clothing/under/civ4, SOUTH)
	trailer_log("prepare done")

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

#define TRAILER_FARMER_BATCH 10

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
	for (var/d in list(SOUTH, EAST, WEST, NORTH))
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
	trailer_walk(H, trailer_engineer_spot ? 79 : 74, 4, 6, token)
	H.dir = SOUTH
	sleep(20)
	return TRUE

// ---------------------------------------------------------------- the take
/proc/trailer_run()
	trailer_start_job(trailer_gatherer, /proc/trailer_job_gatherer)
	trailer_start_job(trailer_farmer, /proc/trailer_job_farmer)
	trailer_start_job(trailer_baker, /proc/trailer_job_baker)
	trailer_start_job(trailer_engineer, /proc/trailer_job_engineer)
	trailer_scene_seeds()
	trailer_scene_harvest()
	trailer_scene_bakery()
	trailer_scene_carriage()
	trailer_scene_train()

// 1. A villager gathers wild seeds and plants them in the farm.
/proc/trailer_scene_seeds()
	trailer_beat("seeds")
	sleep(15)
	trailer_follow(trailer_gatherer, 1, 1, 6)
	trailer_wait_for("trailer_gatherer_planting", 1, 400, "gatherer heads to the field")
	sleep(20)
	trailer_beat("plant")
	trailer_wait_for("trailer_seeds_planted", 2, 400, "seeds planted through the ploughed-field handler")
	trailer_log("gathered [trailer_seeds_gathered], planted [trailer_seeds_planted]")
	sleep(12)

// 2. The farmer harvests ready wheat and carries it to the mill.
/proc/trailer_scene_harvest()
	trailer_beat("harvest")
	trailer_follow(trailer_farmer, 0, 1, 8)
	// Show a couple of plants coming down before the walk to the mill.
	var/until = trailer_wheat_harvested + 2
	var/deadline = world.time + 100
	while (trailer_wheat_harvested < until && trailer_farmer_batch && world.time < deadline)
		sleep(1)
	trailer_wait_for("trailer_farmer_delivering", 1, 600, "farmer carries wheat to the mill")
	trailer_log("harvested [trailer_wheat_harvested] wheat")
	trailer_beat("deliver")
	trailer_wait_for("trailer_wheat_milled", 1, 400, "mill accepted the harvested wheat")

// 3. The mill grinds flour, the baker bakes bread and serves the customer.
/proc/trailer_scene_bakery()
	trailer_beat("bakery")
	trailer_camera_pan(34, 10, 3, FALSE)
	trailer_wait_for("trailer_oven_lit", 1, 400, "baker lit the oven")
	trailer_beat("bake")
	trailer_wait_for("trailer_bread_served", 1, 300, "bread on the counter")
	trailer_beat("serve")
	var/obj/item/weapon/reagent_containers/food/snacks/flatbread/bread = trailer_counter_bread[1]
	sleep(8)
	trailer_walk(trailer_customer, bread.x, 8)
	trailer_customer.dir = NORTH
	trailer_pickup(trailer_customer, bread)
	sleep(10)

// 4. The customer rides the horse carriage to the station.
/proc/trailer_scene_carriage()
	trailer_beat("carriage")
	trailer_follow(trailer_customer, 2, 1, 6)
	// Hitch the waiting horse, then take the driver's seat with a free hand.
	trailer_walk(trailer_customer, 41, 6)
	trailer_face(trailer_customer, trailer_horse)
	var/hand_bread = trailer_customer.get_active_hand()
	if (hand_bread)
		trailer_customer.swap_hand()
	trailer_carriage.MouseDrop_T(trailer_horse, trailer_customer)
	sleep(5)
	trailer_face(trailer_customer, trailer_horse2)
	trailer_carriage.MouseDrop_T(trailer_horse2, trailer_customer)
	trailer_log("hitch: propulsion=[trailer_carriage.buckled_animal_propulsion]")
	intro_check(trailer_carriage.buckled_animal_propulsion >= 4, "two horses hitched")
	trailer_carriage.MouseDrop_T(trailer_customer, trailer_customer)
	intro_check(trailer_carriage.driver == trailer_customer, "customer took the reins")
	var/obj/item/vehicleparts/wheel/rope/reins = trailer_customer.get_active_hand()
	intro_check(istype(reins), "reins in hand")
	trailer_customer.dir = EAST
	sleep(10)
	reins.attack_self(trailer_customer)
	sleep(15)
	reins.attack_self(trailer_customer)
	sleep(15)
	reins.attack_self(trailer_customer)
	// Lead the carriage so it stays in frame at full gallop.
	trailer_follow(trailer_carriage, 4, 1, 12)
	var/deadline = world.time + 400
	while (trailer_carriage.x < 58 && world.time < deadline)
		sleep(1)
	trailer_log("carriage at [trailer_carriage.x],[trailer_carriage.y] speed [trailer_carriage.axis.currentspeed]")
	while (trailer_carriage.axis.currentspeed > 0 && world.time < deadline)
		reins.secondary_attack_self(trailer_customer)
		sleep(5)
	intro_check(trailer_carriage.axis.currentspeed == 0, "carriage stopped at the station")
	sleep(10)
	trailer_follow(trailer_customer, 2, 1)
	trailer_carriage.attack_hand(trailer_customer)
	intro_check(trailer_carriage.driver != trailer_customer, "customer left the carriage")
	trailer_log("customer off at [trailer_customer.x],[trailer_customer.y]")

// 5. The customer boards the train and it steams off east.
/proc/trailer_scene_train()
	trailer_beat("station")
	// Ease along the platform ahead of the traveller, framed on the rails.
	trailer_follow(trailer_customer, 3, 1, 6)
	var/turf/board = locate(trailer_cabin.x, trailer_cabin.y + 1, 1)
	trailer_walk(trailer_customer, board.x, board.y)
	trailer_customer.dir = SOUTH
	trailer_beat("board")
	trailer_cabin.MouseDrop_T(trailer_customer, trailer_customer)
	intro_check(trailer_customer.loc == trailer_cabin.loc, "customer climbed into the cabin")
	trailer_cabin.MouseDrop_T(trailer_customer, trailer_customer)
	trailer_customer.dir = EAST
	// The engineer finishes their round and heads for the footplate.
	trailer_take(trailer_engineer)
	spawn(0)
		trailer_camera_pan(trailer_locomotive.x, 5, 4)
	trailer_walk(trailer_engineer, 74, 4, TRAILER_STEP)
	trailer_engineer.dir = SOUTH
	sleep(5)
	trailer_locomotive.attack_hand(trailer_engineer)
	intro_check(trailer_locomotive.on, "engineer started the locomotive")
	trailer_beat("depart")
	sleep(10)
	// Ride along with the train for a moment, then let it steam out of shot.
	trailer_follow(trailer_locomotive, 2, 2, 3)
	sleep(25)
	trailer_camera_pan(trailer_locomotive.x + 3, 5, 8, FALSE)
	var/deadline = world.time + 200
	while (trailer_locomotive.automovement && trailer_cabin.x <= 90 && world.time < deadline)
		sleep(1)
	trailer_log("train at [trailer_locomotive.x], customer at [trailer_customer.x]; milled [trailer_wheat_milled], baked [trailer_bread_served], planted [trailer_seeds_planted]")
	trailer_beat("gone")
	sleep(10)
