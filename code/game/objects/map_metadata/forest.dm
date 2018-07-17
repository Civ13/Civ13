/obj/map_metadata/forest
	ID = MAP_FOREST
	title = "Forest (200x529x1)"
	prishtina_blocking_area_types = list(
		/area/prishtina/forest/north/invisible_wall,
		/area/prishtina/forest/south/invisible_wall,
		/area/prishtina/forest/south/invisible_wall2)
	allow_bullets_through_blocks = list(
		/area/prishtina/forest/south/invisible_wall)
	roundend_condition_sides = list(
		list(GERMAN, ITALIAN) = /area/prishtina/german,
		list(SOVIET) = /area/prishtina/soviet/bunker)
	uses_supply_train = TRUE
	uses_main_train = TRUE
	supply_points_per_tick = list(
		SOVIET = 1.00,
		GERMAN = 1.50)
	faction_organization = list(
		GERMAN,
		SOVIET,
		PARTISAN,
		CIVILIAN,
		ITALIAN)
	// lower chances because paratroopers are fun too. Todo: make paratroopers a subfaction
	available_subfactions = list(
		SCHUTZSTAFFEL = 25,
		ITALIAN = 25)
	faction_distribution_coeffs = list(GERMAN = 0.42, SOVIET = 0.58)
	zlevels_without_lighting = list(2, 3)
	battle_name = "Battle of Brest"

/obj/map_metadata/forest/germans_can_cross_blocks()
	return (mission_announced || admin_ended_all_grace_periods)

/obj/map_metadata/forest/soviets_can_cross_blocks()
	return ((mission_announced && mapcheck_train_arrived) || admin_ended_all_grace_periods)

/obj/map_metadata/forest/cross_message(faction)
	return "<font size = 4>The [faction_const2name(faction)] may now cross the invisible wall![(faction == SOVIET) ? " They cannot attack the German base until after 15 minutes!" : ""]</font>"

/obj/map_metadata/forest/announce_mission_start(var/preparation_time = 0)
	world << "<font size=4>The German assault has started after <b>[ceil(preparation_time / 600)] minutes</b> of preparation. The Soviet side may not attack until after <b>5 minutes</b>.</font><br>"

/* forest map is special because it has two PBs:
 	* The first ends at 15 minutes and stops the Germans from leaving their base/the Soviets from going North of the town
 	* The second ends at 30 minutes and stops the Soviets from entering the German base and areas very close to it
*/

#define GRACE_WALL_2_MAX_Y 420
/obj/map_metadata/forest/check_prishtina_block(var/mob/living/carbon/human/H, var/turf/T)
	. = ..(H, T)
	if (!.)
		if (H.original_job && list(SOVIET, PARTISAN, CIVILIAN).Find(H.original_job.base_type_flag()))
			if ((T.y >= GRACE_WALL_2_MAX_Y || istype(get_area(T), /area/prishtina/german/train_zone)) && processes.ticker.playtime_elapsed < mission_announced + 9000) // because H.y >= 420 causes magical teleportation
				return TRUE
	return .

/obj/map_metadata/forest/special_relocate(var/mob/M)
	if (ishuman(M))
		var/mob/living/carbon/human/H = M
		var/check = FALSE
		while (H.y >= GRACE_WALL_2_MAX_Y)
			--H.y
			check = TRUE
		return check
	return FALSE

#undef GRACE_WALL_2_MAX_Y