// Standard machine parts (docs/material-roles.md, "Machine parts").
//
// One item type per part, made of any material its role accepts, the way a
// knife is one type in any metal. A part knows its role, its material name and
// whether it was cut precisely; everything else is asked of the role:
//   part_rating(P.part_role, P.part_material) -> performance, lifetime, mass
// A part holds no lists and no material datum, so a crate of gears costs
// three small values each.
//
// Routes: by hand from logs, bone, rope, leather or cloth (config/crafting,
// tools in config/craft_needs.json); forged at an anvil from the Parts kind;
// or cast at an anvil from a filled parts mould.

/obj/item/machine_part
	name = "machine part"
	desc = "A part for a machine."
	icon = 'icons/obj/machine_parts.dmi'
	icon_state = "gear"
	w_class = ITEM_SIZE_SMALL
	force = 3
	throwforce = 4
	// ROLE_* id: what this part does in a machine.
	var/part_role
	// Material name, as get_material_by_name() takes it.
	var/part_material = "iron"
	// TRUE when cut on a lathe. Rough parts are hand-carved, forged or cast.
	var/precise = FALSE
	// 0 (new) to MACHINE_PART_WORN_OUT. A machine hands its wear back when a part is pulled.
	var/wear = 0
	// The name without its material.
	var/part_noun = "machine part"
	// Poured metal can take this shape in a parts mould.
	var/castable = TRUE

#define MACHINE_PART_WORN_OUT 63

/obj/item/machine_part/New(newloc, material_name)
	..(newloc)
	if (istext(material_name) && get_material_by_name(material_name))
		part_material = material_name
	apply_part_material()

// Wood is drawn differently where the wooden part is a different object.
/obj/item/machine_part/proc/part_icon_state(material/M)
	return initial(icon_state)

/obj/item/machine_part/proc/part_material_is_wood()
	return part_material == "wood" || part_material == "woodplank" || part_material == "hardwood" || part_material == "bamboo"

/obj/item/machine_part/proc/part_name(material/M)
	return "[M.name == "wood" ? "wooden" : M.display_name] [part_noun]"

/obj/item/machine_part/proc/apply_part_material()
	var/material/M = get_material_by_name(part_material)
	if (!M)
		return
	name = "[precise ? "precise " : ""][part_name(M)]"
	color = M.icon_colour
	icon_state = part_icon_state(M)
	if (M.flammable)
		flammable = TRUE

// list(performance, lifetime, mass) against the standard part, or null when
// this material cannot do the job.
/obj/item/machine_part/proc/rating()
	return part_rating(part_role, part_material)

/obj/item/machine_part/examine(mob/user, distance = -1)
	..(user, distance)
	var/datum/part_role/R = get_part_role(part_role)
	if (!R)
		return
	var/list/rated = rating()
	if (!rated)
		to_chat(user, "<span class='warning'>It is useless as a [R.name]: [part_refusal(part_role, part_material)].</span>")
		return
	to_chat(user, "As a [R.name] it does [round(rated[1] * 100)]% of the work of a [R.standard == "woodplank" ? "plank" : R.standard] one and lasts [round(rated[2] * 100)]% as long.")
	to_chat(user, precise ? "It was cut true on a lathe." : "It is a rough part: good enough for hand-built machines.")
	if (wear >= MACHINE_PART_WORN_OUT)
		to_chat(user, "<span class='warning'>It is worn out.</span>")
	else if (wear >= MACHINE_PART_WORN_OUT * 0.5)
		to_chat(user, "<span class='warning'>It is badly worn.</span>")
	else if (wear > 0)
		to_chat(user, "It shows some wear.")

/obj/item/machine_part/gear
	name = "gear set"
	desc = "A pair of meshing wheels that pass turning from one shaft to another."
	icon_state = "gear"
	part_role = ROLE_GEAR
	part_noun = "gear set"

/obj/item/machine_part/gear/part_icon_state(material/M)
	return part_material_is_wood() ? "gear_wood" : "gear"

/obj/item/machine_part/shaft
	name = "shaft"
	desc = "A straight bar that carries turning along its length. It serves as an axle too."
	icon_state = "shaft"
	w_class = ITEM_SIZE_NORMAL
	part_role = ROLE_SHAFT
	part_noun = "shaft"

/obj/item/machine_part/shaft/part_icon_state(material/M)
	return part_material_is_wood() ? "shaft_wood" : "shaft"

/obj/item/machine_part/bearing
	name = "bearing"
	desc = "A sleeve a shaft turns in."
	icon_state = "bearing"
	part_role = ROLE_BEARING
	part_noun = "bushing"

/obj/item/machine_part/bearing/part_icon_state(material/M)
	return part_material_is_wood() ? "bearing_wood" : "bearing"

/obj/item/machine_part/bearing/part_name(material/M)
	if (part_material_is_wood())
		return "greased wooden bearing block"
	return ..()

/obj/item/machine_part/spring
	name = "spring"
	desc = "A coil that pushes back when pressed."
	icon_state = "spring"
	part_role = ROLE_SPRING
	part_noun = "spring"
	castable = FALSE

/obj/item/machine_part/belt
	name = "drive belt"
	desc = "An endless loop that carries turning from one wheel to another."
	icon_state = "belt"
	part_role = ROLE_BELT
	part_noun = "drive belt"
	castable = FALSE

// A belt of metal is a chain.
/obj/item/machine_part/belt/proc/is_chain()
	var/material/M = get_material_by_name(part_material)
	return M && M.firmness >= PART_SOFT_FIRMNESS

/obj/item/machine_part/belt/part_icon_state(material/M)
	return is_chain() ? "chain" : "belt"

/obj/item/machine_part/belt/part_name(material/M)
	return "[M.display_name] [is_chain() ? "drive chain" : "drive belt"]"

// Why this part type cannot be made of this material by this route, or null.
/proc/machine_part_refusal(part_type, material_name, cast = FALSE)
	if (!ispath(part_type, /obj/item/machine_part))
		return null
	var/obj/item/machine_part/P = part_type
	if (cast && !initial(P.castable))
		return "it cannot be cast"
	return part_refusal(initial(P.part_role), material_name)
