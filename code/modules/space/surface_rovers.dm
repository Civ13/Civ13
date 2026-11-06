// ============================================================
// Surface rovers (space settlement phase 5)
// ------------------------------------------------------------
// Rovers are ordinary modular vehicles built at a rover assembly bay (a
// car workshop with its own models). Combustion engines need air to burn,
// so on barren ground only the rover's electric drive starts; it runs on
// the charge in its battery pack, topped up at a cabled rover charger.
//
// The sealed rover's cabin is one habitat ledger (habitat_ledger.dm) kept
// as plain numbers on its axis. Everyone on the rover's frame tiles shares
// it; an open door is a breach. While the battery has charge the cabin
// panel tops oxygen up from its reserve (refilled from suit air tanks),
// scrubs CO2 and heats. The open rover carries a cargo bed and no air.
// Trailers are not built: the vehicle system has no towing.
// Reuses existing vehicle parts and sprites; no new art.
// ============================================================

#define ROVER_TICK_SECONDS 2
#define ROVER_CABIN_C 20
#define ROVER_OXYGEN_KPA 21
#define ROVER_INERT_KPA 79
#define ROVER_CO2_TARGET_KPA 0.4
// Battery charge the cabin panel uses per second while it works.
#define ROVER_CABIN_CHARGE_PER_SECOND 0.01
#define ROVER_BATTERY_UNITS 450
#define ROVER_CHARGE_PER_USE 150
#define ROVER_CHARGER_RANGE 2

// ---------------------------------------------------------------- charge

/datum/reagent/rover_charge
	name = "Stored charge"
	id = "rover_charge"
	description = "Energy held in a rover's battery cells. It is not something you can drink."
	taste_description = "a tingle"
	reagent_state = LIQUID
	color = "#7fd3ff"

/obj/item/weapon/reagent_containers/glass/barrel/fueltank/rover_battery
	name = "rover battery pack"
	desc = "Sealed battery cells for a rover's electric drive. Charge it at a cabled rover charger."
	icon_state = "fueltank_large_tank"
	volume = ROVER_BATTERY_UNITS

/obj/item/weapon/reagent_containers/glass/barrel/fueltank/rover_battery/charged/New()
	..()
	reagents.add_reagent("rover_charge", ROVER_BATTERY_UNITS)

// Whether this engine can run on the ground under it.
/obj/structure/engine/internal/proc/engine_has_air()
	var/turf/T = get_turf(src)
	return !T || T.outside_air_breathable()

/obj/structure/engine/internal/electric_drive
	name = "electric drive"
	desc = "Battery-fed hub motors for a rover. Needs no air to run."
	icon = 'icons/obj/engines32.dmi'
	icon_state = "diesel_static"
	engineclass = "electric"
	maxpower = 80
	torque = 1.4
	fuelefficiency = 0.2
	fuels = list("rover_charge")
	enginesize = 8000

/obj/structure/engine/internal/electric_drive/New()
	..()
	name = initial(name)

/obj/structure/engine/internal/electric_drive/engine_has_air()
	return TRUE

/obj/structure/rover_charger
	name = "rover charger"
	desc = "A cabled charging post. Park a rover beside it and use the post to charge the rover's battery."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "smes2"
	anchored = TRUE
	density = TRUE
	not_movable = FALSE
	powerneeded = 20

/obj/structure/rover_charger/proc/has_power()
	return draw_cable_power()

// The battery of a rover with an electric drive parked beside the post.
/obj/structure/rover_charger/proc/rover_battery()
	for (var/obj/structure/vehicleparts/axis/A in range(ROVER_CHARGER_RANGE + 4, src))
		if (!QDELETED(A) && istype(A.engine, /obj/structure/engine/internal/electric_drive) && A.engine.fueltank && rover_near(A))
			return A.engine.fueltank
	return null

/obj/structure/rover_charger/proc/rover_near(obj/structure/vehicleparts/axis/A)
	for (var/obj/structure/vehicleparts/frame/F in A.components)
		if (get_dist(src, F) <= ROVER_CHARGER_RANGE)
			return TRUE
	return FALSE

// Adds up to one charge's worth; returns the units added.
/obj/structure/rover_charger/proc/charge(obj/item/weapon/reagent_containers/glass/barrel/fueltank/B)
	if (!B || !B.reagents || !has_power())
		return 0
	var/room = B.reagents.maximum_volume - B.reagents.total_volume
	var/amount = min(room, ROVER_CHARGE_PER_USE)
	if (amount <= 0)
		return 0
	B.reagents.add_reagent("rover_charge", amount)
	return amount

