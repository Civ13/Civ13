// Helicopters: the UH-1 "Huey".
//
// A helicopter is a modular aircraft (aircraft.dm) that needs no runway. It
// shares the planes' sky: aloft it rides on the open-air level above the
// ground (multiz_level_above), with the same altitude scale, low flight and
// cruise, shadows, ground view and fire from the ground. What differs:
//
// - Vertical takeoff. It sits on skids and can't taxi. With the engine
//   running, Climb spools the rotor up for a few seconds and then lifts the
//   whole airframe straight up to the level above, like the pedal airship
//   (pedal_airship.dm) rising on the spot.
// - Hover. Stopping, or holding at the edge of the world, is no stall: while
//   the engine runs it hangs in place, keeps climbing or sinking toward the
//   height Climb and Descend set, and pivots on the spot when steered.
// - Landing anywhere clear. Descending close to the ground at low speed sets
//   it down on any dry ground with a slope of at most one level under the
//   skids, runway or not. Water, trenches and obstacles still refuse it.
// - Engine failure. Losing the engine in the air is not a three-second stall
//   but an autorotation: the helicopter sinks a few levels a second and comes
//   down hard (airframe damage, as a rough landing) where the ground is clear
//   and it still had forward speed, and crashes otherwise. A restarted
//   engine recovers it.

// Seconds the rotor needs to spool up before the skids leave the ground.
#define HELICOPTER_SPOOL_TIME (3 SECONDS)
// Levels lost per second while autorotating with a dead engine.
#define HELICOPTER_AUTOROTATION_SINK 3
// The rotor overlay is 224x224, centred on the mast frame.
#define HELICOPTER_ROTOR_OFFSET (-96)

/obj/structure/vehicleparts/axis/aircraft/helicopter
	name = "helicopter"
	desc = "The controls of a helicopter."
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "axis_powered"
	// Hovering is flying: only a dead engine takes the lift away.
	stall_gear = 1
	landing_gear = 2
	maxpower = 2000
	var/tmp/spooling = FALSE

/obj/structure/vehicleparts/axis/aircraft/helicopter/persistence_runtime_var(key)
	return (key == "spooling") || ..(key)

// Skids don't roll: on the ground the helicopter stays put.
/obj/structure/vehicleparts/axis/aircraft/helicopter/do_vehicle_check()
	if (airborne())
		return ..()
	if (moving && currentspeed > 0)
		pilot_message(SPAN_WARNING("\The [src] sits on skids and can't taxi. Use Climb to lift off, then fly it where you want it."))
	moving = FALSE
	currentspeed = 0
	stopmovementloop()
	return FALSE

/obj/structure/vehicleparts/axis/aircraft/helicopter/takeoff_hint()
	if (!engine || !engine.on)
		return "Start the engine first: use the cyclic."
	if (landing_gear_broken())
		return "The skids are bent. Weld any part of the airframe to fix them before you lift off."
	return "Use Climb to spool the rotor up and lift off."

// Whether it is in the air with the rotor driven: free to hover and pivot.
/obj/structure/vehicleparts/axis/aircraft/helicopter/proc/hovering()
	return airborne() && check_engine()

/obj/structure/vehicleparts/axis/aircraft/helicopter/climb(mob/user)
	if (airborne())
		return ..()
	if (spooling)
		to_chat(user, SPAN_NOTICE("The rotor is already spooling up."))
		return FALSE
	if (!check_engine() || landing_gear_broken())
		to_chat(user, SPAN_WARNING(takeoff_hint()))
		return FALSE
	if (!multiz_level_above(flight_z()))
		to_chat(user, SPAN_WARNING("There is no open sky above this place to fly into."))
		return FALSE
	spooling = TRUE
	to_chat(user, SPAN_NOTICE("You open the throttle and pull up on the collective. The rotor spools up..."))
	visible_message(SPAN_NOTICE("\The [src]'s rotor beats faster and faster."))
	playsound(get_turf(src), 'sound/effects/aircraft/uh1.ogg', 60, TRUE)
	addtimer(CALLBACK(src, PROC_REF(finish_spool)), HELICOPTER_SPOOL_TIME)
	return TRUE

