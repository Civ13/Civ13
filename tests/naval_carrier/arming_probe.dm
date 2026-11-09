// Turf-built vessels, phase 6: arming the aircraft. A light machine gun
// bolts into the light plane's nose and fires along its heading from the
// control column; bombs are steel casings filled with nitroglycerin, hung
// one to a wing and dropped from the air onto the ground under the plane,
// where they crater a carrier's deck; the carrier's magazine holds two bomb
// racks, and a blast that reaches a rack sets off the bombs in it.
/world
	hub = ""
	hub_password = ""
	maxx = 70
	maxy = 60
	maxz = 3
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/naval_probe/New()
	return
/mob/living/human/naval_probe/New()
	return
var/naval_failures = 0
var/naval_runtime_error = FALSE
/proc/naval_check(condition, label)
	if (!condition)
		naval_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	naval_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/naval_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/R = locate(x, y, 1)
			R.ChangeTurf(/turf/wall/rockwall)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
			var/turf/S = locate(x, y, 3)
			S.ChangeTurf(/turf/sky/building)

/proc/naval_count(z, path)
	. = 0
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			if (istype(locate(x, y, z), path))
				.++

/proc/naval_count_objects(z, path)
	. = 0
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/T = locate(x, y, z)
			for (var/atom/A in T)
				if (istype(A, path))
					.++

// Fills every tile of a compartment to the flooded mark.

// The probe mob is built without a species; it still has hands for the gun.
/mob/living/human/naval_probe/IsAdvancedToolUser(silent)
	return TRUE
/mob/living/human/naval_probe/update_icons()
	return

var/naval_hits = 0
/obj/structure/closet/crate/naval_target/bullet_act(obj/item/projectile/Proj)
	naval_hits++
	return ..()

// Explosions run at once instead of through the scheduler.
var/process/explosion/naval_explosions
/process/callproc/naval_stub/queue(object, function_as_path, proc_args = null, time = 10)
	if (!naval_explosions)
		naval_explosions = new
	var/list/L = proc_args
	if (!islist(L) || !L.len || !istype(L[1], /datum/explosiondata))
		return
	naval_explosions.explosion(L[1])

// Steps every projectile in flight the way the projectile process does.
/proc/naval_fly_bullets(steps)
	for (var/i = 1, i <= steps, i++)
		for (var/obj/item/projectile/P in projectile_list)
			if (!QDELETED(P) && P.loc)
				P.process()

/proc/naval_fuel(obj/structure/vehicleparts/axis/aircraft/A)
	var/obj/structure/engine/internal/E = A.engine
	E.fueltank.reagents.add_reagent(E.fuels[1], 100, safety = TRUE)
	E.on = TRUE

/proc/naval_frames_in(obj/structure/vehicleparts/axis/aircraft/A, z, x1, x2, y1, y2)
	var/list/F = A.frames()
	if (F.len != 12)
		return FALSE
	for (var/obj/structure/vehicleparts/frame/FR in F)
		if (FR.z != z || FR.x < x1 || FR.x > x2 || FR.y < y1 || FR.y > y2)
			return FALSE
	return TRUE

/proc/naval_step(obj/structure/vehicleparts/axis/aircraft/A)
	if (!A.do_vehicle_check())
		return FALSE
	if (!A.do_move())
		return FALSE
	A.after_aircraft_move()
	return TRUE

/proc/naval_roll(obj/structure/vehicleparts/axis/aircraft/A, steps)
	A.moving = TRUE
	A.currentspeed = A.speeds
	for (var/i = 1, i <= steps, i++)
		if (A.airborne() || !naval_step(A))
			return i - 1
	return steps

/proc/naval_hand(mob/living/human/H, obj/item/I)
	I.forceMove(get_turf(H))
	H.put_in_hands(I)
	return I.loc == H

