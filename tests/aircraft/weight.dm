// Aircraft weight (aircraft_load.dm): the load sets the takeoff roll, climb
// rate, flight fuel and cruise pace, and the hangar splits its models across
// Powered Flight and Aviation & Rocketry. Runs on the clean taxi patch
// (x 11-20, y 1-28) after the taxi cases and removes everything it builds.

// Probe-only: lets the check stand in a lighter airframe material.
/obj/structure/vehicleparts/frame/car/aircraft
	var/probe_airframe_weight = null

/obj/structure/vehicleparts/frame/car/aircraft/airframe_weight()
	return isnull(probe_airframe_weight) ? ..() : probe_airframe_weight

// Loads A with heavy crates of cargo until its load ratio passes ratio.
/proc/aircraft_weight_load(obj/structure/vehicleparts/axis/aircraft/A, ratio, list/cargo)
	var/list/F = A.frames()
	for (var/i = 1, i <= 200 && A.aircraft_load(TRUE) <= ratio, i++)
		var/obj/structure/vehicleparts/frame/FR = F[(i % F.len) + 1]
		var/obj/item/I = new /obj/item(get_turf(FR))
		I.w_class = 5
		cargo += I
	return A.aircraft_load(TRUE)

/proc/aircraft_weight_unload(list/cargo)
	for (var/obj/item/I in cargo)
		qdel(I)
	cargo.Cut()

