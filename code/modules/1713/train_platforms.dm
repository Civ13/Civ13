// Walkable platform cars (docs/train-platforms.md). A car is three tiles wide
// and as long as its kind has segments (train_car_length()): four tiles for
// the early four-wheel stock, eight for bogie stock. One segment per rail tile, each a
// /obj/structure/trains on the track with a deck tile either side. Segments
// are hitched to each other like ordinary wagons, so a car follows the track
// round curves. Everything standing on a segment's three tiles (people,
// furniture, crates) rides along when the segment moves.
//
// Deck tiles and the car's walls, windows and doors are train_part objects.
// They are never saved: a segment rebuilds them from its car kind, its place
// in the car and its saved door state (open_doors).

#define TRAIN_CAR_LENGTH 4 // the four-wheel stock and the heavy locomotives
#define TRAIN_LONG_CAR_LENGTH 8 // bogie stock
#define TRAIN_LEFT -1
#define TRAIN_RIGHT 1

// The load of every platform segment in the train taking the current step,
// planned before any of them moves so that a tight curve, where one car's
// new tiles are another's old ones, never hands cargo from car to car.
// segment -> list(atom -> slot 1..3).
var/global/list/train_platform_plan = list()
var/global/train_platform_plan_time = -1

/proc/train_platform_reset_plan()
	train_platform_plan = list()
	train_platform_plan_time = world.time
	train_step_viewers = null

// A step moves every part and load of the train, hundreds of objects for a
// long one. Line of sight only has to hear about those within reach of a
// viewer, so each step lists the viewers on the level once, and a section out
// of all their reach moves its parts and loads without telling anyone.
// train_step_viewers: list(x, y, reach x, reach y) per viewer on train_step_viewers_z.
var/global/list/train_step_viewers = null
var/global/train_step_viewers_z = 0
var/global/train_step_plain = FALSE

// The reach of los_invalidate() (viewport plus 6), and 3 more: parts and
// loads sit beside their section, and riders move with the train.
#define TRAIN_VIEWER_MARGIN 9

/proc/train_step_survey(z)
	train_step_viewers = list()
	train_step_viewers_z = z
	// A save in progress checks every move (persistence_movement_allowed).
	train_step_plain = !persistence_save_active()
	if (!train_step_plain || !CIV13_GEOMETRIC_LOS_CORE || !los_active_contexts)
		return
	for (var/datum/los_context/V in los_active_contexts)
		if (!V.owner || !V.body)
			continue
		var/turf/B = get_turf(V.body)
		if (!B || B.z != z)
			continue
		var/list/radii = V.viewport_radii()
		if (!radii)
			// No viewport to cull by: every move is this viewer's business.
			train_step_plain = FALSE
			return
		train_step_viewers += list(list(B.x, B.y, radii[1] + TRAIN_VIEWER_MARGIN, radii[2] + TRAIN_VIEWER_MARGIN))

#undef TRAIN_VIEWER_MARGIN

// TRUE when what stands around T moves out of every viewer's reach this step.
/proc/train_tile_unwatched(turf/T)
	if (!T)
		return FALSE
	if (isnull(train_step_viewers) || train_step_viewers_z != T.z)
		train_step_survey(T.z)
	if (!train_step_plain)
		return FALSE
	for (var/list/V in train_step_viewers)
		if (abs(T.x - V[1]) <= V[3] && abs(T.y - V[2]) <= V[4])
			return FALSE
	return TRUE

// One step of a train part or a load with its section. plain: the section is
// unwatched, so the move is the bare change of place persistence_set_loc()
// makes, without its line-of-sight calls, which reach nobody.
/atom/movable/proc/train_shift(turf/dest, plain)
	if (!plain || !(istype(src, /obj/structure) || istype(src, /obj/item)))
		return persistence_set_loc(dest)
	var/atom/origin = loc
	loc = dest
	paper_authoring_notify(src, "relocated")
	item_pile_moved(src, origin, dest)
	return TRUE

/obj/structure/train_part/train_shift(turf/dest, plain)
	if (!plain)
		return persistence_set_loc(dest)
	loc = dest
	return TRUE

/obj/structure/trains/train_shift(turf/dest, plain)
	if (!plain)
		return persistence_set_loc(dest)
	loc = dest
	return TRUE

/proc/train_platform_plan_from(obj/structure/trains/platform/first)
	var/list/claimed = list()
	var/obj/structure/trains/car = first
	var/list/seen = list()
	while (istype(car, /obj/structure/trains/platform) && !(car in seen))
		seen += car
		var/list/cargo = list()
		var/list/tiles = train_platform_tiles(car.loc, car.dir)
		for (var/i in list(2, 1, 3))
			var/turf/T = tiles[i]
			if (!T)
				continue
			// A side tile that is another wagon's centre belongs to that wagon.
			if (i != 2 && train_centre_of_other(T, car))
				continue
			for (var/atom/movable/AM in T)
				if (AM.loc == T && !claimed[AM] && train_platform_carries(AM))
					cargo[AM] = i
					claimed[AM] = TRUE
		train_platform_plan[car] = cargo
		car = car.connected

