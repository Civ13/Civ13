// ============================================================
// Debug-only research bench. Instantly completes whatever node it's
// assigned to, bypassing ticks/samples/prototype/book requirements
// entirely -- for quickly testing a specific tech (or, via a Prototype-mode
// capstone, an era advance) without grinding it out.
//
// Deliberately NOT reachable through crafting: no RECIPE: line in any
// config/crafting/material_recipes_*.txt references this subtype, so normal
// play can never produce one. The only way to get one is an admin's
// "Create Object" tool (code/modules/admin/create_object.dm), which lists
// every /obj subtype automatically -- no separate registration needed for
// a new type to show up there, which is what "only spawnable as a debug
// item" means in practice in this codebase.
// ============================================================

/obj/structure/research_bench/adminbench
	name = "admin research bench"
	desc = "DEBUG ITEM. Instantly completes whatever it's assigned to research. Not obtainable through normal play."
	color = "#ff3333" // visually obvious it isn't a normal bench
	tier = MAX_BENCH_TIER // skip the tier-upgrade grind too -- it can research anything immediately

// Admin-spawned, so it never goes through stack.dm's crafting flow that
// stamps a faction onto a normal bench at construction -- without this it
// would sit permanently unowned. Auto-claims for whichever faction the
// first interacting human belongs to.
/obj/structure/research_bench/adminbench/attack_hand(mob/user as mob)
	if (ishuman(user) && !faction)
		var/mob/living/human/H = user
		if (H.civilization && H.civilization != "none")
			faction = H.civilization
	return ..()

/obj/structure/research_bench/adminbench/try_assign_node(mob/living/human/H, node_id)
	..()
	if (assigned_node == node_id && faction && map && !map.is_node_done(faction, node_id))
		map.complete_node(faction, node_id)
		GLOB.nanomanager.update_uis(src)

/obj/structure/research_bench/adminbench/try_advance_queue()
	..()
	if (assigned_node && faction && map && !map.is_node_done(faction, assigned_node))
		map.complete_node(faction, assigned_node)
		GLOB.nanomanager.update_uis(src)
