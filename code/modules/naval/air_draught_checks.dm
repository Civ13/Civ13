// ============================================================
// Checks and part book for airship sheets (docs/airship-sheets.md)
// ------------------------------------------------------------
// Design checks (design_checks.dm) of kind "air_sheet" judge a
// /datum/air_draught the way the helm (air_hull.dm) will judge the airship
// built from it: an error stops her being commissioned or lifting off, a
// warning is a part left out or a crew she can barely carry, a note is
// advice. Cells are the sheet's "col,row".
// tests/ship_draught/test_design_checks.py wants a part book entry for every
// key in the sheet's tables.
// ============================================================

/datum/design_check/air_sheet
	kind = "air_sheet"
	abstract_type = /datum/design_check/air_sheet

/datum/design_check/air_sheet/check(datum/air_draught/D, datum/design_report/R)
	if (istype(D))
		sheet_check(D, R)

/datum/design_check/air_sheet/proc/sheet_check(datum/air_draught/D, datum/design_report/R)
	return

// Her deck is every tile joined to the helm's edge to edge, and her gas
// cells hold up no more than AIR_DRAUGHT_MAX_DECK tiles of it.
/datum/design_check/air_sheet/deck
	order = 10

/datum/design_check/air_sheet/deck/sheet_check(datum/air_draught/D, datum/design_report/R)
	var/list/deck = D.deck_cells()
	if (!deck.len)
		R.error("She has no deck. Lay airship planks or frames on the tiles she should cover.", null, "p")
		return
	if (deck.len > AIR_DRAUGHT_MAX_DECK)
		R.error("She has [deck.len] tiles of deck; an airship can have [AIR_DRAUGHT_MAX_DECK] at most.", null, "p")
	var/list/joined = D.joined_deck()
	if (joined.len < deck.len)
		R.error("Her deck is in pieces: [deck.len - joined.len] tile\s are not joined edge to edge to the rest and would be left behind.", deck - joined, "p")

/datum/design_check/air_sheet/helm
	order = 20

/datum/design_check/air_sheet/helm/sheet_check(datum/air_draught/D, datum/design_report/R)
	var/list/at = D.part_cells("W")
	if (!at.len)
		R.error("She has no helm: nobody can commission or steer her. Stand an airship helm on her deck.", null, "W")
		return
	if (at.len > 1)
		R.warning("She has [at.len] helms; only one commissions and steers her. The yard sets up the first and leaves the rest off.", at.Copy(2), "W")

/datum/design_check/air_sheet/lift
	order = 30

/datum/design_check/air_sheet/lift/sheet_check(datum/air_draught/D, datum/design_report/R)
	var/list/deck = D.deck_cells()
	if (!deck.len)
		return
	var/lift = D.lift()
	var/empty = D.weight()
	var/crewed = D.crewed_weight()
	var/list/cells = D.gas_cells()
	if (!cells.len)
		R.error("She has no gas cells: nothing holds her up. Hang gas cells over her deck.", null, "c")
	else if (lift < empty)
		R.error("Her gas cells hold up [lift] and her deck alone weighs [empty]: she will never lift. Hang more cells or lay a lighter deck.", cells, "c")
	else if (lift < crewed)
		R.error("Her gas cells hold up [lift] and she weighs [crewed] with a crew of [D.crew]: she lifts empty but not crewed. Hang more cells or carry fewer people.", cells, "c")
	else if (lift - crewed < 2)
		R.warning("She lifts her crew of [D.crew] with only [lift - crewed] to spare: a hole in one cell, a passenger or helium instead of hydrogen will ground her.", cells, "c")
	if (cells.len)
		R.note("Her cells hang empty. Fill each with [round(AIR_DRAUGHT_CELL_GAS)] units of hydrogen or helium; helium does not burn but lifts a tenth less.", cells, "c")

/datum/design_check/air_sheet/engines
	order = 40

