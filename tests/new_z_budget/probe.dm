// Actual production controller, allocator, roofbuilder and config parser.
// Large-map arithmetic is exercised without allocating those native grids.
/world
	maxx = 10
	maxy = 10
	maxz = 1
	turf = /turf/floor/plating
	area = /area/caribbean
	hub = ""
	hub_password = ""

/world/OpenPort(port)
	return port == "none" ? ..() : FALSE

/obj/map_metadata/z_budget_fixture/New()
	return

/mob/z_budget_fixture/New()
	return

/obj/item/weapon/roofbuilder/z_budget_fixture
	var/prompts = 0

/obj/item/weapon/roofbuilder/z_budget_fixture/building_confirm(mob/user, direction)
	prompts++
	return TRUE

/obj/item/weapon/roofbuilder/z_budget_fixture/building_wait(mob/user, duration, turf/start)
	return TRUE

var/z_budget_checks = 0
var/z_budget_default_refusal = FALSE
var/z_budget_existing_plane = FALSE

/proc/z_budget_assert(condition, message)
	z_budget_checks++
	if (!condition)
		throw EXCEPTION(message)

/proc/z_budget_arithmetic()
	z_budget_assert(!new_z_grid_error(466666,1,2,1,3,"restore",1400000,1,0,0), "below 1.4 million admitted")
	z_budget_assert(!new_z_grid_error(700000,1,1,1,2,"roof",1400000,1,0,0), "inclusive 1.4 million admitted")
	z_budget_assert(new_z_grid_error(466667,1,2,1,3,"restore",1400000,1,0,0), "one-over total-cell ceiling blocked")
	z_budget_assert(!new_z_grid_error(200000,1,5,1,6,"restore",1400000,1,0,0) && !new_z_grid_error(200000,1,6,1,7,"restore",1400000,1,0,0) && new_z_grid_error(200000,1,7,1,8,"restore",1400000,1,0,0), "repeated requests stop at inclusive ceiling")
	// Retain lower-host-budget vectors independently of the hard ceiling.
	z_budget_assert(!new_z_grid_error(375,447,1,1,2,"roof",600000,1,0,0), "Europe one plane admitted")
	z_budget_assert(!new_z_grid_error(500,350,2,2,3,"roof",600000,1,0,0), "shipped two-z Gaia admitted")
	z_budget_assert(!new_z_grid_error(500,350,1,1,2,"roof",600000,1,0,0), "generated one-z Gaia admitted")
	z_budget_assert(!new_z_grid_error(500,400,1,1,3,"restore",600000,1,0,0), "exact total-cell ceiling admitted")
	z_budget_assert(new_z_grid_error(500,401,1,1,3,"restore",600000,1,0,0), "one-over lower host budget blocked")
	z_budget_assert(new_z_grid_error(500,350,2,2,4,"restore",600000,1,0,0), "multi-level Gaia target refused as a whole")
	z_budget_assert(new_z_grid_error(375,447,1,1,3,"roof",600000,1,0,0), "second roof plane blocked")
	z_budget_assert(new_z_grid_error(500,500,3,3,4,"restore",600000,1,0,0), "over-budget compiled world cannot grow")
	z_budget_assert(!new_z_grid_error(500,500,3,3,3,"restore",600000,1,0,0), "over-budget existing grid retained")
	z_budget_assert(new_z_grid_error(500,350,1,1,2,"roof",600000,1,4,1), "reserved Dagger and home demand protected")
	z_budget_assert(new_z_grid_error(10,10,1,1,2,"instance",600000,1,0,0), "unconfigured instance allocation denied")
	z_budget_assert(!new_z_grid_error(10,10,1,1,5,"instance",600000,1,4,1), "four-deck compact instance fits reservation")
	z_budget_assert(new_z_grid_error(10,10,1,1,33,"restore",600000,1,0,0), "absolute z ceiling blocked")
	for (var/bad in list("2", -1, 2.5, null))
		z_budget_assert(new_z_grid_error(10,10,1,1,bad,"restore",600000,1,0,0), "invalid target blocked")
	z_budget_assert(new_z_grid_error(10,10,1,1,2,"unknown",600000,1,0,0), "unknown purpose blocked")
	z_budget_assert(new_z_dimension_variable("maxz") && new_z_dimension_variable("MAXX") && new_z_dimension_variable("maxy") && !new_z_dimension_variable("view"), "all raw world dimensions protected")

