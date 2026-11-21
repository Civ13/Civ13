// Submarine sheets (naval/sub_draught.dm): a submarine drawn on a ship's
// draught keeps the pen's plan rules, matches the Scout and Explorer section
// for section, travels as a design code, and a boat afloat can have her
// lines drawn. Runs before the hand-built boats clear the sea.

// Walls of a wall code as a sorted list, so "Rh Fb" equals "Fb Rh".
/proc/submarine_sheet_walls(code)
	var/list/parts = splittext(code, " ")
	parts -= ""
	return sortList(parts)

// TRUE when a sheet's layout is the given layout section for section: the
// same hull type, the same walls and the same fittings (a dive locker draws as
// a locker).
/proc/submarine_sheet_matches(datum/sub_draught/D, list/layout)
	var/list/mine = D.layout()
	if (mine.len != layout.len)
		return FALSE
	for (var/coords in layout)
		var/list/theirs = layout[coords]
		var/list/ours = mine[coords]
		if (!ours || ours[1] != theirs[1])
			return FALSE
		if (jointext(submarine_sheet_walls(ours[2]), " ") != jointext(submarine_sheet_walls(theirs[2]), " "))
			return FALSE
		var/list/a = list()
		var/list/b = list()
		for (var/i = 3, i <= theirs.len, i++)
			var/f = sub_draught_fitting_for(theirs[i])
			a += f ? f : "[theirs[i]]"
		for (var/i = 3, i <= ours.len, i++)
			var/f = sub_draught_fitting_for(ours[i])
			b += f ? f : "[ours[i]]"
		if (jointext(sortList(a), ",") != jointext(sortList(b), ","))
			return FALSE
	return TRUE