/datum/design_check/air_sheet/engines/sheet_check(datum/air_draught/D, datum/design_report/R)
	var/list/engines = D.part_cells("E")
	var/list/tanks = D.tank_cells()
	if (!engines.len)
		if (tanks.len)
			R.warning("She carries fuel tanks but no engine to burn it.", tanks, "T")
		R.note("She has no engine, so she creeps at slow ahead only. An engine aboard drives her faster.", null, "E")
		return
	if (tanks.len < engines.len)
		R.warning("She has [engines.len] engine\s and [tanks.len] fuel tank\s; each engine draws from its own tank, so [engines.len - tanks.len] will not run.", engines, "E")
	else if (tanks.len > engines.len)
		R.note("She has more fuel tanks than engines; the spare tanks are not connected.", tanks, "T")
	var/push = D.engine_power() * engines.len
	var/list/deck = D.deck_cells()
	if (deck.len && push < deck.len)
		R.warning("Her engines push [round(push)] against [deck.len] tiles of deck: not enough for half ahead. Draw bigger or more engines.", engines, "E")
	else if (deck.len && push < deck.len * 2)
		R.note("Her engines make half ahead but not full ahead; full ahead needs [deck.len * 2] of push.", engines, "E")
	var/list/E = vehicle_draught_engines[D.engine]
	if (E)
		R.note("Her [D.engine_name()]s burn [english_list(E["fuels"])]. Built tanks leave empty: fill them before casting off.", tanks, D.engine)

/datum/design_check/air_sheet/fire
	order = 50

/datum/design_check/air_sheet/fire/sheet_check(datum/air_draught/D, datum/design_report/R)
	var/wood = 0
	for (var/key in D.cells)
		var/list/C = D.cells[key]
		if (C[1] == "p")
			wood++
	if (wood && D.count_parts("E"))
		R.note("[wood] tile\s of her deck are wooden planks under running engines and hydrogen: aluminium or steel frames do not burn.", null, "a")

/datum/design_check/air_sheet/bombs
	order = 60

/datum/design_check/air_sheet/bombs/sheet_check(datum/air_draught/D, datum/design_report/R)
	var/hatches = D.count_parts("B")
	if (hatches)
		R.note("Her [hatches] bomb [hatches == 1 ? "hatch holds" : "hatches hold"] two aircraft bombs each, dropped on the ground below by pulling the ring.", D.part_cells("B"), "B")

// ---- What each part is ----

/datum/design_part_book/air_sheet
	kind = "air_sheet"

