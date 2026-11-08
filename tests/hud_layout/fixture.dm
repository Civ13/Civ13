// Native fixture for the HUD layout helpers and the production text save.
// run.py appends the helper half of hud_layout.dm and the production
// preferences save file; nothing else from the game is compiled.
#define TRUE 1
#define FALSE 0
#define SPAN_WARNING(T) T
#define SPAN_NOTICE(T) T
/world
	maxx = 1
	maxy = 1
	maxz = 1
	visibility = 0
	hub = ""
	hub_password = ""
var/list/hud_failures = list()
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return 0
/world/IsBanned(key, address, computer_id, type, real_bans_only)
	return TRUE
/world/Error(exception/e)
	world.log << "FAIL runtime: [e] [e.file]:[e.line]"
	del(world)
/obj/screen
/obj/item
/proc/trim(text)
	while (length(text) && copytext(text, 1, 2) == " ")
		text = copytext(text, 2)
	while (length(text) && copytext(text, length(text)) == " ")
		text = copytext(text, 1, length(text))
	return text
/proc/isemptylist(list/L)
	return !islist(L) || !L.len
/proc/dd_hassuffix(text, suffix)
	return copytext(text, length(text) - length(suffix) + 1) == suffix
/proc/sanitize_client_fps(value)
	return value
/proc/get_trait_selection_error(list/traits)
	return null
/proc/to_chat(target, text)
	return
/proc/capitalize(text)
	return text
/proc/random_name(gender, species)
	return "Tester"
/datum/hud_client
	var/key = "hud_test"
	var/datum/preferences/prefs
/datum/hud_client/proc/apply_client_fps_preference()
	return
/datum/hud_client/proc/apply_action_keybindings()
	return
/datum/preferences
	var/datum/hud_client/client
	var/client_ckey = "hud_test"
	var/real_name = "Tester"
	var/client_fps = 100
	var/list/traits = list()
	var/list/preferences_disabled = list()
	var/list/preferences_enabled = list()
	var/gender
	var/species
/datum/preferences/proc/update_setup()
	return
/datum/preferences/proc/sanitize_action_keybindings()
	return
/proc/check(value, message)
	if (!value)
		hud_failures += message
/proc/loc_text(list/L)
	return L ? jointext(L, "|") : "null"
// The live default HUD positions (pixels from the lower-left, 15x15 view).
var/list/default_hud_tiles = list(
	"health" = list(448, 192), "nutrition" = list(448, 160), "bodytemp" = list(448, 256), "mood" = list(448, 224),
	"throw" = list(416, 32), "pull" = list(416, 32), "resist" = list(416, 32), "drop" = list(416, 32), "m_intent" = list(416, 0),
	"equip" = list(192, 32), "swap" = list(192, 32), "intent" = list(368, 0), "help" = list(352, 0), "harm" = list(384, 0),
	"zone" = list(448, 0), "rzone" = list(448, 64), "fixeye" = list(448, 77), "gunmode" = list(96, 32), "move" = list(128, 32),
	"itemuse" = list(160, 32), "inventory" = list(0, 0), "mode" = list(288, 0), "secondary" = list(320, 0), "tactic" = list(256, 0),
	"inv14" = list(32, 64), "inv13" = list(32, 32), "inv2" = list(64, 64), "inv10" = list(0, 64), "inv8" = list(0, 96),
	"inv20" = list(64, 96), "inv11" = list(32, 128), "inv12" = list(0, 32), "inv1" = list(160, 0), "inv22" = list(128, 0),
	"inv9" = list(32, 96), "inv7" = list(64, 32), "inv15" = list(32, 0), "inv16" = list(64, 0), "inv6" = list(96, 0),
	"inv4" = list(224, 0), "inv5" = list(192, 0))
/proc/hud_rects_overlap(list/A, list/B, s)
	return A[1] < B[1] + s - 0.01 && B[1] < A[1] + s - 0.01 && A[2] < B[2] + s - 0.01 && B[2] < A[2] + s - 0.01
