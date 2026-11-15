// Holding tanks by material (docs/material-roles.md, "Tanks").
//
// One tank type in any metal, like the pipe. A tank stores its material name
// and nothing else; what the material means is asked of the material:
//   pipe_material_toxic(name) -> it poisons what it holds (lead)
//   vessel_acid_eats(name)    -> acid eats it (iron)
// A steel tank is exactly the tank it always was. The tank bodies in
// code/modules/1713/factory_pipes.dm are untouched; this file wraps them.

// Acid eats a tank whose material corrodes faster than this. Steel is 40, iron 60.
#define VESSEL_ACID_CORROSION 50
// Units of each acid delivery an eaten tank loses.
#define VESSEL_ACID_LOSS 5
// Chance, each delivery, that a toxic tank adds one unit of lead.
#define VESSEL_TOXIN_CHANCE 2

/proc/vessel_acid_eats(material_name)
	var/material/M = get_material_by_name(material_name)
	return M ? M.corrosion > VESSEL_ACID_CORROSION : FALSE

/proc/reagent_is_acid(id)
	return istype(chemical_reagents_list[id], /datum/reagent/acid)

/obj/structure/fluid_tank
	// Material name, as get_material_by_name() takes it.
	var/tank_material = "steel"

/obj/structure/fluid_tank/New(newloc, material_name)
	if (istext(material_name) && get_material_by_name(material_name))
		tank_material = material_name
	..(newloc)
	apply_tank_material()

/obj/structure/fluid_tank/after_load()
	. = ..()
	apply_tank_material()

// A steel tank keeps the name and look it always had.
/obj/structure/fluid_tank/proc/apply_tank_material()
	var/material/M = get_material_by_name(tank_material)
	if (!M || tank_material == "steel")
		return
	name = "[M.display_name] tank"
	desc = "A fixed [M.display_name] tank for a pipe network. It fills from sources and feeds machines that want what it holds. Hold a container and use Set Tank Filter to keep it to one reagent. Its contents are held inert."
	icon = 'icons/obj/fluid_tanks.dmi'
	icon_state = "tank"
	color = M.icon_colour

// The cistern is wood and keeps its own look.
/obj/structure/fluid_tank/cistern
	tank_material = "wood"

/obj/structure/fluid_tank/cistern/apply_tank_material()
	return

/obj/structure/fluid_tank/fluid_receive(id, amount, data)
	. = ..()
	if (. <= 0 || tank_material == "steel")
		return
	if (pipe_material_toxic(tank_material) && prob(VESSEL_TOXIN_CHANCE) && fluid_add_to(reagents, "lead", 1, null) > 0)
		note_food_toxin("lead from the tank")
	if (vessel_acid_eats(tank_material) && reagent_is_acid(id))
		reagents.remove_reagent(id, min(., VESSEL_ACID_LOSS))

/obj/structure/fluid_tank/examine(mob/user, distance)
	..(user, distance)
	if (pipe_material_toxic(tank_material))
		to_chat(user, SPAN_WARNING("Lead slowly poisons what is piped into it. Do not drink from it."))
	if (vessel_acid_eats(tank_material))
		to_chat(user, SPAN_WARNING("Acid eats this metal: some of any acid piped into it is lost."))

// The same tank behind an earlier research gate: recipes are gated by result
// type, and a smith can raise a tank long before the factory.
/obj/structure/fluid_tank/plain
	name = "tank"
	desc = "A fixed metal tank for a pipe network."
	tank_material = "copper"

#undef VESSEL_ACID_CORROSION
#undef VESSEL_ACID_LOSS
#undef VESSEL_TOXIN_CHANCE
