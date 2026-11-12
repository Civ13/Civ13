// The open sea (code/modules/naval/open_sea.dm, open_sea_sites.dm,
// open_sea_chart.dm, docs/craft-core.md): sea cells and tide races, the home
// island, the cell pool, islands and wrecks that are raised and taken away,
// and a hull making passage by the chart from the home waters to an island
// and home again.
/world
	hub = ""
	hub_password = ""
	maxx = 120
	maxy = 80
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
var/naval_failures = 0
var/naval_runtime_error = FALSE
/proc/naval_check(condition, label)
	if (!condition)
		naval_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	naval_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/obj/map_metadata/nomads/open_sea/probe/New()
	return
/obj/map_metadata/nomads/open_sea/probe/is_node_done(faction, node_id)
	return naval_research_done

// Rock under everything, deep sea on the sea level, sky above. The cells are
// 40 tiles with a 3-tile tide race, so the 120 x 80 sea is 3 by 2 cells.
/proc/naval_fixture()
	sea_cell_pitch = 40
	sea_cell_margin = 3
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/R = locate(x, y, 1)
			R.ChangeTurf(/turf/floor/dirt/underground)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
			var/turf/S = locate(x, y, 3)
			S.ChangeTurf(/turf/sky/building)

/proc/hull_lay(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/repairedfloor/ship/C = new(T)
	C.updateturf()
	return C

// The fixture's people have no body to redraw: hands are plain fields.
/mob/living/human/naval_probe/put_in_hands(var/obj/item/W)
	W.forceMove(src)
	return TRUE

// A 5 by 3 hull with a rigged mast, bow east, its corner at (x, y).
/proc/sea_ship(x, y, ship_name)
	for (var/dx = 0, dx < 5, dx++)
		for (var/dy = 0, dy < 3, dy++)
			hull_lay(x + dx, y + dy)
	var/obj/structure/hull_tiller/tiller = new(locate(x + 1, y + 1, 2))
	var/obj/structure/vehicleparts/movement/sail/mast = new(locate(x + 3, y + 1, 2))
	mast.sails = new /obj/item/sail(mast)
	naval_check(isnull(tiller.commission(ship_name, EAST)), "the [ship_name] is commissioned")
	return tiller

// Runs the chart until her course is done. Returns the steps taken.
/proc/sea_passage(datum/craft/C)
	. = 0
	var/datum/chart/open_sea/chart = open_sea_chart()
	while (C.sea_token && (C.sea_token.on_course || C.sea_token.speed() > 0) && . < 3000)
		chart.run_step(CHART_STEP_SECONDS)
		.++

/proc/sea_land_in(n)
	. = 0
	var/list/B = sea_cell_box(n)
	for (var/turf/T in block(locate(B[1], B[2], 2), locate(B[3], B[4], 2)))
		if (!istype(T, /turf/floor/beach/water))
			.++

/proc/sea_things_in(n)
	. = 0
	var/list/B = sea_cell_box(n)
	for (var/turf/T in block(locate(B[1], B[2], 2), locate(B[3], B[4], 2)))
		for (var/atom/movable/A in T)
			if (A.loc == T && !istype(A, /atom/movable/lighting_overlay))
				.++

/proc/naval_checks()
	naval_fixture()
	naval_check(open_sea_world() && !sea_pool_made, "the fixture is an open-sea world")

	// ---- Cells and tide races ----
	naval_check(sea_cell_count() == 6 && sea_cells_across() == 3 && sea_home_cell() == 5, "the sea is six cells, the middle of the top row the home waters ([sea_cell_count()], [sea_home_cell()])")
	var/list/first = sea_cell_box(1)
	naval_check(first[1] == 4 && first[2] == 4 && first[3] == 37 && first[4] == 37 && isnull(sea_cell_box(7)), "a cell's water lies inside its tide race ([first[1]],[first[2]] to [first[3]],[first[4]])")
	naval_check(sea_cell_of(locate(45, 45, 2)) == 5 && sea_cell_of(locate(45, 45, 1)) == 5 && sea_cell_of(locate(1, 1, 2)) == 1 && sea_cell_of(locate(120, 80, 2)) == 6 && !sea_cell_of(locate(45, 45, 3)), "a tile knows its cell, on the sea and under it")
	naval_check(open_sea_prepare(), "the world is prepared")
	var/turf/race = locate(40, 20, 2)
	var/turf/open = locate(20, 20, 2)
	naval_check(istype(race, /turf/floor/beach/water/deep/saltwater/tide_race) && istype(locate(1, 1, 2), /turf/floor/beach/water/deep/saltwater/tide_race) && !istype(open, /turf/floor/beach/water/deep/saltwater/tide_race), "tide races are laid between the cells and round the edge")
	var/mob/living/human/naval_probe/ann = new(open)
	ann.real_name = "Ann"
	ann.civilization = "Reds"
	human_mob_list += ann
	naval_check(!race.CanPass(ann) && race.density, "nobody swims a tide race")
	naval_check(!open_sea_lay_races(), "and laying them twice changes nothing")
	naval_check(sea_get_registry() && sea_registry.loc == locate(1, 1, 2), "the registry lies in the corner")

	// ---- The home island ----
	var/turf/middle = sea_cell_centre(5)
	naval_check(middle.x == 60 && middle.y == 60 && !istype(middle, /turf/floor/beach/water) && sea_land_in(5) > 10, "the home island is raised in the middle of the home waters ([sea_land_in(5)] tiles of land)")
	var/turf/shore = null
	for (var/turf/D in range(8, middle))
		if (!istype(D, /turf/floor/beach/water) && (locate(/turf/floor/beach/water/shallowsaltwater) in range(1, D)))
			shore = D
			break
	naval_check(shore && open_sea_landing_at(shore) && !open_sea_landing_at(locate(shore.x, shore.y, 1)) && !open_sea_landing_at(locate(20, 20, 2)), "a trail can leave from the shore of the home island and nowhere else")
	var/land_was = sea_land_in(5)
	open_sea_prepare()
	naval_check(sea_land_in(5) == land_was, "and is not raised twice")
	for (var/n in list(1, 2, 3, 4, 6))
		if (sea_land_in(n))
			naval_check(FALSE, "cell [n] should be open water")

	// ---- The pool ----
	var/datum/plane_pool/sea/pool = sea_pool()
	naval_check(length(pool.all_planes()) == 5 && !(5 in pool.all_planes()) && length(pool.free_planes()) == 4 && pool.owner_of(1) == "people", "five cells are the pool; the one Ann swims in is not free ([length(pool.free_planes())])")
	human_mob_list -= ann
	ann.forceMove(locate(50, 46, 2))
	naval_check(length(pool.free_planes()) == 5, "bare probe mobs are counted only when listed")

	// ---- The chart ----
	var/datum/chart/open_sea/chart = open_sea_chart()
	naval_check(chart && chart.home && chart.sites.len == OPEN_SEA_ISLANDS + OPEN_SEA_WRECKS && open_sea_sites.len == chart.sites.len, "the chart has the home waters, nine islands and six wrecks ([chart.sites.len])")
	var/apart = TRUE
	for (var/datum/chart_site/sea/A in chart.sites)
		if (chart_distance(A.x, A.y, chart.home.x, chart.home.y) < 12)
			apart = FALSE
		for (var/datum/chart_site/sea/B in chart.sites)
			if (A != B && chart_distance(A.x, A.y, B.x, B.y) < 9)
				apart = FALSE
	naval_check(apart, "every site lies clear of the home waters and of the others")
	var/saved = chart.state_text()
	naval_check(chart.read_state(saved) && chart.sites.len == 15 && chart.state_text() == saved && open_sea_sites.len == 15, "the sea is saved as one text and read back the same")
	naval_check(!chart.read_state("") && !chart.read_state("nonsense") && chart.sites.len == 15, "a text with no sea in it changes nothing")

	// ---- A ship in the home waters ----
	var/obj/structure/hull_tiller/tiller = sea_ship(46, 45, "Wren")
	var/datum/craft/C = tiller.craft
	var/datum/craft_body/built/B = C.body
	naval_check(findtext(C.open_sea_text(), "lies in the home waters") && C.thrust() > 0 && C.open_sea_place() == chart.home && findtext(C.open_sea_text(), "lies in the home waters"), "she lies in the home waters under sail ([C.open_sea_text()])")
	var/datum/chart_token/passage/T = C.open_sea_token()
	naval_check(T && T.x == chart.home.x && T.y == chart.home.y && T.max_speed == OPEN_SEA_SPEED, "her token lies on the home waters")
	// The nearest island and the nearest wreck.
	var/datum/chart_site/sea/island/isle = null
	var/datum/chart_site/sea/wreck/hulk = null
	for (var/datum/chart_site/sea/S in chart.sites)
		var/far = chart_distance(S.x, S.y, T.x, T.y)
		if (istype(S, /datum/chart_site/sea/island) && (!isle || far < chart_distance(isle.x, isle.y, T.x, T.y)))
			isle = S
		if (istype(S, /datum/chart_site/sea/wreck) && (!hulk || far < chart_distance(hulk.x, hulk.y, T.x, T.y)))
			hulk = S
	naval_check(findtext(C.put_to_sea(), "anchor is down") && C.open_sea_place() == chart.home, "at anchor she does not put to sea")
	C.set_anchor(FALSE)
	var/turf/was = get_turf(tiller)
	naval_check(isnull(C.put_to_sea()) && sea_cell_of(get_turf(tiller)) == 1 && isnull(C.open_sea_place()) && pool.owner_of(1) == "ship", "with her anchor up she puts to sea into the first free cell ([sea_cell_of(get_turf(tiller))])")
	naval_check(get_turf(ann) == locate(tiller.x + 3, tiller.y, 2) && !locate(/obj/covers) in was && B.tile_count() == 15, "all of her and her crew went along")
	var/turf/mid = sea_cell_centre(1)
	naval_check(B.contains(mid), "and she lies in the middle of her own water")
	naval_check(isnull(C.put_to_sea()) && sea_cell_of(get_turf(tiller)) == 1, "at sea already, putting to sea changes nothing")
	naval_check(findtext(C.open_sea_text(), "is at sea") && findtext(C.open_sea_text(), "The home waters: 0 miles"), "the chart says she is at sea ([C.open_sea_text()])")

	// ---- Landfall ----
	naval_check(T.lay_course(isle.x, isle.y, isle.name) && !isle.loaded, "a course is laid for [isle.name], which nobody has raised")
	var/steps = sea_passage(C)
	naval_check(steps > 3 && T.x == isle.x && T.y == isle.y, "she makes the passage in [steps] steps")
	naval_check(isle.loaded && isle.cell == 2 && sea_land_in(2) > 3 && pool.owner_of(2) == "site:[isle.id]", "the island is raised in the next free cell ([isle.cell], [sea_land_in(2)] tiles of land)")
	naval_check(sea_cell_of(get_turf(tiller)) == 2 && C.open_sea_place() == chart.place_of(isle) && C.anchored && C.speed == VESSEL_SPEED_STOP, "and she lies at anchor off it")
	var/afloat = TRUE
	for (var/turf/D in B.cells())
		if (!istype(D, /turf/floor/beach/water) || sea_tide_race_at(D.x, D.y))
			afloat = FALSE
	naval_check(afloat && !pool.owner_of(1) && !sea_things_in(1), "wholly afloat, with the water she crossed in left empty")
	naval_check(findtext(C.open_sea_text(), "lies off [isle.name]"), "the chart says where she lies ([C.open_sea_text()])")
	var/isle_land = sea_land_in(2)

	// ---- Leaving: the island sinks behind her, unless someone stays ----
	var/mob/living/human/naval_probe/bob = new(sea_cell_centre(2))
	bob.real_name = "Bob"
	bob.civilization = "Blues"
	human_mob_list += bob
	C.set_anchor(FALSE)
	naval_check(isnull(C.put_to_sea()) && sea_cell_of(get_turf(tiller)) == 1 && T.x == isle.x, "she puts to sea again from the island")
	naval_check(!isle.can_unload() && !isle.watch() && !isle.unload() && isle.loaded, "with Bob ashore the island stays")
	human_mob_list -= bob
	bob.forceMove(locate(tiller.x + 2, tiller.y, 2))
	var/obj/structure/berth/quay/post = new(sea_cell_centre(2))
	naval_check(isle.has_harbour() && isle.held() && !isle.can_unload(), "a mooring post makes a harbour of it, and a harbour stays")
	qdel(post)
	naval_check(isle.can_unload() && isle.watch() && isle.linger_timer, "empty, its count starts")
	naval_check(isle.linger_done() && !isle.loaded && !isle.cell && !sea_land_in(2) && !sea_things_in(2), "and when it runs out the sea closes over the cell")
	naval_check(istype(sea_cell_centre(2), /turf/floor/beach/water/deep/saltwater), "which is deep salt water again")

	// ---- The same island rises the same ----
	naval_check(isnull(isle.load()) && isle.cell == 2 && sea_land_in(2) == isle_land, "raised again it is the same island ([sea_land_in(2)] tiles)")
	naval_check(isle.unload(), "and sinks again")

	// ---- A wreck ----
	naval_check(isnull(hulk.load()) && hulk.cell == 2, "the wreck is found in a free cell")
	var/planks = 0
	var/crates = 0
	var/list/W = sea_cell_box(2)
	for (var/turf/D in block(locate(W[1], W[2], 2), locate(W[3], W[4], 2)))
		if (locate(/obj/covers/repairedfloor/ship) in D)
			planks++
		for (var/obj/structure/closet/crate/K in D)
			crates++
			if (!K.contents.len)
				naval_check(FALSE, "a crate of the wreck is empty")
	naval_check(planks >= 5 && crates >= 1 && !sea_land_in(2), "she is [planks] broken planks adrift with [crates] crate\s of her hold")

	// ---- Too many sites ----
	pool.site_cap = 1
	naval_check(findtext(isle.load(), "too many") && !isle.loaded, "past the cap no further site is raised ([isle.load()])")
	pool.site_cap = SEA_SITE_CAP
	pool.set_paused(TRUE)
	naval_check(findtext(isle.load(), "paused") && sea_registry.pool_paused, "nor while an admin has paused loading")
	pool.set_paused(FALSE)
	naval_check(hulk.unload() && !sea_things_in(2), "the wreck is taken away with everything on it")

	// ---- Standing off ----
	// Every other cell is taken, so the island cannot be raised.
	var/list/blockers = list()
	for (var/n in list(2, 3, 4, 6))
		var/list/K = sea_cell_box(n)
		blockers += sea_ship(K[1] + 2, K[2] + 2, "Hulk [n]")
	naval_check(!length(pool.free_planes()), "five ships at sea fill the pool")
	T.lay_course(isle.x, isle.y, isle.name)
	T.x = isle.x
	T.y = isle.y
	naval_check(!C.open_sea_arrive() && !isle.loaded && sea_cell_of(get_turf(tiller)) == 1, "with no water free she stands off the island")
	var/obj/structure/hull_tiller/other = blockers[1]
	naval_check(!C.sights(other.craft) && !other.craft.sights(C), "ships in different waters do not sight each other")
	naval_check(findtext(other.craft.put_to_sea(), "anchor"), "a ship at sea at anchor stays where she is")
	for (var/obj/structure/hull_tiller/H in blockers)
		var/list/cells = H.craft.body.cells()
		H.decommission()
		for (var/turf/D in cells)
			for (var/atom/movable/A in D)
				qdel(A)
	naval_check(length(pool.free_planes()) == 4, "with them gone the water is free again")

	// ---- Saved mid-passage ----
	T.lay_course(chart.home.x, chart.home.y, chart.home.name)
	chart.run_step(CHART_STEP_SECONDS)
	chart.run_step(CHART_STEP_SECONDS)
	tiller.before_save()
	var/list/kept = json_decode(tiller.hull_state)
	naval_check(islist(kept["sea"]) && kept["sea"]["course"] == 1 && kept["sea"]["x"] != isle.x, "the tiller saves her place and course on the chart")
	var/at_x = T.x
	var/at_y = T.y
	qdel(C.sea_token)
	C.sea_token = null
	naval_check(C.open_sea_restore(kept["sea"]) && C.sea_token != T && abs(C.sea_token.x - at_x) < 0.01 && abs(C.sea_token.y - at_y) < 0.01 && C.sea_token.on_course && C.sea_token.course_x == chart.home.x, "and a load puts her back on it, still making for home")
	T = C.sea_token

	// ---- Home again ----
	steps = sea_passage(C)
	naval_check(C.open_sea_place() == chart.home && sea_cell_of(get_turf(tiller)) == 5 && C.anchored, "she raises the home waters and anchors there ([steps] steps)")
	afloat = TRUE
	for (var/turf/D in B.cells())
		if (!istype(D, /turf/floor/beach/water) || sea_tide_race_at(D.x, D.y))
			afloat = FALSE
	naval_check(afloat && get_turf(ann) == locate(tiller.x + 3, tiller.y, 2), "afloat off the home island with Ann still aboard")

	// ---- The registry ----
	sea_registry.before_save()
	naval_check(length(sea_registry.state) && sea_registry.state == chart.state_text(), "the registry saves the sea")
	var/text = sea_registry.state
	isle.name = "Renamed"
	sea_registry.state = text
	sea_registry.after_load()
	naval_check(chart.sites.len == 15 && !open_sea_site("s1") == FALSE && chart.state_text() == text, "and a load reads it back")

	// ---- The harbour office ----
	var/obj/structure/sea_office/office = sea_office()
	naval_check(office && sea_cell_of(get_turf(office)) == 5 && !istype(get_turf(office), /turf/floor/beach/water) && sea_office_place() == office, "the harbour office board stands on the home island, once")
	naval_check(office.fill() == SEA_OFFICE_OFFERS && office.contracts(CONTRACT_OPEN).len == SEA_OFFICE_OFFERS && !office.fill(), "it offers four contracts and no more until some time has passed")
	for (var/obj/craft_contract/sea/old in office.contracts())
		qdel(old)
	isle = null
	hulk = null
	for (var/datum/chart_site/sea/S in chart.sites)
		var/far = chart_distance(S.x, S.y, chart.home.x, chart.home.y)
		if (istype(S, /datum/chart_site/sea/island) && (!isle || far < chart_distance(isle.x, isle.y, chart.home.x, chart.home.y)))
			isle = S
		if (istype(S, /datum/chart_site/sea/wreck) && (!hulk || far < chart_distance(hulk.x, hulk.y, chart.home.x, chart.home.y)))
			hulk = S
	var/obj/craft_contract/sea/survey/job = office.offer(isle)
	var/obj/craft_contract/sea/salvage/haul = office.offer(hulk)
	var/obj/item/stack/money/wage = locate(/obj/item/stack/money) in job
	naval_check(istype(job) && istype(haul) && isnull(office.offer(isle)) && wage && wage.amount >= 10 && findtext(job.describe(null), "Survey [isle.name]") && findtext(haul.describe(null), "Salvage from [hulk.name]"), "a survey for the island and salvage for the wreck, each once, with coin in the record ([job.describe(null)])")
	naval_check(isnull(sea_office_crew_craft(ann)) && !job.take(ann, sea_office_crew_craft(ann)) && findtext(job.last_refusal, "registered crews"), "an unregistered ship takes no contract")
	var/reds = party_train_party_of(ann)
	C.register = new /datum/craft_register
	C.register.party = reds
	naval_check(sea_office_crew_craft(ann) == C && isnull(sea_office_crew_craft(bob)) && job.take(ann, C) && haul.take(ann, C) && job.taker_party == reds, "the Wren, registered and lying in the home waters, takes both")
	ann.forceMove(get_step(office, SOUTH))
	naval_check(!office.report(ann) && findtext(office.last_refusal, "not anchored off") && !office.hand_in(ann) && findtext(office.last_refusal, "no crate out of"), "nothing is paid before the work is done ([office.last_refusal])")
	ann.forceMove(locate(tiller.x + 3, tiller.y, 2))

	// The survey.
	C.set_anchor(FALSE)
	naval_check(isnull(C.put_to_sea()), "she puts to sea for the survey")
	T.lay_course(isle.x, isle.y, isle.name)
	sea_passage(C)
	naval_check(C.open_sea_place() == chart.place_of(isle) && job.done && !haul.done, "anchoring off the island does the survey")
	C.set_anchor(FALSE)
	C.put_to_sea()

	// The salvage.
	T.lay_course(hulk.x, hulk.y, hulk.name)
	sea_passage(C)
	var/obj/structure/closet/crate/prize = null
	var/list/hulk_box = sea_cell_box(hulk.cell)
	for (var/turf/D in block(locate(hulk_box[1], hulk_box[2], 2), locate(hulk_box[3], hulk_box[4], 2)))
		prize = locate(/obj/structure/closet/crate) in D
		if (prize)
			break
	naval_check(C.open_sea_place() == chart.place_of(hulk) && prize && prize.salvage_of == hulk.id, "off the wreck, her crates are branded as her cargo")
	var/obj/cargo = prize.contents[1]
	C.set_anchor(FALSE)
	C.put_to_sea()
	T.lay_course(chart.home.x, chart.home.y, chart.home.name)
	sea_passage(C)
	naval_check(C.open_sea_place() == chart.home, "home again")
	ann.forceMove(get_step(office, SOUTH))
	prize.forceMove(get_step(office, EAST))

	bob.forceMove(get_step(office, NORTH))
	naval_check(!office.report(bob) && !office.hand_in(bob) && !office.give_up(bob, job), "another party is paid nothing for it")
	naval_check(!isle.charted && office.report(ann) == 1 && QDELETED(job) && isle.charted && (wage.loc == ann || wage.loc == get_turf(ann)), "Ann reports the survey, is paid, and the island is on the chart for good")
	naval_check(office.hand_in(ann) == 1 && QDELETED(haul) && QDELETED(prize) && cargo.loc == get_step(office, EAST), "the crate is handed in for the salvage pay and its cargo stays with the crew")
	naval_check(isnull(office.offer(isle)) && istype(office.offer(hulk), /obj/craft_contract/sea/salvage), "a surveyed island needs no second survey; a wreck can be worked again")
	var/obj/craft_contract/sea/again = office.contract_for(hulk.id)
	naval_check(again.take(ann, C) && office.give_up(ann, again) && again.state == CONTRACT_OPEN && !length(again.taker_party), "a contract given up goes back on the board")
	naval_check(findtext(chart.state_text(), "\"charted\":1") && chart.read_state(chart.state_text()) && open_sea_site(isle.id).charted, "the survey is saved with the sea")
	T.x = 5
	T.y = 5
	var/found_far = FALSE
	for (var/line in C.open_sea_courses())
		if (findtext(line, open_sea_site(isle.id).name))
			found_far = TRUE
	naval_check(chart_distance(5, 5, isle.x, isle.y) > OPEN_SEA_SIGHT ? found_far : TRUE, "a surveyed island can be made for from beyond sight")

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
		map = new /obj/map_metadata/nomads/open_sea/probe
		naval_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		naval_run()