// The car kinds. Each segment entry lists fittings (left, centre, right) put
// down when a furnished kit is assembled, and edges: list(side, edge, style)
// where side is TRAIN_LEFT, 0 or TRAIN_RIGHT and edge is "out", "in" (side
// tiles only), "front" or "back".
/proc/train_car_layout(kind)
	var/static/list/layouts = null
	if (!layouts)
		layouts = list()
		var/list/vestibule = list(list(TRAIN_LEFT, "out", "door"), list(TRAIN_RIGHT, "out", "door"),
			list(TRAIN_LEFT, "front", "wall"), list(0, "front", "door"), list(TRAIN_RIGHT, "front", "wall"))
		var/list/back_end = list(list(TRAIN_LEFT, "back", "wall"), list(0, "back", "door"), list(TRAIN_RIGHT, "back", "wall"))
		var/list/windows = list(list(TRAIN_LEFT, "out", "window"), list(TRAIN_RIGHT, "out", "window"))
		var/list/walls = list(list(TRAIN_LEFT, "out", "wall"), list(TRAIN_RIGHT, "out", "wall"))
		var/list/compartment = list(list(TRAIN_LEFT, "in", "inner_door"), list(TRAIN_RIGHT, "in", "inner_door"),
			list(TRAIN_LEFT, "front", "partition"), list(TRAIN_RIGHT, "front", "partition"))
		var/list/rails = list(list(TRAIN_LEFT, "out", "rail"), list(TRAIN_RIGHT, "out", "rail"))
		layouts["flatbed"] = list(
			"name" = "platform car", "desc" = "An open flatbed car with a plank deck and side railings. Walk about on it, or load crates and machines.",
			"center" = "wood", "side" = "wood",
			"segments" = list(
				list("edges" = rails),
				list("edges" = list()),
				list("edges" = list()),
				list("edges" = rails)))
		layouts["coach"] = list(
			"name" = "passenger coach", "desc" = "A carriage with rows of seats either side of a carpeted aisle.",
			"center" = "carpet", "side" = "floor", "roof" = "coach",
			"segments" = list(
				list("edges" = vestibule),
				list("edges" = windows, "fit" = list(/obj/structure/bed/chair/comfy/blue, null, /obj/structure/bed/chair/comfy/blue)),
				list("edges" = windows, "fit" = list(/obj/structure/bed/chair/comfy/blue, null, /obj/structure/bed/chair/comfy/blue)),
				list("edges" = windows + back_end, "fit" = list(/obj/structure/bed/chair/comfy/blue, null, /obj/structure/bed/chair/comfy/blue))))
		layouts["sleeper"] = list(
			"name" = "sleeper car", "desc" = "A carriage of private sleeping compartments, each with a bed and a sliding door.",
			"center" = "carpet", "side" = "floor", "roof" = "coach",
			"segments" = list(
				list("edges" = vestibule),
				list("edges" = windows + compartment, "fit" = list(/obj/structure/bed, null, /obj/structure/bed)),
				list("edges" = windows + compartment, "fit" = list(/obj/structure/bed, null, /obj/structure/bed)),
				list("edges" = windows + compartment + back_end, "fit" = list(/obj/structure/bed, null, /obj/structure/bed))))
		layouts["dining"] = list(
			"name" = "dining car", "desc" = "A galley kitchen with a stove, sink and fridge, and booths to eat at.",
			"center" = "floor", "side" = "floor", "roof" = "coach",
			"segments" = list(
				list("edges" = vestibule),
				list("edges" = windows, "fit" = list(/obj/structure/oven/stove, null, /obj/structure/sink)),
				list("edges" = windows, "fit" = list(/obj/structure/closet/fridge, null, /obj/structure/table/modern/table)),
				list("edges" = windows + back_end, "fit" = list(/obj/structure/bed/chair/comfy/diner_booth, null, /obj/structure/bed/chair/comfy/diner_booth))))
		layouts["storage"] = list(
			"name" = "storage car", "desc" = "A steel car of lockable-looking storage compartments either side of a walkway.",
			"center" = "steel", "side" = "steel", "roof" = "steel",
			"segments" = list(
				list("edges" = vestibule),
				list("edges" = walls + compartment, "fit" = list(/obj/structure/closet/cabinet, null, /obj/structure/closet/cabinet)),
				list("edges" = walls + compartment, "fit" = list(/obj/structure/closet/crate/large, null, /obj/structure/closet/crate/large)),
				list("edges" = walls + compartment + back_end, "fit" = list(/obj/structure/closet/cabinet, null, /obj/structure/closet/cabinet))))
		// Wartime cars (train_warfare.dm).
		var/list/armor_sides = list(list(TRAIN_LEFT, "out", "armor"), list(TRAIN_RIGHT, "out", "armor"))
		var/list/armor_doors = list(list(TRAIN_LEFT, "out", "armor_door"), list(TRAIN_RIGHT, "out", "armor_door"),
			list(TRAIN_LEFT, "front", "armor"), list(0, "front", "armor_door"), list(TRAIN_RIGHT, "front", "armor"))
		var/list/armor_back = list(list(TRAIN_LEFT, "back", "armor"), list(0, "back", "armor_door"), list(TRAIN_RIGHT, "back", "armor"))
		layouts["railgun"] = list(
			"name" = "railway gun car", "desc" = "A heavy steel car carrying a long-range gun on a turntable. Brace the car before firing.",
			"center" = "steel", "side" = "steel", "armored" = TRUE,
			"segments" = list(
				list("edges" = rails, "fit" = list(/obj/structure/railway_gun_brace, null, /obj/structure/shellrack)),
				list("edges" = rails, "fit" = list(null, /obj/structure/cannon/modern/railway, null)),
				list("edges" = rails),
				list("edges" = rails)))
		layouts["armored"] = list(
			"name" = "armored wagon", "desc" = "A steel-plated car. Its armor stops bullets from outside while the crew fires through the slits; bring your own emplaced machine guns.",
			"center" = "steel", "side" = "steel", "armored" = TRUE, "roof" = "armor",
			"segments" = list(
				list("edges" = armor_doors),
				list("edges" = armor_sides),
				list("edges" = armor_sides),
				list("edges" = armor_sides + armor_back)))
		layouts["flak"] = list(
			"name" = "flak car", "desc" = "An open armored car for autocannons that reach aircraft at cruising height. Forge the autocannons and bolt them to the deck.",
			"center" = "steel", "side" = "steel", "armored" = TRUE,
			"segments" = list(
				list("edges" = rails),
				list("edges" = rails),
				list("edges" = rails),
				list("edges" = rails, "fit" = list(/obj/structure/closet/crate, null, /obj/structure/closet/crate))))
		// Bogie stock: twice the length on two bogies.
		var/list/seats = list(/obj/structure/bed/chair/comfy/blue, null, /obj/structure/bed/chair/comfy/blue)
		var/list/back_vestibule = list(list(TRAIN_LEFT, "out", "door"), list(TRAIN_RIGHT, "out", "door")) + back_end
		layouts["bogie_coach"] = list(
			"name" = "bogie coach", "desc" = "A long carriage on two bogies: a vestibule at each end and six bays of seats either side of a carpeted aisle.",
			"center" = "carpet", "side" = "floor", "roof" = "coach",
			"segments" = list(
				list("edges" = vestibule),
				list("edges" = windows, "fit" = seats),
				list("edges" = windows, "fit" = seats),
				list("edges" = windows, "fit" = seats),
				list("edges" = windows, "fit" = seats),
				list("edges" = windows, "fit" = seats),
				list("edges" = windows, "fit" = seats),
				list("edges" = back_vestibule)))
		var/list/van_sides = list(list(TRAIN_LEFT, "out", "plank"), list(TRAIN_RIGHT, "out", "plank"))
		var/list/van_doors = list(list(TRAIN_LEFT, "out", "freight_door"), list(TRAIN_RIGHT, "out", "freight_door"))
		var/list/van_front = list(list(TRAIN_LEFT, "front", "plank"), list(0, "front", "plank"), list(TRAIN_RIGHT, "front", "plank"))
		var/list/van_back = list(list(TRAIN_LEFT, "back", "plank"), list(0, "back", "plank"), list(TRAIN_RIGHT, "back", "plank"))
		layouts["boxcar"] = list(
			"name" = "boxcar", "desc" = "A long covered goods van on two bogies. Sliding doors in the middle of each side take crates and barrels; its ends are closed.",
			"center" = "boards", "side" = "boards", "roof" = "boxcar",
			"segments" = list(
				list("edges" = van_sides + van_front),
				list("edges" = van_sides),
				list("edges" = van_sides),
				list("edges" = van_doors),
				list("edges" = van_doors),
				list("edges" = van_sides),
				list("edges" = van_sides),
				list("edges" = van_sides + van_back)))
		var/list/low_sides = list(list(TRAIN_LEFT, "out", "side"), list(TRAIN_RIGHT, "out", "side"))
		var/list/drop_doors = list(list(TRAIN_LEFT, "out", "drop_door"), list(TRAIN_RIGHT, "out", "drop_door"))
		var/list/low_front = list(list(TRAIN_LEFT, "front", "side"), list(0, "front", "side"), list(TRAIN_RIGHT, "front", "side"))
		var/list/low_back = list(list(TRAIN_LEFT, "back", "side"), list(0, "back", "side"), list(TRAIN_RIGHT, "back", "side"))
		layouts["open_wagon"] = list(
			"name" = "open wagon", "desc" = "A long open goods wagon on two bogies with plank sides all round. The drop doors in the middle of each side let down for loading. It takes ore, coal or sand in bulk.",
			"center" = "boards", "side" = "boards", "bulk" = 600,
			"segments" = list(
				list("edges" = low_sides + low_front),
				list("edges" = low_sides),
				list("edges" = low_sides),
				list("edges" = drop_doors),
				list("edges" = drop_doors),
				list("edges" = low_sides),
				list("edges" = low_sides),
				list("edges" = low_sides + low_back)))
		// The hopper (train_freight.dm): steel sides all round, a floor of
		// doors and the lever that drops the load.
		var/list/bin_sides = list(list(TRAIN_LEFT, "out", "hopper"), list(TRAIN_RIGHT, "out", "hopper"))
		var/list/bin_front = list(list(TRAIN_LEFT, "front", "hopper"), list(0, "front", "hopper"), list(TRAIN_RIGHT, "front", "hopper"))
		var/list/bin_back = list(list(TRAIN_LEFT, "back", "hopper"), list(0, "back", "hopper"), list(TRAIN_RIGHT, "back", "hopper"))
		layouts["hopper"] = list(
			"name" = "hopper wagon", "desc" = "A steel bulk wagon on two bogies. Ore, coal or sand is tipped in over its sides, and its door lever drops the whole load through the floor.",
			"center" = "hopper", "side" = "hopper", "bulk" = 800, "hopper" = TRUE,
			"segments" = list(
				list("edges" = bin_sides + bin_front, "fit" = list(/obj/structure/train_hopper_lever, null, null)),
				list("edges" = bin_sides),
				list("edges" = bin_sides),
				list("edges" = bin_sides),
				list("edges" = bin_sides),
				list("edges" = bin_sides + bin_back)))
		// Special stock (train_stock.dm). The stock car: slatted sides for
		// air, straw on the floor, a sliding door in the middle of each side.
		var/list/slat_sides = list(list(TRAIN_LEFT, "out", "slat"), list(TRAIN_RIGHT, "out", "slat"))
		var/list/slat_doors = list(list(TRAIN_LEFT, "out", "slat_door"), list(TRAIN_RIGHT, "out", "slat_door"))
		var/list/slat_front = list(list(TRAIN_LEFT, "front", "slat"), list(0, "front", "slat"), list(TRAIN_RIGHT, "front", "slat"))
		var/list/slat_back = list(list(TRAIN_LEFT, "back", "slat"), list(0, "back", "slat"), list(TRAIN_RIGHT, "back", "slat"))
		layouts["stock_car"] = list(
			"name" = "stock car", "desc" = "A long livestock van on two bogies, with slatted sides for air and straw on the floor. Lead animals in through the sliding doors in the middle of each side and shut them in.",
			"center" = "straw", "side" = "straw", "roof" = "stock",
			"segments" = list(
				list("edges" = slat_sides + slat_front),
				list("edges" = slat_sides),
				list("edges" = slat_sides),
				list("edges" = slat_doors),
				list("edges" = slat_doors),
				list("edges" = slat_sides),
				list("edges" = slat_sides),
				list("edges" = slat_sides + slat_back)))
		// The ice car: an insulated body, the ice bunker at the front and cold
		// lockers down both sides.
		var/list/cold_sides = list(list(TRAIN_LEFT, "out", "cold"), list(TRAIN_RIGHT, "out", "cold"))
		var/list/cold_doors = list(list(TRAIN_LEFT, "out", "cold_door"), list(TRAIN_RIGHT, "out", "cold_door"))
		var/list/cold_front = list(list(TRAIN_LEFT, "front", "cold"), list(0, "front", "cold"), list(TRAIN_RIGHT, "front", "cold"))
		var/list/cold_back = list(list(TRAIN_LEFT, "back", "cold"), list(0, "back", "cold"), list(TRAIN_RIGHT, "back", "cold"))
		var/list/lockers = list(/obj/structure/closet/ice_house/cold_locker, null, /obj/structure/closet/ice_house/cold_locker)
		layouts["ice_car"] = list(
			"name" = "ice car", "desc" = "A long insulated van on two bogies, painted white. Pack its ice bunker with snow or cut ice and the cold lockers down both sides keep food fresh on a long run.",
			"center" = "boards", "side" = "boards", "roof" = "reefer",
			"segments" = list(
				list("edges" = cold_sides + cold_front, "fit" = list(/obj/structure/closet/ice_house/reefer, null, /obj/structure/closet/ice_house/cold_locker)),
				list("edges" = cold_sides, "fit" = lockers),
				list("edges" = cold_sides, "fit" = lockers),
				list("edges" = cold_doors),
				list("edges" = cold_doors),
				list("edges" = cold_sides, "fit" = lockers),
				list("edges" = cold_sides, "fit" = lockers),
				list("edges" = cold_sides + cold_back, "fit" = lockers)))
		// The baggage and mail van: a sorting office at the front, loading
		// doors in the middle and the baggage room behind.
		var/list/side_doors = list(list(TRAIN_LEFT, "out", "door"), list(TRAIN_RIGHT, "out", "door"))
		layouts["mail_van"] = list(
			"name" = "baggage and mail van", "desc" = "A long van for a passenger train: sorting tables and cabinets for the mail at the front, loading doors in the middle and a baggage room of crates and cabinets behind.",
			"center" = "boards", "side" = "boards", "roof" = "coach",
			"segments" = list(
				list("edges" = vestibule),
				list("edges" = windows, "fit" = list(/obj/structure/table/wood, null, /obj/structure/closet/cabinet)),
				list("edges" = windows, "fit" = list(/obj/structure/table/wood, null, /obj/structure/closet/cabinet)),
				list("edges" = side_doors),
				list("edges" = side_doors),
				list("edges" = walls, "fit" = list(/obj/structure/closet/crate/large, null, /obj/structure/closet/crate/large)),
				list("edges" = walls, "fit" = list(/obj/structure/closet/cabinet, null, /obj/structure/closet/cabinet)),
				list("edges" = walls + back_end)))
		// The long sleeper and dining cars.
		var/list/berths = list(/obj/structure/bed, null, /obj/structure/bed)
		var/list/booths = list(/obj/structure/bed/chair/comfy/diner_booth, null, /obj/structure/bed/chair/comfy/diner_booth)
		var/list/dining_tables = list(/obj/structure/table/modern/table, null, /obj/structure/table/modern/table)
		layouts["bogie_sleeper"] = list(
			"name" = "bogie sleeper car", "desc" = "A long carriage on two bogies: a vestibule at each end and twelve private sleeping compartments, each with a bed and a sliding door.",
			"center" = "carpet", "side" = "floor", "roof" = "coach",
			"segments" = list(
				list("edges" = vestibule),
				list("edges" = windows + compartment, "fit" = berths),
				list("edges" = windows + compartment, "fit" = berths),
				list("edges" = windows + compartment, "fit" = berths),
				list("edges" = windows + compartment, "fit" = berths),
				list("edges" = windows + compartment, "fit" = berths),
				list("edges" = windows + compartment, "fit" = berths),
				list("edges" = back_vestibule + list(list(TRAIN_LEFT, "front", "partition"), list(TRAIN_RIGHT, "front", "partition")))))
		layouts["bogie_dining"] = list(
			"name" = "bogie dining car", "desc" = "A long carriage on two bogies: a galley with a stove, sink and fridge, then tables and booths either side of the aisle.",
			"center" = "floor", "side" = "floor", "roof" = "coach",
			"segments" = list(
				list("edges" = vestibule),
				list("edges" = windows, "fit" = list(/obj/structure/oven/stove, null, /obj/structure/sink)),
				list("edges" = windows, "fit" = list(/obj/structure/closet/fridge, null, /obj/structure/table/modern/table)),
				list("edges" = windows, "fit" = booths),
				list("edges" = windows, "fit" = dining_tables),
				list("edges" = windows, "fit" = booths),
				list("edges" = windows, "fit" = dining_tables),
				list("edges" = back_vestibule, "fit" = booths)))
		// The crane car (train_crane.dm): a short, ballasted steel flat with
		// the rail crane on its second section and outriggers to brace it.
		layouts["crane_car"] = list(
			"name" = "crane car", "desc" = "A short, heavy steel flatcar carrying a steam rail crane. Lower its outriggers with the lever before lifting: the crane swings heavy loads on and off the cars beside it and hoists them between levels.",
			"center" = "steel", "side" = "steel", "weight" = 1,
			"segments" = list(
				list("edges" = rails, "fit" = list(/obj/structure/railway_gun_brace, null, null)),
				list("edges" = list(), "fit" = list(null, /obj/structure/workshop_machine/shear_legs/crane/steam/rail, null)),
				list("edges" = list()),
				list("edges" = rails)))
		// The tank car (train_tank.dm): an end platform with the valve, then
		// the tank itself between two running boards with handrails.
		var/list/tank_rails = list(list(TRAIN_LEFT, "out", "rail"), list(TRAIN_RIGHT, "out", "rail"))
		layouts["tank_car"] = list(
			"name" = "tank car", "desc" = "A riveted iron tank on a bogie frame, with running boards down both sides and a valve on its end platform. It carries one liquid at a time: water, oil, fuel, milk or drink.",
			"center" = "steel", "side" = "boards", "tank" = 3600,
			"segments" = list(
				list("edges" = list(), "fit" = list(/obj/structure/train_tank_valve, null, null)),
				list("edges" = tank_rails, "solid" = 1, "tank" = "f"),
				list("edges" = tank_rails, "solid" = 1, "tank" = "d"),
				list("edges" = tank_rails, "solid" = 1, "tank" = "m"),
				list("edges" = tank_rails, "solid" = 1, "tank" = "b"),
				list("edges" = list())))
		// The guard's van: an open veranda, then a cabin with the brake wheel.
		// Ballasted, so its brake holds twice the weight of an ordinary car.
		layouts["brake_van"] = list(
			"name" = "brake van", "desc" = "A heavy guard's van: a veranda at the front and a cabin with a brake wheel. Coupled at the back of a train, its guard helps the driver stop it.",
			"center" = "boards", "side" = "boards", "roof" = "boxcar", "weight" = 1,
			"segments" = list(
				list("edges" = rails),
				list("edges" = windows + list(list(TRAIN_LEFT, "front", "plank"), list(0, "front", "door"), list(TRAIN_RIGHT, "front", "plank"))),
				list("edges" = van_sides, "fit" = list(/obj/structure/train_brake_wheel, null, /obj/structure/bed/chair/comfy/blue)),
				list("edges" = windows + list(list(TRAIN_LEFT, "back", "plank"), list(0, "back", "door"), list(TRAIN_RIGHT, "back", "plank")))))
		layouts["long_flatbed"] = list(
			"name" = "bogie flatcar", "desc" = "A long open flatcar on two bogies, for machines, vehicles and long loads.",
			"center" = "wood", "side" = "wood",
			"segments" = list(
				list("edges" = rails),
				list("edges" = list()),
				list("edges" = list()),
				list("edges" = list()),
				list("edges" = list()),
				list("edges" = list()),
				list("edges" = list()),
				list("edges" = rails)))
		train_locomotive_layouts(layouts)
	return layouts[kind]

