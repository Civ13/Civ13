// Production constructors and accounting, with world/controller startup disabled.
/world
	hub = ""
	hub_password = ""
	maxx = 4
	maxy = 4
	maxz = 2
	turf = /turf
	area = /area
/obj/map_metadata/energy_ci/New()
	return
/world/OpenPort(port)
	return port == "none" ? ..() : FALSE
var/list/energy_ci_errors = list()
/proc/energy_ci_check(label, actual, expected)
	world.log << "[label]: [actual] expected [expected]"
	if (actual != expected)
		energy_ci_errors += label
/proc/run_modern_energy_checks()
	OpenPort("none")
	GLOB.moved_event = new /decl/observ/moved
	makeDatumRefLists()
	populate_material_list()
	map = new /obj/map_metadata/energy_ci
	map.ordinal_age = 8
	var/obj/structure/civ_generator/solar/G = new(locate(1,1,1))
	var/area/A = get_area(G)
	A.location = AREA_OUTSIDE
	A.weather = WEATHER_NONE
	time_of_day = "Midday"
	energy_ci_check("outdoor midday", G.rated_output(), 30)
	time_of_day = "Night"
	energy_ci_check("night zero", G.rated_output(), 0)
	time_of_day = "unrecognized"
	energy_ci_check("unknown label zero", G.rated_output(), 0)
	time_of_day = "Midday"
	A.location = AREA_INSIDE
	energy_ci_check("indoor zero", G.rated_output(), 0)
	A.location = AREA_OUTSIDE
	A.weather = WEATHER_WET
	energy_ci_check("wet weather reduced", G.rated_output(), 15)
	A.weather = WEATHER_NONE
	var/obj/structure/cable/C = new(G.loc)
	G.powersource = C
	C.connections |= G
	G.enabled = TRUE
	G.settle_generation()
	energy_ci_check("real cable capacity", C.rebuild_supply(), 30)
	energy_ci_check("charge first reservation", C.reserve_battery_charge(20), 20)
	energy_ci_check("charge debit reduces live capacity", C.rebuild_supply(), 10)
	energy_ci_check("duplicate charge cannot mint energy", C.reserve_battery_charge(20), 10)
	energy_ci_check("spent output unavailable", G.available_output(), 0)
	G.settle_generation()
	energy_ci_check("same interval not replayed", G.available_output(), 0)
	G.stop_generation()
	G.enabled = TRUE
	G.settle_generation()
	energy_ci_check("toggle not replayed", G.available_output(), 0)
	G.output_epoch = -1
	G.settle_generation()
	var/obj/load = new /obj(G.loc)
	load.powerneeded = 10
	load.powersource = C
	C.connections |= load
	energy_ci_check("consumer reservation accepted", C.rebuild_supply(load,10), TRUE)
	energy_ci_check("consumer demand preserved during charge", C.reserve_battery_charge(30), 20)
	energy_ci_check("consumer capacity retained", C.rebuild_supply(), 10)
	C.connections -= load
	C.power_consumers -= load
	load.powersource = null
	G.output_epoch = -1
	G.settle_generation()
	var/obj/structure/battery/lead_acid/B = new(G.loc)
	B.anchored = TRUE
	B.commissioned = TRUE
	B.powersource = C
	C.connections |= B
	B.mode = "charge"
	B.settle_tick()
	energy_ci_check("solar charges storage", B.stored_energy, 10)
	energy_ci_check("storage charge debited source", G.available_output(), 20)
	G.output_until = world.time
	energy_ci_check("expired solar unavailable", C.rebuild_supply(), 0)
	B.last_tick = -1
	B.settle_tick()
	energy_ci_check("expired source cannot charge", B.stored_energy, 10)
	G.output_epoch = -1
	G.settle_generation()
	C.disconnect()
	energy_ci_check("cut cable stops generator", G.enabled, FALSE)
	G.powersource = C
	C.connections |= G
	G.enabled = TRUE
	G.settle_generation()
	energy_ci_check("reconnect does not replay cut output", G.available_output(), 0)
	G.forceMove(locate(1,1,2))
	energy_ci_check("movement disconnects", G.powersource, null)
	energy_ci_check("old grid loses source", C.rebuild_supply(), 0)
	G.enabled = TRUE
	G.output_power = 30
	G.after_load()
	energy_ci_check("reload off", G.enabled, FALSE)
	energy_ci_check("reload clears output", G.output_power, 0)
	for (var/key in list("enabled", "registered", "retired", "output_power", "output_until", "output_epoch", "charge_power", "powersource"))
		energy_ci_check("runtime excluded [key]", G.persistence_runtime_var(key), TRUE)
	G.name = "saved solar controller"
	G.enabled = TRUE
	G.output_power = 30
	G.output_until = world.time + 10
	var/savefile/F = new("solar-state.sav")
	F["/format_version"] << 2
	map_storage.saving_z = 2
	var/saved_ref = map_storage.BuildVarDirectory(F, G, 2)
	energy_ci_check("native entry exported", !!saved_ref, TRUE)
	F.cd = map_storage.entry_path(F, saved_ref)
	energy_ci_check("native exporter omits output", ("output_power" in F.dir), FALSE)
	// Forged legacy runtime values must be rejected during import too.
	F["enabled"] << list("kind" = "value", "value" = TRUE)
	F["output_power"] << list("kind" = "value", "value" = 999)
	F["registered"] << list("kind" = "value", "value" = FALSE)
	map_storage.clear_bookkeeping()
	var/obj/structure/civ_generator/solar/restored = map_storage.Load_Entry(F, saved_ref, null, locate(2,2,2))
	energy_ci_check("native entry restored", !!restored, TRUE)
	if (restored)
		energy_ci_check("native name retained", restored.name, "saved solar controller")
		energy_ci_check("native import starts off", restored.enabled, FALSE)
		energy_ci_check("native import rejects stale output", restored.output_power, 0)
		energy_ci_check("native import reconstructs registry", restored.registered, TRUE)
		restored.retire_generator()
	G.retire_generator()
	energy_ci_check("retirement releases registry", (G in civ_generators), FALSE)
	var/list/created = list()
	for (var/i = 1, i <= CIV_GENERATOR_LIMIT + 1, i++)
		created += new /obj/structure/civ_generator/solar(locate(4,4,1))
	energy_ci_check("registry bounded", civ_generators.len, CIV_GENERATOR_LIMIT)
	var/obj/structure/civ_generator/overflow = created[created.len]
	energy_ci_check("overflow fails closed", overflow.registered, FALSE)
	for (var/obj/structure/civ_generator/item in created)
		item.retire_generator()
	energy_ci_check("registry released after cycles", civ_generators.len, 0)
	var/report = "Modern energy production contract checks\n"
	for (var/error in energy_ci_errors)
		report += "FAIL [error]\n"
	report += energy_ci_errors.len ? "FAIL" : "PASS"
	text2file(report, "battery-item-checks.txt")
	world.log << report
	shutdown()
