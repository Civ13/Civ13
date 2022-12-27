
/obj/map_metadata/dvojka
	ID = MAP_DVOJKA
	title = "dvojka"
	lobby_icon = "icons/lobby/dvojka.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/one)
	respawn_delay = 1200

	faction_organization = list(
		NATO,
		WARPACT)

	roundend_condition_sides = list(
		list(WARPACT) = /area/caribbean/no_mans_land/capturable/two,
		list(NATO) = /area/caribbean/no_mans_land/capturable/one,
		)
	age = "2025"
	ordinal_age = 8
	faction_distribution_coeffs = list(NATO = 0.5, WARPACT = 0.5)
	battle_name = "A conflict on contested grounds"
	mission_start_message = "<font size=4>All factions have <b>6 minutes</b> to prepare before the ceasefire ends!<br></font>"
	faction1 = NATO
	faction2 = WARPACT
	grace_wall_timer = 3600
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	songs = list(
		"Red Army Choir - Katyusha:1" = "sound/music/katyusha.ogg",)

/obj/map_metadata/dvojka/roundend_condition_def2name(define)
	..()
	switch (define)
		if (NATO)
			return "Nato"
		if (WARPACT)
			return "Warpact"
/obj/map_metadata/dvojka/roundend_condition_def2army(define)
	..()
	switch (define)
		if (NATO)
			return "Natos"
		if (WARPACT)
			return "Warpacts"

/obj/map_metadata/dvojka/army2name(army)
	..()
	switch (army)
		if ("Nato")
			return "Nato"
		if ("Warpact")
			return "Warpact"

/obj/map_metadata/dvojka/cross_message(faction)
	if (faction == WARPACT)
		return "<font size = 4>Warpact may now cross the invisible wall!</font>"
	else if (faction == NATO)
		return "<font size = 4>Nato may now cross the invisible wall!</font>"

/obj/map_metadata/dvojka/reverse_cross_message(faction)
	if (faction == WARPACT)
		return "<span class = 'userdanger'>Warpact may no longer cross the invisible wall!</span>"
	else if (faction == NATO)
		return "<span class = 'userdanger'>Nato may no longer cross the invisible wall!</span>"