// How many tiles long a car of this kind is.
/proc/train_car_length(kind)
	var/list/L = train_car_layout(kind)
	if (!L)
		return TRAIN_CAR_LENGTH
	var/list/segs = L["segments"]
	return segs.len

// The three tiles of a segment at T facing heading: left, centre, right.
/proc/train_platform_tiles(turf/T, heading)
	if (!T)
		return list(null, null, null)
	return list(get_step(T, turn(heading, 90)), T, get_step(T, turn(heading, -90)))

/proc/train_centre_of_other(turf/T, obj/structure/trains/self)
	for (var/obj/structure/trains/TR in T)
		if (TR != self)
			return TRUE
	return FALSE

// What a moving deck carries along: people and objects standing on it, but not
// track, cables, flora, floor covers or the train's own parts.
/proc/train_platform_carries(atom/movable/AM)
	if (!AM || QDELETED(AM))
		return FALSE
	if (isliving(AM))
		return TRUE
	if (!isobj(AM))
		return FALSE
	if (istype(AM, /obj/structure/trains) || istype(AM, /obj/structure/train_part) || istype(AM, /obj/effect))
		return FALSE
	if (istype(AM, /obj/structure/rails) || istype(AM, /obj/structure/rail_bed) || istype(AM, /obj/structure/cable) || istype(AM, /obj/covers))
		return FALSE
	if (istype(AM, /obj/structure/wild) || istype(AM, /obj/structure/sign) || istype(AM, /obj/structure/lamp))
		return FALSE
	if (train_track_fixture(AM))
		return FALSE
	return TRUE

