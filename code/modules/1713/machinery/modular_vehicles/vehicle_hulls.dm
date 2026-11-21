// Vehicle hull materials (docs/aluminium.md "Hulls"): what a works vehicle's
// or a plane's body is made of. Steel is the standard. A lighter hull weighs
// less in the load (vehicle_load.dm wall_weight(), aircraft_load.dm
// airframe_weight()), so it drives, rolls and climbs faster, but its walls
// stop less and break sooner.
//
// The hull is set once, when the press assembles the vehicle, by scaling the
// frames' wall armour and health; the frame keeps its material so the load
// can weigh it against the same body in steel.
// ============================================================

/obj/structure/vehicleparts/frame
	var/hull_material = null // null for steel, else "aluminium" or "wood"

// list(weight, armour, health) against steel for a hull material, or null
// for steel and anything unknown.
/proc/vehicle_hull_stats(hull)
	switch (hull)
		if ("aluminium")
			return list(0.55, 0.6, 0.85)
		if ("wood")
			return list(0.6, 0.3, 0.6)
	return null

// Rebuilds this frame in hull. Walls are scaled from their steel values.
/obj/structure/vehicleparts/frame/proc/set_hull(hull)
	var/list/stats = vehicle_hull_stats(hull)
	if (!stats || hull_material)
		return FALSE
	hull_material = hull
	for (var/list/wall in list(w_front, w_back, w_left, w_right))
		if (!islist(wall) || wall.len < 5 || !wall[1] || wall[1] == "none")
			continue
		wall[4] = round(wall[4] * stats[2])
		wall[5] = max(1, round(wall[5] * stats[3]))
	return TRUE

// Every frame of A in hull.
/obj/structure/vehicleparts/axis/proc/set_hull(hull)
	if (!vehicle_hull_stats(hull))
		return FALSE
	for (var/obj/structure/vehicleparts/frame/F in components)
		F.set_hull(hull)
	return TRUE

/obj/structure/vehicleparts/frame/airframe_weight()
	var/list/stats = vehicle_hull_stats(hull_material)
	return stats ? ..() * stats[1] : ..()

/obj/structure/vehicleparts/frame/examine(mob/user)
	..()
	if (hull_material && (user in range(1, src)))
		to_chat(user, "<span class='notice'>Its hull is [hull_material].</span>")
	var/panels = composite_examine_text()
	if (panels && (user in range(1, src)))
		to_chat(user, "<span class='notice'>[panels]</span>")

// ---- Works vehicles in aluminium ----

// The hull a works model may be built in beyond steel: every works vehicle
// can be aluminium once Aluminium Refining is known. A spec "hull" is the
// model's only hull (the tracked carrier is aluminium).
/obj/structure/car_workshop/proc/hull_choices(model, mob/living/human/H)
	var/list/spec = works_spec(model)
	if (!spec)
		return list("steel")
	if (spec["hull"])
		return list(spec["hull"])
	if (!H || research_node_known(H, "aluminium_refining"))
		return list("steel", "aluminium")
	return list("steel")

// A works model's cost in hull: the frame and body steel becomes four
// fifths as much aluminium, in a multiple of 4 (one quarter per piece); the
// engine and gun stay steel.
/proc/works_hull_cost(list/cost, gun, hull)
	if (hull != "aluminium" || cost["aluminium"])
		return cost
	var/per = round(((cost["steel"] || 0) - gun) / 5)
	if (per <= 0)
		return cost
	cost["aluminium"] = 4 * max(1, round(per * 0.8))
	cost["steel"] -= 4 * per
	return cost