/proc/submarine_sheet_checks()
	// The examples are the pen's boats.
	var/list/examples = sub_draught_examples()
	submarine_check(examples.len == 2, "two example sheets")
	var/datum/sub_draught/scout = examples[1]
	var/datum/sub_draught/explorer = examples[2]
	submarine_check(scout.name == "Scout" && scout.length == 5 && explorer.name == "Explorer" && explorer.length == 7, "the Scout is 5 long and the Explorer 7")
	submarine_check(scout.buildable() && explorer.buildable(), "both examples can be assembled as drawn")
	submarine_check(submarine_sheet_matches(scout, submarine_layouts["scout"]), "the Scout sheet lays out as the pen's Scout")
	submarine_check(submarine_sheet_matches(explorer, submarine_layouts["explorer"]), "the Explorer sheet lays out as the pen's Explorer")
	var/list/cost = scout.costs()
	submarine_check(cost["steel"] == 15 * 6 + 56 + 10 + 8 + 8 && cost["wood"] == 10 && cost["iron"] == 4, "the Scout costs her sections, controls, tank and fittings")

	// Codes go round.
	var/code = explorer.to_code()
	var/datum/sub_draught/again = sub_draught_from_code(code)
	submarine_check(again && again.to_code() == code && again.name == "Explorer", "an Explorer code reads back as the same sheet")
	submarine_check(length(code) <= DESIGN_CODE_SUB_MAX, "the longest boat's code fits the code limit")
	submarine_check(!sub_draught_from_code(replacetext(code, "/7/", "/8/")), "a code for a boat 8 long is refused")
	submarine_check(!sub_draught_from_code(replacetext(code, "2,3,h,", "2,3,x,")), "a code with a hatch amidships is refused")
	submarine_check(!sub_draught_from_code(copytext(code, 1, findtext(code, ";", -12))), "a code missing a section is refused")
	submarine_check(!sub_draught_from_code("C13SHIP/1/ship/"), "a ship code is not a submarine")
	submarine_check(design_code_kind_name("SUB") == "a submarine sheet", "submarine codes are named in refusals")
	submarine_check(draught_code_max() == max(DESIGN_CODE_SHIP_MAX, DESIGN_CODE_SUB_MAX), "the sheet accepts the longest code of any kind")
	var/datum/sub_draught/read = call(draught_kinds["SUB"]["read"])(code)
	submarine_check(read && read.length == 7, "the kinds table reads a submarine code")

	// The rules.
	var/datum/sub_draught/D = new(5)
	var/list/P = D.problems()
	submarine_check(P.len == 3, "a bare hull lacks a wheel, a station and a hatch")
	submarine_check(!D.set_frame(2, 3, "x") && !D.set_frame(1, 1, "x") && !D.set_frame(1, 5, "x") && D.set_frame(1, 3, "x"), "hatches only in side sections between bow and stern")
	submarine_check(!D.set_fitting(2, 5, "B") && D.set_fitting(2, 1, "W") && D.set_fitting(1, 2, "S"), "the stern row takes no fittings")
	submarine_check(!D.set_wall(2, 1, "b") && !D.set_wall(1, 5, "b") && D.set_wall(2, 5, "d"), "no wall on the glass or the tanks; the engine room can have a door")
	submarine_check(D.buildable(), "a wheel, a station and a hatch make her buildable")
	submarine_check(D.wall_code(1, 3) == "" && D.wall_code(1, 1) == "Fg Rg" && D.wall_code(3, 5) == "Ft Bh Lh Rt", "hatch sides are open, the bow is glass, the stern tanks sealed")
	D.set_wall(1, 4, "b")
	D.set_wall(2, 4, "b")
	D.set_wall(3, 4, "b")
	submarine_check(!D.buildable(), "a bulkhead right across her is refused")
	D.set_wall(2, 4, "d")
	submarine_check(D.buildable(), "a door in it opens the way aft")
	D.set_fitting(2, 4, "E")
	D.set_length(4)
	submarine_check(D.length == 4 && !D.cell(2, 4)[2] && D.cell(1, 3)[1] == "x" && !D.cell(1, 5), "shortening her makes row 4 the engine room and keeps the hatch")
	D.set_length(7)
	submarine_check(D.length == 7 && D.cell(1, 7) && D.cell(1, 4)[1] == "h", "lengthening her adds hull")
	submarine_check(!D.set_length(3) && !D.set_length(8) && D.length == 7, "lengths outside 4 to 7 are refused")

	// The sheet item.
	var/obj/item/ship_draught/S = new(locate(2, 2, 2))
	S.take_sub(scout)
	var/datum/sub_draught/kept = S.sub_draught()
	submarine_check(kept && kept.to_code() == scout.to_code() && S.name == "submarine sheet (Scout)" && S.sub_draught_kind() && !S.draught(), "a sheet keeps a submarine and is no ship")
	S.take(null)
	submarine_check(!S.sub_draught_kind() && S.name == initial(S.name), "a cleared sheet is blank")

	// Her lines drawn from a boat afloat.
	var/obj/structure/vehicleparts/axis/ship/submarine/explorer/X = build_submarine(locate(10, 22, 2), "Lines", /obj/structure/vehicleparts/axis/ship/submarine/explorer)
	var/datum/sub_draught/drawn = sub_draught_survey(X)
	submarine_check(istype(drawn) && drawn.name == "Lines" && copytext(drawn.to_code(), length("C13SUB/1/Lines/") + 1) == copytext(explorer.to_code(), length("C13SUB/1/Explorer/") + 1), "drawing an Explorer's lines gives the Explorer sheet")
	submarine_check(istext(sub_draught_survey(new /obj/structure/vehicleparts/axis/ship/submarine)), "an unassembled boat cannot be drawn")