// Reflows the default HUD at scale g; returns a failure text or null.
/proc/check_reflow(g)
	var/view = 480
	var/list/flow = list()
	var/list/tiles = list()
	for (var/name in default_hud_tiles)
		var/list/P = default_hud_tiles[name]
		var/obj/screen/S = new
		S.name = name
		var/list/D = hud_infer_anchor(list("WEST", P[1], "SOUTH", P[2]), view, view)
		flow += list(list(S, hud_anchor_origin(D[1], view) + D[2], hud_anchor_origin(D[3], view) + D[4]))
		tiles[S] = P
	hud_reflow(flow, g, view, view)
	var/s = 32 * g
	var/list/placed = list()
	for (var/obj/screen/S in tiles)
		var/list/R = list(hud_anchor_origin(S.hud_ax, view) + S.hud_ox, hud_anchor_origin(S.hud_ay, view) + S.hud_oy)
		if (R[1] < -0.01 || R[2] < -0.01 || R[1] + s > view + 0.01 || R[2] + s > view + 0.01)
			return "[S.name] off screen at [g]"
		placed[S] = R
	for (var/obj/screen/A in placed)
		for (var/obj/screen/B in placed)
			if (A == B || A.name > B.name)
				continue
			if (hud_rects_overlap(tiles[A], tiles[B], 32))
				continue // tiles that already share a spot at 100% keep sharing it
			if (hud_rects_overlap(placed[A], placed[B], s))
				return "[A.name] covers [B.name] at [g]"
	return null
