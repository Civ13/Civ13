// Headless tactical map probe. Test-only: native_probe.py appends it to a
// temporary copy of civ13.dme (default map) and runs it once in DreamDaemon.
// It spawns a few humans on two sides, opens nothing on a client (there is
// none), and checks the side filter, terrain sampling, marker permissions and
// the page the map sends. The page is written to tacmap.html for a screenshot.
var/global/datum/tactical_map_probe/tactical_map_probe = new

/mob/living/human/tactical_map_probe_actor
/mob/living/human/tactical_map_probe_actor/ssd_check()
	return FALSE

/datum/job/tactical_map_probe_officer
	title = "Probe officer"
	is_officer = TRUE
/datum/job/tactical_map_probe_leader
	title = "Probe squad leader"
	is_squad_leader = TRUE
/datum/job/tactical_map_probe_trooper
	title = "Probe trooper"

/datum/tactical_map_probe
	var/list/checks = list()
	var/phase = "startup"

/datum/tactical_map_probe/New()
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

/datum/tactical_map_probe/proc/pass(name, list/details = null)
	checks += list(list("check" = name, "passed" = TRUE, "details" = details))

/datum/tactical_map_probe/proc/require(condition, message)
	if (!condition)
		throw EXCEPTION(message)

/datum/tactical_map_probe/proc/actor(turf/T, side, jobtype, name)
	var/mob/living/human/tactical_map_probe_actor/H = new(T)
	H.real_name = name
	H.name = name
	H.original_job = new jobtype
	if (map.civilizations)
		H.civilization = side
	else
		H.faction_text = side
	return H

