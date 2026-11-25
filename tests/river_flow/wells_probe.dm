// Native probe for Stone and Classical player-dug wells (dug_wells.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/river_flow/wells_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 10
	maxy = 6
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/dug_wells_probe/New()
	return
var/sewer_failures = 0
var/sewer_runtime_error = FALSE
/proc/sewer_check(condition, label)
	if (!condition)
		sewer_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	sewer_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/dug_wells_probe
		sewer_checks()
	catch(var/exception/e)
		sewer_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = sewer_failures, "runtime_error" = sewer_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

// A river down the east column; a basin (x 3-5, y 3-4) at level 1 inside a rim
// at level 3; ground at 1 elsewhere, but the south row climbs from level 0 in
// the west to 15: 0, 1, 3, 6, 12, 15.
/proc/s2_flood_text()
	var/list/lines = list("civ13-river-flood 2", "size 10 6", "z 1", "reaches 1", "r 1 0 10 3 60 60 6")
	for (var/r in 1 to 6)
		lines += "01010101010101010101"
	lines += list("111111111.", "133333111.", "133333111.", "133333111.", "133333111.", "0136cf111.")
	lines += list("hollows 1", "h 1 3 1 4 4 6 30 6,0,0,0", "hollow_rows 2")
	lines += list("3 00000101010000000000", "4 00000101010000000000")
	return jointext(lines, "\n")

/proc/s2_poo(turf/T)
	return new /obj/item/weapon/reagent_containers/food/snacks/poo(T)

/proc/sewer_near(a, b)
	return abs(a - b) < 0.001

