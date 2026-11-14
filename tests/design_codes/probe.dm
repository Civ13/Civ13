// Native design codes probe, included by tests/ecology_spawning/run_linux.py, never
// by the game DME. It drives code/modules/paintings/design_codes.dm and the flag,
// pole flag and tailoring codes.
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/code_probe/New()
	map = src
/mob/living/human/code_probe/New()
	icon_update = FALSE
	return
var/code_failures = 0
var/code_runtime_error = FALSE
/proc/code_check(condition, label)
	if (!condition)
		code_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	code_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/code_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(20, 20, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		code_art_checks()
		code_flag_checks()
		code_pole_checks()
		code_cloth_checks()
	catch(var/exception/e)
		code_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = code_failures, "runtime_error" = code_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/code_art_checks()
	var/plain = painting_repeat("0", 8) + "1212" + painting_repeat("1", 4)
	var/packed = painting_pack(plain)
	var/code = painting_design_code(4, 4, "#e9dfc8,#1E1B19,#7d2f1e", packed)
	code_check(code == "C13ART/1/4x4/e9dfc8,1e1b19,7d2f1e/[packed]", "a picture exports as C13ART ([code])")
	var/list/A = painting_parse_design_code(code)
	code_check(A && A["w"] == 4 && A["h"] == 4 && A["palette"] == "#e9dfc8,#1e1b19,#7d2f1e" && A["plain"] == plain, "a picture code reads back unchanged")
	code_check(painting_parse_design_code(" c13art/1/4x4/\ne9dfc8,1e1b19,7d2f1e/[packed] ") != null, "spaces, line breaks and lower case in the prefix are forgiven")
	code_check(isnull(painting_parse_design_code("C13ART/1/129x4/e9dfc8/0~516.")), "a picture wider than 128 is refused")
	code_check(isnull(painting_parse_design_code("C13ART/1/4x4/e9dfc8/[packed]")), "a pixel past the palette is refused")
	code_check(isnull(painting_parse_design_code("C13ART/1/4x4/e9dfc8,1e1b19,7d2f1e/0~99.")), "a wrong pixel count is refused")
	code_check(isnull(painting_parse_design_code("C13ART/1/4x4/" + jointext(painting_palette_hex_list(17), ",") + "/0~16.")), "more than 16 colours are refused")
	code_check(isnull(painting_parse_design_code("C13ART/2/4x4/e9dfc8/0~16.")), "an unknown version is refused")
	code_check(isnull(painting_parse_design_code("C13FLAG/1/f_white/-/-/-/-/-/-/-/-")), "a flag code is not a picture")
	code_check(findtext(design_code_refusal("C13FLAG/1/x", "ART"), "flag from the flag maker"), "a code of the wrong kind says what it is for")
	// The painter, and only the painter, sees a finished picture's code.
	var/mob/living/human/code_probe/H = new(locate(5, 5, 1))
	code_check(!painting_code_allowed(H, "someone"), "a mob without a client never gets a code box")
	code_check(findtext(painting_code_box(code), "C13ART/1/4x4/"), "the code box carries the code")
	// Imports are marked and logged once.
	var/obj/item/canvas/table/C = new(H)
	new /obj/item/pigment/charcoal(H)
	var/count = C.canvas_w * C.canvas_h
	var/pal = "[C.base_colour],#1e1b19"
	var/before = design_code_import_log.len
	code_check(C.accept_painting(H, painting_pack(painting_repeat("1", 10) + painting_repeat("0", count - 10)), pal, FALSE, "", TRUE) == "Saved." && C.imported_design, "an imported save is kept and marked")
	C.accept_painting(H, painting_pack(painting_repeat("1", 12) + painting_repeat("0", count - 12)), pal, FALSE, "", TRUE)
	code_check(design_code_import_log.len == before + 1 && findtext(design_code_import_log[design_code_import_log.len], "picture design code"), "an imported picture is logged once for staff")
	code_check(C.accept_painting(H, painting_pack(painting_repeat("0", count)), "[C.base_colour],#0000ff", FALSE, "", TRUE) != "Saved.", "an imported picture still needs the pigments")
	text2file(painting_editor_html(H, C, painting_allowed_colours(H, C)), "editor.html")
	qdel(C)
	qdel(H)

/proc/painting_palette_hex_list(n)
	var/list/out = list()
	for (var/i = 1, i <= n, i++)
		out += copytext(lowertext(rgb(i * 10, 0, 0)), 2)
	return out

/proc/code_flag_checks()
	var/list/layers = list("f_blue", null, null, "f1_red", null, "f3_red", null, null, "e_star1")
	var/code = flagmaker_code(layers)
	code_check(code == "C13FLAG/1/f_blue/-/-/f1_red/-/f3_red/-/-/e_star1", "a flag exports its layers ([code])")
	var/list/back = flagmaker_parse(code)
	code_check(back ~= layers, "a flag code reads back unchanged")
	code_check(isnull(flagmaker_parse("C13FLAG/1/-/-/-/-/-/-/-/-/-")), "a flag needs a background")
	code_check(isnull(flagmaker_parse("C13FLAG/1/f_blue/fl_red/-/-/-/-/-/-/e_skull9")), "an unknown symbol is refused")
	code_check(isnull(flagmaker_parse("C13FLAG/1/f_blue/f1_red/-/-/-/-/-/-/-")), "a layer in the wrong place is refused")
	code_check(isnull(flagmaker_parse("C13FLAG/1/f_blue/-/-/-/-/-/-/-")), "a flag code with a layer missing is refused")
	var/obj/structure/sign/flag/custom/F = new(locate(6, 6, 1))
	code_check(F.apply_design(back) && F.icon_state == "f_blue" && F.overlays.len == 3 && F.design_code == code, "a flag from a code draws its cloth and three layers")
	F.overlays.Cut()
	F.after_load()
	code_check(F.overlays.len == 3, "a saved flag draws its design again after loading")
	var/list/steps = flagmaker_steps()
	var/list/known = icon_states('icons/obj/decals.dmi')
	var/missing = 0
	for (var/list/entry in steps)
		var/list/choices = entry[2]
		for (var/label in choices)
			if (choices[label] && !(choices[label] in known))
				missing++
	code_check(steps.len == 9 && !missing, "every flag maker choice has its sprite ([missing] missing)")
	qdel(F)

/proc/code_pole_checks()
	var/obj/structure/flag/pole/custom/P = new(locate(7, 7, 1))
	code_check(isnull(P.design_code()), "an unpainted pole flag has no code")
	var/list/design = pole_flag_parse("C13POLE/1/AA2211/star/ffffff")
	code_check(design ~= list("#aa2211", "cust_f_star", "#ffffff"), "a pole flag code reads its colours and symbol")
	P.apply_design(design[1], design[2], design[3])
	code_check(!P.uncolored && P.overlays.len == 3 && P.design_code() == "C13POLE/1/aa2211/star/ffffff", "a painted pole flag exports the same code")
	code_check(isnull(pole_flag_parse("C13POLE/1/aa2211/skull/ffffff")) && isnull(pole_flag_parse("C13POLE/1/red/star/ffffff")), "bad symbols and colours are refused")
	P.overlays.Cut()
	P.after_load()
	code_check(P.overlays.len == 3, "a saved pole flag draws its design again after loading")
	qdel(P)

/proc/code_cloth_checks()
	var/list/body = tailoring_body("made_shirt")
	var/list/options = body["options"]
	var/list/values = list()
	for (var/label in options)
		var/list/variants = options[label]
		values += variants[variants.len]
	var/pieces = jointext(values, "|")
	var/colors = "#aa0000|#00bb00"
	var/code = tailoring_design_code("made_shirt", colors, pieces, "Red Tide")
	code_check(findtext(code, "C13CLOTH/1/made_shirt/aa0000.00bb00/") == 1 && findtext(code, "/Red_Tide"), "a clothing design exports as C13CLOTH ([code])")
	var/list/D = tailoring_parse_design_code(code)
	code_check(D && D["body"] == "made_shirt" && D["colors"] == colors && D["pieces"] == pieces && D["name"] == "Red Tide", "a clothing code reads back unchanged")
	var/list/plain = tailoring_parse_design_code("C13CLOTH/1/loincloth/-/-/-")
	code_check(plain && plain["body"] == "loincloth" && isnull(plain["name"]), "a plain design with no colours or name reads back")
	code_check(isnull(tailoring_parse_design_code("C13CLOTH/1/made_shirt/aa0000/99/-")), "a piece number past its choices is refused")
	code_check(isnull(tailoring_parse_design_code("C13CLOTH/1/no_such_body/-/-/-")), "an unknown garment is refused")
	code_check(isnull(tailoring_parse_design_code("C13CLOTH/1/made_shirt/zz0000/-/-")), "a bad colour is refused")
	var/list/named = tailoring_parse_design_code("C13CLOTH/1/loincloth/-/-/<b>Bold")
	code_check(named && !findtext(named["name"], "<"), "a pasted name is cleaned ([named ? named["name"] : "refused"])")
