// Climbing trees.
//
// Grab intent with a free hand on a tree (or the tree's right-click Climb Tree
// verb) climbs it after a few seconds. Up a tree:
// - the climber is raised to the top of the tree's sprite and drawn behind its
//   leaves, head peeking out over the canopy (tree_climb_pose);
// - melee is out of reach both ways: nobody on the ground can hit, grab, kick
//   or pull the climber, and the climber cannot hit them. Guns, bows and thrown
//   things still work (tree_melee_blocked). Animals that climb still follow;
// - the climber sees over walls outdoors (los_terrain.dm los_up_tree,
//   LOS_EYE_CLIMBED);
// - Look into Distance reaches 8 tiles (human.dm look_into_distance);
// - animals that cannot climb (can_climb_trees) lose interest and cannot reach
//   the climber. Trees hide nobody, so the climber stays in plain sight.
// Any movement key, grab-clicking the tree again or Climb Down climbs down to
// where the climb started. Being knocked out, stunned or the tree going away
// drops the climber to the ground.
//
// The climber stays on the tree's turf, so saves, pathing and turf contents are
// unchanged; the state is temporary and cleared on any mismatch.

#define TREE_CLIMB_TIME 50
#define TREE_CLIMB_DOWN_TIME 20
// The climber's feet sit this far below the canopy top. Human heads are about
// 28px tall, so the head (6px) peeks out over the leaves and the body stays
// behind them; the climber keeps its normal layer under the tree.
#define TREE_CLIMB_HEAD_Y 22

// Height of the tree's canopy top above the bottom of its sprite. 0 finds it
// from the sprite: the highest row with a visible pixel.
/obj/structure/wild/var/tree_canopy_top = 0

var/global/list/tree_icon_sizes = list()
var/global/list/tree_canopy_tops = list()

// list(width, height) of an icon file, cached per file.
/proc/tree_icon_size(icon_file)
	if (!icon_file)
		return list(world.icon_size, world.icon_size)
	var/key = "[icon_file]"
	var/list/size = tree_icon_sizes[key]
	if (!size)
		var/icon/I = icon(icon_file)
		size = list(max(1, I.Width()), max(1, I.Height()))
		tree_icon_sizes[key] = size
	return size

// Highest visible row of a tree sprite, counted from its bottom; cached per
// icon state. Scans down from the top and stops at the first leaf.
/proc/tree_sprite_top(icon_file, state)
	var/list/size = tree_icon_size(icon_file)
	if (!icon_file)
		return size[2]
	var/key = "[icon_file]|[state]"
	if (!isnull(tree_canopy_tops[key]))
		return tree_canopy_tops[key]
	var/top = size[2]
	var/icon/I = icon(icon_file, state, SOUTH, 1)
	var/found = FALSE
	for (var/y = size[2], y >= 1 && !found, y--)
		for (var/x = 1, x <= size[1], x++)
			if (I.GetPixel(x, y))
				top = y
				found = TRUE
				break
	tree_canopy_tops[key] = top
	return top

/obj/structure/wild/var/tmp/mob/living/human/tree_climber = null
/mob/living/human/var/tmp/turf/tree_climb_from = null
/mob/living/human/var/tmp/tree_climb_from_x = 0
/mob/living/human/var/tmp/tree_climb_from_y = 0
/mob/living/human/var/tmp/tree_climb_busy = FALSE
/mob/living/human/var/tmp/tree_climb_pixel_x = 0
/mob/living/human/var/tmp/tree_climb_pixel_y = 0

// A save taken while climbing up or down must not keep the climb lock.
/mob/living/human/persistence_runtime_var(key)
	return key == "tree_climb_busy" || ..()

// Animals that can follow someone up a tree.
/mob/living/simple_animal/var/can_climb_trees = FALSE
/mob/living/simple_animal/hostile/panther
	can_climb_trees = TRUE
/mob/living/simple_animal/hostile/poison/snake
	can_climb_trees = TRUE
/mob/living/simple_animal/hostile/gorilla
	can_climb_trees = TRUE
/mob/living/simple_animal/hostile/canopy_strangler
	can_climb_trees = TRUE

// TRUE when this animal can still reach and fight someone up a tree. Human NPCs
// with guns or bows keep shooting; beasts and melee NPCs are left at the foot.
/mob/living/simple_animal/proc/can_reach_tree_climber(mob/M)
	if (!los_up_tree(M))
		return TRUE
	if (can_climb_trees)
		return TRUE
	// Human NPCs can still shoot a climber, but not club one.
	var/mob/living/simple_animal/hostile/human/HN = src
	return istype(HN) && HN.ranged

/proc/tree_climbable(atom/A)
	if (!root_tree_family(A) || !isturf(A.loc))
		return FALSE
	var/obj/structure/wild/W = A
	return W.density && W.holds_climber

// Only grown trees hold a climber: a sprite a single tile tall (the small tree,
// young or burnt-down trees) is too small.
/proc/tree_grown_enough(obj/structure/wild/W)
	var/list/size = tree_icon_size(W.icon)
	return size[2] > world.icon_size

