// Ship's draughts (naval/ship_draught.dm, docs/ship-draught.md): a ship drawn
// on paper keeps to the built hull's rules, reckons her cost and speed, travels
// as a design code, and a ship afloat can have her lines drawn bow up.
/world
	hub = ""
	hub_password = ""
	maxx = 70
	maxy = 60
	maxz = 3
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/naval_research_done = FALSE
/obj/map_metadata/naval_probe/New()
	return
/obj/map_metadata/naval_probe/is_node_done(faction, node_id)
	return naval_research_done
/mob/living/human/naval_probe/New()
	return
var/hull_probe_watched = FALSE
// Nobody has a client here; the probe says when a player is near.
/datum/vehicle_offset/hull/watched()
	return hull_probe_watched
var/naval_failures = 0
var/naval_runtime_error = FALSE
/proc/naval_check(condition, label)
	if (!condition)
		naval_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	naval_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

// Rock under everything, sand ashore (x 1-20) and deep sea beyond, sky above.
/proc/naval_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/R = locate(x, y, 1)
			R.ChangeTurf(/turf/wall/rockwall)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(x <= 20 ? /turf/floor/beach/sand : /turf/floor/beach/water/deep/saltwater)
			var/turf/S = locate(x, y, 3)
			S.ChangeTurf(/turf/sky/building)


// A plank laid the way a player lays one, with its first update already run.
/proc/draught_lay(x, y, path = /obj/covers/repairedfloor/ship)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/C = new path(T)
	C.updateturf()
	return C

// A plain hull drawn on the sheet: w by h planks, the tiller in the middle.
/proc/draught_box(w, h, name = "Box")
	var/datum/ship_draught/D = new
	D.name = name
	for (var/x = 0, x < w, x++)
		for (var/y = 0, y < h, y++)
			D.set_floor(x, y, "w")
	D.set_piece(round(w / 2), round(h / 2), "T")
	return D

