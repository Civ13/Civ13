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
// target (a fixed point or a followed atom) and the remainder below one tile
// is applied as client.pixel_x/y, so pans ease in and out with no hard steps.
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

/proc/trailer_camera_apply()
	var/ax = round(trailer_cam_px / 32 + 0.5)
	var/ay = round(trailer_cam_py / 32 + 0.5)
	var/turf/T = locate(ax, ay, 1)
	if (T && trailer_cam && trailer_cam.loc != T)
		// Re-anchor without a glide; the pixel offset below absorbs the jump.
		trailer_cam.loc = null
		trailer_cam.loc = T
	if (intro_observer_client)
		intro_observer_client.eye = trailer_cam
		intro_observer_client.pixel_x = round(trailer_cam_px - ax * 32)
		intro_observer_client.pixel_y = round(trailer_cam_py - ay * 32)

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
	trailer_camera_apply()
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
/proc/trailer_walk(mob/living/human/H, tx, ty, delay = TRAILER_STEP)
	var/guard = 200
	while ((H.x != tx || H.y != ty) && guard-- > 0)
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
	// Baker behind the counter; oven fuelled from the bakery's wood store.
	trailer_baker = trailer_actor(34, 11, "Baker", /obj/item/clothing/under/civ4, SOUTH)
	var/obj/structure/oven/oven = trailer_oven()
	var/obj/item/stack/material/wood/W = new(locate(35, 12, 1))
	W.amount = 2
	trailer_walk(trailer_baker, 35, 12, 1)
	trailer_pickup(trailer_baker, W)
	oven.attackby(W, trailer_baker)
	intro_check(oven.fuel >= 1, "oven fuelled through the normal handler")
	if (trailer_baker.get_active_hand())
		trailer_baker.drop_item()
	trailer_bucket = new(locate(36, 10, 1))
	trailer_bucket.reagents.add_reagent("water", 10)
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

// ---------------------------------------------------------------- the take
/proc/trailer_run()
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
	var/list/gathered = list()
	for (var/list/spot in list(list(6, 10, 7, 10), list(8, 11, 8, 10)))
		trailer_walk(trailer_gatherer, spot[3], spot[4])
		var/obj/structure/wild/smallbush/B = locate(/obj/structure/wild/smallbush) in locate(spot[1], spot[2], 1)
		intro_check(B && B.Adjacent(trailer_gatherer), "reachable wild bush")
		trailer_face(trailer_gatherer, B)
		trailer_hold(trailer_gatherer, trailer_knife)
		var/list/before = list()
		for (var/obj/item/stack/farming/seeds/S in trailer_gatherer.loc)
			before += S
		B.attackby(trailer_knife, trailer_gatherer)
		for (var/obj/item/stack/farming/seeds/S in trailer_gatherer.loc)
			if (!(S in before))
				gathered += S
		sleep(8)
	intro_check(gathered.len >= 1, "native seed gathering produced seeds")
	trailer_log("gathered [gathered.len] seed stacks: [english_list(gathered)]")
	// Pocket the knife hand, carry the seeds.
	var/obj/item/stack/farming/seeds/carry = gathered[1]
	trailer_gatherer.swap_hand()
	trailer_pickup(trailer_gatherer, carry)
	trailer_walk(trailer_gatherer, 13, 9)
	trailer_walk(trailer_gatherer, 16, 9)
	trailer_beat("plant")
	var/planted = 0
	for (var/list/plot in list(list(16, 8), list(17, 8)))
		if (QDELETED(carry) || carry.loc != trailer_gatherer)
			break
		var/turf/T = locate(plot[1], plot[2], 1)
		if (get_dist(trailer_gatherer, T) > 1)
			trailer_walk(trailer_gatherer, plot[1], plot[2] + 1)
		trailer_face(trailer_gatherer, T)
		trailer_hold(trailer_gatherer, carry)
		T.attackby(carry, trailer_gatherer)
		if (locate(/obj/structure/farming/plant) in T)
			planted++
		sleep(8)
	intro_check(planted >= 1, "seeds planted through the ploughed-field handler")
	sleep(10)