// TRUE when the attacker cannot reach the target in melee because one of them
// is up a tree and the other is not. Only animals that climb follow a climber
// into the branches; everyone else needs a gun, a bow or something to throw.
/proc/tree_melee_blocked(mob/attacker, mob/target)
	if (!ismob(attacker) || !ismob(target) || attacker == target)
		return FALSE
	var/attacker_up = los_up_tree(attacker)
	var/target_up = los_up_tree(target)
	if (!attacker_up && !target_up)
		return FALSE
	if (attacker_up && target_up)
		return attacker.climbed_tree != target.climbed_tree
	var/mob/ground = attacker_up ? target : attacker
	if (istype(ground, /mob/living/simple_animal))
		var/mob/living/simple_animal/SA = ground
		return !SA.can_climb_trees
	return TRUE

// tree_melee_blocked with a message to the attacker.
/proc/tree_melee_refused(mob/attacker, mob/target)
	if (!tree_melee_blocked(attacker, target))
		return FALSE
	if (los_up_tree(attacker))
		to_chat(attacker, SPAN_WARNING("You can't reach [target] from up the tree."))
	else
		to_chat(attacker, SPAN_WARNING("[target] is up the tree, out of reach."))
	return TRUE

// Where the climber is drawn: centred on the trunk, head peeking over the top.
/mob/living/human/proc/tree_climb_pose(obj/structure/wild/W)
	var/list/size = tree_icon_size(W.icon)
	var/trunk_x = W.trunk_center_x ? W.trunk_center_x : round(size[1] / 2)
	var/top = W.tree_canopy_top ? W.tree_canopy_top : tree_sprite_top(W.icon, W.icon_state)
	tree_climb_pixel_x = initial(pixel_x) + W.pixel_x + trunk_x - world.icon_size / 2
	tree_climb_pixel_y = initial(pixel_y) + max(0, W.pixel_y + top - TREE_CLIMB_HEAD_Y)

// Keeps the climber at the treetop; attack animations and posture updates
// put pixel offsets back to their ground values.
/mob/living/human/proc/tree_climb_apply_pose(animate_time = 0)
	if (pixel_x == tree_climb_pixel_x && pixel_y == tree_climb_pixel_y)
		return
	if (animate_time)
		animate(src, pixel_x = tree_climb_pixel_x, pixel_y = tree_climb_pixel_y, time = animate_time)
	else
		pixel_x = tree_climb_pixel_x
		pixel_y = tree_climb_pixel_y

/mob/living/human/rest_pixel_x()
	return climbed_tree ? tree_climb_pixel_x : ..()

/mob/living/human/rest_pixel_y()
	return climbed_tree ? tree_climb_pixel_y : ..()

// Null when H can climb W now, otherwise the reason it cannot.
/mob/living/human/proc/tree_climb_refusal(obj/structure/wild/W)
	if (!tree_climbable(W) || QDELETED(W))
		return "That can't be climbed."
	if (!tree_grown_enough(W))
		return "\The [W] is too small to climb."
	if (climbed_tree)
		return "You are already up a tree."
	if (!isturf(loc) || W.z != z || get_dist(src, W) > 1 || !W.Adjacent(src))
		return "You need to stand next to \the [W]."
	if (stat || lying || resting || prone || weakened || stunned || paralysis || restrained() || buckled)
		return "You can't climb right now."
	if (l_hand && r_hand)
		return "You need a free hand to climb."
	if (W.stored_unit)
		return "Someone is hiding in \the [W]."
	if (W.tree_climber && W.tree_climber != src && W.tree_climber.climbed_tree == W)
		return "Someone is already up \the [W]."
	if (grabbed_by && grabbed_by.len)
		return "You can't climb while someone holds you."
	return null

/mob/living/human/proc/climb_tree(obj/structure/wild/W)
	if (!W)
		return FALSE
	if (climbed_tree)
		if (W == climbed_tree)
			start_climb_down()
			return TRUE
		to_chat(src, SPAN_WARNING("You are already up a tree."))
		return FALSE
	if (tree_climb_busy)
		return FALSE
	var/why = tree_climb_refusal(W)
	if (why)
		to_chat(src, SPAN_WARNING(why))
		return FALSE
	tree_climb_busy = TRUE
	visible_message(SPAN_NOTICE("[src] starts climbing \the [W]."), SPAN_NOTICE("You start climbing \the [W]..."))
	var/climbed = do_after(src, TREE_CLIMB_TIME, W)
	tree_climb_busy = FALSE
	if (!climbed)
		return FALSE
	why = tree_climb_refusal(W)
	if (why)
		to_chat(src, SPAN_WARNING(why))
		return FALSE
	return finish_climb_tree(W)