/datum/design_part_book/air_sheet/entries()
	return list(
		// Decks and the eraser
		"p" = list("what" = "Airship planks: one tile of light wooden gondola deck.", "use" = "Her deck. Every tile weighs 1 against her gas cells' lift, and it burns.", "how" = "Craft airship planks from 3 wood, or let the airship yard lay them from its wood."),
		"a" = list("what" = "An aluminium airship frame: girders and plates for one tile of deck.", "use" = "Weighs half a wooden tile and does not burn.", "how" = "Craft it from 3 aluminium after Powered Flight; the yard lays it from its aluminium."),
		"s" = list("what" = "A steel airship frame: girders and plates for one tile of deck.", "use" = "Weighs twice a wooden tile, does not burn, and flattens treetops instead of snagging on them.", "how" = "Craft it from 3 steel after Powered Flight; the yard lays it from its steel."),
		"x" = list("what" = "The eraser.", "use" = "Clears a tile back to open air: its deck, its gas cell and its part.", "how" = "Click a tile. Undo brings it back."),
		// Gas cells
		"c" = list("what" = "A gas cell of oiled cloth, hung over one tile of deck.", "use" = "Holds up 12 tiles of wooden deck or people when full; each hole loses a quarter of that.", "how" = "Craft it from 20 cloth; the yard hangs it empty. Fill it with hydrogen or helium."),
		"r" = list("what" = "A rubberised gas cell.", "use" = "Holds up 12 like a cloth cell but loses less of its gas when holed.", "how" = "Coat a cloth cell with 5 plastic or rubber sheets; the yard takes 20 cloth and 5 plastic."),
		"k" = list("what" = "A gas cell lined with goldbeater's skin.", "use" = "Holds up 15, the most of any cell, but each hole lets out a third of that.", "how" = "Line a cloth cell with 6 sausage casings; the yard takes 20 cloth and 6 casings."),
		// Parts
		"W" = list("what" = "The airship helm: her wheel and compass.", "use" = "Commissions the deck around it as an airship, casts her off and steers her. Her bow is the way it faces.", "how" = "Craft an airship helm kit from 10 wood and set it up on her deck facing the bow; the yard sets it facing north."),
		"E" = list("what" = "An engine of the kind and size chosen above the plan, standing on her deck.", "use" = "Drives her: half ahead needs 1 of push for each tile of deck, full ahead 2.", "how" = "Make it with the engine maker from steel and stand it on the deck with its own fuel tank beside it; the yard builds and connects both."),
		"Y" = list("what" = "A small fuel tank holding 120 units.", "use" = "Feeds one engine.", "how" = "Craft it from 10 steel and connect it to an engine."),
		"M" = list("what" = "A medium fuel tank holding 180 units.", "use" = "Feeds one engine for longer flights.", "how" = "Craft it from 15 steel and connect it to an engine."),
		"T" = list("what" = "A large fuel tank holding 250 units.", "use" = "Feeds one engine on long flights.", "how" = "Craft it from 20 steel and connect it to an engine."),
		"X" = list("what" = "A huge fuel tank holding 450 units.", "use" = "Feeds one big engine for a long time.", "how" = "Craft it from 36 steel and connect it to an engine."),
		"B" = list("what" = "A bomb hatch: a trapdoor with a cradle for two aircraft bombs.", "use" = "Drops a bomb on the ground below when its ring is pulled.", "how" = "Craft it from 6 steel after Powered Flight and set it in her deck; load bombs into it."),
		// Engines
		"gasoline" = list("what" = "A 4-stroke gasoline engine: 100 power per 1000 cc.", "use" = "A light, common engine. Burns gasoline.", "how" = "The engine maker makes it for 50 steel per 1000 cc, from 80 to 30000 cc."),
		"twostroke" = list("what" = "A 2-stroke gasoline engine: 90 power per 1000 cc.", "use" = "A tiny, cheap engine for the smallest gondolas. Burns gasoline.", "how" = "40 steel per 1000 cc, from 49 to 1000 cc."),
		"efficient" = list("what" = "A high efficiency gasoline engine: 500 power per 1000 cc.", "use" = "Much more power for its size, at a high price in steel.", "how" = "100 steel per 1000 cc, from 100 to 30000 cc."),
		"ethanol" = list("what" = "An ethanol-gasoline engine: 86 power per 1000 cc.", "use" = "Runs on gasoline or on ethanol distilled at home.", "how" = "60 steel per 1000 cc, from 80 to 30000 cc."),
		"diesel" = list("what" = "A diesel engine: 80 power per 1000 cc.", "use" = "Thrifty and strong in big sizes, as the great airships carried. Burns diesel.", "how" = "40 steel per 1000 cc, from 300 to 45000 cc."),
		"biodiesel" = list("what" = "A biodiesel engine: 72 power per 1000 cc.", "use" = "Burns diesel or biodiesel pressed from crops.", "how" = "45 steel per 1000 cc, from 300 to 45000 cc."),
		"hesselman" = list("what" = "A Hesselman engine: 86 power per 1000 cc.", "use" = "Burns diesel, biodiesel or gasoline, whichever is to hand.", "how" = "43 steel per 1000 cc, from 200 to 55000 cc."),
		"hotbulb" = list("what" = "A hot bulb engine: 66 power per 1000 cc.", "use" = "A slow old engine that burns almost any oil or fuel.", "how" = "33 steel per 1000 cc, from 200 to 45000 cc."),
		"turbine" = list("what" = "A turbine engine: 136 power per 1000 cc.", "use" = "Great power for its weight, burning almost any fuel quickly.", "how" = "73 steel per 1000 cc, from 250 to 18000 cc."),
	)