// What is built into the line or stands beside it stays where it is when a
// deck passes over or along it: pits and boards between the rails, posts,
// gates, levers and the yard's coal, sand and water.
/proc/train_track_fixture(atom/movable/AM)
	if (istype(AM, /obj/structure/rail_ash_pit) || istype(AM, /obj/structure/rail_drop_pit) || istype(AM, /obj/structure/train_crossing_boards))
		return TRUE
	if (istype(AM, /obj/structure/train_lineside) || istype(AM, /obj/structure/train_buffer_stop) || istype(AM, /obj/structure/train_lever))
		return TRUE
	if (istype(AM, /obj/structure/train_lever_frame) || istype(AM, /obj/structure/train_token_instrument) || istype(AM, /obj/structure/train_turntable))
		return TRUE
	if (istype(AM, /obj/structure/rail_depot) || istype(AM, /obj/structure/rail_water))
		return TRUE
	return FALSE

/////////////////////////////////////////////////////////////////////////////
// Segments

/obj/structure/trains/platform
	name = "platform car"
	desc = "A walkable rail car."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "deck_center_wood"
	density = FALSE
	layer = 2.6
	health = 1500
	var/car_kind = "flatbed"
	var/seg_index = 1
	var/open_doors = 0 // bit per edge index (1-based) of this segment's layout
	var/braced = FALSE // railway gun car outriggers down (train_warfare.dm)
	var/wrecked = FALSE // knocked off the track by explosions until welded back
	var/tmp/last_moved = -1000
	var/tmp/list/deck_parts = null
	train_weight = 0.5 // per segment, so a four-tile car weighs 2