// The rotor is up to speed: lift off if the engine still runs.
/obj/structure/vehicleparts/axis/aircraft/helicopter/proc/finish_spool()
	if (QDELETED(src) || !spooling)
		return FALSE
	spooling = FALSE
	if (airborne())
		return FALSE
	if (!check_engine())
		pilot_message(SPAN_WARNING("The engine died before the rotor came up to speed."))
		return FALSE
	moving = FALSE
	currentspeed = 0
	return try_takeoff()

// Near the ground, at low speed, it sets down vertically on any dry ground
// level enough for its skids. Everything else (higher up, over water or an
// obstacle) goes the planes' way.
/obj/structure/vehicleparts/axis/aircraft/helicopter/descend(mob/user)
	if (flight_state != AIRCRAFT_LOW || altitude - ground_level() > AIRCRAFT_LANDING_CLEARANCE)
		return ..()
	var/down = multiz_level_below(flight_z())
	if (!down || clear_at_level(down) || !rough_ground_below(down))
		return ..()
	if (moving && currentspeed > landing_gear)
		to_chat(user, SPAN_WARNING("Too fast to set down: slow to gear [landing_gear] or hover first."))
		return FALSE
	return vertical_landing(down)

/obj/structure/vehicleparts/axis/aircraft/helicopter/proc/vertical_landing(down)
	// With the engine dead it is an autorotation touchdown: hard on the skids.
	if (!check_engine())
		visible_message(SPAN_WARNING("\The [src] flares and drops onto its skids."))
		return rough_landing(down)
	if (!aircraft_shift(down))
		return FALSE
	set_flight_state(AIRCRAFT_GROUND)
	moving = FALSE
	currentspeed = 0
	visible_message(SPAN_NOTICE("\The [src] settles gently onto its skids."))
	return TRUE

// The flight watch: hover instead of stalling, autorotate when the engine dies.
/obj/structure/vehicleparts/axis/aircraft/helicopter/flight_watch_tick()
	if (QDELETED(src) || !airborne())
		flight_watching = FALSE
		return
	burn_flight_fuel()
	note_field_work(driver, "flight")
	if (check_engine())
		if (stall_seconds)
			pilot_message(SPAN_NOTICE("The engine catches and the rotor bites again."))
		stall_seconds = 0
		// Not flying a tile this second: the height still follows Climb and Descend.
		if (!moving || currentspeed < stall_gear)
			update_altitude()
			if (airborne())
				update_flight_visuals()
	else if (autorotate())
		flight_watching = FALSE
		return
	if (!airborne())
		flight_watching = FALSE
		return
	addtimer(CALLBACK(src, PROC_REF(flight_watch_tick)), 1 SECOND)

// One second of autorotation. TRUE once the helicopter is down.
/obj/structure/vehicleparts/axis/aircraft/helicopter/proc/autorotate()
	stall_seconds++
	if (stall_seconds == 1)
		pilot_message(SPAN_DANGER("The engine has quit! The rotor is autorotating: keep your airspeed up and get her down on clear ground."))
	var/ground = ground_level()
	altitude = max(ground, altitude - HELICOPTER_AUTOROTATION_SINK)
	target_altitude = altitude
	if (flight_state == AIRCRAFT_CRUISE && altitude <= AIRCRAFT_SURFACE_CEILING)
		var/hit = low_flight_blocked()
		if (hit)
			crash_land("a collision with [hit]")
			return TRUE
		set_flight_state(AIRCRAFT_LOW)
	update_flight_visuals()
	if (altitude > ground)
		return FALSE
	var/down = multiz_level_below(flight_z())
	if (down && !clear_at_level(down) && rough_ground_below(down) && moving && currentspeed >= landing_gear && rough_landing(down))
		visible_message(SPAN_WARNING("\The [src] autorotates down and lands hard on its skids."))
		return TRUE
	crash_land("an engine-out crash")
	return TRUE