/world/New()
	OpenPort("none")
	sleep(1)
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		map = new /obj/map_metadata/z_budget_fixture
		map_storage.record_compiled_dimensions()
		config = new
		z_budget_assert(world.byond_version == 516 && world.byond_build == 1681, "pinned native runtime")
		z_budget_assert(!world.port, "native port closed")
		z_budget_arithmetic()
		var/turf/site = locate(4,4,1)
		new /obj/structure/roof_support(site)
		var/mob/z_budget_fixture/U = new(locate(4,3,1))
		U.dir = NORTH
		var/obj/item/weapon/roofbuilder/z_budget_fixture/B = new(U)
		z_budget_assert(!building_allocate_level(2) && world.maxz == 1, "default unmeasured allocation preserves grid")
		z_budget_assert(findtext(world_z_budget.last_error, "UNMEASURED:") == 1, "default refusal explains unmeasured profile")
		B.attack_self(U)
		var/obj/roof/fallback = locate(/obj/roof) in site
		z_budget_assert((!B || !B.loc) && world.maxz == 1 && fallback && !fallback.building_floor(), "unmeasured roof-only fallback consumes builder without growth")
		z_budget_default_refusal = TRUE
		// Accepted allocation tests use an explicitly isolated test subclass only.
		var/datum/world_z_budget/fixture_admission/F = new
		world_z_budget = F
		world_z_budget.record_compiled_dimensions()
		z_budget_assert(!world_z_budget.configure("new_z_cell_budget", "1400001"), "raising ceiling rejected")
		z_budget_assert(!world_z_budget.configure("new_z_roof_levels", "2"), "raising roof allowance rejected")
		for (var/bad in list("-1", "1.5", "none", "600000x", "1e3", ""))
			z_budget_assert(!world_z_budget.configure("new_z_cell_budget", bad), "malformed config rejected")
		// Exercise the actual configuration switch, not a duplicate parser.
		text2file("NEW_Z_CELL_BUDGET 100\nNEW_Z_ROOF_LEVELS 1\n", "budget-config.txt")
		config.load("budget-config.txt")
		z_budget_assert(world_z_budget.cell_limit == 100 && config.new_z_cell_budget == 100, "production config lowers policy")
		site = locate(6,4,1)
		new /obj/structure/roof_support(site)
		U.loc = locate(6,3,1)
		B = new(U)
		z_budget_assert(!building_allocate_level(2) && world.maxz == 1, "lowered budget refuses growth")
		B.attack_self(U)
		fallback = locate(/obj/roof) in site
		z_budget_assert((!B || !B.loc) && world.maxz == 1 && fallback && !fallback.building_floor(), "budget-denied roof-only fallback consumes builder without growth")
		z_budget_assert(world_z_budget.configure("new_z_cell_budget", "1400000"), "default ceiling restored within hard bound")
		var/datum/new_z_reservation/R = world_z_budget.reserve(2, "roof")
		z_budget_assert(R && !world_z_budget.reserve(2, "roof"), "competing reservation refused")
		z_budget_assert(!begin_persistence_operation(map_storage, "save"), "reservation excludes snapshot admission")
		z_budget_assert(!world_z_budget.configure("new_z_cell_budget", "0"), "active reservation freezes policy")
		z_budget_assert(!building_allocate_level(2) && world.maxz == 1, "unowned allocator cannot steal reservation")
		z_budget_assert(!world_z_budget.claim_level(R, 3), "nonadjacent reservation claim refused")
		R.width = 9
		z_budget_assert(!world_z_budget.claim_level(R, 2) && world.maxz == 1, "stale dimensions refused before resize")
		world_z_budget.finish(R, FALSE)
		z_budget_assert(!world_z_budget.active, "unused reservation releases ownership")
		site = locate(8,4,1)
		new /obj/structure/roof_support(site)
		U.loc = locate(8,3,1)
		B = new(U)
		B.attack_self(U)
		z_budget_assert(world.maxz == 2 && (locate(/obj/roof) in site) && !B.loc, "first roof allocates and consumes builder only after success")
		z_budget_assert(!building_allocate_level(3) && world.maxz == 2, "second physical roof plane denied")
		// Switch back to the production rejection policy: existing planes still work.
		world_z_budget = new
		world_z_budget.record_compiled_dimensions()
		var/turf/reuse = locate(7,7,1)
		new /obj/structure/roof_support(reuse)
		U.loc = locate(7,6,1)
		var/obj/item/weapon/roofbuilder/z_budget_fixture/existing = new(U)
		existing.attack_self(U)
		z_budget_assert(world.maxz == 2 && (locate(/obj/roof) in reuse) && (!existing || !existing.loc), "production unmeasured policy permits existing-plane reuse")
		z_budget_existing_plane = TRUE
		world_z_budget = F
		// Whole-target restoration: reject two added levels before the first write.
		world_z_budget.configure("new_z_cell_budget", "300")
		persistence_save_in_progress = TRUE
		R = world_z_budget.reserve(4, "restore")
		z_budget_assert(!R && world.maxz == 2 && !building_allocating_z, "whole restore denial has no partial level")
		world_z_budget.configure("new_z_cell_budget", "400")
		R = world_z_budget.reserve(4, "restore")
		z_budget_assert(R, "whole restore interval reserved")
		map_storage.dimension_bootstrap_busy = TRUE
		map_storage.dimension_reservation = R
		map_storage.dimension_recovery_required = TRUE
		z_budget_assert(building_allocate_level(3, TRUE, R) && world_z_budget.active == R, "restore first plane retains interval")
		z_budget_assert(!building_allocate_level(4) && world.maxz == 3, "competing roof cannot interrupt restore")
		z_budget_assert(building_allocate_level(4, TRUE, R), "restore second plane uses same admission")
		z_budget_assert(world_z_budget.finish(R, TRUE) && !world_z_budget.active, "whole restore reservation completes")
		map_storage.dimension_reservation = null
		map_storage.dimension_recovery_required = FALSE
		map_storage.dimension_bootstrap_busy = FALSE
		persistence_save_in_progress = FALSE
		z_budget_assert(!world_z_budget.claim_level(R, 5), "completed reservation cannot replay")
		z_budget_assert(world_z_budget.configure("new_z_cell_budget", "1400000") && world_z_budget.configure("new_z_instance_reserve", "4") && world_z_budget.configure("new_z_safehouse_reserve", "1"), "explicit future-purpose reserve configured")
		R = world_z_budget.reserve(8, "instance")
		z_budget_assert(R, "future four-deck request reserves entire interval")
		world_z_budget.finish(R, FALSE)
		z_budget_assert(world_z_budget.instance_used == 0, "cancelled future interval consumes no capacity")
		R = world_z_budget.reserve(8, "instance")
		for (var/deck = 5 to 8)
			z_budget_assert(building_allocate_level(deck, FALSE, R), "reserved compact deck [deck] initializes")
		z_budget_assert(world_z_budget.finish(R, TRUE) && world_z_budget.instance_used == 4, "instance capacity commits once")
		z_budget_assert(!world_z_budget.configure("new_z_instance_reserve", "3"), "committed instance reservation cannot shrink")
		R = world_z_budget.reserve(9, "safehouse")
		z_budget_assert(R && building_allocate_level(9, FALSE, R) && world_z_budget.finish(R, TRUE) && world_z_budget.safehouse_used == 1, "home reserve survives and commits separately")
		text2file("PASS: new-z budget", "result.txt")
	catch (var/exception/budget_error)
		text2file("FAIL: [budget_error.name]", "result.txt")
	text2file(json_encode(list("checks" = z_budget_checks, "maxz" = world.maxz, "default_refusal" = z_budget_default_refusal, "existing_plane" = z_budget_existing_plane, "byond_version" = world.byond_version, "byond_build" = world.byond_build, "port" = world.port)), "receipt.json")
	shutdown()