/proc/naval_checks()
	naval_fixture()
	config = new /datum/configuration
	processes.callproc = new /process/callproc/naval_stub
	processes.scheduler = new
	processes.scheduler.scheduled_tasks = list()
	GLOB.global_listen_count = list()
	GLOB.event_sources_count = list()
	GLOB.event_listen_count = list()
	build_research_tree()
	naval_check(get_recipe_node_req("/obj/item/weapon/aircraft_bomb") == "powered_flight", "bomb casings are a Powered Flight recipe")

	// The carrier lies bow north with its south-west corner at (10, 10):
	// ship cell (u, v) is world tile (10 + v, 10 + u). The magazine is the
	// hangar deck compartment at u 31-32, with its racks at (11, 42, 1) and
	// (13, 42, 1) and hull walls at x 10 and x 18. The light plane is built
	// facing south: at (11, 30) its nose row is y 30 on x 12-14 and its tail
	// row y 33.
	var/datum/vessel/carrier/C = carrier_lay_down(locate(10, 10, 2), NORTH)
	naval_check(istype(C) && C.placed, "the carrier is laid down bow north")
	if (!istype(C))
		return
	C.bunker(C.fuel_capacity)
	var/obj/structure/shellrack/bombs/rack = locate(/obj/structure/shellrack/bombs) in locate(11, 42, 1)
	var/obj/structure/shellrack/bombs/rack2 = locate(/obj/structure/shellrack/bombs) in locate(13, 42, 1)
	naval_check(rack && rack2 && naval_count_objects(1, /obj/structure/shellrack/bombs) == 2 && istype(rack.loc, /turf/floor/sub_deck/carrier/magazine) && rack.bombs().len == 0, "two empty bomb racks stand in the magazine")
	naval_check(naval_count(1, /turf/floor/sub_deck/carrier/magazine) == 15, "the magazine keeps its fifteen deck tiles")

	// Filling a casing.
	var/mob/living/human/naval_probe/pilot = new(locate(16, 36, 2))
	var/obj/item/weapon/aircraft_bomb/B1 = new(locate(16, 36, 2))
	var/obj/item/weapon/aircraft_bomb/B2 = new(locate(16, 36, 2))
	var/obj/item/weapon/reagent_containers/glass/beaker/K = new(locate(16, 36, 2))
	K.reagents.add_reagent("nitroglycerin", 15)
	naval_check(!B1.filled && B1.name == "empty aircraft bomb casing", "a new casing is empty")
	B1.attackby(K, pilot)
	naval_check(B1.filled && B1.name == "aircraft bomb" && K.reagents.total_volume == 5, "fifteen units of nitroglycerin fill it and leave five")
	B2.attackby(K, pilot)
	naval_check(!B2.filled && K.reagents.total_volume == 5, "five units are not enough for the next")
	K.reagents.add_reagent("nitroglycerin", 10)
	B2.attackby(K, pilot)
	naval_check(B2.filled, "topped up, it fills the second")
	var/obj/item/weapon/aircraft_bomb/B3 = new(locate(16, 36, 2))
	naval_check(rack.storage.can_be_inserted(B1, TRUE) && !rack.storage.can_be_inserted(K, TRUE), "the rack takes bombs and nothing else")

	// Mounting the gun and hanging the bombs on a plane parked on the deck.
	var/obj/structure/vehicleparts/axis/aircraft/A = build_light_plane(locate(11, 30, 2))
	naval_check(istype(A) && A.on_runway() && A.nose_frame() && get_turf(A.nose_frame()) == locate(13, 30, 2) && !A.forward_gun() && A.bombs().len == 0, "a light plane stands on the deck unarmed, nose at (13, 30)")
	var/obj/structure/vehicleparts/frame/N = A.nose_frame()
	var/obj/item/weapon/gun/projectile/automatic/madsen/G = new(locate(16, 36, 2))
	var/obj/item/weapon/gun/projectile/automatic/madsen/G2 = new(locate(16, 36, 2))
	naval_hand(pilot, G)
	N.attackby(G, pilot)
	naval_check(G.loc == N && A.forward_gun() == G, "a Madsen bolts into the nose")
	naval_hand(pilot, G2)
	N.attackby(G2, pilot)
	naval_check(G2.loc == pilot && A.forward_gun() == G, "a second gun is refused")
	var/obj/item/ammo_magazine/madsen/M = new(locate(16, 36, 2))
	naval_hand(pilot, M)
	N.attackby(M, pilot)
	naval_check(G.getAmmo() > 0, "a magazine loads through the nose section ([G.getAmmo()] rounds)")
	var/list/wings = list()
	for (var/obj/structure/vehicleparts/frame/car/aircraft/wing/W in A.frames())
		wings += W
	naval_check(wings.len == 2, "the plane has two wings")
	naval_hand(pilot, B1)
	wings[1].attackby(B1, pilot)
	naval_hand(pilot, B3)
	wings[1].attackby(B3, pilot)
	naval_hand(pilot, B2)
	wings[2].attackby(B2, pilot)
	naval_check(B1.loc == wings[1] && B3.loc == pilot && B2.loc == wings[2] && A.bombs().len == 2, "one bomb hangs under each wing and a second on the same wing is refused")
	naval_check(A.drop_bomb(pilot) == "Drop bombs from the air, not the ground." && A.bombs().len == 2, "bombs are not dropped on the ground")

	// Strafing along the deck on the ground.
	var/obj/structure/closet/crate/naval_target/target = new(locate(13, 25, 2))
	pilot.forceMove(locate(16, 30, 2))
	pilot.last_movement = world.time - 100
	pilot.drop_from_inventory(G2, locate(16, 36, 2))
	pilot.drop_from_inventory(B3, locate(16, 36, 2))
	naval_check(pilot.has_empty_hand(TRUE), "the pilot's hands are free")
	var/rounds = G.getAmmo()
	var/refusal = A.fire_guns(pilot)
	naval_check(isnull(refusal) && G.loc == N && G.getAmmo() == rounds - 1 && projectile_list.len == 1, "the pilot fires the forward gun from the column ([refusal])")
	var/obj/item/projectile/shot = projectile_list.len ? projectile_list[1] : null
	naval_check(shot && get_turf(shot) == locate(13, 30, 2) && shot.firer == pilot, "the round leaves the nose, not the pilot's seat")
	naval_fly_bullets(12)
	naval_check(naval_hits >= 1 && !QDELETED(target), "the burst goes down the deck and hits a crate five tiles ahead ([naval_hits] hits)")
	qdel(target)

	// Up and over the deck.
	naval_fuel(A)
	var/rolled = naval_roll(A, A.takeoff_roll + 2)
	naval_check(A.airborne() && rolled == A.takeoff_roll && naval_frames_in(A, 3, 12, 14, 22, 25), "a deck roll lifts the plane into the air over the stern")
	var/turf/centre = A.footprint_centre()
	var/turf/floor/plating/carrier_deck/under = locate(centre.x, centre.y, 2)
	naval_check(istype(under) && !under.cratered && under.aircraft_runway(), "the deck under the plane is sound")
	refusal = A.drop_bomb(pilot)
	naval_check(isnull(refusal) && A.bombs().len == 1 && QDELETED(B1), "the first bomb falls away and bursts")
	naval_check(under.cratered && !under.aircraft_runway(), "it craters the deck under the plane")
	var/craters = naval_count_cratered(2)
	naval_check(craters >= 1 && craters <= 45, "the blast craters [craters] deck tiles within four of the hit")
	A.set_flight_state(AIRCRAFT_CRUISE)
	naval_check(A.fire_guns(pilot) == "Too high to strafe: descend to low flight first.", "the gun cannot be aimed from cruise height")
	A.set_flight_state(AIRCRAFT_LOW)
	refusal = A.drop_bomb(pilot)
	naval_check(isnull(refusal) && A.bombs().len == 0 && A.drop_bomb(pilot) == "There are no bombs under the wings.", "the second bomb goes too and the racks are empty")

	// The magazine cooks off.
	var/obj/item/weapon/aircraft_bomb/filled/stored = new(rack.storage)
	var/obj/item/weapon/aircraft_bomb/empty_stored = new(rack.storage)
	rack.update_icon()
	naval_check(rack.bombs().len == 2 && rack.icon_state == "shellrack2", "two bombs are racked in the magazine")
	var/turf/wall/sub_hull/hull = locate(10, 42, 1)
	var/integrity = hull.hull_integrity
	rack.ex_act(2)
	naval_check(QDELETED(stored) && rack.bombs().len == 0 && (QDELETED(empty_stored) || empty_stored.loc == locate(11, 42, 1)), "a heavy blast on the rack sets off the filled bomb and empties the rack")
	naval_check(hull.hull_integrity < integrity && istype(locate(10, 42, 1), /turf/wall/sub_hull/carrier), "the hull beside the magazine takes the blast ([integrity] to [hull.hull_integrity])")
	naval_check(!QDELETED(rack) || naval_count_objects(1, /obj/structure/shellrack/bombs) >= 1, "the other rack still stands")
	rack2.ex_act(2)
	naval_check(!QDELETED(rack2) && rack2.bombs().len == 0, "an empty rack shrugs off the blast")

/proc/naval_count_cratered(z)
	. = 0
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/floor/plating/carrier_deck/T = locate(x, y, z)
			if (istype(T) && T.cratered)
				.++
/proc/naval_run()
	try
		naval_checks()
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
		world.log << "TRACE [e.desc]"
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = naval_failures, "runtime_error" = naval_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/naval_probe
		naval_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		naval_run()