// A deck's weight counts the people and furniture on its three tiles.
/obj/structure/trains/platform/car_load_weight()
	var/list/L = layout()
	var/w = ((L && L["weight"]) ? L["weight"] : train_weight) + bulk_weight() + tank_weight()
	for (var/turf/T in train_platform_tiles(loc, dir))
		for (var/atom/movable/AM in T)
			if (isliving(AM))
				w += 0.1
			else if (istype(AM, /obj/structure) && !istype(AM, /obj/structure/rails) && !istype(AM, /obj/structure/trains) && !istype(AM, /obj/structure/train_part))
				w += 0.2
	return w

/obj/structure/trains/platform/on_runtime_spawn()
	..()
	if (!car_id)
		car_id = "[rand(100000, 999999)]-[rand(100000, 999999)]"
	apply_layout()

/obj/structure/trains/platform/after_load()
	..()
	apply_layout()

/obj/structure/trains/platform/Destroy()
	clear_parts()
	for (var/obj/structure/trains/TR in range(2, src))
		if (TR.connected == src)
			TR.connected = null
	connected = null
	return ..()

/obj/structure/trains/platform/proc/layout()
	return train_car_layout(car_kind)

/obj/structure/trains/platform/proc/car_length()
	return train_car_length(car_kind)

/obj/structure/trains/platform/proc/segment_layout()
	var/list/L = layout()
	if (!L)
		return null
	var/list/segs = L["segments"]
	return segs[clamp(seg_index, 1, segs.len)]

/obj/structure/trains/platform/proc/clear_parts()
	for (var/obj/structure/train_part/P in deck_parts)
		P.segment = null
		qdel(P)
	deck_parts = null

/obj/structure/trains/platform/proc/apply_layout()
	var/list/L = layout()
	if (!L)
		return
	name = wrecked ? "wrecked [L["name"]]" : L["name"]
	desc = L["desc"]
	var/body = L["body"]
	var/solid = segment_layout()["solid"] // a locomotive's body or a tank car's tank
	icon_state = body ? "loco_[body]_[seg_index]c" : "deck_center_[L["center"]]"
	density = solid >= 1
	clear_parts()
	update_car_overlays()
	// Stored in a rail warehouse (rail_warehouse.dm): no deck until it rolls out.
	if (!isturf(loc))
		return
	deck_parts = list()
	make_roof_images()
	var/end_row = car_end_row()
	for (var/side in list(TRAIN_LEFT, TRAIN_RIGHT))
		var/obj/structure/train_part/deck/D
		if (body)
			D = new /obj/structure/train_part/deck/body(null)
			D.setup(src, side, "out", "loco_[body]_[seg_index][side == TRAIN_LEFT ? "l" : "r"]")
			D.density = solid >= 2
		else
			D = new(null)
			D.setup(src, side, "out", "deck_side_[L["side"]]")
		if (end_row)
			D.overlays += "end_[end_row][side == TRAIN_LEFT ? "l" : "r"]"
		deck_parts += D
	var/list/edges = segment_layout()["edges"]
	for (var/i in 1 to edges.len)
		var/list/E = edges[i]
		var/obj/structure/train_part/edge/G = new(null)
		G.edge_index = i
		G.setup(src, E[1], E[2], E[3])
		G.set_open(open_doors & (1 << (i - 1)))
		deck_parts += G
	hang_roof_images()
	place_parts(loc, dir)
	update_couplers()

// "f" on the car's front segment, "b" on its last one: where the headstock,
// buffers and coupling are drawn.
/obj/structure/trains/platform/proc/car_end_row()
	var/list/L = layout()
	if (L && L["body"])
		return null // a locomotive's buffer beams are part of its body art
	if (seg_index == 1)
		return "f"
	if (seg_index == car_length())
		return "b"
	return null

// The segment's own overlays. The headstock states turn with the segment;
// outriggers are only down while the car is braced and cannot move.
/obj/structure/trains/platform/proc/update_car_overlays()
	overlays.Cut()
	if (wrecked)
		overlays += image(icon, "wreck", layer = layer + 0.01)
	else if (derailed)
		overlays += image(icon, "derailed", layer = layer + 0.01)
	if (!isturf(loc))
		return
	// A bulk load shows as a heap on every section (train_freight.dm).
	var/image/heap = bulk_overlay()
	if (heap)
		overlays += heap
	// A tank car's tank stands over its middle sections (train_tank.dm).
	var/image/shell = tank_overlay()
	if (shell)
		overlays += shell
	var/end_row = car_end_row()
	if (!end_row)
		return
	overlays += "end_[end_row]c"
	if (braced)
		for (var/out in list(turn(dir, 90), turn(dir, -90)))
			var/image/leg = image(icon, "outrigger", dir = out, layer = layer + 0.01)
			leg.pixel_x = 2 * world.icon_size * ((out == EAST) - (out == WEST))
			leg.pixel_y = 2 * world.icon_size * ((out == NORTH) - (out == SOUTH))
			overlays += leg

/obj/structure/trains/platform/proc/place_parts(turf/T, heading, plain = FALSE)
	var/list/tiles = train_platform_tiles(T, heading)
	for (var/image/R in roof_images)
		R.dir = heading
	for (var/obj/structure/train_part/P in deck_parts)
		var/turf/where = tiles[P.side + 2]
		if (!where)
			continue
		P.dir = P.facing(heading)
		if (P.loc != where)
			P.train_shift(where, plain)

// Spawns the kit's fittings on this segment's tiles.
/obj/structure/trains/platform/proc/furnish()
	var/list/fit = segment_layout()["fit"]
	if (!fit)
		return
	var/list/tiles = train_platform_tiles(loc, dir)
	for (var/i in 1 to 3)
		var/fit_type = fit[i]
		if (!fit_type || !tiles[i])
			continue
		var/atom/movable/F = new fit_type(tiles[i])
		if (istype(F, /obj/structure/bed/chair) || istype(F, /obj/structure/workshop_machine))
			F.set_dir(dir) // seats and the rail crane face the way the car does
		else
			F.dir = (i == 1) ? turn(dir, -90) : turn(dir, 90)

