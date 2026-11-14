// Plain tools in other materials (docs/material-roles.md, "Plain tools").
//
// A hammer, chisel, wrench or saw is not a material item, so it carries its
// material as text in tool_material. A plain tool that sets tool_noun can be
// made in another material: a recipe row whose last field names the material
// builds the same type and calls set_tool_material(). Nothing is stored on
// tools made in their usual material.

/obj/item
	var/tool_noun // "hammer": set on plain tools that may be made in other materials
	var/tool_role // ROLE_* the material is rated in for this tool

// Make this plain tool of another material. Returns FALSE and changes nothing
// when the material cannot do the tool's job.
/obj/item/proc/set_tool_material(material_name)
	if (!tool_noun || !tool_role || !istext(material_name))
		return FALSE
	var/material/M = get_material_by_name(material_name)
	if (!M || !part_rating(tool_role, M.name))
		return FALSE
	if (M.name == initial(tool_material))
		return TRUE
	tool_material = M.name
	name = "[M.display_name] [tool_noun]"
	color = M.icon_colour
	return TRUE

// How fast this tool works against the same tool in its usual material:
// 1 for every tool that exists today, between 0.4 and 1.5 for the rest.
/proc/tool_speed(obj/item/I)
	if (!isitem(I) || !I.tool_role || !I.tool_material || I.tool_material == initial(I.tool_material))
		return 1
	var/usual = part_performance(I.tool_role, initial(I.tool_material))
	var/now = part_performance(I.tool_role, I.tool_material)
	if (!usual || !now)
		return 1
	return max(0.4, min(1.5, now / usual))

// A work delay adjusted for the tool doing it.
/proc/tool_work_time(obj/item/I, delay)
	return delay / tool_speed(I)

/obj/item/weapon/hammer
	tool_noun = "hammer"
	tool_role = ROLE_STRIKER

/obj/item/weapon/hammer/tribalhammer
	tool_noun = "mallet"

/obj/item/weapon/hammer/modern
	tool_noun = "clawhammer"

/obj/item/weapon/chisel
	tool_noun = "chisel"
	tool_role = ROLE_EDGE

/obj/item/weapon/saw
	tool_noun = "saw"
	tool_role = ROLE_EDGE

/obj/item/weapon/shears
	tool_noun = "shears"
	tool_role = ROLE_EDGE

/obj/item/weapon/screwdriver
	tool_noun = "screwdriver"
	tool_role = ROLE_EDGE

/obj/item/weapon/wirecutters
	tool_noun = "wirecutters"
	tool_role = ROLE_EDGE

/obj/item/weapon/wirecutters/boltcutters
	tool_noun = "boltcutters"

/obj/item/weapon/wrench
	tool_noun = "wrench"
	tool_role = ROLE_WORK_HEAD

/obj/item/weapon/crowbar
	tool_noun = "crowbar"
	tool_role = ROLE_WORK_HEAD

/obj/item/weapon/crowbar/prybar
	tool_noun = "prybar"

// Sparks. A tool whose material sparks (iron, steel, flint) can set off powder
// or fuel when it is struck against the barrel on harm intent. Bronze, copper,
// wood and bone tools never do, which is why powder mills used them.
#define TOOL_SPARK_CHANCE 4

/proc/tool_throws_sparks(obj/item/I)
	if (!isitem(I) || !I.tool_flags)
		return FALSE
	var/material/M = get_material_by_name(tool_material_name(I))
	return M ? M.sparks : FALSE

// Enough powder or fuel to go up: the same amounts a bullet sets off.
/obj/item/weapon/reagent_containers/glass/barrel/proc/spark_volatile()
	if (!reagents)
		return FALSE
	return reagents.has_reagent("gasoline", 10) || reagents.has_reagent("diesel", 30) || reagents.has_reagent("biodiesel", 30) || reagents.has_reagent("ethanol", 10) || reagents.has_reagent("petroleum", 40) || reagents.has_reagent("gunpowder", 30)

/obj/item/weapon/reagent_containers/glass/barrel/proc/spark_explode()
	explosion(loc, 1, 2, 2, 0)
	qdel(src)

/obj/item/weapon/reagent_containers/glass/barrel/gunpowder/spark_explode()
	explode()

// Asked before every attackby(). TRUE means the blow was dealt with here.
/atom/proc/struck_by_tool(obj/item/I, mob/living/user)
	return FALSE

// A deliberate blow with a tool. Returns TRUE when the barrel went up.
/obj/item/weapon/reagent_containers/glass/barrel/struck_by_tool(obj/item/I, mob/living/user)
	if (!user || user.a_intent != I_HARM || !tool_throws_sparks(I) || !spark_volatile())
		return FALSE
	if (!prob(TOOL_SPARK_CHANCE))
		to_chat(user, SPAN_DANGER("Sparks fly off \the [I] as it hits \the [src]!"))
		return FALSE
	visible_message(SPAN_DANGER("A spark from [user]'s [I.name] sets off \the [src]!"))
	message_admins("[key_name_admin(user)] set off \a [src] with sparks from \a [I] at ([x],[y],[z]).")
	spark_explode()
	return TRUE

#undef TOOL_SPARK_CHANCE

/obj/item/weapon/reagent_containers/glass/proc/spark_warning(mob/user)
	return

/obj/item/weapon/reagent_containers/glass/barrel/spark_warning(mob/user)
	if (spark_volatile())
		to_chat(user, SPAN_WARNING("What is inside could go up at a spark. Do not strike it with iron, steel or flint tools; bronze, copper, wood and bone are safe."))
