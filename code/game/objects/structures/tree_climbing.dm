// Climbing trees.
//
// Grab intent with a free hand on a tree (or the tree's right-click Climb Tree
// verb) climbs it after a few seconds. Up a tree:
// - the climber sees over walls and other trees outdoors and is not limited by
//   its own foliage (los_terrain.dm los_up_tree, LOS_EYE_CLIMBED);
// - Look into Distance reaches 8 tiles (human.dm look_into_distance);
// - animals that cannot climb (can_climb_trees) lose interest and cannot reach
//   the climber, while foliage cover still hides the climber beyond two tiles.
// Any movement key, grab-clicking the tree again or Climb Down climbs down to
// where the climb started. Being knocked out, stunned or the tree going away
// drops the climber to the ground.
//
// The climber stays on the tree's turf, so saves, pathing and turf contents are
// unchanged; the state is temporary and cleared on any mismatch.

#define TREE_CLIMB_TIME 50
#define TREE_CLIMB_DOWN_TIME 20
#define TREE_CLIMB_PIXEL_Y 10

/obj/structure/wild/var/tmp/mob/living/human/tree_climber = null
/mob/living/human/var/tmp/turf/tree_climb_from = null
/mob/living/human/var/tmp/tree_climb_from_x = 0
/mob/living/human/var/tmp/tree_climb_from_y = 0
/mob/living/human/var/tmp/tree_climb_busy = FALSE

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
// keep their weapons and sight; only beasts are left at the foot of the tree.
/mob/living/simple_animal/proc/can_reach_tree_climber(mob/M)
	if (!los_up_tree(M))
		return TRUE
	return can_climb_trees || istype(src, /mob/living/simple_animal/hostile/human)

/proc/tree_climbable(atom/A)
	if (!root_tree_family(A) || !isturf(A.loc))
		return FALSE
	var/obj/structure/wild/W = A
	return W.density && W.opacity

// Null when H can climb W now, otherwise the reason it cannot.
/mob/living/human/proc/tree_climb_refusal(obj/structure/wild/W)
	if (!tree_climbable(W) || QDELETED(W))
		return "That can't be climbed."
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
	pixel_y = initial(pixel_y) + TREE_CLIMB_PIXEL_Y
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
	// Attack animations return pixel_y to its initial value.
	if (pixel_y != initial(pixel_y) + TREE_CLIMB_PIXEL_Y)
		pixel_y = initial(pixel_y) + TREE_CLIMB_PIXEL_Y

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
	if (!climbed_tree)
		to_chat(src, SPAN_WARNING("You are not up a tree."))
		return
	start_climb_down()

/obj/structure/wild/examine(mob/user, distance = -1)
	. = ..()
	if (user && tree_climber && tree_climber.climbed_tree == src && get_dist(user, src) <= 2)
		to_chat(user, SPAN_NOTICE("[tree_climber] is up in its branches."))

#undef TREE_CLIMB_TIME
#undef TREE_CLIMB_DOWN_TIME
#undef TREE_CLIMB_PIXEL_Y