/obj/structure/trains/platform/proc/heading_for(turf/newloc, fdir)
	for (var/obj/structure/trains/TR in orange(1, newloc))
		if (TR.connected == src && TR.loc != newloc)
			var/d = get_dir(newloc, TR.loc)
			if (d in cardinal)
				return d
	return fdir

// Segments are moved by the wagon ahead and never by walking into a tile, so
// the move skips turf entry checks: the car's own walls and doors would refuse
// it. train_consist_obstacle() has already checked the way is clear.
/obj/structure/trains/platform/Move(var/turf/newloc, var/fdir = null)
	if (moving_train || !isturf(loc) || !isturf(newloc))
		return FALSE
	if (!fdir)
		fdir = train_heading()
	if (train_platform_plan_time != world.time)
		train_platform_reset_plan()
	check_connections()
	var/turf/oldloc = loc
	// way: where the car heads; newdir: where it faces, the other way for a
	// car coupled in back to front. Sides and deck slots go by its facing.
	var/way = heading_for(newloc, fdir)
	var/newdir = reversed ? OPPOSITE_DIR(way) : way
	var/list/old_tiles = train_platform_tiles(oldloc, dir)
	var/list/new_tiles = train_platform_tiles(newloc, newdir)
	// Carry the deck's load before followers move into these tiles.
	if (!(src in train_platform_plan))
		train_platform_plan_from(src)
	var/list/cargo = train_platform_plan[src]
	train_platform_plan -= src
	moving_train = TRUE
	var/plain = train_tile_unwatched(newloc)
	if (!train_shift(newloc, plain))
		moving_train = FALSE
		return FALSE
	last_moved = world.time
	var/turning = 0
	if (newdir == turn(dir, 90))
		turning = 90
	else if (newdir == turn(dir, -90))
		turning = -90
	dir = newdir
	for (var/atom/movable/AM in cargo)
		if (AM.loc == old_tiles[cargo[AM]] && new_tiles[cargo[AM]] && AM.train_shift(new_tiles[cargo[AM]], plain))
			// Furniture turns with the car round a curve.
			if (turning && isobj(AM))
				AM.set_dir(turn(AM.dir, turning))
			if (ismob(AM))
				var/mob/M = AM
				if (M.client)
					M.update_vision_cone()
	// On the inside of a curve a load can end up on the rail tile; a locomotive's
	// solid hood puts it back on the walkway beside it.
	if (density)
		for (var/atom/movable/AM in cargo)
			if (cargo[AM] == 2 && AM.loc == newloc)
				var/turf/aside = new_tiles[3] || new_tiles[1]
				if (aside)
					AM.train_shift(aside, plain)
	place_parts(newloc, newdir, plain)
	train_deck_clearance(cargo, OPPOSITE_DIR(way))
	if (connected && !train_solo_move)
		connected.Move(oldloc, way)
	moving_train = FALSE
	return TRUE

// Platform cars couple at their ends only; the segments inside a car stay hitched.
/obj/structure/trains/platform/hitch()
	set category = null
	set name = "Hitch"
	set desc = "Hitch or unhitch to the wagon ahead or behind."
	set src in view(1)
	if (!istype(usr, /mob/living/human))
		return
	// Each end section couples to what stands beyond it. The car's own front
	// is the rear of its train's order when the car is coupled in back to front.
	if (seg_index != 1 && seg_index != car_length())
		to_chat(usr, "Cars are coupled at their ends. Use the front or the rear of \the [src].")
		return FALSE
	if (train_under_power())
		to_chat(usr, SPAN_WARNING("The couplings are pulled tight. Shut the throttle first."))
		return FALSE
	if (couple_end((seg_index == 1) ? !reversed : reversed, usr))
		return TRUE
	to_chat(usr, "There is no wagon to hitch \the [src] to.")
	return FALSE

/obj/structure/trains/platform/examine(mob/user)
	..()
	to_chat(user, "This is section [seg_index] of [car_length()]. A crowbar takes an empty, uncoupled car apart into a kit.")
	if (wrecked)
		to_chat(user, SPAN_WARNING("It is off the rails. Weld it back together before the train can move."))
	else if (derailed && !unit_engine())
		to_chat(user, SPAN_WARNING("It is off the rails. Lift it back on with a rerailing jack before the train can move."))
	else if (health < initial(health))
		to_chat(user, "It is damaged ([round(100 * health / initial(health))]%). A welding tool repairs it.")
	if (braced)
		to_chat(user, "Its outriggers are down: the car is braced and cannot move.")
	var/tender = tender_text()
	if (tender)
		to_chat(user, tender)
	var/bulk = bulk_text()
	if (bulk)
		to_chat(user, bulk)
	var/tank = tank_text()
	if (tank)
		to_chat(user, tank)

/obj/structure/trains/platform/attackby(obj/item/W as obj, mob/user as mob)
	if (tender_load(W, user))
		return
	if (bulk_use(W, user))
		return
	if (tank_use(W, user))
		return
	var/obj/structure/trains/locomotive/E = car_engine()
	if (E && (E.takes_fuel(W) || istype(W, /obj/item/stack/ore/glass) || (is_tool(W, TOOL_WELDER) && !wrecked && health >= initial(health))))
		return E.attackby(W, user)
	if (is_tool(W, TOOL_CROWBAR))
		dismantle_car(user)
		return
	if (is_tool(W, TOOL_WELDER))
		weld_repair(user)
		return
	return ..()

/obj/structure/trains/platform/proc/car_segments()
	var/list/segs = list()
	for (var/obj/structure/trains/platform/P in range(car_length() + 1, src))
		if (P.car_id == car_id && P.car_kind == car_kind)
			segs += P
	return segs

/obj/structure/trains/platform/proc/dismantle_problem()
	var/list/L = layout()
	if (L && L["body"])
		return "It is built in one piece and cannot be packed into a kit."
	var/list/segs = car_segments()
	var/obj/structure/trains/platform/front = null
	var/obj/structure/trains/platform/back = null
	for (var/obj/structure/trains/platform/P in segs)
		if (P.automovement)
			return "The car is moving."
		if (P.seg_index == 1)
			front = P
		if (P.seg_index == car_length())
			back = P
	if (segs.len != car_length() || !front || !back)
		return "The car is not whole."
	if (front.bulk_amount > 0)
		return "Unload the car first."
	if (front.tank_amount > 0)
		return "Drain the tank first."
	for (var/obj/structure/trains/platform/P in list(front, back))
		var/ahead = (P == front) ? !reversed : reversed
		if (ahead ? P.lead_car() : P.connected)
			return ahead ? "Uncouple the car from the one ahead first." : "Uncouple the car behind first."
	for (var/obj/structure/trains/platform/P in segs)
		for (var/turf/T in train_platform_tiles(P.loc, P.dir))
			for (var/atom/movable/AM in T)
				if (AM.loc == T && train_platform_carries(AM))
					return "Clear everything off the deck first, including \the [AM]."
	return null

