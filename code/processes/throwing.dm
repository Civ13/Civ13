/process/throwing

/process/throwing/setup()
	name = "throwing"
	schedule_interval = 0.05 SECONDS
	start_delay = 10
	fires_at_gamestates = list(GAME_STATE_PREGAME, GAME_STATE_SETTING_UP, GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_VERY_HIGH
	processes.throwing = src

/process/throwing/fire()

	for (current in current_list)

		var/atom/movable/AM = current

		if (!isDeleted(AM))
			if (AM.loc)
				try
					switch (AM.throwmode)
						if (0)
							if (AM && AM.original_target &&((((AM.x < AM.original_target.x && AM.dx == EAST) || (AM.x > AM.original_target.x && AM.dx == WEST)) && AM.dist_travelled < AM.range) || (AM.a && AM.a.has_gravity == FALSE)) && AM.throwing && istype(AM.loc, /turf))
								// only stop when we've gone the whole distance (or max throw AM.range) and are on a non-space tile, or hit something, or hit the end of the map, or someone picks it up
								if (AM.error < 0)
									var/atom/step = get_step(AM, AM.dy)
									if (!step) // going off the edge of the map makes get_step return null, don't let things go off the edge
										thrown_list -= AM
										continue
									if (map.check_caribbean_block(AM.thrower, get_turf(step)) && (!map.allow_bullets_through_blocks.Find(get_area(step):type) || ismob(AM)))
										if (istype(AM, /obj/item/weapon/grenade))
											var/obj/item/weapon/grenade/G = AM
											G.active = FALSE
										else if (istype(AM, /obj/item/weapon/reagent_containers/food/drinks/bottle))
											var/obj/item/weapon/reagent_containers/food/drinks/bottle/B = AM
											if (B.rag)
												B.rag.on_fire = FALSE
										thrown_list -= AM
										continue

									var/canMove = TRUE
									for (var/obj/structure/S in step)
										if (istype(S, /obj/structure/window/sandbag) || S.throwpass)
											continue
										if (!S.density && !istype(S, /obj/structure/window/classic))
											continue
										canMove = FALSE
									if (canMove)
										AM.forceMove_nondenseturf(step)

									AM.hit_check(AM.speed)
									AM.error += AM.dist_x
									AM.dist_travelled++
								else
									var/atom/step = get_step(AM, AM.dx)
									if (!step) // going off the edge of the map makes get_step return null, don't let things go off the edge
										thrown_list -= AM
										continue
									if (map.check_caribbean_block(AM.thrower, get_turf(step)) && (!map.allow_bullets_through_blocks.Find(get_area(step):type) || ismob(AM)))
										if (istype(AM, /obj/item/weapon/grenade))
											var/obj/item/weapon/grenade/G = AM
											G.active = FALSE
										thrown_list -= AM
										continue
									var/canMove = TRUE
									for (var/obj/structure/S in step)
										if (istype(S, /obj/structure/window/sandbag) || S.throwpass)
											continue
										if (!S.density && !istype(S, /obj/structure/window/classic))
											continue
										canMove = FALSE
									if (canMove)
										AM.forceMove_nondenseturf(step)
									AM.hit_check(AM.speed)
									AM.error -= AM.dist_y
									AM.dist_travelled++
								AM.a = get_area(AM.loc)
							else
								AM.finished_throwing()
						if (1)
							if (AM && AM.original_target &&((((AM.y < AM.original_target.y && AM.dy == NORTH) || (AM.y > AM.original_target.y && AM.dy == SOUTH)) && AM.dist_travelled < AM.range) || (AM.a && AM.a.has_gravity == FALSE)) && AM.throwing && istype(AM.loc, /turf))
								// only stop when we've gonea the whole distance (or max throw AM.range) and are on a non-space tile, or hit something, or hit the end of the map, or someone picks it up
								if (AM.error < 0)
									var/atom/step = get_step(AM, AM.dx)
									if (!step) // going off the edge of the map makes get_step return null, don't let things go off the edge
										thrown_list -= AM
										continue
									if (map.check_caribbean_block(AM.thrower, get_turf(step)) && (!map.allow_bullets_through_blocks.Find(get_area(step):type) || ismob(AM)))
										if (istype(AM, /obj/item/weapon/grenade))
											var/obj/item/weapon/grenade/G = AM
											G.active = FALSE
										thrown_list -= AM
										continue
									var/canMove = TRUE
									for (var/obj/structure/S in step)
										if (istype(S, /obj/structure/window/sandbag) || S.throwpass)
											continue
										if (!S.density && !istype(S, /obj/structure/window/classic))
											continue
										canMove = FALSE
									if (canMove)
										AM.forceMove_nondenseturf(step)
									AM.hit_check(AM.speed)
									AM.error += AM.dist_y
									AM.dist_travelled++
								else
									var/atom/step = get_step(AM, AM.dy)
									if (!step) // going off the edge of the map makes get_step return null, don't let things go off the edge
										thrown_list -= AM
										continue
									if (map.check_caribbean_block(AM.thrower, get_turf(step)) && (!map.allow_bullets_through_blocks.Find(get_area(step):type) || ismob(AM)))
										if (istype(AM, /obj/item/weapon/grenade))
											var/obj/item/weapon/grenade/G = AM
											G.active = FALSE
										thrown_list -= AM
										continue
									var/canMove = TRUE
									for (var/obj/structure/S in step)
										if (istype(S, /obj/structure/window/sandbag) || S.throwpass)
											continue
										if (!S.density && !istype(S, /obj/structure/window/classic))
											continue
										canMove = FALSE
									if (canMove)
										AM.forceMove_nondenseturf(step)
									AM.hit_check(AM.speed)
									AM.error -= AM.dist_x
									AM.dist_travelled++

								AM.a = get_area(AM.loc)
							else
								AM.finished_throwing()

				catch (var/exception/e)
					catchException(e, AM)
					if (AM)
						AM.finished_throwing()
			else
				thrown_list -= AM
		else
			catchBadType(AM)
			thrown_list -= AM

		PROCESS_LIST_CHECK
		PROCESS_TICK_CHECK

/process/throwing/reset_current_list()
	PROCESS_USE_FASTEST_LIST(thrown_list)
	if (current_list.len > 100)
		current_list.len = min(current_list.len, 100)

/process/throwing/statProcess()
	..()
	stat(null, "[thrown_list.len] moving atoms")

/process/throwing/htmlProcess()
	return ..() + "[thrown_list.len] moving atoms"