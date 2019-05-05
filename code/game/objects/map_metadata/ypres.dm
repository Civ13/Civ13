#define NO_WINNER "The fighting is still going on."
/obj/map_metadata/ypres
	ID = MAP_YPRES
	title = "2nd Battle of Ypres (75x75x1)"
	lobby_icon_state = "ww1"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 300
	squad_spawn_locations = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		BRITISH,
		FRENCH,
		GERMAN)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(BRITISH) = /area/caribbean/british/land/inside/objective,
		list(FRENCH) = /area/caribbean/french/land/inside/objective,
		list(GERMAN) = /area/caribbean/german/inside/objective
		)
	age = "1915"
	ordinal_age = 5
	faction_distribution_coeffs = list(BRITISH = 0.5, FRENCH = 0.5, GERMAN = 0.5)
	battle_name = "second battle of Ypres"
	mission_start_message = "<font size=4>The <b>German</b> and the <b>Allied</b> forces are facing eachother in the trenches near Ypres! Get ready for the battle! It will start in <b>5 minutes</b>.</font>"
	faction1 = BRITISH
	faction2 = GERMAN
	songs = list(
		"Yuki No Shingun:1" = 'sound/music/yuki_no_shingun.ogg')

/obj/map_metadata/ypres/New()
	..()
	spawn(1)
		faction1 = pick(BRITISH,FRENCH)
	faction_distribution_coeffs = list(faction1 = 0.5, GERMAN = 0.5)
	setup_autobalance(FALSE)
	spawn(2)
		if (faction1 == FRENCH)
			for (var/obj/structure/vending/ww1britapparel/BA in world)
				var/turf/T1 = get_turf(BA)
				new/obj/structure/vending/ww1frenchapparel(T1)
				qdel(BA)
			for (var/obj/structure/vending/ww1britweapons/BW in world)
				var/turf/T2 = get_turf(BW)
				new/obj/structure/vending/ww1frenchweapons(T2)
				qdel(BW)
			for (var/obj/structure/closet/crate/ww1/ammo_vickers/AB in world)
				var/turf/T3 = get_turf(AB)
				new/obj/structure/closet/crate/ww1/ammo_hotchkiss(T3)
				qdel(AB)
			for (var/obj/structure/closet/crate/ww1/grenades_british/GR in world)
				var/turf/T4 = get_turf(GR)
				new/obj/structure/closet/crate/ww1/grenades_french(T4)
				qdel(GR)
			for (var/obj/item/weapon/gun/projectile/automatic/stationary/modern/vickers/VK in world)
				var/turf/T5 = get_turf(VK)
				new/obj/item/weapon/gun/projectile/automatic/stationary/modern/hotchkiss1914(T5)
				qdel(VK)
			for (var/obj/structure/sign/flag/uk/UKF in world)
				var/turf/T6 = get_turf(UKF)
				new/obj/structure/sign/flag/french(T6)
				qdel(UKF)
			for (var/turf/floor/trench/A1 in world)
				var/area/A = get_area(A1)
				if (istype(A,/area/caribbean/british/land/inside))
					new/area/caribbean/french/land/inside(get_turf(A1))
				if (istype(A,/area/caribbean/british/land/outside))
					new/area/caribbean/french/land/outside(get_turf(A1))
				if (istype(A,/area/caribbean/british/land/outside/objective))
					new/area/caribbean/french/land/outside/objective(get_turf(A1))
			british_toggled = FALSE
			french_toggled = TRUE
		else
			british_toggled = TRUE
			french_toggled = FALSE
	spawn(30)
		world << "<font size=3>This battle will feature <b>[faction1]</b> and <b>[faction2]</b> troops.</font>"
/obj/map_metadata/ypres/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_ww1 == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/ypres/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/ypres/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)


	#undef NO_WINNER