/obj/structure/trains/platform/proc/dismantle_car(mob/user)
	var/problem = dismantle_problem()
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	user.visible_message("[user] starts taking \the [src] apart...", "You start taking \the [src] apart...")
	if (!do_after(user, 80, src))
		return FALSE
	problem = dismantle_problem()
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return FALSE
	var/obj/structure/train_car_kit/K = pack_car()
	user.visible_message("[user] takes the car apart into \a [K].", "You take the car apart into \a [K].")
	return K

// Packs the whole car back into an unfurnished kit at its front tile.
/obj/structure/trains/platform/proc/pack_car()
	var/turf/T = null
	for (var/obj/structure/trains/platform/P in car_segments())
		if (P.seg_index == 1)
			T = P.loc
	var/obj/structure/train_car_kit/K = new(T)
	K.set_kind(car_kind)
	K.furnished = FALSE
	for (var/obj/structure/trains/platform/P in car_segments())
		qdel(P)
	return K

/////////////////////////////////////////////////////////////////////////////
// Deck tiles, walls, windows and doors

/obj/structure/train_part
	name = "platform car"
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	flammable = FALSE
	crushable = FALSE
	should_save = FALSE
	layer = 2.6
	var/obj/structure/trains/platform/segment = null
	var/side = 0
	var/edge_kind = "out"

/obj/structure/train_part/Destroy()
	if (segment && segment.deck_parts)
		segment.deck_parts -= src
	segment = null
	return ..()

/obj/structure/train_part/ex_act(severity)
	return

/obj/structure/train_part/proc/setup(obj/structure/trains/platform/S, new_side, new_edge, state)
	segment = S
	side = new_side
	edge_kind = new_edge
	name = S.name
	desc = S.desc
	icon_state = state

// The direction of the tile edge this part sits on, for a car facing heading.
/obj/structure/train_part/proc/facing(heading)
	switch (edge_kind)
		if ("front")
			return heading
		if ("back")
			return OPPOSITE_DIR(heading)
		if ("in")
			return side == TRAIN_LEFT ? turn(heading, -90) : turn(heading, 90)
	return side == TRAIN_LEFT ? turn(heading, 90) : turn(heading, -90)

/obj/structure/train_part/examine(mob/user)
	if (segment)
		return segment.examine(user)
	return ..()

/obj/structure/train_part/attackby(obj/item/W as obj, mob/user as mob)
	if (segment)
		return segment.attackby(W, user)
	return ..()

/obj/structure/train_part/deck
	layer = 2.6

// A wall, window, railing or door along one edge of a deck tile.
/obj/structure/train_part/edge
	layer = 3.2
	flags = ON_BORDER
	density = TRUE
	throwpass = TRUE
	var/style = "wall"
	var/edge_index = 0
	var/open = FALSE

/obj/structure/train_part/edge/setup(obj/structure/trains/platform/S, new_side, new_edge, state)
	..(S, new_side, new_edge, "edge_[state]")
	style = state
	switch (style)
		if ("window")
			name = "[S.name] window"
		if ("door", "inner_door", "armor_door", "freight_door", "drop_door", "slat_door", "cold_door")
			name = "[S.name] door"
		if ("plank", "side", "hopper", "slat", "cold")
			name = "[S.name] side"
		if ("armor")
			name = "[S.name] armor plate"
		if ("rail")
			name = "[S.name] railing"
		if ("cab_end")
			// The windscreen of a rear cab: it is part of the body's art.
			name = "[S.name] windscreen"
			icon_state = null
			mouse_opacity = 0
		else
			name = "[S.name] wall"

/obj/structure/train_part/edge/proc/is_door()
	return style == "door" || style == "inner_door" || style == "armor_door" || style == "freight_door" || style == "drop_door" || style == "slat_door" || style == "cold_door"

/obj/structure/train_part/edge/proc/is_armor()
	return style == "armor" || style == "armor_door"

// Armor stops projectiles fired from outside the car; the crew shoots out.
/obj/structure/train_part/edge/proc/stops_projectile(obj/item/projectile/P)
	if (!is_armor() || !P || !P.starting)
		return FALSE
	return (get_dir(loc, P.starting) & dir) != 0

/obj/structure/train_part/edge/proc/set_open(state)
	if (!is_door())
		return
	open = !!state
	density = !open
	icon_state = open ? "edge_[style]_open" : "edge_[style]"

/obj/structure/train_part/edge/attack_hand(mob/user)
	if (!is_door() || !segment || !ishuman(user))
		return ..()
	// A locked door (train_conductor.dm) opens by hand from its own tile only.
	if (is_locked())
		if (locked_against(user))
			to_chat(user, "\The [src] is locked.")
			return TRUE
		set_locked(FALSE)
	set_open(!open)
	var/bit = 1 << (edge_index - 1)
	if (open)
		segment.open_doors |= bit
	else
		segment.open_doors &= ~bit
	playsound(loc, 'sound/effects/lever.ogg', 40, TRUE)
	user.visible_message("[user] [open ? "opens" : "closes"] \the [src].", "You [open ? "open" : "close"] \the [src].")
	return TRUE

/obj/structure/train_part/edge/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (!density || !mover)
		return TRUE
	if (istype(mover, /obj/item/projectile))
		return !stops_projectile(mover)
	if (istype(mover) && mover.checkpass(PASSTABLE) && style == "rail")
		return TRUE
	return get_dir(loc, target) != dir

/obj/structure/train_part/edge/CheckExit(atom/movable/O as mob|obj, target as turf, exit_direction = null)
	if (!density || !O)
		return TRUE
	if (istype(O, /obj/item/projectile))
		return !stops_projectile(O)
	if (istype(O) && O.checkpass(PASSTABLE) && style == "rail")
		return TRUE
	return (isnull(exit_direction) ? get_dir(O.loc, target) : exit_direction) != dir

/////////////////////////////////////////////////////////////////////////////
// Clearance: a train with platform cars stops before any deck would scrape a
// wall, tree or another train. Called by process_rail_movement (trains.dm)
// for the leading wagon before it moves.

/proc/train_consist_list(obj/structure/trains/head)
	var/list/cars = list()
	var/obj/structure/trains/car = head
	while (car && !(car in cars) && cars.len < 200)
		cars += car
		car = car.connected
	return cars

/proc/train_consist_tiles(list/cars)
	var/list/tiles = list()
	for (var/obj/structure/trains/car in cars)
		if (car.wide_body())
			for (var/turf/T in train_platform_tiles(car.loc, car.dir))
				tiles[T] = TRUE
		else if (isturf(car.loc))
			tiles[car.loc] = TRUE
	return tiles

