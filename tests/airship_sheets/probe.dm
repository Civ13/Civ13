// Airship sheets (code/modules/naval/air_draught.dm, air_draught_checks.dm,
// airship_yard.dm, docs/airship-sheets.md): the ready-made sheets pass their
// checks and read back from their codes, bad codes are refused, each
// air_sheet check fires, every key has a part description, the airship yard
// refuses what it cannot build and lays and commissions a sheet from its
// stock, and her lines are drawn back onto a sheet tile for tile.
/world
	hub = ""
	hub_password = ""
	maxx = 60
	maxy = 60
	maxz = 1
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
var/naval_failures = 0
var/naval_runtime_error = FALSE
/proc/naval_check(condition, label)
	if (!condition)
		naval_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	naval_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/air_report_has(datum/air_draught/D, level, text)
	var/datum/design_report/R = D.check_design()
	. = FALSE
	for (var/t in R.texts(level))
		if (findtext(t, text))
			. = TRUE
	qdel(R)

/proc/air_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/T = locate(x, y, 1)
			T.ChangeTurf(/turf/floor/dirt)

/proc/naval_checks()
	air_fixture()
	if (!research_nodes.len)
		build_research_tree()

	// ---- Codes and the ready-made sheets ----
	var/list/examples = air_draught_examples()
	naval_check(examples.len == 3, "three ready-made airship sheets")
	for (var/datum/air_draught/E in examples)
		var/datum/design_report/R = E.check_design()
		naval_check(!R.blocked(), "the [E.name] can be built as drawn ([jointext(R.texts(DESIGN_ERROR), " ")])")
		qdel(R)
		var/code = E.to_code()
		var/datum/air_draught/back = air_draught_from_code(code)
		naval_check(back && back.to_code() == code && length(code) <= DESIGN_CODE_AIR_MAX, "the [E.name] reads back from its code ([code])")
		naval_check(findtext(E.summary_text(), "Building her takes"), "and has a summary")
	var/datum/air_draught/scout = examples[1]
	var/good = scout.to_code()
	naval_check(!air_draught_from_code(replacetext(good, "2,1,p,c,W", "2,1,q,c,W")), "an unknown deck is refused")
	naval_check(!air_draught_from_code(replacetext(good, "2,1,p,c,W", "9,1,p,c,W")), "a tile off the sheet is refused")
	naval_check(!air_draught_from_code(replacetext(good, "/gasoline/1000/", "/gasoline/90000/")), "an engine bigger than the engine maker makes is refused")
	naval_check(!air_draught_from_code(replacetext(good, "/3/3/4/", "/3/30/4/")), "a sheet wider than 12 is refused")
	naval_check(draught_kinds["AIR"] && draught_kinds["AIR"]["read"] == /proc/air_draught_from_code, "the airship sheet is a kind of ship's draught")
	naval_check(design_code_kind_name("AIR") == "an airship sheet", "a pasted airship code is named")

	// ---- Checks ----
	var/datum/air_draught/D = air_draught_from_code(good)
	D.set_part(2, 1, null)
	naval_check(air_report_has(D, DESIGN_ERROR, "no helm"), "no helm is an error")
	D = air_draught_from_code(good)
	D.set_deck(2, 4, null)
	D.set_deck(1, 4, "p")
	D.set_deck(1, 3, null)
	naval_check(air_report_has(D, DESIGN_ERROR, "in pieces"), "a deck in pieces is an error")
	D = air_draught_from_code(good)
	for (var/key in D.cells)
		var/list/at = splittext(key, ",")
		D.set_gas_cell(text2num(at[1]), text2num(at[2]), null)
	naval_check(air_report_has(D, DESIGN_ERROR, "no gas cells"), "no gas cells is an error")
	D = air_draught_from_code(good)
	D.set_crew(60)
	for (var/col = 1, col <= 3, col++)
		D.set_gas_cell(col, 2, null)
	D.set_gas_cell(2, 4, null)
	naval_check(air_report_has(D, DESIGN_ERROR, "lifts empty but not crewed"), "too big a crew is an error")
	D = air_draught_from_code(good)
	D.set_part(3, 3, null)
	naval_check(air_report_has(D, DESIGN_WARNING, "will not run"), "an engine with no tank is a warning")
	D = air_draught_from_code(good)
	D.set_part(2, 3, null)
	naval_check(air_report_has(D, DESIGN_WARNING, "no engine to burn"), "a tank with no engine is a warning")
	naval_check(air_report_has(D, DESIGN_NOTE, "slow ahead only"), "and no engine is a note")
	var/list/book = design_part_help_for("air_sheet")
	var/list/missing = list()
	for (var/key in air_draught_decks() + air_draught_cells() + air_draught_parts() + vehicle_draught_engines)
		if (!book[key])
			missing += key
	naval_check(!missing.len && book["x"], "every key on the sheet has a part description ([jointext(missing, " ")])")

	// ---- The airship yard ----
	var/obj/structure/car_workshop/airship_yard/Y = new(locate(10, 10, 1))
	naval_check(get_recipe_node_req("/obj/structure/car_workshop/airship_yard") == "lighter_than_air_flight", "Lighter-than-Air Flight gates the yard")
	naval_check(!Y.sheet_axes().len && !Y.models().len, "the yard builds no cars and no fixed models")
	var/refusal = Y.air_refusal(null, scout)
	naval_check(findtext(refusal, "Combustion"), "a sheet with an engine needs the Combustion Engine ([refusal])")
	Y.stock = list("wood" = 100, "cloth" = 400, "steel" = 200)
	naval_check(Y.stock_key(new /obj/item/stack/material/plastic(null)) == "plastic" && Y.stock_cap("cloth") == 1200, "the yard takes plastic and holds 1200 cloth")
	var/obj/structure/airship_helm/helm = Y.build_airship(scout)
	naval_check(istype(helm) && helm.craft && helm.craft.name == "scout airship", "the yard lays and commissions the scout airship ([helm])")
	if (istype(helm))
		var/list/deck = scout.deck_cells()
		naval_check(helm.x == Y.x + 2 && helm.y == Y.y + 4 && helm.dir == NORTH, "her helm is on the bow row, facing north ([helm.x],[helm.y])")
		var/datum/craft_body/built/air/B = helm.craft.body
		naval_check(B.cells().len == deck.len, "her deck is all [deck.len] tiles (got [B.cells().len])")
		var/obj/structure/airship_gas_cell/G = locate() in locate(Y.x + 1, Y.y + 3, 1)
		naval_check(istype(G) && !G.gas && !G.lift(), "her cells hang empty")
		var/obj/structure/engine/internal/E = locate() in locate(Y.x + 2, Y.y + 2, 1)
		naval_check(istype(E) && E.enginesize == 1000 && E.fueltank && !E.fueltank.reagents.total_volume, "her 1000cc engine is connected to an empty tank")
		naval_check(Y.stock["wood"] == 100 - 8 * 3 - 10 && Y.stock["cloth"] == 400 - 8 * 20, "the yard spends its stock (wood [Y.stock["wood"]], cloth [Y.stock["cloth"]])")
		naval_check(findtext(Y.air_refusal(null, examples[2]), "clear") || findtext(Y.air_refusal(null, examples[2]), "research"), "her deck blocks the next build")
		var/datum/air_draught/drawn = air_draught_survey(helm)
		if (istype(drawn))
			drawn.set_crew(scout.crew)
		naval_check(istype(drawn) && drawn.to_code() == scout.to_code(), "her lines are drawn back tile for tile ([istype(drawn) ? drawn.to_code() : drawn])")

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