// 2. The farmer harvests ready wheat and carries it to the bakery.
/proc/trailer_scene_harvest()
	trailer_beat("harvest")
	trailer_follow(trailer_farmer, 0, 1, 8)
	var/list/grain = list()
	for (var/tx in list(18, 19, 20))
		var/obj/structure/farming/plant/wheat/P = locate(/obj/structure/farming/plant/wheat) in locate(tx, 11, 1)
		intro_check(P, "ready wheat at [tx],11")
		if (!P.Adjacent(trailer_farmer))
			trailer_walk(trailer_farmer, tx, 10)
		trailer_farmer.dir = NORTH
		trailer_hold(trailer_farmer, trailer_scythe)
		var/turf/T = get_turf(P)
		P.attackby(trailer_scythe, trailer_farmer)
		intro_check(QDELETED(P), "normal harvest removes the crop")
		for (var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/G in T)
			grain += G
		sleep(12)
	intro_check(grain.len >= 1, "harvest produced wheat")
	trailer_log("harvested [grain.len] wheat")
	// Drop the scythe hand's tool on the field and gather the grain.
	trailer_hold(trailer_farmer, trailer_scythe)
	trailer_farmer.drop_item()
	var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/sheaf = grain[1]
	trailer_walk(trailer_farmer, sheaf.x, sheaf.y - 1)
	trailer_farmer.dir = NORTH
	trailer_pickup(trailer_farmer, sheaf)
	sleep(5)
	trailer_beat("deliver")
	trailer_walk(trailer_farmer, 27, 9)
	trailer_walk(trailer_farmer, 32, 8)
	trailer_walk(trailer_farmer, 32, 11)
	// Hand the wheat straight into the mill hopper.
	var/obj/structure/mill/large/M = trailer_mill()
	trailer_face(trailer_farmer, M)
	trailer_hold(trailer_farmer, sheaf)
	M.attackby(sheaf, trailer_farmer)
	intro_check(M.current_material == sheaf, "mill accepted the harvested wheat")
	trailer_farmer.dir = SOUTH

// 3. The baker mills flour, mixes dough, bakes bread and serves the customer.
/proc/trailer_scene_bakery()
	trailer_beat("bakery")
	trailer_camera_pan(34, 10, 3, FALSE)
	var/obj/structure/mill/large/M = trailer_mill()
	var/deadline = world.time + 150
	var/obj/item/weapon/reagent_containers/food/condiment/flour/F
	while (!F && world.time < deadline)
		F = locate(/obj/item/weapon/reagent_containers/food/condiment/flour) in M.loc
		sleep(1)
	intro_check(F, "mill produced flour")
	trailer_log("flour [F] with [F.reagents.get_reagent_amount("flour")] units")
	// The farmer heads back to the field.
	spawn(0)
		trailer_walk(trailer_farmer, 30, 10)
		trailer_walk(trailer_farmer, 27, 9)
	trailer_walk(trailer_baker, 33, 11)
	trailer_face(trailer_baker, F)
	trailer_pickup(trailer_baker, F)
	trailer_walk(trailer_baker, 35, 10)
	trailer_baker.dir = EAST
	trailer_baker.swap_hand()
	trailer_pickup(trailer_baker, trailer_bucket)
	trailer_hold(trailer_baker, F)
	var/obj/item/weapon/reagent_containers/food/snacks/dough/D
	F.attack_self(trailer_baker)
	D = locate(/obj/item/weapon/reagent_containers/food/snacks/dough) in trailer_baker.loc
	intro_check(D, "dough recipe produced dough")
	sleep(5)
	trailer_hold(trailer_baker, trailer_bucket)
	trailer_baker.drop_item()
	trailer_hold(trailer_baker, F)
	trailer_baker.drop_item()
	trailer_pickup(trailer_baker, D)
	var/obj/structure/oven/oven = trailer_oven()
	trailer_walk(trailer_baker, 35, 12)
	trailer_baker.dir = NORTH
	var/list/old_bread = list()
	for (var/obj/item/weapon/reagent_containers/food/snacks/flatbread/B in world)
		old_bread += B
	oven.attackby(D, trailer_baker)
	intro_check(D.loc == oven, "oven loaded with dough")
	oven.attack_hand(trailer_baker)
	intro_check(oven.on, "oven lit through the normal handler")
	trailer_beat("bake")
	var/obj/item/weapon/reagent_containers/food/snacks/flatbread/bread
	deadline = world.time + 200
	while (!bread && world.time < deadline)
		for (var/obj/item/weapon/reagent_containers/food/snacks/flatbread/B in oven.loc)
			if (!(B in old_bread))
				bread = B
		sleep(1)
	intro_check(bread, "fresh flatbread from the oven")
	trailer_pickup(trailer_baker, bread)
	trailer_walk(trailer_baker, 34, 10)
	trailer_baker.dir = SOUTH
	var/obj/structure/table/counter = locate(/obj/structure/table) in locate(34, 9, 1)
	intro_check(counter, "authored counter")
	trailer_beat("serve")
	counter.attackby(bread, trailer_baker, "icon-x=16;icon-y=16")
	intro_check(bread.loc == counter.loc, "bread placed on the counter")
	sleep(8)
	trailer_customer.dir = NORTH
	trailer_walk(trailer_customer, 34, 8)
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
	sleep(10)
	trailer_camera_pan(trailer_locomotive.x, 5, 4)
	trailer_engineer.dir = SOUTH
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
	trailer_log("train at [trailer_locomotive.x], customer at [trailer_customer.x]")
	trailer_beat("gone")
	sleep(10)