// Null when the step is clear, else the blocking atom.
// cars: the train in the order it travels, when it is not head's own chain
// (a reversing train lists its cars from the rear).
/proc/train_consist_obstacle(obj/structure/trains/head, turf/target, heading, list/cars = null)
	train_platform_reset_plan()
	if (!cars)
		cars = train_consist_list(head)
	var/has_platform = FALSE
	for (var/obj/structure/trains/car in cars)
		if (car.wide_body())
			has_platform = TRUE
			break
	var/list/ours = train_consist_tiles(cars)
	// The head's own new tile may not lie on another train's deck.
	if (target && !ours[target])
		for (var/obj/structure/train_part/P in target)
			if (!(P.segment in cars))
				return P
	if (!has_platform)
		return null
	for (var/obj/structure/trains/platform/P in cars)
		if (P.wrecked || P.braced || P.derailed)
			return P
	var/turf/next_loc = target
	var/next_dir = heading
	for (var/obj/structure/trains/car in cars)
		if (car.wide_body())
			var/list/tiles = train_platform_tiles(next_loc, next_dir)
			for (var/i in list(1, 3))
				var/turf/T = tiles[i]
				if (!T)
					return car
				if (ours[T])
					continue
				if (T.density)
					return T
				for (var/atom/movable/AM in T)
					if (istype(AM, /obj/structure/trains) || istype(AM, /obj/structure/train_part))
						return AM
					if (AM.density && !isliving(AM) && !istype(AM, /obj/structure/rails))
						return AM
		var/turf/car_loc = car.loc
		if (car_loc && next_loc && car_loc != next_loc)
			next_dir = get_dir(car_loc, next_loc)
			if (!(next_dir in cardinal))
				next_dir = car.train_heading()
		else
			next_dir = car.train_heading()
		next_loc = car_loc
	return null

/////////////////////////////////////////////////////////////////////////////
// Kits

/obj/structure/train_car_kit
	name = "platform car kit"
	desc = "The frame, wheels and deck of a rail car, packed for assembly. Set it on straight track with room for the whole car behind it, face the way the car should face, and use a hammer on it."
	icon = 'icons/obj/vehicles/train_platforms.dmi'
	icon_state = "car_kit"
	density = TRUE
	anchored = FALSE
	flammable = FALSE
	var/car_kind = "flatbed"
	var/furnished = TRUE

/obj/structure/train_car_kit/proc/set_kind(kind)
	var/list/L = train_car_layout(kind)
	if (!L)
		return
	car_kind = kind
	name = "[L["name"]] kit"

/obj/structure/train_car_kit/proc/car_length()
	return train_car_length(car_kind)

/obj/structure/train_car_kit/coach
	name = "passenger coach kit"
	car_kind = "coach"
/obj/structure/train_car_kit/sleeper
	name = "sleeper car kit"
	car_kind = "sleeper"
/obj/structure/train_car_kit/dining
	name = "dining car kit"
	car_kind = "dining"
/obj/structure/train_car_kit/storage
	name = "storage car kit"
	car_kind = "storage"
/obj/structure/train_car_kit/bogie_coach
	name = "bogie coach kit"
	car_kind = "bogie_coach"
/obj/structure/train_car_kit/boxcar
	name = "boxcar kit"
	car_kind = "boxcar"
/obj/structure/train_car_kit/open_wagon
	name = "open wagon kit"
	car_kind = "open_wagon"
/obj/structure/train_car_kit/long_flatbed
	name = "bogie flatcar kit"
	car_kind = "long_flatbed"
/obj/structure/train_car_kit/brake_van
	name = "brake van kit"
	car_kind = "brake_van"

/obj/structure/train_car_kit/examine(mob/user)
	..()
	to_chat(user, "The car is [car_length()] tiles long and three wide.")
	if (!furnished)
		to_chat(user, "Its fittings were left behind when it was taken apart.")

/obj/structure/train_car_kit/attackby(obj/item/W as obj, mob/user as mob)
	if (is_tool(W, TOOL_HAMMER))
		var/heading = user.dir
		var/problem = assembly_problem(heading)
		if (problem)
			to_chat(user, SPAN_WARNING(problem))
			return
		user.visible_message("[user] starts assembling \the [src]...", "You start assembling \the [src]...")
		if (!do_after(user, 100, src))
			return
		problem = assembly_problem(heading)
		if (problem)
			to_chat(user, SPAN_WARNING(problem))
			return
		var/obj/structure/trains/platform/front = assemble(heading)
		if (front)
			user.visible_message("[user] assembles \a [front].", "You assemble \a [front].")
		return
	return ..()

// Tiles of the car's segments from the front, when built here facing heading.
/obj/structure/train_car_kit/proc/car_turfs(heading)
	var/list/turfs = list()
	var/turf/T = get_turf(src)
	for (var/i in 1 to car_length())
		if (!T)
			return null
		turfs += T
		T = get_step(T, OPPOSITE_DIR(heading))
	return turfs

/obj/structure/train_car_kit/proc/assembly_problem(heading)
	if (!isturf(loc))
		return "Set the kit down on the track first."
	if (!(heading in cardinal))
		return "Face along the track."
	var/list/turfs = car_turfs(heading)
	if (!turfs)
		return "There is no room for the car here."
	for (var/turf/T in turfs)
		var/straight = FALSE
		for (var/obj/structure/rails/R in T)
			if (R.type == /obj/structure/rails/regular || R.type == /obj/structure/rails/regular/horizontal || R.type == /obj/structure/rails)
				if (R.dir == heading || R.dir == OPPOSITE_DIR(heading))
					straight = TRUE
		if (!straight)
			return "The car needs [car_length()] tiles of straight track running the way you face, starting under the kit."
		for (var/obj/structure/trains/TR in T)
			return "\The [TR] is in the way."
		for (var/turf/S in train_platform_tiles(T, heading))
			if (!S || S.density)
				return "The deck needs a clear tile either side of the track."
			for (var/atom/movable/AM in S)
				if (AM == src)
					continue
				if (istype(AM, /obj/structure/trains) || istype(AM, /obj/structure/train_part) || (AM.density && !isliving(AM)))
					return "\The [AM] is in the way of the deck."
	return null

/obj/structure/train_car_kit/proc/assemble(heading)
	var/list/turfs = car_turfs(heading)
	var/id = "[rand(100000, 999999)]-[rand(100000, 999999)]"
	var/obj/structure/trains/front = null
	var/obj/structure/trains/ahead = null
	var/engine_type = train_car_layout(car_kind)["engine"]
	for (var/i in 1 to car_length())
		// A locomotive kit: the engine itself is the front section.
		if (i == 1 && engine_type)
			var/obj/structure/trains/locomotive/E = new engine_type(turfs[1])
			E.dir = heading
			E.car_id = id
			E.build_body()
			front = E
			ahead = E
			continue
		var/obj/structure/trains/platform/P = new(turfs[i])
		P.dir = heading
		P.car_kind = car_kind
		P.car_id = id
		P.seg_index = i
		P.apply_layout()
		if (furnished)
			P.furnish()
		if (ahead)
			ahead.connected = P
		else
			front = P
		ahead = P
	qdel(src)
	return front