/obj/structure/rover_charger/attack_hand(mob/user as mob)
	var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/B = rover_battery()
	if (!B)
		to_chat(user, SPAN_WARNING("Park a rover with an electric drive beside \the [src] first."))
		return
	if (!has_power())
		to_chat(user, SPAN_WARNING("\The [src] has no power."))
		return
	to_chat(user, SPAN_NOTICE("You plug the rover in..."))
	if (!do_after(user, 50, src))
		return
	var/added = charge(B)
	if (added <= 0)
		to_chat(user, SPAN_NOTICE("The rover's battery is already full."))
		return
	to_chat(user, SPAN_NOTICE("The rover's battery is now at [round(100 * B.reagents.get_reagent_amount("rover_charge") / B.reagents.maximum_volume)]%."))

/obj/structure/rover_charger/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack/cable_coil))
		if (powersource)
			to_chat(user, SPAN_WARNING("It is already cabled."))
			return
		connect_cable(user, W)
		return
	return ..()

// ---------------------------------------------------------------- sealed cabin

/obj/structure/vehicleparts/axis/car/rover_sealed
	name = "sealed rover"
	desc = "The drive axis of a pressurised rover."
	speeds = 3
	maxpower = 1100
	speedlist = alist(1=7,2=5.5,3=4.5)
	turntimer = 9
	// Cabin air as plain numbers, and the oxygen reserve. No time stamps.
	var/cabin_oxygen = 0
	var/cabin_co2 = 0
	var/cabin_inert = 0
	var/cabin_temperature = ROVER_CABIN_C
	var/oxygen_reserve = 0
	var/tmp/datum/habitat_ledger/cabin_air = null

/obj/structure/vehicleparts/axis/car/rover_sealed/New()
	..()
	processing_objects |= src

/obj/structure/vehicleparts/axis/car/rover_sealed/Destroy()
	processing_objects -= src
	cabin_air = null
	return ..()

/obj/structure/vehicleparts/axis/car/rover_sealed/proc/cabin_frames()
	var/list/found = list()
	for (var/obj/structure/vehicleparts/frame/F in components)
		if (!QDELETED(F))
			found += F
	return found

/obj/structure/vehicleparts/axis/car/rover_sealed/proc/cabin_volume()
	return max(1, length(cabin_frames()))

/obj/structure/vehicleparts/axis/car/rover_sealed/proc/fill_cabin()
	var/volume = cabin_volume()
	cabin_oxygen = ROVER_OXYGEN_KPA * volume
	cabin_co2 = 0
	cabin_inert = ROVER_INERT_KPA * volume
	cabin_temperature = ROVER_CABIN_C
	oxygen_reserve = 4 * HABITAT_BREATH_PER_SECOND * 3600
	cabin_air = null

/obj/structure/vehicleparts/axis/car/rover_sealed/proc/cabin()
	if (!cabin_air)
		cabin_air = new /datum/habitat_ledger(cabin_volume())
		if (!cabin_air.from_list(list("volume" = cabin_volume(), "oxygen" = cabin_oxygen, "co2" = cabin_co2, "inert" = cabin_inert, "temperature" = cabin_temperature)))
			cabin_air.temperature = BARREN_AMBIENT_C
	return cabin_air

/obj/structure/vehicleparts/axis/car/rover_sealed/proc/store_cabin()
	if (!cabin_air)
		return
	cabin_oxygen = cabin_air.oxygen
	cabin_co2 = cabin_air.co2
	cabin_inert = cabin_air.inert
	cabin_temperature = cabin_air.temperature

// Open doors and wrecked frames.
/obj/structure/vehicleparts/axis/car/rover_sealed/proc/cabin_breaches()
	. = 0
	for (var/obj/structure/vehicleparts/frame/F in cabin_frames())
		if (F.broken)
			.++
			continue
		for (var/list/wall in list(F.w_front, F.w_back, F.w_left, F.w_right))
			if (length(wall) >= 7 && wall[6] && wall[7])
				.++

/obj/structure/vehicleparts/axis/car/rover_sealed/proc/cabin_occupants()
	. = 0
	for (var/obj/structure/vehicleparts/frame/F in cabin_frames())
		for (var/mob/living/human/H in F.loc)
			if (H.stat != DEAD)
				.++

/obj/structure/vehicleparts/axis/car/rover_sealed/proc/battery_charge()
	if (!engine || !engine.fueltank || !engine.fueltank.reagents)
		return 0
	return engine.fueltank.reagents.get_reagent_amount("rover_charge")