/proc/naval_checks()
	naval_fixture()
	// ---- Limits are the built hull's own ----
	naval_check(SHIP_DRAUGHT_MAX_TILES == BUILT_HULL_MAX_TILES && SHIP_DRAUGHT_MAX_DECK == BUILT_HULL_MAX_DECK_TILES, "a draught keeps to the built hull's tile limits")

	// ---- What each piece weighs is what it weighs afloat ----
	var/turf/yard = locate(5, 5, 2)
	for (var/key in ship_draught_pieces())
		var/list/P = ship_draught_pieces()[key]
		var/path = P["path"]
		var/atom/movable/M = new path(yard)
		naval_check(M.hull_load() == P["load"], "a [P["name"]] weighs [P["load"]] on a deck, as hull_load() says ([M.hull_load()])")
		qdel(M)

	// ---- A sound draught ----
	var/datum/ship_draught/D = draught_box(3, 5, "Wren")
	naval_check(D.buildable() && D.hull_tiles() == 15, "a 3 by 5 hull with a tiller can be built ([jointext(D.problems(), " ")])")
	var/list/cost = D.costs()
	naval_check(cost["wood"] == 72 && cost.len == 1, "she costs her floors, her tiller and 16 gunwales: 72 wood ([D.costs_text()])")
	naval_check(length(D.gunwale_sides()) == 16, "a 3 by 5 boat has 16 open sides to rail")
	naval_check(D.size_class() == HULL_CLASS_BOAT, "fifteen tiles make a boat")
	D.set_upper(1, 1, TRUE)
	D.set_floor(1, 0, "s")
	cost = D.costs()
	naval_check(cost["wood"] == 70 && cost["steel"] == 3, "a steel floor costs steel with a steel bulwark on its open side, and a deck above costs a floor ([D.costs_text()])")
	naval_check(findtext(jointext(D.problems(), " "), "nothing to carry it"), "a deck above with nothing under it to carry it is refused ([jointext(D.problems(), " ")])")
	D.set_piece(2, 4, "S")
	naval_check(!findtext(jointext(D.problems(), " "), "carry"), "a deck pillar three tiles off carries it")
	D.set_piece(0, 0, "W")
	naval_check(length(D.gunwale_sides()) == 14, "a plank wall closes both open sides of its corner tile")
	D.set_piece(0, 0, "Y", WEST)
	var/list/gangway_figures = D.summary_data()
	naval_check(length(D.gunwale_sides()) == 15 && D.buildable() && gangway_figures["gunwales"] == 15, "a gangway drawn on her edge closes the side it faces instead of a gunwale")
	D.set_piece(0, 0, "Y", EAST)
	naval_check(findtext(jointext(D.problems(), " "), "gangway faces her own deck"), "a gangway facing inboard is refused ([jointext(D.problems(), " ")])")
	D.set_piece(0, 0, null)
	var/datum/ship_draught/nest_ship = draught_box(3, 5, "Lookout")
	nest_ship.set_piece(1, 3, "N")
	naval_check(nest_ship.mast_count() == 1 && nest_ship.sail_step() == VESSEL_SPEED_HALF && nest_ship.costs()["wood"] == 95, "a mast with a crow's nest drives her like a mast and costs 8 wood more ([nest_ship.costs_text()])")
	qdel(nest_ship)
	var/datum/ship_draught/jib_ship = draught_box(3, 5, "Jib")
	jib_ship.set_piece(1, 4, "J")
	jib_ship.set_piece(1, 0, "F", NORTH)
	naval_check(jib_ship.sail_push() == CRAFT_SAIL_THRUST * 0.5 && jib_ship.costs()["wood"] == 88 && findtext(jib_ship.summary_text(), "under sail"), "a bowsprit's jib pushes half a mast and the figurehead costs its wood ([jib_ship.costs_text()])")
	var/datum/design_report/jib_report = design_report("ship", jib_ship)
	naval_check(!findtext(jointext(jib_report.texts(DESIGN_WARNING), " "), "bowsprit"), "a bowsprit at her bow draws no warning about it")
	qdel(jib_report)
	jib_ship.set_piece(1, 4, null)
	jib_ship.set_piece(1, 3, "J")
	jib_report = design_report("ship", jib_ship)
	naval_check(findtext(jointext(jib_report.texts(DESIGN_WARNING), " "), "bowsprit"), "a bowsprit behind more of her deck is warned of")
	qdel(jib_report)
	qdel(jib_ship)
	var/datum/ship_draught/raft = draught_box(3, 4, "Raft")
	naval_check(!length(raft.gunwale_sides()), "small craft of 12 tiles are left open")
	qdel(raft)

	// ---- Codes ----
	var/code = D.to_code()
	naval_check(findtext(code, "C13SHIP/1/Wren/") == 1, "her code is a ship code ([code])")
	var/datum/ship_draught/back = ship_draught_from_code(code)
	naval_check(back && back.to_code() == code && back.upper_tiles() == 1 && back.cell(1, 0)[1] == "s", "her code draws the same ship again")
	naval_check(!ship_draught_from_code("C13FLAG/1/x/y"), "a flag code is not a ship")
	naval_check(!ship_draught_from_code("C13SHIP/1/X/0,0,q,-,1,0"), "an unknown floor is refused")
	naval_check(!ship_draught_from_code("C13SHIP/1/X/0,0,w,-,1,0;0,0,w,-,1,0"), "a tile drawn twice is refused")
	naval_check(!ship_draught_from_code("C13SHIP/1/X/0,0,w,%,1,0"), "an unknown piece is refused")
	naval_check(!ship_draught_from_code("C13SHIP/1/X/0,[SHIP_DRAUGHT_SIDE],w,-,1,0"), "a tile off the sheet is refused")
	naval_check(!ship_draught_from_code("C13SHIP/1/X/0,0,w,R,3,0"), "a piece facing no direction is refused")
	var/datum/ship_draught/named = ship_draught_from_code("C13SHIP/1/Sea_Wolf/0,0,w,T,1,0")
	naval_check(named && named.name == "Sea Wolf" && named.buildable(), "a one-tile code with a tiller is a ship named Sea Wolf")
	var/obj/item/ship_draught/sheet = new(yard)
	sheet.take(D)
	var/datum/ship_draught/again = sheet.draught()
	naval_check(again && again.to_code() == code && sheet.name == "ship's draught (Wren)", "the sheet keeps her code")

	// ---- What cannot be built ----
	var/datum/ship_draught/apart = draught_box(3, 3)
	apart.set_floor(10, 10, "w")
	naval_check(!apart.buildable() && findtext(jointext(apart.problems(), " "), "more than one piece"), "floors in two pieces are refused")
	var/datum/ship_draught/two = draught_box(3, 3)
	two.set_piece(0, 0, "O")
	naval_check(findtext(jointext(two.problems(), " "), "2 helms"), "two helms are refused")
	var/datum/ship_draught/none = draught_box(3, 3)
	none.set_piece(1, 1, null)
	naval_check(findtext(jointext(none.problems(), " "), "no helm"), "no helm is refused")
	var/datum/ship_draught/ark = draught_box(15, 14)
	naval_check(findtext(jointext(ark.problems(), " "), "at most [SHIP_DRAUGHT_MAX_TILES]"), "more tiles than a built hull may have are refused")
	var/datum/ship_draught/tall = draught_box(10, 18)
	for (var/x = 0, x < 10, x++)
		for (var/y = 0, y < 18, y++)
			tall.set_upper(x, y, TRUE)
	naval_check(findtext(jointext(tall.problems(), " "), "at most [SHIP_DRAUGHT_MAX_DECK]"), "more deck than can sail is refused")
	naval_check(!D.set_piece(20, 20, "M"), "a piece needs a floor under it")

	// ---- Decks off her main deck ----
	var/datum/ship_draught/decked = draught_box(4, 6, "Puffin")
	naval_check(!decked.set_deck(-1, 9, 9, TRUE) && !decked.set_deck(2, 1, 1, TRUE) && !decked.set_deck(3, 1, 1, TRUE), "a hold needs her hull over it, a second deck the deck below it, and there is no third")
	for (var/y = 1, y <= 4, y++)
		decked.set_deck(-1, 1, y, TRUE)
		decked.set_deck(-1, 2, y, TRUE)
	decked.set_deck_piece(-1, 2, 2, "C")
	naval_check(!decked.set_deck_piece(-1, 1, 1, "M") && !decked.set_deck_piece(-1, 1, 1, "T"), "masts and helms stand only on her main deck")
	naval_check(findtext(jointext(decked.problems(), " "), "hold has a part with no ladder"), "a hold with no ladder is refused ([jointext(decked.problems(), " ")])")
	decked.set_deck_piece(-1, 1, 1, "X")
	naval_check(decked.buildable(), "a ladder in the hold under a clear tile of deck reaches it ([jointext(decked.problems(), " ")])")
	decked.set_piece(1, 1, "C")
	naval_check(findtext(jointext(decked.problems(), " "), "on her hold leads nowhere") && findtext(jointext(decked.problems(), " "), "no ladder up"), "a ladder under a crate leads nowhere ([jointext(decked.problems(), " ")])")
	decked.set_piece(1, 1, null)
	for (var/x = 0, x < 4, x++)
		decked.set_deck(1, x, 5, TRUE)
	decked.set_piece(1, 4, "S")
	decked.set_deck(2, 0, 5, TRUE)
	naval_check(findtext(jointext(decked.problems(), " "), "tile of her second deck above has nothing to carry it"), "a second deck with nothing under it is refused ([jointext(decked.problems(), " ")])")
	decked.set_deck_piece(1, 2, 5, "S")
	naval_check(decked.upper_tiles() == 4 && decked.cell(0, 5)[4] && decked.deck_tiles(2) == 1, "the deck above keeps the hull's upper flags, and a second deck stands on it")
	var/datum/design_report/deck_report = decked.check_design()
	var/deck_notes = jointext(deck_report.texts(DESIGN_NOTE), " ")
	var/list/deck_finding_decks = list()
	for (var/datum/design_finding/F in deck_report.findings)
		if (F.part == "X")
			deck_finding_decks += F.deck
	qdel(deck_report)
	naval_check(decked.buildable() && findtext(deck_notes, "No ladder is drawn up to a part of her deck above") && findtext(deck_notes, "a part of her second deck above") && (1 in deck_finding_decks) && (2 in deck_finding_decks), "decks above with no ladder are noted on their own decks, not refused ([deck_notes])")
	decked.set_piece(3, 5, "X")
	decked.set_deck_piece(1, 0, 5, "X")
	naval_check(!decked.set_deck_piece(2, 0, 5, "X"), "nothing climbs above her top deck")
	deck_report = decked.check_design()
	deck_notes = jointext(deck_report.texts(DESIGN_NOTE), " ")
	qdel(deck_report)
	naval_check(decked.buildable() && !findtext(deck_notes, "No ladder"), "a ladder from each deck to the next reaches them all ([deck_notes])")
	naval_check(findtext(decked.summary_text(), "4 of deck above and 1 of second deck above") || findtext(decked.summary_text(), "of hold"), "the summary counts every deck ([decked.summary_text()])")
	naval_check(!findtext(decked.summary_text(), "drawn for later"), "a second deck above is no longer said to be for later")
	var/list/decked_cost = decked.costs()
	var/datum/ship_draught/flat = draught_box(4, 6)
	var/list/flat_cost = flat.costs()
	// 8 hold floors and a crate on them, 5 tiles of deck above, three ladders and two pillars.
	naval_check(decked_cost["steel"] == 8 && decked_cost["wood"] == flat_cost["wood"] + 5 + 5 * 2 + 3 * 4 + 2 + 2, "her other decks cost their floors and fittings ([decked.costs_text()])")
	naval_check(decked.load() > flat.load(), "what stands on her other decks weighs on her")
	qdel(flat)
	var/decked_code = decked.to_code()
	naval_check(findtext(decked_code, "C13SHIP/2/Puffin/") == 1, "a draught with a hold writes a second-format code ([decked_code])")
	var/datum/ship_draught/decked_back = ship_draught_from_code(decked_code)
	naval_check(decked_back && decked_back.to_code() == decked_code && decked_back.buildable() && decked_back.deck_tiles(-1) == 8, "her code draws every deck again")
	naval_check(!ship_draught_from_code("C13SHIP/2/X/0,0,w,T,1,0/-1,5,5,-,1"), "a hold tile with no hull over it is refused")
	naval_check(!ship_draught_from_code("C13SHIP/2/X/0,0,w,T,1,0/3,0,0,-,1"), "a deck on an unknown level is refused")
	naval_check(!ship_draught_from_code("C13SHIP/2/X/0,0,w,T,1,0/-1,0,0,M,1"), "a mast in the hold is refused")
	var/datum/ship_draught/plain_decked = ship_draught_from_code("C13SHIP/2/X/0,0,w,T,1,1/1,0,0,-,1")
	naval_check(plain_decked && findtext(plain_decked.to_code(), "C13SHIP/1/") == 1, "a bare deck above keeps to the first format")
	decked.clear(1, 1)
	naval_check(!decked.deck_cell(-1, 1, 1) && decked.deck_tiles(-1) == 7, "taking up a hull tile takes up the hold under it")
	decked.set_deck(1, 0, 5, FALSE)
	naval_check(!decked.deck_tiles(2) && !decked.cell(0, 5)[4], "taking up the deck above takes up the deck on it")
	qdel(decked_back)
	qdel(decked)

	// ---- How she will go ----
	var/datum/ship_draught/sloop = draught_box(4, 5)
	sloop.set_piece(1, 3, "M")
	naval_check(sloop.sail_step() == VESSEL_SPEED_HALF && sloop.oar_step() == VESSEL_SPEED_SLOW, "one mast drives twenty tiles at half ahead on a reach")
	var/datum/ship_draught/galley = draught_box(3, 6)
	for (var/y = 0, y < 6, y++)
		galley.set_piece(0, y, "R", EAST)
		galley.set_piece(2, y, "R", WEST)
	naval_check(galley.oar_step() == VESSEL_SPEED_FULL, "twelve manned benches row eighteen tiles at full ahead ([galley.mass()])")
	var/datum/ship_draught/barge = draught_box(6, 10)
	barge.set_piece(2, 2, "M")
	naval_check(barge.sail_step() == VESSEL_SPEED_SLOW && barge.wants_ballast() > 0, "one mast is too little for sixty tiles, and she wants ballast ([barge.wants_ballast()])")
	naval_check(findtext(barge.summary_text(), "ballast"), "the summary tells her builder about ballast")

	// ---- The designer window ----
	var/list/examples = ship_draught_examples()
	naval_check(examples.len == 4, "four ready-made draughts to start from")
	for (var/datum/ship_draught/E in examples)
		naval_check(E.buildable(), "the ready-made [E.name] can be built as drawn ([jointext(E.problems(), " ")])")
		var/list/layout = ship_designer_layout(E)
		var/list/cells = layout[1]
		var/list/other_decks = layout[2]
		var/inside = TRUE
		for (var/list/C in cells)
			if (!ship_draught_on_sheet(C[1], C[2]))
				inside = FALSE
		naval_check(cells.len == E.hull_tiles() && other_decks.len == E.other_deck_tiles() && inside, "the [E.name] is laid out on the sheet for the window")
	var/datum/ship_draught/merchant_example = examples[4]
	naval_check(merchant_example.deck_tiles(-1) && merchant_example.upper_tiles() && findtext(merchant_example.to_code(), "C13SHIP/2/"), "the ready-made merchantman has a hold and a deck above")
	var/datum/ship_draught/galley_example = examples[1]
	naval_check(galley_example.oar_step() == VESSEL_SPEED_FULL, "the ready-made galley rows at full ahead")
	var/datum/ship_draught/sloop_example = examples[2]
	naval_check(sloop_example.sail_step() == VESSEL_SPEED_HALF, "the ready-made sloop sails at half ahead")
	var/obj/item/ship_draught/pad = new(yard)
	var/html = ship_designer_html(pad, null)
	naval_check(findtext(html, "C13SHIP") && findtext(html, "rowing galley"), "the window carries the drawing tools and the ready-made ships")
	naval_check(!findtext(html, "@@DATA@@") && findtext(html, "\"PIECES\":") && findtext(html, "Steering and drive") && findtext(html, "\"FLOORS\":") && findtext(html, "\"DECKS\":") && findtext(html, "\"START_DECKS\":"), "the window's palette is built from the draught's own tables")
	var/every_piece_grouped = TRUE
	for (var/piece in ship_draught_pieces())
		if (ship_designer_group(piece) == "Other")
			every_piece_grouped = FALSE
			world.log << "no palette group for [piece]"
	naval_check(every_piece_grouped && ship_designer_group("?") == "Other", "every fitting has a heading in the palette, and an unknown one still shows")
	var/list/figures = galley_example.summary_data()
	var/list/galley_drives = figures["drives"]
	var/list/galley_problems = figures["problems"]
	naval_check(figures["tiles"] == 27 && figures["max_tiles"] == SHIP_DRAUGHT_MAX_TILES && figures["class"] == "boat" && galley_drives.len == 1 && galley_drives[1][2] == "full ahead" && !galley_problems.len, "the window's figures for the galley are the summary's own")
	var/datum/ship_draught/bare = new
	var/list/bare_figures = bare.summary_data()
	var/list/bare_problems = bare_figures["problems"]
	var/list/bare_costs = bare_figures["costs"]
	naval_check(bare_figures["tiles"] == 0 && bare_problems.len == 1 && !bare_costs.len && istext(json_encode(bare_figures)), "a blank sheet still has figures to show")
	qdel(bare)
	var/list/pictures = ship_designer_sprite_names()
	var/pictures_sent = TRUE
	for (var/picture in pictures)
		if (!isfile(ship_designer_sprites[picture]))
			pictures_sent = FALSE
			world.log << "no picture [picture]"
	naval_check(pictures.len == ship_designer_sprites.len && pictures_sent, "the window is sent a picture of every floor and fitting, one per facing for those that turn ([pictures.len])")
	var/mob/living/human/naval_probe/drawer = new(yard)
	naval_check(pad.accept_drawing(drawer, "C13SHIP/1/ship/0,0,w,T,1,0;0,1,w,M,1,0", "Little/Auk", TRUE) == "Saved on the sheet." && pad.draughts_name() == "Little Auk", "saving keeps the drawing and its cleaned name on the sheet")
	naval_check(pad.accept_drawing(drawer, "C13SHIP/1/ship/0,0,w,T,1,0;0,0,w,T,1,0", "Bad", TRUE) != "Saved on the sheet." && pad.draughts_name() == "Little Auk", "a damaged drawing is refused and the sheet keeps what it had")
	naval_check(pad.accept_drawing(drawer, "C13SHIP/2/ship/0,0,w,T,1,0;0,1,w,-,1,0/-1,0,1,X,1;-1,0,0,C,1", "Dunlin", TRUE) == "Saved on the sheet." && findtext(pad.draught_code, "C13SHIP/2/Dunlin/"), "a drawing with a hold is saved in the second format")
	naval_check(pad.accept_drawing(drawer, "C13SHIP/1/ship/", "Empty", FALSE) == null, "an empty sheet still gets a summary")
	naval_check(pad.accept_drawing(drawer, "C13SHIP/1/ship/", "Empty", FALSE) == "", "a summary asked for again at once is put off")

	// ---- Drawing a ship afloat ----
	for (var/x = 22, x <= 60, x++)
		for (var/y = 4, y <= 50, y++)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(/turf/floor/beach/water)
	for (var/x = 30, x <= 34, x++)
		for (var/y = 10, y <= 12, y++)
			draught_lay(x, y, (x == 34 && y == 12) ? /obj/covers/steelplating : /obj/covers/repairedfloor/ship)
	var/obj/structure/hull_tiller/tiller = new(locate(32, 11, 2))
	new /obj/structure/vehicleparts/movement/sail(locate(33, 11, 2))
	var/obj/structure/bed/chair/wood/rowing_bench/bench = new(locate(31, 10, 2))
	bench.set_dir(NORTH)
	var/obj/structure/hull_tiller/spare = new(locate(30, 12, 2))
	// A hold under her, one tile astern of her tiller, with a ladder up.
	var/turf/hold_turf = locate(31, 11, 1)
	hold_turf.ChangeTurf(/turf/wall/rockwall)
	hull_hold_lay(locate(31, 11, 1))
	new /obj/structure/multiz/ladder/up/placed(locate(31, 11, 1))
	naval_check(isnull(tiller.commission("Heron", EAST)) && tiller.craft, "a hull is commissioned bow to the east")
	var/datum/ship_draught/lines = ship_draught_survey(tiller)
	naval_check(istype(lines) && lines.hull_tiles() == 15 && lines.name == "Heron", "her lines are fifteen tiles named Heron")
	if (istype(lines))
		var/list/E = lines.extent()
		naval_check(E[3] - E[1] == 2 && E[4] - E[2] == 4, "drawn bow up, she is 3 wide and 5 long ([E[3] - E[1] + 1] by [E[4] - E[2] + 1])")
		// Tiller amidships at (1,2) on the sheet; ahead of it (east afloat) is up.
		naval_check(lines.cell(1, 2)[2] == "T" && lines.cell(1, 3)[2] == "M", "the mast that stood ahead of the tiller is drawn above it")
		// The bench stood one tile astern and to starboard (south of a ship
		// heading east), facing north: to port. Bow up, port is west.
		var/list/bench_cell = lines.cell(2, 1)
		naval_check(bench_cell && bench_cell[2] == "R" && bench_cell[3] == WEST, "the bench is drawn astern to starboard, facing to port ([bench_cell ? "[bench_cell[2]] [bench_cell[3]]" : "none"])")
		naval_check(lines.cell(0, 4)[1] == "s", "her steel tile is drawn as steel")
		var/list/hold_cell = lines.deck_cell(-1, 1, 1)
		naval_check(lines.deck_tiles(-1) == 1 && hold_cell && hold_cell[1] == "X", "her hold is drawn under her with its ladder ([lines.deck_tiles(-1)] [hold_cell ? hold_cell[1] : "none"])")
		naval_check(lines.helms().len == 1 && lines.buildable(), "the spare tiller is left off and her lines can be built ([jointext(lines.problems(), " ")])")
	qdel(spare)
	tiller.decommission()
	naval_check(istext(ship_draught_survey(tiller)), "a struck hull has no lines to draw")

	// ---- Building a draught on the slipway (naval/slipway_draught.dm) ----
	var/list/turn_ok = list()
	for (var/heading in cardinal)
		var/list/W = slipway_draught_turn(1, 2, heading)
		var/list/undone = ship_draught_bow_up(W[1], W[2], heading)
		if (undone[1] == 1 && undone[2] == 2)
			turn_ok += heading
	naval_check(turn_ok.len == 4, "laying a sheet on the berth is the inverse of drawing her lines, every heading")
	naval_check(piece_material(new /obj/item/stack/material/iron) == "iron" && piece_material(new /obj/item/stack/material/woodplank) == "planks", "iron and planks pay for slipway pieces")
	var/datum/ship_draught/skiff = new
	skiff.name = "Tern"
	for (var/x = 0, x < 3, x++)
		for (var/y = 0, y < 4, y++)
			skiff.set_floor(x, y, (x == 2 && y == 3) ? "s" : "w")
	skiff.set_piece(1, 0, "T")
	skiff.set_piece(0, 1, "R", EAST)
	skiff.set_piece(2, 2, "W")
	skiff.set_piece(1, 3, "K")
	skiff.set_upper(1, 1, TRUE)
	var/datum/slipway_design/draught/plan = slipway_draught_plan(skiff)
	var/list/stage_names = list()
	for (var/list/stage in plan.stages)
		stage_names += stage["name"]
	naval_check(plan.total_pieces() == 17 && jointext(stage_names, "|") == "Plank floors|Steel floors|Tillers|Rowing benches|Killicks|Plank walls|Deck above", "a draught builds floor by floor, then her fittings kind by kind ([jointext(stage_names, "|")])")
	var/list/plan_cost = plan.total_cost()
	naval_check(plan_cost["wood"] == 50 && plan_cost["steel"] == 1 && plan_cost["planks"] == 4 && plan_cost.len == 3, "she costs her hand-built floors and fittings, and her deck above last ([piece_cost_text(plan_cost)])")
	naval_check(plan.order[1][1] == "0,0" && plan.order[12][1] == "2,3", "her floors go down from stern to bow")
	// The plan keeps its draught; the probe draws a fresh one for the post.
	plan.draught = null
	qdel(plan)

	var/obj/structure/slipway/ways = new(locate(5, 30, 2))
	ways.dir = EAST
	var/obj/structure/vessel_mast/block = new(locate(8, 29, 2))
	var/refusal = ways.draught_refusal(skiff)
	naval_check(refusal && findtext(refusal, "in the way"), "something solid on her berth refuses the draught ([refusal])")
	qdel(block)
	var/obj/covers/repairedfloor/old_floor = new(locate(9, 30, 2))
	refusal = ways.draught_refusal(skiff)
	naval_check(refusal && findtext(refusal, "already floors"), "a floor already on her berth refuses the draught ([refusal])")
	qdel(old_floor)
	var/datum/ship_draught/helmless = ship_draught_from_code(skiff.to_code())
	helmless.set_piece(1, 0, null)
	refusal = ways.draught_refusal(helmless)
	naval_check(refusal && findtext(refusal, "no helm"), "a draught that could not be commissioned is refused ([refusal])")
	qdel(helmless)
	var/obj/structure/slipway/edge = new(locate(2, 10, 2))
	edge.dir = WEST
	refusal = edge.draught_refusal(skiff)
	naval_check(refusal && findtext(refusal, "edge of the world"), "a berth off the map is refused ([refusal])")
	qdel(edge)
	naval_check(!ways.draught_refusal(skiff), "the berth east of the post takes her")

	ways.lay_draught(skiff)
	naval_check(ways.design == "Tern" && ways.draught_code == skiff.to_code() && slipway_frame_count(ways) == 12 && slipway_frames_named(ways, "cradle") == 12, "laying her out marks her 12 tiles with the cradle")
	var/obj/structure/slipway_frame/stern_frame = locate() in locate(6, 30, 2)
	var/obj/structure/slipway_frame/bow_frame = locate() in locate(9, 30, 2)
	naval_check(stern_frame && bow_frame && !(locate(/obj/structure/slipway_frame) in locate(10, 30, 2)) && !(locate(/obj/structure/slipway_frame) in locate(5, 30, 2)), "her stern is before the post and her bow runs east")
	naval_check(findtext(ways.status_text(), "plank floor") && findtext(ways.status_text(), "2 wood"), "the post asks for the first plank floor ([ways.status_text()])")
	var/obj/item/stack/material/steel/wrong_stack = new(ways.loc)
	wrong_stack.amount = 10
	naval_check(!ways.pay(wrong_stack), "steel does not pay for a plank floor")
	var/obj/item/stack/material/wood/one_floor = new(ways.loc)
	one_floor.amount = 2
	ways.pay(one_floor)
	naval_check(ways.pieces_done == 1 && (locate(/obj/covers/repairedfloor) in locate(6, 31, 2)) && !(locate(/obj/structure/slipway_frame) in locate(6, 31, 2)) && slipway_frame_count(ways) == 11, "a paid floor is laid at once, stern to starboard first, and its marker goes")
	var/list/pay_paths = list("wood" = /obj/item/stack/material/wood, "steel" = /obj/item/stack/material/steel, "iron" = /obj/item/stack/material/iron, "planks" = /obj/item/stack/material/woodplank)
	var/guard = 0
	while (ways.pieces_done < 12 && guard++ < 50)
		var/list/needed = ways.still_needed()
		for (var/key in needed)
			var/path = pay_paths[key]
			var/obj/item/stack/stack = new path(ways.loc)
			stack.amount = needed[key]
			ways.pay(stack)
	var/obj/structure/slipway_frame/tiller_mark = locate() in locate(6, 30, 2)
	naval_check(ways.pieces_done == 12 && (locate(/obj/covers/steelplating) in locate(9, 29, 2)) && tiller_mark && findtext(tiller_mark.name, "tiller") && slipway_frame_count(ways) == 4, "with her floors down only her four fittings stay marked ([slipway_frame_count(ways)])")
	// A reload rebuilds the plan and the markers from the saved code.
	ways.draught_cache = null
	ways.update_frames()
	naval_check(slipway_frame_count(ways) == 4 && ways.get_design() && ways.next_piece() ~= list(3, 1), "after a load the same four markers come back")
	guard = 0
	while (ways.next_piece() && guard++ < 50)
		var/list/needed = ways.still_needed()
		for (var/key in needed)
			var/path = pay_paths[key]
			var/obj/item/stack/stack = new path(ways.loc)
			stack.amount = needed[key]
			ways.pay(stack)
	var/obj/structure/hull_tiller/built_tiller = locate() in locate(6, 30, 2)
	var/obj/structure/bed/chair/wood/rowing_bench/built_bench = locate() in locate(7, 31, 2)
	naval_check(ways.finished() && !slipway_frame_count(ways), "every piece paid, she is finished and no marker is left")
	naval_check(built_tiller && built_tiller.type == /obj/structure/hull_tiller && built_bench && built_bench.dir == SOUTH && (locate(/obj/covers/wood_wall/adjustable) in locate(8, 29, 2)) && (locate(/obj/structure/hull_anchor/stone) in locate(9, 30, 2)), "her fittings stand where drawn, the bench turned to face starboard as her bow faces east")
	naval_check(findtext(ways.status_text(), "ready to launch"), "a finished draught is ready to launch ([ways.status_text()])")

	// The launch: she slides east until all of her floats, crew aboard.
	var/obj/structure/vessel_mast/chock = new(locate(15, 30, 2))
	var/launched = ways.launch()
	naval_check(istext(launched) && findtext(launched, "in the way down the ways") && ways.design, "something solid on the ways holds her ([launched])")
	qdel(chock)
	built_tiller.loc = null
	launched = ways.launch()
	naval_check(istext(launched) && findtext(launched, "helm is gone"), "she will not launch without her tiller ([launched])")
	built_tiller.loc = locate(6, 30, 2)
	var/mob/living/human/naval_probe/crew = new(locate(7, 30, 2))
	launched = ways.launch()
	var/obj/structure/hull_tiller/afloat = launched
	naval_check(istype(afloat) && afloat == built_tiller && afloat.loc == locate(21, 30, 2) && afloat.craft && afloat.craft.name == "Tern", "she slides 15 tiles to the first water that floats all of her and is commissioned as the Tern ([istext(launched) ? launched : "launched"])")
	naval_check(afloat && afloat.craft && afloat.craft.body.tile_count() == 12, "all 12 of her tiles sail")
	var/datum/craft_body/built/tern_body = afloat ? afloat.craft.body : null
	naval_check(tern_body && tern_body.upper_tile_count() == 1, "the deck above the slipway roofed over her sails with her ([tern_body ? tern_body.upper_tile_count() : 0])")
	naval_check(crew.loc == locate(22, 30, 2) && built_bench.loc == locate(22, 31, 2) && built_bench.dir == SOUTH && (locate(/obj/covers/steelplating) in locate(24, 29, 2)), "her crew and fittings go with her")
	naval_check(!hull_floor_in(locate(6, 30, 2)) && !ways.design && !ways.draught_code && !slipway_frame_count(ways), "the berth is left empty and the post clear")

	// ---- A ship on three levels from the slipway ----
	var/datum/ship_draught/gannet = draught_box(3, 5, "Gannet")
	gannet.set_deck(-1, 1, 1, TRUE)
	gannet.set_deck(-1, 1, 2, TRUE)
	gannet.set_deck_piece(-1, 1, 1, "X")
	gannet.set_deck_piece(-1, 1, 2, "C")
	for (var/x = 0, x < 3, x++)
		gannet.set_deck(1, x, 4, TRUE)
	gannet.set_piece(2, 3, "S")
	gannet.set_piece(1, 4, "X")
	gannet.set_deck_piece(1, 0, 4, "B")
	naval_check(gannet.buildable(), "the Gannet with a hold and a deck above can be built ([jointext(gannet.problems(), " ")])")
	var/datum/slipway_design/draught/gannet_plan = slipway_draught_plan(gannet)
	var/list/gannet_stages = list()
	for (var/list/stage in gannet_plan.stages)
		gannet_stages += stage["name"]
	naval_check(findtext(jointext(gannet_stages, "|"), "Hold floors|Deck above|Wood crates below and above|Beds below and above|Ladders"), "her other decks are built last: hold, deck above, what stands on them, then ladders ([jointext(gannet_stages, "|")])")
	gannet_plan.draught = null
	qdel(gannet_plan)
	var/obj/structure/slipway/high_ways = new(locate(5, 48, 2))
	high_ways.dir = EAST
	var/turf/no_rock = locate(7, 48, 1)
	var/no_rock_type = no_rock.type
	no_rock.ChangeTurf(/turf/floor/dirt)
	refusal = high_ways.draught_refusal(gannet)
	naval_check(refusal && findtext(refusal, "hold cannot be dug"), "a berth with no rock under it refuses her hold ([refusal])")
	no_rock.ChangeTurf(no_rock_type)
	var/obj/covers/repairedfloor/overhead = new(locate(10, 48, 3))
	refusal = high_ways.draught_refusal(gannet)
	naval_check(refusal && findtext(refusal, "open air over the berth"), "a floor over the berth refuses her deck above ([refusal])")
	qdel(overhead)
	naval_check(!high_ways.draught_refusal(gannet), "the berth takes her ([high_ways.draught_refusal(gannet)])")
	high_ways.lay_draught(gannet)
	guard = 0
	while (high_ways.next_piece() && guard++ < 80)
		var/list/needed = high_ways.still_needed()
		for (var/key in needed)
			var/path = pay_paths[key]
			var/obj/item/stack/stack = new path(high_ways.loc)
			stack.amount = needed[key]
			high_ways.pay(stack)
	var/obj/structure/multiz/ladder/up/placed/hold_foot = locate() in locate(7, 48, 1)
	var/obj/structure/multiz/ladder/placed/hold_head = locate() in locate(7, 48, 2)
	naval_check(high_ways.finished() && hull_hold_cover(locate(7, 48, 1)) && hull_hold_cover(locate(8, 48, 1)) && (locate(/obj/structure/closet/crate) in locate(8, 48, 1)), "her hold is dug and floored under the berth, with its crate ([high_ways.finished()])")
	naval_check(hold_foot && hold_head && hold_foot.target == hold_head, "the hold ladder joins her hold to her deck")
	var/obj/roof/deck_roof = locate() in locate(10, 47, 2)
	naval_check(deck_roof && deck_roof.building_floor() && (locate(/obj/structure/bed) in locate(10, 49, 3)), "her deck above is a roof over her bow with its floor above, and the bed stands on it")
	var/obj/structure/hull_tiller/gannet_tiller = locate() in locate(8, 48, 2)
	var/gannet_launched = high_ways.launch()
	var/datum/craft_body/built/GB = istype(gannet_launched, /obj/structure/hull_tiller) && gannet_tiller.craft ? gannet_tiller.craft.body : null
	var/gannet_hold = 0
	if (GB)
		for (var/turf/L in GB.lower_cells())
			gannet_hold++
	naval_check(GB && GB.tile_count() == 15 && GB.upper_tile_count() == 3 && gannet_hold == 2, "she launches with all three decks ([istext(gannet_launched) ? gannet_launched : "launched"]; [GB ? "[GB.upper_tile_count()] above, [gannet_hold] hold" : "no body"])")
	naval_check(!hull_hold_cover(locate(7, 48, 1)) && istype(locate(7, 48, 1), /turf/wall/rockwall), "the rock under the berth closes behind her hold")
	if (gannet_tiller && gannet_tiller.craft)
		gannet_tiller.decommission()
	qdel(high_ways)
	qdel(gannet)

	// Facing along the shore there is no water to launch into.
	ways.dir = NORTH
	refusal = ways.draught_refusal(skiff)
	naval_check(refusal && findtext(refusal, "no open water"), "a berth with no water ahead refuses the draught ([refusal])")
	ways.dir = EAST
	ways.lay_draught(skiff)
	ways.abandon()
	naval_check(!ways.design && !ways.draught_code && !slipway_frame_count(ways), "giving her up clears the post")
	qdel(skiff)

	// ---- Her sides (naval/hull_sides.dm) ----
	var/obj/structure/railing/built/gunwale/G = new(locate(3, 3, 2))
	var/obj/structure/railing/built/gunwale/bulwark/BW = new(locate(3, 3, 2))
	naval_check(!G.hull_load() && !BW.hull_load(), "gunwales and bulwarks are part of her hull and weigh nothing on her deck")
	qdel(G)
	qdel(BW)
	var/datum/ship_draught/petrel = draught_box(3, 5, "Petrel")
	petrel.set_floor(2, 4, "s")
	var/datum/slipway_design/draught/rail_plan = slipway_draught_plan(petrel)
	var/list/rail_stages = list()
	for (var/list/stage in rail_plan.stages)
		rail_stages += stage["name"]
	naval_check(jointext(rail_stages, "|") == "Plank floors|Steel floors|Tillers|Wooden gunwales|Steel bulwarks" && rail_plan.total_pieces() == 32, "a boat's draught ends with her gunwales, bulwarks on steel ([jointext(rail_stages, "|")])")
	rail_plan.draught = null
	qdel(rail_plan)
	var/obj/structure/slipway/rail_ways = new(locate(5, 40, 2))
	rail_ways.dir = EAST
	naval_check(!rail_ways.draught_refusal(petrel), "the berth takes the Petrel")
	rail_ways.lay_draught(petrel)
	guard = 0
	while (rail_ways.pieces_done < 16 && guard++ < 50)
		var/list/needed = rail_ways.still_needed()
		for (var/key in needed)
			var/path = pay_paths[key]
			var/obj/item/stack/stack = new path(rail_ways.loc)
			stack.amount = needed[key]
			rail_ways.pay(stack)
	naval_check(slipway_frames_named(rail_ways, "gunwale") == 11 && slipway_frames_named(rail_ways, "bulwark") == 1, "with her floors and tiller in, her edge tiles are marked for gunwales and her steel corner for a bulwark ([slipway_frames_named(rail_ways, "gunwale")], [slipway_frames_named(rail_ways, "bulwark")])")
	guard = 0
	while (rail_ways.next_piece() && guard++ < 50)
		var/list/needed = rail_ways.still_needed()
		for (var/key in needed)
			var/path = pay_paths[key]
			var/obj/item/stack/stack = new path(rail_ways.loc)
			stack.amount = needed[key]
			rail_ways.pay(stack)
	var/obj/structure/railing/built/gunwale/stern_rail
	for (var/obj/structure/railing/built/gunwale/R in locate(6, 40, 2))
		if (R.dir == WEST)
			stern_rail = R
	var/obj/structure/railing/built/gunwale/bulwark/bow_bulwark
	for (var/obj/structure/railing/built/gunwale/bulwark/R in locate(10, 39, 2))
		if (R.dir == EAST)
			bow_bulwark = R
	naval_check(rail_ways.finished() && stern_rail && bow_bulwark, "her gunwales stand along her edges turned with her: the stern rail faces west, the steel bow corner's bulwark east")
	launched = rail_ways.launch()
	var/obj/structure/hull_tiller/petrel_tiller = launched
	naval_check(istype(petrel_tiller) && petrel_tiller.craft && !length(petrel_tiller.open_sides()), "launched, the Petrel has no open side ([istext(launched) ? launched : "launched"])")
	if (istype(petrel_tiller) && petrel_tiller.craft)
		var/list/petrel_deck = petrel_tiller.craft.body.cells()
		var/rails_aboard = 0
		for (var/turf/T in petrel_deck)
			for (var/obj/structure/railing/built/gunwale/R in T)
				rails_aboard++
		naval_check(rails_aboard == 16 && !hull_sides_refusal(petrel_deck), "all 16 gunwales slid down the ways with her")
		var/turf/rail_turf
		for (var/turf/T in petrel_deck)
			if (!rail_turf && (locate(/obj/structure/railing/built/gunwale) in T) && !(locate(/obj/structure/railing/built/gunwale/bulwark) in T))
				rail_turf = T
		var/list/packed = list("crew" = list(), "refused" = list(), "blocking" = list(), "items" = 0, "cargo" = 0)
		var/list/rail_entries = sea_crossing_pack_tile(rail_turf, petrel_tiller, packed)
		var/rail_kinds = 0
		for (var/list/E in rail_entries)
			if (E[1] == "r")
				rail_kinds++
		naval_check(rail_kinds && !packed["cargo"], "her gunwales cross the sea as part of her hull, not as cargo")
		for (var/obj/structure/railing/built/gunwale/R in rail_turf)
			qdel(R)
		naval_check(length(petrel_tiller.open_sides()) && findtext(petrel_tiller.status_text(), "open"), "a gunwale taken off opens her side and the tiller says so")
		var/why = hull_sides_refusal(petrel_deck)
		naval_check(why && findtext(why, "Rail her sides") && (locate(/obj/effect/vessel_path/open_side) in rail_turf), "she cannot be refitted with an open side, and it is marked on her deck ([why])")
		naval_check(hull_rail_sides_free(petrel_deck) && !hull_sides_refusal(petrel_deck), "railing her open sides closes her all round")

		// ---- A gangway and her gangplank (naval/hull_gangway.dm) ----
		var/obj/structure/railing/built/gunwale/side_rail = locate(/obj/structure/railing/built/gunwale) in rail_turf
		var/out_dir = side_rail ? side_rail.dir : NORTH
		qdel(side_rail)
		var/obj/structure/railing/built/gunwale/gangway/way = new(rail_turf)
		way.set_dir(out_dir)
		naval_check(!hull_sides_refusal(petrel_deck), "a gangway closes her side like a gunwale")
		var/turf/gap1 = get_step(rail_turf, out_dir)
		var/turf/gap2 = get_step(gap1, out_dir)
		var/turf/pier_turf = get_step(gap2, out_dir)
		naval_check(findtext(hull_gangplank_plan(way), "no pier"), "with open water off her gangway there is nothing to run the plank out to ([hull_gangplank_plan(way)])")
		var/obj/covers/pier = draught_lay(pier_turf.x, pier_turf.y)
		var/list/plank_plan = hull_gangplank_plan(way)
		naval_check(islist(plank_plan) && plank_plan.len == 2 && plank_plan[1] == gap1, "a pier three tiles off takes a two-tile gangplank")
		petrel_tiller.craft.set_speed(VESSEL_SPEED_SLOW)
		naval_check(findtext(hull_run_out_gangplank(way), "stopped"), "the gangplank goes out only when she is stopped")
		petrel_tiller.craft.set_speed(VESSEL_SPEED_STOP)
		naval_check(isnull(hull_run_out_gangplank(way)) && way.planks.len == 2 && way.gate_open && (locate(/obj/covers/repairedfloor/rope/boarding/gangplank) in gap2), "the gangplank runs out over the water and the gangway opens")
		naval_check(!hull_floor_in(gap1), "a gangplank is not part of her hull, so she is no jetty")
		var/held = petrel_tiller.craft.gangplank_refusal()
		naval_check(held && findtext(held, "Take it in"), "she is held while her gangplank is out ([held])")
		naval_check(hull_take_in_gangplank(way) && !way.planks.len && !(locate(/obj/covers/repairedfloor/rope/boarding/gangplank) in gap1) && !petrel_tiller.craft.gangplank_refusal(), "taken in, the plank is gone and she may sail")
		hull_run_out_gangplank(way)
		var/obj/covers/broken_plank = way.planks[1]
		qdel(broken_plank)
		naval_check(!way.planks.len && !(locate(/obj/covers/repairedfloor/rope/boarding/gangplank) in gap2) && !petrel_tiller.craft.gangplank_refusal(), "a broken plank brings the rest in")
		qdel(pier)

		// ---- Going aloft (naval/hull_masts.dm) ----
		var/turf/mast_turf
		for (var/turf/T in petrel_deck)
			if (!mast_turf && !(locate(/obj/structure/railing) in T) && !(locate(/obj/structure/hull_tiller) in T))
				mast_turf = T
		var/obj/structure/vehicleparts/movement/sail/aloft_mast = new(mast_turf)
		var/mob/living/human/naval_probe/topman = new(get_step(mast_turf, NORTH))
		var/datum/craft/petrel_craft = petrel_tiller.craft
		var/below = petrel_craft.lookout_range()
		naval_check(!petrel_craft.aloft_reach() && isnull(topman.mast_climb_refusal(aloft_mast)), "nobody is aloft yet, and a sailor beside the mast may climb it")
		naval_check(topman.go_aloft(aloft_mast) && topman.climbed_tree == aloft_mast && topman.loc == mast_turf && los_up_tree(topman), "up the mast, the sailor stands at its masthead and sees over walls")
		naval_check(petrel_craft.aloft_reach() == 4 && petrel_craft.lookout_range() == below + 4, "a sailor at the masthead lets her lookout see 4 tiles further")
		aloft_mast.crows_nest = TRUE
		naval_check(petrel_craft.aloft_reach() == 8 && mast_look_amount(aloft_mast) > 8, "from a crow's nest her lookout sees 8 tiles further, and Look into Distance reaches further")
		naval_check(ship_draught_piece_on(mast_turf, petrel_tiller) ~= list("N", aloft_mast.dir), "drawing her lines draws a mast with a crow's nest as one")
		topman.climb_down_tree()
		naval_check(!topman.climbed_tree && !aloft_mast.mast_aloft() && !petrel_craft.aloft_reach(), "climbed down, nobody is aloft")
		qdel(aloft_mast)
		qdel(topman)

		// ---- Her bow (naval/hull_bow.dm) ----
		var/bow_dir = petrel_craft.body.heading()
		var/turf/bow_turf
		var/turf/stern_turf
		for (var/turf/T in petrel_deck)
			if (!(locate(/obj/structure/hull_tiller) in T) && !(locate(/obj/structure/vehicleparts/movement/sail) in T))
				if (!bow_turf && !petrel_craft.body.carries(get_step(T, bow_dir)))
					bow_turf = T
				if (!stern_turf && !petrel_craft.body.carries(get_step(T, turn(bow_dir, 180))))
					stern_turf = T
		var/obj/structure/vehicleparts/movement/sail/bowsprit/sprit = new(bow_turf)
		sprit.sails = new /obj/item/sail(sprit)
		var/datum/craft_drive/fitted/sail/jib/jib = sprit.craft_drive()
		jib.craft = petrel_craft
		naval_check(jib.ready() && jib.thrust == CRAFT_SAIL_THRUST * 0.5, "a jib rigged on a bowsprit at her bow draws, with half a mast's thrust")
		sprit.forceMove(stern_turf)
		naval_check(!jib.ready(), "a bowsprit with her deck ahead of it draws nothing")
		jib.craft = null
		qdel(jib)
		var/mob/living/human/naval_probe/sprit_climber = new(get_turf(sprit))
		sprit_climber.a_intent = I_GRAB
		naval_check(!sprit.mast_grab_climb(sprit_climber), "nobody climbs a bowsprit")
		qdel(sprit_climber)
		qdel(sprit)
		var/obj/structure/figurehead/figure = new(bow_turf)
		naval_check(!figure.carving && figure.carve("wolf") && figure.name == "wolf figurehead" && !figure.carve("dragon"), "a figurehead is carved once, as one of its figures")
		naval_check(ship_draught_piece_on(bow_turf, petrel_tiller) ~= list("F", figure.dir), "drawing her lines draws a figurehead")
		qdel(figure)
		// Her bowsprit's picture is centred on its tile by a fixed offset,
		// which a turn must leave alone while its dir comes round with her.
		var/obj/structure/vehicleparts/movement/sail/bowsprit/turned_sprit = new(bow_turf)
		turned_sprit.set_dir(bow_dir)
		var/sprit_turns = 0
		var/sprit_square = (turned_sprit.pixel_x == -32 && turned_sprit.pixel_y == -32)
		for (var/heading in list(turn(bow_dir, 90), turn(bow_dir, 180), turn(bow_dir, -90), bow_dir))
			if (!petrel_craft.body.turn_to(heading))
				continue
			sprit_turns++
			if (turned_sprit.dir != heading || turned_sprit.pixel_x != -32 || turned_sprit.pixel_y != -32)
				sprit_square = FALSE
		naval_check(sprit_turns == 4 && sprit_square, "turned to every heading, her bowsprit points ahead and keeps its picture centred on its tile ([sprit_turns] turns, [turned_sprit.pixel_x],[turned_sprit.pixel_y])")
		qdel(turned_sprit)
	qdel(petrel)
	draught_design_checks()

