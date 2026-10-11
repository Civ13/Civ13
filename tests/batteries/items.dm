// Actual game constructors/APIs, with world/controller startup disabled by runner.
/world
	hub = ""
	hub_password = ""
	maxx = 4
	maxy = 4
	maxz = 1
	turf = /turf
	area = /area
/obj/map_metadata/battery_ci
	New()
		return
var/list/battery_item_errors = list()
/proc/battery_item_check(label, actual, expected)
	var/line = "[label]: [actual] expected [expected]"
	world.log << line
	if (actual != expected) battery_item_errors += line
/proc/run_battery_item_checks()
	GLOB.moved_event = new /decl/observ/moved
	makeDatumRefLists()
	populate_material_list()
	map = new /obj/map_metadata/battery_ci
	map.ordinal_age = 1
	var/list/rows = file2list(file("config/crafting/material_recipes_global.txt"), "\n")
	var/found = 0
	craftlist_lists["global"] = list()
	for (var/line in rows)
		if (!findtext(line, "RECIPE: ") || findtext(line, "//")) continue
		var/list/row = splittext(replacetext(line, "RECIPE: ", ""), ",")
		if (findtext(row[3], "/obj/structure/battery"))
			found++
			battery_item_check("recipe field count", row.len, 13)
			battery_item_check("compiled output", ispath(text2path(row[3]), /obj/structure/battery), TRUE)
			craftlist_lists["global"] += list(row)
	battery_item_check("three recipe tiers", found, 3)
	var/material/copper/M = get_material_by_name("copper")
	M.generate_recipes_civs(list(200,200,200), "global")
	var/count = 0
	for (var/datum/stack_recipe_list/G in M.recipes)
		count += G.recipes.len
	battery_item_check("copper assemblies in production menu", count, 2)
	var/material/lead/LM = get_material_by_name("lead")
	LM.generate_recipes_civs(list(200,200,200), "global")
	count = 0
	for (var/datum/stack_recipe_list/G in LM.recipes)
		count += G.recipes.len
	battery_item_check("lead assembly in production menu", count, 1)
	var/turf/T = locate(1,1,1)
	var/obj/structure/battery/B = new(T)
	battery_item_check("crafted jar empty", B.stored_energy, 0)
	var/obj/item/weapon/reagent_containers/food/drinks/clay/clayvase/J = new(T)
	B.attackby(J, null)
	battery_item_check("fired jar consumed into assembly", B.assembled, TRUE)
	var/obj/item/stack/material/iron/I = new(T, 3, FALSE)
	B.attackby(I, null)
	battery_item_check("electrode sheet consumed", I.amount, 2)
	B.attackby(I, null)
	battery_item_check("duplicate electrode not consumed", I.amount, 2)
	var/obj/item/weapon/reagent_containers/glass/beaker/R = new(T)
	R.reagents.add_reagent("grapejuice", 9)
	B.attackby(R, null)
	battery_item_check("insufficient electrolyte no energy", B.stored_energy, 0)
	battery_item_check("insufficient electrolyte retained", R.reagents.get_reagent_amount("grapejuice"), 9)
	R.reagents.add_reagent("grapejuice", 11)
	B.attackby(R, null)
	battery_item_check("primary batch energy", B.stored_energy, 600)
	battery_item_check("electrolyte consumed exactly", R.reagents.get_reagent_amount("grapejuice"), 10)
	B.attackby(R, null)
	battery_item_check("full primary cannot renew", R.reagents.get_reagent_amount("grapejuice"), 10)
	var/obj/structure/battery/lead_acid/L = new(locate(2,1,1))
	R.reagents.add_reagent("sacid", 20)
	L.attackby(R, null)
	battery_item_check("lead-acid commissioned", L.commissioned, TRUE)
	battery_item_check("commissioning grants no energy", L.stored_energy, 0)
	battery_item_check("acid consumed exactly", R.reagents.get_reagent_amount("sacid"), 0)
	L.stored_energy = 123.5
	L.mode = "discharge"
	L.output_power = 10
	var/list/fields = L.get_saved_vars()
	battery_item_check("energy durable field", ("stored_energy" in fields), TRUE)
	battery_item_check("output excluded from save", ("output_power" in fields), FALSE)
	battery_item_check("mode excluded from save", ("mode" in fields), FALSE)
	battery_item_check("wiring excluded from save", ("powersource" in fields), FALSE)
	var/savefile/S = new("battery-state.sav")
	for (var/field in fields) S[field] << L.vars[field]
	var/obj/structure/battery/lead_acid/loaded = new(locate(3,1,1))
	for (var/field in fields) S[field] >> loaded.vars[field]
	battery_item_check("durable energy round trip", loaded.stored_energy, 123.5)
	battery_item_check("load starts off", loaded.mode, "off")
	battery_item_check("load has no output credit", loaded.output_power, 0)
	var/obj/structure/cable/port = new(T)
	B.anchored = TRUE
	B.powersource = port
	port.connections |= B
	B.mode = "discharge"
	B.settle_tick()
	battery_item_check("real source advertises output", port.powerflow, 1)
	B.forceMove(locate(1,2,1))
	battery_item_check("movement detaches source", B.powersource, null)
	battery_item_check("movement removes stale supply", port.powerflow, 0)
	loaded.anchored = TRUE
	loaded.loc = T
	loaded.powersource = port
	port.connections |= loaded
	loaded.mode = "discharge"
	loaded.settle_tick()
	battery_item_check("loaded storage can power circuit", port.powerflow, 10)
	loaded.Destroy()
	battery_item_check("deletion removes stale supply", port.powerflow, 0)
	var/report = battery_item_errors.len ? "[jointext(battery_item_errors, "\n")]\nFAIL" : "BATTERY ITEMS PASS"
	text2file(report, "battery-item-checks.txt")
	shutdown()