// ---- The airframe ----

// Every section draws its piece of the Huey from huey_airframe.dmi (scripts/draw_huey.py):
// "huey_<column>_<row>" from outside and "..._floor" from inside, like the
// light plane's sections.
/obj/structure/vehicleparts/frame/car/aircraft/huey
	name = "helicopter frame"
	desc = "A section of a helicopter's light metal airframe."
	icon = 'icons/obj/vehicles/huey_airframe.dmi'
	hull_icon = 'icons/obj/vehicles/huey_airframe.dmi'
	icon_state = "huey_2_3_floor"
	hull_state = "huey_2_3"

// The tail cone, boom and fin: the same seen from inside and out, and walled
// off from the cabin.
/obj/structure/vehicleparts/frame/car/aircraft/huey/tail
	name = "helicopter tail boom"
	desc = "The long tail boom of a helicopter."
	noroof = TRUE

/obj/structure/vehicleparts/frame/car/aircraft/huey/nose/right
	hull_state = "huey_1_1"
	w_front = list("c_armoredfront",FALSE,TRUE,0,0.1,FALSE,FALSE)
	w_right = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/aircraft/huey/nose/center
	hull_state = "huey_2_1"
	w_front = list("c_armoredfront",FALSE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/aircraft/huey/nose/left
	hull_state = "huey_3_1"
	w_front = list("c_armoredfront",FALSE,TRUE,0,0.1,FALSE,FALSE)
	w_left = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)

/obj/structure/vehicleparts/frame/car/aircraft/huey/cockpit/right
	name = "cockpit"
	hull_state = "huey_1_2"
	w_right = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/aircraft/huey/cockpit/center
	name = "cockpit"
	hull_state = "huey_2_2"
/obj/structure/vehicleparts/frame/car/aircraft/huey/cockpit/left
	name = "cockpit"
	hull_state = "huey_3_2"
	w_left = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)

// The cargo doors are slid back, as they usually flew.
/obj/structure/vehicleparts/frame/car/aircraft/huey/cabin/right
	name = "helicopter cabin"
	hull_state = "huey_1_3"
	w_right = list("c_windoweddoor",TRUE,TRUE,0,4,TRUE,TRUE)
/obj/structure/vehicleparts/frame/car/aircraft/huey/cabin/center
	name = "helicopter cabin"
	hull_state = "huey_2_3"
/obj/structure/vehicleparts/frame/car/aircraft/huey/cabin/left
	name = "helicopter cabin"
	hull_state = "huey_3_3"
	w_left = list("c_windoweddoor",TRUE,TRUE,0,4,TRUE,TRUE)

/obj/structure/vehicleparts/frame/car/aircraft/huey/aft/right
	name = "helicopter cabin"
	hull_state = "huey_1_4"
	w_right = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
/obj/structure/vehicleparts/frame/car/aircraft/huey/aft/left
	name = "helicopter cabin"
	hull_state = "huey_3_4"
	w_left = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)
	w_back = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)

// Under the rotor mast, with the engine and the fuel tank: a hit here can
// stop the engine, and the main rotor turns over it.
/obj/structure/vehicleparts/frame/car/aircraft/huey/aft/mast
	name = "rotor mast"
	hull_state = "huey_2_4"
	engine_section = TRUE
	w_back = list("c_wall",TRUE,TRUE,0,0.1,FALSE,FALSE)

/obj/structure/vehicleparts/frame/car/aircraft/huey/aft/mast/update_icon()
	..()
	var/spinning = FALSE
	for (var/obj/structure/engine/E in loc)
		if (E.on)
			spinning = TRUE
			break
	var/image/rotor = image(icon='icons/obj/vehicles/huey_rotor.dmi', icon_state=spinning ? "rotor_spin" : "rotor", layer=11.3)
	rotor.pixel_x = HELICOPTER_ROTOR_OFFSET
	rotor.pixel_y = HELICOPTER_ROTOR_OFFSET
	overlays += rotor

