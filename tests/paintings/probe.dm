// Native paintings probe, included by tests/ecology_spawning/run_linux.py, never
// by the game DME. It drives code/modules/paintings/.
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
/obj/map_metadata/paint_probe/New()
	map = src
/mob/living/human/paint_probe/New()
	icon_update = FALSE
	return
var/paint_failures = 0
var/paint_runtime_error = FALSE
/proc/paint_check(condition, label)
	if (!condition)
		paint_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	paint_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/paint_probe
		for (var/turf/T in block(locate(1, 1, 1), locate(20, 20, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		paint_codec_checks()
		paint_upload_checks()
		paint_hang_checks()
		paint_framed_plan_checks()
		paint_locket_checks()
		paint_drawing_checks()
		paint_gallery_checks()
	catch(var/exception/e)
		paint_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = paint_failures, "runtime_error" = paint_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/paint_codec_checks()
	var/plain = "0000000012" + painting_repeat("f", 30) + "3"
	var/packed = painting_pack(plain)
	paint_check(packed == "0~8.12f~30.3", "runs of four or more pack ([packed])")
	paint_check(painting_unpack(packed, length(plain)) == plain, "packed pixels unpack unchanged")
	paint_check(isnull(painting_unpack(packed, length(plain) + 1)), "a wrong pixel count is refused")
	paint_check(isnull(painting_unpack("0~3.", 3)) && isnull(painting_unpack("g", 1)) && isnull(painting_unpack("0~9999999.", 9999999)), "malformed runs and digits are refused")
	paint_check(painting_palette_list("#000000,#FFFFFF") ~= list("#000000", "#ffffff"), "palette text reads in lower case")
	paint_check(isnull(painting_palette_list("#000000,red")), "a palette with a bad colour is refused")
	// Black and white checkerboard 2x2 -> one pixel: linear-light mean is sRGB 188 (b).
	paint_check(painting_shrink("0110", list("#000000", "#ffffff"), 2, 2, 1, 1) == "bbb", "shrinking averages in linear light")
	paint_check(painting_shrink("0123", list("#000000", "#ff0000", "#00ff00", "#0000ff"), 2, 2, 2, 2) == "000f000f000f", "same-size shrink keeps every pixel")
	var/icon/I = painting_build_icon("f00" + painting_repeat("0", 3 * 15), 4, 4, 8, 6, 'icons/obj/paintings.dmi', "canvas_table")
	paint_check(I && I.GetPixel(9, 26) == "#ff0000" && !I.GetPixel(1, 1), "the shrunk copy lands in the art window and nothing else is drawn")
	paint_check(painting_build_icon("f00" + painting_repeat("0", 3 * 15), 4, 4, 8, 6, 'icons/obj/paintings.dmi', "canvas_table") == I, "identical paintings share one icon")
	paint_check(painting_mix("#000000", "#ffffff") == "#7f7f7f", "mixing averages two colours")

/proc/paint_upload_checks()
	var/turf/T = locate(5, 5, 1)
	var/mob/living/human/paint_probe/H = new(T)
	H.ckey = null
	H.real_name = "Ada Painter"
	var/obj/item/canvas/table/C = new(H)
	var/list/blank_allowed = painting_allowed_colours(H, C)
	paint_check(blank_allowed.len == 1 && blank_allowed[1] == C.base_colour, "without pigment only the canvas colour is allowed")
	var/obj/item/pigment/charcoal/P = new(H)
	new /obj/item/pigment/ochre_red(H)
	new /obj/item/pigment/ochre_yellow(H)
	new /obj/item/pigment/bone_white(H)
	text2file(painting_editor_html(H, C, painting_allowed_colours(H, C)), "editor.html")
	for (var/obj/item/pigment/X in H)
		if (X != P)
			qdel(X)
	var/list/allowed = painting_allowed_colours(H, C)
	paint_check(allowed.len == 6 && ("#1e1b19" in allowed) && (painting_mix(C.base_colour, "#1e1b19") in allowed), "charcoal adds two colours and their mixes")
	var/count = C.canvas_w * C.canvas_h
	var/plain = painting_repeat("1", 300) + painting_repeat("0", count - 300)
	var/pal = "[C.base_colour],#1e1b19"
	paint_check(C.accept_painting(H, painting_pack(plain), "#ffffff,#1e1b19", FALSE, "") != "Saved.", "a palette that does not start with the canvas colour is refused")
	paint_check(C.accept_painting(H, painting_pack(plain), "[C.base_colour],#0000ff", FALSE, "") != "Saved.", "an uncarried colour is refused")
	paint_check(C.accept_painting(H, painting_pack(plain + "0"), pal, FALSE, "") != "Saved.", "a painting of the wrong size is refused")
	paint_check(C.accept_painting(H, painting_pack(painting_repeat("2", count)), pal, FALSE, "") != "Saved.", "a pixel past the palette is refused")
	paint_check(C.accept_painting(H, painting_pack(plain), pal, FALSE, "") == "Saved." && !C.finished && length(C.small) == 16 * 16 * 3, "a save keeps the painting and its shrunk copy")
	paint_check(C.author_name == "Ada Painter", "the first painter is recorded")
	paint_check(C.accept_painting(H, painting_pack(plain), pal, TRUE, "") != null && !C.finished, "finishing needs a title")
	var/uses = P.pigment_uses
	paint_check(isnull(C.accept_painting(H, painting_pack(plain), pal, TRUE, "Night <b>Sky</b>")) && C.finished, "finishing locks the painting")
	paint_check(!findtext(C.title, "<"), "the title is sanitised ([C.title])")
	paint_check(C in painting_registry, "a finished painting is listed for admins")
	paint_check(P.pigment_uses == uses - 2, "300 charcoal pixels use two charcoal ([uses] -> [P.pigment_uses])")
	paint_check(C.overlays.len == 2, "the picture shows its art and frame")
	// Kept colours stay valid after the pigment is gone.
	var/obj/item/canvas/table/D = new(H)
	D.accept_painting(H, painting_pack(plain), pal, FALSE, "")
	qdel(P)
	paint_check(D.accept_painting(H, painting_pack(plain), pal, FALSE, "") == "Saved.", "colours already on the canvas stay after the pigment runs out")
	var/old = painting_registry.Copy()
	painting_registry.Cut()
	for (var/i = 1, i <= PAINTING_REGION_CAP, i++)
		painting_registry += new /obj/item/canvas
	paint_check(D.accept_painting(H, painting_pack(plain), pal, TRUE, "Too many") != null && !D.finished, "the region cap stops new finished paintings")
	for (var/obj/O in painting_registry)
		qdel(O)
	painting_registry = old
	qdel(C)
	paint_check(!(C in painting_registry), "a deleted painting leaves the admin list")
	qdel(D)
	qdel(H)

/proc/paint_hang_checks()
	var/turf/wall = locate(9, 5, 1)
	wall.density = TRUE
	var/turf/stand = locate(8, 5, 1)
	var/mob/living/human/paint_probe/H = new(stand)
	var/obj/item/canvas/C = new(H)
	var/count = C.canvas_w * C.canvas_h
	C.accept_painting(H, painting_pack(painting_repeat("0", count)), C.base_colour, TRUE, "Wall")
	paint_check(C.finished && length(C.small) == 32 * 32 * 3, "a 64x64 wall painting shrinks to 32x32")
	H.r_hand = C
	paint_check(painting_hang(H, C, wall), "a finished painting hangs on a wall")
	var/obj/structure/painting_frame/F = locate() in stand
	paint_check(F && F.dir == EAST && F.pixel_x == 32 && C.loc == F && F.overlays.len == 2, "the frame sits against the wall with the painting in it")
	qdel(F)
	paint_check(C.loc == stand, "taking the frame down leaves the painting")
	var/obj/structure/easel/E = new(stand)
	var/obj/item/canvas/B = new(stand)
	E.attackby(B, H)
	paint_check(B.loc == E && E.held_canvas() == B, "an easel holds a canvas")
	qdel(E)
	paint_check(B.loc == stand, "a broken easel drops its canvas")
	paint_check(mortar_pigment_result(new /obj/item/stack/ore/charcoal(stand)) == /obj/item/pigment/charcoal && mortar_pigment_result(new /obj/item/stack/ore/iron(stand)) == /obj/item/pigment/ochre_red && mortar_pigment_result(new /obj/item/stack/material/clay(stand)) == /obj/item/pigment/ochre_yellow && mortar_pigment_result(new /obj/item/stack/material/bone(stand)) == /obj/item/pigment/bone_white, "the mortar grinds charcoal, iron ore, clay and bone into pigments")
	qdel(H)

/proc/paint_framed_plan_checks()
	var/turf/T = locate(11, 5, 1)
	var/turf/W = locate(12, 5, 1)
	W.density = TRUE
	var/mob/living/human/paint_probe/H = new(T)
	var/obj/item/ship_draught/P = new(H)
	H.r_hand = P
	paint_check(!P.framed_plan_diagram(), "a blank plan cannot be framed")
	var/datum/rail_plan/R = new
	R.name = "East railway"
	R.set_track(1, 1, TRUE)
	R.set_track(2, 1, TRUE)
	R.set_track(2, 2, TRUE)
	P.take_rail(R)
	qdel(R)
	var/original_code = P.draught_code
	var/datum/framed_plan_diagram/V = P.framed_plan_diagram()
	var/diagram = V?.html()
	paint_check(V && findtext(diagram, "East railway") && findtext(diagram, "Track at 2,2") && !findtext(diagram, "byond://"), "the frame renders all rail tiles without editor links")
	paint_check(wall_frame_mount(H, P, W, V), "the active sheet can hang on a wall")
	var/obj/structure/painting_frame/F = locate() in T
	paint_check(F && F.held_plan() == P && P.draught_code == original_code && !H.r_hand, "the frame holds the exact original sheet")
	if (F)
		F.overlays.Cut()
		F.after_load()
		paint_check(F.overlays.len == 2 && F.held_plan() == P, "loading rebuilds the thumbnail from the retained original")
		qdel(F)
		paint_check(P.loc == T && P.draught_code == original_code, "breaking a frame puts the untouched sheet back on its floor tile")
	qdel(V)
	qdel(P)
	var/obj/item/weapon/paper/S = new(H)
	H.r_hand = S
	paint_draw(H, S, "#7744aa", "Framed rose")
	paint_check(wall_frame_mount(H, S, W), "a loose drawing can hang in the same wall frame")
	var/obj/structure/painting_frame/sketch_frame = locate() in T
	if (sketch_frame)
		paint_check(sketch_frame.held_sketch() == S && findtext(drawings_html(S), "Framed rose"), "the original artwork remains available at full size")
		drawing_set_list(S, null)
		paint_check(sketch_frame.overlays.len == 1, "removing artwork updates the frame immediately")
		qdel(sketch_frame)
		paint_check(S.loc == T, "unframing art returns the original sheet")
	qdel(S)
	qdel(H)

/proc/paint_locket_checks()
	var/turf/T = locate(12, 12, 1)
	var/mob/living/human/paint_probe/H = new(T)
	var/obj/item/canvas/miniature/M = new(H)
	var/obj/item/pigment/ochre_red/P = new(H)
	M.accept_painting(H, painting_pack(painting_repeat("1", 256)), "[M.base_colour],#7d2f1e", TRUE, "Rose")
	paint_check(M.finished && length(M.small) == 16 * 16 * 3, "a miniature keeps all 16x16 pixels")
	var/obj/item/clothing/accessory/necklace/N = new(T)
	N.attackby(M, H)
	paint_check(M.loc == N && N.held_miniature() == M, "a finished miniature sets into a necklace")
	N.mob_overlay = null
	var/image/O = N.get_mob_overlay()
	paint_check(O && O.overlays.len == 2 && length(M.get_worn_small()) == 8 * 8 * 3, "the worn necklace shows the locket and its 8x8 art")
	var/obj/item/canvas/miniature/M2 = new(H)
	N.attackby(M2, H)
	paint_check(M2.loc == H, "an unfinished miniature or a second one is refused")
	qdel(P)
	qdel(N)
	qdel(H)

/proc/paint_draw(mob/user, atom/target, colour, title, size = 32)
	var/obj/item/canvas/sketch/S = new(null)
	S.target = target
	S.canvas_w = size
	S.canvas_h = size
	S.art_w = size
	S.art_h = size
	S.accept_painting(user, painting_pack(painting_repeat("1", size * size)), "[S.base_colour],[colour]", TRUE, title)
	return QDELETED(S)

/proc/paint_drawing_checks()
	var/turf/T = locate(14, 14, 1)
	var/mob/living/human/paint_probe/H = new(T)
	H.real_name = "Ada Painter"
	var/obj/item/weapon/pen/pen = new(H)
	H.hand = 0
	H.r_hand = pen
	paint_check(drawing_tool(H) == pen, "a held pen is a drawing tool")
	var/obj/item/weapon/paper/P = new(H)
	var/ink = painting_hex(book_page_ink(pen.colour))
	paint_check(paint_draw(H, P, ink, "Ink Hills") && length(P.drawings) == 1 && P.drawings[1]["title"] == "Ink Hills" && P.drawings[1]["by"] == "Ada Painter", "a finished sketch lands on the paper as a drawing")
	paint_check((P in drawing_holders) && !(locate(/obj/item/canvas/sketch) in painting_registry), "the paper is listed for admins and the sketch is not a painting")
	paint_check(!paint_draw(H, P, "#0000fe", "Stolen blue") || length(P.drawings) == 1, "a colour the drawer lacks is refused")
	paint_check(paint_draw(H, P, ink, "Large", 64) && length(P.drawings) == 2, "a large drawing fits as the second picture")
	paint_draw(H, P, ink, "Third")
	paint_check(length(P.drawings) == 2, "a page holds only two pictures")
	var/html = drawings_html(P)
	paint_check(findtext(html, "drawing2") && findtext(html, "Ink Hills") && findtext(html, "unpackArt"), "the reader draws the pictures in the browser")
	var/list/copy = drawings_copy(P.drawings)
	paint_check(copy.len == 2 && copy[1] != P.drawings[1] && copy[1]["data"] == P.drawings[1]["data"], "copies are separate records")
	paint_check(isnull(drawings_copy(list(list("w" = 48, "h" = 48)))), "a bad record is not copied")
	var/list/snapshot = paper_document_copy_snapshot(P)
	var/obj/item/weapon/paper/C = snapshot ? paper_document_create_copy(snapshot) : null
	paint_check(C && length(C.drawings) == 2 && (C in drawing_holders), "a printed copy keeps the drawings")
	var/obj/item/weapon/book/B = new(H)
	paint_check(B.page_drawings_fit(P), "an empty book has room for a page's pictures")
	B.take_page_drawings(P)
	paint_check(length(B.drawings) == 2 && (B in drawing_holders), "a bound page brings its pictures into the book")
	B.drawings = null
	for (var/i = 1, i <= 11, i++)
		B.drawings = (B.drawings || list()) + list(P.drawings[1])
	paint_check(!B.page_drawings_fit(P), "a nearly full book refuses a page with two pictures")
	drawing_holders -= B
	B.after_load()
	paint_check(B in drawing_holders, "a loaded book with pictures rejoins the admin list")
	drawing_set_list(C, null)
	paint_check(!(C in drawing_holders), "a page without pictures leaves the admin list")
	qdel(C)
	qdel(B)
	qdel(P)
	H.r_hand = null
	qdel(pen)
	paint_check(!drawing_tool(H), "an empty hand cannot draw")
	qdel(H)

/proc/paint_gallery_checks()
	var/turf/T = locate(4, 15, 1)
	for (var/turf/W in block(locate(3, 16, 1), locate(7, 16, 1)))
		W.density = TRUE
	var/mob/living/human/paint_probe/H = new(T)
	H.real_name = "Ada Painter"
	paint_check(mortar_pigment_result(new /obj/item/stack/ore/copper(T)) == /obj/item/pigment/malachite && mortar_pigment_result(new /obj/item/stack/ore/mercury(T)) == /obj/item/pigment/vermilion && mortar_pigment_result(new /obj/item/stack/ore/lead(T)) == /obj/item/pigment/lead_white && mortar_pigment_result(new /obj/item/stack/ore/gem/sapphire(T)) == /obj/item/pigment/ultramarine, "the mortar grinds copper ore, cinnabar, lead ore and sapphire into later pigments")
	var/obj/item/pigment/oil_paints/O = new(H)
	var/obj/item/canvas/gallery/G = new(H)
	var/list/allowed = painting_allowed_colours(H, G)
	var/all = TRUE
	for (var/c in O.pigment_colors)
		if (!(c in allowed))
			all = FALSE
	paint_check(all, "a box of oil paints offers all eight colours")
	var/count = G.canvas_w * G.canvas_h
	var/plain = painting_repeat("1", count / 2) + painting_repeat("2", count / 2)
	paint_check(isnull(G.accept_painting(H, painting_pack(plain), "[G.base_colour],#1f4fa0,#e0b020", TRUE, "Harbour")) && G.finished && length(G.small) == 56 * 56 * 3, "a 128x128 gallery painting shrinks to 56x56")
	paint_check(O.pigment_uses == 40 - 8, "a full gallery painting uses at most eight of a box of oil paints ([O.pigment_uses])")
	paint_check(!G.overlays.len, "a held gallery canvas shows its plain sprite")
	var/list/framed = G.framed_overlays()
	paint_check(framed.len == 2, "a gallery painting builds its art and gilded frame")
	var/turf/side = locate(10, 15, 1)
	var/turf/side_wall = locate(11, 15, 1)
	side_wall.density = TRUE
	H.r_hand = G
	H.forceMove(side)
	paint_check(!painting_hang(H, G, side_wall), "a gallery painting refuses a wall that is not to the north")
	H.forceMove(T)
	paint_check(painting_hang(H, G, locate(4, 16, 1)), "a gallery painting hangs on a wall to the north")
	var/obj/structure/painting_frame/F = locate() in T
	paint_check(F && F.dir == NORTH && F.pixel_y == 32 && F.overlays.len == 2, "the gallery frame sits on the wall")
	var/obj/item/canvas/C = new(H)
	C.accept_painting(H, painting_pack(painting_repeat("0", C.canvas_w * C.canvas_h)), C.base_colour, TRUE, "Neighbour")
	H.r_hand = C
	H.forceMove(locate(5, 15, 1))
	paint_check(!painting_hang(H, C, locate(5, 16, 1)), "the second tile of a gallery painting is taken")
	var/obj/item/canvas/gallery/wide/D = new(H)
	D.accept_painting(H, painting_pack(painting_repeat("1", D.canvas_w * D.canvas_h)), "[D.base_colour],#1f4fa0", TRUE, "Shore")
	paint_check(D.finished && length(D.small) == 56 * 24 * 3, "a 128x64 wide painting shrinks to 56x24")
	H.r_hand = D
	H.forceMove(locate(7, 15, 1))
	paint_check(!painting_hang(H, D, locate(7, 16, 1)), "a gallery painting needs the wall to run on to the right")
	qdel(F)
	qdel(C)
	qdel(D)
	qdel(O)
	qdel(H)
