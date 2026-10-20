// Actual asset getter/register/send, Create Faction route and NanoUI HTML.
// Only world/actor startup and the final browse boundary are adapted.
var/global/faction_ui_registrations = 0
var/global/datum/nanoui/faction_assets_probe/faction_ui_last
var/global/list/faction_ui_checks = list()
var/global/list/faction_ui_failures = list()

/world
	maxx = 3
	maxy = 3
	maxz = 1
	turf = /turf/faction_assets_probe
	area = /area/faction_assets_probe
	hub = ""
	visibility = 0

/world/OpenPort(port)
	return ..("none")

/world/Topic()
	return null

/area/faction_assets_probe
/turf/faction_assets_probe

/obj/map_metadata/faction_assets_probe
	nomads = TRUE

/obj/map_metadata/faction_assets_probe/New()
	return

/mob/living/human/faction_assets_probe/New()
	return

/datum/nanoui/faction_assets_probe
	var/captured_html

/datum/nanoui/faction_assets_probe/open()
	// No client, browse, winset or manager registration is simulated here.
	// Constructor, asset lookup, draft data and get_html remain production.
	faction_ui_last = src
	captured_html = get_html()

/proc/faction_ui_check(value, label)
	faction_ui_checks += list(list("label" = label, "passed" = !!value))
	if (!value)
		faction_ui_failures += label

/world/New()
	OpenPort("none")
	faction_ui_check(port == 0, "headless port closed")
	GLOB.nanomanager = new
	map = new /obj/map_metadata/faction_assets_probe
	asset_datums = list()
	asset_cache.cache = list()
	map_storage.round_restored = TRUE
	var/datum/controller/gameticker/T = new
	faction_ui_check(T.setup() && !faction_ui_registrations && !asset_cache.cache.len, "restored setup skips roundstart registration")
	register_asset("fixture-preserved.txt", 'UI/templates/layout_basic.tmpl')
	var/preserved = asset_cache.cache["fixture-preserved.txt"]
	var/mob/living/human/faction_assets_probe/H = new(locate(2, 2, 1))
	H.name = "Synthetic Founder"
	H.civilization = "none"
	H.create_faction()
	faction_ui_check(istype(faction_ui_last), "actual creation route reaches browser boundary")
	var/datum/asset/nanoui/A = asset_datums[/datum/asset/nanoui]
	faction_ui_check(A && faction_ui_registrations == 1, "cold lookup registers once")
	faction_ui_check(asset_cache.cache["libraries.min.js"] && asset_cache.cache["nano_template.js"] && asset_cache.cache["nano_state_manager.js"] && asset_cache.cache["faction_symbol.js"], "cold cache contains JavaScript")
	faction_ui_check(asset_cache.cache["faction_creation.tmpl"] && asset_cache.cache["layout_basic.tmpl"], "cold cache contains faction templates")
	faction_ui_check(A && ("civ13_theme.css" in A.common) && ("faction_symbol.css" in A.common) && ("layout_basic.css" in A.common), "cold common contains styles")
	faction_ui_check(A && !("faction_creation.tmpl" in A.common), "templates retain uncommon delivery policy")
	var/size = asset_cache.cache.len
	for (var/i = 1, i <= 3, i++)
		faction_ui_check(get_asset_datum(/datum/asset/nanoui) == A, "repeat lookup identity [i]")
		A.send(null, "faction_creation.tmpl")
	faction_ui_check(faction_ui_registrations == 1 && asset_cache.cache.len == size, "repeat lookup and disconnected sends do not register again")
	faction_ui_check(asset_cache.cache["fixture-preserved.txt"] == preserved, "existing cache entries preserved")
	if (faction_ui_last)
		faction_ui_check(findtext(faction_ui_last.captured_html, "faction_creation.tmpl") && findtext(faction_ui_last.captured_html, "layout_basic.tmpl") && findtext(faction_ui_last.captured_html, "faction_symbol.js"), "production HTML names required resources")
		faction_ui_check(faction_ui_last.initial_data["grid"].len == 1024 && H.civilization == "none" && !map.custom_faction_nr.len, "initial draft has full canvas without founding")
		text2file(faction_ui_last.captured_html, "browser/index.html")
		text2file(json_encode(faction_ui_last.initial_data), "draft.json")
		for (var/filename in asset_cache.cache)
			fcopy(asset_cache.cache[filename], "browser/[filename]")
	H.civilization = "Existing Faction"
	var/datum/nanoui/previous = faction_ui_last
	H.create_faction()
	faction_ui_check(faction_ui_last == previous && !map.custom_faction_nr.len, "member gate and draft do not found a faction")
	var/before_hook = faction_ui_registrations
	var/hook/roundstart/round_hook = new
	round_hook.send_assets()
	var/datum/asset/nanoui/normal = get_asset_datum(/datum/asset/nanoui)
	faction_ui_check(faction_ui_registrations == before_hook + 1 && normal != A && asset_cache.cache["faction_creation.tmpl"] && asset_cache.cache["fixture-preserved.txt"] == preserved, "normal roundstart remains registered and preserves cache")
	var/after_hook = faction_ui_registrations
	faction_ui_check(get_asset_datum(/datum/asset/nanoui) == normal && faction_ui_registrations == after_hook, "existing roundstart datum reused")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "check_count" = faction_ui_checks.len, "checks" = faction_ui_checks, "failed_labels" = faction_ui_failures, "cold_cache_size" = size, "registrations_after_roundstart" = faction_ui_registrations, "port" = port)), "result.json")
	world.log << "COMPLETE faction UI assets"
	del(world)
	return
