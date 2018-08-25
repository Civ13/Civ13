#define NO_WINNER "The round is proceeding normally."
/obj/map_metadata/tribes
	ID = MAP_TRIBES
	title = "Tribes (225x225x2)"
//	lobby_icon_state = "pirates"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 6000 // 10 minutes!
	squad_spawn_locations = FALSE
	reinforcements = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		INDIANS,)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(INDIANS) = /area/caribbean/indians,
		)
	front = "Pacific"
	faction_distribution_coeffs = list(INDIANS = 1)
	battle_name = "Tribal village"
	var/targetnr = 2
	var/targetnr_text= "2"
	mission_start_message = "<big>A villager, apparently possessed by a demmonic force, has been murdering his fellow tribesmen! He must be caught before he manages to kill 2 tribesmen!</big><br>Bonus objective: He must steal the leader's crown."
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = INDIANS
	single_faction = TRUE
	var/message = ""

obj/map_metadata/tribes/job_enabled_specialcheck(var/datum/job/J)
	if (!(istype(J, /datum/job/indians/tribes)))
		. = FALSE
	else
		. = TRUE
	return .
/obj/map_metadata/tribes/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 0 || admin_ended_all_grace_periods)

/obj/map_metadata/tribes/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 0 || admin_ended_all_grace_periods)

/obj/map_metadata/tribes/cross_message(faction)
	return ""

/obj/map_metadata/tribes/reinforcements_ready()
	return (faction2_can_cross_blocks() && faction1_can_cross_blocks())

/obj/map_metadata/tribes/New()
	..()
	targetnr = max(1,round(clients.len/3))
	targetnr_text = num2text(targetnr)
	mission_start_message = "<big>A villager, apparently possessed by a demmonic force, has been murdering his fellow tribesmen! He must be caught before he manages to kill <b>[targetnr_text]</b> more people. <b>Attention</b>, people killed by others besides the possessed also count!</big><br>Bonus objective: He must steal the leader's crown."

/obj/map_metadata/tribes/update_win_condition()
	if (processes.ticker.playtime_elapsed >= 1200)
		if (dead_indians.len >= targetnr)
			for (var/mob/living/carbon/human/H in player_list)
				if (H.original_job && H.stat != DEAD && H.is_murderer == TRUE)
					message = "The possessed villager has managed to kill enough tribesmen! He has won the round!"
					world << "<font size = 4><span class = 'notice'>[message]</span></font>"
					return FALSE
		else
			for (var/mob/living/carbon/human/H in player_list)
				if (H.original_job && H.stat == DEAD && H.is_murderer == TRUE)
					message = "The possessed villager has been killed! The tribe won!"
					world << "<font size = 4><span class = 'notice'>[message]</span></font>"
					return FALSE
		ticker.finished = TRUE
		return FALSE
#undef NO_WINNER