/obj/structure/vehicleparts/axis/car/rover_sealed/process()
	if (!clients.len)
		return
	cabin_step(ROVER_TICK_SECONDS, cabin_occupants())

// One bounded step: breathing, leaks and cooling, then, while the battery
// has charge, the panel tops up oxygen, scrubs CO2 and heats.
/obj/structure/vehicleparts/axis/car/rover_sealed/proc/cabin_step(seconds, occupants)
	var/datum/habitat_ledger/L = cabin()
	if (!L.advance(seconds, occupants, cabin_breaches(), barren_ambient_c()))
		return FALSE
	var/dt = habitat_clamp(seconds, 0, HABITAT_MAX_STEP_SECONDS)
	var/use = ROVER_CABIN_CHARGE_PER_SECOND * dt
	if (battery_charge() >= use)
		engine.fueltank.reagents.remove_reagent("rover_charge", use)
		var/give = min(max(0, ROVER_OXYGEN_KPA * L.volume - L.oxygen), oxygen_reserve)
		if (give > 0)
			oxygen_reserve -= give
			L.add_gas(give)
		var/excess = max(0, L.co2 - ROVER_CO2_TARGET_KPA * L.volume)
		if (excess > 0)
			L.scrub_co2(excess)
		L.temperature = ROVER_CABIN_C
	store_cabin()
	return TRUE

// The panel on a sealed rover's cabin: shows the air and takes suit tanks.
/obj/structure/rover_cabin_panel
	name = "rover cabin panel"
	desc = "Shows the rover cabin's air. Use a suit air tank on it to empty the tank into the cabin's oxygen reserve."
	icon = 'icons/obj/computers.dmi'
	icon_state = "solar_screen"
	anchored = TRUE
	density = FALSE
	layer = 3.1

/obj/structure/rover_cabin_panel/proc/rover()
	for (var/obj/structure/vehicleparts/frame/F in loc)
		if (istype(F.axis, /obj/structure/vehicleparts/axis/car/rover_sealed))
			return F.axis
	return null

/obj/structure/rover_cabin_panel/examine(mob/user)
	..()
	var/obj/structure/vehicleparts/axis/car/rover_sealed/R = rover()
	if (!R)
		return
	var/datum/habitat_ledger/L = R.cabin()
	to_chat(user, SPAN_NOTICE("Cabin: [round(L.pressure_kpa())] kPa, [round(L.oxygen_kpa(), 0.1)] kPa oxygen, [round(L.temperature)] C. Oxygen reserve [round(R.oxygen_reserve, 0.1)]. Battery [round(R.battery_charge())]."))
	var/holes = R.cabin_breaches()
	if (holes)
		to_chat(user, SPAN_WARNING("[holes] open door\s or breach\s: the cabin is venting."))

/obj/structure/rover_cabin_panel/attackby(obj/item/W as obj, mob/user as mob)
	var/obj/structure/vehicleparts/axis/car/rover_sealed/R = rover()
	if (R && istype(W, /obj/item/pressure_tank))
		var/obj/item/pressure_tank/A = W
		if (A.air_seconds <= 0)
			to_chat(user, SPAN_WARNING("\The [A] is empty."))
			return
		R.oxygen_reserve += A.air_seconds * HABITAT_BREATH_PER_SECOND
		A.air_seconds = 0
		to_chat(user, SPAN_NOTICE("You empty \the [A] into the cabin's oxygen reserve."))
		return
	return ..()

// The sealed rover cabin a person is in, or null.
/mob/living/human/proc/rover_cabin()
	if (!isturf(loc))
		return null
	for (var/obj/structure/vehicleparts/frame/F in loc)
		var/obj/structure/vehicleparts/axis/car/rover_sealed/R = F.axis
		if (istype(R) && !QDELETED(R))
			return R.cabin()
	return null

// ---------------------------------------------------------------- templates

/obj/structure/vehicleparts/frame/car/wyoming/lfc/rover
	w_left = list("none",TRUE,TRUE,0,4,TRUE,FALSE)
/obj/structure/vehicleparts/frame/car/wyoming/rbc/rover
	noroof = FALSE
/obj/structure/vehicleparts/frame/car/wyoming/lbc/rover
	noroof = FALSE

/obj/effects/premadevehicles/rover
	icon_state = "4x4"
	custom_color = "#c9c3b5"

