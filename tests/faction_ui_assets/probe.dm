// Actual asset getter/register/send, Create Faction route and TGUI HTML.
// Only world/actor startup and the final browse boundary are adapted.
var/global/faction_ui_registrations = 0
var/global/faction_tgui_registrations = 0
var/global/datum/nanoui/tgui/faction_assets_probe/faction_ui_last
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

// The creation window is a tgui window: this probe checks the resources its
// page needs are registered on a cold lookup.
/datum/nanoui/tgui/faction_assets_probe
	var/captured_html

/datum/nanoui/tgui/faction_assets_probe/open()
	// No client, browse, winset or manager registration is simulated here.
	// Constructor, asset lookup, draft data and get_html remain production.
	faction_ui_last = src
	get_asset_datum(/datum/asset/simple/civ13_tgui)
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
	faction_ui_check(T.setup() && !faction_ui_registrations && !faction_tgui_registrations && !asset_cache.cache.len, "restored setup skips roundstart registration")
	register_asset("fixture-preserved.txt", 'UI/tgui/THIRD_PARTY.txt')
	var/preserved = asset_cache.cache["fixture-preserved.txt"]
	var/mob/living/human/faction_assets_probe/H = new(locate(2, 2, 1))
	H.name = "Synthetic Founder"
	H.civilization = "none"
	H.create_faction()
	faction_ui_check(istype(faction_ui_last), "actual creation route reaches browser boundary")
	var/datum/asset/simple/civ13_tgui/M = asset_datums[/datum/asset/simple/civ13_tgui]
	faction_ui_check(M && faction_tgui_registrations == 1, "cold TGUI lookup registers once")
	var/version = civ13_tgui_assets_version
	var/modern_files_present = length(version) > 0
	for (var/filename in list("civ13-tgui-bootstrap.js", "civ13-tgui.js", "civ13-tgui.css"))
		var/versioned_name = civ13_tgui_versioned_name(filename, version)
		if (!asset_cache.cache[filename] || !asset_cache.cache[versioned_name])
			modern_files_present = FALSE
	faction_ui_check(modern_files_present, "cold cache contains versioned modern assets")
	faction_ui_check(!asset_datums[/datum/asset/nanoui] && !faction_ui_registrations && !asset_cache.cache["libraries.min.js"], "modern open does not warm classic NanoUI")
	var/modern_size = asset_cache.cache.len
	var/cached_modern = get_asset_datum(/datum/asset/simple/civ13_tgui)
	if (M)
		M.send(null)
	faction_ui_check(M && cached_modern == M && faction_tgui_registrations == 1 && asset_cache.cache.len == modern_size, "repeat TGUI lookup and disconnected send do not register again")
	faction_ui_check(asset_cache.cache["fixture-preserved.txt"] == preserved, "existing cache entries preserved")
	var/initial_html = faction_ui_last?.captured_html
	var/bootstrap_file = civ13_tgui_versioned_name("civ13-tgui-bootstrap.js", version)
	faction_ui_check(initial_html && length(version) > 0 && findtext(initial_html, "src=\"[bootstrap_file]\"") && findtext(initial_html, "tgui-initial") && findtext(initial_html, "faction_creation.tmpl") && !findtext(initial_html, "nano_template.js"), "production HTML names required resources")
	faction_ui_check(faction_ui_last && faction_ui_last.initial_data["grid"].len == 1024 && H.civilization == "none" && !map.custom_faction_nr.len, "initial draft has full canvas without founding")
	if (faction_ui_last)
		text2file(faction_ui_last.captured_html, "browser/index.html")
		text2file(json_encode(faction_ui_last.initial_data), "draft.json")
		for (var/filename in asset_cache.cache)
			fcopy(asset_cache.cache[filename], "browser/[filename]")

	// Classic windows are separate: exercise their cold getter explicitly.
	var/datum/asset/nanoui/A = get_asset_datum(/datum/asset/nanoui)
	faction_ui_check(A && faction_ui_registrations == 1, "cold NanoUI lookup registers once")
	faction_ui_check(asset_cache.cache["libraries.min.js"] && asset_cache.cache["nano_template.js"] && asset_cache.cache["nano_state_manager.js"] && asset_cache.cache["faction_symbol.js"], "cold classic cache contains JavaScript")
	faction_ui_check(A && ("civ13_theme.css" in A.common) && ("faction_symbol.css" in A.common) && ("layout_basic.css" in A.common), "cold classic common contains styles")
	faction_ui_check(A && !("civ13-tgui.js" in A.common), "modern screen assets stay out of the common NanoUI set")
	var/size = asset_cache.cache.len
	for (var/i = 1, i <= 3, i++)
		faction_ui_check(get_asset_datum(/datum/asset/nanoui) == A, "repeat NanoUI lookup identity [i]")
	if (A)
		A.send(null)
	faction_ui_check(A && faction_ui_registrations == 1 && asset_cache.cache.len == size, "repeat NanoUI lookups and disconnected sends do not register again")
	H.civilization = "Existing Faction"
	var/datum/nanoui/previous = faction_ui_last
	H.create_faction()
	faction_ui_check(faction_ui_last == previous && !map.custom_faction_nr.len, "member gate and draft do not found a faction")
	var/before_hook = faction_ui_registrations
	var/before_modern_hook = faction_tgui_registrations
	var/hook/roundstart/round_hook = new
	round_hook.send_assets()
	var/datum/asset/nanoui/normal = get_asset_datum(/datum/asset/nanoui)
	var/datum/asset/simple/civ13_tgui/normal_modern = get_asset_datum(/datum/asset/simple/civ13_tgui)
	faction_ui_check(faction_ui_registrations == before_hook + 1 && faction_tgui_registrations == before_modern_hook + 1 && normal != A && normal_modern != M && asset_cache.cache["civ13-tgui.js"] && asset_cache.cache["fixture-preserved.txt"] == preserved, "normal roundstart remains registered and preserves cache")
	var/after_hook = faction_ui_registrations
	var/after_modern_hook = faction_tgui_registrations
	faction_ui_check(get_asset_datum(/datum/asset/nanoui) == normal && get_asset_datum(/datum/asset/simple/civ13_tgui) == normal_modern && faction_ui_registrations == after_hook && faction_tgui_registrations == after_modern_hook, "existing roundstart datums reused")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "check_count" = faction_ui_checks.len, "checks" = faction_ui_checks, "failed_labels" = faction_ui_failures, "cold_cache_size" = size, "registrations_after_roundstart" = faction_ui_registrations, "tgui_registrations_after_roundstart" = faction_tgui_registrations, "port" = port)), "result.json")
	world.log << "COMPLETE faction UI assets"
	del(world)
	return