// ---- Design checks (craft/design_checks.dm, naval/draught_checks.dm) ----
/proc/draught_report_has(datum/design_report/R, level, text)
	for (var/datum/design_finding/F in R.findings)
		if (F.level == level && findtext(F.text, text))
			return F
	return null

/proc/draught_design_checks()
	// The checks are found by kind, in order, with nothing listing them.
	var/list/ship_checks = design_checks_for("ship")
	var/list/sub_checks = design_checks_for("sub")
	var/list/vehicle_checks = design_checks_for("vehicle")
	var/ordered = TRUE
	for (var/i = 2, i <= ship_checks.len, i++)
		var/datum/design_check/A = ship_checks[i - 1]
		var/datum/design_check/B = ship_checks[i]
		if (A.order > B.order)
			ordered = FALSE
	naval_check(ship_checks.len >= 10 && sub_checks.len >= 4 && vehicle_checks.len >= 3 && ordered && !design_checks_for("rocket").len, "design checks are gathered by kind and run in order ([ship_checks.len] ship, [sub_checks.len] submarine, [vehicle_checks.len] vehicle)")

	// Errors are problems(); the ready-made ships have no warnings either.
	for (var/datum/ship_draught/E in ship_draught_examples())
		var/datum/design_report/R = E.check_design()
		naval_check(!R.blocked() && !R.count(DESIGN_WARNING), "the ready-made [E.name] has no errors or warnings ([jointext(R.texts(DESIGN_WARNING), " ")])")
		qdel(R)
		qdel(E)
	var/datum/ship_draught/blank = new
	var/datum/design_report/BR = blank.check_design()
	naval_check(BR.findings.len == 1 && BR.blocked() && findtext(BR.texts(DESIGN_ERROR)[1], "Nothing is drawn"), "a blank sheet has one error and nothing else")
	qdel(BR)

	// A 6x10 hull with only a tiller: no drive, pump or anchor.
	var/datum/ship_draught/D = draught_box(6, 10, "Hulk")
	var/datum/design_report/R = D.check_design()
	naval_check(!R.blocked() && draught_report_has(R, DESIGN_WARNING, "no masts, rowing benches or engine") && draught_report_has(R, DESIGN_WARNING, "no bilge pump") && draught_report_has(R, DESIGN_WARNING, "no anchor"), "a bare hull builds but warns of no drive, no pump and no anchor")
	qdel(R)
	// A killick holds 40 of her 60 tiles.
	D.set_piece(0, 0, "K")
	D.set_piece(1, 0, "P")
	D.set_piece(2, 2, "M")
	R = D.check_design()
	var/datum/design_finding/drag = draught_report_has(R, DESIGN_WARNING, "hold 40 tiles")
	naval_check(drag && drag.cells && ("0,0" in drag.cells) && !draught_report_has(R, DESIGN_WARNING, "no anchor") && !draught_report_has(R, DESIGN_WARNING, "no bilge pump"), "an anchor too small for her says so and lights the anchor")
	qdel(R)
	// A cannon facing across her deck, with a wall behind it.
	D.set_piece(0, 5, "Z", EAST)
	D.set_piece(5, 5, "H", EAST)
	R = D.check_design()
	var/datum/design_finding/aim = draught_report_has(R, DESIGN_WARNING, "across her own deck")
	naval_check(aim && ("0,5" in aim.cells) && !("5,5" in aim.cells) && aim.part == "Z", "a gun pointing across her deck is warned of, a gun facing out over the side is not")
	qdel(R)
	// A pump walled in on every side.
	D.set_piece(3, 7, "P")
	D.set_piece(2, 7, "W")
	D.set_piece(4, 7, "W")
	D.set_piece(3, 6, "W")
	D.set_piece(3, 8, "W")
	R = D.check_design()
	var/datum/design_finding/shut = draught_report_has(R, DESIGN_WARNING, "Crew cannot reach")
	naval_check(shut && shut.cells.len == 1 && shut.cells[1] == "3,7" && findtext(shut.text, "hand bilge pump"), "a pump walled in on every side cannot be reached ([shut ? shut.text : "no warning"])")
	D.set_piece(3, 8, "D")
	R = D.check_design()
	naval_check(!draught_report_has(R, DESIGN_WARNING, "Crew cannot reach"), "a door in the wall lets crew reach it")
	qdel(R)
	// Two pieces of hull light up the piece away from her helm.
	D.set_floor(12, 12, "w")
	R = D.check_design()
	var/datum/design_finding/apart = draught_report_has(R, DESIGN_ERROR, "more than one piece")
	naval_check(apart && apart.cells.len == 1 && apart.cells[1] == "12,12", "a stray tile is the one lit up as apart from her")
	var/list/data = R.data()
	naval_check(data.len == R.findings.len && data[1]["level"] == "error", "the window gets every finding, worst first")
	qdel(R)
	// The engine counts as a drive.
	var/datum/ship_draught/steamer = draught_box(4, 8, "Steamer")
	steamer.set_piece(1, 1, "E")
	naval_check(steamer.engine_push() > 0 && steamer.engine_step() >= VESSEL_SPEED_HALF && findtext(steamer.summary_text(), "under steam"), "a steam engine drives her and the summary says how fast ([steamer.engine_step()])")
	qdel(steamer)
	qdel(D)

	// Every part the designers offer is described.
	var/list/ship_help = design_part_help_for("ship")
	var/list/undescribed = list()
	for (var/key in ship_draught_pieces() + ship_draught_floors() + list("u", "x"))
		var/list/H = ship_help[key]
		if (!H || !length(H["what"]) || !length(H["use"]) || !length(H["how"]))
			undescribed += key
	var/list/sub_help = design_part_help_for("sub")
	for (var/key in sub_draught_fittings + sub_draught_frames + list("wb", "wd", "wn"))
		var/list/H = sub_help[key]
		if (!H || !length(H["what"]) || !length(H["use"]) || !length(H["how"]))
			undescribed += "sub [key]"
	naval_check(!undescribed.len && design_part_help_text("ship", "M"), "every floor, piece, section, fitting and tool is described ([jointext(undescribed, ", ")])")
	var/obj/item/ship_draught/pad = new(locate(5, 5, 2))
	var/html = ship_designer_html(pad, null)
	naval_check(findtext(html, "\"HELP\":") && findtext(html, "Holds 40 tiles"), "the ship window carries the part descriptions")
	qdel(pad)

	// Submarines: no banks warn, a second wheel is an error on its cells.
	var/datum/sub_draught/S = new(5)
	S.set_fitting(2, 1, "W")
	S.set_fitting(1, 2, "S")
	S.set_frame(3, 3, "x")
	var/datum/design_report/SR = S.check_design()
	naval_check(!SR.blocked() && draught_report_has(SR, DESIGN_WARNING, "no battery bank") && draught_report_has(SR, DESIGN_WARNING, "no air bank") && draught_report_has(SR, DESIGN_NOTE, "no berth"), "a submarine without banks builds but warns")
	qdel(SR)
	S.set_fitting(3, 2, "W")
	SR = S.check_design()
	var/datum/design_finding/wheels = draught_report_has(SR, DESIGN_ERROR, "2 of the ship's wheel")
	naval_check(wheels && ("3,2" in wheels.cells) && ("2,1" in wheels.cells) && S.problems().len == 1, "two wheels are an error lit on both")
	qdel(SR)
	qdel(S)

/proc/slipway_frames_named(obj/structure/slipway/S, text)
	. = 0
	for (var/obj/structure/slipway_frame/F in S.frames)
		if (!QDELETED(F) && findtext(F.name, text))
			.++

/proc/slipway_frame_count(obj/structure/slipway/S)
	. = 0
	for (var/obj/structure/slipway_frame/F in S.frames)
		if (!QDELETED(F))
			.++

/proc/naval_run()
	try
		naval_checks()
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = naval_failures, "runtime_error" = naval_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/naval_probe
		naval_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		naval_run()
