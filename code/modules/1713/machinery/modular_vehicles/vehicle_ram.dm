// Vehicles ramming buildings.
//
// A car, truck, bus or tank driving into a wall, pillar, door or barricade
// hits it with a force from its weight and gear (structure_impact.dm). A part
// that gives way lets the vehicle through, a gear slower; a part that holds
// stops it. Either way the vehicle's leading hull plates take the blow back
// and the crew are thrown about in proportion.
//
// A vehicle several frames wide shares its force across the frames that lead,
// so a wide truck does not hit with its whole weight once per frame.

// Ram force per point of weight per gear.
#define VEHICLE_RAM_FORCE_PER_WEIGHT 1
// The hull takes one point of damage per this much force a part absorbed.
#define VEHICLE_RAM_HULL_PER_FORCE 20
// A crew member takes one point of brute per this much absorbed force.
#define VEHICLE_RAM_CREW_PER_FORCE 60
#define VEHICLE_RAM_CREW_MAX 30

// Whether T holds a building part that blocks a vehicle.
// A heavy vehicle (tank) still crushes crushable things outright, so they
// are not in its way.
/proc/vehicle_ram_blockers(turf/T, crush_crushable = FALSE)
	var/list/parts = list()
	if (!T)
		return parts
	if (T.density && is_structure_impact_part(T))
		parts += T
	for (var/obj/covers/CV in T)
		if (CV.density && is_structure_impact_part(CV))
			parts += CV
	for (var/obj/structure/O in T)
		if (crush_crushable && O.crushable)
			continue
		if (O.density && is_structure_impact_part(O) && !istype(O, /obj/structure/vehicleparts))
			parts += O
	return parts

// One check of the vehicle hits with the gear it started in, and loses at most
// one gear however many frames break through.
/obj/structure/vehicleparts/axis
	var/tmp/ram_tick = -1
	var/tmp/ram_speed = 0

/obj/structure/vehicleparts/axis/proc/ram_dir()
	return reverse ? OPPOSITE_DIR(dir) : dir

// The frames of this vehicle with no frame of their own vehicle ahead of them.
/obj/structure/vehicleparts/axis/proc/ram_leading_frames()
	var/list/lead = list()
	var/m_dir = ram_dir()
	for (var/obj/structure/vehicleparts/frame/FR in components)
		var/turf/ahead = get_step(FR.loc, m_dir)
		var/own = FALSE
		if (ahead)
			for (var/obj/structure/vehicleparts/frame/F2 in ahead)
				if (F2.axis == src)
					own = TRUE
					break
		if (!own)
			lead += FR
	return lead

// The whole ram force of this vehicle at its present gear.
/obj/structure/vehicleparts/axis/proc/ram_force()
	var/gear = ram_tick == world.time ? ram_speed : currentspeed
	if (gear <= 0)
		return 0
	return max(0, current_weight) * gear * VEHICLE_RAM_FORCE_PER_WEIGHT

// FR is about to move onto T. Hits the building parts there. Returns TRUE when
// the way is clear (nothing to hit, or everything gave way).
/obj/structure/vehicleparts/axis/proc/vehicle_ram(obj/structure/vehicleparts/frame/FR, turf/T)
	var/heavy = istype(src, /obj/structure/vehicleparts/axis/heavy)
	var/list/parts = vehicle_ram_blockers(T, heavy)
	if (!parts.len)
		return TRUE
	if (ram_tick != world.time)
		ram_tick = world.time
		ram_speed = currentspeed
	var/lanes = max(1, length(ram_leading_frames()))
	var/force = ram_force() / lanes
	var/m_dir = ram_dir()
	var/absorbed = 0
	var/first_name = "[parts[1]]"
	for (var/atom/A in parts)
		if (force <= 0)
			break
		if (QDELETED(A) || !is_structure_impact_part(A))
			continue
		var/left = A.structure_impact(force, IMPACT_CRUSH, src, m_dir)
		absorbed += force - left
		force = left
	var/clear = !length(vehicle_ram_blockers(T, heavy))
	ram_feedback(FR, absorbed)
	if (clear)
		visible_message(SPAN_DANGER("\The [src] smashes through \the [first_name]!"))
		playsound(T, 'sound/effects/grillehit.ogg', 80, TRUE, 4)
		// Breaking through costs a gear.
		if (currentspeed > 1 && currentspeed == ram_speed)
			currentspeed--
			var/spd = get_speed()
			if (spd > 0)
				vehicle_m_delay = spd
		return TRUE
	visible_message(SPAN_WARNING("\The [src] crashes into \the [first_name]!"))
	playsound(T, 'sound/effects/grillehit.ogg', 60, TRUE, 3)
	return FALSE

// The blow comes back on the leading hull plate of FR and on everyone aboard.
/obj/structure/vehicleparts/axis/proc/ram_feedback(obj/structure/vehicleparts/frame/FR, absorbed)
	if (absorbed <= 0)
		return
	if (FR && !QDELETED(FR))
		var/list/plate = reverse ? FR.w_back : FR.w_front
		if (plate && plate.len >= 5)
			var/hull = round(absorbed / VEHICLE_RAM_HULL_PER_FORCE) - round(plate[4] / 10)
			if (hull > 0)
				plate[5] -= hull
				FR.try_destroy()
	var/hurt = min(VEHICLE_RAM_CREW_MAX, round(absorbed / VEHICLE_RAM_CREW_PER_FORCE))
	if (hurt <= 0)
		return
	for (var/obj/structure/vehicleparts/frame/F in components)
		for (var/mob/living/human/H in F.loc)
			H.adjustBruteLoss(hurt)
			if (hurt >= 10)
				H.Weaken(2)
			to_chat(H, SPAN_DANGER("The crash throws you about!"))

#undef VEHICLE_RAM_FORCE_PER_WEIGHT
#undef VEHICLE_RAM_HULL_PER_FORCE
#undef VEHICLE_RAM_CREW_PER_FORCE
#undef VEHICLE_RAM_CREW_MAX
