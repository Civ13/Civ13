// Full-source probe: climbing a tree, sight from the canopy, animals that
// cannot follow, climbing down to the starting spot and falling when the tree
// goes away. Real humans, trees and animals; do_after is skipped by calling
// finish_climb_tree directly after the same refusal check.
/world
	hub = ""
	visibility = 0
	maxx = 20
	maxy = 20
	maxz = 1
	fps = 20
	turf = /turf/floor/plating/tree_climbing_probe
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

/obj/map_metadata/tree_climbing_probe/New()
	map = src

/turf/floor/plating/tree_climbing_probe

/mob/living/human/tree_climbing_probe/human_subtile_authority(client/owner)
	return TRUE

var/tree_climbing_probe_checks = 0

/proc/tree_climbing_probe_assert(ok, label)
	tree_climbing_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/tree_climbing_probe_actor(tx, ty, sx = 0, sy = 0)
	var/mob/living/human/tree_climbing_probe/H = new(locate(tx, ty, 1))
	H.canmove = TRUE
	H.stat = CONSCIOUS
	H.lastarea = get_area(H)
	H.real_name = "Climber"
	H.name = H.real_name
	H.step_x = sx
	H.step_y = sy
	return H

/proc/tree_climbing_probe_run()
	config = new
	config.webhook_can_fire = FALSE
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	movementMachine = new
	map = new /obj/map_metadata/tree_climbing_probe
	tree_climbing_probe_assert(world.byond_version == 516 && world.byond_build == 1688, "pinned_native_engine")

	var/obj/structure/wild/tree/live_tree/T = new(locate(8, 8, 1))
	tree_climbing_probe_assert(tree_climbable(T), "live_tree_climbable")
	var/obj/structure/wild/tree/small = new(locate(12, 12, 1))
	var/mob/living/human/tree_climbing_probe/kid = tree_climbing_probe_actor(12, 11)
	tree_climbing_probe_assert(kid.tree_climb_refusal(small) == "\The [small] is too small to climb.", "small_tree_too_small")
	qdel(kid)
	qdel(small)
	var/obj/structure/wild/bush/B = new(locate(3, 3, 1))
	tree_climbing_probe_assert(!tree_climbable(B), "bush_not_climbable")

	// Climb from the next tile; the start spot is kept for climbing down.
	var/mob/living/human/tree_climbing_probe/H = tree_climbing_probe_actor(9, 8, 4, 6)
	tree_climbing_probe_assert(isnull(H.tree_climb_refusal(T)), "adjacent_climb_allowed")
	tree_climbing_probe_assert(los_eye_level(H) == LOS_EYE_STANDING, "ground_eye")
	tree_climbing_probe_assert(isnull(los_terrain_for(H, 7)), "ground_no_canopy_field")
	tree_climbing_probe_assert(H.finish_climb_tree(T), "climbed")
	tree_climbing_probe_assert(H.loc == T.loc && H.climbed_tree == T && T.tree_climber == H && los_up_tree(H), "up_the_tree")
	// Raised to the treetop behind the leaves: trunk centre, head peeking over
	// the highest leaf of the sprite, layered under the tree.
	tree_climbing_probe_assert(H.tree_climb_pixel_x == T.pixel_x + 32 - 16 && H.tree_climb_pixel_y == max(0, T.pixel_y + tree_sprite_top(T.icon, T.icon_state) - 22), "pose_at_treetop")
	tree_climbing_probe_assert(tree_sprite_top('icons/obj/flora/bigtrees.dmi', "tree_1") == 62 && tree_sprite_top('icons/obj/flora/palm.dmi', "palm1") == 54 && tree_sprite_top('icons/obj/flora/jungletreesmaller.dmi', "tree2") == 78, "canopy_top_from_sprite")
	tree_climbing_probe_assert(H.pixel_x == H.tree_climb_pixel_x && H.pixel_y == H.tree_climb_pixel_y && H.layer < T.layer, "drawn_behind_canopy")
	H.pixel_y = 0
	H.tree_climb_check()
	tree_climbing_probe_assert(H.pixel_y == H.tree_climb_pixel_y, "pose_restored_each_life")
	tree_climbing_probe_assert(H.rest_pixel_y() == H.tree_climb_pixel_y, "attack_animation_rests_at_treetop")
	tree_climbing_probe_assert(los_eye_level(H) == LOS_EYE_CLIMBED, "climber_eye")
	// Flat ground without heights still gets an open field with the eye up high,
	// so walls and other tree tops below it can be seen over.
	var/list/field = los_terrain_for(H, 7)
	tree_climbing_probe_assert(islist(field) && field.len == 3, "canopy_field")
	var/datum/los_terrain_field/F = field[1]
	tree_climbing_probe_assert(F.eye == LOS_EYE_CLIMBED && !F.flat && F.visible(5, 5, 0.25), "canopy_field_open")

	// Foliage: the climber sees people far off; they still cannot see it.
	var/mob/living/human/tree_climbing_probe/far = tree_climbing_probe_actor(14, 8)
	var/mob/living/human/tree_climbing_probe/near = tree_climbing_probe_actor(9, 9)
	tree_climbing_probe_assert(!los_foliage_hides(H, far), "climber_sees_far")
	tree_climbing_probe_assert(los_foliage_hides(far, H), "climber_hidden_from_far")
	tree_climbing_probe_assert(!los_foliage_hides(near, H), "climber_seen_near")

	// One climber per tree; a full pair of hands cannot climb.
	tree_climbing_probe_assert(near.tree_climb_refusal(T) == "Someone is already up \the [T].", "one_climber_per_tree")
	var/obj/structure/wild/tree/live_tree/T2 = new(locate(10, 9, 1))
	near.put_in_l_hand(new /obj/item/stack/material/wood(near.loc))
	near.put_in_r_hand(new /obj/item/stack/material/wood(near.loc))
	tree_climbing_probe_assert(near.l_hand && near.r_hand && near.tree_climb_refusal(T2) == "You need a free hand to climb.", "free_hand_needed")
	tree_climbing_probe_assert(far.tree_climb_refusal(T2) == "You need to stand next to \the [T2].", "must_be_adjacent")

	// Animals: wolves give up on a climber, cats follow; both reach the ground.
	var/mob/living/simple_animal/hostile/wolf/W = new(locate(8, 7, 1))
	var/mob/living/simple_animal/hostile/panther/P = new(locate(7, 8, 1))
	tree_climbing_probe_assert(!W.can_reach_tree_climber(H), "wolf_cannot_reach_climber")
	tree_climbing_probe_assert(P.can_reach_tree_climber(H), "panther_climbs")
	tree_climbing_probe_assert(W.can_reach_tree_climber(far), "wolf_reaches_ground")
	W.target_mob = H
	W.AttackTarget()
	tree_climbing_probe_assert(isnull(W.target_mob) || W.stance == HOSTILE_STANCE_IDLE, "wolf_loses_climber")

	// Melee: nobody on the ground reaches the climber, the climber reaches
	// nobody on the ground; climbing animals still fight; guns are not melee.
	tree_climbing_probe_assert(tree_melee_blocked(near, H) && tree_melee_blocked(H, near), "no_melee_across_canopy")
	tree_climbing_probe_assert(tree_melee_blocked(W, H) && !tree_melee_blocked(P, H) && !tree_melee_blocked(H, P), "only_climbing_animals_follow")
	tree_climbing_probe_assert(!tree_melee_blocked(near, far) && !tree_melee_blocked(H, H), "ground_melee_unchanged")
	var/mob/living/human/tree_climbing_probe/striker = tree_climbing_probe_actor(8, 9)
	var/obj/item/weapon/material/hatchet/axe = new(striker.loc)
	striker.put_in_r_hand(axe)
	striker.a_intent = I_HARM
	var/before_hit = H.getBruteLoss()
	tree_climbing_probe_assert(H.attackby(axe, striker) && H.getBruteLoss() == before_hit, "item_melee_refused")
	H.attack_hand(striker)
	tree_climbing_probe_assert(H.getBruteLoss() == before_hit, "unarmed_melee_refused")
	striker.start_pulling(H)
	tree_climbing_probe_assert(striker.pulling != H, "cannot_pull_climber")

	// Climbing down returns to the exact starting spot.
	H.climb_down_tree()
	tree_climbing_probe_assert(!H.climbed_tree && !T.tree_climber && !los_up_tree(H), "down")
	tree_climbing_probe_assert(H.loc == locate(9, 8, 1) && H.step_x == 4 && H.step_y == 6 && H.pixel_y == 0 && H.pixel_x == 0, "back_at_start")
	tree_climbing_probe_assert(los_foliage_hides(far, H) == FALSE, "visible_again")

	// The tree going away drops the climber.
	tree_climbing_probe_assert(H.finish_climb_tree(T), "climbed_again")
	var/brute = H.getBruteLoss()
	qdel(T)
	H.tree_climb_check()
	tree_climbing_probe_assert(!H.climbed_tree && H.getBruteLoss() > brute && H.pixel_y == 0, "fell_when_tree_gone")

	// Stunned up a tree: fall.
	tree_climbing_probe_assert(isnull(H.tree_climb_refusal(T2)) || H.weakened, "second_tree_reachable_or_stunned")
	H.weakened = 0
	H.lying = FALSE
	H.forceMove(locate(10, 8, 1))
	tree_climbing_probe_assert(isnull(H.tree_climb_refusal(T2)), "second_tree_climbable")
	tree_climbing_probe_assert(H.finish_climb_tree(T2), "climbed_second")
	H.weakened = 3
	H.tree_climb_check()
	tree_climbing_probe_assert(!H.climbed_tree && !T2.tree_climber, "stun_falls")

/world/New()
	OpenPort("none")
	var/error = null
	try
		tree_climbing_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = tree_climbing_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
