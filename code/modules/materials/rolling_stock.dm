// Rolling stock by material (docs/material-roles.md, "Rolling stock").
//
// The pedal bicycle is built from a frame, two wheels and a drive chain or
// belt (config/craft_needs.json). The frame may be steel or aluminium, and a
// wooden running bike with no chain comes much earlier. A bicycle stores its
// frame's material name; how fast a rider can pedal it is asked of the
// material:
//   bicycle_frame_factor(name) -> step delay against a steel frame
// The bicycle body in code/game/objects/structures/bicycle.dm is untouched;
// this file wraps it.

// A frame with no mass at all would be this much quicker than steel.
#define BICYCLE_FRAME_SHARE 0.25

// Deciseconds per tile against a steel frame: aluminium 0.85.
/proc/bicycle_frame_factor(material_name)
	var/material/M = get_material_by_name(material_name)
	var/material/steel = get_material_by_name("steel")
	if (!M || !steel || !steel.density)
		return 1
	return round(max(0.75, min(1.25, 1 - BICYCLE_FRAME_SHARE + BICYCLE_FRAME_SHARE * M.density / steel.density)), 0.05)

/obj/structure/vehicle/bicycle
	// Material name, as get_material_by_name() takes it.
	var/frame_material = "steel"

/obj/structure/vehicle/bicycle/New(newloc, material_name)
	if (istext(material_name) && get_material_by_name(material_name))
		frame_material = material_name
	..(newloc)
	apply_frame_material()

/obj/structure/vehicle/bicycle/after_load()
	. = ..()
	apply_frame_material()

// A steel bicycle keeps the name, look and speed it always had.
/obj/structure/vehicle/bicycle/proc/apply_frame_material()
	var/material/M = get_material_by_name(frame_material)
	if (!M || frame_material == initial(frame_material))
		return
	name = "[M.display_name] [initial(name)]"
	color = M.icon_colour
	pedal_fastest = initial(pedal_fastest) * bicycle_frame_factor(frame_material)
	vehicle_m_delay = pedal_fastest

// The pedal airship is cloth and wicker and has no frame to choose.
/obj/structure/vehicle/bicycle/airship/apply_frame_material()
	return

/obj/structure/vehicle/bicycle/examine(mob/user, distance)
	..(user, distance)
	if (frame_material != initial(frame_material))
		var/material/M = get_material_by_name(frame_material)
		if (M)
			to_chat(user, "Its frame is [M.display_name]: unladen it covers a tile in [pedal_fastest / 10] seconds, where steel takes [initial(pedal_fastest) / 10].")

// Two wheels in line and a seat: pushed along with the feet, no pedals and
// no chain. Slower than a bicycle and faster than walking.
/obj/structure/vehicle/bicycle/running
	name = "running bike"
	desc = "Two wooden wheels in line under a wooden beam with a seat. There are no pedals: you push it along with your feet. It is slower than a pedal bicycle. Drag yourself onto it, use the handlebars to set off, and use their secondary action to brake."
	frame_material = "wood"
	color = "#824B28"
	pedal_fastest = 2.6
	vehicle_m_delay = 2.6

#undef BICYCLE_FRAME_SHARE