/world/New()
	OpenPort("none")
	check(port == 0 && byond_version == 516 && byond_build == 1688, "pin and closed port")
	// Default HUD positions from _defines.dm parse to anchor + lower-left pixel offset.
	check(loc_text(hud_parse_screen_loc("EAST-1:28,7:5")) == "EAST|-36|SOUTH|197", "east-anchored health: [loc_text(hud_parse_screen_loc("EAST-1:28,7:5"))]")
	check(loc_text(hud_parse_screen_loc("WEST+6:16,2:5")) == "WEST|208|SOUTH|37", "west-anchored swap hand")
	check(loc_text(hud_parse_screen_loc("14,2")) == "WEST|416|SOUTH|32", "plain tile numbers")
	check(loc_text(hud_parse_screen_loc("EAST:-16,2")) == "EAST|-48|SOUTH|32", "pixel-only east")
	check(loc_text(hud_parse_screen_loc("CENTER-7,CENTER-7")) == "CENTER|-240|CENTER|-240", "centre anchor")
	check(!hud_parse_screen_loc("WEST,SOUTH to EAST,NORTH"), "ranges are not editable")
	check(!hud_parse_screen_loc(null), "missing loc")
	// Writing an anchor back gives the same on-screen place.
	check(hud_axis_text("EAST", -36) == "EAST:-4", "east text")
	check(hud_axis_text("WEST", 208) == "WEST:208", "west text")
	check(hud_axis_text("CENTER", -240) == "CENTER:-224", "centre text")
	var/list/again = hud_parse_screen_loc("[hud_axis_text("EAST", -36)],[hud_axis_text("NORTH", -70)]")
	check(loc_text(again) == "EAST|-36|NORTH|-70", "round trip [loc_text(again)]")
	// Scale matrices keep the lower-left corner fixed and are recognised.
	check(hud_scale_matrix(1) == null, "unit scale is identity")
	var/matrix/M = hud_scale_matrix(1.5)
	check(M.a == 1.5 && M.e == 1.5 && M.c == 8 && M.f == 8, "1.5x lower-left anchored")
	check(is_hud_scale_matrix(M), "own matrix recognised")
	check(is_hud_scale_matrix(matrix()), "identity recognised")
	check(is_hud_scale_matrix(null), "null recognised")
	check(!is_hud_scale_matrix(turn(matrix(), 45)), "rotation preserved")
	check(!is_hud_scale_matrix(matrix(2, 0, 0, 0, 2, 0)), "centre scale preserved")
	var/obj/item/I = new
	var/obj/screen/S = new
	S.transform = hud_scale_matrix(2)
	hud_scale_item(I, S)
	check(I.transform.a == 2 && I.transform.c == 16, "item takes slot scale")
	hud_unscale_item(I)
	check(I.transform.a == 1 && I.transform.c == 0, "dropped item unscaled")
	I.transform = turn(matrix(), 90)
	hud_scale_item(I, S)
	hud_unscale_item(I)
	check(I.transform.b != 0, "item rotation untouched")
	// Mouse parameters, with and without a map control prefix.
	check(loc_text(hud_mouse_pixels("screen-loc=mapwindow.map:14:20,3:5")) == "436|69", "prefixed mouse loc")
	check(loc_text(hud_mouse_pixels("screen-loc=1:1,1:1")) == "1|1", "plain mouse loc")
	check(!hud_mouse_pixels("icon-x=3"), "missing mouse loc")
	check(hud_anchor_origin("EAST", 480) == 480 && hud_anchor_origin("CENTER", 480) == 240 && hud_anchor_origin("WEST", 480) == 0, "anchor origins")
	// Layout entries are per style and per tile, and survive the production text save.
	var/datum/preferences/P = new
	var/datum/hud_client/C = new
	P.client = C
	C.prefs = P
	P.set_hud_layout_entry("1713Style", "need:health", list("1713Style", "need:health", "WEST", "12.5", "NORTH", "-40", "1.5", "1"))
	P.set_hud_layout_entry("1713Style", "inv:1", list("1713Style", "inv:1", "D", "0", "D", "0", "2", "0"))
	P.set_hud_layout_entry("NewStyle", "need:health", list("NewStyle", "need:health", "EAST", "-36", "SOUTH", "0", "1", "0"))
	P.set_hud_layout_entry("1713Style", "need:health", list("1713Style", "need:health", "WEST", "10", "NORTH", "-40", "1.5", "1"))
	check(P.hud_layout.len == 3, "one entry per style and tile")
	var/list/F = P.hud_layout_entry("1713Style", "need:health")
	check(F && F[4] == "10" && F[8] == "1", "entry replaced")
	check(!P.hud_layout_entry("1713Style", "need:mood"), "absent entry")
	P.set_hud_layout_entry("1713Style", "inv:1", null)
	check(P.hud_layout.len == 2, "entry removed")
	P.hud_scale = 1.25
	P.save_preferences()
	var/datum/preferences/Q = new
	var/datum/hud_client/D = new
	Q.client = D
	D.prefs = Q
	check(Q.load_preferences(), "production text save round trip")
	check(Q.hud_scale == 1.25, "scale saved: [Q.hud_scale]")
	check(jointext(Q.hud_layout, "|") == jointext(P.hud_layout, "|"), "layout saved: [jointext(Q.hud_layout, "|")]")
	F = Q.hud_layout_entry("NewStyle", "need:health")
	check(F && F[3] == "EAST" && F[4] == "-36", "loaded entry readable")
	Q.hud_scale = 9
	Q.sanitize_hud_scale()
	check(Q.hud_scale == 1, "out-of-range scale reset")
	Q.hud_layout = list("", "junk", "1713Style~need:mood~WEST")
	check(!Q.hud_layout_entry("1713Style", "need:mood"), "malformed entries ignored")
	// Default tiles keep the edge they sit on, so small scales stay in the corners.
	check(loc_text(hud_infer_anchor(list("WEST", 448, "SOUTH", 192), 480, 480)) == "EAST|-32|CENTER|-48", "right column anchors east: [loc_text(hud_infer_anchor(list("WEST", 448, "SOUTH", 192), 480, 480))]")
	check(loc_text(hud_infer_anchor(list("WEST", 0, "SOUTH", 0), 480, 480)) == "WEST|0|SOUTH|0", "lower-left stays west/south")
	check(loc_text(hud_infer_anchor(list("WEST", 224, "SOUTH", 0), 480, 480)) == "CENTER|-16|SOUTH|0", "middle hand anchors centre")
	for (var/g in list(1.25, 1.5, 1.75, 2))
		var/err = check_reflow(g)
		check(!err, "reflow: [err]")
	if (hud_failures.len)
		world.log << "FAIL hud layout: [jointext(hud_failures, "; ")]"
		del(world)
		return
	world.log << "PASS hud layout: screen_loc parsing, anchor text, scale matrices, item scale ownership, mouse params, per-style entries, production text save/load, inferred anchors, reflow without overlap at 125-200%"
	del(world)
