// Vehicle storage: garages put cars away and hangars put planes away. A stored
// vehicle leaves the map entirely and comes back from a record kept in the
// structure's saved field, with its fuel, damage, key binding and cargo.
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 30
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/vehicle_storage_probe/New()
	return
// Holding a key is all key_access() asks of a driver; skip body setup.
/mob/living/human/vehicle_storage_probe/New()
	return
var/storage_failures = 0
var/storage_runtime_error = FALSE
/proc/storage_check(condition, label)
	if (!condition)
		storage_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	storage_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/storage_floor(x1, y1, x2, y2)
	for (var/x = x1, x <= x2, x++)
		for (var/y = y1, y <= y2, y++)
			var/turf/T = locate(x, y, 1)
			T.ChangeTurf(/turf/floor/dirt)

/proc/storage_frames(obj/structure/S)
	. = 0
	for (var/turf/T in vehicle_storage_bay(S))
		for (var/obj/structure/vehicleparts/frame/F in T)
			.++

/proc/storage_key(obj/structure/vehicleparts/axis/A, turf/T)
	for (var/obj/item/vehicle_key/K in T)
		if (K.vehicle_id == A.keyed_vehicle_id)
			return K
	return null

/proc/storage_fuel(obj/structure/vehicleparts/axis/A)
	var/obj/structure/engine/internal/E = A.engine
	return E.fueltank.reagents.get_reagent_amount(E.fuels[1])

/proc/storage_unsaved_parts(obj/structure/vehicleparts/axis/A)
	. = 0
	for (var/obj/O in vehicle_storage_objects(A.components))
		if (!O.should_save)
			.++