/datum/tactical_map_probe/proc/drive()
	var/failure = null
	try
		var/until = world.time + 6000
		while (!(ticker && processScheduler && processes && map))
			if (world.time > until)
				throw EXCEPTION("world never reached pregame")
			sleep(5)
		phase = "actors"
		var/z = world.maxz >= 2 && map.ID == MAP_NOMADS_GAIA ? 2 : 1
		var/cx = round(world.maxx / 2)
		var/cy = round(world.maxy / 2)
		var/side_a = map.civilizations ? "Probe Civ A" : (map.faction1 || "Probe A")
		var/side_b = map.civilizations ? "Probe Civ B" : (map.faction2 || "Probe B")
		var/mob/living/human/officer = actor(locate(cx, cy, z), side_a, /datum/job/tactical_map_probe_officer, "Officer Probe")
		var/mob/living/human/leader = actor(locate(cx + 20, cy + 10, z), side_a, /datum/job/tactical_map_probe_leader, "Leader Probe")
		leader.squad = 2
		var/mob/living/human/trooper = actor(locate(cx - 15, cy - 12, z), side_a, /datum/job/tactical_map_probe_trooper, "Trooper Probe")
		var/mob/living/human/trooper2 = actor(locate(cx + 30, cy - 25, z), side_a, /datum/job/tactical_map_probe_trooper, "Trooper Two")
		var/mob/living/human/enemy = actor(locate(cx + 5, cy + 5, z), side_b, /datum/job/tactical_map_probe_officer, "Enemy Probe")
		var/mob/living/human/stranger = actor(locate(cx + 8, cy + 3, z), null, /datum/job/tactical_map_probe_officer, "Stranger Probe")
		if (map.civilizations)
			stranger.civilization = "none"
		else
			stranger.faction_text = null

		phase = "permissions"
		require(tactical_map_can_draw(officer) && tactical_map_can_view(officer), "officer cannot draw")
		require(!tactical_map_can_draw(leader) && tactical_map_can_view(leader), "squad leader rights wrong")
		require(!tactical_map_can_view(trooper), "trooper can view")
		officer.make_tactical_map_user()
		leader.make_tactical_map_user()
		trooper.make_tactical_map_user()
		require((/mob/living/human/proc/Tactical_Map in officer.verbs) && (/mob/living/human/proc/Tactical_Map in leader.verbs), "verb missing")
		require(!(/mob/living/human/proc/Tactical_Map in trooper.verbs), "trooper got the verb")
		require(tactical_map_side(stranger) == null, "sideless human has a side")
		pass("permissions")

		phase = "terrain"
		var/started = world.timeofday
		var/list/base = tactical_maps.terrain_for(z)
		var/ms = (world.timeofday - started) * 100
		require(length(base[4]) == base[2] * base[3], "terrain length [length(base[4])] != [base[2]]x[base[3]]")
		require(base[2] <= 160 && base[3] <= 160, "terrain too large")
		var/list/counts = list()
		for (var/i in 1 to length(base[4]))
			var/c = copytext(base[4], i, i + 1)
			counts[c] = (counts[c] || 0) + 1
		require(counts.len >= 2, "terrain has a single class")
		require(tactical_maps.terrain_for(z) == base, "terrain not cached")
		pass("terrain", list("cell" = base[1], "cols" = base[2], "rows" = base[3], "bytes" = length(base[4]), "ms" = ms, "classes" = counts))

		phase = "blips"
		var/key = tactical_maps.view_key(officer)
		require(key == null, "client-less officer got a view key")
		var/side = tactical_map_side(officer)
		key = "[side]|[z]"
		var/list/blips = tactical_maps.blips_for(side, z, officer)
		var/list/kinds = list()
		for (var/list/B in blips)
			kinds += B[3]
		require(blips.len == 4, "expected 4 own blips, got [blips.len]: [json_encode(blips)]")
		require(("y" in kinds) && ("s" in kinds) && ("u" in kinds), "blip kinds [json_encode(kinds)]")
		for (var/list/B in blips)
			require(!(B[1] == enemy.x && B[2] == enemy.y), "enemy shown")
			if (B[3] == "s")
				require(B[4] == "2", "squad label missing")
		trooper2.stat = UNCONSCIOUS
		blips = tactical_maps.blips_for(side, z, officer)
		var/downs = 0
		for (var/list/B in blips)
			if (B[3] == "d")
				downs++
		require(downs == 1, "downed trooper not shown as down")
		trooper2.stat = CONSCIOUS
		pass("blips", list("count" = blips.len))

		phase = "markers"
		require(tactical_maps.side_key(officer) == key, "side key [tactical_maps.side_key(officer)] != [key]")
		require(tactical_maps.add_marker(officer, "[cx + 10]", "[cy + 10]", "attack"), "officer could not mark")
		require(!tactical_maps.add_marker(officer, "[cx]", "[cy]", "defend"), "cooldown not applied")
		sleep(11)
		require(tactical_maps.add_marker(officer, "[cx - 20]", "[cy]", "rally"), "second mark failed")
		require(!tactical_maps.add_marker(leader, "[cx]", "[cy]", "attack"), "squad leader could mark")
		require(!tactical_maps.add_marker(officer, "[cx]", "[cy]", "nuke"), "unknown kind accepted")
		require(!tactical_maps.add_marker(officer, "0", "[cy]", "attack"), "out of bounds accepted")
		require(!tactical_maps.add_marker(officer, "abc", "[cy]", "attack"), "bad number accepted")
		require(tactical_maps.marker_list(key).len == 2, "marker count")
		require(tactical_maps.marker_list("[tactical_map_side(enemy)]|[z]").len == 0, "enemy sees our markers")
		sleep(11)
		require(tactical_maps.add_marker(enemy, "[cx]", "[cy]", "danger"), "enemy could not mark own map")
		require(tactical_maps.marker_list(key).len == 2, "enemy marker leaked")
		require(!tactical_maps.erase_marker(officer, "[cx + 40]", "[cy + 40]"), "erased out of reach")
		require(tactical_maps.erase_marker(officer, "[cx + 12]", "[cy + 9]"), "erase near marker failed")
		require(tactical_maps.marker_list(key).len == 1, "erase removed wrong count")
		for (var/i in 1 to 30)
			tactical_maps.last_mark.Cut()
			tactical_maps.add_marker(officer, "[cx + i]", "[cy]", "objective")
		require(tactical_maps.marker_list(key).len == 24, "marker cap")
		pass("markers")

		phase = "page"
		tactical_maps.marker_list(key).Cut()
		tactical_maps.last_mark.Cut()
		tactical_maps.add_marker(officer, "[cx + 22]", "[cy + 14]", "attack")
		tactical_maps.last_mark.Cut()
		tactical_maps.add_marker(officer, "[cx - 18]", "[cy - 10]", "defend")
		tactical_maps.last_mark.Cut()
		tactical_maps.add_marker(officer, "[cx + 30]", "[cy - 30]", "danger")
		tactical_maps.last_mark.Cut()
		tactical_maps.add_marker(officer, "[cx - 2]", "[cy + 3]", "rally")
		var/scale = clamp(round(640 / max(base[2], base[3])), 2, 8)
		var/html = tactical_maps.page_html(officer, key, base, scale)
		require(findtext(html, "var REF=") && findtext(html, "function upd("), "page script missing")
		require(!findtext(html, "Enemy Probe"), "enemy name in page")
		fdel("tacmap.html")
		text2file(html, "tacmap.html")
		pass("page", list("bytes" = length(html)))

		phase = "refresh"
		tactical_maps.viewers[officer] = key
		tactical_maps.start()
		require(tactical_maps.refresh_timer, "refresh timer not started")
		var/wait_until = world.time + 100
		while (tactical_maps.refresh_timer && world.time < wait_until)
			sleep(5)
		require(!(officer in tactical_maps.viewers), "client-less viewer kept")
		require(!tactical_maps.refresh_timer, "refresh timer kept running with no viewers")
		pass("refresh")
	catch (var/exception/E)
		failure = "[E.name]"
	var/list/result = list("passed" = !failure, "failure" = failure, "failed_phase" = failure ? phase : null, "map" = map ? map.ID : null, "checks" = checks)
	fdel("result.json")
	text2file(json_encode(result), "result.json")
	shutdown()
