// Work speed of a tool head by material (docs/material-roles.md).
//
// Each family lists the speeds its hand-made variants always had. A head in
// one of those materials keeps that number exactly. A head in any other
// material (a cast copper or bronze pick) is placed between its neighbours
// by its ROLE_WORK_HEAD performance, and never outside the listed range.
// Pickaxe and shovel values are usespeed (higher is faster); hatchet values
// are chopping_speed (lower is faster).
var/global/list/tool_speed_families = list(
	/obj/item/weapon/material/pickaxe = list("bone" = 1, "stone" = 1.5, "iron" = 2, "steel" = 3),
	/obj/item/weapon/material/shovel = list("bone" = 0.6, "iron" = 1.5, "steel" = 2),
	/obj/item/weapon/material/hatchet = list("bone" = 4, "flint" = 3.5, "stone" = 3.3, "bronze" = 1.9, "iron" = 1.7, "steel" = 1.4),
)

// The family's speed for a head of this material, or 0 when the family or
// material is unknown.
/proc/tool_material_speed(family, material_name)
	var/list/anchors = tool_speed_families[family]
	if (!anchors || !material_name)
		return 0
	if (!isnull(anchors[material_name]))
		return anchors[material_name]
	var/performance = part_performance(ROLE_WORK_HEAD, material_name)
	if (!performance)
		return 0
	// Nearest listed material below and above by performance.
	var/low_performance = -1
	var/low_speed = 0
	var/high_performance = -1
	var/high_speed = 0
	for (var/anchor in anchors)
		var/anchor_performance = part_performance(ROLE_WORK_HEAD, anchor)
		if (anchor_performance <= performance && anchor_performance > low_performance)
			low_performance = anchor_performance
			low_speed = anchors[anchor]
		if (anchor_performance >= performance && (high_performance < 0 || anchor_performance < high_performance))
			high_performance = anchor_performance
			high_speed = anchors[anchor]
	if (low_performance < 0)
		return high_speed
	if (high_performance < 0 || high_performance == low_performance)
		return low_speed
	return low_speed + (high_speed - low_speed) * (performance - low_performance) / (high_performance - low_performance)

// The material a tool is made of: a material item's own, or the plain
// tool's tool_material.
/proc/tool_material_name(obj/item/I)
	if (!isitem(I))
		return null
	var/material/M = I.get_material()
	return M ? M.name : I.tool_material

// Called when a material item's material is set. A tool family overrides it
// to take its work speed from the material.
/obj/item/weapon/material/proc/apply_tool_material_speed()
	return

// Variants with their own hand-set speed (jackhammer, spades, chainsaw) are
// not the plain family tool and keep that speed.
/obj/item/weapon/material/pickaxe/apply_tool_material_speed()
	if (!material || initial(usespeed) != 2)
		return
	var/speed = tool_material_speed(/obj/item/weapon/material/pickaxe, material.name)
	if (speed)
		usespeed = speed

/obj/item/weapon/material/shovel/apply_tool_material_speed()
	if (!material || initial(usespeed) != 1.5)
		return
	var/speed = tool_material_speed(/obj/item/weapon/material/shovel, material.name)
	if (speed)
		usespeed = speed

/obj/item/weapon/material/hatchet/apply_tool_material_speed()
	if (!material || initial(chopping_speed) != 1.7)
		return
	var/speed = tool_material_speed(/obj/item/weapon/material/hatchet, material.name)
	if (speed)
		chopping_speed = speed