/proc/storage_checks()
	if (!research_nodes.len)
		build_research_tree()
	storage_check(get_recipe_node_req("/obj/structure/vehicle_garage") == "automobiles", "Automobiles gates the garage (got [get_recipe_node_req("/obj/structure/vehicle_garage")])")
	var/mob/living/human/vehicle_storage_probe/H = new(locate(1, 1, 1))

	// A car built at the workshop, then the workshop swapped for a garage.
	storage_floor(3, 3, 6, 6)
	var/obj/structure/car_workshop/workshop = new(locate(2, 2, 1))
	workshop.stock = list("steel" = 60, "glass" = 10, "cloth" = 10, "cable" = 10, "wheels" = 4)
	var/obj/structure/vehicleparts/axis/car = workshop.complete_assembly("SMC Falcon")
	storage_check(istype(car) && car.keyed_vehicle_id, "the workshop builds a keyed car in its bay")
	if (!istype(car))
		return
	car.set_hull("aluminium")
	var/obj/item/vehicle_key/car_key = storage_key(car, get_turf(workshop))
	qdel(workshop)
	var/obj/structure/vehicle_garage/garage = new(locate(2, 2, 1))
	var/frames = storage_frames(garage)
	var/reg = car.reg_number
	var/id = car.keyed_vehicle_id
	var/obj/structure/engine/internal/E = car.engine
	E.fueltank.reagents.add_reagent(E.fuels[1], 30, safety = TRUE)
	var/obj/structure/vehicleparts/frame/damaged
	var/wall_side
	var/list/wall
	for (var/obj/structure/vehicleparts/frame/F in car.components)
		for (var/side in list("left", "right", "front", "back"))
			var/list/candidate = F.vars["w_[side]"]
			if (F.wall_weight(candidate) > 0)
				damaged = F
				wall_side = side
				wall = candidate
				break
		if (damaged)
			break
	storage_check(damaged, "the aluminium car has a representative wall")
	if (!damaged)
		return
	var/datum/wall_config/wall_condition = damaged.walls.vars[wall_side]
	wall_condition.current_health = 7
	var/car_weight = damaged.wall_weight(wall)
	var/car_wall_health = wall[5]
	var/car_wall_armor = wall[4]
	var/damaged_x = damaged.x
	var/damaged_y = damaged.y
	// Roads under a parked car are ground, not cargo.
	new /obj/covers/roads/dirt(locate(3, 3, 1))

	storage_check(!vehicle_storage_store(garage, garage.stored_vehicles, garage.capacity, FALSE, H) && garage.stored_vehicles.len == 0 && storage_frames(garage) == frames, "without the car's key the garage refuses it")
	car_key.forceMove(H)
	E.on = TRUE
	storage_check(!vehicle_storage_store(garage, garage.stored_vehicles, garage.capacity, FALSE, H) && storage_frames(garage) == frames && !storage_unsaved_parts(car), "a running car is refused and keeps every part saveable")
	E.on = FALSE
	var/obj/structure/car_workshop/hangar/hangar_probe = new(locate(20, 20, 1))
	hangar_probe.loc = garage.loc
	storage_check(!vehicle_storage_store(hangar_probe, hangar_probe.stored_vehicles, hangar_probe.storage_capacity, TRUE, H), "a hangar does not take cars")
	qdel(hangar_probe)
	storage_check(vehicle_storage_store(garage, garage.stored_vehicles, garage.capacity, FALSE, H), "the garage puts the stopped car away")
	storage_check(garage.stored_vehicles.len == 1 && storage_frames(garage) == 0 && QDELETED(car), "the stored car has left the map ([storage_frames(garage)] frames left)")
	var/obj/O = locate(/obj/structure) in locate(4, 4, 1)
	storage_check(!O, "nothing of the car is left in the bay")
	storage_check(locate(/obj/covers/roads/dirt) in locate(3, 3, 1), "the road stays")
	storage_check(("stored_vehicles" in garage.get_saved_vars()) && istext(garage.stored_vehicles[1]), "the record is a text field the world save writes")

	// A save and reload rebuilds the garage from its fields alone.
	var/list/saved = garage.stored_vehicles.Copy()
	qdel(garage)
	garage = new(locate(2, 2, 1))
	garage.stored_vehicles = saved
	garage.after_load()
	storage_check(vehicle_storage_names(garage.stored_vehicles)[1] == "[car.name] ([reg])" || findtext(vehicle_storage_names(garage.stored_vehicles)[1], reg), "the reloaded garage lists the car by its plate ([vehicle_storage_names(garage.stored_vehicles)[1]])")

	car_key.forceMove(locate(1, 2, 1))
	storage_check(!vehicle_storage_retrieve(garage, garage.stored_vehicles, 1, H) && garage.stored_vehicles.len == 1, "taking a keyed car out needs its key")
	car_key.forceMove(H)
	var/obj/item/blocker = new /obj/item/weapon/reagent_containers/glass/bucket(locate(4, 4, 1))
	storage_check(!vehicle_storage_retrieve(garage, garage.stored_vehicles, 1, H) && garage.stored_vehicles.len == 1, "a cluttered bay keeps the car inside")
	qdel(blocker)
	var/obj/structure/vehicleparts/axis/back = vehicle_storage_retrieve(garage, garage.stored_vehicles, 1, H)
	storage_check(istype(back) && !garage.stored_vehicles.len, "the car rolls back out")
	if (!istype(back))
		return
	storage_check(storage_frames(garage) == frames && back.reg_number == reg && back.keyed_vehicle_id == id, "same body, plate and key binding ([storage_frames(garage)]/[frames] frames)")
	storage_check(round(storage_fuel(back)) == 30 && !back.engine.on, "its fuel is still in the tank with the engine off ([storage_fuel(back)])")
	var/obj/structure/vehicleparts/frame/same
	for (var/obj/structure/vehicleparts/frame/F in back.components)
		if (F.x == damaged_x && F.y == damaged_y)
			same = F
	var/list/restored_wall = same ? same.vars["w_[wall_side]"] : null
	var/datum/wall_config/restored_condition = same ? same.walls.vars[wall_side] : null
	storage_check(restored_condition && restored_condition.current_health == 7, "damage is kept")
	storage_check(same && same.hull_material == "aluminium" && car_weight > 0 && same.wall_weight(restored_wall) == car_weight, "a garage round trip keeps the aluminium material and its calculated wall weight")
	storage_check(restored_wall && restored_wall[4] == car_wall_armor && restored_wall[5] == car_wall_health, "already scaled hull armour and maximum health are not scaled again")
	storage_check(!storage_unsaved_parts(back), "every rebuilt part is saved with the map again")
	storage_check(back.key_access(H) && back.wheel && back.wheel.drivingchair == back.wheel.loc && back.wheel.control && back.wheel.control.axis == back, "the key starts it and the wheel belongs to its seat")

	garage.capacity = 0
	storage_check(!vehicle_storage_store(garage, garage.stored_vehicles, garage.capacity, FALSE, H) && storage_frames(garage) == frames, "a full garage refuses another car")
	garage.capacity = 3

	// Planes go into the hangar the same way.
	storage_floor(13, 3, 16, 6)
	var/obj/structure/car_workshop/hangar/hangar = new(locate(12, 2, 1))
	// The light plane is a wooden airframe: 40 wood on top of the steel.
	hangar.stock = list("steel" = 60, "wood" = 45, "glass" = 10, "cloth" = 10, "cable" = 10, "wheels" = 4)
	var/obj/structure/vehicleparts/axis/aircraft/plane = hangar.complete_assembly("Light plane")
	storage_check(istype(plane), "the hangar builds a light plane")
	if (!istype(plane))
		return
	var/obj/item/vehicle_key/plane_key = storage_key(plane, get_turf(hangar))
	plane_key.forceMove(H)
	var/obj/structure/vehicle_garage/garage_probe = new(locate(20, 20, 1))
	garage_probe.loc = hangar.loc
	storage_check(!vehicle_storage_store(garage_probe, garage_probe.stored_vehicles, garage_probe.capacity, FALSE, H), "a garage does not take aircraft")
	qdel(garage_probe)
	var/list/options = hangar.extra_options()
	storage_check(options.len == 1 && options[options[1]] == "store", "the hangar menu offers to hangar the parked aircraft")
	plane.flight_state = AIRCRAFT_LOW
	storage_check(!vehicle_storage_store(hangar, hangar.stored_vehicles, hangar.storage_capacity, TRUE, H), "an airborne plane is not hangared")
	plane.flight_state = AIRCRAFT_GROUND
	var/plane_reg = plane.reg_number
	var/obj/structure/vehicleparts/frame/plane_frame = plane.frames()[1]
	var/plane_weight = plane_frame.airframe_weight()
	storage_check(vehicle_storage_store(hangar, hangar.stored_vehicles, hangar.storage_capacity, TRUE, H) && storage_frames(hangar) == 0 && QDELETED(plane), "the hangar puts the plane away")
	storage_hull_record_checks(hangar.stored_vehicles[1])
	options = hangar.extra_options()
	storage_check(options.len == 2 && ("stored_vehicles" in hangar.get_saved_vars()), "a hangared plane can be rolled out and is saved with the hangar")
	var/obj/structure/vehicleparts/axis/aircraft/flown = vehicle_storage_retrieve(hangar, hangar.stored_vehicles, 1, H)
	storage_check(istype(flown) && flown.frames().len == 12 && flown.wheels.len == 4 && flown.reg_number == plane_reg, "the plane rolls out whole ([istype(flown) ? flown.frames().len : 0] frames)")
	if (istype(flown))
		storage_check(istype(flown.wheel, /obj/item/vehicleparts/wheel/modular/aircraft) && flown.wheel.control && flown.wheel.control.axis == flown && !flown.airborne(), "the control column flies this plane again")
		storage_check(flown.engine.fueltank in flown.transporting, "the plane knows its tank is aboard")
		var/obj/structure/vehicleparts/frame/same_frame = flown.frames()[1]
		storage_check(same_frame.hull_material == "wood" && plane_weight < 10 && same_frame.airframe_weight() == plane_weight, "a hangar round trip keeps the wooden airframe weight")
		storage_check(!storage_unsaved_parts(flown), "every rebuilt plane part is saved with the map again")