/proc/aircraft_weight_checks()
	var/obj/structure/vehicleparts/axis/aircraft/A = build_light_plane(locate(11, 15, 1))
	if (!istype(A))
		aircraft_check(FALSE, "the weight probe's light plane builds")
		return
	var/obj/structure/engine/internal/E = A.engine
	E.fueltank.reagents.add_reagent(E.fuels[1], 200, safety = TRUE)
	E.on = TRUE
	var/list/cargo = list()

	// A normal load flies exactly as before.
	var/normal = A.aircraft_load(TRUE)
	aircraft_check(abs(normal - 1) < 0.01 && A.takeoff_distance(TRUE) == A.takeoff_roll && A.takeoff_distance(FALSE) == A.rough_takeoff_roll && A.aircraft_climb_rate() == 2 && !A.load_description(), "an empty light plane keeps its 8 / 16 tile roll and climbs two levels a tile (load [normal])")
	A.flight_state = AIRCRAFT_LOW
	var/normal_burn = A.burn_flight_fuel()
	A.flight_state = AIRCRAFT_GROUND

	// Step pace: car pace on the ground, at least two ticks in low flight, and
	// one tick quicker than the gear at cruise.
	A.currentspeed = A.speeds
	A.vehicle_m_delay = A.get_speed()
	var/ground_delay = A.aircraft_step_delay()
	A.flight_state = AIRCRAFT_LOW
	var/low_delay = A.aircraft_step_delay()
	A.flight_state = AIRCRAFT_CRUISE
	var/cruise_delay = A.aircraft_step_delay()
	A.flight_state = AIRCRAFT_GROUND
	aircraft_check(ground_delay == A.vehicle_m_delay + 1 && low_delay == 2 && cruise_delay == 1, "full throttle taxis at car pace and cruises three times as fast ([ground_delay] / [low_delay] / [cruise_delay] ticks a tile)")
	A.currentspeed = 1
	A.vehicle_m_delay = A.get_speed()
	A.flight_state = AIRCRAFT_LOW
	aircraft_check(A.aircraft_step_delay() == A.vehicle_m_delay, "a slow gear in low flight keeps its own pace")
	A.flight_state = AIRCRAFT_GROUND
	A.currentspeed = 0

	// Loaded down: a longer roll, a slow climb, more fuel and a slower cruise.
	var/heavy = aircraft_weight_load(A, 1.3, cargo)
	aircraft_check(heavy > 1.3 && A.takeoff_distance(TRUE) > A.takeoff_roll && A.takeoff_distance(FALSE) > A.rough_takeoff_roll && A.aircraft_climb_rate() == 1, "a heavily loaded plane needs a longer roll ([A.takeoff_distance(TRUE)] / [A.takeoff_distance(FALSE)]) and climbs one level a tile (load [heavy])")
	A.flight_state = AIRCRAFT_LOW
	var/heavy_burn = A.burn_flight_fuel()
	A.currentspeed = A.speeds
	A.vehicle_m_delay = A.get_speed()
	A.flight_state = AIRCRAFT_CRUISE
	var/heavy_cruise = A.aircraft_step_delay()
	A.flight_state = AIRCRAFT_GROUND
	A.currentspeed = 0
	aircraft_check(normal_burn > 0 && heavy_burn > normal_burn && heavy_cruise == 2, "it burns more fuel in the air ([normal_burn] -> [heavy_burn]) and cruises a tick slower ([heavy_cruise])")
	A.takeoff_armed = TRUE
	A.currentspeed = 1
	aircraft_check(findtext(A.load_description(), "heavily loaded") && findtext(A.takeoff_hint(), "after [A.takeoff_distance(TRUE)] tiles of runway or [A.takeoff_distance(FALSE)] tiles of open ground"), "examine and the takeoff hint give the loaded roll")
	A.takeoff_armed = FALSE
	A.currentspeed = 0

	// Overloaded: the wheels never leave the ground.
	var/over = aircraft_weight_load(A, 1.8, cargo)
	aircraft_check(over > 1.8 && A.too_heavy_to_fly() && !A.try_takeoff() && !A.airborne() && A.runway_roll == 0 && findtext(A.load_description(), "too heavy"), "an overloaded plane refuses to lift off (load [over])")
	aircraft_weight_unload(cargo)
	aircraft_check(abs(A.aircraft_load(TRUE) - 1) < 0.01 && !A.too_heavy_to_fly(), "unloading the cargo brings it back to a normal load")

	// A lighter airframe material lifts off sooner and climbs faster.
	for (var/obj/structure/vehicleparts/frame/car/aircraft/F in A.frames())
		F.probe_airframe_weight = 0
	var/light = A.aircraft_load(TRUE)
	aircraft_check(light <= 0.85 && A.takeoff_distance(TRUE) < A.takeoff_roll && A.takeoff_distance(FALSE) < A.rough_takeoff_roll && A.aircraft_climb_rate() == 3 && findtext(A.load_description(), "light"), "a lighter airframe needs a shorter roll ([A.takeoff_distance(TRUE)] / [A.takeoff_distance(FALSE)]) and climbs three levels a tile (load [light])")
	for (var/obj/structure/vehicleparts/frame/car/aircraft/F in A.frames())
		F.probe_airframe_weight = null

	// The hangar's models are split across two research nodes.
	if (!research_nodes.len)
		build_research_tree()
	var/obj/structure/car_workshop/hangar/hangar = new(locate(14, 2, 1))
	aircraft_check(aircraft_model_node("Light plane") == "powered_flight" && aircraft_model_node("Trainer") == "powered_flight" && aircraft_model_node("Cabin plane") == "aviation_rocketry" && aircraft_model_node("Cargo plane") == "aviation_rocketry" && aircraft_model_node("Twin-engine plane") == "aviation_rocketry", "Powered Flight builds the trainer and light plane; the cabin, cargo and twin-engine planes need Aviation & Rocketry")
	var/list/early = hangar.model_missing_research(null, "Light plane")
	var/list/late = hangar.model_missing_research(null, "Twin-engine plane")
	aircraft_check(!early.len && late.len == 1 && late[1] == "Aviation & Rocketry", "without Aviation & Rocketry the twin-engine plane is held back ([english_list(late)])")
	var/list/options = hangar.project_options()
	aircraft_check(("Start a Twin-engine plane piece by piece" in options) && ("Start a Light plane piece by piece" in options), "the full model list is unchanged when no builder is named")

	for (var/atom/movable/part in A.components.Copy())
		if (part != A)
			qdel(part)
	for (var/turf/T in block(locate(11, 1, 1), locate(20, 28, 1)))
		for (var/atom/movable/M in T)
			if (!istype(M, /atom/movable/lighting_overlay))
				qdel(M)
	qdel(A)
	qdel(hangar)