/obj/structure/vehicleparts/frame/car/aircraft/huey/tail/cone/right
	hull_state = "huey_1_5"
/obj/structure/vehicleparts/frame/car/aircraft/huey/tail/cone/center
	hull_state = "huey_2_5"
/obj/structure/vehicleparts/frame/car/aircraft/huey/tail/cone/left
	hull_state = "huey_3_5"
/obj/structure/vehicleparts/frame/car/aircraft/huey/tail/boom/right
	hull_state = "huey_1_6"
/obj/structure/vehicleparts/frame/car/aircraft/huey/tail/boom/center
	hull_state = "huey_2_6"
/obj/structure/vehicleparts/frame/car/aircraft/huey/tail/boom/left
	hull_state = "huey_3_6"
/obj/structure/vehicleparts/frame/car/aircraft/huey/tail/fin/right
	hull_state = "huey_1_7"
/obj/structure/vehicleparts/frame/car/aircraft/huey/tail/fin/center
	hull_state = "huey_2_7"
/obj/structure/vehicleparts/frame/car/aircraft/huey/tail/fin/left
	hull_state = "huey_3_7"

// ---- The controls ----

/obj/structure/bed/chair/drivers/aircraft/helicopter
	name = "pilot's seat"
	desc = "Where you fly the helicopter from. The Huey's pilot sits on the right."

/obj/structure/bed/chair/drivers/aircraft/helicopter/New()
	..()
	if (wheel)
		qdel(wheel)
	wheel = new /obj/item/vehicleparts/wheel/modular/aircraft/helicopter(src)
	wheel.drivingchair = src

/obj/item/vehicleparts/wheel/modular/aircraft/helicopter
	name = "cyclic"
	desc = "Use it to start the engine and throttle up, right-click it to slow down, steer with the arrow keys. Climb spools the rotor up and lifts off straight up; Descend close to the ground at low speed sets her down on any dry, fairly level ground. She hovers when stopped and turns on the spot."

// A hovering helicopter pivots on the spot, where a plane or car must be moving to turn.
/obj/item/vehicleparts/wheel/modular/aircraft/helicopter/turndir(var/mob/living/mob = null, var/newdir = "left")
	var/obj/structure/vehicleparts/axis/aircraft/helicopter/H = control && control.axis
	if (!istype(H) || !H.hovering() || (H.moving && H.currentspeed > 0))
		return ..()
	var/was_moving = H.moving
	var/was_speed = H.currentspeed
	H.moving = TRUE
	H.currentspeed = 1
	. = ..()
	H.moving = was_moving
	H.currentspeed = was_speed

// At a standstill the secondary action would cut the engine: not in the air.
/obj/item/vehicleparts/wheel/modular/aircraft/helicopter/secondary_attack_self(mob/living/human/user)
	var/obj/structure/vehicleparts/axis/aircraft/helicopter/H = control && control.axis
	if (istype(H) && H.airborne() && H.engine && H.engine.on && H.currentspeed <= 0)
		to_chat(user, SPAN_WARNING("You are hovering. Set her down before you cut the engine."))
		return
	. = ..()
	if (istype(H) && H.airborne() && !H.moving)
		to_chat(user, SPAN_NOTICE("\The [H] hangs in a hover."))

// The Lycoming T53 turboshaft. It burns diesel, the nearest thing in game to
// the kerosene-based jet fuel it ran on.
/obj/structure/engine/internal/diesel/premade/v6/turboshaft
	name = "turboshaft engine"
	fuelefficiency = 0.05

/obj/structure/vehicleparts/axis/aircraft/helicopter/huey
	name = "UH-1 Huey"
	desc = "The controls of a Bell UH-1 Iroquois utility helicopter, the Huey."