/obj/effects/premadevehicles/rover/open
	name = "open rover"
	axis = /obj/structure/vehicleparts/axis/car/wyoming
	tocreate = list(
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/rover_battery/charged, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/frame/car/wyoming/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/wyoming/lf, /obj/structure/engine/internal/electric_drive, /obj/structure/vehicleparts/movement),
	"1,2" = list(/obj/structure/vehicleparts/frame/car/wyoming/rfc, /obj/structure/bed/chair/carseat/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/wyoming/lfc, /obj/structure/bed/chair/drivers/car),
	"1,3" = list(/obj/structure/vehicleparts/frame/car/wyoming/rbc, /obj/structure/table/carboot),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/wyoming/lbc, /obj/structure/table/carboot),
	"1,4" = list(/obj/structure/vehicleparts/frame/car/wyoming/rb, /obj/structure/vehicleparts/movement/reversed),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/wyoming/lb, /obj/structure/vehicleparts/movement/reversed),
	)

/obj/effects/premadevehicles/rover/sealed
	name = "sealed rover"
	axis = /obj/structure/vehicleparts/axis/car/rover_sealed
	tocreate = list(
	"1,1" = list(/obj/item/weapon/reagent_containers/glass/barrel/fueltank/rover_battery/charged, /obj/structure/vehicleparts/movement, /obj/structure/vehicleparts/frame/car/wyoming/rf),
	"2,1" = list(/obj/structure/vehicleparts/frame/car/wyoming/lf, /obj/structure/engine/internal/electric_drive, /obj/structure/vehicleparts/movement),
	"1,2" = list(/obj/structure/vehicleparts/frame/car/wyoming/rfc, /obj/structure/bed/chair/carseat/right),
	"2,2" = list(/obj/structure/vehicleparts/frame/car/wyoming/lfc/rover, /obj/structure/bed/chair/drivers/car),
	"1,3" = list(/obj/structure/vehicleparts/frame/car/wyoming/rbc/rover, /obj/structure/rover_cabin_panel),
	"2,3" = list(/obj/structure/vehicleparts/frame/car/wyoming/lbc/rover, /obj/structure/bed/chair/carseat/left),
	"1,4" = list(/obj/structure/vehicleparts/frame/car/wyoming/rb, /obj/structure/vehicleparts/movement/reversed),
	"2,4" = list(/obj/structure/vehicleparts/frame/car/wyoming/lb, /obj/structure/vehicleparts/movement/reversed),
	)

// ---------------------------------------------------------------- assembly bay

/obj/structure/car_workshop/rover_bay
	name = "rover assembly bay"
	desc = "A rover assembly press. Feed steel, glass, cloth, cable and four unattached wheels. It builds a rover in the clear square northeast of the press, with a charged battery."

/obj/structure/car_workshop/rover_bay/models()
	return list("Open rover" = /obj/effects/premadevehicles/rover/open, "Sealed rover" = /obj/effects/premadevehicles/rover/sealed)

/obj/structure/car_workshop/rover_bay/allowed(mob/living/human/H)
	return H && map && map.is_node_done(H.civilization, "surface_vehicles")

/obj/structure/car_workshop/rover_bay/model_size(model)
	return (model in models()) ? 4 : 0

/obj/structure/car_workshop/rover_bay/costs(model)
	if (!(model in models()))
		return null
	if (model == "Sealed rover")
		return list("steel" = 70, "glass" = 10, "cloth" = 6, "cable" = 20, "wheels" = 4)
	return list("steel" = 50, "glass" = 4, "cloth" = 4, "cable" = 20, "wheels" = 4)

/obj/structure/car_workshop/rover_bay/requirement_text()
	return "Surface Vehicles research is required."

/obj/structure/car_workshop/rover_bay/menu_text()
	return "Stored: [stock["steel"]] steel, [stock["glass"]] glass, [stock["cloth"]] cloth, [stock["cable"]] cable, [stock["wheels"]] wheels. The open rover costs 50/4/4/20/4; the sealed rover costs 70/10/6/20/4. Keep the northeast 4x4 bay empty."

/obj/structure/car_workshop/rover_bay/assembled_message(model)
	return "Your [model] is assembled with a charged battery."

// Workshop layouts replace map fuel with an empty tank; a rover gets its
// charged battery back, and a sealed rover a full cabin.
/obj/structure/car_workshop/rover_bay/complete_assembly(model)
	var/obj/structure/vehicleparts/axis/A = ..()
	if (!A || !A.engine)
		return A
	var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/old = A.engine.fueltank
	var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/rover_battery/charged/B = new(old ? old.loc : get_turf(A.engine))
	B.anchored = TRUE
	B.icon_state = "fueltank_incar"
	A.engine.fueltank = B
	if (old)
		qdel(old)
	var/obj/structure/vehicleparts/axis/car/rover_sealed/R = A
	if (istype(R))
		R.fill_cabin()
	return A
