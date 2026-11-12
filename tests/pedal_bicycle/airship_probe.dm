// Headless full-game pedal airship regression. ride.py --probe airship_probe.dm
// appends it to a temporary copy of civ13.dme. A rider boards a landed
// airship, finds the propeller useless on the ground, rises, pedals across the
// open air, hovers, is refused a dismount and a descent onto water, sinks back
// to dry ground and gets off. Further legs cover the lift limit, an upper
// storey in the way, loose things on its tile and a forced set-down.
// Production code runs unchanged; this file only drives it and records.
var/global/datum/pedal_airship_probe/pedal_airship_probe = new

/mob/living/human/pedal_airship_actor/ssd_check()
	return FALSE

/datum/pedal_airship_probe
	var/list/notes = list()
	var/list/problems = list()

/datum/pedal_airship_probe/New()
	if(!all_species || !all_species.len)
		makeDatumRefLists()
	if(!config)
		load_configuration()
		initialize_chemical_reagents()
		initialize_chemical_reactions()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	spawn(10)
		run_probe()

/datum/pedal_airship_probe/proc/ready()
	return ticker && processScheduler && ticker.current_state >= GAME_STATE_PREGAME

/datum/pedal_airship_probe/proc/playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/pedal_airship_probe/proc/sky_ready()
	return building_standing_present()

/datum/pedal_airship_probe/proc/wait_for(proc_name, limit)
	var/until = world.time + limit
	while(!call(src, proc_name)())
		if(world.time > until)
			throw EXCEPTION("timeout waiting for [proc_name]")
		sleep(5)

/datum/pedal_airship_probe/proc/expect(condition, text)
	if(!condition)
		problems += text

// Clear grass below and clear open air above.
/datum/pedal_airship_probe/proc/prepare(turf/centre, sky_z)
	for(var/dx = -14 to 14)
		for(var/dy = -14 to 14)
			for(var/level in list(centre.z, sky_z))
				var/turf/T = locate(centre.x + dx, centre.y + dy, level)
				if(!T)
					return FALSE
				for(var/atom/movable/A in T)
					if(A.density || ismob(A) || istype(A, /obj/structure) || istype(A, /obj/covers) || istype(A, /obj/roof))
						A.loc = null // Fixture ground only; immediate, unlike queued qdel.
				if(level == centre.z && T.type != /turf/floor/grass)
					T = new /turf/floor/grass(T)
				if(level == sky_z && T.type != /turf/sky/building)
					T = new /turf/sky/building(T)
	sleep(10)
	return TRUE

/datum/pedal_airship_probe/proc/board(turf/start, load = 0)
	var/obj/structure/vehicle/bicycle/airship/V = new(start)
	V.dir = EAST
	var/mob/living/human/pedal_airship_actor/R = new(start)
	R.m_intent = "walk"
	R.a_intent = I_HELP
	sleep(5)
	if(load)
		var/obj/item/weapon/wrench/cargo = new(R)
		cargo.weight = load
	R.dir = EAST
	V.MouseDrop_T(R, R)
	if(V.driver != R)
		throw EXCEPTION("rider did not take the tiller")
	R.dir = EAST
	return V

/datum/pedal_airship_probe/proc/discard(obj/structure/vehicle/bicycle/airship/V)
	var/mob/living/human/R = V.driver
	qdel(V)
	if(R)
		R.loc = null
	sleep(5)