// The Huey: 3 wide and 7 long, built facing south from the bottom-left of a
// 7x7 square. Row 1 is the nose. The pilot sits front right with a co-pilot
// beside them; five cabin seats, the two by the open doors for gunners; the
// engine and tank sit under the rotor mast.
var/global/list/aircraft_huey_layout = list(
	"1,1" = list(/obj/structure/vehicleparts/frame/car/aircraft/huey/nose/right),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/aircraft/huey/nose/center),
	"3,1" = list(/obj/structure/vehicleparts/frame/car/aircraft/huey/nose/left),
	"1,2" = list(/obj/structure/vehicleparts/frame/car/aircraft/huey/cockpit/right, /obj/structure/bed/chair/drivers/aircraft/helicopter, /obj/structure/vehicleparts/movement),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/aircraft/huey/cockpit/center),
	"3,2" = list(/obj/structure/vehicleparts/frame/car/aircraft/huey/cockpit/left, /obj/structure/bed/chair/carseat/aircraft_cabin, /obj/structure/vehicleparts/movement),
	"1,3" = list(/obj/structure/vehicleparts/frame/car/aircraft/huey/cabin/right, /obj/structure/bed/chair/carseat/aircraft_cabin),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/aircraft/huey/cabin/center, /obj/structure/bed/chair/carseat/aircraft_cabin),
	"3,3" = list(/obj/structure/vehicleparts/frame/car/aircraft/huey/cabin/left, /obj/structure/bed/chair/carseat/aircraft_cabin),
	"1,4" = list(/obj/structure/vehicleparts/frame/car/aircraft/huey/aft/right, /obj/structure/bed/chair/carseat/aircraft_cabin, /obj/structure/vehicleparts/movement/reversed),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/aircraft/huey/aft/mast, /obj/structure/engine/internal/diesel/premade/v6/turboshaft, /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank/fueleddiesel),
	"3,4" = list(/obj/structure/vehicleparts/frame/car/aircraft/huey/aft/left, /obj/structure/bed/chair/carseat/aircraft_cabin, /obj/structure/vehicleparts/movement/reversed),
	"1,5" = list(/obj/structure/vehicleparts/frame/car/aircraft/huey/tail/cone/right),
	"2,5" = list(/obj/structure/vehicleparts/frame/car/aircraft/huey/tail/cone/center),
	"3,5" = list(/obj/structure/vehicleparts/frame/car/aircraft/huey/tail/cone/left),
	"1,6" = list(/obj/structure/vehicleparts/frame/car/aircraft/huey/tail/boom/right),
	"2,6" = list(/obj/structure/vehicleparts/frame/car/aircraft/huey/tail/boom/center),
	"3,6" = list(/obj/structure/vehicleparts/frame/car/aircraft/huey/tail/boom/left),
	"1,7" = list(/obj/structure/vehicleparts/frame/car/aircraft/huey/tail/fin/right),
	"2,7" = list(/obj/structure/vehicleparts/frame/car/aircraft/huey/tail/fin/center),
	"3,7" = list(/obj/structure/vehicleparts/frame/car/aircraft/huey/tail/fin/left),
	)

/proc/build_huey(turf/origin)
	return build_aircraft(origin, /obj/structure/vehicleparts/axis/aircraft/helicopter/huey, aircraft_huey_layout, 3, 7)

// Admin and map spawn: builds the Huey facing south, with this tile as the
// bottom-left of its 7x7 footprint. It flies only where the map has an open-air
// level above the ground, as the planes do.
/obj/effect/aircraft_spawner/huey
	name = "Huey spawner"
	icon = 'icons/obj/vehicles/vehicleeffects.dmi'
	icon_state = "5x5"
	invisibility = 101

/obj/effect/aircraft_spawner/huey/New(loc)
	..()
	addtimer(CALLBACK(src, PROC_REF(build)), 1)

/obj/effect/aircraft_spawner/huey/proc/build()
	build_huey(get_turf(src))
	qdel(src)

#undef HELICOPTER_ROTOR_OFFSET
#undef HELICOPTER_AUTOROTATION_SINK
#undef HELICOPTER_SPOOL_TIME
