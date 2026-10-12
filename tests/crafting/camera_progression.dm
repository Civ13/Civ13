// Production recipe generation and two-faction research accounting, isolated startup.
// Inputs/study/prototype flags are supplied; no connected player or timed crafting.
/proc/recipe_ci_camera_expect(condition, reason)
	if (!condition)
		recipe_ci_fail("camera progression", reason)
/proc/recipe_ci_camera_progression()
	map.ordinal_age = 7
	var/lagging = "camera_lagging_ci"
	var/leading = "camera_leading_ci"
	map.faction_baseline_era[lagging] = 7
	map.faction_baseline_era[leading] = 7
	var/datum/research_node/N = get_research_node("digital_computing")
	recipe_ci_camera_expect(N && N.prototype_type == /obj/item/camera/coldwar, "Digital Computing requires the cold-war subtype")
	var/datum/stack_recipe/R = recipe_ci_food_recipe(/material/electronics, /obj/item/camera/coldwar, lagging)
	recipe_ci_camera_expect(R && R.req_amount == 7 && ispath(R.result_type, N.prototype_type), "Cold War offers a paid matching prototype")
	recipe_ci_camera_expect(!map.is_node_done(lagging, N.id), "established faction has not completed Modern research")
	recipe_ci_camera_expect(!ispath(/obj/item/camera, N.prototype_type), "modern parent camera does not match the required subtype")
	map.set_prototype_submitted(leading, N.id)
	recipe_ci_camera_expect(map.add_research_ticks(leading, N.id, N.cost_ticks) && map.ordinal_age == 8, "another faction's production completion advances the world")
	recipe_ci_camera_expect(map.faction_baseline_era[lagging] == 7 && !map.is_node_done(lagging, N.id), "era advancement preserves lagging faction research")
	R = recipe_ci_food_recipe(/material/electronics, /obj/item/camera/coldwar, lagging)
	recipe_ci_camera_expect(R && R.req_amount == 7 && ispath(R.result_type, N.prototype_type), "lagging faction retains paid matching prototype after another faction advances the world")
	recipe_ci_camera_expect(!map.add_research_ticks(lagging, N.id, N.cost_ticks) && !map.is_node_done(lagging, N.id), "full study still requires the prototype")
	map.set_prototype_submitted(lagging, N.id)
	recipe_ci_camera_expect(map.add_research_ticks(lagging, N.id, 1) && map.is_node_done(lagging, N.id), "supplied matching prototype and study complete lagging faction research")
	var/locked = "camera_locked_ci"
	map.faction_baseline_era[locked] = 0
	recipe_ci_camera_expect(!recipe_ci_food_recipe(/material/electronics, /obj/item/camera/coldwar, locked), "Modern era does not waive Assembly Line research")
	map.ordinal_age = 0
