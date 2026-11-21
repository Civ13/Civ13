// Headless admin player panel probe. Test-only: native_probe.py appends it to a
// temporary copy of civ13.dme (default map) and runs it once in DreamDaemon.
// There is no client, so player bodies show as disconnected. It builds the
// player list for an admin and for a mentor, and one player's panel for an
// admin and for a moderator, and checks what each may see. The pages are
// written to players.html, players_mentor.html and panel.html for screenshots.
var/global/datum/admin_player_panel_probe/admin_player_panel_probe = new

/mob/living/human/admin_player_panel_probe_actor
/mob/living/human/admin_player_panel_probe_actor/ssd_check()
	return FALSE

/datum/admin_player_panel_probe
	var/list/checks = list()
	var/phase = "startup"

/datum/admin_player_panel_probe/New()
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

/datum/admin_player_panel_probe/proc/pass(name, list/details = null)
	checks += list(list("check" = name, "passed" = TRUE, "details" = details))

/datum/admin_player_panel_probe/proc/require(condition, message)
	if (!condition)
		throw EXCEPTION(message)

/datum/admin_player_panel_probe/proc/actor(turf/T, side, name, ckey)
	var/mob/living/human/admin_player_panel_probe_actor/H = new(T)
	H.real_name = name
	H.name = name
	H.ckey = ckey
	H.lastKnownIP = "203.0.113.[rand(2, 250)]"
	if (map.civilizations)
		H.civilization = side || "none"
	else
		H.faction_text = side
	return H

/datum/admin_player_panel_probe/proc/drive()
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
		var/mob/living/human/p1 = actor(locate(cx, cy, z), "Riverfolk", "Alpha Probe", "probealpha")
		var/mob/living/human/p2 = actor(locate(cx + 25, cy + 12, z), "Hill Clan", "Bravo <script>x</script> Probe", "probebravo")
		var/mob/living/human/p3 = actor(locate(cx - 20, cy - 15, z), "Riverfolk", "Charlie Probe", "probecharlie")
		p3.stat = DEAD
		var/mob/living/human/p4 = actor(locate(cx - 4, cy + 30, z), "Hill Clan", "Delta Probe", "probedelta")
		p4.stat = UNCONSCIOUS
		p4.name = "Unknown"
		var/mob/observer/ghost/G = new(locate(cx + 3, cy + 3, z))
		G.name = "Echo Probe"
		G.real_name = "Echo Probe"
		G.ckey = "probeecho"
		actor(locate(cx + 8, cy - 6, z), null, "Npc Probe", null)

		notes_add("probealpha", "Argued with staff over a ruling.", null)
		notes_add("probealpha", "Returned stolen tools when asked.", null)
		shared_records.add("probealpha", "warning", list("text" = "Griefing a farm"), "probeadmin", "Admin")
		watchlist_add("probealpha", "Possible alt of a banned account", null)
		notes_add("probecharlie", "Helpful with new players.", null)
		karma_set_standing("probealpha", -1, "Repeated arguments", "probeadmin", "Admin")
		karma_rate("probebravo", "probealpha", "poorly", "took my axe")
		karma_rate("probecharlie", "probealpha", "kindly", "")

		var/datum/admins/admin = new("Probe Admin", R_ADMIN|R_MOD|R_SPAWN, "probeadmin")
		var/datum/admins/moderator = new("Probe Moderator", R_MOD, "probemod")
		var/datum/admins/mentor = new("Probe Mentor", R_MENTOR, "probementor")

		phase = "list"
		var/html = admin.player_list_html(null)
		fdel("players.html")
		text2file(html, "players.html")
		require(findtext(html, "Alpha Probe") && findtext(html, "Echo Probe"), "players missing from the list")
		require(!findtext(html, "Npc Probe"), "a mob without a key is listed")
		require(!findtext(html, "<script>x</script>"), "a name reached the page as HTML")
		require(findtext(html, "Bravo &lt;script&gt;x&lt;/script&gt; Probe"), "escaped name missing")
		require(findtext(html, "pill red'>watchlist") && findtext(html, "2 notes") && findtext(html, "1 warning"), "record badges missing")
		require(findtext(html, "203.0.113."), "address missing for staff")
		require(findtext(html, "data-s='dead dc flag'") && findtext(html, "data-s='down dc'") && findtext(html, "data-s='ghost dc'"), "state tags missing")
		require(findtext(html, "<div class='dim'>Delta Probe</div>"), "real name line missing")
		pass("list", list("bytes" = length(html)))

		phase = "mentor_list"
		var/mentor_html = mentor.player_list_html(null)
		fdel("players_mentor.html")
		text2file(mentor_html, "players_mentor.html")
		require(findtext(mentor_html, "Alpha Probe"), "mentor list empty")
		require(!findtext(mentor_html, "203.0.113."), "mentors see addresses")
		require(!findtext(mentor_html, "watchlist") && !findtext(mentor_html, "h played") && !findtext(mentor_html, "Has records"), "mentors see records")
		require(!findtext(mentor_html, "_src_=vars"), "mentors get variable links")
		pass("mentor_list")

		phase = "panel"
		var/panel = admin.player_options_html(p1, null)
		fdel("panel.html")
		text2file(panel, "panel.html")
		require(findtext(panel, "<h1>Alpha Probe</h1>") && findtext(panel, "probealpha"), "panel header missing")
		require(findtext(panel, "on the watchlist") && findtext(panel, "watchlist_remove=probealpha"), "records card missing")
		require(findtext(panel, "<b>2</b>notes") && findtext(panel, "<b>1</b>warnings"), "record counts wrong")
		require(findtext(panel, "admin standing") && findtext(panel, "karma_ckey=probealpha"), "karma card missing")
		require(findtext(panel, "boot2=\ref[p1]") && findtext(panel, "getmob=\ref[p1]") && findtext(panel, "toglang=\ref[p1]"), "actions missing")
		require(!findtext(panel, "simplemake"), "transformations offered for a body without a client")
		var/escaped = admin.player_options_html(p2, null)
		require(!findtext(escaped, "<script>x</script>"), "a name reached the panel as HTML")
		var/lobby_free = admin.player_options_html(G, null)
		require(findtext(lobby_free, "pill blue'>Ghost"), "ghost state missing")
		pass("panel", list("bytes" = length(panel)))

		phase = "rights"
		var/mod_panel = moderator.player_options_html(p1, null)
		require(findtext(mod_panel, "on the watchlist"), "moderators lost the records card")
		require(!findtext(mod_panel, "karma_ckey") && !findtext(mod_panel, "admin standing"), "moderators see hidden karma")
		pass("rights")
	catch (var/exception/E)
		failure = "[E.name]"
	var/list/result = list("passed" = !failure, "failure" = failure, "failed_phase" = failure ? phase : null, "map" = map ? map.ID : null, "checks" = checks)
	fdel("result.json")
	text2file(json_encode(result), "result.json")
	shutdown()
