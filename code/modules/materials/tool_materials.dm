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
