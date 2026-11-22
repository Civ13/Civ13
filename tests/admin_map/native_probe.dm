// Headless admin map probe. Test-only: native_probe.py appends it to a
// temporary copy of civ13.dme (default map) and runs it once in DreamDaemon.
// There is no client, so player bodies show as disconnected. It checks the
// staff guards, level picker data, marker states and sides, unnamed markers,
// sending and ending weather, the page and the refresh timer. The page is
// written to adminmap.html for a screenshot.
var/global/datum/admin_map_probe/admin_map_probe = new

/mob/living/human/admin_map_probe_actor
/mob/living/human/admin_map_probe_actor/ssd_check()
	return FALSE

/datum/admin_map_probe
	var/list/checks = list()
	var/phase = "startup"

/datum/admin_map_probe/New()
	if (!all_species || !all_species.len)
		makeDatumRefLists()
	if (!config)
		load_configuration()
		initialize_chemical_reagents()
		initialize_chemical_reactions()
	if (config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	spawn(10)
		drive()

/datum/admin_map_probe/proc/pass(name, list/details = null)
	checks += list(list("check" = name, "passed" = TRUE, "details" = details))

/datum/admin_map_probe/proc/require(condition, message)
	if (!condition)
		throw EXCEPTION(message)

/datum/admin_map_probe/proc/actor(turf/T, side, name, ckey)
	var/mob/living/human/admin_map_probe_actor/H = new(T)
	H.real_name = name
	H.name = name
	if (ckey)
		H.ckey = ckey
	if (map.civilizations)
		H.civilization = side || "none"
	else
		H.faction_text = side
	return H

/datum/admin_map_probe/proc/state_of(list/blips, mob/M)
	for (var/list/B in blips)
		if (B[7] == "\ref[M]")
			return B[3]
	return null

/datum/admin_map_probe/proc/drive()
	var/failure = null
	try
		var/until = world.time + 6000
		while (!(ticker && processScheduler && processes && map))
			if (world.time > until)
				throw EXCEPTION("world never reached pregame")
			sleep(5)
		phase = "permissions"
		require(!admin_map_allowed(null), "null client allowed")
		require(/client/proc/admin_map in admin_verbs_admin, "verb not in admin verbs")
		require(/client/proc/admin_map in admin_verbs_mod, "verb not in mod verbs")
		require(!(/client/proc/admin_map in admin_verbs_mentor), "mentors got the verb")
		pass("permissions")

		phase = "actors"
		var/z = world.maxz >= 2 && map.ID == MAP_NOMADS_GAIA ? 2 : 1
		var/other_z = z == 1 ? (world.maxz >= 2 ? 2 : 0) : 1
		var/cx = round(world.maxx / 2)
		var/cy = round(world.maxy / 2)
		var/side_a = map.civilizations ? "Probe Civ A" : (map.faction1 || "Probe A")
		var/side_b = map.civilizations ? "Probe Civ B" : (map.faction2 || "Probe B")
		var/mob/living/human/p1 = actor(locate(cx, cy, z), side_a, "Alpha Probe", "probealpha")
		var/mob/living/human/p2 = actor(locate(cx + 25, cy + 12, z), side_b, "Bravo </script> Probe", "probebravo")
		var/mob/living/human/p3 = actor(locate(cx - 20, cy - 15, z), side_a, "Charlie Probe", "probecharlie")
		p3.stat = DEAD
		var/mob/living/human/npc = actor(locate(cx + 8, cy - 6, z), null, "Npc Probe", null)
		var/mob/living/human/dead_npc = actor(locate(cx + 9, cy - 6, z), null, "Dead Npc Probe", null)
		dead_npc.stat = DEAD
		var/mob/living/human/elsewhere = other_z ? actor(locate(cx, cy, other_z), side_a, "Elsewhere Probe", "probeelse") : null

		phase = "levels"
		var/list/labels = admin_maps.level_labels()
		require(labels.len == world.maxz, "level labels [labels.len] != [world.maxz]")
		var/list/counts = admin_maps.level_counts()
		require(counts.len == world.maxz, "level counts [counts.len] != [world.maxz]")
		pass("levels", list("labels" = labels, "counts" = counts))

		phase = "blips"
		var/list/blips = admin_maps.blips_for(z, null)
		require(state_of(blips, p1) == "s", "disconnected player state [state_of(blips, p1)]")
		require(state_of(blips, p2) == "s", "second player state [state_of(blips, p2)]")
		require(state_of(blips, p3) == "x", "dead player state [state_of(blips, p3)]")
		require(state_of(blips, npc) == "n", "npc state [state_of(blips, npc)]")
		require(!state_of(blips, dead_npc), "dead NPC shown")
		if (elsewhere)
			require(!state_of(blips, elsewhere), "other level shown")
			require(state_of(admin_maps.blips_for(other_z, null), elsewhere) == "s", "other level missing its player")
		for (var/list/B in blips)
			if (B[7] == "\ref[p1]")
				require(B[1] == p1.x && B[2] == p1.y && B[4] == side_a && B[6] == "probealpha", "player row [json_encode(B)]")
			if (B[7] == "\ref[p2]")
				require(B[4] == side_b, "second side [json_encode(B)]")
			if (B[7] == "\ref[npc]")
				require(B[4] == "" && B[6] == "", "npc row [json_encode(B)]")

		var/list/unnamed = admin_maps.blips_for(z, null, FALSE)
		require(unnamed.len <= 3, "unnamed markers [unnamed.len]: more than the players") // connected players only; none here
		for (var/list/B in unnamed)
			require(B[3] == "p" && B[4] == "" && B[5] == "" && B[6] == "" && B[7] == "", "unnamed row leaks [json_encode(B)]")
		pass("blips", list("count" = blips.len))

		phase = "weather"
		require(!admin_map_sees_players(null) && !admin_map_changes_weather(null), "null client has rights")
		weather_systems_clear()
		require(admin_maps.send_weather(null, "storm", p2.x, p2.y), "storm not sent")
		require(admin_maps.send_weather(null, "heat", p3.x, p3.y), "heat wave not sent")
		var/list/systems = admin_maps.systems()
		require(systems.len == 2, "systems [systems.len]")
		var/list/first = systems[1]
		require(first.len == 11 && first[2] == WEATHER_SYSTEM_STORM && first[6] > 0 && first[7] > 0, "system row [json_encode(first)]")
		var/list/update = json_decode(admin_maps.update_json(null, z))
		for (var/key in list("b", "c", "s", "w", "a", "pc", "zone", "season", "cap", "who", "edit"))
			require(key in update, "update lacks [key]")
		require(update["who"] == 1 && update["edit"] == 0, "viewer flags [update["who"]] [update["edit"]]")
		var/list/air = update["a"]
		require(islist(air) && air.len == 7 && length(air[4]) == air[1] * air[2], "air grid shape")
		require(admin_maps.end_weather(null, first[1]) && length(admin_maps.systems()) == 1, "system not ended")
		require(!admin_maps.end_weather(null, -5), "ended a system that does not exist")
		require(admin_maps.send_weather(null, "severe", p1.x + 10, p1.y + 4), "severe storm not sent")
		// Bring the systems over the players so the screenshot shows them.
		for (var/datum/weather_system/S in weather_systems)
			S.origin_x = S.kind == WEATHER_SYSTEM_HEAT ? p3.x : p1.x + 14
			S.origin_y = S.kind == WEATHER_SYSTEM_HEAT ? p3.y : p1.y + 6
			S.origin_time = world.time
		pass("weather", list("systems" = admin_maps.systems()))

		phase = "page"
		var/list/base = tactical_maps.terrain_for(z)
		var/scale = clamp(round(760 / max(base[2], base[3])), 2, 8)
		var/html = admin_maps.page_html(null, z, base, scale, "\ref[p1]")
		require(findtext(html, "PICK=\"\ref[p1]\""), "picked mob not on the page")
		require(findtext(html, "var REF=") && findtext(html, "function upd("), "page script missing")
		require(findtext(html, "Alpha Probe"), "player missing from page")
		require(!findtext(html, "Bravo </script>"), "name can end the script block")
		require(findtext(html, "Bravo <\\/script>"), "escaped name missing")
		fdel("adminmap.html")
		text2file(html, "adminmap.html")
		pass("page", list("bytes" = length(html)))

		phase = "refresh"
		admin_maps.start()
		require(admin_maps.refresh_timer, "refresh timer not started")
		var/wait_until = world.time + 100
		while (admin_maps.refresh_timer && world.time < wait_until)
			sleep(5)
		require(!admin_maps.refresh_timer, "refresh timer kept running with no viewers")
		pass("refresh")
	catch (var/exception/E)
		failure = "[E.name]"
	var/list/result = list("passed" = !failure, "failure" = failure, "failed_phase" = failure ? phase : null, "map" = map ? map.ID : null, "checks" = checks)
	fdel("result.json")
	text2file(json_encode(result), "result.json")
	shutdown()