/proc/storage_hull_record_checks(stored)
	var/list/entry = json_decode(stored)
	var/list/record = entry["record"]
	var/datum/extraction_vehicle_codec/codec = new
	var/list/air_manifest = list("v" = 1, "record" = record, "name" = "Light plane", "dir" = NORTH, "gear" = 1, "state" = AIRCRAFT_LOW, "from" = list(10, 10, 1))
	storage_check(air_crossing_plane_ok(air_manifest), "the intercontinental flight manifest accepts the wooden hull record")
	storage_floor(21, 10, 29, 17)
	var/obj/structure/vehicleparts/axis/aircraft/arrived = air_crossing_build(air_manifest, locate(25, 13, 1), null)
	var/obj/structure/vehicleparts/frame/arrived_frame
	if (istype(arrived))
		arrived_frame = arrived.frames()[1]
	storage_check(arrived_frame && arrived_frame.hull_material == "wood" && arrived_frame.airframe_weight() == 6, "the destination plane rebuild retains wooden weight")
	var/list/root = record["nodes"][1]
	var/list/frame = record["nodes"][root["parent"]]
	storage_check(frame["hull_material"] == "wood" && !("hull_material" in frame["scalars"]), "material is an optional node field outside the strict scalar map")
	frame["hull_material"] = "unsupported"
	storage_check(!codec.validate(record), "an invalid hull material is refused")
	frame["hull_material"] = "wood"
	root["hull_material"] = "wood"
	storage_check(!codec.validate(record), "material on a non-frame node is refused")
	root -= "hull_material"
	for (var/list/N in record["nodes"])
		N -= "hull_material"
	storage_check(codec.validate(record), "a legacy record omitting material still validates")
	storage_floor(21, 1, 29, 9)
	var/obj/structure/vehicleparts/axis/aircraft/legacy = codec.decode(record, locate(25, 5, 1))
	var/obj/structure/vehicleparts/frame/F
	if (istype(legacy))
		F = legacy.frames()[1]
	storage_check(F && isnull(F.hull_material) && F.airframe_weight() == 10, "older records still rebuild with the original default hull")
	var/list/scalars = frame["scalars"]
	scalars -= "resistance"
	storage_check(!codec.validate(record), "the new optional field does not loosen required scalar validation")

/proc/storage_run()
	try
		storage_checks()
	catch(var/exception/e)
		storage_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = storage_failures, "runtime_error" = storage_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/vehicle_storage_probe
		storage_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		storage_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		storage_run()