/datum/pedal_airship_probe/proc/flight(turf/start, sky_z)
	var/obj/structure/vehicle/bicycle/airship/V = board(start)
	var/mob/living/human/R = V.driver
	var/obj/item/vehicleparts/wheel/handle/bicycle/airship/tiller = R.get_active_hand()
	expect(istype(tiller), "no tiller in hand")
	expect(V.overlays.len, "no rider overlay when boarded")
	expect(R.pixel_y == 0, "rider raised [R.pixel_y] in the basket")
	// On the ground the propeller does nothing.
	tiller.attack_self(R)
	sleep(10)
	expect(!V.moving && V.loc == start, "pedaled along the ground")
	// Rise.
	// Too tired to pedal it up (checked before the climb starts).
	var/rested = R.stats["stamina"][1]
	R.stats["stamina"][1] = 3
	tiller.secondary_attack_self(R)
	expect(!V.aloft && V.z == start.z, "rose while exhausted")
	R.stats["stamina"][1] = rested
	tiller.secondary_attack_self(R)
	expect(V.aloft && V.z == sky_z && V.x == start.x && V.y == start.y, "did not rise: aloft [V.aloft] at [V.x],[V.y],[V.z]")
	expect(R.loc == V.loc && R.buckled == V && V.driver == R, "rider not carried up")
	expect(R.getBruteLoss() == 0, "rider hurt rising")
	expect(V in aloft_pedal_airships, "not listed aloft")
	expect(V.shadow_turf == start && (V.shadow in start.vis_contents), "no shadow below")
	expect(V.ground_view && V.ground_view.vis_contents.len > 100, "no ground view")
	sleep(10)
	expect(V.z == sky_z && R.z == sky_z, "fell while hovering")
	// Fly east.
	tiller.attack_self(R)
	expect(V.moving, "pedaling did not start aloft")
	var/lastx = V.x
	var/first_arrival = null
	var/last_arrival = null
	var/arrivals = 0
	var/together = TRUE
	var/until = world.time + 300
	while(world.time < until && V.x - start.x < 6 && V.moving)
		sleep(world.tick_lag)
		if(V.x != lastx)
			lastx = V.x
			arrivals++
			if(isnull(first_arrival))
				first_arrival = world.time
			last_arrival = world.time
			if(R.loc != V.loc || R.z != sky_z || R.glide_size != V.glide_size)
				together = FALSE
	var/interval = arrivals > 1 ? (last_arrival - first_arrival) / (arrivals - 1) : null
	notes["interval"] = interval
	notes["set_delay"] = V.vehicle_m_delay
	expect(V.x - start.x >= 6, "flew only [V.x - start.x] tiles")
	expect(together, "rider left behind in flight")
	expect(V.vehicle_m_delay == 3 && !isnull(interval) && abs(interval - 3) <= world.tick_lag / 2, "[interval] ds per tile, expected 3")
	var/turf/under = locate(V.x, V.y, start.z)
	expect(V.shadow_turf == under && !(V.shadow in start.vis_contents), "shadow did not follow")
	// Brake: it hangs where it is.
	tiller.secondary_attack_self(R)
	expect(!V.moving && V.aloft, "brake did not stop it in the air")
	var/turf/hung = V.loc
	sleep(15)
	expect(V.loc == hung && R.loc == hung, "drifted or fell after braking")
	// No getting off up here.
	V.attack_hand(R)
	sleep(5)
	expect(V.driver == R && R.buckled == V && R.z == sky_z, "got off in the air")
	// Loose things on its tile are not held; nor is the open air beside it.
	var/obj/item/weapon/wrench/dropped = new(null)
	dropped.forceMove(V.loc)
	expect(dropped.z == start.z, "a dropped item hung in the air")
	dropped.loc = null
	// Water below: no settling.
	var/under_type = under.type
	under = new /turf/floor/beach/water(under)
	tiller.secondary_attack_self(R)
	expect(V.aloft && V.z == sky_z, "sank onto water")
	under = new under_type(under)
	// Dry ground: sink, then get off.
	V.update_flight_visuals()
	tiller.secondary_attack_self(R)
	expect(!V.aloft && V.loc == under && R.loc == under && V.driver == R, "did not sink to the ground: aloft [V.aloft] z [V.z]")
	expect(R.getBruteLoss() == 0 && V.health >= 100, "landing did damage")
	expect(!(V in aloft_pedal_airships) && !V.shadow_turf && !V.ground_view, "flight visuals left behind after landing")
	V.attack_hand(R)
	sleep(15)
	expect(!V.driver && !R.buckled && tiller.loc == V && !V.overlays.len, "did not get off on the ground")
	qdel(V)
	R.loc = null
	sleep(5)

/datum/pedal_airship_probe/proc/overloaded(turf/start, sky_z)
	var/obj/structure/vehicle/bicycle/airship/V = board(start, 200)
	var/mob/living/human/R = V.driver
	var/obj/item/vehicleparts/wheel/handle/bicycle/airship/tiller = R.get_active_hand()
	tiller.secondary_attack_self(R)
	expect(!V.aloft && V.z == start.z, "lifted more than the rider can carry")
	discard(V)
	// A load the rider can carry lifts, and flies slower.
	V = board(start, 30)
	R = V.driver
	tiller = R.get_active_hand()
	tiller.secondary_attack_self(R)
	expect(V.aloft, "a moderate load did not lift")
	tiller.attack_self(R)
	sleep(40)
	notes["loaded_delay"] = V.vehicle_m_delay
	expect(V.vehicle_m_delay > 3 && V.vehicle_m_delay <= 12 && V.x > start.x, "loaded pace [V.vehicle_m_delay], moved [V.x - start.x]")
	discard(V)

