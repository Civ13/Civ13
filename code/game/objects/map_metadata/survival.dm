/obj/map_metadata/survival
	ID = MAP_SURVIVAL
	title = "Survival (70x70x2)"
	lobby_icon_state = "su"
	prishtina_blocking_area_types = list(/area/prishtina/no_mans_land/invisible_wall/inside)
	allow_bullets_through_blocks = list(/area/prishtina/no_mans_land/invisible_wall/inside)
	event_faction = PILLARMEN
	min_autobalance_players = 100
	respawn_delay = 0
	valid_weather_types = list()
	reinforcements = FALSE
	no_subfaction_chance = FALSE
	subfaction_is_main_faction = TRUE
	roundend_condition_sides = list(
		list(CIVILIAN) = /area/prishtina/german/bunker, // faster than /area/prishtina/german, less subtypess - Kachnov
		list(PILLARMEN) = /area/prishtina/sewers)
	faction_organization = list(
		CIVILIAN,
		PILLARMEN)
	ambience = list()
	times_of_day = list("Night")
	zlevels_without_lighting = list(2)
	songs = list(
		"Dark Part 3 Michael Meara:1" = 'sound/music/dark.ogg')
	meme = FALSE

/obj/map_metadata/survival/specialfaction_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4500)

/obj/map_metadata/survival/announce_mission_start(var/preparation_time)
	world << "<font size=4>This is a Survival Map. You are a <b>Civilian</b>, who got lost inside the forest when running from the frontlines, but there is something very wrong going on here...<span class = 'danger'> Try to survive.</span></font>"

/obj/map_metadata/survival/job_enabled_specialcheck(var/datum/job/J)
	. = TRUE
	if (istype(J, /datum/job/partisan/civilian))
		J.total_positions = max(1, round(clients.len*3))
	if (istype(J, /datum/job/pillarman/vampire))
		J.total_positions = max(2, round(clients.len/3))
	if (istype(J, /datum/job/pillarman/pillarman))
		J.total_positions = 0
	return .

/obj/map_metadata/survival/cross_message(faction)
	if (faction == CIVILIAN)
		return "<font size = 4>A horrible chill runs down your spine...</font>"
	return "<font size = 4>The [faction_const2name(faction)] may now cross the invisible wall!</font>"


// pillarmap is special; the round ends ALMOST immediately when one faction has completely died: used to be immediately, but falling down counts as being dead so that's a thing
/obj/map_metadata/survival/short_win_time(faction)
	return 300

/obj/map_metadata/survival/long_win_time(faction)
	return 300

// avoid checking this too often, alive_n_of_side is expensive-ish
/obj/map_metadata/survival/win_condition_specialcheck()
	if (processes.ticker.ticks % 5 == 0)
		return (!alive_n_of_side(PILLARMEN) || !alive_n_of_side(CIVILIAN))
	return FALSE