/mob/living/human/proc/finish_climb_tree(obj/structure/wild/W)
	stop_pulling()
	if (pulledby)
		pulledby.stop_pulling()
	tree_climb_from = loc
	tree_climb_from_x = step_x
	tree_climb_from_y = step_y
	if (loc != W.loc)
		forceMove(W.loc)
		step_x = 0
		step_y = 0
	if (loc != W.loc)
		tree_climb_from = null
		return FALSE
	climbed_tree = W
	W.tree_climber = src
	tree_climb_pose(W)
	tree_climb_apply_pose(4)
	visible_message(SPAN_NOTICE("[src] climbs up \the [W]."), SPAN_NOTICE("You climb up \the [W]. You can see far from up here; Look into Distance reaches further. Move or grab the tree again to climb down."))
	tree_climb_refresh_sight()
	return TRUE

/mob/living/human/proc/start_climb_down()
	if (!climbed_tree || tree_climb_busy)
		return FALSE
	var/obj/structure/wild/W = climbed_tree
	tree_climb_busy = TRUE
	to_chat(src, SPAN_NOTICE("You start climbing down \the [W]..."))
	var/done = do_after(src, TREE_CLIMB_DOWN_TIME, W)
	tree_climb_busy = FALSE
	if (!done || climbed_tree != W)
		return FALSE
	climb_down_tree()
	return TRUE

// Leaves the tree. fall: dropped by a stun, knockout or the tree going away.
/mob/living/human/proc/climb_down_tree(fall = FALSE)
	var/obj/structure/wild/W = climbed_tree
	if (!W && !tree_climb_from)
		return
	climbed_tree = null
	if (W && W.tree_climber == src)
		W.tree_climber = null
	animate(src)
	pixel_x = initial(pixel_x)
	pixel_y = initial(pixel_y)
	var/turf/from = tree_climb_from
	tree_climb_from = null
	if (!fall && isturf(from) && isturf(loc) && from.z == z && get_dist(from, loc) <= 1 && (!W || W.loc == loc))
		forceMove(from)
		step_x = tree_climb_from_x
		step_y = tree_climb_from_y
	if (fall)
		visible_message(SPAN_DANGER("[src] falls out of the tree!"), SPAN_DANGER("You fall out of the tree!"))
		adjustBruteLoss(rand(3, 8))
		Weaken(2)
	else
		visible_message(SPAN_NOTICE("[src] climbs down."), SPAN_NOTICE("You climb down."))
	if (looking)
		look_into_distance(src, FALSE)
	tree_climb_refresh_sight()

/mob/living/human/proc/tree_climb_refresh_sight()
	if (client && CIV13_GEOMETRIC_LOS_CORE)
		client.los_dirty = TRUE
		client.reconcile_geometric_los()

// Once per Life tick while up a tree.
/mob/living/human/proc/tree_climb_check()
	var/obj/structure/wild/W = climbed_tree
	if (QDELETED(W) || !isturf(loc) || W.loc != loc)
		// The tree is gone: fall. Moved off it some other way: just let go.
		climb_down_tree(QDELETED(W) || !isturf(W.loc))
		return
	if (stat || paralysis || weakened || stunned || sleeping > 0 || buckled)
		climb_down_tree(TRUE)
		return
	// The tree may have been re-offset (a save loaded, a sapling grew).
	tree_climb_pose(W)
	tree_climb_apply_pose()

/mob/living/human/Life()
	. = ..()
	if (climbed_tree)
		tree_climb_check()

// Grab intent, free hand: climb the tree, or climb down from your own tree.
/mob/living/human/proc/grab_climb_tree(atom/A)
	if (a_intent != I_GRAB || get_active_hand() || !tree_climbable(A))
		return FALSE
	var/obj/structure/wild/W = A
	// Gorillamen still forage leaves with grab intent; Vietnamese hiders leave.
	if ((gorillaman && W.edible && W.leaves >= 1) || W.stored_unit)
		return FALSE
	climb_tree(W)
	return TRUE

/obj/structure/wild/proc/climb_tree_by(mob/user)
	if (!ishuman(user) || !tree_climbable(src))
		return
	var/mob/living/human/H = user
	H.climb_tree(src)

/obj/structure/wild/tree/verb/climb_tree_verb()
	set name = "Climb Tree"
	set category = null
	set src in view(1)
	climb_tree_by(usr)

/obj/structure/wild/jungle/verb/climb_jungle_verb()
	set name = "Climb Tree"
	set category = null
	set src in view(1)
	climb_tree_by(usr)

/obj/structure/wild/palm/verb/climb_palm_verb()
	set name = "Climb Tree"
	set category = null
	set src in view(1)
	climb_tree_by(usr)

/mob/living/human/verb/climb_down_tree_verb()
	set name = "Climb Down"
	set category = "IC"
	set desc = "Climb down from a tree, or over the edge of an upper floor onto the ground below. Keep a hand free."
	if (!climbed_tree)
		climb_down_any_edge() // Not up a tree: climb down over open air (edge_climbing.dm).
		return
	start_climb_down()

/obj/structure/wild/examine(mob/user, distance = -1)
	. = ..()
	if (user && tree_climber && tree_climber.climbed_tree == src && get_dist(user, src) <= 2)
		to_chat(user, SPAN_NOTICE("[tree_climber] is up in its branches."))

#undef TREE_CLIMB_TIME
#undef TREE_CLIMB_DOWN_TIME
#undef TREE_CLIMB_HEAD_Y
