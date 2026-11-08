// Location blurb: when a player takes control of a character, a short
// typewriter line in the lower left reads the time, season, year, map and area.
// Based on CM-SS13's text_blurbs.dm (cmss13-devs/cmss13, AGPL-3.0), which is
// itself based on Nebula's (NebulaSS13/Nebula#357); reimplemented for Civ13.

/client/var/tmp/mob/location_blurb_mob = null

/obj/screen/text/location_blurb
	name = ""
	screen_loc = "WEST+1,SOUTH+2"
	maptext_height = 64
	maptext_width = 480
	layer = 21
	plane = HUD_PLANE

/proc/location_blurb_season()
	var/text = "[season]"
	if (!length(text))
		return ""
	if (text == uppertext(text))
		text = capitalize(lowertext(text))
	return text

/proc/location_blurb_text(area/A)
	var/list/first = list()
	if (time_of_day)
		first += clock_time()
	var/when = trim("[location_blurb_season()] [map ? map.age : ""]")
	if (when)
		first += when
	var/list/second = list()
	var/map_name = map && map.title ? "[map.title]" : ""
	if (map_name)
		second += map_name
	if (A)
		var/area_name = replacetext("[A.name]", "\improper", "")
		area_name = trim(area_name)
		if (area_name && area_name != map_name && lowertext(area_name) != "space")
			second += area_name
	var/list/lines = list()
	if (first.len)
		lines += jointext(first, ", ")
	if (second.len)
		lines += jointext(second, ", ")
	return jointext(lines, "\n")

// Shows the blurb once per client and character; a reconnect shows it again.
/mob/living/human/proc/show_location_blurb()
	if (!client || client.location_blurb_mob == src)
		return FALSE
	var/text = location_blurb_text(get_area(src))
	if (!text)
		return FALSE
	client.location_blurb_mob = src
	play_location_blurb(client, text)
	return TRUE

/proc/play_location_blurb(client/C, text, duration = 5 SECONDS)
	set waitfor = FALSE
	if (!C)
		return
	var/obj/screen/text/location_blurb/B = new
	C.screen += B
	var/style = "font-family: 'Courier New', monospace; font-size: 9px; color: #e8e2cf; -dm-text-outline: 1px #000000;"
	var/shown = ""
	for (var/i = 1 to length(text))
		if (!C)
			qdel(B)
			return
		var/c = copytext(text, i, i + 1)
		shown += (c == "\n") ? "<br>" : html_encode(c)
		B.maptext = "<span style=\"[style]\">[shown]</span>"
		sleep(0.5)
	sleep(duration)
	if (C)
		animate(B, alpha = 0, time = 1 SECOND)
		sleep(1 SECOND)
		if (C)
			C.screen -= B
	qdel(B)