// A boat assembled from a sheet (ships/submarine_assembly.dm): six sections
// long, which only a sheet allows, with two battery banks. Runs after the
// hand-built checks have cleared the sea.
/proc/submarine_sheet_assembly_checks()
	submarine_clear_boats()
	var/mob/living/submarine_probe/builder = new(locate(2, 2, 2))
	var/datum/sub_draught/D = new(6)
	D.name = "Longfin"
	D.set_fitting(2, 1, "W")
	D.set_fitting(1, 2, "S")
	D.set_frame(1, 3, "x")
	D.set_frame(3, 3, "x")
	D.set_fitting(1, 4, "E")
	D.set_fitting(3, 4, "E")
	D.set_fitting(1, 5, "A")
	D.set_wall(1, 4, "b")
	D.set_wall(2, 4, "d")
	D.set_wall(3, 4, "b")
	submarine_check(D.buildable(), "the Longfin is drawn ready to assemble")
	var/obj/item/ship_draught/S = new(locate(2, 2, 2))
	S.take_sub(D)

	// Bow south: column c lies at x 9 + c, row r at y 9 + r.
	submarine_lay_sections(10, 10, 12, 15)
	new /obj/structure/vehicleparts/shipwheel(locate(11, 10, 2))
	new /obj/structure/vehicleparts/sub_station/loose(locate(10, 11, 2))
	new /obj/structure/engine/internal/diesel/premade/chiha(locate(11, 15, 2))
	new /obj/item/weapon/reagent_containers/glass/barrel/fueltank/tank(locate(11, 15, 2))
	new /obj/structure/vehicleparts/sub_fitting/battery/loose(locate(10, 13, 2))
	new /obj/structure/vehicleparts/sub_fitting/battery/loose(locate(12, 13, 2))
	new /obj/structure/vehicleparts/sub_fitting/air/loose(locate(10, 14, 2))
	var/obj/structure/vehicleparts/axis/ship/submarine/controls/A = new(locate(11, 12, 2))
	var/datum/vehicle_survey/V = new(A)
	submarine_check(V.refusal && findtext(V.refusal, "5 (a Scout) or 7 (an Explorer)"), "without a sheet a 3 by 6 hull is refused ([V.refusal])")

	var/obj/item/ship_draught/bare = new(locate(2, 2, 2))
	bare.take_sub(new /datum/sub_draught(6))
	A.attackby(bare, builder)
	submarine_check(!A.sheet_code, "a sheet that cannot be assembled is not clipped on")
	A.attackby(S, builder)
	submarine_check(A.sheet_code == S.draught_code, "the controls take the Longfin's sheet")
	V = new(A)
	submarine_check(!V.refusal && !V.missing().len, "with the sheet the 3 by 6 hull surveys as a boat ([V.refusal])")

	submarine_check(isnull(A.assemble(SOUTH)) && A.frames().len == 18 && A.hull_class == "explorer", "she assembles bow south with eighteen sections")
	var/list/hull_states = icon_states('icons/obj/vehicles/submarine_hull.dmi')
	var/art = TRUE
	for (var/obj/structure/vehicleparts/frame/ship/steel/submarine/F in A.frames())
		if (!("[F.hull_tile]_deck" in hull_states))
			art = FALSE
	submarine_check(art && submarine_hull_at(11, 15).hull_tile == "explorer_2_7" && submarine_hull_at(11, 13).hull_tile == "explorer_2_4", "every section has hull art, the stern row the Explorer's stern")
	submarine_check(istype(submarine_hull_at(10, 12), /obj/structure/vehicleparts/frame/ship/steel/submarine/hatch) && istype(submarine_hull_at(12, 12), /obj/structure/vehicleparts/frame/ship/steel/submarine/hatch) && !istype(submarine_hull_at(10, 13), /obj/structure/vehicleparts/frame/ship/steel/submarine/hatch), "her hatches are where the sheet put them")
	submarine_check(submarine_hull_at(10, 13).w_front[1] == "sub_bulkhead" && submarine_hull_at(11, 13).door_walls().len == 1 && submarine_hull_at(10, 10).w_front[1] == "sub_glass", "her bulkhead, door and glass bow are where the sheet put them")
	var/list/layout = A.hull_layout()
	submarine_check(layout.len == 18 && A.hull_square() == 6, "her plan is the sheet's, six rows long")
	submarine_check(A.battery_capacity() == 5400 * 3 / 2 && A.air_capacity() == 6000 && A.battery <= A.battery_capacity(), "two battery banks hold half again a Scout's charge; one air bank a Scout's air")
	submarine_check(isnull(A.change_depth(TRUE)) && A.submerged && isnull(A.change_depth(FALSE)) && !A.submerged, "she dives and surfaces")
	submarine_check(A.do_matrix(A.dir, TURN_LEFT(A.dir), "left") && submarine_span(A, "x") == 6 && submarine_span(A, "y") == 3, "she turns in her square")
	var/datum/sub_draught/drawn = sub_draught_survey(A)
	submarine_check(istype(drawn) && drawn.length == 6 && drawn.fitting_count("E") == 2, "drawing her lines gives her sheet back")
	var/before = A.sheet_code
	var/obj/item/ship_draught/scout_sheet = new(locate(2, 2, 2))
	var/list/examples = sub_draught_examples()
	scout_sheet.take_sub(examples[1])
	A.attackby(scout_sheet, builder)
	submarine_check(A.sheet_code == before, "an assembled boat keeps her plan")
	submarine_clear_boats()

	// A boat with no banks has half a Scout's battery and air.
	var/obj/structure/vehicleparts/axis/ship/submarine/P = build_submarine(locate(10, 10, 2), "bankless")
	for (var/obj/structure/vehicleparts/sub_fitting/B in world)
		qdel(B)
	submarine_check(P.battery_capacity() == 5400 / 2 && P.air_capacity() == 6000 / 2, "a boat stripped of her banks keeps half a bank of each in her hull")
	submarine_clear_boats()