/proc/sewer_checks()
	map.persistence = TRUE
	var/datum/terrain_heights/H = new
	H.maxx = 10
	H.maxy = 6
	H.rows_by_z["1"] = list("1111111110", "1333331110", "1311131110", "1311131110", "1333331110", "0136cf1110")
	map.terrain_height_file = "probe"
	map.terrain_heights_cache = H
	var/datum/river_flood/F = river_flood_parse(s2_flood_text(), 10, 6, 1)
	sewer_check(!F.error && F.hollow_count == 1, "the probe flood file parses ([F.error])")
	map.river_flood_cache = F
	map.river_flood_loaded = TRUE
	map.river_flood_state = list()
	F.published = map.river_flood_state
	F.stage[1] = 0
	for (var/y in 1 to 6)
		var/turf/W = locate(10, y, 1)
		W.ChangeTurf(/turf/floor/beach/water/deep)
	var/turf/low = locate(1, 1, 1)
	var/turf/bank = locate(2, 1, 1)
	var/turf/plain = locate(3, 1, 1)
	var/turf/rise = locate(4, 1, 1)
	var/turf/hill = locate(5, 1, 1)
	var/turf/peak = locate(6, 1, 1)
	var/area/A = get_area(low)

	// The water table: a spit under low ground, deeper under hills.
	sewer_check(sewer_near(well_water_table(low), 1) && sewer_near(well_water_table(bank), 1.5) && sewer_near(well_water_table(plain), 2.5), "water lies 1, 1.5 and 2.5 spits under ground at levels 0, 1 and 3 ([well_water_table(low)], [well_water_table(bank)], [well_water_table(plain)])")
	sewer_check(sewer_near(well_water_table(rise), 4) && sewer_near(well_water_table(hill), 7) && sewer_near(well_water_table(peak), 8.5), "and 4, 7 and 8.5 under levels 6, 12 and 15")
	F.stage[1] = 1
	sewer_check(sewer_near(well_water_table(plain), 2), "a river a level up brings the water half a spit nearer ([well_water_table(plain)])")
	F.stage[1] = -1
	sewer_check(sewer_near(well_water_table(plain), 3), "a low river takes it half a spit further ([well_water_table(plain)])")
	F.stage[1] = 0
	A.climate = "desert"
	sewer_check(sewer_near(well_water_table(low), 3), "desert ground holds its water 2 spits deeper ([well_water_table(low)])")
	A.climate = "jungle"
	sewer_check(sewer_near(well_water_table(low), 0.5) && sewer_near(well_water_table(plain), 2), "jungle ground half a spit nearer")
	A.climate = "temperate"
	F.restore_hollows(list(1, 6))
	sewer_check(flood_depth_at(locate(4, 4, 1)) > 0 && well_water_table(locate(4, 4, 1)) == 0, "under floodwater the water is at the surface")
	F.restore_hollows(list(1, 0))
	sewer_check(findtext(well_earth_text(low, 1), "wet") && findtext(well_earth_text(plain, 1), "damp") && findtext(well_earth_text(hill, 1), "dry") && findtext(well_earth_text(low, 2), "seeps"), "the earth in the hole tells how near the water is")

	// A waterhole: dry a spit deep, wet at two, and no deeper unlined.
	sewer_check(isnull(well_site_problem(low)) && !well_build_site(low), "bare low ground can be dug, and is no place to build a well yet")
	var/obj/structure/sink/puddle/waterhole/WH = new /obj/structure/sink/puddle/waterhole(low)
	sewer_check(WH.dug_depth == 1 && WH.heat_dried() && !WH.volume && WH.icon_state == "waterhole_dry", "a hole a spit deep on low ground is dry")
	sewer_check(well_site_problem(low) && well_dug_at(low) == WH && well_build_site(low), "the hole is found on its tile, which takes a lining and no second hole")
	WH.dug_deepen()
	sewer_check(WH.dug_depth == 2 && sewer_near(WH.dug_column(), 1) && !WH.heat_dried() && WH.max_volume == 150, "at two spits a level of water stands in it ([WH.dug_column()], holds [WH.max_volume])")
	var/spoil = 0
	for (var/obj/item/weapon/barrier/B in low)
		spoil++
	sewer_check(spoil == 1, "each spit leaves a dirt pile ([spoil])")
	sewer_check(!WH.volume, "it starts empty and fills as the water seeps in")
	WH.dug_settled_at = world.time - 600
	WH.dug_settle()
	WH.update_icon()
	sewer_check(sewer_near(WH.volume, 50) && WH.icon_state == "waterhole", "a bare hole gains 50 a minute for a level of water ([WH.volume])")
	WH.dug_settled_at = world.time - 60000
	WH.dug_settle()
	sewer_check(WH.volume == 150, "and fills no further than it holds ([WH.volume])")
	sewer_check(findtext(WH.dug_deepen_problem(), "timber or stone"), "its sides stand no deeper than two spits without a lining")
	sewer_check(istype(WH, /obj/structure/sink/puddle) && !WH.mosquito_limit, "it is a puddle to everything that fouls puddles, and breeds no mosquitoes")

	// A timber lining takes over the hole and goes to five.
	WH.volume = 40
	sewer_check(!well_relining(/obj/structure/sink/well/timber, bank) && well_relining(/obj/structure/sink/well/timber, low), "a lining goes over a dug hole, and nothing is relined on bare ground")
	var/obj/structure/sink/well/timber/TW = new /obj/structure/sink/well/timber(low)
	sewer_check(QDELETED(WH) && well_dug_at(low) == TW && TW.dug_depth == 2 && TW.volume == 40, "a timber lining takes over the hole with its depth and water ([TW.dug_depth], [TW.volume])")
	sewer_check(TW.icon_state == "timber_well" && !TW.dirty, "it stands wet and clean")
	TW.dug_settled_at = world.time - 600
	TW.dug_settle()
	sewer_check(sewer_near(TW.volume, 140), "a lined well gains 100 a minute for a level of water ([TW.volume])")
	for (var/i in 1 to 3)
		TW.dug_deepen()
	sewer_check(TW.dug_depth == 5 && findtext(TW.dug_deepen_problem(), "Line it with stone"), "timber stands to five spits, then wants stone")
	sewer_check(TW.max_volume == 600, "four levels of water hold 600 ([TW.max_volume])")
	sewer_check(well_relining(/obj/structure/sink/well, low) && well_relining(/obj/structure/sink/well/marble, low) && !well_relining(/obj/structure/sink/well/timber, low) && !well_relining(/obj/structure/table, low), "a timber well takes a stone lining, not a second timber one")

	// Stone takes over from timber and goes to eight.
	TW.dirty = TRUE
	TW.volume = 300
	var/obj/structure/sink/well/SW = new /obj/structure/sink/well(low)
	sewer_check(QDELETED(TW) && SW.dug_depth == 5 && SW.volume == 300 && SW.dirty, "a stone lining takes over the timber well, foul water and all")
	for (var/i in 1 to 3)
		SW.dug_deepen()
	sewer_check(SW.dug_depth == 8 && findtext(SW.dug_deepen_problem(), "as deep as") && SW.max_volume == 750, "stone stands to eight spits and holds no more than 750 ([SW.max_volume])")
	sewer_check(SW.icon_state == "well1", "it shows as the stone well")

	// Dry spells: a shallow well fails, a deeper one lasts.
	var/obj/structure/sink/well/timber/PW = new /obj/structure/sink/well/timber(plain)
	PW.dug_depth = 3
	PW.dug_settle()
	sewer_check(sewer_near(PW.dug_column(), 0.5) && !PW.heat_dried(), "three spits on the plain reach half a level of water")
	PW.dry = TRUE
	PW.update_icon()
	sewer_check(PW.heat_dried() && PW.icon_state == "timber_well_dry", "a dry season draws the water down a spit and the well fails")
	PW.dug_deepen()
	sewer_check(!PW.heat_dried() && sewer_near(PW.dug_column(), 0.5), "dug a spit deeper it holds water through the dry season")
	PW.dry = FALSE
	F.stage[1] = 1
	sewer_check(sewer_near(PW.dug_column(), 2), "and stands deeper when the river is up ([PW.dug_column()])")
	F.stage[1] = 0

	// Hills: the deepest stone well cannot reach water under the highest ground.
	var/obj/structure/sink/well/HW = new /obj/structure/sink/well(hill)
	HW.dug_depth = 8
	var/obj/structure/sink/well/KW = new /obj/structure/sink/well(peak)
	KW.dug_depth = 8
	sewer_check(sewer_near(HW.dug_column(), 1) && !KW.dug_column() && KW.heat_dried(), "eight spits reach water under level 12 and not under level 15")

	// Springs are as they were.
	var/turf/spring = locate(1, 6, 1)
	var/obj/structure/sink/puddle/P = new /obj/structure/sink/puddle(spring)
	sewer_check(well_build_site(spring) && !well_dug_at(spring), "a puddle is a place to build a well and is not a dug one")
	var/obj/structure/sink/well/OW = new /obj/structure/sink/well(spring)
	sewer_check(!OW.dug_depth && OW.volume == 750 && !OW.heat_dried() && !QDELETED(P), "a well built over a puddle is a spring: full, and no dug depth")
	sewer_check(findtext(OW.dug_deepen_problem(), "spring"), "digging does nothing for a spring")
	OW.volume = 100
	OW.dug_settle()
	sewer_check(OW.volume == 100 && OW.max_volume == 750, "and the dug-well water rules leave it alone")

	// What fouls a well fouls a dug one.
	var/obj/item/waste = s2_poo(locate(3, 2, 1))
	sewer_check(PW.has_nearby_fecal_waste(), "waste near a dug well fouls it like any well")
	var/turf/basin = locate(4, 4, 1)
	var/obj/structure/sink/well/timber/FW = new /obj/structure/sink/well/timber(basin)
	FW.dug_depth = 2
	F.restore_hollows(list(1, 6))
	sewer_check(FW.flood_foul() && FW.dirty && sewer_near(FW.dug_column(), 2), "floodwater over a dug well fills and fouls it")
	F.restore_hollows(list(1, 0))

	// Fittings: a windlass fills a container in one haul, a pump takes its place.
	var/bail_by_hand = SW.well_bail_delay()
	var/obj/structure/well_fitting/windlass/WL = new /obj/structure/well_fitting/windlass(low)
	sewer_check(SW.well_fitting() == WL && WL.well() == SW && !PW.well_fitting(), "a windlass over a well is that well's fitting")
	var/bail_windlass = SW.well_bail_delay()
	var/obj/item/weapon/reagent_containers/glass/bucket/BK = new /obj/item/weapon/reagent_containers/glass/bucket(low)
	qdel(waste)
	SW.dirty = FALSE
	SW.volume = 300
	SW.dug_settled_at = world.time
	var/room = BK.volume - BK.reagents.total_volume
	sewer_check(room > 20 && WL.draw_into(SW, BK) == room && BK.reagents.total_volume == BK.volume && sewer_near(SW.volume, 300 - room), "one haul fills the whole bucket ([room]) and takes it from the well ([SW.volume])")
	sewer_check(BK.reagents.get_reagent_amount("water") == room && !BK.reagents.get_reagent_amount("cholera"), "clean water from a clean well")
	sewer_check(!WL.draw_into(SW, BK), "a full bucket takes no more")
	BK.reagents.clear_reagents()
	SW.dirty = TRUE
	SW.volume = 60
	sewer_check(WL.draw_into(SW, BK) == 60 && !SW.volume && BK.reagents.get_reagent_amount("cholera") > 0, "a foul well gives foul water, and only what it holds")
	BK.reagents.clear_reagents()
	sewer_check(!WL.draw_into(SW, BK), "an empty well gives nothing")
	var/obj/structure/well_fitting/pump/PU = new /obj/structure/well_fitting/pump(low)
	sewer_check(QDELETED(WL) && SW.well_fitting() == PU && PU.draw_time < initial(WL.draw_time), "a pump takes the windlass's place and draws faster")
	// Cleaning is a drain, a separate clearing stage, and a natural refill.
	sewer_check(bail_by_hand > bail_windlass && bail_windlass > SW.well_bail_delay(), "hand bailing is slower than the windlass, and a pump is faster again")
	SW.radiation = 17
	SW.dirty = TRUE
	SW.volume = 180
	SW.well_begin_scraping()
	SW.dug_settled_at = world.time - 600
	SW.dug_settle()
	sewer_check(SW.well_pauses_recharge() && !SW.volume && SW.dirty, "bailing empties the well, pauses refill, and does not clear fouling")
	SW.well_finish_scraping(FALSE)
	sewer_check(!SW.well_pauses_recharge() && SW.dirty && SW.radiation == 17, "an interrupted scrape resumes recharge without clearing contamination")
	SW.dug_settled_at = world.time - 600
	SW.dug_settle()
	sewer_check(SW.volume > 0, "a dug well refills again after the interruption")
	waste = s2_poo(locate(2, 1, 1))
	SW.well_begin_scraping()
	sewer_check(SW.well_finish_scraping(TRUE) && SW.dirty, "nearby fresh waste prevents a completed scrape from clearing fouling")
	qdel(waste)
	F.restore_hollows(list(1, 6))
	FW.well_begin_scraping()
	sewer_check(FW.well_finish_scraping(TRUE) && FW.dirty, "active inundation prevents lasting cleanup")
	F.restore_hollows(list(1, 0))
	SW.well_begin_scraping()
	sewer_check(!SW.well_finish_scraping(TRUE) && !SW.dirty && SW.radiation == 17 && !SW.volume, "with no source, clearing removes only fecal fouling and leaves the well empty")
	SW.dug_settled_at = world.time - 600
	SW.dug_settle()
	sewer_check(SW.volume > 0 && SW.radiation == 17, "the refilled well retains its radioactive contamination")
	OW.dirty = TRUE
	OW.well_begin_scraping()
	OW.refill()
	sewer_check(!OW.volume && OW.dirty, "a spring pauses its normal refill while being scraped")
	OW.well_finish_scraping(TRUE)
	OW.refill()
	sewer_check(OW.volume == 10 && !OW.dirty, "a cleaned spring refills at its ordinary rate")
	// Taking a well apart: fitting, then lining, then the hole.
	PU.unfit()
	var/obj/item/stack/material/iron/scrap = locate() in low
	sewer_check(QDELETED(PU) && !SW.well_fitting() && scrap && scrap.amount == 3, "a pump taken down gives back half its iron")
	qdel(scrap)
	SW.dug_depth = 6
	SW.volume = 400
	SW.dug_settled_at = world.time
	sewer_check(SW.dug_lined() && findtext("[SW.well_salvage()[1]]", "stone"), "a stone well is lined and gives stone back")
	var/obj/structure/sink/puddle/waterhole/BH = SW.well_break_lining()
	var/obj/item/stack/material/stone/rubble = locate() in low
	sewer_check(QDELETED(SW) && istype(BH) && BH.loc == low && rubble && rubble.amount == 3, "breaking the lining leaves a waterhole and three stone")
	sewer_check(BH.dug_depth == 2 && !BH.dug_lined() && BH.volume <= 400, "the bare shaft caves in to two spits ([BH.dug_depth]) and keeps no more water than it had ([BH.volume])")
	BH.dug_fill_in()
	sewer_check(QDELETED(BH) && !well_dug_at(low), "a shovel fills the bare hole in and nothing is left")
	qdel(rubble)
	var/obj/structure/sink/well/OW2 = new /obj/structure/sink/well(low)
	var/obj/structure/sink/left = OW2.well_break_lining(FALSE)
	sewer_check(QDELETED(OW2) && left && left.type == /obj/structure/sink/puddle && !(locate(/obj/item/stack/material/stone) in low), "an old spring well leaves its puddle, and a blast leaves no stone")
	qdel(left)
	var/obj/structure/sink/well/OW3 = new /obj/structure/sink/well(low)
	OW3.dry = TRUE
	var/obj/structure/sink/dried = OW3.well_break_lining(FALSE)
	sewer_check(istype(dried, /obj/structure/sink/puddle) && dried.dry, "a season-dried spring well leaves a dry puddle (#6764)")
	qdel(dried)
	var/obj/structure/sink/well/timber/TW2 = new /obj/structure/sink/well/timber(low)
	TW2.dug_depth = 3
	var/obj/structure/well_fitting/windlass/WL2 = new /obj/structure/well_fitting/windlass(low)
	TW2.ex_act(1)
	sewer_check(QDELETED(TW2) && QDELETED(WL2) && !well_dug_at(low), "a blast on the well fills it in, fitting and all")

	// Places a well cannot go.
	var/turf/ditch = locate(8, 5, 1)
	new /obj/structure/sewer_piece/drain/ditch(ditch)
	sewer_check(findtext(well_site_problem(ditch), "drain"), "no well in a drain")
	sewer_check(well_site_problem(locate(10, 3, 1)) && findtext(well_site_problem(spring), "water here already"), "none in the river, and none dug where a spring is")