/datum/pedal_airship_probe/proc/blocked(turf/start, sky_z)
	var/obj/structure/vehicle/bicycle/airship/V = board(start)
	var/mob/living/human/R = V.driver
	var/obj/item/vehicleparts/wheel/handle/bicycle/airship/tiller = R.get_active_hand()
	// An upper storey three tiles ahead.
	var/obj/covers/floor = new(locate(start.x + 3, start.y, sky_z))
	tiller.secondary_attack_self(R)
	tiller.attack_self(R)
	sleep(60)
	expect(V.aloft && V.x == start.x + 2 && !V.moving && R.getBruteLoss() == 0, "upper storey: at +[V.x - start.x], moving [V.moving]")
	// A roof overhead stops the rise.
	floor.loc = null
	discard(V)
	V = board(start)
	R = V.driver
	tiller = R.get_active_hand()
	floor = new(locate(start.x, start.y, sky_z))
	tiller.secondary_attack_self(R)
	expect(!V.aloft && V.z == start.z, "rose through a floor")
	floor.loc = null
	discard(V)

/datum/pedal_airship_probe/proc/forced(turf/start, sky_z)
	var/obj/structure/vehicle/bicycle/airship/V = board(start)
	var/mob/living/human/R = V.driver
	var/obj/item/vehicleparts/wheel/handle/bicycle/airship/tiller = R.get_active_hand()
	tiller.secondary_attack_self(R)
	expect(V.aloft, "forced: did not rise")
	// The rider is pulled from the seat in mid air: both come down unhurt.
	V.unbuckle_mob()
	expect(!V.aloft && V.z == start.z && R.z == start.z && R.getBruteLoss() == 0 && !V.driver, "forced set-down: aloft [V.aloft], airship z [V.z], rider z [R.z], brute [R.getBruteLoss()]")
	expect(!V.shadow_turf && !(V in aloft_pedal_airships), "forced set-down left visuals")
	qdel(V)
	R.loc = null
	sleep(5)
	// Over water with dry ground nearby it drifts to the dry ground.
	V = board(start)
	R = V.driver
	tiller = R.get_active_hand()
	tiller.secondary_attack_self(R)
	var/turf/G = new /turf/floor/beach/water(start)
	V.driver_died(R)
	expect(!V.aloft && V.z == start.z && V.loc != G && get_dist(V, G) == 1, "set-down over water landed at [V.x],[V.y],[V.z]")
	expect(!V.driver && R.z == start.z, "dead rider left in the air")
	G = new /turf/floor/grass(G)
	qdel(V)
	R.loc = null
	// Destroyed in the air: the rider comes down unhurt.
	V = board(start)
	R = V.driver
	tiller = R.get_active_hand()
	tiller.secondary_attack_self(R)
	qdel(V)
	sleep(5)
	expect(R.z == start.z && R.getBruteLoss() == 0 && !R.buckled, "rider of a destroyed airship at z [R.z], brute [R.getBruteLoss()]")
	R.loc = null

/datum/pedal_airship_probe/proc/run_probe()
	var/failure = null
	try
		wait_for("ready", 9000)
		ticker.admin_started = TRUE
		if(ticker.pregame_timeleft > 1)
			ticker.pregame_timeleft = 1
		wait_for("playing", 3000)
		// The standing open-air level is added shortly after the round starts.
		wait_for("sky_ready", 600)
		var/turf/start = null
		var/sky_z = 0
		for(var/level = 1 to world.maxz)
			var/up = multiz_level_above(level)
			if(up && istype(locate(1, 1, up), /turf/sky))
				start = locate(round(world.maxx / 2), round(world.maxy / 2), level)
				sky_z = up
				break
		if(!start || !prepare(start, sky_z))
			throw EXCEPTION("no ground with open sky above found")
		notes["start"] = "[start.x],[start.y],[start.z] under [sky_z]"
		flight(start, sky_z)
		overloaded(start, sky_z)
		blocked(start, sky_z)
		forced(start, sky_z)
		if(problems.len)
			notes["problems"] = problems
			throw EXCEPTION(jointext(problems, "; "))
	catch(var/exception/e)
		failure = "[e.name] [e.file]:[e.line]"
	var/list/result = list("passed" = isnull(failure), "failure" = failure, "notes" = notes, "tick_lag" = world.tick_lag)
	text2file(json_encode(result), "result.json")
	world.log << "PEDAL AIRSHIP PROBE DONE [failure]"
	sleep(5)
	del(world)
